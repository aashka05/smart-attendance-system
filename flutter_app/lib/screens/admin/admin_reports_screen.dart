// lib/screens/admin/admin_reports_screen.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _records = [];
  List<dynamic> _bleEvents = [];
  bool _loading = false;

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
      final records = await ApiService().getAttendanceReport();
      final ble = await ApiService().getBleEvents();
      setState(() { _records = records; _bleEvents = ble; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: const Color(AppColors.error),
        behavior: SnackBarBehavior.floating,
      ));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Attendance'), Tab(text: 'BLE Events')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildAttendance(), _buildBleEvents()],
            ),
    );
  }

  Widget _buildAttendance() {
    if (_records.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'No attendance records yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (_, i) {
        final r = _records[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(AppColors.success).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Color(AppColors.success), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['student_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${r['subject_name'] ?? 'N/A'} • ${r['department_name'] ?? ''}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          )),
                      Text(r['marked_at'] ?? '',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            fontSize: 11,
                          )),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(AppColors.success).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r['status'] ?? 'present',
                    style: const TextStyle(
                      color: Color(AppColors.success),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBleEvents() {
    if (_bleEvents.isEmpty) {
      return const EmptyState(
        icon: Icons.bluetooth_rounded,
        title: 'No BLE events yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bleEvents.length,
      itemBuilder: (_, i) {
        final e = _bleEvents[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(AppColors.primary).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bluetooth_rounded,
                      color: Color(AppColors.primary), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e['student_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(e['token'] ?? '',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          )),
                      Text('RSSI: ${e['rssi']} dBm',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            fontSize: 11,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
