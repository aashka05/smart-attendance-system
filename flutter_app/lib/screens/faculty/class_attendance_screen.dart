// lib/screens/faculty/class_attendance_screen.dart

import 'package:flutter/material.dart';
import '../../config.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../student/attendance_calendar_screen.dart';
import 'session_attendees_screen.dart';

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
  final ApiService _api = ApiService();

  // Students tab state
  Map<String, dynamic>? _classStats;
  List<dynamic> _students = [];
  bool _statsLoading = true;
  String _sortBy = 'name'; // name, percentage, attendance

  // Sessions tab state
  late int _currentMonth;
  late int _currentYear;
  Map<String, dynamic>? _calendarData;
  List<dynamic> _sessions = [];
  List<dynamic> _cancelled = [];
  bool _calendarLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _currentMonth = now.month;
    _currentYear = now.year;
    _loadClassStats();
    _loadClassCalendar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClassStats() async {
    setState(() => _statsLoading = true);
    try {
      final data = await _api.getClassStats(widget.slotId);
      setState(() {
        _classStats = data;
        _students = (data['students'] as List?) ?? [];
        _statsLoading = false;
      });
    } catch (e) {
      setState(() => _statsLoading = false);
      _showSnack(e.toString(), isError: true);
    }
  }

  Future<void> _loadClassCalendar() async {
    setState(() => _calendarLoading = true);
    try {
      final data = await _api.getClassCalendar(
        slotId: widget.slotId,
        month: _currentMonth,
        year: _currentYear,
      );
      setState(() {
        _calendarData = data;
        _sessions = (data['sessions'] as List?) ?? [];
        _cancelled = (data['cancelled'] as List?) ?? [];
        _calendarLoading = false;
      });
    } catch (e) {
      setState(() => _calendarLoading = false);
      _showSnack(e.toString(), isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? const Color(AppColors.error) : const Color(AppColors.success),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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
    _loadClassCalendar();
  }

  // ─────────────────────────────────────────
  // COMPUTED VALUES
  // ─────────────────────────────────────────

  int get _totalStudents => _students.length;

  int get _totalSessionsHeld {
    if (_classStats == null) return 0;
    return (_classStats!['total_held'] as num?)?.toInt() ?? 0;
  }

  int get _atRiskCount {
    int count = 0;
    for (final s in _students) {
      if (s['is_below_threshold'] == true) count++;
    }
    return count;
  }

  List<dynamic> get _sortedStudents {
    final list = List<dynamic>.from(_students);
    switch (_sortBy) {
      case 'name':
        list.sort((a, b) => ((a['full_name'] ?? '') as String)
            .compareTo((b['full_name'] ?? '') as String));
        break;
      case 'percentage':
        list.sort((a, b) => ((b['percentage'] as num?) ?? 0)
            .compareTo((a['percentage'] as num?) ?? 0));
        break;
      case 'attendance':
        list.sort((a, b) => ((b['attended'] as num?) ?? 0)
            .compareTo((a['attended'] as num?) ?? 0));
        break;
    }
    return list;
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────

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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStudentsTab(),
          _buildSessionsTab(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // STUDENTS TAB
  // ─────────────────────────────────────────

  Widget _buildStudentsTab() {
    if (_statsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadClassStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsSummary(),
            const SizedBox(height: 20),
            _buildSortControls(),
            const SizedBox(height: 14),
            _buildStudentList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Students',
            value: '$_totalStudents',
            icon: Icons.people_rounded,
            color: const Color(AppColors.primary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            label: 'Sessions Held',
            value: '$_totalSessionsHeld',
            icon: Icons.event_available_rounded,
            color: const Color(AppColors.success),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            label: 'At Risk',
            value: '$_atRiskCount',
            icon: Icons.warning_amber_rounded,
            color: const Color(AppColors.error),
          ),
        ),
      ],
    );
  }

  Widget _buildSortControls() {
    return Row(
      children: [
        Text(
          'Sort by:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(width: 10),
        _sortChip('name', 'Name'),
        const SizedBox(width: 8),
        _sortChip('percentage', 'Percentage'),
        const SizedBox(width: 8),
        _sortChip('attendance', 'Attendance'),
      ],
    );
  }

  Widget _sortChip(String value, String label) {
    final isActive = _sortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(AppColors.primary)
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    if (_students.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No students found',
        subtitle: 'No students are enrolled in this slot yet.',
      );
    }

    final sorted = _sortedStudents;
    return Column(
      children: sorted.map((student) {
        final percentage =
            (student['percentage'] as num?)?.toDouble() ?? 0.0;
        final isBelowThreshold = student['is_below_threshold'] == true;
        final attended = (student['attended'] as num?)?.toInt() ?? 0;
        final totalHeld = (student['total_held'] as num?)?.toInt() ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AttendanceCalendarScreen(
                  studentId: student['student_id'] ?? '',
                  studentName: student['full_name'] ?? '',
                  subjectId: _classStats?['subject_id'],
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isBelowThreshold
                        ? const Color(AppColors.error)
                        : const Color(AppColors.success),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['full_name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${student['enrollment_number'] ?? ''}  $attended/$totalHeld sessions',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AttendancePercent(percentage: percentage),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────
  // SESSIONS TAB
  // ─────────────────────────────────────────

  Widget _buildSessionsTab() {
    return RefreshIndicator(
      onRefresh: _loadClassCalendar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonthNav(),
            const SizedBox(height: 20),
            _calendarLoading
                ? const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _buildSessionList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNav() {
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        Text(
          '${monthNames[_currentMonth]} $_currentYear',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
          style: IconButton.styleFrom(
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionList() {
    if (_sessions.isEmpty && _cancelled.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'No sessions this month',
        subtitle: 'No attendance sessions or cancelled lectures found.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sessions
        ..._sessions.map((session) {
          final status = (session['status'] as String?) ?? '';
          final isLive = status == 'live';
          final presentCount =
              (session['present_count'] as num?)?.toInt() ?? 0;
          final sessionDate = session['session_date'] ?? '';
          final sessionId = session['id'] ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SessionAttendeesScreen(
                      sessionId: sessionId,
                      sessionDate: sessionDate,
                      subjectName: widget.subjectName,
                    ),
                  ),
                );
              },
              child: AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(AppColors.success),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatSessionDate(sessionDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$presentCount present',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(AppColors.success).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle,
                                color: Color(AppColors.success), size: 7),
                            SizedBox(width: 5),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Color(AppColors.success),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),

        // Cancelled lectures
        ..._cancelled.map((cancel) {
          final date = cancel['date'] ?? '';
          final reason = cancel['reason'] ?? 'No reason provided';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(AppColors.cancelled),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatSessionDate(date),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reason,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatSessionDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
