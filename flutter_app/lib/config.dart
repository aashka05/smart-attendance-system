// lib/config.dart

class AppConfig {
  static const String baseUrl = "http://192.168.1.117";
  //static const String baseUrl = "http://59.95.100.34:45810";
  //static const String baseUrl = "http://192.168.1.102";
  static const int manufacturerId = 0x4154;
  static const int bleScanDuration = 30;
  static const String appName = "AttendX";
  static const double attendanceThreshold = 75.0;
  static const int academicYearStartMonth = 7;
}

class AppColors {
  static const int primary = 0xFF3D5AFE;
  static const int primaryLight = 0xFF8187FF;
  static const int primaryDark = 0xFF0031CA;
  static const int adminColor = 0xFF3D5AFE;
  static const int facultyColor = 0xFF10B981;
  static const int studentColor = 0xFFF59E0B;
  static const int hodColor = 0xFFF43F5E;
  static const int principalColor = 0xFF8B5CF6;
  static const int success = 0xFF10B981;
  static const int error = 0xFFEF4444;
  static const int warning = 0xFFF59E0B;
  static const int info = 0xFF3B82F6;
  static const int present = 0xFF10B981;
  static const int absent = 0xFFEF4444;
  static const int holiday = 0xFFF59E0B;
  static const int cancelled = 0xFFF97316;
  static const int exam = 0xFF8B5CF6;
  static const int fest = 0xFF3B82F6;
  static const int lightBackground = 0xFFF8FAFC;
  static const int lightSurface = 0xFFFFFFFF;
  static const int lightBorder = 0xFFE2E8F0;
  static const int lightText = 0xFF0F172A;
  static const int lightTextSecondary = 0xFF64748B;
  static const int darkBackground = 0xFF0F172A;
  static const int darkSurface = 0xFF1E293B;
  static const int darkBorder = 0xFF334155;
  static const int darkText = 0xFFF1F5F9;
  static const int darkTextSecondary = 0xFF94A3B8;
}

class Roles {
  static const String admin = "admin";
  static const String faculty = "faculty";
  static const String student = "student";
  static const String hod = "hod";
  static const String principal = "principal";
}

class UserStatus {
  static const String pending = "pending";
  static const String approved = "approved";
  static const String rejected = "rejected";
}

class LectureTypes {
  static const String lecture = "lecture";
  static const String practical = "practical";
  static const String tutorial = "tutorial";
  static const String openElective = "open_elective";
  static const String programElective = "program_elective";

  static String display(String type) {
    switch (type) {
      case lecture: return "Lecture";
      case practical: return "Practical";
      case tutorial: return "Tutorial";
      case openElective: return "Open Elective";
      case programElective: return "Program Elective";
      default: return type;
    }
  }
}

class EventTypes {
  static const String holiday = "holiday";
  static const String exam = "exam";
  static const String fest = "fest";
  static const String expertTalk = "expert_talk";

  static String display(String type) {
    switch (type) {
      case holiday: return "Holiday";
      case exam: return "Exam";
      case fest: return "College Fest";
      case expertTalk: return "Expert Talk";
      default: return type;
    }
  }
}
