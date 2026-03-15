// lib/widgets/common_widgets.dart

import 'package:flutter/material.dart';
import '../config.dart';

// ─────────────────────────────────────────
// APP BUTTON
// ─────────────────────────────────────────
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final IconData? icon;
  final bool outlined;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? const Color(AppColors.primary);

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon ?? Icons.check, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: btnColor,
          side: BorderSide(color: btnColor),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(double.infinity, 50),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────
// APP TEXT FIELD
// ─────────────────────────────────────────
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(AppColors.primary), width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────
// ROLE BADGE
// ─────────────────────────────────────────
class RoleBadge extends StatelessWidget {
  final String role;
  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final config = _roleConfig(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config['bg'] as Color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        config['label'] as String,
        style: TextStyle(
          color: config['fg'] as Color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Map<String, dynamic> _roleConfig(String role) {
    switch (role) {
      case 'admin':
        return {'label': 'Admin', 'bg': const Color(0xFFE8F0FE), 'fg': const Color(0xFF1A73E8)};
      case 'faculty':
        return {'label': 'Faculty', 'bg': const Color(0xFFE6F4EA), 'fg': const Color(0xFF137333)};
      case 'student':
        return {'label': 'Student', 'bg': const Color(0xFFFCE8E6), 'fg': const Color(0xFFC5221F)};
      case 'hod':
        return {'label': 'HOD', 'bg': const Color(0xFFFFF3E0), 'fg': const Color(0xFFE65100)};
      case 'principal':
        return {'label': 'Principal', 'bg': const Color(0xFFF3E5F5), 'fg': const Color(0xFF6A1B9A)};
      default:
        return {'label': role, 'bg': Colors.grey.shade100, 'fg': Colors.grey.shade700};
    }
  }
}

// ─────────────────────────────────────────
// STATUS BADGE
// ─────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'approved':
        bg = const Color(0xFFE6F4EA); fg = const Color(0xFF137333); label = 'Approved';
        break;
      case 'pending':
        bg = const Color(0xFFFFF3E0); fg = const Color(0xFFE65100); label = 'Pending';
        break;
      case 'rejected':
        bg = const Color(0xFFFCE8E6); fg = const Color(0xFFC5221F); label = 'Rejected';
        break;
      default:
        bg = Colors.grey.shade100; fg = Colors.grey.shade700; label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Text(subtitle!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

// ─────────────────────────────────────────
// STAT CARD
// ─────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// ERROR BANNER
// ─────────────────────────────────────────
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const ErrorBanner({super.key, required this.message, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE8E6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEA4335).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEA4335), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Color(0xFFC5221F), fontSize: 13)),
          ),
          if (onDismiss != null)
            GestureDetector(onTap: onDismiss, child: const Icon(Icons.close, size: 18, color: Color(0xFFC5221F))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// LOADING OVERLAY
// ─────────────────────────────────────────
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({super.key, required this.isLoading, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
