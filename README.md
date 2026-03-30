# Smart Attendance System

A face recognition + BLE-based attendance system built with Flutter and FastAPI.

## Features

- **Role-based access** — Admin, HOD, Principal, Faculty, Student
- **BLE-based presence detection** — Faculty broadcasts, students scan
- **Face recognition + liveness detection** — Blink, head turn, and smile challenges powered by InsightFace + Google ML Kit
- **Face enrollment with admin approval** — Students submit selfie + ID card, admin reviews
- **Admin approval workflow** — New user registrations require admin/HOD approval
- **Timetable management** — Lectures, practicals, tutorials, electives
- **Real-time attendance tracking** — Calendar view, subject-wise stats
- **Department & subject management**
- **Event & lecture cancellation management**

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter (Dart) |
| BLE Broadcasting | flutter_ble_peripheral |
| BLE Scanning | flutter_blue_plus |
| Face Detection (on-device) | Google ML Kit Face Detection |
| Backend | FastAPI (Python 3.10+) |
| Face Recognition (server) | InsightFace + ONNX Runtime |
| Database | PostgreSQL |
| Auth | JWT (python-jose) + bcrypt |

## Project Structure

```
smart-attendance-system/
├── server/
│   ├── main.py               ← FastAPI app + core routes
│   ├── database.py           ← DB connection pool, auth helpers
│   ├── face_routes.py        ← Face enrollment + liveness + verification
│   ├── ble_routes.py         ← BLE event routes
│   ├── stats_routes.py       ← Attendance stats & calendar
│   ├── events_routes.py      ← College events (holidays, exams, etc.)
│   ├── divisions_routes.py   ← Division management
│   ├── init.sql              ← Full PostgreSQL schema + seed data
│   └── requirements.txt
└── flutter_app/
    ├── lib/
    │   ├── main.dart
    │   ├── config.dart       ← Server IP, app constants, colors
    │   ├── theme.dart        ← App theme
    │   ├── services/
    │   │   ├── api_service.dart
    │   │   ├── auth_provider.dart
    │   │   └── theme_provider.dart
    │   ├── widgets/
    │   │   └── common_widgets.dart
    │   └── screens/
    │       ├── auth/          ← Login, Register
    │       ├── admin/         ← User approval, departments, subjects, timetable
    │       ├── faculty/       ← Start/stop attendance, BLE broadcast
    │       ├── student/       ← BLE scan, face scan, enrollment, calendar
    │       ├── hod/           ← Department management
    │       ├── principal/     ← Overview & reports
    │       └── profile/       ← User profile
    └── pubspec.yaml
```

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Python | 3.10+ | Required by InsightFace |
| PostgreSQL | 14+ | Database |
| Flutter | 3.x | Mobile app |
| Android Studio | Latest | Android SDK + emulator |
| Physical Android device | — | Required for BLE + camera features |

> **Note:** BLE broadcasting and camera-based face detection only work on a **physical device**, not an emulator.

---

## Server Setup

### 1. Install PostgreSQL

<details>
<summary><strong>macOS</strong></summary>

```bash
# Install via Homebrew
brew install postgresql@16

# Start the service
brew services start postgresql@16

# Create the database
createdb attendance
```

</details>

<details>
<summary><strong>Ubuntu / Debian</strong></summary>

```bash
# Install
sudo apt update
sudo apt install postgresql postgresql-contrib

# Start the service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create the database
sudo -u postgres createdb attendance
```

> If you need a custom password:
> ```bash
> sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'yourpassword';"
> ```
> Then set `DATABASE_URL` accordingly (see step 3).

</details>

<details>
<summary><strong>Windows</strong></summary>

1. Download the installer from [postgresql.org/download/windows](https://www.postgresql.org/download/windows/)
2. Run the installer — remember the password you set for the `postgres` user
3. Open **pgAdmin** or **SQL Shell (psql)** and create the database:
   ```sql
   CREATE DATABASE attendance;
   ```

</details>

### 2. Initialize the Database Schema

```bash
psql -d attendance -f server/init.sql
```

This creates all tables and seeds a default admin account:

| Field | Value |
|---|---|
| Email | `admin@college.edu` |
| Password | `admin123` |

### 3. Set Environment Variables (optional)

The server reads `DATABASE_URL` from the environment. The default is:

```
postgresql://postgres:postgres@localhost:5432/attendance
```

If your PostgreSQL setup uses a different user, password, host, or database name, set it:

<details>
<summary><strong>macOS / Linux</strong></summary>

```bash
export DATABASE_URL="postgresql://YOUR_USER:YOUR_PASSWORD@localhost:5432/attendance"
```

</details>

<details>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
$env:DATABASE_URL = "postgresql://YOUR_USER:YOUR_PASSWORD@localhost:5432/attendance"
```

</details>

### 4. Install Python Dependencies & Run

<details>
<summary><strong>macOS / Linux</strong></summary>

```bash
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
```

</details>

<details>
<summary><strong>Windows</strong></summary>

```bash
cd server
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

</details>

The server will start on `http://0.0.0.0:8000`.

### 5. Verify

Open the interactive API docs in your browser:

```
http://localhost:8000/docs
```

---

## Flutter App Setup

### 1. Install Dependencies

```bash
cd flutter_app
flutter pub get
```

### 2. Configure Server IP

Open `lib/config.dart` and set your server's local IP address:

```dart
static const String baseUrl = "http://YOUR_LAPTOP_IP:8000";
```

> **Tip:** Find your IP with `ifconfig` (macOS/Linux) or `ipconfig` (Windows).
> Use the IP from your Wi-Fi adapter (e.g., `192.168.1.x`). Do **not** use `localhost` — the phone cannot reach your laptop via `localhost`.

### 3. Run on Device

```bash
flutter run
```

> **Important:** Use a physical device for full functionality (BLE + camera).

---

## Attendance Flow

This is the end-to-end flow for marking attendance:

```
┌─────────────────────────────────────────────────────────────────┐
│  SETUP (one-time)                                               │
│                                                                 │
│  1. Admin creates departments, subjects, timetable slots        │
│  2. Faculty & students register → Admin/HOD approves accounts   │
│  3. Student submits face enrollment (selfie + ID card)          │
│  4. Admin reviews & approves face enrollment                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  EACH CLASS                                                     │
│                                                                 │
│  5. Faculty opens app → starts attendance → phone broadcasts    │
│     BLE signal with a rotating token                            │
│  6. Student opens app → scans for BLE signal → detects faculty  │
│  7. Student taps "Mark Attendance" → app opens front camera     │
│  8. Server sends a random liveness challenge:                   │
│     • "Blink twice"                                             │
│     • "Turn your head left, then right"                         │
│     • "Smile"                                                   │
│  9. Student completes the challenge (verified on-device via     │
│     Google ML Kit)                                              │
│ 10. App captures a photo → sends to server with BLE token +    │
│     challenge ID                                                │
│ 11. Server verifies:                                            │
│     • BLE token is valid (proves physical proximity)            │
│     • Liveness challenge was completed (anti-spoofing)          │
│     • Face matches enrolled embedding (InsightFace)             │
│ 12. Attendance marked ✅                                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## First-Time Setup Checklist

After the server and app are running:

1. **Login as admin** — `admin@college.edu` / `admin123`
2. **Create departments** (e.g., Computer Science, Electronics)
3. **Create subjects** (e.g., Data Structures, OS)
4. **Register faculty and student accounts** (from the app's register screen)
5. **Admin approves accounts** (Admin dashboard → Pending Users)
6. **Admin creates timetable slots** (assign subject + faculty + day + time + room)
7. **Student completes face enrollment** (Student dashboard → selfie + ID card)
8. **Admin approves face enrollment** (Admin dashboard → Pending Enrollments)
9. **Faculty starts attendance** for a timetable slot → BLE broadcasting begins
10. **Student scans BLE** → taps Mark → completes liveness challenge → attendance marked

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `postgresql://postgres:postgres@localhost:5432/attendance` | PostgreSQL connection string |

The JWT secret key is currently hardcoded in `database.py`. For production, change `SECRET_KEY` in `server/database.py`:

```python
SECRET_KEY = "your-secure-random-string-here"
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `psycopg2` install fails | Install `libpq-dev` (Linux) or ensure PostgreSQL is installed (macOS/Windows) |
| `InsightFace` model download fails | Run server with internet access the first time — it downloads ONNX models (~300 MB) |
| BLE not working | Use a physical device. Ensure Bluetooth + Location permissions are granted |
| Camera shows black screen | Grant camera permission. Restart the app |
| "Face does not match" on verify | Re-enroll with a well-lit, frontal photo. Check server logs for similarity score |
| "Challenge expired" | Ensure server and phone clocks are roughly in sync |
| App can't connect to server | Ensure phone and laptop are on the same Wi-Fi. Use laptop's local IP, not `localhost` |

---

## API Documentation

Once the server is running, interactive Swagger docs are available at:

```
http://localhost:8000/docs
```

---

## Roadmap

- [x] Role-based authentication (Admin, HOD, Principal, Faculty, Student)
- [x] BLE-based attendance flow
- [x] Timetable management (lectures, practicals, tutorials, electives)
- [x] Admin approval workflow
- [x] Face enrollment with admin review
- [x] Liveness detection (blink, head turn, smile)
- [x] Face recognition (InsightFace)
- [x] PostgreSQL database
- [x] Attendance calendar & stats
- [x] Event management (holidays, exams, fests)
- [x] Lecture cancellation
- [ ] Push notifications (FCM)
- [ ] Export reports (PDF/Excel)
- [ ] Attendance percentage alerts

---

## License

This project is for educational purposes.
