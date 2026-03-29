# face_routes.py
# Face enrollment and recognition routes

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import cv2
import numpy as np
import base64
import random
import json
import uuid

from database import get_db, get_current_user, require_role, validate_ble_token

router = APIRouter()

# ─────────────────────────────────────────
# INSIGHTFACE SETUP
# ─────────────────────────────────────────
face_app_instance = None


def get_face_app():
    global face_app_instance
    if face_app_instance is None:
        from insightface.app import FaceAnalysis

        face_app_instance = FaceAnalysis(allowed_modules=["detection", "recognition"])
        face_app_instance.prepare(ctx_id=0, det_size=(640, 640))
    return face_app_instance


LIVENESS_CHALLENGES = ["blink", "turn_head", "smile"]


# ─────────────────────────────────────────
# DB INIT
# ─────────────────────────────────────────
def init_face_db():
    conn = get_db()
    c = conn.cursor()

    c.execute("""
        CREATE TABLE IF NOT EXISTS face_enrollments (
            id TEXT PRIMARY KEY,
            student_id TEXT UNIQUE NOT NULL,
            face_embedding TEXT,
            face_image_b64 TEXT,
            id_card_image_b64 TEXT,
            status TEXT DEFAULT 'pending',
            submitted_at TIMESTAMP DEFAULT NOW(),
            reviewed_at TEXT,
            reviewed_by TEXT,
            rejection_reason TEXT,
            FOREIGN KEY (student_id) REFERENCES users(id)
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS liveness_challenges (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            student_id TEXT NOT NULL,
            challenge TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT NOW(),
            used BOOLEAN DEFAULT FALSE
        )
    """)

    conn.commit()
    conn.close()


init_face_db()


# ─────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────
def decode_image(b64_string: str) -> np.ndarray:
    if "," in b64_string:
        b64_string = b64_string.split(",")[1]
    img_bytes = base64.b64decode(b64_string)
    img_array = np.frombuffer(img_bytes, dtype=np.uint8)
    return cv2.imdecode(img_array, cv2.IMREAD_COLOR)


def get_embedding(b64_image: str):
    face_app = get_face_app()
    img = decode_image(b64_image)
    if img is None:
        return None, "Could not decode image"
    faces = face_app.get(img)
    if len(faces) == 0:
        return None, "No face detected"
    if len(faces) > 1:
        return None, "Multiple faces detected"
    return faces[0].embedding, None


def cosine_similarity(a, b) -> float:
    a = np.array(a)
    b = np.array(b)
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))


# ─────────────────────────────────────────
# PYDANTIC MODELS
# ─────────────────────────────────────────
class FaceEnrollmentSubmit(BaseModel):
    face_image_b64: str
    id_card_image_b64: str


class EnrollmentReview(BaseModel):
    enrollment_id: str
    action: str  # approve or reject
    rejection_reason: Optional[str] = None


class FaceVerifyRequest(BaseModel):
    session_id: str
    token: str
    face_image_b64: str
    challenge_id: str


class ChallengeRequest(BaseModel):
    session_id: str


# ─────────────────────────────────────────
# ENROLLMENT ROUTES
# ─────────────────────────────────────────
@router.post("/enrollment/submit")
async def submit_enrollment(
    req: FaceEnrollmentSubmit, current_user: dict = Depends(get_current_user)
):
    if current_user["role"] != "student":
        raise HTTPException(status_code=403, detail="Only students can enroll")
    if current_user["status"] != "approved":
        raise HTTPException(status_code=403, detail="Account not approved")

    embedding, error = get_embedding(req.face_image_b64)
    if error:
        raise HTTPException(status_code=400, detail=f"Face issue: {error}")

    conn = get_db()
    existing = conn.execute(
        "SELECT id, status FROM face_enrollments WHERE student_id = %s",
        (current_user["id"],),
    ).fetchone()

    enrollment_id = str(uuid.uuid4())
    embedding_json = json.dumps(embedding.tolist())

    if existing:
        conn.execute(
            """
            UPDATE face_enrollments
            SET face_image_b64 = %s, id_card_image_b64 = %s,
                face_embedding = %s, status = 'pending',
                submitted_at = %s, reviewed_at = NULL, rejection_reason = NULL
            WHERE student_id = %s
        """,
            (
                req.face_image_b64,
                req.id_card_image_b64,
                embedding_json,
                datetime.utcnow().isoformat(),
                current_user["id"],
            ),
        )
        enrollment_id = existing["id"]
    else:
        conn.execute(
            """
            INSERT INTO face_enrollments
            (id, student_id, face_image_b64, id_card_image_b64, face_embedding, status)
            VALUES (%s, %s, %s, %s, %s, 'pending')
        """,
            (
                enrollment_id,
                current_user["id"],
                req.face_image_b64,
                req.id_card_image_b64,
                embedding_json,
            ),
        )

    # 0=not enrolled, 1=enrolled, 2=pending review
    conn.execute(
        "UPDATE users SET face_enrolled = 2 WHERE id = %s", (current_user["id"],)
    )

    conn.commit()
    conn.close()

    return {
        "message": "Enrollment submitted. Waiting for admin approval.",
        "enrollment_id": enrollment_id,
    }


@router.get("/enrollment/status")
async def get_enrollment_status(current_user: dict = Depends(get_current_user)):
    conn = get_db()
    enrollment = conn.execute(
        """
        SELECT id, status, submitted_at, reviewed_at, rejection_reason
        FROM face_enrollments WHERE student_id = %s
    """,
        (current_user["id"],),
    ).fetchone()
    conn.close()

    if not enrollment:
        return {"status": "not_submitted"}
    return dict(enrollment)


@router.get("/enrollment/pending")
async def get_pending_enrollments(current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    enrollments = conn.execute("""
        SELECT fe.id, fe.student_id, fe.face_image_b64, fe.id_card_image_b64,
               fe.status, fe.submitted_at, fe.rejection_reason,
               u.full_name, u.email, u.enrollment_number,
               d.name as department_name
        FROM face_enrollments fe
        LEFT JOIN users u ON fe.student_id = u.id
        LEFT JOIN departments d ON u.department_id = d.id
        WHERE fe.status = 'pending'
        ORDER BY fe.submitted_at DESC
    """).fetchall()
    conn.close()
    return [dict(e) for e in enrollments]


@router.get("/enrollment/all")
async def get_all_enrollments(current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    enrollments = conn.execute("""
        SELECT fe.id, fe.student_id, fe.status, fe.submitted_at, fe.reviewed_at,
               fe.rejection_reason, u.full_name, u.email, u.enrollment_number,
               d.name as department_name
        FROM face_enrollments fe
        LEFT JOIN users u ON fe.student_id = u.id
        LEFT JOIN departments d ON u.department_id = d.id
        ORDER BY fe.submitted_at DESC
    """).fetchall()
    conn.close()
    return [dict(e) for e in enrollments]


@router.post("/enrollment/review")
async def review_enrollment(
    req: EnrollmentReview, current_user: dict = Depends(require_role("admin"))
):
    if req.action not in ["approve", "reject"]:
        raise HTTPException(status_code=400, detail="Action must be approve or reject")

    conn = get_db()
    enrollment = conn.execute(
        "SELECT * FROM face_enrollments WHERE id = %s", (req.enrollment_id,)
    ).fetchone()

    if not enrollment:
        conn.close()
        raise HTTPException(status_code=404, detail="Enrollment not found")

    new_status = "approved" if req.action == "approve" else "rejected"

    conn.execute(
        """
        UPDATE face_enrollments
        SET status = %s, reviewed_at = %s, reviewed_by = %s, rejection_reason = %s
        WHERE id = %s
    """,
        (
            new_status,
            datetime.utcnow().isoformat(),
            current_user["id"],
            req.rejection_reason,
            req.enrollment_id,
        ),
    )

    face_enrolled_val = 1 if req.action == "approve" else 0
    conn.execute(
        "UPDATE users SET face_enrolled = %s WHERE id = %s",
        (face_enrolled_val, enrollment["student_id"]),
    )

    conn.commit()
    conn.close()
    return {"message": f"Enrollment {req.action}d successfully"}


@router.post("/enrollment/check-duplicate")
async def check_duplicate_face(
    req: FaceEnrollmentSubmit, current_user: dict = Depends(get_current_user)
):
    embedding, error = get_embedding(req.face_image_b64)
    if error:
        raise HTTPException(status_code=400, detail=f"Face issue: {error}")

    conn = get_db()
    all_enrollments = conn.execute(
        """
        SELECT fe.student_id, fe.face_embedding, u.full_name
        FROM face_enrollments fe
        LEFT JOIN users u ON fe.student_id = u.id
        WHERE fe.status = 'approved' AND fe.student_id != %s
    """,
        (current_user["id"],),
    ).fetchall()
    conn.close()

    for enrolled in all_enrollments:
        stored = json.loads(enrolled["face_embedding"])
        sim = cosine_similarity(embedding, stored)
        if sim > 0.6:
            raise HTTPException(
                status_code=400, detail="Face already registered to another account"
            )

    return {"message": "No duplicate found", "can_proceed": True}


# ─────────────────────────────────────────
# LIVENESS CHALLENGE
# ─────────────────────────────────────────
@router.post("/attendance/challenge")
async def get_challenge(
    req: ChallengeRequest, current_user: dict = Depends(get_current_user)
):
    if current_user["status"] != "approved":
        raise HTTPException(status_code=403, detail="Account not approved")

    if current_user.get("face_enrolled", 0) != 1:
        raise HTTPException(
            status_code=403,
            detail="Face not enrolled. Please complete face enrollment first.",
        )

    conn = get_db()
    session = conn.execute(
        """
        SELECT * FROM attendance_sessions
        WHERE id = %s AND status = 'live'
    """,
        (req.session_id,),
    ).fetchone()

    if not session:
        conn.close()
        raise HTTPException(status_code=404, detail="No active session found")

    already_marked = conn.execute(
        """
        SELECT id FROM attendance_records
        WHERE session_id = %s AND student_id = %s
    """,
        (req.session_id, current_user["id"]),
    ).fetchone()

    if already_marked:
        conn.close()
        raise HTTPException(status_code=400, detail="Attendance already marked")

    challenge = random.choice(LIVENESS_CHALLENGES)
    challenge_id = str(uuid.uuid4())

    conn.execute(
        """
        INSERT INTO liveness_challenges (id, session_id, student_id, challenge)
        VALUES (%s, %s, %s, %s)
    """,
        (challenge_id, req.session_id, current_user["id"], challenge),
    )

    conn.commit()
    conn.close()

    instructions = {
        "blink": "Please blink twice",
        "turn_head": "Please turn your head left, then right",
        "smile": "Please smile",
    }

    return {
        "challenge_id": challenge_id,
        "challenge": challenge,
        "instruction": instructions[challenge],
        "timeout_seconds": 15,
    }


# ─────────────────────────────────────────
# FACE VERIFICATION
# ─────────────────────────────────────────
@router.post("/attendance/verify-face")
async def verify_face(
    req: FaceVerifyRequest, current_user: dict = Depends(get_current_user)
):
    if current_user["status"] != "approved":
        raise HTTPException(status_code=403, detail="Account not approved")

    conn = get_db()

    # Validate challenge
    challenge = conn.execute(
        """
        SELECT * FROM liveness_challenges
        WHERE id = %s AND student_id = %s AND session_id = %s AND used = FALSE
    """,
        (req.challenge_id, current_user["id"], req.session_id),
    ).fetchone()

    if not challenge:
        conn.close()
        raise HTTPException(status_code=400, detail="Invalid or expired challenge")

    # Check challenge not older than 30 seconds
    created_at = challenge["created_at"]
    if isinstance(created_at, str):
        created_at = datetime.fromisoformat(created_at)
    if (datetime.utcnow() - created_at).seconds > 30:
        conn.close()
        raise HTTPException(status_code=400, detail="Challenge expired")

    # Validate session
    session = conn.execute(
        """
        SELECT * FROM attendance_sessions
        WHERE id = %s AND status = 'live'
    """,
        (req.session_id,),
    ).fetchone()

    if not session:
        conn.close()
        raise HTTPException(status_code=404, detail="Session not found or closed")

    # Validate token
    if not validate_ble_token(req.token, session["slot_id"]):
        conn.close()
        raise HTTPException(status_code=400, detail="Invalid or expired BLE token")

    # Check already marked
    already_marked = conn.execute(
        """
        SELECT id FROM attendance_records
        WHERE session_id = %s AND student_id = %s
    """,
        (req.session_id, current_user["id"]),
    ).fetchone()

    if already_marked:
        conn.close()
        raise HTTPException(status_code=400, detail="Attendance already marked")

    # Get stored embedding
    enrollment = conn.execute(
        """
        SELECT face_embedding FROM face_enrollments
        WHERE student_id = %s AND status = 'approved'
    """,
        (current_user["id"],),
    ).fetchone()

    if not enrollment:
        conn.close()
        raise HTTPException(status_code=400, detail="Face not enrolled")

    # Get live embedding
    live_embedding, error = get_embedding(req.face_image_b64)
    if error:
        conn.close()
        raise HTTPException(status_code=400, detail=f"Face detection failed: {error}")

    # Compare
    stored_embedding = json.loads(enrollment["face_embedding"])
    similarity = cosine_similarity(live_embedding, stored_embedding)

    SIMILARITY_THRESHOLD = 0.4

    if similarity < SIMILARITY_THRESHOLD:
        conn.close()
        raise HTTPException(
            status_code=400, detail=f"Face does not match. Similarity: {similarity:.2f}"
        )

    # Mark challenge used
    conn.execute(
        "UPDATE liveness_challenges SET used = TRUE WHERE id = %s", (req.challenge_id,)
    )

    # Mark attendance
    record_id = str(uuid.uuid4())
    conn.execute(
        """
        INSERT INTO attendance_records (id, session_id, student_id, status, marked_at)
        VALUES (%s, %s, %s, 'present', %s)
    """,
        (record_id, req.session_id, current_user["id"], datetime.utcnow().isoformat()),
    )

    conn.commit()
    conn.close()

    return {
        "status": "present",
        "similarity": round(similarity, 3),
        "message": "Attendance marked successfully!",
    }
