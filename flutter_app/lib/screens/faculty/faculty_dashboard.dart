// lib/screens/faculty/faculty_dashboard.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';
import '../profile/profile_screen.dart';
import '../reports/reports_menu_screen.dart';
import 'class_attendance_screen.dart';

class FacultyDashboard extends StatefulWidget {
  const FacultyDashboard({super.key});
  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  List<dynamic> _slots = [];
  bool _loading = false;
  String? _activeSessionId;
  String? _activeToken;
  String? _activeSlotName;
  bool _isAdvertising = false;
  Timer? _tokenTimer;
  int _secondsRemaining = 300;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    _stopAdvertising();
    _tokenTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() => _loading = true);
    try {
      final slots = await ApiService().getTimetable();
      setState(() => _slots = slots);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
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

  Future<void> _startAttendance(Map<String, dynamic> slot) async {
    try {
      final result = await ApiService().startAttendance(slot['id']);
      final token = result['token'] as String;
      final sessionId = result['session_id'] as String;

      setState(() {
        _activeSessionId = sessionId;
        _activeToken = token;
        _activeSlotName = slot['subject_name'];
        _secondsRemaining = 300;
      });

      await _startBleAdvertising(token);

      _tokenTimer?.cancel();
      _tokenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _secondsRemaining--);
        if (_secondsRemaining <= 0) {
          _refreshToken(slot['id']);
        }
      });

      _showSnack('Attendance started for ${slot['subject_name']}');
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  Future<void> _refreshToken(String slotId) async {
    try {
      final result = await ApiService().startAttendance(slotId);
      final newToken = result['token'] as String;
      setState(() {
        _activeToken = newToken;
        _secondsRemaining = 300;
      });
      await _stopAdvertising();
      await _startBleAdvertising(newToken);
    } catch (_) {}
  }

  Future<void> _startBleAdvertising(String token) async {
    try {
      final peripheral = FlutterBlePeripheral();
      bool isSupported = await peripheral.isSupported;
      print('BLE Peripheral supported: $isSupported');

      if (!isSupported) {
        _showSnack('BLE peripheral NOT supported on this device', isError: true);
        setState(() => _isAdvertising = true);
        return;
      }

      final data = Uint8List.fromList(token.codeUnits);
      final advertiseData = AdvertiseData(
        serviceUuid: '00004154-0000-1000-8000-00805F9B34FB',
        manufacturerId: 0x4154,
        manufacturerData: data,
      );

      final advertiseSettings = AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeBalanced,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        connectable: false,
        timeout: 0,
      );

      await peripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );
      print('=== BLE ADVERTISING STARTED: $token ===');
      setState(() => _isAdvertising = true);
    } catch (e) {
      print('=== BLE ADVERTISING ERROR: $e ===');
      _showSnack('BLE failed: $e', isError: true);
      setState(() => _isAdvertising = true);
    }
  }

  Future<void> _stopAdvertising() async {
    try {
      final peripheral = FlutterBlePeripheral();
      await peripheral.stop();
    } catch (_) {}
    setState(() => _isAdvertising = false);
  }

  Future<void> _stopAttendance() async {
    if (_activeSessionId == null) return;
    _tokenTimer?.cancel();
    await _stopAdvertising();
    try {
      await ApiService().stopAttendance(_activeSessionId!);
      setState(() {
        _activeSessionId = null;
        _activeToken = null;
        _activeSlotName = null;
      });
      _showSnack('Attendance closed');
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  String get _formattedTime {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showCancelDialog(Map<String, dynamic> slot) {
    DateTime? selectedDate;
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cancel Lecture'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today_rounded,
                        size: 20,
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5)),
                  ),
                  child: Text(
                    selectedDate != null
                        ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                        : 'Tap to select date',
                    style: TextStyle(
                      color: selectedDate != null
                          ? Theme.of(ctx).colorScheme.onSurface
                          : Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Reason (optional)',
                controller: reasonCtrl,
                maxLines: 2,
                prefixIcon: Icons.notes_rounded,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedDate == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Please select a date'),
                    behavior: SnackBarBehavior.floating,
                  ));
                  return;
                }
                try {
                  final dateStr =
                      '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
                  await ApiService().cancelLecture(
                    slotId: slot['id'],
                    date: dateStr,
                    reason: reasonCtrl.text.trim().isEmpty
                        ? null
                        : reasonCtrl.text.trim(),
                  );
                  Navigator.pop(ctx);
                  _showSnack('Lecture cancelled');
                } catch (e) {
                  _showSnack(e.toString(), isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.error),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancel Lecture'),
            ),
          ],
        ),
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
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(AppColors.facultyColor).withOpacity(0.15),
                child: const Icon(Icons.person_rounded,
                    color: Color(AppColors.facultyColor), size: 18),
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
              'Faculty • ${user.departmentName ?? 'No Department'}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ActionCard(
              icon: Icons.bar_chart_rounded,
              title: 'Attendance Reports',
              subtitle: 'Generate subject and class reports',
              color: const Color(AppColors.hodColor),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReportsMenuScreen(currentUser: user)),
              ),
            ),
            const SizedBox(height: 24),

            // Active session banner
            if (_isAdvertising && _activeToken != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(AppColors.facultyColor), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bluetooth_audio_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _activeSlotName ?? 'Attendance Live',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.greenAccent, size: 7),
                              SizedBox(width: 5),
                              Text('LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Token refreshes in',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formattedTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _stopAttendance,
                          icon: const Icon(Icons.stop_rounded, size: 18),
                          label: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(AppColors.facultyColor),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Timetable
            SectionHeader(
              title: 'My Schedule',
              subtitle: 'Tap a slot to start attendance',
              action: IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _loadSlots,
              ),
            ),
            const SizedBox(height: 14),

            _loading
                ? const Center(child: CircularProgressIndicator())
                : _slots.isEmpty
                    ? EmptyState(
                        icon: Icons.calendar_today_rounded,
                        title: 'No slots assigned yet',
                        subtitle: 'Contact admin to add timetable slots',
                      )
                    : Column(
                        children: _slots.map((slot) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onLongPress: !_isAdvertising
                                ? () => _showCancelDialog(slot)
                                : null,
                            child: AppCard(
                            onTap: !_isAdvertising ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClassAttendanceScreen(
                                  slotId: slot['id'],
                                  subjectName: '${slot['subject_name']} (${slot['subject_code'] ?? ''})',
                                ),
                              ),
                            ) : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 4, height: 70,
                                  decoration: BoxDecoration(
                                    color: const Color(AppColors.facultyColor),
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
                                              '${slot['subject_name']} (${slot['subject_code'] ?? ''})',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700, fontSize: 14),
                                            ),
                                          ),
                                          LectureTypeBadge(type: slot['lecture_type'] ?? 'lecture'),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${slot['room']}${slot['year'] != null ? ' • Year ${slot['year']}' : ''}${slot['batch'] != null ? ' • Batch ${slot['batch']}' : ''}',
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
                                const SizedBox(width: 10),
                                if (!_isAdvertising)
                                  ElevatedButton(
                                    onPressed: () => _startAttendance(slot),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(AppColors.facultyColor),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Start', style: TextStyle(fontSize: 13)),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Busy',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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
