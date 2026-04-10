# import_routes.py
# Admin-only CSV import endpoints for bulk data ingestion

import csv
import io
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from database import get_db, require_role, pwd_context

router = APIRouter(prefix="/admin/import", tags=["Admin Import"])


def parse_csv(content: bytes) -> list[dict]:
    """Parse CSV bytes into a list of dicts."""
    text = content.decode("utf-8-sig")  # handles BOM from Excel
    reader = csv.DictReader(io.StringIO(text))
    # Strip whitespace from headers and values
    rows = []
    for row in reader:
        cleaned = {k.strip(): v.strip() for k, v in row.items() if k}
        rows.append(cleaned)
    return rows


def validate_headers(rows: list[dict], required: list[str], endpoint: str):
    """Validate that required CSV headers are present."""
    if not rows:
        raise HTTPException(status_code=400, detail=f"CSV file is empty")
    actual = set(rows[0].keys())
    missing = set(required) - actual
    if missing:
        raise HTTPException(
            status_code=400,
            detail=f"Missing required columns for {endpoint}: {sorted(missing)}. "
            f"Found columns: {sorted(actual)}",
        )


# ─────────────────────────────────────────
# 1. Import Departments
# ─────────────────────────────────────────
@router.post("/departments")
async def import_departments(
    file: UploadFile = File(...),
    current_user: dict = Depends(require_role("admin")),
):
    """
    Import departments from CSV.
    Required columns: name
    """
    content = await file.read()
    rows = parse_csv(content)
    validate_headers(rows, ["name"], "departments")

    conn = get_db()
    imported = 0
    skipped = 0
    errors = []

    for i, row in enumerate(rows, start=2):  # row 1 = header
        name = row.get("name", "").strip()
        if not name:
            errors.append(f"Row {i}: empty department name")
            continue

        existing = conn.execute(
            "SELECT id FROM departments WHERE name = %s", (name,)
        ).fetchone()
        if existing:
            skipped += 1
            continue

        dept_id = str(uuid.uuid4())
        try:
            conn.execute(
                "INSERT INTO departments (id, name) VALUES (%s, %s)",
                (dept_id, name),
            )
            imported += 1
        except Exception as e:
            errors.append(f"Row {i}: {str(e)}")

    conn.commit()
    conn.close()
    return {"imported": imported, "skipped": skipped, "errors": errors}


# ─────────────────────────────────────────
# 2. Import Subjects
# ─────────────────────────────────────────
@router.post("/subjects")
async def import_subjects(
    file: UploadFile = File(...),
    current_user: dict = Depends(require_role("admin")),
):
    """
    Import subjects from CSV.
    Required columns: name, code, department_name, year
    """
    content = await file.read()
    rows = parse_csv(content)
    validate_headers(rows, ["name", "code", "department_name", "year"], "subjects")

    conn = get_db()
    imported = 0
    skipped = 0
    errors = []

    # Cache department lookups
    dept_cache = {}
    depts = conn.execute("SELECT id, name FROM departments").fetchall()
    for d in depts:
        d = dict(d)
        dept_cache[d["name"].lower()] = d["id"]

    for i, row in enumerate(rows, start=2):
        name = row.get("name", "").strip()
        code = row.get("code", "").strip()
        dept_name = row.get("department_name", "").strip()
        year_str = row.get("year", "").strip()

        if not all([name, code, dept_name, year_str]):
            errors.append(f"Row {i}: missing required fields")
            continue

        dept_id = dept_cache.get(dept_name.lower())
        if not dept_id:
            errors.append(f"Row {i}: department '{dept_name}' not found")
            continue

        try:
            year = int(year_str)
        except ValueError:
            errors.append(f"Row {i}: invalid year '{year_str}'")
            continue

        existing = conn.execute(
            "SELECT id FROM subjects WHERE code = %s", (code,)
        ).fetchone()
        if existing:
            skipped += 1
            continue

        subj_id = str(uuid.uuid4())
        try:
            conn.execute(
                """INSERT INTO subjects (id, name, code, department_id, year)
                   VALUES (%s, %s, %s, %s, %s)""",
                (subj_id, name, code, dept_id, year),
            )
            imported += 1
        except Exception as e:
            errors.append(f"Row {i}: {str(e)}")

    conn.commit()
    conn.close()
    return {"imported": imported, "skipped": skipped, "errors": errors}


# ─────────────────────────────────────────
# 3. Import Faculty
# ─────────────────────────────────────────
@router.post("/faculty")
async def import_faculty(
    file: UploadFile = File(...),
    current_user: dict = Depends(require_role("admin")),
):
    """
    Import faculty from CSV.
    Required columns: full_name, email, password, department_name, employee_id
    """
    content = await file.read()
    rows = parse_csv(content)
    validate_headers(
        rows,
        ["full_name", "email", "password", "department_name", "employee_id"],
        "faculty",
    )

    conn = get_db()
    imported = 0
    skipped = 0
    errors = []

    dept_cache = {}
    depts = conn.execute("SELECT id, name FROM departments").fetchall()
    for d in depts:
        d = dict(d)
        dept_cache[d["name"].lower()] = d["id"]

    for i, row in enumerate(rows, start=2):
        full_name = row.get("full_name", "").strip()
        email = row.get("email", "").strip()
        password = row.get("password", "").strip()
        dept_name = row.get("department_name", "").strip()
        employee_id = row.get("employee_id", "").strip()

        if not all([full_name, email, password, dept_name, employee_id]):
            errors.append(f"Row {i}: missing required fields")
            continue

        dept_id = dept_cache.get(dept_name.lower())
        if not dept_id:
            errors.append(f"Row {i}: department '{dept_name}' not found")
            continue

        existing = conn.execute(
            "SELECT id FROM users WHERE email = %s", (email,)
        ).fetchone()
        if existing:
            skipped += 1
            continue

        user_id = str(uuid.uuid4())
        try:
            conn.execute(
                """INSERT INTO users
                   (id, full_name, email, password_hash, role, department_id,
                    employee_id, status)
                   VALUES (%s, %s, %s, %s, 'faculty', %s, %s, 'approved')""",
                (
                    user_id,
                    full_name,
                    email,
                    pwd_context.hash(password),
                    dept_id,
                    employee_id,
                ),
            )
            imported += 1
        except Exception as e:
            errors.append(f"Row {i}: {str(e)}")

    conn.commit()
    conn.close()
    return {"imported": imported, "skipped": skipped, "errors": errors}


# ─────────────────────────────────────────
# 4. Import Students
# ─────────────────────────────────────────
@router.post("/students")
async def import_students(
    file: UploadFile = File(...),
    current_user: dict = Depends(require_role("admin")),
):
    """
    Import students from CSV.
    Required columns: full_name, email, password, department_name, enrollment_number, year
    """
    content = await file.read()
    rows = parse_csv(content)
    validate_headers(
        rows,
        ["full_name", "email", "password", "department_name", "enrollment_number", "year"],
        "students",
    )

    conn = get_db()
    imported = 0
    skipped = 0
    errors = []

    dept_cache = {}
    depts = conn.execute("SELECT id, name FROM departments").fetchall()
    for d in depts:
        d = dict(d)
        dept_cache[d["name"].lower()] = d["id"]

    for i, row in enumerate(rows, start=2):
        full_name = row.get("full_name", "").strip()
        email = row.get("email", "").strip()
        password = row.get("password", "").strip()
        dept_name = row.get("department_name", "").strip()
        enrollment = row.get("enrollment_number", "").strip()
        year_str = row.get("year", "").strip()

        if not all([full_name, email, password, dept_name, enrollment, year_str]):
            errors.append(f"Row {i}: missing required fields")
            continue

        dept_id = dept_cache.get(dept_name.lower())
        if not dept_id:
            errors.append(f"Row {i}: department '{dept_name}' not found")
            continue

        try:
            year = int(year_str)
        except ValueError:
            errors.append(f"Row {i}: invalid year '{year_str}'")
            continue

        existing = conn.execute(
            "SELECT id FROM users WHERE email = %s", (email,)
        ).fetchone()
        if existing:
            skipped += 1
            continue

        user_id = str(uuid.uuid4())
        try:
            conn.execute(
                """INSERT INTO users
                   (id, full_name, email, password_hash, role, department_id,
                    enrollment_number, status, year)
                   VALUES (%s, %s, %s, %s, 'student', %s, %s, 'approved', %s)""",
                (
                    user_id,
                    full_name,
                    email,
                    pwd_context.hash(password),
                    dept_id,
                    enrollment,
                    year,
                ),
            )
            imported += 1
        except Exception as e:
            errors.append(f"Row {i}: {str(e)}")

    conn.commit()
    conn.close()
    return {"imported": imported, "skipped": skipped, "errors": errors}


# ─────────────────────────────────────────
# 5. Import Timetable
# ─────────────────────────────────────────
@router.post("/timetable")
async def import_timetable(
    file: UploadFile = File(...),
    current_user: dict = Depends(require_role("admin")),
):
    """
    Import timetable slots from CSV.
    Required columns: subject_code, faculty_email, department_name, year,
                      day_of_week, start_time, end_time, room, lecture_type
    Optional columns: batch
    """
    content = await file.read()
    rows = parse_csv(content)
    validate_headers(
        rows,
        [
            "subject_code",
            "faculty_email",
            "department_name",
            "year",
            "day_of_week",
            "start_time",
            "end_time",
            "room",
            "lecture_type",
        ],
        "timetable",
    )

    conn = get_db()
    imported = 0
    skipped = 0
    errors = []

    # Build lookup caches
    dept_cache = {}
    depts = conn.execute("SELECT id, name FROM departments").fetchall()
    for d in depts:
        d = dict(d)
        dept_cache[d["name"].lower()] = d["id"]

    subject_cache = {}
    subjects = conn.execute("SELECT id, code FROM subjects").fetchall()
    for s in subjects:
        s = dict(s)
        subject_cache[s["code"].lower()] = s["id"]

    faculty_cache = {}
    faculty = conn.execute(
        "SELECT id, email FROM users WHERE role = 'faculty'"
    ).fetchall()
    for f in faculty:
        f = dict(f)
        faculty_cache[f["email"].lower()] = f["id"]

    for i, row in enumerate(rows, start=2):
        subject_code = row.get("subject_code", "").strip()
        faculty_email = row.get("faculty_email", "").strip()
        dept_name = row.get("department_name", "").strip()
        year_str = row.get("year", "").strip()
        day = row.get("day_of_week", "").strip()
        start = row.get("start_time", "").strip()
        end = row.get("end_time", "").strip()
        room = row.get("room", "").strip()
        lecture_type = row.get("lecture_type", "lecture").strip()
        batch = row.get("batch", "").strip() or None

        if not all([subject_code, faculty_email, dept_name, year_str, day, start, end, room]):
            errors.append(f"Row {i}: missing required fields")
            continue

        # Resolve foreign keys
        dept_id = dept_cache.get(dept_name.lower())
        if not dept_id:
            errors.append(f"Row {i}: department '{dept_name}' not found")
            continue

        subj_id = subject_cache.get(subject_code.lower())
        if not subj_id:
            errors.append(f"Row {i}: subject code '{subject_code}' not found")
            continue

        fac_id = faculty_cache.get(faculty_email.lower())
        if not fac_id:
            errors.append(f"Row {i}: faculty email '{faculty_email}' not found")
            continue

        try:
            year = int(year_str)
        except ValueError:
            errors.append(f"Row {i}: invalid year '{year_str}'")
            continue

        slot_id = str(uuid.uuid4())
        try:
            conn.execute(
                """INSERT INTO timetable_slots
                   (id, subject_id, faculty_id, department_id, year,
                    day_of_week, start_time, end_time, room, lecture_type, batch)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (
                    slot_id,
                    subj_id,
                    fac_id,
                    dept_id,
                    year,
                    day,
                    start,
                    end,
                    room,
                    lecture_type,
                    batch,
                ),
            )
            imported += 1
        except Exception as e:
            errors.append(f"Row {i}: {str(e)}")

    conn.commit()
    conn.close()
    return {"imported": imported, "skipped": skipped, "errors": errors}
