// lib/screens/auth/pending_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../config.dart';

class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    return Scaffold(
      backgroundColor: const Color(AppColors.surface),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE65100).withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.hourglass_empty, color: Color(0xFFE65100), size: 48),
              ),
              const SizedBox(height: 32),
              const Text(
                'Pending Approval',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Hi ${user.fullName},',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Your account is under review. An admin will approve your registration shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    _InfoRow(label: 'Name', value: user.fullName),
                    const Divider(height: 20),
                    _InfoRow(label: 'Email', value: user.email),
                    const Divider(height: 20),
                    _InfoRow(label: 'Role', value: user.roleDisplay),
                    if (user.departmentName != null) ...[
                      const Divider(height: 20),
                      _InfoRow(label: 'Department', value: user.departmentName!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 48),
              TextButton.icon(
                onPressed: () => context.read<AuthProvider>().logout(),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign Out'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
