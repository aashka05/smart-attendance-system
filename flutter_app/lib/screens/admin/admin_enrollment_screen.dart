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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
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
      backgroundColor: isError ? const Color(AppColors.error) : const Color(AppColors.success),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showEnrollmentDetail(Map<String, dynamic> enrollment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(enrollment['full_name'] ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text('${enrollment['enrollment_number']} • ${enrollment['department_name']}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  )),
              const SizedBox(height: 20),
              const Text('Face Photo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              if (enrollment['face_image_b64'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(enrollment['face_image_b64']),
                    width: double.infinity, height: 250, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 250, color: Colors.grey.shade200,
                      child: const Center(child: Text('Could not load image')),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              const Text('ID Card Photo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              if (enrollment['id_card_image_b64'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(enrollment['id_card_image_b64']),
                    width: double.infinity, height: 200, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200, color: Colors.grey.shade200,
                      child: const Center(child: Text('Could not load image')),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(AppColors.warning).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(AppColors.warning).withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Color(AppColors.warning), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Compare the face photo with the ID card. Approve only if they clearly match.',
                        style: TextStyle(color: Color(AppColors.warning), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(context, enrollment),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(AppColors.error),
                        side: const BorderSide(color: Color(AppColors.error)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
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
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppColors.success),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _showRejectDialog(BuildContext context, Map<String, dynamic> enrollment) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Enrollment'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            hintText: 'Reason (optional)', border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(AppColors.error)),
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context);
              try {
                await ApiService().reviewEnrollment(
                  enrollmentId: enrollment['id'],
                  action: 'reject',
                  rejectionReason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                );
                _showSnack('Enrollment rejected');
                await _loadData();
              } catch (e) {
                _showSnack(e.toString(), isError: true);
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Enrollments'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pendingEnrollments.isEmpty
              ? const EmptyState(
                  icon: Icons.face_rounded,
                  title: 'No pending enrollments',
                  subtitle: 'All face enrollments have been reviewed',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingEnrollments.length,
                  itemBuilder: (_, i) {
                    final e = _pendingEnrollments[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        onTap: () => _showEnrollmentDetail(e),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: e['face_image_b64'] != null
                                  ? Image.memory(
                                      base64Decode(e['face_image_b64']),
                                      width: 56, height: 56, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 56, height: 56,
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                                        child: const Icon(Icons.face_rounded),
                                      ),
                                    )
                                  : Container(
                                      width: 56, height: 56,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                                      child: const Icon(Icons.face_rounded),
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
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                        fontSize: 12,
                                      )),
                                  Text(e['department_name'] ?? '',
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
                                StatusBadge(status: e['status'] ?? 'pending'),
                                const SizedBox(height: 4),
                                Text('Tap to review',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                      fontSize: 11,
                                    )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
