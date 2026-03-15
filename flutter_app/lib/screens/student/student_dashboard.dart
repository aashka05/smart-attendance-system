// lib/screens/student/student_dashboard.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  List<dynamic> _slots = [];
  bool _loading = false;
  bool _isScanning = false;
  List<Map<String, dynamic>> _detectedSignals = [];
  String _scanStatus = 'Tap "Scan" when your lecture starts';
  bool _isReporting = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
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

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _detectedSignals.clear();
      _scanStatus = 'Scanning for nearby signals...';
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: AppConfig.bleScanDuration));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final mfrData = r.advertisementData.manufacturerData;
        if (mfrData.containsKey(0x4154)) {
          final data = mfrData[0x4154]!;
          final token = String.fromCharCodes(data);
          final rssi = r.rssi;
          final exists = _detectedSignals.any((s) => s['token'] == token);
          if (!exists) {
            setState(() {
              _detectedSignals.add({
                'token': token,
                'rssi': rssi,
                'reported': false,
              });
              _scanStatus = '${_detectedSignals.length} signal(s) detected';
            });
          }
        }
      }
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && mounted) {
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

      setState(() => signal['reported'] = true);

      final tokenValid = result['token_valid'] as bool? ?? false;
      final sessionFound = result['session_found'] as bool? ?? false;

      if (tokenValid && sessionFound) {
        _showSnack('✅ Attendance signal verified! Proceed to face scan');
        // TODO: Navigate to face recognition screen
      } else {
        _showSnack('⚠️ Signal found but no matching active session', isError: true);
      }
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
    setState(() => _isReporting = false);
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
              backgroundColor: Color(AppColors.primary),
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
            Text('Student • ${user.departmentName ?? 'No Department'} • ${user.enrollmentNumber ?? ''}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 24),

            // BLE Scanner Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isScanning
                      ? [const Color(AppColors.primary), const Color(0xFF0D47A1)]
                      : [Colors.grey.shade700, Colors.grey.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Animated bluetooth icon
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isScanning ? 'Scanning...' : 'BLE Scanner',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(_scanStatus,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isScanning ? _stopScanning : _startScanning,
                          icon: Icon(_isScanning ? Icons.stop : Icons.search, size: 18),
                          label: Text(_isScanning ? 'Stop' : 'Scan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Detected signals
            if (_detectedSignals.isNotEmpty) ...[
              SectionHeader(title: 'Detected Signals', subtitle: 'Tap to mark your attendance'),
              const SizedBox(height: 12),
              ..._detectedSignals.map((signal) => _SignalCard(
                signal: signal,
                isReporting: _isReporting,
                onReport: signal['reported'] ? null : () => _reportSignal(signal),
              )),
              const SizedBox(height: 20),
            ],

            // Timetable
            SectionHeader(
              title: "My Schedule",
              subtitle: "Today's lectures",
              action: IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loadSlots),
            ),
            const SizedBox(height: 16),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _slots.isEmpty
                    ? Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No lectures scheduled', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : Column(
                        children: _slots.map((slot) => _ScheduleCard(slot: slot)).toList(),
                      ),
          ],
        ),
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final Map<String, dynamic> signal;
  final bool isReporting;
  final VoidCallback? onReport;

  const _SignalCard({required this.signal, required this.isReporting, this.onReport});

  @override
  Widget build(BuildContext context) {
    final reported = signal['reported'] as bool;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: reported ? const Color(0xFF137333) : const Color(AppColors.primary).withOpacity(0.3),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: reported
                  ? const Color(0xFFE6F4EA)
                  : const Color(AppColors.primary).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              reported ? Icons.check_circle : Icons.bluetooth,
              color: reported ? const Color(0xFF137333) : const Color(AppColors.primary),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(signal['token'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'monospace')),
                Text('Signal strength: ${signal['rssi']} dBm',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          if (!reported)
            ElevatedButton(
              onPressed: isReporting ? null : onReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primary),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isReporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Mark', style: TextStyle(fontSize: 13)),
            )
          else
            const Text('Reported ✓', style: TextStyle(color: Color(0xFF137333), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> slot;
  const _ScheduleCard({required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 56,
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
                Text(slot['subject_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${slot['faculty_name']} • ${slot['room']}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text('${slot['day_of_week']} ${slot['start_time']} – ${slot['end_time']}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
