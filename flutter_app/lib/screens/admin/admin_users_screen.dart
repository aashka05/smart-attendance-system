// lib/screens/admin/admin_users_screen.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class AdminUsersScreen extends StatefulWidget {
  final int initialTab;
  const AdminUsersScreen({super.key, this.initialTab = 0});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _allUsers = [];
  List<dynamic> _pendingUsers = [];
  bool _loading = false;
  String _searchQuery = '';
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
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
      final all = await ApiService().getAllUsers();
      final pending = await ApiService().getPendingUsers();
      setState(() { _allUsers = all; _pendingUsers = pending; });
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
    setState(() => _loading = false);
  }

  Future<void> _handleApproval(String userId, String action) async {
    try {
      await ApiService().approveUser(userId, action);
      _showSnack('User ${action}d successfully');
      await _loadData();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(AppColors.error) : const Color(AppColors.success),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  List<dynamic> get _filteredAll {
    return _allUsers.where((u) {
      final matchSearch = _searchQuery.isEmpty ||
          u['full_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchRole = _roleFilter == null || u['role'] == _roleFilter;
      return matchSearch && matchRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'All Users'),
            Tab(text: 'Pending (${_pendingUsers.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildAllUsers(), _buildPendingUsers()],
            ),
    );
  }

  Widget _buildAllUsers() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String?>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.filter_list_rounded, size: 20),
                ),
                onSelected: (v) => setState(() => _roleFilter = v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: null, child: Text('All Roles')),
                  const PopupMenuItem(value: 'student', child: Text('Students')),
                  const PopupMenuItem(value: 'faculty', child: Text('Faculty')),
                  const PopupMenuItem(value: 'hod', child: Text('HOD')),
                  const PopupMenuItem(value: 'principal', child: Text('Principal')),
                  const PopupMenuItem(value: 'admin', child: Text('Admin')),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredAll.length,
            itemBuilder: (_, i) => _UserCard(
              user: _filteredAll[i],
              showActions: _filteredAll[i]['status'] == 'pending',
              onApprove: () => _handleApproval(_filteredAll[i]['id'], 'approve'),
              onReject: () => _handleApproval(_filteredAll[i]['id'], 'reject'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingUsers() {
    if (_pendingUsers.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'No pending approvals',
        subtitle: 'All registrations have been reviewed',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingUsers.length,
      itemBuilder: (_, i) => _UserCard(
        user: _pendingUsers[i],
        showActions: true,
        onApprove: () => _handleApproval(_pendingUsers[i]['id'], 'approve'),
        onReject: () => _handleApproval(_pendingUsers[i]['id'], 'reject'),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool showActions;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _UserCard({
    required this.user,
    required this.showActions,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(AppColors.primary).withOpacity(0.1),
                child: Text(
                  (user['full_name'] as String).isNotEmpty
                      ? (user['full_name'] as String)[0].toUpperCase()
                      : '?',
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
                    Text(user['full_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(user['email'] ?? '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
              StatusBadge(status: user['status'] ?? 'pending'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              RoleBadge(role: user['role'] ?? ''),
              if (user['department_name'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(user['department_name'],
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      )),
                ),
              if (user['year'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Year ${user['year']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      )),
                ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(AppColors.error),
                      side: const BorderSide(color: Color(AppColors.error)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppColors.success),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
