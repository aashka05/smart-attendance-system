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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: const Color(AppColors.warning).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_empty_rounded,
                    color: Color(AppColors.warning), size: 44),
              ),
              const SizedBox(height: 24),
              const Text('Pending Approval',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Hi ${user.fullName},',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Your account is under review. An admin will approve your registration shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14, height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    _InfoRow(label: 'Name', value: user.fullName),
                    Divider(height: 20,
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                    _InfoRow(label: 'Email', value: user.email),
                    Divider(height: 20,
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                    _InfoRow(label: 'Role', value: user.roleDisplay),
                    if (user.departmentName != null) ...[
                      Divider(height: 20,
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                      _InfoRow(label: 'Department', value: user.departmentName!),
                    ],
                    if (user.year != null) ...[
                      Divider(height: 20,
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                      _InfoRow(label: 'Year', value: 'Year ${user.year}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: () => context.read<AuthProvider>().logout(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
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
        Text(label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              fontSize: 13,
            )),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
