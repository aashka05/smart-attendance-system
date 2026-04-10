// lib/screens/student/student_dashboard.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';
import 'attendance_calendar_screen.dart';
import 'face_enrollment_screen.dart';
import 'face_scan_screen.dart';
import '../profile/profile_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  List<dynamic> _slots = [];
  List<dynamic> _allSlots = [];
  bool _loading = false;
  bool _isScanning = false;
  List<Map<String, dynamic>> _detectedSignals = [];
  String _scanStatus = 'Tap "Scan" when your lecture starts';
  bool _isReporting = false;
  Map<String, dynamic>? _enrollmentStatus;

  StreamSubscription? _scanSub;
  StreamSubscription? _scanStateSub;

  @override
  void initState() {
    super.initState();
    _loadSlots();
    _loadEnrollmentStatus();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _scanStateSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  String _getTodayDayOfWeek() {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[DateTime.now().weekday - 1];
  }

  List<dynamic> _filterTodaySlots(List<dynamic> slots) {
    final today = _getTodayDayOfWeek();
    return slots.where((slot) => slot['day_of_week'] == today).toList();
  }

  Future<void> _loadSlots() async {
    setState(() => _loading = true);
    try {
      final slots = await ApiService().getTimetable();
      setState(() {
        _allSlots = slots;
        _slots = _filterTodaySlots(slots);
      });
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
    setState(() => _loading = false);
  }

  Future<void> _loadEnrollmentStatus() async {
    try {
      final status = await ApiService().getEnrollmentStatus();
      setState(() => _enrollmentStatus = status);
    } catch (_) {}
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(AppColors.error) : const Color(AppColors.success),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showFullTimetable() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Full Timetable',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                child: _allSlots.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: EmptyState(
                          icon: Icons.calendar_today_rounded,
                          title: 'No slots scheduled',
                        ),
                      )
                    : Column(
                        children: _allSlots.map((slot) {
                          final today = _getTodayDayOfWeek();
                          final isToday = slot['day_of_week'] == today;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isToday
                                      ? const Color(AppColors.primary).withOpacity(0.3)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: AppCard(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? const Color(AppColors.primary)
                                            : const Color(AppColors.primary).withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  slot['subject_name'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              if (isToday)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(AppColors.primary)
                                                        .withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'Today',
                                                    style: TextStyle(
                                                      color: Color(AppColors.primary),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              LectureTypeBadge(
                                                type: slot['lecture_type'] ?? 'lecture',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${slot['faculty_name']} • ${slot['room']}',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.5),
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            '${slot['day_of_week']} ${slot['start_time']} – ${slot['end_time']}',
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
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _detectedSignals.clear();
      _scanStatus = 'Scanning for nearby signals...';
    });

    print('=== BLE SCAN START ===');
    final state = await FlutterBluePlus.adapterState.first;
    print('Bluetooth state: $state');
    bool isSupported = await FlutterBluePlus.isSupported;
    print('BLE supported: $isSupported');

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: AppConfig.bleScanDuration),
      androidUsesFineLocation: false,
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      for (ScanResult r in results) {
        if (r.advertisementData.manufacturerData.isNotEmpty) {
          print('Device: ${r.device.remoteId}');
          r.advertisementData.manufacturerData.forEach((id, data) {
            print('Manufacturer ID: $id, Data: $data');
          });
        }
        final mfrData = r.advertisementData.manufacturerData;
        if (mfrData.containsKey(0x4154)) {
          final data = mfrData[0x4154]!;
          final token = String.fromCharCodes(data);
          final rssi = r.rssi;
          final exists = _detectedSignals.any((s) => s['token'] == token);
          if (!exists) {
            setState(() {
              _detectedSignals.add({'token': token, 'rssi': rssi, 'reported': false});
              _scanStatus = '${_detectedSignals.length} signal(s) detected';
            });
          }
        }
      }
    });

    _scanStateSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return;
      if (!scanning) {
        setState(() {
          _isScanning = false;
          _scanStatus = _detectedSignals.isEmpty
              ? 'No signals found. Are you in the classroom?'
              : '${_detectedSignals.length} signal(s) found';
        });
      }
    });
  }

  Future<void> _stopScanning() async {
    await FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);
  }

  Future<void> _reportSignal(Map<String, dynamic> signal) async {
    setState(() => _isReporting = true);
    try {
      final result = await ApiService().reportBleDetected(
        token: signal['token'],
        rssi: signal['rssi'],
        timestamp: DateTime.now().toIso8601String(),
      );

      print('Token: ${signal['token']}');
      print('Session ID: ${result['session_id']}');
      print('Token valid: ${result['token_valid']}');
      print('Session found: ${result['session_found']}');

      setState(() => signal['reported'] = true);

      final tokenValid = result['token_valid'] as bool? ?? false;
      final sessionFound = result['session_found'] as bool? ?? false;
      final sessionId = result['session_id'] as String?;

      if (tokenValid && sessionFound && sessionId != null) {
        final enrollStatus = _enrollmentStatus?['status'];
        if (enrollStatus != 'approved') {
          _showEnrollmentDialog();
          return;
        }
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => FaceScanScreen(
              sessionId: sessionId,
              token: signal['token'],
              subjectName: signal['subject_name'] ?? 'Attendance',
            ),
          ));
        }
      } else {
        _showSnack('⚠️ Signal found but no matching active session', isError: true);
      }
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
    setState(() => _isReporting = false);
  }

  void _showEnrollmentDialog() {
    final status = _enrollmentStatus?['status'] ?? 'not_submitted';
    String message;
    String buttonText;
    VoidCallback? onPressed;

    if (status == 'pending') {
      message = 'Your face enrollment is pending admin approval.';
      buttonText = 'OK';
      onPressed = () => Navigator.pop(context);
    } else if (status == 'rejected') {
      message = 'Your face enrollment was rejected. Please re-enroll.';
      buttonText = 'Re-enroll';
      onPressed = () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const FaceEnrollmentScreen(),
        ));
      };
    } else {
      message = 'You need to enroll your face before marking attendance.';
      buttonText = 'Enroll Now';
      onPressed = () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const FaceEnrollmentScreen(),
        ));
      };
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Face Enrollment Required'),
        content: Text(message),
        actions: [
          ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton(
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(AppColors.studentColor).withOpacity(0.15),
                child: const Icon(Icons.person_rounded,
                    color: Color(AppColors.studentColor), size: 18),
              ),
              itemBuilder: (_) => [
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
                PopupMenuItem(
                  child: const Row(children: [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ]),
                  onTap: () => context.read<AuthProvider>().logout(),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${user.fullName.split(' ').first} 👋',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
            ),
            Text(
              '${user.departmentName ?? 'No Department'}${user.year != null ? ' • Year ${user.year}' : ''} • ${user.enrollmentNumber ?? ''}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),

            // Enrollment banner
            if (_enrollmentStatus != null && _enrollmentStatus!['status'] != 'approved') ...[
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const FaceEnrollmentScreen(),
                )).then((_) => _loadEnrollmentStatus()),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.warning).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(AppColors.warning).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.face_rounded, color: Color(AppColors.warning), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _enrollmentStatus!['status'] == 'pending'
                              ? 'Face enrollment pending approval'
                              : 'Face enrollment required — tap to enroll',
                          style: const TextStyle(color: Color(AppColors.warning), fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(AppColors.warning), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // My Attendance card
            ActionCard(
              icon: Icons.calendar_month_rounded,
              title: 'My Attendance',
              subtitle: 'View calendar & subject breakdown',
              color: const Color(AppColors.success),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttendanceCalendarScreen(
                    studentId: user.id,
                    studentName: user.fullName,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // BLE Scanner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isScanning
                      ? [const Color(AppColors.primary), const Color(0xFF0031CA)]
                      : [const Color(0xFF334155), const Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isScanning ? Icons.bluetooth_searching_rounded : Icons.bluetooth_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isScanning ? 'Scanning...' : 'BLE Scanner',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _scanStatus,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isScanning ? _stopScanning : _startScanning,
                    icon: Icon(
                      _isScanning ? Icons.stop_rounded : Icons.search_rounded,
                      size: 18,
                    ),
                    label: Text(_isScanning ? 'Stop' : 'Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(AppColors.primary),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Detected signals
            if (_detectedSignals.isNotEmpty) ...[
              const SectionHeader(
                title: 'Detected Signals',
                subtitle: 'Tap Mark to proceed',
              ),
              const SizedBox(height: 12),
              ..._detectedSignals.map((signal) {
                final reported = signal['reported'] as bool;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: reported
                                ? const Color(AppColors.success).withOpacity(0.1)
                                : const Color(AppColors.primary).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            reported ? Icons.check_circle_rounded : Icons.bluetooth_rounded,
                            color: reported
                                ? const Color(AppColors.success)
                                : const Color(AppColors.primary),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                signal['token'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              Text(
                                'Signal: ${signal['rssi']} dBm',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!reported)
                          ElevatedButton(
                            onPressed: _isReporting ? null : () => _reportSignal(signal),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(AppColors.primary),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _isReporting
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Mark', style: TextStyle(fontSize: 13)),
                          )
                        else
                          Text(
                            'Reported ✓',
                            style: TextStyle(
                              color: const Color(AppColors.success),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            // Schedule
            SectionHeader(
              title: 'My Schedule',
              subtitle: "Today's lectures",
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_view_week_rounded, size: 20),
                    onPressed: _showFullTimetable,
                    tooltip: 'Full Timetable',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _loadSlots,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _slots.isEmpty
                    ? const EmptyState(
                        icon: Icons.calendar_today_rounded,
                        title: 'No lectures scheduled',
                      )
                    : Column(
                        children: _slots.map((slot) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 4, height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(AppColors.primary),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              slot['subject_name'] ?? '',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600, fontSize: 14),
                                            ),
                                          ),
                                          LectureTypeBadge(type: slot['lecture_type'] ?? 'lecture'),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${slot['faculty_name']} • ${slot['room']}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${slot['day_of_week']} ${slot['start_time']} – ${slot['end_time']}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
          ],
        ),
      ),
    );
  }
}
