# AttendX - Attendance System

## Project Structure
```
attendance_system/
├── server/
│   ├── main.py          ← FastAPI server
│   ├── requirements.txt
│   └── attendance.db    ← auto-created on first run
└── flutter_app/
    ├── lib/
    │   ├── main.dart                    ← App entry + routing
    │   ├── config.dart                  ← ⚠️ SET YOUR SERVER IP HERE
    │   ├── models/user_model.dart
    │   ├── services/
    │   │   ├── api_service.dart
    │   │   └── auth_provider.dart
    │   ├── widgets/common_widgets.dart
    │   └── screens/
    │       ├── auth/
    │       │   ├── login_screen.dart
    │       │   ├── register_screen.dart
    │       │   └── pending_screen.dart
    │       ├── admin/
    │       │   ├── admin_dashboard.dart
    │       │   ├── admin_users_screen.dart
    │       │   ├── admin_departments_screen.dart
    │       │   ├── admin_timetable_screen.dart
    │       │   └── admin_reports_screen.dart
    │       ├── faculty/
    │       │   └── faculty_dashboard.dart
    │       ├── student/
    │       │   └── student_dashboard.dart
    │       ├── hod/
    │       │   └── hod_dashboard.dart
    │       └── principal/
    │           └── principal_dashboard.dart
    ├── pubspec.yaml
    └── android/app/src/main/AndroidManifest.xml
```

---

## STEP 1: Start the Server

```bash
cd server/

# Install dependencies
pip install -r requirements.txt

# Run server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Default admin account (auto-created):
```
Email:    admin@college.edu
Password: admin123
```

### API Docs (auto-generated):
```
http://localhost:8000/docs
```

---

## STEP 2: Configure Flutter App

Open `flutter_app/lib/config.dart` and change:

```dart
static const String baseUrl = "http://YOUR_LAPTOP_IP:8000";
```

Find your IP:
- Windows: `ipconfig` → IPv4 Address
- Mac/Linux: `ifconfig` → inet

⚠️ All devices must be on the same WiFi network.

---

## STEP 3: Run Flutter App

```bash
cd flutter_app/

# Install packages
flutter pub get

# Connect phone via USB with developer mode ON
flutter devices

# Run on device
flutter run
```

---

## STEP 4: Test the Full Flow

### Setup (do this first via admin account):
1. Login as admin → Departments & Subjects → Add a department
2. Add subjects for that department
3. Register a faculty account and a student account (use register screen)
4. Login as admin → Pending Approvals → Approve both accounts
5. Login as admin → Timetable → Create a slot (assign faculty + department)

### Test BLE:
1. Phone 1: Login as faculty → tap the slot → Start Attendance
   - BLE starts broadcasting
2. Phone 2: Login as student → tap Scan
   - Signal detected → tap Mark
   - Server reports the BLE event

### Check server logs:
```bash
# In server terminal you'll see:
# INFO: POST /attendance/start → 200
# INFO: POST /ble/detected → 200
```

---

## Roles & Permissions

| Role      | Can Do |
|-----------|--------|
| Admin     | Manage everything: users, depts, subjects, timetable, reports |
| HOD       | View/approve their dept users, view dept reports |
| Faculty   | View own timetable, start/stop attendance via BLE |
| Student   | View own timetable, scan BLE, mark attendance |
| Principal | View all attendance reports college-wide |

---

## Account States

```
Register → PENDING → (Admin approves) → APPROVED → can use app
                   → (Admin rejects) → REJECTED → sees rejection screen
```

---

## Face Recognition (Future)

The student attendance flow is already structured for face recognition.
In `student_dashboard.dart`, after BLE signal is validated:

```dart
// TODO: Navigate to face recognition screen
// This is where MediaPipe liveness + InsightFace recognition goes
```

When ready, create `screens/student/face_scan_screen.dart` and add the face scan step here.

---

## Security Notes

- JWT tokens expire in 24 hours
- BLE tokens rotate every 5 minutes (TOTP-style)
- Old tokens have 5-minute grace period
- Each student can only report once per session
- Tokens are validated server-side on every request
