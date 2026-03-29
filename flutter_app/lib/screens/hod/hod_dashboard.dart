// lib/screens/hod/hod_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';
import '../profile/profile_screen.dart';
import '../admin/admin_events_screen.dart';

class HodDashboard extends StatefulWidget {
  const HodDashboard({super.key});
  @override
  State<HodDashboard> createState() => _HodDashboardState();
}

class _HodDashboardState extends State<HodDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _deptUsers = [];
  List<dynamic> _pendingUsers = [];
  List<dynamic> _reports = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final users = await ApiService().getHodDepartmentUsers();
      final pending = await ApiService().getHodPendingUsers();
      final reports = await ApiService().getAttendanceReport();
      setState(() { _deptUsers = users; _pendingUsers = pending; _reports = reports; });
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

  Future<void> _handleApproval(String userId, String action) async {
    try {
      await ApiService().hodApproveUser(userId, action);
      _showSnack('User ${action}d successfully');
      await _loadData();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.event_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AdminEventsScreen())),
            tooltip: 'Events',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton(
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(AppColors.hodColor).withOpacity(0.15),
                child: const Icon(Icons.person_rounded,
                    color: Color(AppColors.hodColor), size: 18),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Users'),
            Tab(text: 'Pending (${_pendingUsers.length})'),
            const Tab(text: 'Reports'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildUsers(), _buildPending(), _buildReports()],
            ),
    );
  }

  Widget _buildUsers() {
    if (_deptUsers.isEmpty) {
      return const EmptyState(
        icon: Icons.people_rounded,
        title: 'No users in your department',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deptUsers.length,
      itemBuilder: (_, i) {
        final u = _deptUsers[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(AppColors.primary).withOpacity(0.1),
                  child: Text(
                    (u['full_name'] as String)[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(AppColors.primary),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u['full_name'],
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(u['email'],
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          )),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RoleBadge(role: u['role']),
                    const SizedBox(height: 4),
                    StatusBadge(status: u['status']),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPending() {
    if (_pendingUsers.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'No pending approvals',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingUsers.length,
      itemBuilder: (_, i) {
        final u = _pendingUsers[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(AppColors.warning).withOpacity(0.1),
                      child: Text(
                        (u['full_name'] as String)[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(AppColors.warning),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u['full_name'],
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(u['email'],
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 12,
                              )),
                        ],
                      ),
                    ),
                    RoleBadge(role: u['role']),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleApproval(u['id'], 'reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(AppColors.error),
                          side: const BorderSide(color: Color(AppColors.error)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleApproval(u['id'], 'approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(AppColors.success),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReports() {
    if (_reports.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'No attendance records',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (_, i) {
        final r = _reports[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(AppColors.success), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['student_name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${r['subject_name'] ?? 'N/A'} • ${r['marked_at'] ?? ''}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
