// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _loadingStats = false;

  late TextEditingController _nameController;
  late TextEditingController _practicalBatchController;
  late TextEditingController _tutorialBatchController;

  Map<String, dynamic>? _studentStats;
  Map<String, dynamic>? _enrollmentStatus;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _nameController = TextEditingController(text: user.fullName);
    _practicalBatchController = TextEditingController(text: user.practicalBatch ?? '');
    _tutorialBatchController = TextEditingController(text: user.tutorialBatch ?? '');

    if (user.role == 'student') {
      _loadStudentData(user.id);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _practicalBatchController.dispose();
    _tutorialBatchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData(String studentId) async {
    setState(() => _loadingStats = true);
    try {
      final results = await Future.wait([
        ApiService().getStudentStats(studentId),
        ApiService().getEnrollmentStatus(),
      ]);
      if (mounted) {
        setState(() {
          _studentStats = results[0];
          _enrollmentStatus = results[1];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingStats = false);
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(AppColors.adminColor);
      case 'faculty':
        return const Color(AppColors.facultyColor);
      case 'student':
        return const Color(AppColors.studentColor);
      case 'hod':
        return const Color(AppColors.hodColor);
      case 'principal':
        return const Color(AppColors.principalColor);
      default:
        return Colors.grey;
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await ApiService().updateProfile(
        fullName: _nameController.text.trim(),
        practicalBatch: _practicalBatchController.text.trim().isEmpty
            ? null
            : _practicalBatchController.text.trim(),
        tutorialBatch: _tutorialBatchController.text.trim().isEmpty
            ? null
            : _tutorialBatchController.text.trim(),
      );
      if (mounted) {
        await context.read<AuthProvider>().tryAutoLogin();
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile updated'),
          backgroundColor: const Color(AppColors.success),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(AppColors.error),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final roleColor = _roleColor(user.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded, size: 22),
            onPressed: () {
              if (_isEditing) {
                // Cancel editing - restore original values
                _nameController.text = user.fullName;
                _practicalBatchController.text = user.practicalBatch ?? '';
                _tutorialBatchController.text = user.tutorialBatch ?? '';
              }
              setState(() => _isEditing = !_isEditing);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Header Section ──
            _buildHeader(user, roleColor),
            const SizedBox(height: 24),

            // ── Info Card ──
            _buildInfoCard(user),
            const SizedBox(height: 16),

            // ── Edit Fields (students: batches) ──
            if (_isEditing && user.role == 'student') ...[
              AppTextField(
                label: 'Practical Batch',
                controller: _practicalBatchController,
                prefixIcon: Icons.science_rounded,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Tutorial Batch',
                controller: _tutorialBatchController,
                prefixIcon: Icons.menu_book_rounded,
              ),
              const SizedBox(height: 16),
            ],

            // ── Save Button ──
            if (_isEditing) ...[
              AppButton(
                label: 'Save Changes',
                onPressed: _saveProfile,
                isLoading: _isSaving,
                icon: Icons.check_rounded,
              ),
              const SizedBox(height: 24),
            ],

            // ── Student-only sections (only when NOT editing) ──
            if (user.role == 'student' && !_isEditing) ...[
              _buildEnrollmentCard(user),
              const SizedBox(height: 14),
              _buildAttendanceCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(user, Color roleColor) {
    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: roleColor.withOpacity(0.15),
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: roleColor,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_isEditing)
          SizedBox(
            width: 260,
            child: AppTextField(
              label: 'Full Name',
              controller: _nameController,
              prefixIcon: Icons.person_rounded,
            ),
          )
        else
          Text(
            user.fullName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 8),
        RoleBadge(role: user.role),
      ],
    );
  }

  Widget _buildInfoCard(user) {
    final items = <MapEntry<String, String>>[];

    items.add(MapEntry('Email', user.email));
    if (user.departmentName != null) {
      items.add(MapEntry('Department', user.departmentName!));
    }
    if (user.role == 'student' && user.enrollmentNumber != null) {
      items.add(MapEntry('Enrollment No.', user.enrollmentNumber!));
    }
    if ((user.role == 'faculty' || user.role == 'hod') && user.employeeId != null) {
      items.add(MapEntry('Employee ID', user.employeeId!));
    }
    if (user.year != null) {
      items.add(MapEntry('Year', user.yearDisplay));
    }
    if (user.practicalBatch != null && user.practicalBatch!.isNotEmpty) {
      items.add(MapEntry('Practical Batch', user.practicalBatch!));
    }
    if (user.tutorialBatch != null && user.tutorialBatch!.isNotEmpty) {
      items.add(MapEntry('Tutorial Batch', user.tutorialBatch!));
    }
    items.add(MapEntry('Status', user.statusDisplay));
    items.add(MapEntry('Joined', _formatDate(user.createdAt)));

    return AppCard(
      child: Column(
        children: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final kv = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Text(
                      kv.key,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        kv.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
              if (idx < items.length - 1) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEnrollmentCard(user) {
    if (_loadingStats) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading enrollment status...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final enrollmentStatusStr = _enrollmentStatus?['status'] as String?;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (user.faceEnrolled || enrollmentStatusStr == 'approved') {
      statusColor = const Color(AppColors.success);
      statusIcon = Icons.check_circle_rounded;
      statusText = 'Face Enrolled';
    } else if (enrollmentStatusStr == 'pending') {
      statusColor = const Color(AppColors.warning);
      statusIcon = Icons.hourglass_top_rounded;
      statusText = 'Enrollment Pending';
    } else {
      statusColor = const Color(AppColors.error);
      statusIcon = Icons.cancel_rounded;
      statusText = 'Not Enrolled';
    }

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Face Enrollment',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard() {
    if (_loadingStats) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading attendance stats...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final overall = (_studentStats?['overall_percentage'] as num?)?.toDouble() ?? 0.0;
    final attended = (_studentStats?['attended'] as num?)?.toInt() ?? 0;
    final total = (_studentStats?['total'] as num?)?.toInt() ?? 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(AppColors.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    color: Color(AppColors.primary), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Attendance Overview',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              AttendancePercent(percentage: overall),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  'Attended',
                  '$attended',
                  const Color(AppColors.success),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Theme.of(context).dividerColor,
              ),
              Expanded(
                child: _miniStat(
                  'Total Classes',
                  '$total',
                  const Color(AppColors.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
