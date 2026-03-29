// lib/screens/principal/principal_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';
import '../profile/profile_screen.dart';

class PrincipalDashboard extends StatefulWidget {
  const PrincipalDashboard({super.key});
  @override
  State<PrincipalDashboard> createState() => _PrincipalDashboardState();
}

class _PrincipalDashboardState extends State<PrincipalDashboard> {
  List<dynamic> _reports = [];
  bool _loading = false;
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
    final user = context.watch<AuthProvider>().user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton(
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(AppColors.principalColor).withOpacity(0.15),
                child: const Icon(Icons.person_rounded,
                    color: Color(AppColors.principalColor), size: 18),
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
                    Text(
                      'Hello, ${user.fullName.split(' ').first} 👋',
                      style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    ),
                    Text(
                      'Principal • College Overview',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(AppColors.principalColor), Color(0xFF6D28D9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Attendance Records',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_totalPresent',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            'Across all departments',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Department breakdown
                    if (_deptStats.isNotEmpty) ...[
                      const SectionHeader(title: 'Department Breakdown'),
                      const SizedBox(height: 12),
                      ..._deptStats.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(AppColors.principalColor).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.business_rounded,
                                    color: Color(AppColors.principalColor), size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(AppColors.principalColor).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${entry.value} records',
                                  style: const TextStyle(
                                    color: Color(AppColors.principalColor),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                      const SizedBox(height: 24),
                    ],

                    // Recent records
                    const SectionHeader(title: 'Recent Attendance'),
                    const SizedBox(height: 12),
                    _reports.isEmpty
                        ? const EmptyState(
                            icon: Icons.bar_chart_rounded,
                            title: 'No records yet',
                          )
                        : Column(
                            children: _reports.take(20).map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: Color(AppColors.success), size: 16),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${r['student_name']} — ${r['subject_name'] ?? 'N/A'} (${r['department_name'] ?? ''})',
                                        style: const TextStyle(fontSize: 13),
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
            ),
    );
  }
}
