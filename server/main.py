from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext
import sqlite3
import uuid
import hmac
import hashlib
import time
import json

# ─────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────
SECRET_KEY = os.getenv("SECRET_KEY", "fallback_dev_key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours
BLE_TOKEN_WINDOW = 300  # 5 minutes

app = FastAPI(title="Attendance System API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

# ─────────────────────────────────────────
# DATABASE SETUP
# ─────────────────────────────────────────
def get_db():
    conn = sqlite3.connect("attendance.db", check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    c = conn.cursor()

    c.execute("""
        CREATE TABLE IF NOT EXISTS departments (
            id TEXT PRIMARY KEY,
            name TEXT UNIQUE NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS subjects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT UNIQUE NOT NULL,
            department_id TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (department_id) REFERENCES departments(id)
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            full_name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL,
            department_id TEXT,
            enrollment_number TEXT,
            employee_id TEXT,
            status TEXT DEFAULT 'pending',
            face_enrolled INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (department_id) REFERENCES departments(id)
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS timetable_slots (
            id TEXT PRIMARY KEY,
            subject_id TEXT NOT NULL,
            faculty_id TEXT NOT NULL,
            department_id TEXT NOT NULL,
            section TEXT NOT NULL,
            day_of_week TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            room TEXT NOT NULL,
            is_active INTEGER DEFAULT 1,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (subject_id) REFERENCES subjects(id),
            FOREIGN KEY (faculty_id) REFERENCES users(id)
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS attendance_sessions (
            id TEXT PRIMARY KEY,
            slot_id TEXT NOT NULL,
            faculty_id TEXT NOT NULL,
            token TEXT NOT NULL,
            status TEXT DEFAULT 'live',
            started_at TEXT DEFAULT CURRENT_TIMESTAMP,
            ended_at TEXT,
            FOREIGN KEY (slot_id) REFERENCES timetable_slots(id)
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS ble_events (
            id TEXT PRIMARY KEY,
            student_id TEXT NOT NULL,
            student_name TEXT NOT NULL,
            token TEXT NOT NULL,
            rssi INTEGER,
            session_id TEXT,
            timestamp TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS attendance_records (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            student_id TEXT NOT NULL,
            status TEXT DEFAULT 'present',
            marked_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (session_id) REFERENCES attendance_sessions(id),
            FOREIGN KEY (student_id) REFERENCES users(id)
        )
    """)

    # Seed default admin if not exists
    existing = c.execute("SELECT id FROM users WHERE role='admin'").fetchone()
    if not existing:
        admin_id = str(uuid.uuid4())
        c.execute("""
            INSERT INTO users (id, full_name, email, password_hash, role, status)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            admin_id,
            "System Admin",
            "admin@college.edu",
            pwd_context.hash("admin123"),
            "admin",
            "approved"
        ))
        print("✅ Default admin created: admin@college.edu / admin123")

    conn.commit()
    conn.close()

init_db()

# ─────────────────────────────────────────
# PYDANTIC MODELS
# ─────────────────────────────────────────
class RegisterRequest(BaseModel):
    full_name: str
    email: str
    password: str
    role: str  # admin, faculty, student, hod, principal
    department_id: Optional[str] = None
    enrollment_number: Optional[str] = None
    employee_id: Optional[str] = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user: dict

class ApproveRequest(BaseModel):
    user_id: str
    action: str  # approve or reject

class DepartmentCreate(BaseModel):
    name: str

class SubjectCreate(BaseModel):
    name: str
    code: str
    department_id: str

class SlotCreate(BaseModel):
    subject_id: str
    faculty_id: str
    department_id: str
    section: str
    day_of_week: str
    start_time: str
    end_time: str
    room: str

class BLEDetectedRequest(BaseModel):
    token: str
    rssi: int
    timestamp: str

class StartAttendanceRequest(BaseModel):
    slot_id: str

# ─────────────────────────────────────────
# AUTH HELPERS
# ─────────────────────────────────────────
def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def create_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()
    if user is None:
        raise credentials_exception
    return dict(user)

def require_role(*roles):
    def checker(current_user: dict = Depends(get_current_user)):
        if current_user["role"] not in roles:
            raise HTTPException(status_code=403, detail=f"Access denied. Required roles: {roles}")
        if current_user["status"] != "approved":
            raise HTTPException(status_code=403, detail="Account pending approval")
        return current_user
    return checker

# ─────────────────────────────────────────
# BLE TOKEN HELPERS
# ─────────────────────────────────────────
def generate_ble_token(slot_id: str) -> str:
    window = int(time.time() // BLE_TOKEN_WINDOW)
    message = f"{slot_id}:{window}".encode()
    return "ATT:" + hmac.new(SECRET_KEY.encode(), message, hashlib.sha256).hexdigest()[:12]

def validate_ble_token(token: str, slot_id: str) -> bool:
    # Check current window and previous window (grace period)
    for offset in [0, -1]:
        window = int(time.time() // BLE_TOKEN_WINDOW) + offset
        message = f"{slot_id}:{window}".encode()
        expected = "ATT:" + hmac.new(SECRET_KEY.encode(), message, hashlib.sha256).hexdigest()[:12]
        if token == expected:
            return True
    return False

# ─────────────────────────────────────────
# AUTH ROUTES
# ─────────────────────────────────────────
@app.post("/auth/register")
def register(req: RegisterRequest):
    conn = get_db()
    existing = conn.execute("SELECT id FROM users WHERE email = ?", (req.email,)).fetchone()
    if existing:
        conn.close()
        raise HTTPException(status_code=400, detail="Email already registered")

    valid_roles = ["admin", "faculty", "student", "hod", "principal"]
    if req.role not in valid_roles:
        conn.close()
        raise HTTPException(status_code=400, detail=f"Invalid role. Must be one of: {valid_roles}")

    user_id = str(uuid.uuid4())
    # Admin registrations still need approval from existing admin
    initial_status = "pending"

    conn.execute("""
        INSERT INTO users (id, full_name, email, password_hash, role, department_id,
                           enrollment_number, employee_id, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        user_id, req.full_name, req.email,
        hash_password(req.password), req.role,
        req.department_id, req.enrollment_number,
        req.employee_id, initial_status
    ))
    conn.commit()
    conn.close()

    return {
        "message": "Registration successful. Waiting for admin approval.",
        "user_id": user_id,
        "status": "pending"
    }

@app.post("/auth/login", response_model=TokenResponse)
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE email = ?", (form_data.username,)).fetchone()
    conn.close()

    if not user or not verify_password(form_data.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    user_dict = dict(user)
    token = create_token({"sub": user_dict["id"], "role": user_dict["role"]})

    # Remove sensitive data
    user_dict.pop("password_hash", None)

    return {
        "access_token": token,
        "token_type": "bearer",
        "user": user_dict
    }

@app.get("/auth/me")
def get_me(current_user: dict = Depends(get_current_user)):
    current_user.pop("password_hash", None)
    return current_user

# ─────────────────────────────────────────
# ADMIN ROUTES
# ─────────────────────────────────────────
@app.get("/admin/pending-users")
def get_pending_users(current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    users = conn.execute("""
        SELECT u.id, u.full_name, u.email, u.role, u.status,
               u.enrollment_number, u.employee_id, u.created_at,
               d.name as department_name
        FROM users u
        LEFT JOIN departments d ON u.department_id = d.id
        WHERE u.status = 'pending'
        ORDER BY u.created_at DESC
    """).fetchall()
    conn.close()
    return [dict(u) for u in users]

@app.get("/admin/all-users")
def get_all_users(current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    users = conn.execute("""
        SELECT u.id, u.full_name, u.email, u.role, u.status,
               u.enrollment_number, u.employee_id, u.created_at, u.face_enrolled,
               d.name as department_name
        FROM users u
        LEFT JOIN departments d ON u.department_id = d.id
        ORDER BY u.created_at DESC
    """).fetchall()
    conn.close()
    return [dict(u) for u in users]

@app.post("/admin/approve-user")
def approve_user(req: ApproveRequest, current_user: dict = Depends(require_role("admin"))):
    if req.action not in ["approve", "reject"]:
        raise HTTPException(status_code=400, detail="Action must be approve or reject")

    new_status = "approved" if req.action == "approve" else "rejected"
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE id = ?", (req.user_id,)).fetchone()
    if not user:
        conn.close()
        raise HTTPException(status_code=404, detail="User not found")

    conn.execute("UPDATE users SET status = ? WHERE id = ?", (new_status, req.user_id))
    conn.commit()
    conn.close()
    return {"message": f"User {req.action}d successfully", "status": new_status}

# ─────────────────────────────────────────
# DEPARTMENT ROUTES
# ─────────────────────────────────────────
@app.get("/departments")
def get_departments():
    conn = get_db()
    departments = conn.execute("SELECT * FROM departments ORDER BY name").fetchall()
    conn.close()
    return [dict(d) for d in departments]

@app.post("/departments")
def create_department(req: DepartmentCreate, current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    dept_id = str(uuid.uuid4())
    try:
        conn.execute("INSERT INTO departments (id, name) VALUES (?, ?)", (dept_id, req.name))
        conn.commit()
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(status_code=400, detail="Department already exists")
    conn.close()
    return {"id": dept_id, "name": req.name, "message": "Department created"}

@app.delete("/departments/{dept_id}")
def delete_department(dept_id: str, current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    conn.execute("DELETE FROM departments WHERE id = ?", (dept_id,))
    conn.commit()
    conn.close()
    return {"message": "Department deleted"}

# ─────────────────────────────────────────
# SUBJECT ROUTES
# ─────────────────────────────────────────
@app.get("/subjects")
def get_subjects(current_user: dict = Depends(get_current_user)):
    conn = get_db()
    subjects = conn.execute("""
        SELECT s.*, d.name as department_name
        FROM subjects s
        LEFT JOIN departments d ON s.department_id = d.id
        ORDER BY s.name
    """).fetchall()
    conn.close()
    return [dict(s) for s in subjects]

@app.post("/subjects")
def create_subject(req: SubjectCreate, current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    subj_id = str(uuid.uuid4())
    try:
        conn.execute("""
            INSERT INTO subjects (id, name, code, department_id)
            VALUES (?, ?, ?, ?)
        """, (subj_id, req.name, req.code, req.department_id))
        conn.commit()
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(status_code=400, detail="Subject code already exists")
    conn.close()
    return {"id": subj_id, "message": "Subject created"}

@app.delete("/subjects/{subj_id}")
def delete_subject(subj_id: str, current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    conn.execute("DELETE FROM subjects WHERE id = ?", (subj_id,))
    conn.commit()
    conn.close()
    return {"message": "Subject deleted"}

# ─────────────────────────────────────────
# TIMETABLE ROUTES
# ─────────────────────────────────────────
@app.get("/timetable")
def get_timetable(current_user: dict = Depends(get_current_user)):
    conn = get_db()
    role = current_user["role"]
    user_id = current_user["id"]

    if role == "faculty":
        slots = conn.execute("""
            SELECT ts.*, s.name as subject_name, s.code as subject_code,
                   u.full_name as faculty_name, d.name as department_name
            FROM timetable_slots ts
            LEFT JOIN subjects s ON ts.subject_id = s.id
            LEFT JOIN users u ON ts.faculty_id = u.id
            LEFT JOIN departments d ON ts.department_id = d.id
            WHERE ts.faculty_id = ? AND ts.is_active = 1
            ORDER BY ts.day_of_week, ts.start_time
        """, (user_id,)).fetchall()
    elif role == "student":
        dept_id = current_user.get("department_id")
        slots = conn.execute("""
            SELECT ts.*, s.name as subject_name, s.code as subject_code,
                   u.full_name as faculty_name, d.name as department_name
            FROM timetable_slots ts
            LEFT JOIN subjects s ON ts.subject_id = s.id
            LEFT JOIN users u ON ts.faculty_id = u.id
            LEFT JOIN departments d ON ts.department_id = d.id
            WHERE ts.department_id = ? AND ts.is_active = 1
            ORDER BY ts.day_of_week, ts.start_time
        """, (dept_id,)).fetchall()
    else:
        slots = conn.execute("""
            SELECT ts.*, s.name as subject_name, s.code as subject_code,
                   u.full_name as faculty_name, d.name as department_name
            FROM timetable_slots ts
            LEFT JOIN subjects s ON ts.subject_id = s.id
            LEFT JOIN users u ON ts.faculty_id = u.id
            LEFT JOIN departments d ON ts.department_id = d.id
            WHERE ts.is_active = 1
            ORDER BY ts.day_of_week, ts.start_time
        """).fetchall()

    conn.close()
    return [dict(s) for s in slots]

@app.post("/timetable")
def create_slot(req: SlotCreate, current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    slot_id = str(uuid.uuid4())
    conn.execute("""
        INSERT INTO timetable_slots
        (id, subject_id, faculty_id, department_id, section, day_of_week, start_time, end_time, room)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (slot_id, req.subject_id, req.faculty_id, req.department_id,
          req.section, req.day_of_week, req.start_time, req.end_time, req.room))
    conn.commit()
    conn.close()
    return {"id": slot_id, "message": "Timetable slot created"}

@app.delete("/timetable/{slot_id}")
def delete_slot(slot_id: str, current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    conn.execute("UPDATE timetable_slots SET is_active = 0 WHERE id = ?", (slot_id,))
    conn.commit()
    conn.close()
    return {"message": "Slot deactivated"}

# ─────────────────────────────────────────
# ATTENDANCE / BLE ROUTES
# ─────────────────────────────────────────
@app.post("/attendance/start")
def start_attendance(req: StartAttendanceRequest, current_user: dict = Depends(require_role("faculty"))):
    conn = get_db()

    # Verify this slot belongs to this faculty
    slot = conn.execute("""
        SELECT ts.*, s.name as subject_name
        FROM timetable_slots ts
        LEFT JOIN subjects s ON ts.subject_id = s.id
        WHERE ts.id = ? AND ts.faculty_id = ?
    """, (req.slot_id, current_user["id"])).fetchone()

    if not slot:
        conn.close()
        raise HTTPException(status_code=403, detail="Slot not found or not assigned to you")

    # Close any existing live session for this slot
    conn.execute("""
        UPDATE attendance_sessions SET status = 'closed', ended_at = ?
        WHERE slot_id = ? AND status = 'live'
    """, (datetime.utcnow().isoformat(), req.slot_id))

    # Generate new token
    token = generate_ble_token(req.slot_id)
    session_id = str(uuid.uuid4())

    conn.execute("""
        INSERT INTO attendance_sessions (id, slot_id, faculty_id, token, status)
        VALUES (?, ?, ?, ?, 'live')
    """, (session_id, req.slot_id, current_user["id"], token))

    conn.commit()
    conn.close()

    return {
        "session_id": session_id,
        "token": token,
        "slot_id": req.slot_id,
        "subject_name": slot["subject_name"],
        "message": "Attendance session started. Broadcasting BLE token."
    }

@app.post("/attendance/stop/{session_id}")
def stop_attendance(session_id: str, current_user: dict = Depends(require_role("faculty"))):
    conn = get_db()
    conn.execute("""
        UPDATE attendance_sessions SET status = 'closed', ended_at = ?
        WHERE id = ? AND faculty_id = ?
    """, (datetime.utcnow().isoformat(), session_id, current_user["id"]))
    conn.commit()
    conn.close()
    return {"message": "Attendance session closed"}

@app.post("/ble/detected")
def ble_detected(req: BLEDetectedRequest, current_user: dict = Depends(get_current_user)):
    if current_user["status"] != "approved":
        raise HTTPException(status_code=403, detail="Account not approved")

    conn = get_db()

    # Find active session with this token
    session = conn.execute("""
        SELECT * FROM attendance_sessions
        WHERE token = ? AND status = 'live'
    """, (req.token,)).fetchone()

    session_id = session["id"] if session else None
    slot_id = session["slot_id"] if session else None

    # Validate token if session found
    token_valid = False
    if slot_id:
        token_valid = validate_ble_token(req.token, slot_id)

    event_id = str(uuid.uuid4())
    conn.execute("""
        INSERT INTO ble_events (id, student_id, student_name, token, rssi, session_id, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (
        event_id,
        current_user["id"],
        current_user["full_name"],
        req.token,
        req.rssi,
        session_id,
        req.timestamp
    ))

    conn.commit()
    conn.close()

    return {
        "status": "received",
        "token_valid": token_valid,
        "session_found": session_id is not None,
        "message": "BLE signal logged" + (" — valid session found" if session_id else " — no matching session")
    }

@app.get("/ble/events")
def get_ble_events(current_user: dict = Depends(require_role("admin", "faculty"))):
    conn = get_db()
    events = conn.execute("""
        SELECT * FROM ble_events ORDER BY timestamp DESC LIMIT 100
    """).fetchall()
    conn.close()
    return [dict(e) for e in events]

# ─────────────────────────────────────────
# HOD ROUTES
# ─────────────────────────────────────────
@app.get("/hod/department-users")
def hod_get_users(current_user: dict = Depends(require_role("hod"))):
    dept_id = current_user.get("department_id")
    if not dept_id:
        raise HTTPException(status_code=400, detail="HOD not assigned to a department")
    conn = get_db()
    users = conn.execute("""
        SELECT u.id, u.full_name, u.email, u.role, u.status, u.created_at
        FROM users u
        WHERE u.department_id = ?
        ORDER BY u.role, u.full_name
    """, (dept_id,)).fetchall()
    conn.close()
    return [dict(u) for u in users]

@app.get("/hod/pending-users")
def hod_pending_users(current_user: dict = Depends(require_role("hod"))):
    dept_id = current_user.get("department_id")
    conn = get_db()
    users = conn.execute("""
        SELECT u.id, u.full_name, u.email, u.role, u.status, u.created_at
        FROM users u
        WHERE u.department_id = ? AND u.status = 'pending'
    """, (dept_id,)).fetchall()
    conn.close()
    return [dict(u) for u in users]

@app.post("/hod/approve-user")
def hod_approve_user(req: ApproveRequest, current_user: dict = Depends(require_role("hod"))):
    dept_id = current_user.get("department_id")
    conn = get_db()
    user = conn.execute("""
        SELECT * FROM users WHERE id = ? AND department_id = ?
    """, (req.user_id, dept_id)).fetchone()
    if not user:
        conn.close()
        raise HTTPException(status_code=404, detail="User not found in your department")
    new_status = "approved" if req.action == "approve" else "rejected"
    conn.execute("UPDATE users SET status = ? WHERE id = ?", (new_status, req.user_id))
    conn.commit()
    conn.close()
    return {"message": f"User {req.action}d successfully"}

# ─────────────────────────────────────────
# ATTENDANCE REPORTS
# ─────────────────────────────────────────
@app.get("/reports/attendance")
def get_attendance_report(current_user: dict = Depends(get_current_user)):
    conn = get_db()
    role = current_user["role"]

    if role == "principal":
        records = conn.execute("""
            SELECT ar.*, u.full_name as student_name, u.enrollment_number,
                   s.name as subject_name, d.name as department_name,
                   ases.started_at
            FROM attendance_records ar
            LEFT JOIN users u ON ar.student_id = u.id
            LEFT JOIN attendance_sessions ases ON ar.session_id = ases.id
            LEFT JOIN timetable_slots ts ON ases.slot_id = ts.id
            LEFT JOIN subjects s ON ts.subject_id = s.id
            LEFT JOIN departments d ON ts.department_id = d.id
            ORDER BY ar.marked_at DESC
            LIMIT 200
        """).fetchall()
    elif role in ["admin", "hod"]:
        dept_id = current_user.get("department_id") if role == "hod" else None
        query = """
            SELECT ar.*, u.full_name as student_name, u.enrollment_number,
                   s.name as subject_name, d.name as department_name,
                   ases.started_at
            FROM attendance_records ar
            LEFT JOIN users u ON ar.student_id = u.id
            LEFT JOIN attendance_sessions ases ON ar.session_id = ases.id
            LEFT JOIN timetable_slots ts ON ases.slot_id = ts.id
            LEFT JOIN subjects s ON ts.subject_id = s.id
            LEFT JOIN departments d ON ts.department_id = d.id
        """
        if dept_id:
            query += f" WHERE ts.department_id = '{dept_id}'"
        query += " ORDER BY ar.marked_at DESC LIMIT 200"
        records = conn.execute(query).fetchall()
    elif role == "faculty":
        records = conn.execute("""
            SELECT ar.*, u.full_name as student_name, u.enrollment_number,
                   s.name as subject_name, ases.started_at
            FROM attendance_records ar
            LEFT JOIN users u ON ar.student_id = u.id
            LEFT JOIN attendance_sessions ases ON ar.session_id = ases.id
            LEFT JOIN timetable_slots ts ON ases.slot_id = ts.id
            LEFT JOIN subjects s ON ts.subject_id = s.id
            WHERE ases.faculty_id = ?
            ORDER BY ar.marked_at DESC LIMIT 100
        """, (current_user["id"],)).fetchall()
    else:  # student
        records = conn.execute("""
            SELECT ar.*, s.name as subject_name, ases.started_at
            FROM attendance_records ar
            LEFT JOIN attendance_sessions ases ON ar.session_id = ases.id
            LEFT JOIN timetable_slots ts ON ases.slot_id = ts.id
            LEFT JOIN subjects s ON ts.subject_id = s.id
            WHERE ar.student_id = ?
            ORDER BY ar.marked_at DESC
        """, (current_user["id"],)).fetchall()

    conn.close()
    return [dict(r) for r in records]

@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}
