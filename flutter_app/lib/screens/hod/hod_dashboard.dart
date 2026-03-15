// lib/screens/hod/hod_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class HodDashboard extends StatefulWidget {
  const HodDashboard({super.key});
  @override
  State<HodDashboard> createState() => _HodDashboardState();
}

class _HodDashboardState extends State<HodDashboard> with SingleTickerProviderStateMixin {
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
      backgroundColor: isError ? Colors.red : Colors.green,
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
              backgroundColor: Color(0xFFE65100),
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(AppColors.primary),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(AppColors.primary),
          tabs: [
            const Tab(text: 'Users'),
            Tab(text: 'Pending (${_pendingUsers.length})'),
            const Tab(text: 'Reports'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header info
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.supervisor_account, color: Color(0xFFE65100), size: 18),
                      const SizedBox(width: 8),
                      Text('${user.departmentName ?? 'Department'} • Head of Department',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildUsers(), _buildPending(), _buildReports()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUsers() {
    if (_deptUsers.isEmpty) {
      return Center(child: Text('No users in your department', style: TextStyle(color: Colors.grey.shade600)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deptUsers.length,
      itemBuilder: (_, i) {
        final u = _deptUsers[i];
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
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(AppColors.primary).withOpacity(0.1),
                child: Text(
                  (u['full_name'] as String)[0].toUpperCase(),
                  style: const TextStyle(color: Color(AppColors.primary), fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u['full_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(u['email'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
        );
      },
    );
  }

  Widget _buildPending() {
    if (_pendingUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No pending approvals', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingUsers.length,
      itemBuilder: (_, i) {
        final u = _pendingUsers[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE65100).withOpacity(0.1),
                    child: Text(
                      (u['full_name'] as String)[0].toUpperCase(),
                      style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u['full_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(u['email'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleApproval(u['id'], 'approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF137333),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReports() {
    if (_reports.isEmpty) {
      return Center(child: Text('No attendance records', style: TextStyle(color: Colors.grey.shade600)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (_, i) {
        final r = _reports[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF137333), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['student_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${r['subject_name'] ?? 'N/A'} • ${r['marked_at'] ?? ''}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
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
