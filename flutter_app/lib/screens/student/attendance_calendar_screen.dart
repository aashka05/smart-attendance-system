// lib/screens/student/attendance_calendar_screen.dart

import 'package:flutter/material.dart';
import '../../config.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? subjectId;

  const AttendanceCalendarScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.subjectId,
  });

  @override
  State<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  final ApiService _api = ApiService();

  // Stats data
  Map<String, dynamic>? _statsData;
  List<dynamic> _subjectStats = [];
  bool _statsLoading = true;

  // Calendar data
  Map<String, dynamic> _calendarData = {};
  bool _calendarLoading = true;

  // Filters
  String? _selectedSubjectId;
  late int _currentMonth;
  late int _currentYear;

  // Subject map for chips: subjectId -> {name, code}
  final Map<String, Map<String, String>> _subjectMap = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = now.month;
    _currentYear = now.year;
    _selectedSubjectId = widget.subjectId; // Set initial filter to subjectId if provided
    _loadStats();
    _loadCalendar();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final data = await _api.getStudentStats(widget.studentId);
      final stats = (data['stats'] as List?) ?? [];
      _subjectMap.clear();
      for (final s in stats) {
        final sid = s['subject_id'] as String? ?? '';
        if (sid.isNotEmpty) {
          _subjectMap[sid] = {
            'name': s['subject_name'] ?? '',
            'code': s['subject_code'] ?? '',
          };
        }
      }
      setState(() {
        _statsData = data;
        _subjectStats = stats;
        _statsLoading = false;
      });
    } catch (e) {
      setState(() => _statsLoading = false);
      _showSnack(e.toString(), isError: true);
    }
  }

  Future<void> _loadCalendar() async {
    setState(() => _calendarLoading = true);
    try {
      final data = await _api.getStudentCalendar(
        studentId: widget.studentId,
        month: _currentMonth,
        year: _currentYear,
        subjectId: _selectedSubjectId,
      );
      final cal = data['calendar'] as Map<String, dynamic>? ?? {};
      setState(() {
        _calendarData = cal;
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
    _loadCalendar();
  }

  // ─────────────────────────────────────────
  // COMPUTED STATS
  // ─────────────────────────────────────────

  double get _overallPercentage {
    final filteredStats = _selectedSubjectId != null
        ? _subjectStats.where((s) => s['subject_id'] == _selectedSubjectId).toList()
        : _subjectStats;
    if (filteredStats.isEmpty) return 0;
    int totalHeld = 0;
    int totalAttended = 0;
    for (final s in filteredStats) {
      totalHeld += (s['total_held'] as num?)?.toInt() ?? 0;
      totalAttended += (s['attended'] as num?)?.toInt() ?? 0;
    }
    if (totalHeld == 0) return 0;
    return (totalAttended / totalHeld) * 100;
  }

  String get _attendedOfTotal {
    final filteredStats = _selectedSubjectId != null
        ? _subjectStats.where((s) => s['subject_id'] == _selectedSubjectId).toList()
        : _subjectStats;
    int totalHeld = 0;
    int totalAttended = 0;
    for (final s in filteredStats) {
      totalHeld += (s['total_held'] as num?)?.toInt() ?? 0;
      totalAttended += (s['attended'] as num?)?.toInt() ?? 0;
    }
    return '$totalAttended/$totalHeld';
  }

  int get _atRiskCount {
    final filteredStats = _selectedSubjectId != null
        ? _subjectStats.where((s) => s['subject_id'] == _selectedSubjectId).toList()
        : _subjectStats;
    int count = 0;
    for (final s in filteredStats) {
      if (s['is_below_threshold'] == true) count++;
    }
    return count;
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = widget.subjectId != null
        ? (_subjectMap[widget.subjectId]?['name'] ?? 'Attendance')
        : 'My Attendance';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _statsLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([_loadStats(), _loadCalendar()]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsSummary(),
                    const SizedBox(height: 20),
                    _buildSubjectFilterChips(),
                    const SizedBox(height: 20),
                    _buildMonthNav(),
                    const SizedBox(height: 14),
                    _buildCalendarGrid(),
                    const SizedBox(height: 16),
                    _buildLegend(),
                    const SizedBox(height: 24),
                    _buildSubjectBreakdown(),
                  ],
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────
  // 1. STATS SUMMARY ROW
  // ─────────────────────────────────────────

  Widget _buildStatsSummary() {
    return Row(
      children: [
        Expanded(child: _miniStatCard(
          '${_overallPercentage.toStringAsFixed(1)}%',
          'Overall',
          Icons.pie_chart_rounded,
          _overallPercentage >= 75
              ? const Color(AppColors.success)
              : _overallPercentage >= 60
                  ? const Color(AppColors.warning)
                  : const Color(AppColors.error),
        )),
        const SizedBox(width: 10),
        Expanded(child: _miniStatCard(
          _attendedOfTotal,
          'Attended',
          Icons.check_circle_outline_rounded,
          const Color(AppColors.info),
        )),
        const SizedBox(width: 10),
        Expanded(child: _miniStatCard(
          '$_atRiskCount',
          'At Risk',
          Icons.warning_amber_rounded,
          _atRiskCount > 0
              ? const Color(AppColors.error)
              : const Color(AppColors.success),
        )),
      ],
    );
  }

  Widget _miniStatCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 2. SUBJECT FILTER CHIPS
  // ─────────────────────────────────────────

  Widget _buildSubjectFilterChips() {
    if (widget.subjectId != null) return const SizedBox.shrink(); // Hide filters for faculty view
    final subjectIds = _subjectMap.keys.toList();
    final options = subjectIds
        .map((id) => _subjectMap[id]!['code'] ?? id)
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(
            label: 'All',
            isSelected: _selectedSubjectId == null,
            onTap: () {
              setState(() => _selectedSubjectId = null);
              _loadCalendar();
            },
          ),
          ...subjectIds.asMap().entries.map((entry) {
            final idx = entry.key;
            final sid = entry.value;
            return _filterChip(
              label: options[idx],
              isSelected: _selectedSubjectId == sid,
              onTap: () {
                setState(() => _selectedSubjectId = sid);
                _loadCalendar();
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
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
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // 3. MONTH NAVIGATION
  // ─────────────────────────────────────────

  Widget _buildMonthNav() {
    final monthNames = [
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

  // ─────────────────────────────────────────
  // 4. CALENDAR GRID
  // ─────────────────────────────────────────

  Widget _buildCalendarGrid() {
    if (_calendarLoading) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final firstDay = DateTime(_currentYear, _currentMonth, 1);
    final daysInMonth =
        DateTime(_currentYear, _currentMonth + 1, 0).day;
    // Monday = 1, Sunday = 7 in DateTime.weekday
    final startWeekday = firstDay.weekday; // 1=Mon .. 7=Sun
    final today = DateTime.now();

    const dayHeaders = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      children: [
        // Day headers
        Row(
          children: dayHeaders
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.45),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.85,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: _gridCellCount(startWeekday, daysInMonth),
          itemBuilder: (context, index) {
            final dayNum = index - (startWeekday - 1) + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const SizedBox();
            }

            final dateStr = _dateString(_currentYear, _currentMonth, dayNum);
            final dayData = _calendarData[dateStr] as Map<String, dynamic>?;
            final isToday = today.year == _currentYear &&
                today.month == _currentMonth &&
                today.day == dayNum;

            final dots = _dotsForDay(dayData);
            final hasData = dayData != null;

            return GestureDetector(
              onTap: hasData ? () => _showDayDetails(dateStr, dayData!) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: hasData
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.03)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  border: isToday
                      ? Border.all(
                          color: const Color(AppColors.primary), width: 1.8)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday
                            ? const Color(AppColors.primary)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (dots.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: dots.take(5).map((color) {
                          return Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  int _gridCellCount(int startWeekday, int daysInMonth) {
    final totalSlots = (startWeekday - 1) + daysInMonth;
    // Round up to full weeks
    return ((totalSlots + 6) ~/ 7) * 7;
  }

  String _dateString(int year, int month, int day) {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  List<Color> _dotsForDay(Map<String, dynamic>? dayData) {
    if (dayData == null) return [];
    final dots = <Color>[];

    // Sessions
    final sessions = dayData['sessions'] as List? ?? [];
    for (final session in sessions) {
      final status = (session['status'] as String?) ?? '';
      switch (status) {
        case 'present':
          dots.add(const Color(AppColors.present));
          break;
        case 'absent':
          dots.add(const Color(AppColors.absent));
          break;
        case 'cancelled':
          dots.add(const Color(AppColors.cancelled));
          break;
        default:
          dots.add(Colors.grey);
      }
    }

    // Events
    final events = dayData['events'] as List? ?? [];
    for (final event in events) {
      final type = (event['type'] as String?) ?? '';
      switch (type) {
        case 'holiday':
          dots.add(const Color(AppColors.holiday));
          break;
        case 'exam':
          dots.add(const Color(AppColors.exam));
          break;
        case 'fest':
          dots.add(const Color(AppColors.fest));
          break;
        default:
          dots.add(Colors.grey);
      }
    }

    return dots;
  }

  // ─────────────────────────────────────────
  // DAY DETAILS BOTTOM SHEET
  // ─────────────────────────────────────────

  void _showDayDetails(String dateStr, Map<String, dynamic> dayData) {
    final sessions = dayData['sessions'] as List? ?? [];
    final events = dayData['events'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _formatDateDisplay(dateStr),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),

              // Sessions
              if (sessions.isNotEmpty) ...[
                Text(
                  'Sessions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                ...sessions.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _statusColor(s['status'] ?? ''),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s['subject_name'] ?? '',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(s['status'] ?? '')
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _statusLabel(s['status'] ?? ''),
                              style: TextStyle(
                                color: _statusColor(s['status'] ?? ''),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],

              // Events
              if (events.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Events',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                ...events.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _eventColor(e['type'] ?? ''),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e['title'] ?? '',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  _eventColor(e['type'] ?? '').withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              EventTypes.display(e['type'] ?? ''),
                              style: TextStyle(
                                color: _eventColor(e['type'] ?? ''),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],

              if (sessions.isEmpty && events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No data for this day.'),
                ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return const Color(AppColors.present);
      case 'absent':
        return const Color(AppColors.absent);
      case 'cancelled':
        return const Color(AppColors.cancelled);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'holiday':
        return const Color(AppColors.holiday);
      case 'exam':
        return const Color(AppColors.exam);
      case 'fest':
        return const Color(AppColors.fest);
      default:
        return Colors.grey;
    }
  }

  String _formatDateDisplay(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  // ─────────────────────────────────────────
  // 5. LEGEND
  // ─────────────────────────────────────────

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
      spacing: 14,
      runSpacing: 6,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: item.$2,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              item.$1,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.55),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────
  // 6. SUBJECT BREAKDOWN
  // ─────────────────────────────────────────

  List<Map<String, dynamic>> get _groupedSubjectStats {
    final grouped = <String, Map<String, dynamic>>{};

    final filteredStats = _selectedSubjectId != null
        ? _subjectStats.where((s) => s['subject_id'] == _selectedSubjectId).toList()
        : _subjectStats;

    for (final stat in filteredStats) {
      final subjectId = stat['subject_id'] as String? ?? '';
      final lectureType = stat['lecture_type'] as String? ?? 'lecture';
      final key = '$subjectId|$lectureType';

      if (!grouped.containsKey(key)) {
        grouped[key] = {
          'subject_id': subjectId,
          'subject_name': stat['subject_name'] ?? '',
          'subject_code': stat['subject_code'] ?? '',
          'lecture_type': lectureType,
          'faculty_name': stat['faculty_name'] ?? '',
          'total_held': 0,
          'attended': 0,
          'is_below_threshold': false,
        };
      }

      // Aggregate data
      final group = grouped[key]!;
      group['total_held'] = (group['total_held'] as int) + ((stat['total_held'] as num?)?.toInt() ?? 0);
      group['attended'] = (group['attended'] as int) + ((stat['attended'] as num?)?.toInt() ?? 0);

      // Update faculty name if different (prefer non-null)
      if (group['faculty_name'].isEmpty && (stat['faculty_name'] ?? '').isNotEmpty) {
        group['faculty_name'] = stat['faculty_name'] ?? '';
      }
    }

    // Calculate percentages and threshold status
    final result = grouped.values.toList();
    for (final stat in result) {
      final totalHeld = stat['total_held'] as int;
      final attended = stat['attended'] as int;
      final percentage = totalHeld > 0 ? (attended / totalHeld) * 100 : 0.0;
      stat['percentage'] = percentage;
      stat['is_below_threshold'] = percentage < 75 && totalHeld > 0;
    }

    // Sort by subject name
    result.sort((a, b) => (a['subject_name'] as String).compareTo(b['subject_name'] as String));

    return result;
  }

  Widget _buildSubjectBreakdown() {
    final groupedStats = _groupedSubjectStats;

    if (groupedStats.isEmpty) {
      return const EmptyState(
        icon: Icons.school_rounded,
        title: 'No subjects found',
        subtitle: 'Attendance data will appear once sessions are recorded.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Subject Breakdown',
          subtitle: 'Per-subject attendance details',
        ),
        const SizedBox(height: 14),
        ...groupedStats.map((stat) {
          final percentage =
              (stat['percentage'] as num?)?.toDouble() ?? 0.0;
          final isBelowThreshold = stat['is_below_threshold'] == true;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(
                children: [
                  // Left indicator bar
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
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                stat['subject_name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            LectureTypeBadge(
                                type: stat['lecture_type'] ?? 'lecture'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${stat['faculty_name'] ?? ''} '
                          '  ${stat['attended'] ?? 0}/${stat['total_held'] ?? 0} sessions',
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
        }),
      ],
    );
  }
}
