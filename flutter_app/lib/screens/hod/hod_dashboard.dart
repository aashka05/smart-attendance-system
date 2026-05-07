// lib/screens/hod/hod_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';
import '../profile/profile_screen.dart';
import '../admin/admin_events_screen.dart';
import '../reports/reports_menu_screen.dart';

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
  String _selectedRole = 'all';
  int? _selectedYear;

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

  List<dynamic> _getFilteredUsers() {
    return _deptUsers.where((user) {
      if (_selectedRole != 'all' && user['role'] != _selectedRole) {
        return false;
      }
      if (_selectedRole == 'student' && _selectedYear != null) {
        if (user['year'] != _selectedYear) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Set<int> _getAvailableYears() {
    return _deptUsers
        .where((user) => user['role'] == 'student' && user['year'] != null)
        .map<int>((user) => user['year'] as int)
        .toSet();
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(AppColors.primary)
              : const Color(AppColors.primary).withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(AppColors.primary)
                : const Color(AppColors.primary).withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : const Color(AppColors.primary),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
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
    final filteredUsers = _getFilteredUsers();
    final availableYears = _getAvailableYears();

    return Column(
      children: [
        if (_deptUsers.isNotEmpty) Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //const Text('Filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(label: 'All', selected: _selectedRole == 'all', onTap: () => setState(() { _selectedRole = 'all'; _selectedYear = null; })),
                    const SizedBox(width: 8),
                    _buildFilterChip(label: 'Faculty', selected: _selectedRole == 'faculty', onTap: () => setState(() { _selectedRole = 'faculty'; _selectedYear = null; })),
                    const SizedBox(width: 8),
                    _buildFilterChip(label: 'Students', selected: _selectedRole == 'student', onTap: () => setState(() { _selectedRole = 'student'; })),
                  ],
                ),
              ),
              if (_selectedRole == 'student') ...[const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(label: 'All Years', selected: _selectedYear == null, onTap: () => setState(() => _selectedYear = null)),
                      ...(availableYears.toList()..sort()).map((year) => Padding(padding: const EdgeInsets.only(left: 8), child: _buildFilterChip(label: 'Year $year', selected: _selectedYear == year, onTap: () => setState(() => _selectedYear = year)))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _deptUsers.isEmpty
              ? const EmptyState(
                  icon: Icons.people_rounded,
                  title: 'No users in your department',
                )
              : filteredUsers.isEmpty
                  ? const EmptyState(icon: Icons.people_rounded, title: 'No users matching filters')
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredUsers.length,
                      itemBuilder: (_, i) {
                        final u = filteredUsers[i];
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
                                    style: const TextStyle(color: Color(AppColors.primary), fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u['full_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text(u['email'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                                      if (u['role'] == 'student' && u['year'] != null) Text('Year ${u['year']}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 11)),
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
                    ),
        ),
      ],
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ActionCard(
            icon: Icons.bar_chart_rounded,
            title: 'Generate Attendance Report',
            subtitle: 'Create filtered reports for your department',
            color: const Color(AppColors.hodColor),
            onTap: () {
              final currentUser = context.read<AuthProvider>().user!;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReportsMenuScreen(currentUser: currentUser)),
              );
            },
          ),
        ),
        Expanded(
          child: _reports.isEmpty
              ? const EmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'No attendance records',
                )
              : ListView.builder(
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
                ),
        ),
      ],
    );
  }
}
