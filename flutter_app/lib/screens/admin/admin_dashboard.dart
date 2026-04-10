// lib/screens/admin/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';
import '../profile/profile_screen.dart';
import 'admin_users_screen.dart';
import 'admin_departments_screen.dart';
import 'admin_timetable_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_enrollment_screen.dart';
import 'admin_events_screen.dart';
import 'admin_import_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _pendingCount = 0;
  int _totalUsers = 0;
  int _pendingEnrollments = 0;
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
      final enrollments = await ApiService().getPendingEnrollments();
      setState(() {
        _pendingCount = pending.length;
        _totalUsers = all.length;
        _pendingEnrollments = enrollments.length;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton(
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(AppColors.adminColor).withOpacity(0.15),
                child: const Icon(Icons.person_rounded,
                    color: Color(AppColors.adminColor), size: 18),
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
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${user.fullName.split(' ').first} 👋',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
              ),
              Text(
                'System Administrator',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // Stats
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Pending Approvals',
                        value: '$_pendingCount',
                        icon: Icons.pending_actions_rounded,
                        color: const Color(AppColors.warning),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Total Users',
                        value: '$_totalUsers',
                        icon: Icons.people_rounded,
                        color: const Color(AppColors.adminColor),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 28),

              const SectionHeader(title: 'Management'),
              const SizedBox(height: 14),

              ActionCard(
                icon: Icons.pending_actions_rounded,
                title: 'Pending Approvals',
                subtitle: '$_pendingCount users waiting',
                color: const Color(AppColors.warning),
                badge: _pendingCount > 0 ? '$_pendingCount' : null,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AdminUsersScreen(initialTab: 1))),
              ),
              const SizedBox(height: 10),
              ActionCard(
                icon: Icons.people_rounded,
                title: 'All Users',
                subtitle: 'View, approve or reject accounts',
                color: const Color(AppColors.adminColor),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AdminUsersScreen(initialTab: 0))),
              ),
              const SizedBox(height: 10),
              ActionCard(
                icon: Icons.face_rounded,
                title: 'Face Enrollments',
                subtitle: '$_pendingEnrollments pending review',
                color: const Color(AppColors.facultyColor),
                badge: _pendingEnrollments > 0 ? '$_pendingEnrollments' : null,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AdminEnrollmentScreen())),
              ),
              const SizedBox(height: 10),
              ActionCard(
                icon: Icons.business_rounded,
                title: 'Departments & Subjects',
                subtitle: 'Manage academic structure',
                color: const Color(AppColors.facultyColor),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AdminDepartmentsScreen())),
              ),
              const SizedBox(height: 10),
              ActionCard(
                icon: Icons.calendar_month_rounded,
                title: 'Timetable',
                subtitle: 'Manage lecture slots',
                color: const Color(AppColors.principalColor),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AdminTimetableScreen())),
              ),
              const SizedBox(height: 10),
              ActionCard(
                icon: Icons.bar_chart_rounded,
                title: 'Attendance Reports',
                subtitle: 'View all attendance data',
                color: const Color(AppColors.hodColor),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AdminReportsScreen())),
              ),
              const SizedBox(height: 10),
              ActionCard(
                icon: Icons.cloud_upload_rounded,
                title: 'Bulk Import Data',
                subtitle: 'Import CSV records',
                color: const Color(AppColors.primary),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AdminImportScreen())),
              ),
              const SizedBox(height: 10),
              ActionCard(
                icon: Icons.event_rounded,
                title: 'Events & Holidays',
                subtitle: 'Manage college events',
                color: const Color(AppColors.holiday),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AdminEventsScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
