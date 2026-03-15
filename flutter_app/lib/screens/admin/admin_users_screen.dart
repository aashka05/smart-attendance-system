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

class _AdminUsersScreenState extends State<AdminUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _allUsers = [];
  List<dynamic> _pendingUsers = [];
  bool _loading = false;
  String _searchQuery = '';

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
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  List<dynamic> get _filteredAll {
    if (_searchQuery.isEmpty) return _allUsers;
    return _allUsers.where((u) =>
      u['full_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
      u['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.surface),
      appBar: AppBar(
        title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(AppColors.primary),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(AppColors.primary),
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
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No pending approvals', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
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
                  style: const TextStyle(color: Color(AppColors.primary), fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(user['email'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              StatusBadge(status: user['status'] ?? 'pending'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              RoleBadge(role: user['role'] ?? ''),
              if (user['department_name'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(user['department_name'], style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                ),
              if (user['enrollment_number'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                  child: Text('Roll: ${user['enrollment_number']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF137333),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
