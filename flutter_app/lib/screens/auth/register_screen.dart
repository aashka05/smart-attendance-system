// lib/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _enrollmentCtrl = TextEditingController();
  final _employeeCtrl = TextEditingController();

  String _selectedRole = Roles.student;
  String? _selectedDeptId;
  int? _selectedYear;
  bool _obscurePassword = true;
  List<dynamic> _departments = [];
  bool _loadingDepts = false;

  final _roles = [
    {'value': Roles.student, 'label': 'Student', 'icon': Icons.school_rounded},
    {'value': Roles.faculty, 'label': 'Faculty', 'icon': Icons.person_rounded},
    {'value': Roles.hod, 'label': 'HOD', 'icon': Icons.supervisor_account_rounded},
    {'value': Roles.principal, 'label': 'Principal', 'icon': Icons.account_balance_rounded},
    {'value': Roles.admin, 'label': 'Admin', 'icon': Icons.admin_panel_settings_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() => _loadingDepts = true);
    try {
      final depts = await ApiService().getDepartments();
      setState(() => _departments = depts);
    } catch (_) {}
    setState(() => _loadingDepts = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _enrollmentCtrl.dispose();
    _employeeCtrl.dispose();
    super.dispose();
  }

  bool get _needsDept =>
      [Roles.student, Roles.faculty, Roles.hod].contains(_selectedRole);
  bool get _needsEnrollment => _selectedRole == Roles.student;
  bool get _needsEmployeeId =>
      [Roles.faculty, Roles.hod].contains(_selectedRole);
  bool get _needsYear => _selectedRole == Roles.student;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_needsDept && _selectedDeptId == null) {
      _showSnack('Please select a department');
      return;
    }
    if (_needsYear && _selectedYear == null) {
      _showSnack('Please select your year');
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      role: _selectedRole,
      departmentId: _selectedDeptId,
      enrollmentNumber:
          _needsEnrollment ? _enrollmentCtrl.text.trim() : null,
      employeeId: _needsEmployeeId ? _employeeCtrl.text.trim() : null,
      year: _needsYear ? _selectedYear : null,
    );

    if (mounted) {
      if (success) {
        _showSuccessDialog();
      } else {
        _showSnack(auth.error ?? 'Registration failed');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(AppColors.error),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: const Color(AppColors.success).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(AppColors.success),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Registration Submitted!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Your account is pending approval. You will be able to log in once an admin approves it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Back to Login'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role selection
              const Text(
                'Select Role',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _roles.map((role) {
                  final isSelected = _selectedRole == role['value'];
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedRole = role['value'] as String;
                      _selectedDeptId = null;
                      _selectedYear = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(AppColors.primary)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(AppColors.primary)
                              : Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            role['icon'] as IconData,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            role['label'] as String,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Full Name
              AppTextField(
                label: 'Full Name',
                controller: _nameCtrl,
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),

              // Email
              AppTextField(
                label: 'Email Address',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Department
              if (_needsDept) ...[
                DropdownButtonFormField<String>(
                  value: _selectedDeptId,
                  decoration: InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(
                      Icons.business_outlined,
                      size: 20,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                  ),
                  hint: Text(
                    _loadingDepts ? 'Loading...' : 'Select Department',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                    ),
                  ),
                  items: _departments
                      .map<DropdownMenuItem<String>>((dept) =>
                          DropdownMenuItem(
                            value: dept['id'] as String,
                            child: Text(dept['name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedDeptId = v),
                ),
                const SizedBox(height: 14),
              ],

              // Year (student only)
              if (_needsYear) ...[
                DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    prefixIcon: Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                  ),
                  hint: Text(
                    'Select Year',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                    ),
                  ),
                  items: [1, 2, 3, 4]
                      .map((y) => DropdownMenuItem(
                            value: y,
                            child: Text('Year $y'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedYear = v),
                ),
                const SizedBox(height: 14),
              ],

              // Enrollment Number
              if (_needsEnrollment) ...[
                AppTextField(
                  label: 'Enrollment Number',
                  controller: _enrollmentCtrl,
                  prefixIcon: Icons.badge_outlined,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Enrollment number is required'
                      : null,
                ),
                const SizedBox(height: 14),
              ],

              // Employee ID
              if (_needsEmployeeId) ...[
                AppTextField(
                  label: 'Employee ID',
                  controller: _employeeCtrl,
                  prefixIcon: Icons.badge_outlined,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Employee ID is required'
                      : null,
                ),
                const SizedBox(height: 14),
              ],

              // Password
              AppTextField(
                label: 'Password',
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Confirm Password',
                controller: _confirmCtrl,
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (v) {
                  if (v != _passwordCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(AppColors.warning).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(AppColors.warning).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Color(AppColors.warning), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your account requires admin approval before you can sign in.',
                        style: TextStyle(
                          color: const Color(AppColors.warning)
                              .withOpacity(0.9),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              AppButton(
                label: 'Create Account',
                onPressed: _register,
                isLoading: auth.isLoading,
                icon: Icons.person_add_rounded,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
