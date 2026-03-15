// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_provider.dart';
import 'config.dart';

// Auth screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/pending_screen.dart';

// Role dashboards
import 'screens/admin/admin_dashboard.dart';
import 'screens/faculty/faculty_dashboard.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/hod/hod_dashboard.dart';
import 'screens/principal/principal_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const AttendanceApp(),
    ),
  );
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(AppColors.primary)),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(AppColors.surface),
      ),
      home: const SplashRouter(),
    );
  }
}

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});
  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await context.read<AuthProvider>().tryAutoLogin();
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const SplashScreen();
    }

    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    final user = auth.user!;

    // Rejected
    if (user.status == UserStatus.rejected) {
      return const RejectedScreen();
    }

    // Pending
    if (user.status == UserStatus.pending) {
      return const PendingScreen();
    }

    // Route by role
    switch (user.role) {
      case Roles.admin:
        return const AdminDashboard();
      case Roles.faculty:
        return const FacultyDashboard();
      case Roles.student:
        return const StudentDashboard();
      case Roles.hod:
        return const HodDashboard();
      case Roles.principal:
        return const PrincipalDashboard();
      default:
        return const LoginScreen();
    }
  }
}

// ─────────────────────────────────────────
// SPLASH SCREEN
// ─────────────────────────────────────────
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.primary),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              AppConfig.appName,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Smart Attendance System',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// REJECTED SCREEN
// ─────────────────────────────────────────
class RejectedScreen extends StatelessWidget {
  const RejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.surface),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFFFCE8E6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel, color: Color(0xFFEA4335), size: 48),
              ),
              const SizedBox(height: 24),
              const Text('Account Rejected',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(
                'Your account registration was rejected. Please contact your administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => context.read<AuthProvider>().logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppColors.primary),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
