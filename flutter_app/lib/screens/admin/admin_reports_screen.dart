// lib/screens/admin/admin_reports_screen.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  List<dynamic> _records = [];
  List<dynamic> _bleEvents = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final records = await ApiService().getAttendanceReport();
      final ble = await ApiService().getBleEvents();
      setState(() { _records = records; _bleEvents = ble; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(AppColors.surface),
        appBar: AppBar(
          title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
          bottom: const TabBar(
            labelColor: Color(AppColors.primary),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(AppColors.primary),
            tabs: [Tab(text: 'Attendance'), Tab(text: 'BLE Events')],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_buildAttendance(), _buildBleEvents()]),
      ),
    );
  }

  Widget _buildAttendance() {
    if (_records.isEmpty) {
      return Center(child: Text('No attendance records yet', style: TextStyle(color: Colors.grey.shade600)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (_, i) {
        final r = _records[i];
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
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Color(0xFF137333), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['student_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${r['subject_name'] ?? 'N/A'} • ${r['department_name'] ?? ''}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text(r['marked_at'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(r['status'] ?? 'present',
                    style: const TextStyle(color: Color(0xFF137333), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBleEvents() {
    if (_bleEvents.isEmpty) {
      return Center(child: Text('No BLE events yet', style: TextStyle(color: Colors.grey.shade600)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bleEvents.length,
      itemBuilder: (_, i) {
        final e = _bleEvents[i];
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
              const Icon(Icons.bluetooth, color: Color(AppColors.primary), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e['student_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(e['token'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontFamily: 'monospace')),
                    Text('RSSI: ${e['rssi']} dBm • ${e['timestamp'] ?? ''}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
