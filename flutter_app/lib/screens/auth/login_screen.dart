// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Login failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(AppColors.surface),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                // Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(AppColors.primary),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.school, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    AppConfig.appName,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ),
                Center(
                  child: Text(
                    'Smart Attendance System',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 48),
                const Text('Welcome back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Sign in to your account', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 28),

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
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Login button
                AppButton(
                  label: 'Sign In',
                  onPressed: _login,
                  isLoading: auth.isLoading,
                  icon: Icons.login,
                ),
                const SizedBox(height: 24),

                // Register link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ", style: TextStyle(color: Colors.grey.shade600)),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            color: Color(AppColors.primary),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Dev hint
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🧪 Test Credentials', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      SizedBox(height: 4),
                      Text('admin@college.edu / admin123', style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
