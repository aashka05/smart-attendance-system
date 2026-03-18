// lib/screens/admin/admin_enrollment_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class AdminEnrollmentScreen extends StatefulWidget {
  const AdminEnrollmentScreen({super.key});

  @override
  State<AdminEnrollmentScreen> createState() => _AdminEnrollmentScreenState();
}

class _AdminEnrollmentScreenState extends State<AdminEnrollmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pendingEnrollments = [];
  List<dynamic> _allEnrollments = [];
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
      final pending = await ApiService().getPendingEnrollments();
      setState(() => _pendingEnrollments = pending);
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

  void _showEnrollmentDetail(Map<String, dynamic> enrollment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EnrollmentDetailSheet(
        enrollment: enrollment,
        onApprove: () async {
          Navigator.pop(context);
          try {
            await ApiService().reviewEnrollment(
              enrollmentId: enrollment['id'],
              action: 'approve',
            );
            _showSnack('Enrollment approved ✅');
            await _loadData();
          } catch (e) {
            _showSnack(e.toString(), isError: true);
          }
        },
        onReject: (reason) async {
          Navigator.pop(context);
          try {
            await ApiService().reviewEnrollment(
              enrollmentId: enrollment['id'],
              action: 'reject',
              rejectionReason: reason,
            );
            _showSnack('Enrollment rejected');
            await _loadData();
          } catch (e) {
            _showSnack(e.toString(), isError: true);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.surface),
      appBar: AppBar(
        title: const Text('Face Enrollments', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(AppColors.primary),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(AppColors.primary),
          tabs: [
            Tab(text: 'Pending (${_pendingEnrollments.length})'),
            const Tab(text: 'All'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildEnrollmentList(_pendingEnrollments, showActions: true),
                _buildEnrollmentList(_allEnrollments, showActions: false),
              ],
            ),
    );
  }

  Widget _buildEnrollmentList(List<dynamic> enrollments, {required bool showActions}) {
    if (enrollments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.face, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              showActions ? 'No pending enrollments' : 'No enrollments yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: enrollments.length,
      itemBuilder: (_, i) {
        final e = enrollments[i];
        return GestureDetector(
          onTap: showActions ? () => _showEnrollmentDetail(e) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Row(
              children: [
                // Face thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: e['face_image_b64'] != null
                      ? Image.memory(
                          base64Decode(e['face_image_b64']),
                          width: 56, height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56, height: 56,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.face, color: Colors.grey),
                          ),
                        )
                      : Container(
                          width: 56, height: 56,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.face, color: Colors.grey),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e['full_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(e['enrollment_number'] ?? '',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text(e['department_name'] ?? '',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(status: e['status'] ?? 'pending'),
                    if (showActions) ...[
                      const SizedBox(height: 4),
                      Text('Tap to review',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EnrollmentDetailSheet extends StatelessWidget {
  final Map<String, dynamic> enrollment;
  final VoidCallback onApprove;
  final Function(String?) onReject;

  const _EnrollmentDetailSheet({
    required this.enrollment,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Student info
              Text(enrollment['full_name'] ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text('${enrollment['enrollment_number']} • ${enrollment['department_name']}',
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 20),

              // Face photo
              const Text('Face Photo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              if (enrollment['face_image_b64'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(enrollment['face_image_b64']),
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 250,
                      color: Colors.grey.shade200,
                      child: const Center(child: Text('Could not load image')),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // ID Card photo
              const Text('ID Card Photo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              if (enrollment['id_card_image_b64'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(enrollment['id_card_image_b64']),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(child: Text('Could not load image')),
                    ),
                  ),
                ),
              const SizedBox(height: 28),

              // Instruction
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFE65100), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Compare the face photo with the ID card photo. Approve only if they clearly match the same person.',
                        style: TextStyle(color: Color(0xFFE65100), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(context),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF137333),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Enrollment'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              onReject(reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim());
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
