# events_routes.py
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import uuid
from database import get_db, get_current_user, require_role

router = APIRouter()


class EventCreate(BaseModel):
    title: str
    date: str  # YYYY-MM-DD
    event_type: str  # holiday / exam / fest / expert_talk
    department_id: Optional[str] = None  # null = college-wide
    year: Optional[int] = None  # null = all years
    description: Optional[str] = None


class LectureCancelRequest(BaseModel):
    slot_id: str
    date: str  # YYYY-MM-DD
    reason: Optional[str] = None


def init_events_db():
    conn = get_db()
    c = conn.cursor()

    c.execute("""
        CREATE TABLE IF NOT EXISTS college_events (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            date TEXT NOT NULL,
            event_type TEXT NOT NULL,
            department_id TEXT,
            year INTEGER,
            description TEXT,
            created_by TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT NOW(),
            FOREIGN KEY (department_id) REFERENCES departments(id),
            FOREIGN KEY (created_by) REFERENCES users(id)
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS cancelled_lectures (
            id TEXT PRIMARY KEY,
            slot_id TEXT NOT NULL,
            date TEXT NOT NULL,
            reason TEXT,
            cancelled_by TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT NOW(),
            FOREIGN KEY (slot_id) REFERENCES timetable_slots(id),
            FOREIGN KEY (cancelled_by) REFERENCES users(id)
        )
    """)

    conn.commit()
    conn.close()


init_events_db()


# ─────────────────────────────────────────
# COLLEGE EVENTS
# ─────────────────────────────────────────
@router.get("/events")
def get_events(
    month: Optional[int] = None,
    year: Optional[int] = None,
    department_id: Optional[str] = None,
    year_level: Optional[int] = None,
    current_user: dict = Depends(get_current_user),
):
    conn = get_db()
    query = """
        SELECT ce.*, u.full_name as created_by_name,
               d.name as department_name
        FROM college_events ce
        LEFT JOIN users u ON ce.created_by = u.id
        LEFT JOIN departments d ON ce.department_id = d.id
        WHERE 1=1
    """
    params = []

    if month and year:
        query += " AND EXTRACT(MONTH FROM ce.date::date) = %s AND EXTRACT(YEAR FROM ce.date::date) = %s"
        params.extend([month, year])
    elif year:
        query += " AND EXTRACT(YEAR FROM ce.date::date) = %s"
        params.append(year)

    if department_id:
        query += " AND (ce.department_id = %s OR ce.department_id IS NULL)"
        params.append(department_id)

    if year_level:
        query += " AND (ce.year = %s OR ce.year IS NULL)"
        params.append(year_level)

    query += " ORDER BY ce.date ASC"
    events = conn.execute(query, params if params else None).fetchall()
    conn.close()
    return [dict(e) for e in events]


@router.post("/events")
def create_event(
    req: EventCreate,
    current_user: dict = Depends(require_role("admin", "principal", "hod")),
):
    valid_types = ["holiday", "exam", "fest", "expert_talk"]
    if req.event_type not in valid_types:
        raise HTTPException(
            status_code=400, detail=f"Invalid event type. Must be one of: {valid_types}"
        )

    conn = get_db()
    event_id = str(uuid.uuid4())
    conn.execute(
        """
        INSERT INTO college_events
        (id, title, date, event_type, department_id, year, description, created_by)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """,
        (
            event_id,
            req.title,
            req.date,
            req.event_type,
            req.department_id,
            req.year,
            req.description,
            current_user["id"],
        ),
    )
    conn.commit()
    conn.close()
    return {"id": event_id, "message": "Event created"}


@router.delete("/events/{event_id}")
def delete_event(
    event_id: str,
    current_user: dict = Depends(require_role("admin", "principal", "hod")),
):
    conn = get_db()
    conn.execute("DELETE FROM college_events WHERE id = %s", (event_id,))
    conn.commit()
    conn.close()
    return {"message": "Event deleted"}


# ─────────────────────────────────────────
# CANCELLED LECTURES
# ─────────────────────────────────────────
@router.post("/lectures/cancel")
def cancel_lecture(
    req: LectureCancelRequest, current_user: dict = Depends(require_role("faculty"))
):
    conn = get_db()

    # Verify slot belongs to faculty
    slot = conn.execute(
        """
        SELECT * FROM timetable_slots
        WHERE id = %s AND faculty_id = %s
    """,
        (req.slot_id, current_user["id"]),
    ).fetchone()

    if not slot:
        conn.close()
        raise HTTPException(
            status_code=403, detail="Slot not found or not assigned to you"
        )

    # Check not already cancelled
    existing = conn.execute(
        """
        SELECT id FROM cancelled_lectures
        WHERE slot_id = %s AND date = %s
    """,
        (req.slot_id, req.date),
    ).fetchone()

    if existing:
        conn.close()
        raise HTTPException(
            status_code=400, detail="Lecture already cancelled for this date"
        )

    cancel_id = str(uuid.uuid4())
    conn.execute(
        """
        INSERT INTO cancelled_lectures (id, slot_id, date, reason, cancelled_by)
        VALUES (%s, %s, %s, %s, %s)
    """,
        (cancel_id, req.slot_id, req.date, req.reason, current_user["id"]),
    )

    conn.commit()
    conn.close()
    return {"id": cancel_id, "message": "Lecture cancelled"}


@router.get("/lectures/cancelled")
def get_cancelled_lectures(
    slot_id: Optional[str] = None, current_user: dict = Depends(get_current_user)
):
    conn = get_db()
    if slot_id:
        records = conn.execute(
            """
            SELECT cl.*, u.full_name as cancelled_by_name,
                   ts.subject_id
            FROM cancelled_lectures cl
            LEFT JOIN users u ON cl.cancelled_by = u.id
            LEFT JOIN timetable_slots ts ON cl.slot_id = ts.id
            WHERE cl.slot_id = %s
            ORDER BY cl.date DESC
        """,
            (slot_id,),
        ).fetchall()
    else:
        records = conn.execute("""
            SELECT cl.*, u.full_name as cancelled_by_name,
                   ts.subject_id
            FROM cancelled_lectures cl
            LEFT JOIN users u ON cl.cancelled_by = u.id
            LEFT JOIN timetable_slots ts ON cl.slot_id = ts.id
            ORDER BY cl.date DESC
        """).fetchall()
    conn.close()
    return [dict(r) for r in records]


@router.delete("/lectures/cancelled/{cancel_id}")
def restore_lecture(
    cancel_id: str, current_user: dict = Depends(require_role("faculty", "admin"))
):
    conn = get_db()
    conn.execute("DELETE FROM cancelled_lectures WHERE id = %s", (cancel_id,))
    conn.commit()
    conn.close()
    return {"message": "Cancellation removed"}
