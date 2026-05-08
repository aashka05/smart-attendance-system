import 'package:flutter/material.dart';
import '../../config.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

class SessionAttendeesScreen extends StatefulWidget {
  final String sessionId;
  final String sessionDate;
  final String subjectName;

  const SessionAttendeesScreen({
    super.key,
    required this.sessionId,
    required this.sessionDate,
    required this.subjectName,
  });

  @override
  State<SessionAttendeesScreen> createState() => _SessionAttendeesScreenState();
}

class _SessionAttendeesScreenState extends State<SessionAttendeesScreen> {
  late List<dynamic> _attendees = [];
  late Map<String, String> _originalStatuses = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAttendees();
  }

  Future<void> _loadAttendees() async {
    setState(() {
      _loading = true;
      _saving = false;
    });
    try {
      final data = await ApiService().getSessionAttendees(widget.sessionId);
      final attendees = (data as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
          .toList();
      final originalStatuses = <String, String>{};
      for (final attendee in attendees) {
        originalStatuses[attendee['student_id'] as String] =
            (attendee['status'] as String?) ?? 'absent';
      }
      setState(() {
        _attendees = attendees;
        _originalStatuses = originalStatuses;
      });
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
    setState(() => _loading = false);
  }

  bool get _hasChanges {
    for (final attendee in _attendees) {
      final id = attendee['student_id'] as String;
      final status = attendee['status'] as String? ?? 'absent';
      if (_originalStatuses[id] != status) {
        return true;
      }
    }
    return false;
  }

  void _setStatus(String studentId, String status) {
    setState(() {
      final index = _attendees.indexWhere((item) => item['student_id'] == studentId);
      if (index >= 0) {
        _attendees[index]['status'] = status;
      }
    });
  }

  Future<void> _saveAttendance() async {
    if (!_hasChanges || _saving) return;
    setState(() => _saving = true);

    try {
      final records = _attendees
          .map((attendee) => {
                'student_id': attendee['student_id'] as String,
                'status': attendee['status'] as String,
              })
          .toList()
          .cast<Map<String, String>>();

      await ApiService().updateSessionAttendance(widget.sessionId, records);
      _showSnack('Attendance saved successfully.');
      await _loadAttendees();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      setState(() => _saving = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subjectName),
            Text(
              'Session: ${widget.sessionDate}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: 'Save attendance',
            onPressed: _hasChanges && !_saving ? _saveAttendance : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _attendees.isEmpty
              ? const Center(
                  child: EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No students found',
                    subtitle:
                        'No students are enrolled for this session yet.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAttendees,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _attendees.length,
                    itemBuilder: (context, index) {
                      final attendee = _attendees[index];
                      final status = (attendee['status'] as String?) ?? 'absent';
                      final isPresent = status == 'present';
                      final statusColor = isPresent
                          ? const Color(AppColors.success)
                          : const Color(AppColors.error);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        const Color(AppColors.primary).withOpacity(0.1),
                                    child: Text(
                                      (attendee['full_name'] as String)[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(AppColors.primary),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          attendee['full_name'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          attendee['enrollment_number'] ?? '',
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isPresent ? 'Present' : 'Absent',
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Present'),
                                    selected: isPresent,
                                    selectedColor:
                                        const Color(AppColors.success).withOpacity(0.12),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.surface,
                                    labelStyle: TextStyle(
                                      color: isPresent
                                          ? const Color(AppColors.success)
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                    ),
                                    onSelected: (_) => _setStatus(
                                      attendee['student_id'] as String,
                                      'present',
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Absent'),
                                    selected: !isPresent,
                                    selectedColor:
                                        const Color(AppColors.error).withOpacity(0.12),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.surface,
                                    labelStyle: TextStyle(
                                      color: !isPresent
                                          ? const Color(AppColors.error)
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                    ),
                                    onSelected: (_) => _setStatus(
                                      attendee['student_id'] as String,
                                      'absent',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
