# Smart Attendance System - Next Features Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build 4 missing frontend features: (1) attendance tracking calendar UI, (2) user profile pages, (3) admin events management, (4) faculty class attendance view.

**Architecture:** All 4 features have backend APIs already built (`stats_routes.py`, `events_routes.py`). Work is purely Flutter frontend + wiring API calls through `ApiService`. Each feature is a new screen or set of screens, routed from existing dashboards.

**Tech Stack:** Flutter/Dart, Provider, existing `http` package via `ApiService`, existing widget library in `common_widgets.dart`

---

## Pre-Work: Fix Missing Dependencies & API Service Methods

Before any feature work, we need to add the missing `ApiService` methods and fix `requirements.txt`.

### Task 0: Add missing API service methods + fix requirements.txt

**Files:**
- Modify: `server/requirements.txt`
- Modify: `flutter_app/lib/services/api_service.dart:427` (append before response handler)

**Step 1: Fix requirements.txt - add face recognition libraries**

Add to `server/requirements.txt`:
```
insightface==0.7.3
opencv-python-headless==4.9.0.80
numpy==1.26.4
onnxruntime==1.17.1
```

Remove unused:
```
python-dotenv==1.0.0
```

**Step 2: Add all missing API methods to ApiService**

Append to `flutter_app/lib/services/api_service.dart` (before the response handler section at line 428):

```dart
  // ─────────────────────────────────────────
  // STUDENT STATS
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> getStudentStats(String studentId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/stats/student/$studentId'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getStudentCalendar({
    required String studentId,
    required int month,
    required int year,
    String? subjectId,
  }) async {
    var url = '${AppConfig.baseUrl}/stats/calendar/$studentId?month=$month&year=$year';
    if (subjectId != null) url += '&subject_id=$subjectId';
    final response = await http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // CLASS STATS (faculty/admin/hod)
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> getClassStats(String slotId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/stats/class/$slotId'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getClassCalendar({
    required String slotId,
    required int month,
    required int year,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/stats/class/calendar/$slotId?month=$month&year=$year'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // EVENTS
  // ─────────────────────────────────────────
  Future<List<dynamic>> getEvents({
    int? month,
    int? year,
    String? departmentId,
    int? yearLevel,
  }) async {
    var url = '${AppConfig.baseUrl}/events?';
    if (month != null) url += 'month=$month&';
    if (year != null) url += 'year=$year&';
    if (departmentId != null) url += 'department_id=$departmentId&';
    if (yearLevel != null) url += 'year_level=$yearLevel&';
    final response = await http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  Future<Map<String, dynamic>> createEvent({
    required String title,
    required String date,
    required String eventType,
    String? departmentId,
    int? year,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/events'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'title': title,
        'date': date,
        'event_type': eventType,
        'department_id': departmentId,
        'year': year,
        'description': description,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> deleteEvent(String eventId) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/events/$eventId'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> cancelLecture({
    required String slotId,
    required String date,
    String? reason,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/lectures/cancel'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'slot_id': slotId,
        'date': date,
        'reason': reason,
      }),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> getCancelledLectures({String? slotId}) async {
    var url = '${AppConfig.baseUrl}/lectures/cancelled';
    if (slotId != null) url += '?slot_id=$slotId';
    final response = await http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  Future<Map<String, dynamic>> restoreLecture(String cancelId) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/lectures/cancelled/$cancelId'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // DIVISIONS
  // ─────────────────────────────────────────
  Future<List<dynamic>> getDivisions() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/divisions'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  // ─────────────────────────────────────────
  // PROFILE (update user)
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String? practicalBatch,
    String? tutorialBatch,
  }) async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/auth/profile'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'full_name': fullName,
        'practical_batch': practicalBatch,
        'tutorial_batch': tutorialBatch,
      }),
    );
    return _handleResponse(response);
  }
```

**Step 3: Add profile update endpoint to backend**

Add to `server/main.py` after the `/auth/me` route (line 286):

```python
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
        updates.append("full_name = ?")
        params.append(req.full_name)
    if req.practical_batch is not None:
        updates.append("practical_batch = ?")
        params.append(req.practical_batch)
    if req.tutorial_batch is not None:
        updates.append("tutorial_batch = ?")
        params.append(req.tutorial_batch)

    if updates:
        params.append(current_user["id"])
        conn.execute(f"UPDATE users SET {', '.join(updates)} WHERE id = ?", params)
        conn.commit()

    user = conn.execute("SELECT * FROM users WHERE id = ?", (current_user["id"],)).fetchone()
    conn.close()
    user_dict = dict(user)
    user_dict.pop("password_hash", None)
    return user_dict
```

**Step 4: Commit**
```
git add -A && git commit -m "chore: add missing API methods and fix requirements.txt"
```

---

## Feature 1: Attendance Tracking Calendar (Duolingo-inspired)

**Concept:** A calendar view on the student dashboard. Each day cell shows colored dots for each slot that day - green (present), red (absent), yellow (cancelled), purple (exam/event), blue (fest). Days with no data are grey. Monthly navigation. Subject filter chips at top. Overall stats summary above the calendar.

### Task 1A: Create the Attendance Calendar Screen

**Files:**
- Create: `flutter_app/lib/screens/student/attendance_calendar_screen.dart`
- Modify: `flutter_app/lib/screens/student/student_dashboard.dart` (add navigation)

**Step 1: Create the calendar screen**

Create `flutter_app/lib/screens/student/attendance_calendar_screen.dart`:

```dart
// lib/screens/student/attendance_calendar_screen.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const AttendanceCalendarScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<AttendanceCalendarScreen> createState() => _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  late int _currentMonth;
  late int _currentYear;
  bool _loading = false;
  Map<String, dynamic>? _calendarData;
  Map<String, dynamic>? _statsData;
  String? _selectedSubjectId;
  List<Map<String, dynamic>> _subjects = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = now.month;
    _currentYear = now.year;
    _loadStats();
    _loadCalendar();
  }

  Future<void> _loadStats() async {
    try {
      final data = await ApiService().getStudentStats(widget.studentId);
      setState(() {
        _statsData = data;
        _subjects = (data['stats'] as List).map((s) => {
          'id': s['subject_id'] as String,
          'name': s['subject_name'] as String,
          'code': s['subject_code'] as String?,
          'percentage': s['percentage'] as num,
          'lecture_type': s['lecture_type'] as String,
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadCalendar() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getStudentCalendar(
        studentId: widget.studentId,
        month: _currentMonth,
        year: _currentYear,
        subjectId: _selectedSubjectId,
      );
      setState(() => _calendarData = data);
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth += delta;
      if (_currentMonth > 12) {
        _currentMonth = 1;
        _currentYear++;
      } else if (_currentMonth < 1) {
        _currentMonth = 12;
        _currentYear--;
      }
    });
    _loadCalendar();
  }

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats summary cards
            if (_statsData != null) _buildStatsSummary(),
            const SizedBox(height: 16),

            // Subject filter
            if (_subjects.isNotEmpty) ...[
              const SectionHeader(title: 'Filter by Subject'),
              const SizedBox(height: 8),
              _buildSubjectFilter(),
              const SizedBox(height: 16),
            ],

            // Month navigation
            _buildMonthNav(),
            const SizedBox(height: 12),

            // Calendar grid
            _loading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ))
                : _buildCalendarGrid(),

            const SizedBox(height: 16),

            // Legend
            _buildLegend(),

            const SizedBox(height: 20),

            // Per-subject breakdown
            if (_statsData != null) _buildSubjectBreakdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    final stats = _statsData!['stats'] as List;
    if (stats.isEmpty) return const SizedBox.shrink();

    int totalHeld = 0;
    int totalAttended = 0;
    int belowThreshold = 0;

    for (final s in stats) {
      totalHeld += (s['total_held'] as num).toInt();
      totalAttended += (s['attended'] as num).toInt();
      if (s['is_below_threshold'] == true) belowThreshold++;
    }

    final overallPct = totalHeld > 0 ? (totalAttended / totalHeld * 100) : 0.0;

    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            label: 'Overall',
            value: '${overallPct.toStringAsFixed(1)}%',
            color: overallPct >= 75
                ? const Color(AppColors.success)
                : overallPct >= 60
                    ? const Color(AppColors.warning)
                    : const Color(AppColors.error),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'Attended',
            value: '$totalAttended / $totalHeld',
            color: const Color(AppColors.primary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: 'At Risk',
            value: '$belowThreshold',
            color: belowThreshold > 0
                ? const Color(AppColors.error)
                : const Color(AppColors.success),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', null),
          ..._subjects.map((s) => _buildFilterChip(
            s['code'] ?? s['name'],
            s['id'],
          )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? subjectId) {
    final isSelected = _selectedSubjectId == subjectId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedSubjectId = subjectId);
          _loadCalendar();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(AppColors.primary)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(AppColors.primary)
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          '${_monthNames[_currentMonth]} $_currentYear',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentYear, _currentMonth, 1);
    final daysInMonth = DateTime(_currentYear, _currentMonth + 1, 0).day;
    // Monday = 1, Sunday = 7
    final startWeekday = firstDay.weekday; // 1 = Monday
    final calendar = _calendarData?['calendar'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        // Day labels
        Row(
          children: _dayLabels.map((d) => Expanded(
            child: Center(
              child: Text(d,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 8),

        // Calendar cells
        ..._buildWeekRows(startWeekday, daysInMonth, calendar),
      ],
    );
  }

  List<Widget> _buildWeekRows(int startWeekday, int daysInMonth, Map<String, dynamic> calendar) {
    final rows = <Widget>[];
    int dayCounter = 1;
    final today = DateTime.now();

    for (int week = 0; week < 6; week++) {
      if (dayCounter > daysInMonth) break;
      final cells = <Widget>[];

      for (int weekday = 1; weekday <= 7; weekday++) {
        if ((week == 0 && weekday < startWeekday) || dayCounter > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 52)));
        } else {
          final day = dayCounter;
          final dateStr = '$_currentYear-${_currentMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          final dayData = calendar[dateStr];
          final isToday = today.year == _currentYear &&
              today.month == _currentMonth &&
              today.day == day;

          cells.add(Expanded(child: _buildDayCell(day, dateStr, dayData, isToday)));
          dayCounter++;
        }
      }

      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: cells),
      ));
    }
    return rows;
  }

  Widget _buildDayCell(int day, String dateStr, dynamic dayData, bool isToday) {
    final sessions = (dayData != null ? dayData['sessions'] as List? : null) ?? [];
    final events = (dayData != null ? dayData['events'] as List? : null) ?? [];

    // Determine dot colors
    final dots = <Color>[];
    for (final s in sessions) {
      final status = s['status'] as String?;
      if (status == 'present') {
        dots.add(const Color(AppColors.present));
      } else {
        dots.add(const Color(AppColors.absent));
      }
    }
    for (final e in events) {
      final type = e['type'] as String?;
      switch (type) {
        case 'holiday':
          dots.add(const Color(AppColors.holiday));
          break;
        case 'cancelled':
          dots.add(const Color(AppColors.cancelled));
          break;
        case 'exam':
          dots.add(const Color(AppColors.exam));
          break;
        case 'fest':
          dots.add(const Color(AppColors.fest));
          break;
        default:
          dots.add(const Color(AppColors.info));
      }
    }

    Color? bgColor;
    if (dots.length == 1) {
      bgColor = dots.first.withOpacity(0.12);
    } else if (dots.isNotEmpty) {
      // Mixed day - use a neutral tint
      bgColor = Theme.of(context).colorScheme.primary.withOpacity(0.06);
    }

    return GestureDetector(
      onTap: dayData != null ? () => _showDayDetail(dateStr, dayData) : null,
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(color: const Color(AppColors.primary), width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday
                    ? const Color(AppColors.primary)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(
                        dots.isEmpty ? 0.3 : 0.8),
              ),
            ),
            if (dots.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: dots.take(4).map((c) => Container(
                  width: 5, height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDayDetail(String dateStr, dynamic dayData) {
    final sessions = (dayData['sessions'] as List?) ?? [];
    final events = (dayData['events'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(dateStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...sessions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: s['status'] == 'present'
                          ? const Color(AppColors.present)
                          : const Color(AppColors.absent),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s['subject_name'] ?? 'Unknown')),
                  Text(
                    s['status'] == 'present' ? 'Present' : 'Absent',
                    style: TextStyle(
                      color: s['status'] == 'present'
                          ? const Color(AppColors.present)
                          : const Color(AppColors.absent),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )),
            ...events.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _eventColor(e['type']),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e['title'] ?? '')),
                  Text(
                    _eventLabel(e['type']),
                    style: TextStyle(
                      color: _eventColor(e['type']),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )),
            if (sessions.isEmpty && events.isEmpty)
              const Text('No records for this day'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Color _eventColor(String? type) {
    switch (type) {
      case 'holiday': return const Color(AppColors.holiday);
      case 'cancelled': return const Color(AppColors.cancelled);
      case 'exam': return const Color(AppColors.exam);
      case 'fest': return const Color(AppColors.fest);
      default: return const Color(AppColors.info);
    }
  }

  String _eventLabel(String? type) {
    switch (type) {
      case 'holiday': return 'Holiday';
      case 'cancelled': return 'Cancelled';
      case 'exam': return 'Exam';
      case 'fest': return 'Fest';
      default: return type ?? '';
    }
  }

  Widget _buildLegend() {
    final items = [
      ('Present', const Color(AppColors.present)),
      ('Absent', const Color(AppColors.absent)),
      ('Holiday', const Color(AppColors.holiday)),
      ('Cancelled', const Color(AppColors.cancelled)),
      ('Exam', const Color(AppColors.exam)),
      ('Fest', const Color(AppColors.fest)),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: item.$2, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(item.$1, style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          )),
        ],
      )).toList(),
    );
  }

  Widget _buildSubjectBreakdown() {
    final stats = _statsData!['stats'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Subject Breakdown'),
        const SizedBox(height: 12),
        ...stats.map((s) {
          final pct = (s['percentage'] as num).toDouble();
          final isBelowThreshold = s['is_below_threshold'] == true;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    width: 4, height: 50,
                    decoration: BoxDecoration(
                      color: pct >= 75
                          ? const Color(AppColors.success)
                          : pct >= 60
                              ? const Color(AppColors.warning)
                              : const Color(AppColors.error),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s['subject_name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                            LectureTypeBadge(type: s['lecture_type'] ?? 'lecture'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${s['attended']}/${s['total_held']} sessions'
                          '${s['faculty_name'] != null ? ' - ${s['faculty_name']}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AttendancePercent(percentage: pct),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// Small stat card for the summary row
class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(value,
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
            style: TextStyle(
              fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Add navigation from student dashboard**

In `flutter_app/lib/screens/student/student_dashboard.dart`:
- Add import for `attendance_calendar_screen.dart`
- Add an `ActionCard` or navigation button between the enrollment banner and the BLE scanner section to navigate to the calendar

Insert after the enrollment banner block (around line 303), before the BLE Scanner:

```dart
// Attendance tracking card
GestureDetector(
  onTap: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => AttendanceCalendarScreen(
      studentId: user.id,
      studentName: user.fullName,
    ),
  )),
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(AppColors.success).withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(AppColors.success).withOpacity(0.15)),
    ),
    child: Row(
      children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: const Color(AppColors.success).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.calendar_month_rounded,
              color: Color(AppColors.success), size: 22),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Attendance',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              SizedBox(height: 2),
              Text('View calendar & subject breakdown',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), size: 20),
      ],
    ),
  ),
),
const SizedBox(height: 14),
```

**Step 3: Commit**
```
git add -A && git commit -m "feat: add attendance tracking calendar screen with Duolingo-inspired UI"
```

---

## Feature 2: Profile Page for Each User

**Concept:** A profile screen accessible from every dashboard (via the avatar popup menu). Shows user info, department, enrollment status, face enrollment status, attendance summary (for students). Allows editing name and batch info.

### Task 2A: Create the Profile Screen

**Files:**
- Create: `flutter_app/lib/screens/profile/profile_screen.dart`
- Modify: `flutter_app/lib/screens/student/student_dashboard.dart` (add profile nav)
- Modify: `flutter_app/lib/screens/faculty/faculty_dashboard.dart` (add profile nav)
- Modify: `flutter_app/lib/screens/admin/admin_dashboard.dart` (add profile nav)
- Modify: `flutter_app/lib/screens/hod/hod_dashboard.dart` (add profile nav)
- Modify: `flutter_app/lib/screens/principal/principal_dashboard.dart` (add profile nav)

**Step 1: Create the profile screen**

Create `flutter_app/lib/screens/profile/profile_screen.dart`:

```dart
// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;
  bool _editing = false;
  Map<String, dynamic>? _statsData;
  Map<String, dynamic>? _enrollmentStatus;

  late TextEditingController _nameController;
  late TextEditingController _practicalBatchController;
  late TextEditingController _tutorialBatchController;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _nameController = TextEditingController(text: user.fullName);
    _practicalBatchController = TextEditingController(text: user.practicalBatch ?? '');
    _tutorialBatchController = TextEditingController(text: user.tutorialBatch ?? '');

    if (user.role == 'student') {
      _loadStudentData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _practicalBatchController.dispose();
    _tutorialBatchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    final user = context.read<AuthProvider>().user!;
    try {
      final stats = await ApiService().getStudentStats(user.id);
      final enrollment = await ApiService().getEnrollmentStatus();
      setState(() {
        _statsData = stats;
        _enrollmentStatus = enrollment;
      });
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    try {
      await ApiService().updateProfile(
        fullName: _nameController.text.trim(),
        practicalBatch: _practicalBatchController.text.trim().isEmpty
            ? null : _practicalBatchController.text.trim(),
        tutorialBatch: _tutorialBatchController.text.trim().isEmpty
            ? null : _tutorialBatchController.text.trim(),
      );
      // Refresh user data
      await context.read<AuthProvider>().tryAutoLogin();
      setState(() => _editing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: Color(AppColors.success),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(AppColors.error),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    setState(() => _loading = false);
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return const Color(AppColors.adminColor);
      case 'faculty': return const Color(AppColors.facultyColor);
      case 'student': return const Color(AppColors.studentColor);
      case 'hod': return const Color(AppColors.hodColor);
      case 'principal': return const Color(AppColors.principalColor);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final color = _roleColor(user.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: () => setState(() => _editing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => setState(() => _editing = false),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar + name
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w800, color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (!_editing)
              Text(user.fullName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))
            else
              AppTextField(
                label: 'Full Name',
                controller: _nameController,
                prefixIcon: Icons.person_rounded,
              ),
            const SizedBox(height: 4),
            RoleBadge(role: user.role),
            const SizedBox(height: 24),

            // Info cards
            _buildInfoSection(user),

            if (_editing && user.role == 'student') ...[
              const SizedBox(height: 16),
              AppTextField(
                label: 'Practical Batch',
                controller: _practicalBatchController,
                prefixIcon: Icons.science_rounded,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Tutorial Batch',
                controller: _tutorialBatchController,
                prefixIcon: Icons.school_rounded,
              ),
            ],

            if (_editing) ...[
              const SizedBox(height: 20),
              AppButton(
                label: 'Save Changes',
                isLoading: _loading,
                onPressed: _saveProfile,
                icon: Icons.save_rounded,
              ),
            ],

            // Student-specific sections
            if (user.role == 'student' && !_editing) ...[
              const SizedBox(height: 24),
              _buildFaceEnrollmentStatus(),
              if (_statsData != null) ...[
                const SizedBox(height: 20),
                _buildAttendanceSummary(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(user) {
    final items = <MapEntry<String, String>>[];

    items.add(MapEntry('Email', user.email));

    if (user.departmentName != null) {
      items.add(MapEntry('Department', user.departmentName!));
    }

    if (user.enrollmentNumber != null) {
      items.add(MapEntry('Enrollment No.', user.enrollmentNumber!));
    }

    if (user.employeeId != null) {
      items.add(MapEntry('Employee ID', user.employeeId!));
    }

    if (user.year != null) {
      items.add(MapEntry('Year', user.yearDisplay));
    }

    if (user.practicalBatch != null && !_editing) {
      items.add(MapEntry('Practical Batch', user.practicalBatch!));
    }

    if (user.tutorialBatch != null && !_editing) {
      items.add(MapEntry('Tutorial Batch', user.tutorialBatch!));
    }

    items.add(MapEntry('Status', user.statusDisplay));
    items.add(MapEntry('Joined', user.createdAt.split('T').first));

    return AppCard(
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(item.key,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(item.value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildFaceEnrollmentStatus() {
    final status = _enrollmentStatus?['status'] ?? 'not_submitted';
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'approved':
        color = const Color(AppColors.success);
        label = 'Face Enrolled';
        icon = Icons.check_circle_rounded;
        break;
      case 'pending':
        color = const Color(AppColors.warning);
        label = 'Enrollment Pending Review';
        icon = Icons.hourglass_top_rounded;
        break;
      default:
        color = const Color(AppColors.error);
        label = 'Face Not Enrolled';
        icon = Icons.cancel_rounded;
    }

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Face Enrollment',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    final stats = _statsData!['stats'] as List;
    if (stats.isEmpty) return const SizedBox.shrink();

    int totalHeld = 0;
    int totalAttended = 0;
    for (final s in stats) {
      totalHeld += (s['total_held'] as num).toInt();
      totalAttended += (s['attended'] as num).toInt();
    }
    final overallPct = totalHeld > 0 ? (totalAttended / totalHeld * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Attendance Overview'),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('${overallPct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800,
                            color: overallPct >= 75
                                ? const Color(AppColors.success)
                                : const Color(AppColors.error),
                          ),
                        ),
                        const Text('Overall', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('$totalAttended',
                          style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800,
                            color: Color(AppColors.primary)),
                        ),
                        const Text('Attended', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('$totalHeld',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                        const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

**Step 2: Add profile navigation to all 5 dashboards**

In each dashboard's PopupMenuButton (before the Sign Out item), add:

```dart
PopupMenuItem(
  child: const Row(children: [
    Icon(Icons.account_circle_rounded, size: 18),
    SizedBox(width: 8),
    Text('Profile'),
  ]),
  onTap: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => const ProfileScreen(),
  )),
),
```

And add the import:
```dart
import '../profile/profile_screen.dart';
```

Do this in:
- `student_dashboard.dart` (popup at line ~239)
- `faculty_dashboard.dart` (popup at line ~191)
- `admin_dashboard.dart` (popup at line ~69)
- `hod_dashboard.dart` (find the popup menu)
- `principal_dashboard.dart` (find the popup menu)

**Step 3: Commit**
```
git add -A && git commit -m "feat: add user profile screen with edit capability and attendance overview"
```

---

## Feature 3: Admin Events Management + Filters

**Concept:** Admin/principal/HOD can declare holidays, exams, fests, expert talks. When a holiday is declared, it should be reflected in student calendars. A dedicated events management screen with create/delete, and a cancelled lectures section for faculty.

### Task 3A: Create the Events Management Screen

**Files:**
- Create: `flutter_app/lib/screens/admin/admin_events_screen.dart`
- Modify: `flutter_app/lib/screens/admin/admin_dashboard.dart` (add nav)
- Modify: `flutter_app/lib/screens/principal/principal_dashboard.dart` (add nav)
- Modify: `flutter_app/lib/screens/hod/hod_dashboard.dart` (add nav)

**Step 1: Create the events management screen**

Create `flutter_app/lib/screens/admin/admin_events_screen.dart`:

```dart
// lib/screens/admin/admin_events_screen.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _events = [];
  List<dynamic> _cancelled = [];
  List<dynamic> _departments = [];
  bool _loading = false;
  String? _filterType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final events = await ApiService().getEvents();
      final cancelled = await ApiService().getCancelledLectures();
      final departments = await ApiService().getDepartments();
      setState(() {
        _events = events;
        _cancelled = cancelled;
        _departments = departments;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(AppColors.error) : const Color(AppColors.success),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await ApiService().deleteEvent(eventId);
      _showSnack('Event deleted');
      _loadData();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  Future<void> _restoreLecture(String cancelId) async {
    try {
      await ApiService().restoreLecture(cancelId);
      _showSnack('Lecture restored');
      _loadData();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  void _showCreateEventDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'holiday';
    String? selectedDeptId;
    int? selectedYear;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create Event', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(label: 'Title', controller: titleCtrl, prefixIcon: Icons.title_rounded),
                const SizedBox(height: 12),

                // Date picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(ctx).colorScheme.outline.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18),
                        const SizedBox(width: 10),
                        Text('${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Event type
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Event Type'),
                  items: ['holiday', 'exam', 'fest', 'expert_talk'].map((t) =>
                    DropdownMenuItem(value: t, child: Text(EventTypes.display(t)))
                  ).toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),

                // Department (optional)
                DropdownButtonFormField<String?>(
                  value: selectedDeptId,
                  decoration: const InputDecoration(labelText: 'Department (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Departments')),
                    ..._departments.map((d) =>
                      DropdownMenuItem(value: d['id'] as String, child: Text(d['name'] as String))
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedDeptId = v),
                ),
                const SizedBox(height: 12),

                // Year (optional)
                DropdownButtonFormField<int?>(
                  value: selectedYear,
                  decoration: const InputDecoration(labelText: 'Year (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Years')),
                    ...[1, 2, 3, 4].map((y) =>
                      DropdownMenuItem(value: y, child: Text('Year $y'))
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedYear = v),
                ),
                const SizedBox(height: 12),

                AppTextField(label: 'Description (optional)', controller: descCtrl,
                    prefixIcon: Icons.description_rounded, maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await ApiService().createEvent(
                    title: titleCtrl.text.trim(),
                    date: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                    eventType: selectedType,
                    departmentId: selectedDeptId,
                    year: selectedYear,
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  );
                  _showSnack('Event created');
                  _loadData();
                } catch (e) {
                  _showSnack(e.toString(), isError: true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Color _eventTypeColor(String type) {
    switch (type) {
      case 'holiday': return const Color(AppColors.holiday);
      case 'exam': return const Color(AppColors.exam);
      case 'fest': return const Color(AppColors.fest);
      case 'expert_talk': return const Color(AppColors.info);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _filterType == null
        ? _events
        : _events.where((e) => e['event_type'] == _filterType).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events & Holidays'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Events'),
            Tab(text: 'Cancelled Lectures'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateEventDialog,
        backgroundColor: const Color(AppColors.primary),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Events tab
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Filter chips
                      FilterChipRow(
                        options: ['holiday', 'exam', 'fest', 'expert_talk'],
                        selected: _filterType,
                        onSelected: (v) => setState(() => _filterType = v),
                      ),
                      const SizedBox(height: 16),

                      if (filteredEvents.isEmpty)
                        const EmptyState(
                          icon: Icons.event_rounded,
                          title: 'No events',
                          subtitle: 'Tap + to create one',
                        )
                      else
                        ...filteredEvents.map((event) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Dismissible(
                            key: Key(event['id']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: const Color(AppColors.error).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_rounded, color: Color(AppColors.error)),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Event?'),
                                  content: Text('Delete "${event['title']}"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(AppColors.error)),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ) ?? false;
                            },
                            onDismissed: (_) => _deleteEvent(event['id']),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Container(
                                    width: 4, height: 50,
                                    decoration: BoxDecoration(
                                      color: _eventTypeColor(event['event_type']),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(event['title'],
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _eventTypeColor(event['event_type']).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                EventTypes.display(event['event_type']),
                                                style: TextStyle(
                                                  color: _eventTypeColor(event['event_type']),
                                                  fontSize: 10, fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${event['date']}${event['department_name'] != null ? ' - ${event['department_name']}' : ' - All Depts'}'
                                          '${event['year'] != null ? ' - Year ${event['year']}' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                          ),
                                        ),
                                        if (event['description'] != null && event['description'].toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(event['description'],
                                              style: TextStyle(fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )),
                    ],
                  ),
                ),

                // Cancelled lectures tab
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: _cancelled.isEmpty
                      ? ListView(children: const [
                          EmptyState(
                            icon: Icons.event_available_rounded,
                            title: 'No cancelled lectures',
                          ),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _cancelled.length,
                          itemBuilder: (_, i) {
                            final c = _cancelled[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppCard(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4, height: 50,
                                      decoration: BoxDecoration(
                                        color: const Color(AppColors.cancelled),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c['date'] ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${c['cancelled_by_name'] ?? 'Unknown'}${c['reason'] != null ? ' - ${c['reason']}' : ''}',
                                            style: TextStyle(fontSize: 12,
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.restore_rounded, size: 20,
                                          color: Color(AppColors.primary)),
                                      onPressed: () => _restoreLecture(c['id']),
                                      tooltip: 'Restore',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
```

**Step 2: Add events navigation to admin dashboard**

In `admin_dashboard.dart`, add navigation card after the Attendance Reports card (around line 188):

```dart
const SizedBox(height: 10),
ActionCard(
  icon: Icons.event_rounded,
  title: 'Events & Holidays',
  subtitle: 'Manage college events',
  color: const Color(AppColors.holiday),
  onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => const AdminEventsScreen())),
),
```

And add import: `import 'admin_events_screen.dart';`

Similarly add to `principal_dashboard.dart` and `hod_dashboard.dart`.

**Step 3: Add cancel lecture to faculty dashboard**

In `faculty_dashboard.dart`, add a long-press action on each slot card to cancel a lecture. Add a method:

```dart
void _showCancelDialog(Map<String, dynamic> slot) {
  final reasonCtrl = TextEditingController();
  DateTime selectedDate = DateTime.now();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Lecture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cancel ${slot['subject_name']} for:'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setDialogState(() => selectedDate = picked);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(ctx).colorScheme.outline.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'),
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(label: 'Reason (optional)', controller: reasonCtrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService().cancelLecture(
                  slotId: slot['id'],
                  date: '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                  reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                );
                _showSnack('Lecture cancelled');
              } catch (e) {
                _showSnack(e.toString(), isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(AppColors.error)),
            child: const Text('Cancel Lecture'),
          ),
        ],
      ),
    ),
  );
}
```

Wire this to a long-press on the slot card.

**Step 4: Commit**
```
git add -A && git commit -m "feat: add events management screen with create/delete and lecture cancellation"
```

---

## Feature 4: Faculty Class Attendance View

**Concept:** Faculty can tap a slot to see class-wide attendance stats - per student attendance %, below-threshold highlighting, session history calendar. Uses the existing `/stats/class/{slot_id}` and `/stats/class/calendar/{slot_id}` APIs.

### Task 4A: Create the Class Attendance Screen

**Files:**
- Create: `flutter_app/lib/screens/faculty/class_attendance_screen.dart`
- Modify: `flutter_app/lib/screens/faculty/faculty_dashboard.dart` (add navigation)

**Step 1: Create the class attendance screen**

Create `flutter_app/lib/screens/faculty/class_attendance_screen.dart`:

```dart
// lib/screens/faculty/class_attendance_screen.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';
import '../student/attendance_calendar_screen.dart';

class ClassAttendanceScreen extends StatefulWidget {
  final String slotId;
  final String subjectName;

  const ClassAttendanceScreen({
    super.key,
    required this.slotId,
    required this.subjectName,
  });

  @override
  State<ClassAttendanceScreen> createState() => _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends State<ClassAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _classStats;
  Map<String, dynamic>? _calendarData;
  bool _loading = false;
  late int _currentMonth;
  late int _currentYear;
  String _sortBy = 'name'; // name, percentage, attendance

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _currentMonth = now.month;
    _currentYear = now.year;
    _loadStats();
    _loadCalendar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getClassStats(widget.slotId);
      setState(() => _classStats = data);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _loadCalendar() async {
    try {
      final data = await ApiService().getClassCalendar(
        slotId: widget.slotId,
        month: _currentMonth,
        year: _currentYear,
      );
      setState(() => _calendarData = data);
    } catch (_) {}
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth += delta;
      if (_currentMonth > 12) { _currentMonth = 1; _currentYear++; }
      else if (_currentMonth < 1) { _currentMonth = 12; _currentYear--; }
    });
    _loadCalendar();
  }

  List<dynamic> get _sortedStudents {
    final students = List.from(_classStats?['students'] ?? []);
    switch (_sortBy) {
      case 'percentage':
        students.sort((a, b) => (a['percentage'] as num).compareTo(b['percentage'] as num));
        break;
      case 'attendance':
        students.sort((a, b) => (b['attended'] as num).compareTo(a['attended'] as num));
        break;
      default:
        students.sort((a, b) => (a['full_name'] as String).compareTo(b['full_name'] as String));
    }
    return students;
  }

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Sessions'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStudentsTab(),
                _buildSessionsTab(),
              ],
            ),
    );
  }

  Widget _buildStudentsTab() {
    if (_classStats == null) {
      return const Center(child: Text('No data available'));
    }

    final students = _sortedStudents;
    final totalHeld = _classStats!['total_held'] as int? ?? 0;
    final belowThreshold = students.where((s) => s['is_below_threshold'] == true).length;

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary row
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Students',
                  value: '${students.length}',
                  icon: Icons.people_rounded,
                  color: const Color(AppColors.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'Sessions Held',
                  value: '$totalHeld',
                  icon: Icons.calendar_today_rounded,
                  color: const Color(AppColors.facultyColor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'At Risk',
                  value: '$belowThreshold',
                  icon: Icons.warning_rounded,
                  color: belowThreshold > 0
                      ? const Color(AppColors.error)
                      : const Color(AppColors.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sort options
          Row(
            children: [
              const Text('Sort by:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              ...['name', 'percentage', 'attendance'].map((s) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _sortBy = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _sortBy == s
                          ? const Color(AppColors.primary)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _sortBy == s
                            ? const Color(AppColors.primary)
                            : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      s[0].toUpperCase() + s.substring(1),
                      style: TextStyle(
                        fontSize: 11,
                        color: _sortBy == s ? Colors.white : null,
                        fontWeight: _sortBy == s ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              )),
            ],
          ),
          const SizedBox(height: 14),

          // Student list
          ...students.map((student) {
            final pct = (student['percentage'] as num).toDouble();
            final isBelowThreshold = student['is_below_threshold'] == true;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AttendanceCalendarScreen(
                    studentId: student['student_id'],
                    studentName: student['full_name'],
                  ),
                )),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 50,
                      decoration: BoxDecoration(
                        color: isBelowThreshold
                            ? const Color(AppColors.error)
                            : const Color(AppColors.success),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(student['full_name'],
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            '${student['enrollment_number'] ?? 'N/A'} - ${student['attended']}/$totalHeld sessions',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AttendancePercent(percentage: pct),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    final sessions = (_calendarData?['sessions'] as List?) ?? [];
    final cancelled = (_calendarData?['cancelled'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Month nav
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
            Text('${_monthNames[_currentMonth]} $_currentYear',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
          ],
        ),
        const SizedBox(height: 12),

        if (sessions.isEmpty && cancelled.isEmpty)
          const EmptyState(
            icon: Icons.event_note_rounded,
            title: 'No sessions this month',
          )
        else ...[
          ...sessions.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    width: 4, height: 50,
                    decoration: BoxDecoration(
                      color: const Color(AppColors.success),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['session_date'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          '${s['present_count']} present'
                          '${s['status'] == 'live' ? ' (Live)' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (s['status'] == 'live')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(AppColors.success).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Color(AppColors.success), size: 6),
                          SizedBox(width: 4),
                          Text('LIVE', style: TextStyle(
                            color: Color(AppColors.success),
                            fontSize: 10, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          )),
          ...cancelled.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    width: 4, height: 50,
                    decoration: BoxDecoration(
                      color: const Color(AppColors.cancelled),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['date'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('Cancelled${c['reason'] != null ? ': ${c['reason']}' : ''}',
                          style: TextStyle(fontSize: 12,
                            color: const Color(AppColors.cancelled)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ],
    );
  }
}
```

**Step 2: Add navigation from faculty dashboard**

In `faculty_dashboard.dart`, add a long-press or info button on slot cards. Wrap the existing `AppCard` so tapping the slot name area navigates to `ClassAttendanceScreen`:

```dart
import 'class_attendance_screen.dart';
```

Add an info icon button on each slot card that navigates to class attendance view. In the slot card row, after the Start button, add a GestureDetector on the card itself:

Change the `AppCard` for each slot to have an `onTap` that navigates to class stats (when not broadcasting):

```dart
AppCard(
  onTap: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => ClassAttendanceScreen(
      slotId: slot['id'],
      subjectName: '${slot['subject_name']} (${slot['subject_code'] ?? ''})',
    ),
  )),
  child: Row(/* existing content */),
),
```

**Step 3: Commit**
```
git add -A && git commit -m "feat: add faculty class attendance view with student stats and session history"
```

---

## Summary of All Tasks

| # | Feature | New Files | Modified Files |
|---|---------|-----------|----------------|
| 0 | Pre-work: API methods + deps | - | `api_service.dart`, `requirements.txt`, `main.py` |
| 1 | Attendance Calendar | `attendance_calendar_screen.dart` | `student_dashboard.dart` |
| 2 | Profile Page | `profile_screen.dart` | All 5 dashboards |
| 3 | Events Management | `admin_events_screen.dart` | `admin_dashboard.dart`, `principal_dashboard.dart`, `hod_dashboard.dart`, `faculty_dashboard.dart` |
| 4 | Faculty Class View | `class_attendance_screen.dart` | `faculty_dashboard.dart` |

**Total new Dart files:** 4
**Total modified files:** ~12
**Backend changes:** `requirements.txt` + 1 new endpoint in `main.py`

---

## Execution Order

Tasks can be parallelized in pairs:
- **Task 0** must go first (shared dependency)
- **Task 1** and **Task 2** are independent (can be parallel)
- **Task 3** and **Task 4** are independent (can be parallel)

```
Task 0 (pre-work)
   |
   ├── Task 1 (calendar) ── ─┐
   └── Task 2 (profile) ─────┤
                              ├── Task 3 (events) ──── ─┐
                              └── Task 4 (class view) ──┤
                                                        └── Done
```
