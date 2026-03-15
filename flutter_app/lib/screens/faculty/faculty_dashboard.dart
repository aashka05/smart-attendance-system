// lib/screens/faculty/faculty_dashboard.dart

import 'dart:async';
//import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';
import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

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
      backgroundColor: isError ? Colors.red : Colors.green,
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

      // Timer to update countdown
      _tokenTimer?.cancel();
      _tokenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _secondsRemaining--);
        if (_secondsRemaining <= 0) {
          // Token refreshed server-side automatically, restart advertising
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
      await FlutterBlePeripheral().stop();
      await _startBleAdvertising(newToken);
    } catch (_) {}
  }

  Future<void> _startBleAdvertising(String token) async {
    try {
      final peripheral = FlutterBlePeripheral();
      bool isSupported = await peripheral.isSupported;
      print('BLE Peripheral supported: $isSupported');
      _showSnack('BLE supported: $isSupported');
      
      if (!isSupported) {
        _showSnack('BLE peripheral NOT supported on this device', isError: true);
        setState(() => _isAdvertising = true);
        return;
      }

      final advertiseData = AdvertiseData(
        serviceUuid: '00004154-0000-1000-8000-00805F9B34FB',
        manufacturerId: 0x4154,
        manufacturerData: Uint8List.fromList(token.codeUnits),
      );
      await peripheral.start(advertiseData: advertiseData);
      print('BLE advertising started with token: $token');
      _showSnack('Broadcasting: $token');
      setState(() => _isAdvertising = true);
    } catch (e) {
      print('BLE error: $e');
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    return Scaffold(
      backgroundColor: const Color(AppColors.surface),
      appBar: AppBar(
        title: Text(AppConfig.appName, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          PopupMenuButton(
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF137333),
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                child: const Row(children: [Icon(Icons.logout, size: 18), SizedBox(width: 8), Text('Sign Out')]),
                onTap: () => context.read<AuthProvider>().logout(),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome
            Text('Hello, ${user.fullName.split(' ').first} 👋',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text('Faculty • ${user.departmentName ?? 'No Department'}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 24),

            // Active Session Banner
            if (_isAdvertising && _activeToken != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF137333), Color(0xFF0D5A2B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bluetooth_audio, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(_activeSlotName ?? 'Attendance Live',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
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
                              Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                              SizedBox(width: 4),
                              Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Broadcasting BLE Signal',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_activeToken ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 14,
                            fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Token refreshes in',
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                              Text(_formattedTime,
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _stopAttendance,
                          icon: const Icon(Icons.stop, size: 18),
                          label: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF137333),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              title: "My Timetable",
              subtitle: "Tap a slot to start attendance",
              action: IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loadSlots),
            ),
            const SizedBox(height: 16),

            _loading
                ? const Center(child: CircularProgressIndicator())
                : _slots.isEmpty
                    ? Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No slots assigned yet', style: TextStyle(color: Colors.grey.shade600)),
                            Text('Contact admin to add timetable slots',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        ),
                      )
                    : Column(
                        children: _slots.map((slot) => _SlotCard(
                          slot: slot,
                          isActive: _activeSessionId != null,
                          onStart: _isAdvertising ? null : () => _startAttendance(slot),
                        )).toList(),
                      ),
          ],
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final Map<String, dynamic> slot;
  final bool isActive;
  final VoidCallback? onStart;

  const _SlotCard({required this.slot, required this.isActive, this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF137333),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${slot['subject_name']} (${slot['subject_code'] ?? ''})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text('${slot['section']} • ${slot['room']}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text('${slot['day_of_week']} ${slot['start_time']} – ${slot['end_time']}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          if (onStart != null)
            ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF137333),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Start', style: TextStyle(fontSize: 13)),
            )
          else if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Busy', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
