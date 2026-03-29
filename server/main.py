# main.py

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta
from jose import jwt
import psycopg2
import uuid

from database import (
    get_db,
    get_current_user,
    require_role,
    SECRET_KEY,
    ALGORITHM,
    ACCESS_TOKEN_EXPIRE_MINUTES,
    BLE_TOKEN_WINDOW,
    pwd_context,
    oauth2_scheme,
)

# ─────────────────────────────────────────
# APP SETUP
# ─────────────────────────────────────────
app = FastAPI(title="Attendance System API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────
# DATABASE INIT
# ─────────────────────────────────────────
def init_db():
    conn = get_db()
    c = conn.cursor()

    c.execute("""
        CREATE TABLE IF NOT EXISTS departments (
            id TEXT PRIMARY KEY,
            name TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT NOW()
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS subjects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT UNIQUE NOT NULL,
            department_id TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT NOW(),
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
            year INTEGER,
            practical_batch TEXT,
            tutorial_batch TEXT,
            created_at TIMESTAMP DEFAULT NOW(),
            FOREIGN KEY (department_id) REFERENCES departments(id)
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS timetable_slots (
            id TEXT PRIMARY KEY,
            subject_id TEXT NOT NULL,
            faculty_id TEXT NOT NULL,
            department_id TEXT NOT NULL,
            section TEXT,
            division_id TEXT,
            year INTEGER,
            lecture_type TEXT DEFAULT 'lecture',
            batch TEXT,
            day_of_week TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            room TEXT NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT NOW(),
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
            started_at TIMESTAMP DEFAULT NOW(),
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
            timestamp TIMESTAMP DEFAULT NOW()
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS attendance_records (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            student_id TEXT NOT NULL,
            status TEXT DEFAULT 'present',
            marked_at TIMESTAMP DEFAULT NOW(),
            FOREIGN KEY (session_id) REFERENCES attendance_sessions(id),
            FOREIGN KEY (student_id) REFERENCES users(id)
        )
    """)

    # Seed default admin
    existing = conn.execute("SELECT id FROM users WHERE role='admin'").fetchone()
    if not existing:
        admin_id = str(uuid.uuid4())
        conn.execute(
            """
            INSERT INTO users (id, full_name, email, password_hash, role, status)
            VALUES (%s, %s, %s, %s, %s, %s)
        """,
            (
                admin_id,
                "System Admin",
                "admin@college.edu",
                pwd_context.hash("admin123"),
                "admin",
                "approved",
            ),
        )
        print("Default admin created: admin@college.edu / admin123")

    conn.commit()
    conn.close()


init_db()

# ─────────────────────────────────────────
# INCLUDE ROUTERS
# ─────────────────────────────────────────
from ble_routes import router as ble_router
from face_routes import router as face_router
from divisions_routes import router as divisions_router
from events_routes import router as events_router
from stats_routes import router as stats_router

app.include_router(ble_router)
app.include_router(face_router)
app.include_router(divisions_router)
app.include_router(events_router)
app.include_router(stats_router)


# ─────────────────────────────────────────
# PYDANTIC MODELS
# ─────────────────────────────────────────
class RegisterRequest(BaseModel):
    full_name: str
    email: str
    password: str
    role: str
    department_id: Optional[str] = None
    enrollment_number: Optional[str] = None
    employee_id: Optional[str] = None
    year: Optional[int] = None
    practical_batch: Optional[str] = None
    tutorial_batch: Optional[str] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user: dict


class ApproveRequest(BaseModel):
    user_id: str
    action: str


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
    section: Optional[str] = None
    division_id: Optional[str] = None
    year: Optional[int] = None
    lecture_type: str = "lecture"
    batch: Optional[str] = None
    day_of_week: str
    start_time: str
    end_time: str
    room: str


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


# ─────────────────────────────────────────
# AUTH ROUTES
# ─────────────────────────────────────────
@app.post("/auth/register")
def register(req: RegisterRequest):
    conn = get_db()
    existing = conn.execute(
        "SELECT id FROM users WHERE email = %s", (req.email,)
    ).fetchone()
    if existing:
        conn.close()
        raise HTTPException(status_code=400, detail="Email already registered")

    valid_roles = ["admin", "faculty", "student", "hod", "principal"]
    if req.role not in valid_roles:
        conn.close()
        raise HTTPException(
            status_code=400, detail=f"Invalid role. Must be one of: {valid_roles}"
        )

    user_id = str(uuid.uuid4())
    conn.execute(
        """
        INSERT INTO users (id, full_name, email, password_hash, role, department_id,
                           enrollment_number, employee_id, status, year,
                           practical_batch, tutorial_batch)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """,
        (
            user_id,
            req.full_name,
            req.email,
            hash_password(req.password),
            req.role,
            req.department_id,
            req.enrollment_number,
            req.employee_id,
            "pending",
            req.year,
            req.practical_batch,
            req.tutorial_batch,
        ),
    )
    conn.commit()
    conn.close()

    return {
        "message": "Registration successful. Waiting for admin approval.",
        "user_id": user_id,
        "status": "pending",
    }


@app.post("/auth/login", response_model=TokenResponse)
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    conn = get_db()
    user = conn.execute(
        "SELECT * FROM users WHERE email = %s", (form_data.username,)
    ).fetchone()
    conn.close()

    if not user or not verify_password(form_data.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    user_dict = dict(user)
    token = create_token({"sub": user_dict["id"], "role": user_dict["role"]})
    user_dict.pop("password_hash", None)

    return {"access_token": token, "token_type": "bearer", "user": user_dict}


@app.get("/auth/me")
def get_me(current_user: dict = Depends(get_current_user)):
    current_user.pop("password_hash", None)
    return current_user


class ProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    practical_batch: Optional[str] = None
    tutorial_batch: Optional[str] = None


@app.put("/auth/profile")
def update_profile(req: ProfileUpdate, current_user: dict = Depends(get_current_user)):
    conn = get_db()
    updates = []
    params = []
    if req.full_name:
        updates.append("full_name = %s")
        params.append(req.full_name)
    if req.practical_batch is not None:
        updates.append("practical_batch = %s")
        params.append(req.practical_batch)
    if req.tutorial_batch is not None:
        updates.append("tutorial_batch = %s")
        params.append(req.tutorial_batch)

    if updates:
        params.append(current_user["id"])
        conn.execute(f"UPDATE users SET {', '.join(updates)} WHERE id = %s", params)
        conn.commit()

    user = conn.execute(
        "SELECT * FROM users WHERE id = %s", (current_user["id"],)
    ).fetchone()
    conn.close()
    user_dict = dict(user)
    user_dict.pop("password_hash", None)
    return user_dict


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
def approve_user(
    req: ApproveRequest, current_user: dict = Depends(require_role("admin"))
):
    if req.action not in ["approve", "reject"]:
        raise HTTPException(status_code=400, detail="Action must be approve or reject")

    new_status = "approved" if req.action == "approve" else "rejected"
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE id = %s", (req.user_id,)).fetchone()
    if not user:
        conn.close()
        raise HTTPException(status_code=404, detail="User not found")

    conn.execute(
        "UPDATE users SET status = %s WHERE id = %s", (new_status, req.user_id)
    )
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
def create_department(
    req: DepartmentCreate, current_user: dict = Depends(require_role("admin"))
):
    conn = get_db()
    dept_id = str(uuid.uuid4())
    try:
        conn.execute(
            "INSERT INTO departments (id, name) VALUES (%s, %s)", (dept_id, req.name)
        )
        conn.commit()
    except psycopg2.errors.UniqueViolation:
        conn.close()
        raise HTTPException(status_code=400, detail="Department already exists")
    conn.close()
    return {"id": dept_id, "name": req.name, "message": "Department created"}


@app.delete("/departments/{dept_id}")
def delete_department(
    dept_id: str, current_user: dict = Depends(require_role("admin"))
):
    conn = get_db()
    conn.execute("DELETE FROM departments WHERE id = %s", (dept_id,))
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
def create_subject(
    req: SubjectCreate, current_user: dict = Depends(require_role("admin"))
):
    conn = get_db()
    subj_id = str(uuid.uuid4())
    try:
        conn.execute(
            """
            INSERT INTO subjects (id, name, code, department_id)
            VALUES (%s, %s, %s, %s)
        """,
            (subj_id, req.name, req.code, req.department_id),
        )
        conn.commit()
    except psycopg2.errors.UniqueViolation:
        conn.close()
        raise HTTPException(status_code=400, detail="Subject code already exists")
    conn.close()
    return {"id": subj_id, "message": "Subject created"}


@app.delete("/subjects/{subj_id}")
def delete_subject(subj_id: str, current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    conn.execute("DELETE FROM subjects WHERE id = %s", (subj_id,))
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
        slots = conn.execute(
            """
            SELECT ts.*, s.name as subject_name, s.code as subject_code,
                   u.full_name as faculty_name, d.name as department_name
            FROM timetable_slots ts
            LEFT JOIN subjects s ON ts.subject_id = s.id
            LEFT JOIN users u ON ts.faculty_id = u.id
            LEFT JOIN departments d ON ts.department_id = d.id
            WHERE ts.faculty_id = %s AND ts.is_active = TRUE
            ORDER BY ts.day_of_week, ts.start_time
        """,
            (user_id,),
        ).fetchall()
    elif role == "student":
        dept_id = current_user.get("department_id")
        slots = conn.execute(
            """
            SELECT ts.*, s.name as subject_name, s.code as subject_code,
                   u.full_name as faculty_name, d.name as department_name
            FROM timetable_slots ts
            LEFT JOIN subjects s ON ts.subject_id = s.id
            LEFT JOIN users u ON ts.faculty_id = u.id
            LEFT JOIN departments d ON ts.department_id = d.id
            WHERE ts.department_id = %s AND ts.is_active = TRUE
            ORDER BY ts.day_of_week, ts.start_time
        """,
            (dept_id,),
        ).fetchall()
    else:
        slots = conn.execute("""
            SELECT ts.*, s.name as subject_name, s.code as subject_code,
                   u.full_name as faculty_name, d.name as department_name
            FROM timetable_slots ts
            LEFT JOIN subjects s ON ts.subject_id = s.id
            LEFT JOIN users u ON ts.faculty_id = u.id
            LEFT JOIN departments d ON ts.department_id = d.id
            WHERE ts.is_active = TRUE
            ORDER BY ts.day_of_week, ts.start_time
        """).fetchall()

    conn.close()
    return [dict(s) for s in slots]


@app.post("/timetable")
def create_slot(req: SlotCreate, current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    slot_id = str(uuid.uuid4())
    conn.execute(
        """
        INSERT INTO timetable_slots
        (id, subject_id, faculty_id, department_id, section, division_id,
         year, lecture_type, batch, day_of_week, start_time, end_time, room)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """,
        (
            slot_id,
            req.subject_id,
            req.faculty_id,
            req.department_id,
            req.section,
            req.division_id,
            req.year,
            req.lecture_type,
            req.batch,
            req.day_of_week,
            req.start_time,
            req.end_time,
            req.room,
        ),
    )
    conn.commit()
    conn.close()
    return {"id": slot_id, "message": "Timetable slot created"}


@app.delete("/timetable/{slot_id}")
def delete_slot(slot_id: str, current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    conn.execute(
        "UPDATE timetable_slots SET is_active = FALSE WHERE id = %s", (slot_id,)
    )
    conn.commit()
    conn.close()
    return {"message": "Slot deactivated"}


# ─────────────────────────────────────────
# HOD ROUTES
# ─────────────────────────────────────────
@app.get("/hod/department-users")
def hod_get_users(current_user: dict = Depends(require_role("hod"))):
    dept_id = current_user.get("department_id")
    if not dept_id:
        raise HTTPException(status_code=400, detail="HOD not assigned to a department")
    conn = get_db()
    users = conn.execute(
        """
        SELECT u.id, u.full_name, u.email, u.role, u.status, u.created_at
        FROM users u
        WHERE u.department_id = %s
        ORDER BY u.role, u.full_name
    """,
        (dept_id,),
    ).fetchall()
    conn.close()
    return [dict(u) for u in users]


@app.get("/hod/pending-users")
def hod_pending_users(current_user: dict = Depends(require_role("hod"))):
    dept_id = current_user.get("department_id")
    conn = get_db()
    users = conn.execute(
        """
        SELECT u.id, u.full_name, u.email, u.role, u.status, u.created_at
        FROM users u
        WHERE u.department_id = %s AND u.status = 'pending'
    """,
        (dept_id,),
    ).fetchall()
    conn.close()
    return [dict(u) for u in users]


@app.post("/hod/approve-user")
def hod_approve_user(
    req: ApproveRequest, current_user: dict = Depends(require_role("hod"))
):
    dept_id = current_user.get("department_id")
    conn = get_db()
    user = conn.execute(
        """
        SELECT * FROM users WHERE id = %s AND department_id = %s
    """,
        (req.user_id, dept_id),
    ).fetchone()
    if not user:
        conn.close()
        raise HTTPException(status_code=404, detail="User not found in your department")
    new_status = "approved" if req.action == "approve" else "rejected"
    conn.execute(
        "UPDATE users SET status = %s WHERE id = %s", (new_status, req.user_id)
    )
    conn.commit()
    conn.close()
    return {"message": f"User {req.action}d successfully"}


# ─────────────────────────────────────────
# REPORTS
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
            ORDER BY ar.marked_at DESC LIMIT 200
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
        params = []
        if dept_id:
            query += " WHERE ts.department_id = %s"
            params.append(dept_id)
        query += " ORDER BY ar.marked_at DESC LIMIT 200"
        records = conn.execute(query, params if params else None).fetchall()
    elif role == "faculty":
        records = conn.execute(
            """
            SELECT ar.*, u.full_name as student_name, u.enrollment_number,
                   s.name as subject_name, ases.started_at
            FROM attendance_records ar
            LEFT JOIN users u ON ar.student_id = u.id
            LEFT JOIN attendance_sessions ases ON ar.session_id = ases.id
            LEFT JOIN timetable_slots ts ON ases.slot_id = ts.id
            LEFT JOIN subjects s ON ts.subject_id = s.id
            WHERE ases.faculty_id = %s
            ORDER BY ar.marked_at DESC LIMIT 100
        """,
            (current_user["id"],),
        ).fetchall()
    else:
        records = conn.execute(
            """
            SELECT ar.*, s.name as subject_name, ases.started_at
            FROM attendance_records ar
            LEFT JOIN attendance_sessions ases ON ar.session_id = ases.id
            LEFT JOIN timetable_slots ts ON ases.slot_id = ts.id
            LEFT JOIN subjects s ON ts.subject_id = s.id
            WHERE ar.student_id = %s
            ORDER BY ar.marked_at DESC
        """,
            (current_user["id"],),
        ).fetchall()

    conn.close()
    return [dict(r) for r in records]


# ─────────────────────────────────────────
# HEALTH CHECK
# ─────────────────────────────────────────
@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}
