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
  bool _obscurePassword = true;
  List<dynamic> _departments = [];
  bool _loadingDepts = false;

  final _roles = [
    {'value': Roles.student, 'label': 'Student', 'icon': Icons.school},
    {'value': Roles.faculty, 'label': 'Faculty', 'icon': Icons.person},
    {'value': Roles.hod, 'label': 'Head of Department', 'icon': Icons.supervisor_account},
    {'value': Roles.principal, 'label': 'Principal', 'icon': Icons.account_balance},
    {'value': Roles.admin, 'label': 'Admin', 'icon': Icons.admin_panel_settings},
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

  bool get _needsDept => [Roles.student, Roles.faculty, Roles.hod].contains(_selectedRole);
  bool get _needsEnrollment => _selectedRole == Roles.student;
  bool get _needsEmployeeId => [Roles.faculty, Roles.hod].contains(_selectedRole);

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_needsDept && _selectedDeptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department'), backgroundColor: Colors.red),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      role: _selectedRole,
      departmentId: _selectedDeptId,
      enrollmentNumber: _needsEnrollment ? _enrollmentCtrl.text.trim() : null,
      employeeId: _needsEmployeeId ? _employeeCtrl.text.trim() : null,
    );

    if (mounted) {
      if (success) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F4EA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Color(0xFF137333), size: 36),
                ),
                const SizedBox(height: 16),
                const Text('Registration Successful!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Your account is pending approval. You will be notified once approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Registration failed'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(AppColors.surface),
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role selection
              const Text('Select Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(AppColors.primary) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(AppColors.primary) : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            role['icon'] as IconData,
                            size: 16,
                            color: isSelected ? Colors.white : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            role['label'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                prefixIcon: Icons.person_outline,
                validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

              // Department (conditional)
              if (_needsDept) ...[
                DropdownButtonFormField<String>(
                  value: _selectedDeptId,
                  decoration: InputDecoration(
                    labelText: 'Department',
                    prefixIcon: const Icon(Icons.business_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  hint: _loadingDepts
                      ? const Text('Loading...')
                      : const Text('Select Department'),
                  items: _departments.map<DropdownMenuItem<String>>((dept) {
                    return DropdownMenuItem(
                      value: dept['id'] as String,
                      child: Text(dept['name'] as String),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedDeptId = v),
                ),
                const SizedBox(height: 16),
              ],

              // Enrollment (student only)
              if (_needsEnrollment) ...[
                AppTextField(
                  label: 'Enrollment Number',
                  controller: _enrollmentCtrl,
                  prefixIcon: Icons.badge_outlined,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enrollment number is required' : null,
                ),
                const SizedBox(height: 16),
              ],

              // Employee ID (faculty/hod)
              if (_needsEmployeeId) ...[
                AppTextField(
                  label: 'Employee ID',
                  controller: _employeeCtrl,
                  prefixIcon: Icons.badge_outlined,
                  validator: (v) => (v == null || v.isEmpty) ? 'Employee ID is required' : null,
                ),
                const SizedBox(height: 16),
              ],

              // Password
              AppTextField(
                label: 'Password',
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm Password
              AppTextField(
                label: 'Confirm Password',
                controller: _confirmCtrl,
                obscureText: true,
                prefixIcon: Icons.lock_outline,
                validator: (v) {
                  if (v != _passwordCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Pending notice
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
                        'Your account will be reviewed and approved by an admin before you can log in.',
                        style: TextStyle(color: Color(0xFFE65100), fontSize: 12),
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
                icon: Icons.person_add,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
