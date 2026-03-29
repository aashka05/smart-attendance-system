// lib/models/user_model.dart

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String status;
  final String? departmentId;
  final String? departmentName;
  final String? enrollmentNumber;
  final String? employeeId;
  final bool faceEnrolled;
  final String createdAt;
  final int? year;
  final String? practicalBatch;
  final String? tutorialBatch;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    this.departmentId,
    this.departmentName,
    this.enrollmentNumber,
    this.employeeId,
    this.faceEnrolled = false,
    required this.createdAt,
    this.year,
    this.practicalBatch,
    this.tutorialBatch,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      status: json['status'] ?? 'pending',
      departmentId: json['department_id'],
      departmentName: json['department_name'],
      enrollmentNumber: json['enrollment_number'],
      employeeId: json['employee_id'],
      faceEnrolled: (json['face_enrolled'] ?? 0) == 1,
      createdAt: json['created_at'] ?? '',
      year: json['year'],
      practicalBatch: json['practical_batch'],
      tutorialBatch: json['tutorial_batch'],
    );
  }

  String get roleDisplay {
    switch (role) {
      case 'admin': return 'Admin';
      case 'faculty': return 'Faculty';
      case 'student': return 'Student';
      case 'hod': return 'Head of Department';
      case 'principal': return 'Principal';
      default: return role;
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'pending': return 'Pending Approval';
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      default: return status;
    }
  }

  String get yearDisplay => year != null ? 'Year $year' : '';
}
