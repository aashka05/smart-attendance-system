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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendees();
  }

  Future<void> _loadAttendees() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getSessionAttendees(widget.sessionId);
      setState(() => _attendees = data);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
    setState(() => _loading = false);
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _attendees.isEmpty
              ? const Center(
                  child: EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No attendees',
                    subtitle: 'No students attended this session',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAttendees,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _attendees.length,
                    itemBuilder: (context, index) {
                      final attendee = _attendees[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    const Color(AppColors.primary).withOpacity(0.1),
                                child: Text(
                                  (attendee['full_name'] as String)[0].toUpperCase(),
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
                                  color: const Color(AppColors.success).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Present',
                                  style: TextStyle(
                                    color: Color(AppColors.success),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
