# smart-attendance-system

A face recognition + BLE based attendance system built with Flutter and FastAPI.

## Features
- Role-based access: Admin, HOD, Principal, Faculty, Student
- BLE-based presence detection (faculty broadcasts, students scan)
- Face recognition + liveness detection (blink) — coming soon
- Admin approval workflow for new registrations
- Timetable management
- Real-time attendance tracking
- Department and subject management

## Tech Stack
| Layer | Technology |
|---|---|
| Mobile App | Flutter (Dart) |
| BLE Broadcasting | flutter_ble_peripheral |
| BLE Scanning | flutter_blue_plus |
| Backend | FastAPI (Python) |
| Database | SQLite (dev) → PostgreSQL (prod) |
| Auth | JWT + Refresh Tokens |
| Face Recognition | MediaPipe + InsightFace (coming soon) |

## Project Structure
```
attendance_system/
├── server/
│   ├── main.py           ← FastAPI server
│   ├── requirements.txt
│   └── .env.example      ← copy to .env and fill in values
└── flutter_app/
    ├── lib/
    │   ├── main.dart
    │   ├── config.dart   ← set your server IP here
    │   ├── models/
    │   ├── services/
    │   ├── widgets/
    │   └── screens/
    │       ├── admin/
    │       ├── faculty/
    │       ├── student/
    │       ├── hod/
    │       ├── principal/
    │       └── auth/
    └── pubspec.yaml
```

## Setup

### Prerequisites
- Python 3.10+
- Flutter 3.x
- Android Studio

### Server Setup
```bash
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# edit .env and set your SECRET_KEY
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
```

### Flutter App Setup
```bash
cd flutter_app
flutter pub get
```

Open `lib/config.dart` and set your server IP:
```dart
static const String baseUrl = "http://YOUR_LAPTOP_IP:8000";
```

Run on device:
```bash
flutter run
```

### First Time Setup
1. Login as admin
2. Create departments
3. Create subjects
4. Register faculty and student accounts
5. Admin approves accounts
6. Admin creates timetable slots
7. Faculty starts attendance → BLE broadcasts
8. Student scans → marks attendance

## API Docs
Once server is running, visit:
```
http://localhost:8000/docs
```

## Roadmap
- [x] Role-based authentication
- [x] BLE attendance flow
- [x] Timetable management
- [x] Admin approval workflow
- [ ] Face enrollment
- [ ] Liveness detection (blink)
- [ ] Face recognition
- [ ] Push notifications (FCM)
- [ ] Attendance percentage tracking
- [ ] Export reports (PDF/Excel)
- [ ] PostgreSQL migration
