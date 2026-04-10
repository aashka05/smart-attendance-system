# stats_routes.py
from fastapi import APIRouter, Depends, HTTPException
from typing import Optional
from datetime import datetime, date
import json
from database import get_db, get_current_user, require_role

router = APIRouter()


# ─────────────────────────────────────────
# STUDENT STATS
# ─────────────────────────────────────────
@router.get("/stats/student/{student_id}")
def get_student_stats(student_id: str, current_user: dict = Depends(get_current_user)):
    """Get subjectwise attendance % for a student."""
    # Students can only view their own stats
    if current_user["role"] == "student" and current_user["id"] != student_id:
        raise HTTPException(status_code=403, detail="Access denied")

    conn = get_db()

    # Get all slots the student is enrolled in
    # For regular slots: match by department + year
    # For electives: match by elective_enrollments table
    student = conn.execute(
        "SELECT * FROM users WHERE id = %s", (student_id,)
    ).fetchone()

    if not student:
        conn.close()
        raise HTTPException(status_code=404, detail="Student not found")

    student = dict(student)

    # Get all subjects for this student
    slots = conn.execute(
        """
        SELECT DISTINCT ts.id as slot_id, ts.subject_id, ts.faculty_id,
               s.name as subject_name, s.code as subject_code,
               ts.lecture_type, ts.batch,
               u.full_name as faculty_name
        FROM timetable_slots ts
        LEFT JOIN subjects s ON ts.subject_id = s.id
        LEFT JOIN users u ON ts.faculty_id = u.id
        WHERE ts.is_active = TRUE
        AND (
            (ts.lecture_type = 'lecture'
             AND ts.department_id = %s
             AND ts.year = %s)
            OR
            (ts.lecture_type IN ('practical', 'tutorial')
             AND ts.department_id = %s
             AND ts.year = %s
             AND (ts.batch = %s OR ts.batch = %s OR ts.batch IS NULL))
            OR
            (ts.lecture_type IN ('open_elective', 'program_elective')
             AND ts.id IN (
                 SELECT slot_id FROM elective_enrollments
                 WHERE student_id = %s AND status = 'enrolled'
             ))
        )
    """,
        (
            student["department_id"],
            student.get("year"),
            student["department_id"],
            student.get("year"),
            student.get("practical_batch"),
            student.get("tutorial_batch"),
            student_id,
        ),
    ).fetchall()

    # Filter for faculty
    if current_user["role"] == "faculty":
        slots = [s for s in slots if dict(s)["faculty_id"] == current_user["id"]]

    stats = []
    for slot in slots:
        slot = dict(slot)

        # Count total sessions held (excluding cancelled)
        total_held = conn.execute(
            """
            SELECT COUNT(*) as count
            FROM attendance_sessions ases
            WHERE ases.slot_id = %s
            AND ases.status = 'closed'
            AND ases.slot_id NOT IN (
                SELECT slot_id FROM cancelled_lectures
                WHERE date = ases.started_at::date::text
            )
        """,
            (slot["slot_id"],),
        ).fetchone()["count"]

        # Count attended
        attended = conn.execute(
            """
            SELECT COUNT(*) as count
            FROM attendance_records ar
            LEFT JOIN attendance_sessions ases ON ar.session_id = ases.id
            WHERE ases.slot_id = %s
            AND ar.student_id = %s
            AND ar.status = 'present'
        """,
            (slot["slot_id"], student_id),
        ).fetchone()["count"]

        percentage = round((attended / total_held * 100), 1) if total_held > 0 else 0.0

        stats.append(
            {
                "slot_id": slot["slot_id"],
                "subject_id": slot["subject_id"],
                "subject_name": slot["subject_name"],
                "subject_code": slot["subject_code"],
                "lecture_type": slot["lecture_type"],
                "faculty_name": slot["faculty_name"],
                "total_held": total_held,
                "attended": attended,
                "percentage": percentage,
                "is_below_threshold": percentage < 75 and total_held > 0,
            }
        )

    overall_attended = sum(int(s["attended"]) for s in stats)
    overall_total = sum(int(s["total_held"]) for s in stats)
    overall_percentage = round((overall_attended / overall_total * 100), 1) if overall_total > 0 else 0.0

    conn.close()
    return {
        "student_id": student_id,
        "student_name": student["full_name"],
        "stats": stats,
        "attended": overall_attended,
        "total": overall_total,
        "overall_percentage": overall_percentage,
    }


@router.get("/stats/calendar/{student_id}")
def get_student_calendar(
    student_id: str,
    month: int,
    year: int,
    subject_id: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
):
    """Get day-by-day attendance for calendar view."""
    if current_user["role"] == "student" and current_user["id"] != student_id:
        raise HTTPException(status_code=403, detail="Access denied")

    conn = get_db()

    student = conn.execute(
        "SELECT * FROM users WHERE id = %s", (student_id,)
    ).fetchone()
    if not student:
        conn.close()
        raise HTTPException(status_code=404, detail="Student not found")

    student = dict(student)

    # Get attendance sessions for the month, including absent markers when a student has no present record.
    month_str = f"{year}-{month:02d}"

    records = conn.execute(
        """
        SELECT ases.started_at::date::text as session_date,
               COALESCE(ar.status, 'absent') as status,
               s.name as subject_name, s.id as subject_id, ts.faculty_id
        FROM attendance_sessions ases
        LEFT JOIN attendance_records ar
            ON ases.id = ar.session_id AND ar.student_id = %s
        LEFT JOIN timetable_slots ts ON ases.slot_id = ts.id
        LEFT JOIN subjects s ON ts.subject_id = s.id
        LEFT JOIN elective_enrollments ee
            ON ts.id = ee.slot_id AND ee.student_id = %s AND ee.status = 'enrolled'
        WHERE ases.status = 'closed'
          AND to_char(ases.started_at, 'YYYY-MM') = %s
          AND ases.slot_id NOT IN (
              SELECT slot_id FROM cancelled_lectures
              WHERE date = ases.started_at::date::text
          )
          AND (
              (ts.lecture_type = 'lecture' AND ts.department_id = %s AND ts.year = %s)
              OR (ts.lecture_type IN ('practical', 'tutorial')
                  AND ts.department_id = %s AND ts.year = %s
                  AND (ts.batch = %s OR ts.batch = %s OR ts.batch IS NULL))
              OR (ts.lecture_type IN ('open_elective', 'program_elective')
                  AND ee.student_id IS NOT NULL)
          )
        ORDER BY ases.started_at ASC
    """,
        (
            student_id,
            student_id,
            month_str,
            student["department_id"],
            student.get("year"),
            student["department_id"],
            student.get("year"),
            student.get("practical_batch"),
            student.get("tutorial_batch"),
        ),
    ).fetchall()

    # Filter for faculty
    if current_user["role"] == "faculty":
        records = [r for r in records if dict(r)["faculty_id"] == current_user["id"]]

    if subject_id:
        records = [
            r for r in records if r["subject_id"] == subject_id
        ]

    # Get cancelled lectures for the month
    cancelled_query = """
        SELECT cl.date, s.name as subject_name
        FROM cancelled_lectures cl
        LEFT JOIN timetable_slots ts ON cl.slot_id = ts.id
        LEFT JOIN subjects s ON ts.subject_id = s.id
        WHERE to_char(cl.date::date, 'YYYY-MM') = %s
          AND ts.department_id = %s
    """
    params = [month_str, student["department_id"]]
    if current_user["role"] == "faculty":
        cancelled_query += " AND ts.faculty_id = %s"
        params.append(current_user["id"])

    cancelled = conn.execute(cancelled_query, params).fetchall()

    # Get college events for the month
    events = conn.execute(
        """
        SELECT date, title, event_type
        FROM college_events
        WHERE to_char(date::date, 'YYYY-MM') = %s
        AND (department_id = %s OR department_id IS NULL)
        AND (year = %s OR year IS NULL)
    """,
        (month_str, student["department_id"], student.get("year")),
    ).fetchall()

    # Build calendar data
    calendar_data = {}

    for r in records:
        r = dict(r)
        d = r["session_date"]
        if d not in calendar_data:
            calendar_data[d] = {"sessions": [], "events": []}
        calendar_data[d]["sessions"].append(
            {
                "subject_name": r["subject_name"],
                "subject_id": r["subject_id"],
                "status": r["status"],
            }
        )

    for c in cancelled:
        c = dict(c)
        d = c["date"]
        if d not in calendar_data:
            calendar_data[d] = {"sessions": [], "events": []}
        calendar_data[d]["events"].append(
            {"type": "cancelled", "title": f"Cancelled: {c['subject_name']}"}
        )

    for e in events:
        e = dict(e)
        d = e["date"]
        if d not in calendar_data:
            calendar_data[d] = {"sessions": [], "events": []}
        calendar_data[d]["events"].append(
            {"type": e["event_type"], "title": e["title"]}
        )

    conn.close()
    return {
        "student_id": student_id,
        "month": month,
        "year": year,
        "calendar": calendar_data,
    }


# ─────────────────────────────────────────
# SESSION ATTENDEES
# ─────────────────────────────────────────
@router.get("/stats/session/{session_id}/attendees")
def get_session_attendees(
    session_id: str, current_user: dict = Depends(require_role("faculty", "admin", "hod"))
):
    """Get list of attendees for a specific session."""
    conn = get_db()

    session = conn.execute(
        "SELECT * FROM attendance_sessions WHERE id = %s",
        (session_id,),
    ).fetchone()

    if not session:
        conn.close()
        raise HTTPException(status_code=404, detail="Session not found")

    session = dict(session)

    # Check access: faculty can only view their own sessions
    if current_user["role"] == "faculty":
        slot = conn.execute(
            "SELECT faculty_id FROM timetable_slots WHERE id = %s",
            (session["slot_id"],),
        ).fetchone()
        if not slot or slot["faculty_id"] != current_user["id"]:
            conn.close()
            raise HTTPException(status_code=403, detail="Access denied")

    # Get attendees
    attendees = conn.execute(
        """
        SELECT ar.student_id, u.full_name, u.enrollment_number
        FROM attendance_records ar
        LEFT JOIN users u ON ar.student_id = u.id
        WHERE ar.session_id = %s AND ar.status = 'present'
        ORDER BY u.full_name ASC
    """,
        (session_id,),
    ).fetchall()

    conn.close()
    return [dict(a) for a in attendees]


# ─────────────────────────────────────────
# FACULTY CLASS STATS
# ─────────────────────────────────────────
@router.get("/stats/class/{slot_id}")
def get_class_stats(
    slot_id: str, current_user: dict = Depends(require_role("faculty", "admin", "hod"))
):
    """Get attendance stats for all students in a slot."""
    conn = get_db()

    slot = conn.execute(
        """
        SELECT ts.*, s.name as subject_name, s.code as subject_code,
               d.name as department_name
        FROM timetable_slots ts
        LEFT JOIN subjects s ON ts.subject_id = s.id
        LEFT JOIN departments d ON ts.department_id = d.id
        WHERE ts.id = %s
    """,
        (slot_id,),
    ).fetchone()

    if not slot:
        conn.close()
        raise HTTPException(status_code=404, detail="Slot not found")

    slot = dict(slot)

    # Verify faculty owns this slot
    if current_user["role"] == "faculty" and slot["faculty_id"] != current_user["id"]:
        conn.close()
        raise HTTPException(status_code=403, detail="Access denied")

    # Get all students for this slot
    if slot["lecture_type"] in ["open_elective", "program_elective"]:
        students = conn.execute(
            """
            SELECT u.id, u.full_name, u.enrollment_number,
                   u.practical_batch, u.tutorial_batch
            FROM users u
            LEFT JOIN elective_enrollments ee ON u.id = ee.student_id
            WHERE ee.slot_id = %s AND ee.status = 'enrolled'
            ORDER BY u.enrollment_number
        """,
            (slot_id,),
        ).fetchall()
    else:
        batch_filter = ""
        params = [slot["department_id"], slot["year"]]
        if slot.get("batch") and slot["lecture_type"] == "practical":
            batch_filter = "AND u.practical_batch = %s"
            params.append(slot["batch"])
        elif slot.get("batch") and slot["lecture_type"] == "tutorial":
            batch_filter = "AND u.tutorial_batch = %s"
            params.append(slot["batch"])

        students = conn.execute(
            f"""
            SELECT u.id, u.full_name, u.enrollment_number,
                   u.practical_batch, u.tutorial_batch
            FROM users u
            WHERE u.department_id = %s
            AND u.year = %s
            AND u.role = 'student'
            AND u.status = 'approved'
            {batch_filter}
            ORDER BY u.enrollment_number
        """,
            params,
        ).fetchall()

    # Total sessions held
    total_held = conn.execute(
        """
        SELECT COUNT(*) as count
        FROM attendance_sessions
        WHERE slot_id = %s AND status = 'closed'
    """,
        (slot_id,),
    ).fetchone()["count"]

    student_stats = []
    for student in students:
        student = dict(student)
        attended = conn.execute(
            """
            SELECT COUNT(*) as count
            FROM attendance_records ar
            LEFT JOIN attendance_sessions ases ON ar.session_id = ases.id
            WHERE ases.slot_id = %s
            AND ar.student_id = %s
            AND ar.status = 'present'
        """,
            (slot_id, student["id"]),
        ).fetchone()["count"]

        percentage = round((attended / total_held * 100), 1) if total_held > 0 else 0.0

        student_stats.append(
            {
                "student_id": student["id"],
                "full_name": student["full_name"],
                "enrollment_number": student["enrollment_number"],
                "practical_batch": student.get("practical_batch"),
                "tutorial_batch": student.get("tutorial_batch"),
                "attended": attended,
                "total_held": total_held,
                "percentage": percentage,
                "is_below_threshold": percentage < 75 and total_held > 0,
            }
        )

    conn.close()
    return {
        "slot_id": slot_id,
        "subject_id": slot["subject_id"],
        "subject_name": slot["subject_name"],
        "subject_code": slot["subject_code"],
        "department_name": slot["department_name"],
        "lecture_type": slot["lecture_type"],
        "total_held": total_held,
        "students": student_stats,
    }


@router.get("/stats/class/calendar/{slot_id}")
def get_class_calendar(
    slot_id: str,
    month: int,
    year: int,
    current_user: dict = Depends(require_role("faculty", "admin", "hod")),
):
    """Get session history for a slot by month."""
    conn = get_db()

    slot = conn.execute(
        "SELECT * FROM timetable_slots WHERE id = %s",
        (slot_id,),
    ).fetchone()
    if not slot:
        conn.close()
        raise HTTPException(status_code=404, detail="Slot not found")

    slot = dict(slot)
    if current_user["role"] == "faculty" and slot["faculty_id"] != current_user["id"]:
        conn.close()
        raise HTTPException(status_code=403, detail="Access denied")

    if slot["lecture_type"] in ["open_elective", "program_elective"]:
        total_students = conn.execute(
            """
            SELECT COUNT(*) as count
            FROM elective_enrollments
            WHERE slot_id = %s AND status = 'enrolled'
        """,
            (slot_id,),
        ).fetchone()["count"]
    else:
        batch_filter = ""
        params = [slot["department_id"], slot["year"]]
        if slot.get("batch") and slot["lecture_type"] == "practical":
            batch_filter = "AND u.practical_batch = %s"
            params.append(slot["batch"])
        elif slot.get("batch") and slot["lecture_type"] == "tutorial":
            batch_filter = "AND u.tutorial_batch = %s"
            params.append(slot["batch"])

        total_students = conn.execute(
            f"""
            SELECT COUNT(*) as count
            FROM users u
            WHERE u.department_id = %s
            AND u.year = %s
            AND u.role = 'student'
            AND u.status = 'approved'
            {batch_filter}
        """,
            params,
        ).fetchone()["count"]

    month_str = f"{year}-{month:02d}"

    sessions = conn.execute(
        """
        SELECT ases.id, ases.started_at, ases.ended_at, ases.status,
               ases.started_at::date::text as session_date,
               COUNT(ar.id) as present_count
        FROM attendance_sessions ases
        LEFT JOIN attendance_records ar ON ases.id = ar.session_id
            AND ar.status = 'present'
        WHERE ases.slot_id = %s
        AND to_char(ases.started_at, 'YYYY-MM') = %s
        GROUP BY ases.id
        ORDER BY ases.started_at ASC
    """,
        (slot_id, month_str),
    ).fetchall()

    cancelled = conn.execute(
        """
        SELECT date, reason
        FROM cancelled_lectures
        WHERE slot_id = %s
        AND to_char(date::date, 'YYYY-MM') = %s
    """,
        (slot_id, month_str),
    ).fetchall()

    result_sessions = []
    for s in sessions:
        s = dict(s)
        original_status = s["status"]
        present_count = int(s.get("present_count", 0) or 0)
        absent_count = max(total_students - present_count, 0)

        if original_status == "live":
            s["status"] = "live"
        elif absent_count > 0:
            s["status"] = "absent"
        else:
            s["status"] = "present"

        s["session_status"] = original_status
        s["absent_count"] = absent_count
        s["total_students"] = total_students
        result_sessions.append(s)

    conn.close()
    return {
        "slot_id": slot_id,
        "month": month,
        "year": year,
        "sessions": result_sessions,
        "cancelled": [dict(c) for c in cancelled],
    }


# ─────────────────────────────────────────
# ELECTIVE ENROLLMENTS
# ─────────────────────────────────────────
from pydantic import BaseModel as PydanticBaseModel


class ElectiveEnroll(PydanticBaseModel):
    slot_id: str
    student_id: str
    enrollment_type: str  # open_elective or program_elective
    status: str = "enrolled"  # enrolled or exempt


def init_elective_db():
    conn = get_db()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS elective_enrollments (
            id TEXT PRIMARY KEY,
            slot_id TEXT NOT NULL,
            student_id TEXT NOT NULL,
            enrollment_type TEXT NOT NULL,
            status TEXT DEFAULT 'enrolled',
            created_at TIMESTAMP DEFAULT NOW(),
            FOREIGN KEY (slot_id) REFERENCES timetable_slots(id),
            FOREIGN KEY (student_id) REFERENCES users(id),
            UNIQUE(slot_id, student_id)
        )
    """)
    conn.commit()
    conn.close()


init_elective_db()


@router.get("/electives/students/{slot_id}")
def get_elective_students(
    slot_id: str, current_user: dict = Depends(require_role("faculty", "admin"))
):
    conn = get_db()
    students = conn.execute(
        """
        SELECT ee.id as enrollment_id, ee.status, ee.enrollment_type,
               u.id, u.full_name, u.email, u.enrollment_number,
               d.name as department_name, u.year
        FROM elective_enrollments ee
        LEFT JOIN users u ON ee.student_id = u.id
        LEFT JOIN departments d ON u.department_id = d.id
        WHERE ee.slot_id = %s
        ORDER BY u.full_name
    """,
        (slot_id,),
    ).fetchall()
    conn.close()
    return [dict(s) for s in students]


@router.post("/electives/enroll")
def enroll_student(
    req: ElectiveEnroll, current_user: dict = Depends(require_role("faculty", "admin"))
):
    import uuid as _uuid

    conn = get_db()
    enroll_id = str(_uuid.uuid4())
    try:
        conn.execute(
            """
            INSERT INTO elective_enrollments
            (id, slot_id, student_id, enrollment_type, status)
            VALUES (%s, %s, %s, %s, %s)
        """,
            (enroll_id, req.slot_id, req.student_id, req.enrollment_type, req.status),
        )
        conn.commit()
    except Exception:
        conn.close()
        raise HTTPException(status_code=400, detail="Student already enrolled")
    conn.close()
    return {"id": enroll_id, "message": "Student enrolled"}


@router.delete("/electives/{enrollment_id}")
def remove_enrollment(
    enrollment_id: str, current_user: dict = Depends(require_role("faculty", "admin"))
):
    conn = get_db()
    conn.execute("DELETE FROM elective_enrollments WHERE id = %s", (enrollment_id,))
    conn.commit()
    conn.close()
    return {"message": "Enrollment removed"}
