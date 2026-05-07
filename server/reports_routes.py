# reports_routes.py
from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional, List
from datetime import datetime, date
from database import get_db, get_current_user, require_role
from report_generator import ReportGenerator
from fastapi.responses import FileResponse
import io

router = APIRouter()


# ─────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────
def get_term_dates(conn):
    """Get academic term start and end dates (placeholder)"""
    # In a real system, this would be configurable
    today = date.today()
    year = today.year
    
    # Assuming term starts in January and ends in May
    term_start = date(year, 1, 1)
    term_end = date(year, 5, 31)
    
    return term_start, term_end


def build_attendance_query(
    department_ids: Optional[List[str]] = None,
    years: Optional[List[int]] = None,
    subject_ids: Optional[List[str]] = None,
    student_ids: Optional[List[str]] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    student_threshold: Optional[str] = None,  # "above", "below", or None for all
    current_user: dict = None,
):
    """Build WHERE clause for attendance queries based on filters"""
    conditions = []
    params = []

    if department_ids:
        placeholders = ', '.join(['%s'] * len(department_ids))
        conditions.append(f"ts.department_id IN ({placeholders})")
        params.extend(department_ids)

    if years:
        placeholders = ', '.join(['%s'] * len(years))
        conditions.append(f"ts.year IN ({placeholders})")
        params.extend(years)

    if subject_ids:
        placeholders = ', '.join(['%s'] * len(subject_ids))
        conditions.append(f"ts.subject_id IN ({placeholders})")
        params.extend(subject_ids)

    if student_ids:
        placeholders = ', '.join(['%s'] * len(student_ids))
        conditions.append(f"ar.student_id IN ({placeholders})")
        params.extend(student_ids)

    if start_date:
        conditions.append("ases.started_at::date >= %s::date")
        params.append(start_date)

    if end_date:
        conditions.append("ases.started_at::date <= %s::date")
        params.append(end_date)

    where_clause = " AND ".join(conditions) if conditions else "1=1"
    return where_clause, params


# ─────────────────────────────────────────
# ADMIN & PRINCIPAL REPORTS
# ─────────────────────────────────────────
@router.post("/reports/department")
def generate_department_report(
    department_ids: Optional[List[str]] = Query(None),
    years: Optional[List[int]] = Query(None),
    subject_ids: Optional[List[str]] = Query(None),
    student_threshold: Optional[str] = Query(None),  # "all", "above", "below"
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user),
):
    """
    Generate department-level report (Admin & Principal only)
    """
    # Verify authorization
    if current_user["role"] not in ["admin", "principal"]:
        raise HTTPException(status_code=403, detail="Access denied")

    conn = get_db()

    try:
        # Get default dates if not provided
        if not start_date or not end_date:
            term_start, term_end = get_term_dates(conn)
            start_date = start_date or term_start.isoformat()
            end_date = end_date or term_end.isoformat()

        # If no departments specified, get all
        if not department_ids:
            depts = conn.execute("SELECT id FROM departments ORDER BY name").fetchall()
            department_ids = [d["id"] for d in depts]

        # Build report data
        report_data = []

        for dept_id in department_ids:
            dept = conn.execute(
                "SELECT name FROM departments WHERE id = %s",
                (dept_id,)
            ).fetchone()

            if not dept:
                continue

            # Get years for this department
            target_years = years if years else [1, 2, 3, 4]

            for year in target_years:
                # Get subjects for department and year
                subjects = conn.execute(
                    """
                    SELECT DISTINCT s.id, s.name, s.code
                    FROM subjects s
                    WHERE s.department_id = %s AND s.year = %s
                    ORDER BY s.name
                    """,
                    (dept_id, year)
                ).fetchall()

                for subject in subjects:
                    subject = dict(subject)

                    if subject_ids and subject["id"] not in subject_ids:
                        continue

                    # Get attendance statistics for this subject
                    stats = conn.execute(
                        """
                        SELECT
                            COUNT(DISTINCT ar.student_id) as total_students,
                            COUNT(CASE WHEN ar.status = 'present' THEN 1 END) as present,
                            COUNT(CASE WHEN ar.status IN ('absent', 'unmarked') THEN 1 END) as absent
                        FROM attendance_records ar
                        JOIN attendance_sessions ases ON ar.session_id = ases.id
                        JOIN timetable_slots ts ON ases.slot_id = ts.id
                        WHERE ts.subject_id = %s
                        AND ts.department_id = %s
                        AND ts.year = %s
                        AND ases.started_at::date >= %s::date
                        AND ases.started_at::date <= %s::date
                        AND ases.status = 'closed'
                        """,
                        (subject["id"], dept_id, year, start_date, end_date)
                    ).fetchone()

                    stats = dict(stats) if stats else {}
                    total = stats.get("total_students", 0) or 0
                    present = stats.get("present", 0) or 0

                    if total > 0:
                        attendance_pct = (present / total) * 100
                    else:
                        attendance_pct = 0

                    # Apply student threshold filter if needed
                    if student_threshold == "above":
                        if attendance_pct < 75:
                            continue
                    elif student_threshold == "below":
                        if attendance_pct >= 75:
                            continue

                    report_data.append({
                        "department": dept["name"],
                        "year": year,
                        "subject": subject["name"],
                        "total_students": total,
                        "present": present,
                        "absent": stats.get("absent", 0) or 0,
                        "attendance_percentage": attendance_pct
                    })

        # Generate PDF
        filters = {
            "Departments": ", ".join(department_ids) if len(department_ids) <= 3 else f"{len(department_ids)} departments",
            "Years": ", ".join(map(str, years)) if years else "All",
            "Subjects": "All" if not subject_ids else f"{len(subject_ids)} subjects",
            "Period": f"{start_date} to {end_date}",
            "Student Filter": student_threshold or "All"
        }

        pdf_bytes = ReportGenerator.generate_department_report(
            "Department Attendance Report",
            department_ids,
            years or [1, 2, 3, 4],
            subject_ids or [],
            report_data,
            filters,
            current_user["full_name"]
        )

        conn.close()

        return {
            "success": True,
            "message": "Report generated successfully",
            "pdf_base64": __import__('base64').b64encode(pdf_bytes).decode(),
            "total_records": len(report_data)
        }

    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────
# HOD REPORT
# ─────────────────────────────────────────
@router.get("/reports/hod")
def generate_hod_report(
    years: Optional[List[int]] = Query(None),
    subject_ids: Optional[List[str]] = Query(None),
    student_threshold: Optional[str] = Query(None),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user),
):
    """
    Generate HOD report (for their department only)
    """
    # Verify authorization
    if current_user["role"] != "hod":
        raise HTTPException(status_code=403, detail="Access denied")

    if not current_user.get("department_id"):
        raise HTTPException(status_code=400, detail="HOD must have department assigned")

    conn = get_db()

    try:
        # Get default dates if not provided
        if not start_date or not end_date:
            term_start, term_end = get_term_dates(conn)
            start_date = start_date or term_start.isoformat()
            end_date = end_date or term_end.isoformat()

        dept_id = current_user["department_id"]
        dept = conn.execute(
            "SELECT name FROM departments WHERE id = %s",
            (dept_id,)
        ).fetchone()

        report_data = []
        target_years = years if years else [1, 2, 3, 4]

        for year in target_years:
            subjects = conn.execute(
                """
                SELECT DISTINCT s.id, s.name, s.code
                FROM subjects s
                WHERE s.department_id = %s AND s.year = %s
                ORDER BY s.name
                """,
                (dept_id, year)
            ).fetchall()

            for subject in subjects:
                subject = dict(subject)

                if subject_ids and subject["id"] not in subject_ids:
                    continue

                stats = conn.execute(
                    """
                    SELECT
                        COUNT(DISTINCT ar.student_id) as total_students,
                        COUNT(CASE WHEN ar.status = 'present' THEN 1 END) as present,
                        COUNT(CASE WHEN ar.status IN ('absent', 'unmarked') THEN 1 END) as absent
                    FROM attendance_records ar
                    JOIN attendance_sessions ases ON ar.session_id = ases.id
                    JOIN timetable_slots ts ON ases.slot_id = ts.id
                    WHERE ts.subject_id = %s
                    AND ts.department_id = %s
                    AND ts.year = %s
                    AND ases.started_at::date >= %s::date
                    AND ases.started_at::date <= %s::date
                    AND ases.status = 'closed'
                    """,
                    (subject["id"], dept_id, year, start_date, end_date)
                ).fetchone()

                stats = dict(stats) if stats else {}
                total = stats.get("total_students", 0) or 0
                present = stats.get("present", 0) or 0

                if total > 0:
                    attendance_pct = (present / total) * 100
                else:
                    attendance_pct = 0

                if student_threshold == "above":
                    if attendance_pct < 75:
                        continue
                elif student_threshold == "below":
                    if attendance_pct >= 75:
                        continue

                report_data.append({
                    "department": dept["name"] if dept else "Unknown",
                    "year": year,
                    "subject": subject["name"],
                    "total_students": total,
                    "present": present,
                    "absent": stats.get("absent", 0) or 0,
                    "attendance_percentage": attendance_pct
                })

        filters = {
            "Department": dept["name"] if dept else "Unknown",
            "Years": ", ".join(map(str, years)) if years else "All",
            "Subjects": "All" if not subject_ids else f"{len(subject_ids)} subjects",
            "Period": f"{start_date} to {end_date}",
            "Student Filter": student_threshold or "All"
        }

        pdf_bytes = ReportGenerator.generate_department_report(
            f"Department Report - {dept['name'] if dept else 'Unknown'}",
            [dept_id],
            target_years,
            subject_ids or [],
            report_data,
            filters,
            current_user["full_name"]
        )

        conn.close()

        return {
            "success": True,
            "message": "Report generated successfully",
            "pdf_base64": __import__('base64').b64encode(pdf_bytes).decode(),
            "total_records": len(report_data)
        }

    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────
# FACULTY REPORT
# ─────────────────────────────────────────
@router.get("/reports/faculty")
def generate_faculty_report(
    subject_ids: Optional[List[str]] = Query(None),
    student_threshold: Optional[str] = Query(None),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user),
):
    """
    Generate faculty report (for their taught subjects only)
    """
    if current_user["role"] != "faculty":
        raise HTTPException(status_code=403, detail="Access denied")

    conn = get_db()

    try:
        if not start_date or not end_date:
            term_start, term_end = get_term_dates(conn)
            start_date = start_date or term_start.isoformat()
            end_date = end_date or term_end.isoformat()

        faculty_id = current_user["id"]

        # Get selected subjects or all subjects taught by this faculty
        if subject_ids:
            # Use provided subject_ids but verify they belong to this faculty
            taught_subjects = conn.execute(
                """
                SELECT DISTINCT s.id, s.name, s.code
                FROM subjects s
                JOIN timetable_slots ts ON s.id = ts.subject_id
                WHERE ts.faculty_id = %s AND s.id IN ({})
                ORDER BY s.name
                """.format(','.join(['%s'] * len(subject_ids))),
                (faculty_id,) + tuple(subject_ids)
            ).fetchall()
        else:
            # Get all subjects taught by this faculty
            taught_subjects = conn.execute(
                """
                SELECT DISTINCT s.id, s.name, s.code
                FROM subjects s
                JOIN timetable_slots ts ON s.id = ts.subject_id
                WHERE ts.faculty_id = %s
                ORDER BY s.name
                """,
                (faculty_id,)
            ).fetchall()

        # First, determine which subject IDs to use
        if not subject_ids:
            # Get all subjects taught by this faculty to get subject IDs
            taught_subjects_rows = conn.execute(
                """
                SELECT DISTINCT s.id
                FROM subjects s
                JOIN timetable_slots ts ON s.id = ts.subject_id
                WHERE ts.faculty_id = %s
                """,
                (faculty_id,)
            ).fetchall()
            effective_subject_ids = [str(s['id']) for s in taught_subjects_rows]
        else:
            effective_subject_ids = list(subject_ids)

        if not effective_subject_ids:
            students_data = []
        else:
            # Count total closed sessions for these subjects taught by this faculty
            total_sessions_count = conn.execute(
                """
                SELECT COUNT(DISTINCT ases.id) as total
                FROM attendance_sessions ases
                JOIN timetable_slots ts ON ases.slot_id = ts.id
                WHERE ts.subject_id IN ({})
                AND ts.faculty_id = %s
                AND ases.started_at::date >= %s::date
                AND ases.started_at::date <= %s::date
                AND ases.status = 'closed'
                """.format(','.join(['%s'] * len(effective_subject_ids))),
                tuple(effective_subject_ids) + (faculty_id, start_date, end_date)
            ).fetchone()
            total_sessions = (dict(total_sessions_count) if total_sessions_count else {}).get("total", 0) or 0

            # Get all students in the relevant department/year and their attended count
            # We find students via their attendance records OR via department enrollment
            students_data = conn.execute(
                """
                SELECT
                    u.id as student_id,
                    u.enrollment_number,
                    u.full_name,
                    COUNT(DISTINCT CASE WHEN ar.status = 'present' THEN ar.session_id END) as attended_sessions,
                    %s as total_sessions,
                    ROUND(
                        COUNT(DISTINCT CASE WHEN ar.status = 'present' THEN ar.session_id END) * 100.0
                        / NULLIF(%s, 0),
                        2
                    ) as attendance_percentage
                FROM users u
                LEFT JOIN attendance_records ar ON u.id = ar.student_id
                    AND ar.session_id IN (
                        SELECT ases.id
                        FROM attendance_sessions ases
                        JOIN timetable_slots ts ON ases.slot_id = ts.id
                        WHERE ts.subject_id IN ({subject_placeholders})
                        AND ts.faculty_id = %s
                        AND ases.started_at::date >= %s::date
                        AND ases.started_at::date <= %s::date
                        AND ases.status = 'closed'
                    )
                WHERE u.role = 'student'
                AND u.department_id IN (
                    SELECT DISTINCT ts2.department_id
                    FROM timetable_slots ts2
                    WHERE ts2.subject_id IN ({subject_placeholders2})
                    AND ts2.faculty_id = %s
                )
                AND u.year IN (
                    SELECT DISTINCT ts3.year
                    FROM timetable_slots ts3
                    WHERE ts3.subject_id IN ({subject_placeholders3})
                    AND ts3.faculty_id = %s
                )
                AND u.status = 'approved'
                GROUP BY u.id, u.enrollment_number, u.full_name
                ORDER BY u.enrollment_number
                """.format(
                    subject_placeholders=','.join(['%s'] * len(effective_subject_ids)),
                    subject_placeholders2=','.join(['%s'] * len(effective_subject_ids)),
                    subject_placeholders3=','.join(['%s'] * len(effective_subject_ids)),
                ),
                (total_sessions, total_sessions)
                + tuple(effective_subject_ids) + (faculty_id, start_date, end_date)
                + tuple(effective_subject_ids) + (faculty_id,)
                + tuple(effective_subject_ids) + (faculty_id,)
            ).fetchall()

        report_data = []
        sr_no = 1
        total_lectures = 0

        for student in students_data:
            student = dict(student)
            attendance_pct = student.get("attendance_percentage", 0) or 0
            attended_sessions = student.get("attended_sessions", 0)
            total_sessions = student.get("total_sessions", 0)

            # Apply student threshold filter
            if student_threshold == "above":
                if attendance_pct < 75:
                    continue
            elif student_threshold == "below":
                if attendance_pct >= 75:
                    continue

            report_data.append({
                "sr_no": sr_no,
                "enrollment_number": student["enrollment_number"] or "",
                "student_name": student["full_name"],
                "total_lectures": total_sessions,
                "lectures_attended": attended_sessions,
                "attendance_percentage": attendance_pct
            })
            sr_no += 1
            total_lectures = max(total_lectures, total_sessions)

        filters = {
            "Faculty": current_user["full_name"],
            "Subjects": "All" if not subject_ids else f"{len(subject_ids)} subjects",
            "Period": f"{start_date} to {end_date}",
            "Student Filter": student_threshold or "All",
            "Total Lectures": total_lectures
        }

        pdf_bytes = ReportGenerator.generate_faculty_report(
            "Faculty Attendance Report",
            current_user["full_name"],
            report_data,
            filters,
            current_user["full_name"]
        )

        conn.close()

        return {
            "success": True,
            "message": "Report generated successfully",
            "pdf_base64": __import__('base64').b64encode(pdf_bytes).decode(),
            "total_records": len(report_data)
        }

    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────
# STUDENT REPORT
# ─────────────────────────────────────────
@router.get("/reports/student/{student_id}")
def generate_student_report(
    student_id: str,
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user),
):
    """
    Generate student report (students can only view their own)
    """
    if current_user["role"] == "student" and current_user["id"] != student_id:
        raise HTTPException(status_code=403, detail="Access denied")

    if current_user["role"] not in ["student", "admin", "principal", "hod", "faculty"]:
        raise HTTPException(status_code=403, detail="Access denied")

    conn = get_db()

    try:
        student = conn.execute(
            "SELECT id, full_name, enrollment_number, department_id, year FROM users WHERE id = %s",
            (student_id,)
        ).fetchone()

        if not student:
            conn.close()
            raise HTTPException(status_code=404, detail="Student not found")

        student = dict(student)

        if not start_date or not end_date:
            term_start, term_end = get_term_dates(conn)
            start_date = start_date or term_start.isoformat()
            end_date = end_date or term_end.isoformat()

        # Get all subjects for this student (grouped by subject, not slot)
        subjects = conn.execute(
            """
            SELECT DISTINCT s.id as subject_id, s.name as subject_name, s.code as subject_code,
                   STRING_AGG(DISTINCT u.full_name, ', ') as faculty_names
            FROM subjects s
            LEFT JOIN timetable_slots ts ON s.id = ts.subject_id
            LEFT JOIN users u ON ts.faculty_id = u.id
            WHERE ts.is_active = TRUE
            AND s.department_id = %s
            AND s.year = %s
            AND ts.lecture_type IN ('lecture', 'practical', 'tutorial')
            GROUP BY s.id, s.name, s.code
            ORDER BY s.name
            """,
            (student["department_id"], student["year"])
        ).fetchall()

        report_data = []

        for subject in subjects:
            subject = dict(subject)

            # Get combined attendance for this subject across all slots
            stats = conn.execute(
                """
                SELECT
                    COUNT(DISTINCT ases.id) as total_lectures,
                    COUNT(DISTINCT CASE WHEN ar.status = 'present' THEN ases.id END) as attended
                FROM attendance_sessions ases
                JOIN timetable_slots ts ON ases.slot_id = ts.id
                LEFT JOIN attendance_records ar ON ases.id = ar.session_id
                    AND ar.student_id = %s
                WHERE ts.subject_id = %s
                AND ases.started_at::date >= %s::date
                AND ases.started_at::date <= %s::date
                AND ases.status = 'closed'
                """,
                (student_id, subject["subject_id"], start_date, end_date)
            ).fetchone()

            stats = dict(stats) if stats else {}
            total = stats.get("total_lectures", 0) or 0
            attended = stats.get("attended", 0) or 0

            if total > 0:
                attendance_pct = (attended / total) * 100
            else:
                attendance_pct = 0

            report_data.append({
                "subject_code": subject["subject_code"],
                "subject_name": subject["subject_name"],
                "faculty": subject["faculty_names"] or "N/A",
                "total_lectures": total,
                "attended": attended,
                "attendance_percentage": attendance_pct
            })

        filters = {
            "Student": student["full_name"],
            "Enrollment No.": student.get("enrollment_number", "N/A"),
            "Period": f"{start_date} to {end_date}"
        }

        pdf_bytes = ReportGenerator.generate_student_report(
            f"Attendance Report - {student['full_name']}",
            student["full_name"],
            report_data,
            filters,
            current_user["full_name"]
        )

        conn.close()

        return {
            "success": True,
            "message": "Report generated successfully",
            "pdf_base64": __import__('base64').b64encode(pdf_bytes).decode(),
            "total_records": len(report_data)
        }

    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────
# REPORT OPTIONS/FILTERS
# ─────────────────────────────────────────
@router.get("/reports/options")
def get_report_options(current_user: dict = Depends(get_current_user)):
    """Get available report options and filters based on user role"""
    conn = get_db()

    options = {
        "role": current_user["role"],
        "filters": {},
        "available_reports": []
    }

    try:
        if current_user["role"] in ["admin", "principal"]:
            # Get all departments
            depts = conn.execute(
                "SELECT id, name FROM departments ORDER BY name"
            ).fetchall()
            options["filters"]["departments"] = [{"id": d["id"], "name": d["name"]} for d in depts]
            options["filters"]["years"] = [1, 2, 3, 4]
            options["filters"]["subjects"] = []  # Populated client-side based on selected dept/year
            options["available_reports"] = ["department", "hod", "faculty", "student"]

        elif current_user["role"] == "hod":
            options["filters"]["years"] = [1, 2, 3, 4]
            options["filters"]["subjects"] = []
            options["available_reports"] = ["department"]

        elif current_user["role"] == "faculty":
            # Get taught subjects
            subjects = conn.execute(
                """
                SELECT DISTINCT s.id, s.name, s.code
                FROM subjects s
                JOIN timetable_slots ts ON s.id = ts.subject_id
                WHERE ts.faculty_id = %s
                ORDER BY s.name
                """,
                (current_user["id"],)
            ).fetchall()
            options["filters"]["subjects"] = [{"id": s["id"], "name": s["name"], "code": s["code"]} for s in subjects]
            options["available_reports"] = ["faculty", "student"]

        elif current_user["role"] == "student":
            options["available_reports"] = ["student"]

        conn.close()

        return options

    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=str(e))
