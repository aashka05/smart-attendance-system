-- ============================================================
-- Smart Attendance System — PostgreSQL Schema & Seed Data
-- ============================================================
-- Usage:
--   1. Create the database:
--        createdb attendance
--   2. Import this file:
--        psql -d attendance -f init.sql
--
-- Default admin login:
--   Email:    admin@college.edu
--   Password: admin123
-- ============================================================

BEGIN;

-- ─────────────────────────────────────────
-- 1. departments (no dependencies)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS departments (
    id              TEXT PRIMARY KEY,
    name            TEXT UNIQUE NOT NULL,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- 2. subjects (depends on: departments)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS subjects (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    code            TEXT UNIQUE NOT NULL,
    department_id   TEXT NOT NULL,
    year            INTEGER NOT NULL,
    created_at      TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (department_id) REFERENCES departments(id)
);

-- ─────────────────────────────────────────
-- 3. users (depends on: departments)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id                  TEXT PRIMARY KEY,
    full_name           TEXT NOT NULL,
    email               TEXT UNIQUE NOT NULL,
    password_hash       TEXT NOT NULL,
    role                TEXT NOT NULL,
    department_id       TEXT,
    enrollment_number   TEXT,
    employee_id         TEXT,
    status              TEXT DEFAULT 'pending',
    face_enrolled       INTEGER DEFAULT 0,       -- 0=not enrolled, 1=approved, 2=pending review
    year                INTEGER,
    practical_batch     TEXT,
    tutorial_batch      TEXT,
    created_at          TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (department_id) REFERENCES departments(id)
);

-- ─────────────────────────────────────────
-- 4. divisions (depends on: departments)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS divisions (
    id              TEXT PRIMARY KEY,
    number          INTEGER NOT NULL,
    name            TEXT NOT NULL,
    department_id   TEXT NOT NULL,
    created_at      TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (department_id) REFERENCES departments(id)
);

-- ─────────────────────────────────────────
-- 5. timetable_slots (depends on: subjects, users)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS timetable_slots (
    id              TEXT PRIMARY KEY,
    subject_id      TEXT NOT NULL,
    faculty_id      TEXT NOT NULL,
    department_id   TEXT NOT NULL,
    section         TEXT,
    division_id     TEXT,
    year            INTEGER,
    lecture_type     TEXT DEFAULT 'lecture',
    batch           TEXT,
    day_of_week     TEXT NOT NULL,
    start_time      TEXT NOT NULL,
    end_time        TEXT NOT NULL,
    room            TEXT NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (subject_id) REFERENCES subjects(id),
    FOREIGN KEY (faculty_id) REFERENCES users(id)
);

-- ─────────────────────────────────────────
-- 6. attendance_sessions (depends on: timetable_slots)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance_sessions (
    id              TEXT PRIMARY KEY,
    slot_id         TEXT NOT NULL,
    faculty_id      TEXT NOT NULL,
    token           TEXT NOT NULL,
    status          TEXT DEFAULT 'live',
    started_at      TIMESTAMP DEFAULT NOW(),
    ended_at        TEXT,
    FOREIGN KEY (slot_id) REFERENCES timetable_slots(id)
);

-- ─────────────────────────────────────────
-- 7. ble_events (no foreign keys)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ble_events (
    id              TEXT PRIMARY KEY,
    student_id      TEXT NOT NULL,
    student_name    TEXT NOT NULL,
    token           TEXT NOT NULL,
    rssi            INTEGER,
    session_id      TEXT,
    timestamp       TIMESTAMP DEFAULT NOW()
);

-- ─────────────────────────────────────────
-- 8. attendance_records (depends on: attendance_sessions, users)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance_records (
    id              TEXT PRIMARY KEY,
    session_id      TEXT NOT NULL,
    student_id      TEXT NOT NULL,
    status          TEXT DEFAULT 'present',
    marked_at       TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (session_id) REFERENCES attendance_sessions(id),
    FOREIGN KEY (student_id) REFERENCES users(id)
);

-- ─────────────────────────────────────────
-- 9. face_enrollments (depends on: users)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS face_enrollments (
    id                  TEXT PRIMARY KEY,
    student_id          TEXT UNIQUE NOT NULL,
    face_embedding      TEXT,
    face_image_b64      TEXT,
    id_card_image_b64   TEXT,
    status              TEXT DEFAULT 'pending',
    submitted_at        TIMESTAMP DEFAULT NOW(),
    reviewed_at         TEXT,
    reviewed_by         TEXT,
    rejection_reason    TEXT,
    FOREIGN KEY (student_id) REFERENCES users(id)
);

-- ─────────────────────────────────────────
-- 10. liveness_challenges (no foreign keys)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS liveness_challenges (
    id              TEXT PRIMARY KEY,
    session_id      TEXT NOT NULL,
    student_id      TEXT NOT NULL,
    challenge       TEXT NOT NULL,
    created_at      TIMESTAMP DEFAULT NOW(),
    used            BOOLEAN DEFAULT FALSE
);

-- ─────────────────────────────────────────
-- 11. college_events (depends on: departments, users)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS college_events (
    id              TEXT PRIMARY KEY,
    title           TEXT NOT NULL,
    date            TEXT NOT NULL,
    event_type      TEXT NOT NULL,
    department_id   TEXT,
    year            INTEGER,
    description     TEXT,
    created_by      TEXT NOT NULL,
    created_at      TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (department_id) REFERENCES departments(id),
    FOREIGN KEY (created_by) REFERENCES users(id)
);

-- ─────────────────────────────────────────
-- 12. cancelled_lectures (depends on: timetable_slots, users)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cancelled_lectures (
    id              TEXT PRIMARY KEY,
    slot_id         TEXT NOT NULL,
    date            TEXT NOT NULL,
    reason          TEXT,
    cancelled_by    TEXT NOT NULL,
    created_at      TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (slot_id) REFERENCES timetable_slots(id),
    FOREIGN KEY (cancelled_by) REFERENCES users(id)
);

-- ─────────────────────────────────────────
-- 13. elective_enrollments (depends on: timetable_slots, users)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS elective_enrollments (
    id                  TEXT PRIMARY KEY,
    slot_id             TEXT NOT NULL,
    student_id          TEXT NOT NULL,
    enrollment_type     TEXT NOT NULL,
    status              TEXT DEFAULT 'enrolled',
    created_at          TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (slot_id) REFERENCES timetable_slots(id),
    FOREIGN KEY (student_id) REFERENCES users(id),
    UNIQUE(slot_id, student_id)
);


-- ============================================================
-- INDEXES (for query performance on foreign key columns)
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_subjects_department       ON subjects(department_id);
CREATE INDEX IF NOT EXISTS idx_users_department           ON users(department_id);
CREATE INDEX IF NOT EXISTS idx_users_role                 ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status               ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_email                ON users(email);
CREATE INDEX IF NOT EXISTS idx_timetable_faculty          ON timetable_slots(faculty_id);
CREATE INDEX IF NOT EXISTS idx_timetable_subject          ON timetable_slots(subject_id);
CREATE INDEX IF NOT EXISTS idx_timetable_department       ON timetable_slots(department_id);
CREATE INDEX IF NOT EXISTS idx_timetable_active           ON timetable_slots(is_active);
CREATE INDEX IF NOT EXISTS idx_sessions_slot              ON attendance_sessions(slot_id);
CREATE INDEX IF NOT EXISTS idx_sessions_status            ON attendance_sessions(status);
CREATE INDEX IF NOT EXISTS idx_sessions_faculty           ON attendance_sessions(faculty_id);
CREATE INDEX IF NOT EXISTS idx_records_session            ON attendance_records(session_id);
CREATE INDEX IF NOT EXISTS idx_records_student            ON attendance_records(student_id);
CREATE INDEX IF NOT EXISTS idx_ble_events_student         ON ble_events(student_id);
CREATE INDEX IF NOT EXISTS idx_ble_events_session         ON ble_events(session_id);
CREATE INDEX IF NOT EXISTS idx_face_enrollments_student   ON face_enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_face_enrollments_status    ON face_enrollments(status);
CREATE INDEX IF NOT EXISTS idx_liveness_session           ON liveness_challenges(session_id);
CREATE INDEX IF NOT EXISTS idx_liveness_student           ON liveness_challenges(student_id);
CREATE INDEX IF NOT EXISTS idx_college_events_date        ON college_events(date);
CREATE INDEX IF NOT EXISTS idx_college_events_department  ON college_events(department_id);
CREATE INDEX IF NOT EXISTS idx_cancelled_slot             ON cancelled_lectures(slot_id);
CREATE INDEX IF NOT EXISTS idx_cancelled_date             ON cancelled_lectures(date);
CREATE INDEX IF NOT EXISTS idx_divisions_department       ON divisions(department_id);
CREATE INDEX IF NOT EXISTS idx_elective_slot              ON elective_enrollments(slot_id);
CREATE INDEX IF NOT EXISTS idx_elective_student           ON elective_enrollments(student_id);


-- ============================================================
-- SEED DATA: Default admin account
-- ============================================================
-- Email:    admin@college.edu
-- Password: admin123
-- ============================================================

INSERT INTO users (id, full_name, email, password_hash, role, status)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'System Admin',
    'admin@college.edu',
    '$2b$12$5k6k3dPB5Z80a3KV69BnBujAorLqvfuU7lfrwtQJmS8bTjGprb6zO',
    'admin',
    'approved'
)
ON CONFLICT (email) DO NOTHING;


COMMIT;
