// lib/screens/principal/principal_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class PrincipalDashboard extends StatefulWidget {
  const PrincipalDashboard({super.key});
  @override
  State<PrincipalDashboard> createState() => _PrincipalDashboardState();
}

class _PrincipalDashboardState extends State<PrincipalDashboard> {
  List<dynamic> _reports = [];
  bool _loading = false;

  // Stats
  int _totalPresent = 0;
  Map<String, int> _deptStats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final reports = await ApiService().getAttendanceReport();
      setState(() {
        _reports = reports;
        _totalPresent = reports.length;
        _deptStats = {};
        for (final r in reports) {
          final dept = r['department_name'] ?? 'Unknown';
          _deptStats[dept] = (_deptStats[dept] ?? 0) + 1;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
    setState(() => _loading = false);
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          PopupMenuButton(
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF6A1B9A),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello, ${user.fullName.split(' ').first} 👋',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const Text('Principal • College Overview',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 24),

                    // Summary card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Attendance Records',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Text('$_totalPresent',
                              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          const Text('Across all departments',
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Department breakdown
                    if (_deptStats.isNotEmpty) ...[
                      const SectionHeader(title: 'Department Breakdown'),
                      const SizedBox(height: 12),
                      ..._deptStats.entries.map((entry) => Container(
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
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6A1B9A).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.business_outlined, color: Color(0xFF6A1B9A), size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6A1B9A).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${entry.value} records',
                                  style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.w600, fontSize: 12)),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 24),
                    ],

                    // Recent records
                    const SectionHeader(title: 'Recent Attendance'),
                    const SizedBox(height: 12),
                    _reports.isEmpty
                        ? Center(child: Text('No records yet', style: TextStyle(color: Colors.grey.shade600)))
                        : Column(
                            children: _reports.take(20).map((r) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Color(0xFF137333), size: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${r['student_name']} — ${r['subject_name'] ?? 'N/A'} (${r['department_name'] ?? ''})',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
