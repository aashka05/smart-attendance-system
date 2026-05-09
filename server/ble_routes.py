# ble_routes.py
# BLE events and attendance session routes

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from datetime import datetime
import uuid

from database import (
    get_db,
    get_current_user,
    require_role,
    generate_ble_token,
    validate_ble_token,
)

router = APIRouter()


# ─────────────────────────────────────────
# PYDANTIC MODELS
# ─────────────────────────────────────────
class StartAttendanceRequest(BaseModel):
    slot_id: str


class BLEDetectedRequest(BaseModel):
    token: str
    rssi: int
    timestamp: str


# ─────────────────────────────────────────
# ATTENDANCE SESSION ROUTES
# ─────────────────────────────────────────
@router.post("/attendance/start")
def start_attendance(
    req: StartAttendanceRequest, current_user: dict = Depends(require_role("faculty"))
):
    conn = get_db()

    slot = conn.execute(
        """
        SELECT ts.*, s.name as subject_name
        FROM timetable_slots ts
        LEFT JOIN subjects s ON ts.subject_id = s.id
        WHERE ts.id = %s AND ts.faculty_id = %s
    """,
        (req.slot_id, current_user["id"]),
    ).fetchone()

    if not slot:
        conn.close()
        raise HTTPException(
            status_code=403, detail="Slot not found or not assigned to you"
        )

    # Close any existing live session for this slot
    conn.execute(
        """
        UPDATE attendance_sessions SET status = 'closed', ended_at = %s
        WHERE slot_id = %s AND status = 'live'
    """,
        (datetime.utcnow().isoformat(), req.slot_id),
    )

    token = generate_ble_token(req.slot_id)
    session_id = str(uuid.uuid4())

    conn.execute(
        """
        INSERT INTO attendance_sessions (id, slot_id, faculty_id, token, status)
        VALUES (%s, %s, %s, %s, 'live')
    """,
        (session_id, req.slot_id, current_user["id"], token),
    )

    conn.commit()
    conn.close()

    return {
        "session_id": session_id,
        "token": token,
        "slot_id": req.slot_id,
        "subject_name": slot["subject_name"],
        "message": "Attendance session started. Broadcasting BLE token.",
    }


@router.post("/attendance/stop/{session_id}")
def stop_attendance(
    session_id: str, current_user: dict = Depends(require_role("faculty"))
):
    conn = get_db()
    conn.execute(
        """
        UPDATE attendance_sessions SET status = 'closed', ended_at = %s
        WHERE id = %s AND faculty_id = %s
    """,
        (datetime.utcnow().isoformat(), session_id, current_user["id"]),
    )
    conn.commit()
    conn.close()
    return {"message": "Attendance session closed"}


@router.delete("/attendance/session/{session_id}")
def delete_session(
    session_id: str, current_user: dict = Depends(require_role("faculty"))
):
    conn = get_db()
    cursor = conn.cursor()

    try:
        # Check if session exists and belongs to this faculty
        cursor.execute(
            "SELECT id FROM attendance_sessions WHERE id = %s AND faculty_id = %s",
            (session_id, current_user["id"]),
        )
        session = cursor.fetchone()

        if not session:
            conn.close()
            raise HTTPException(
                status_code=403, detail="Session not found or not assigned to you"
            )

        # 1. Delete liveness challenges
        cursor.execute(
            "DELETE FROM liveness_challenges WHERE session_id = %s", (session_id,)
        )

        # 2. Delete BLE events
        cursor.execute("DELETE FROM ble_events WHERE session_id = %s", (session_id,))

        # 3. Delete attendance records
        cursor.execute(
            "DELETE FROM attendance_records WHERE session_id = %s", (session_id,)
        )

        # 4. Delete session itself
        cursor.execute("DELETE FROM attendance_sessions WHERE id = %s", (session_id,))

        conn.commit()
        return {"message": "Session and all related records deleted successfully"}

    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to delete session: {str(e)}")
    finally:
        conn.close()


@router.get("/attendance/live")
def get_live_sessions(current_user: dict = Depends(get_current_user)):
    conn = get_db()
    sessions = conn.execute("""
        SELECT ases.id, ases.slot_id, ases.token, ases.started_at,
               s.name as subject_name, s.code as subject_code,
               ts.department_id, ts.section, ts.room,
               u.full_name as faculty_name
        FROM attendance_sessions ases
        LEFT JOIN timetable_slots ts ON ases.slot_id = ts.id
        LEFT JOIN subjects s ON ts.subject_id = s.id
        LEFT JOIN users u ON ases.faculty_id = u.id
        WHERE ases.status = 'live'
    """).fetchall()
    conn.close()
    return [dict(s) for s in sessions]


# ─────────────────────────────────────────
# BLE EVENT ROUTES
# ─────────────────────────────────────────
@router.post("/ble/detected")
def ble_detected(
    req: BLEDetectedRequest, current_user: dict = Depends(get_current_user)
):
    if current_user["status"] != "approved":
        raise HTTPException(status_code=403, detail="Account not approved")

    conn = get_db()

    session = conn.execute(
        """
        SELECT * FROM attendance_sessions
        WHERE token = %s AND status = 'live'
    """,
        (req.token,),
    ).fetchone()

    session_id = session["id"] if session else None
    slot_id = session["slot_id"] if session else None

    token_valid = False
    if slot_id:
        token_valid = validate_ble_token(req.token, slot_id)

    event_id = str(uuid.uuid4())
    conn.execute(
        """
        INSERT INTO ble_events (id, student_id, student_name, token, rssi, session_id, timestamp)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """,
        (
            event_id,
            current_user["id"],
            current_user["full_name"],
            req.token,
            req.rssi,
            session_id,
            req.timestamp,
        ),
    )

    conn.commit()
    conn.close()

    return {
        "status": "received",
        "token_valid": token_valid,
        "session_id": session_id,
        "session_found": session_id is not None,
        "message": "BLE signal logged"
        + (" — valid session found" if session_id else " — no matching session"),
    }


@router.get("/ble/events")
def get_ble_events(current_user: dict = Depends(require_role("admin", "faculty"))):
    conn = get_db()
    events = conn.execute("""
        SELECT * FROM ble_events ORDER BY timestamp DESC LIMIT 100
    """).fetchall()
    conn.close()
    return [dict(e) for e in events]
