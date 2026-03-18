// lib/config.dart

class AppConfig {
  // ⚠️ CHANGE THIS to your laptop's local IP address
  static const String baseUrl = "http://192.168.1.108:8000";

  // BLE
  static const int manufacturerId = 0x4154; // "AT" in hex
  static const int bleScanDuration = 30; // seconds

  // App
  static const String appName = "AttendX";
}

class AppColors {
  static const int primary = 0xFF1A73E8;
  static const int secondary = 0xFF34A853;
  static const int error = 0xFFEA4335;
  static const int warning = 0xFFFBBC04;
  static const int surface = 0xFFF8F9FA;
  static const int background = 0xFFFFFFFF;
}

// Role constants
class Roles {
  static const String admin = "admin";
  static const String faculty = "faculty";
  static const String student = "student";
  static const String hod = "hod";
  static const String principal = "principal";
}

// User status
class UserStatus {
  static const String pending = "pending";
  static const String approved = "approved";
  static const String rejected = "rejected";
}
