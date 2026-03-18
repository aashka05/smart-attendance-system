// lib/screens/admin/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';
import 'admin_users_screen.dart';
import 'admin_departments_screen.dart';
import 'admin_timetable_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_enrollment_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _pendingCount = 0;
  int _totalUsers = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final pending = await ApiService().getPendingUsers();
      final all = await ApiService().getAllUsers();
      setState(() {
        _pendingCount = pending.length;
        _totalUsers = all.length;
      });
    } catch (_) {}
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
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
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome
              Text('Hello, ${user.fullName.split(' ').first} 👋',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text('System Administrator', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 24),

              // Stats
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.4,
                      children: [
                        StatCard(
                          label: 'Pending Approvals',
                          value: '$_pendingCount',
                          icon: Icons.pending_actions,
                          color: const Color(0xFFE65100),
                        ),
                        StatCard(
                          label: 'Total Users',
                          value: '$_totalUsers',
                          icon: Icons.people_outline,
                          color: const Color(AppColors.primary),
                        ),
                      ],
                    ),
              const SizedBox(height: 28),

              // Quick actions
              const SectionHeader(title: 'Management', subtitle: 'Tap to manage'),
              const SizedBox(height: 16),

              _ActionCard(
                icon: Icons.pending_actions,
                title: 'Pending Approvals',
                subtitle: '$_pendingCount users waiting',
                color: const Color(0xFFE65100),
                badge: _pendingCount > 0 ? '$_pendingCount' : null,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminUsersScreen(initialTab: 1))),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.people_outline,
                title: 'All Users',
                subtitle: 'View, approve, or reject accounts',
                color: const Color(AppColors.primary),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminUsersScreen(initialTab: 0))),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.business_outlined,
                title: 'Departments & Subjects',
                subtitle: 'Manage academic structure',
                color: const Color(0xFF137333),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminDepartmentsScreen())),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.calendar_month_outlined,
                title: 'Timetable',
                subtitle: 'Manage lecture slots',
                color: const Color(0xFF6A1B9A),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminTimetableScreen())),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.bar_chart_outlined,
                title: 'Attendance Reports',
                subtitle: 'View all attendance data',
                color: const Color(0xFF1565C0),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminReportsScreen())),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.face,
                title: 'Face Enrollments',
                subtitle: 'Review student face enrollments',
                color: const Color(0xFF00897B),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminEnrollmentScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  const _ActionCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.onTap, this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              )
            else
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
