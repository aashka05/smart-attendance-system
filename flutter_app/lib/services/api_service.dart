// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage();
  String? _token;

  // ─────────────────────────────────────────
  // TOKEN MANAGEMENT
  // ─────────────────────────────────────────
  Future<void> saveToken(String token) async {
    _token = token;
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<String?> getToken() async {
    _token ??= await _storage.read(key: 'jwt_token');
    return _token;
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_data');
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: 'user_data', value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getSavedUser() async {
    final data = await _storage.read(key: 'user_data');
    if (data == null) return null;
    return jsonDecode(data);
  }

  // ─────────────────────────────────────────
  // HEADERS
  // ─────────────────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

  // ─────────────────────────────────────────
  // AUTH
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? departmentId,
    String? enrollmentNumber,
    String? employeeId,
    int? year,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/register'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
        'role': role,
        'department_id': departmentId,
        'enrollment_number': enrollmentNumber,
        'employee_id': employeeId,
        'year': year,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'username': email,
        'password': password,
      },
    );
    final data = _handleResponse(response);
    if (data['access_token'] != null) {
      await saveToken(data['access_token']);
      await saveUser(data['user']);
    }
    return data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/auth/me'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // ADMIN
  // ─────────────────────────────────────────
  Future<List<dynamic>> getPendingUsers() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/admin/pending-users'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  Future<List<dynamic>> getAllUsers() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/admin/all-users'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  Future<Map<String, dynamic>> approveUser(String userId, String action) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/admin/approve-user'),
      headers: await _authHeaders(),
      body: jsonEncode({'user_id': userId, 'action': action}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> importCsv(String endpoint, String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/admin/import/$endpoint'),
    );
    final headers = await _authHeaders();
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // DEPARTMENTS
  // ─────────────────────────────────────────
  Future<List<dynamic>> getDepartments() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/departments'),
      headers: _jsonHeaders,
    );
    return _handleResponse(response) as List;
  }

  Future<Map<String, dynamic>> createDepartment(String name) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/departments'),
      headers: await _authHeaders(),
      body: jsonEncode({'name': name}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> deleteDepartment(String id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/departments/$id'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // SUBJECTS
  // ─────────────────────────────────────────
  Future<List<dynamic>> getSubjects() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/subjects'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  Future<Map<String, dynamic>> createSubject({
    required String name,
    required String code,
    required String departmentId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/subjects'),
      headers: await _authHeaders(),
      body: jsonEncode({'name': name, 'code': code, 'department_id': departmentId}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> deleteSubject(String id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/subjects/$id'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // TIMETABLE
  // ─────────────────────────────────────────
  Future<List<dynamic>> getTimetable() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/timetable'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  Future<Map<String, dynamic>> createSlot({
    required String subjectId,
    required String facultyId,
    required String departmentId,
    String? section,
    required String dayOfWeek,
    required String startTime,
    required String endTime,
    required String room,
    int? year,
    String? lectureType,
    String? batch,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/timetable'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'subject_id': subjectId,
        'faculty_id': facultyId,
        'department_id': departmentId,
        'section': section,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'room': room,
        'year': year,
        'lecture_type': lectureType ?? 'lecture',
        'batch': batch,
      }),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // ATTENDANCE / BLE
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> startAttendance(String slotId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/attendance/start'),
      headers: await _authHeaders(),
      body: jsonEncode({'slot_id': slotId}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> stopAttendance(String sessionId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/attendance/stop/$sessionId'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> reportBleDetected({
    required String token,
    required int rssi,
    required String timestamp,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/ble/detected'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'token': token,
        'rssi': rssi,
        'timestamp': timestamp,
      }),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> getBleEvents() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/ble/events'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  // ─────────────────────────────────────────
  // HOD
  // ─────────────────────────────────────────
  Future<List<dynamic>> getHodDepartmentUsers() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/hod/department-users'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  Future<List<dynamic>> getHodPendingUsers() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/hod/pending-users'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  Future<Map<String, dynamic>> hodApproveUser(String userId, String action) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/hod/approve-user'),
      headers: await _authHeaders(),
      body: jsonEncode({'user_id': userId, 'action': action}),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // REPORTS
  // ─────────────────────────────────────────
  Future<List<dynamic>> getAttendanceReport() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/reports/attendance'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  // ─────────────────────────────────────────
  // FACE ENROLLMENT
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> checkDuplicateFace({
    required String faceImageB64,
    required String idCardImageB64,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/enrollment/check-duplicate'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'face_image_b64': faceImageB64,
        'id_card_image_b64': idCardImageB64,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> submitFaceEnrollment({
    required String faceImageB64,
    required String idCardImageB64,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/enrollment/submit'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'face_image_b64': faceImageB64,
        'id_card_image_b64': idCardImageB64,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getEnrollmentStatus() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/enrollment/status'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> getPendingEnrollments() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/enrollment/pending'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  Future<Map<String, dynamic>> reviewEnrollment({
    required String enrollmentId,
    required String action,
    String? rejectionReason,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/enrollment/review'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'enrollment_id': enrollmentId,
        'action': action,
        'rejection_reason': rejectionReason,
      }),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // FACE RECOGNITION
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> getLivenessChallenge({
    required String sessionId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/attendance/challenge'),
      headers: await _authHeaders(),
      body: jsonEncode({'session_id': sessionId}),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> verifyFace({
    required String sessionId,
    required String token,
    required String faceImageB64,
    required String challengeId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/attendance/verify-face'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'session_id': sessionId,
        'token': token,
        'face_image_b64': faceImageB64,
        'challenge_id': challengeId,
      }),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // STUDENT STATS
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> getStudentStats(String studentId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/stats/student/$studentId'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getStudentCalendar({
    required String studentId,
    required int month,
    required int year,
    String? subjectId,
  }) async {
    var url = '${AppConfig.baseUrl}/stats/calendar/$studentId?month=$month&year=$year';
    if (subjectId != null) url += '&subject_id=$subjectId';
    final response = await http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // CLASS STATS (faculty/admin/hod)
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> getClassStats(String slotId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/stats/class/$slotId'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getClassCalendar({
    required String slotId,
    required int month,
    required int year,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/stats/class/calendar/$slotId?month=$month&year=$year'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> getSessionAttendees(String sessionId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/stats/session/$sessionId/attendees'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // EVENTS
  // ─────────────────────────────────────────
  Future<List<dynamic>> getEvents({
    int? month,
    int? year,
    String? departmentId,
    int? yearLevel,
  }) async {
    var url = '${AppConfig.baseUrl}/events?';
    if (month != null) url += 'month=$month&';
    if (year != null) url += 'year=$year&';
    if (departmentId != null) url += 'department_id=$departmentId&';
    if (yearLevel != null) url += 'year_level=$yearLevel&';
    final response = await http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  Future<Map<String, dynamic>> createEvent({
    required String title,
    required String date,
    required String eventType,
    String? departmentId,
    int? year,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/events'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'title': title,
        'date': date,
        'event_type': eventType,
        'department_id': departmentId,
        'year': year,
        'description': description,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> deleteEvent(String eventId) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/events/$eventId'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> cancelLecture({
    required String slotId,
    required String date,
    String? reason,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/lectures/cancel'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'slot_id': slotId,
        'date': date,
        'reason': reason,
      }),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> getCancelledLectures({String? slotId}) async {
    var url = '${AppConfig.baseUrl}/lectures/cancelled';
    if (slotId != null) url += '?slot_id=$slotId';
    final response = await http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  Future<Map<String, dynamic>> restoreLecture(String cancelId) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/lectures/cancelled/$cancelId'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // DIVISIONS
  // ─────────────────────────────────────────
  Future<List<dynamic>> getDivisions() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/divisions'),
      headers: await _authHeaders(),
    );
    return _handleResponse(response) as List;
  }

  // ─────────────────────────────────────────
  // PROFILE
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String? practicalBatch,
    String? tutorialBatch,
  }) async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/auth/profile'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'full_name': fullName,
        'practical_batch': practicalBatch,
        'tutorial_batch': tutorialBatch,
      }),
    );
    return _handleResponse(response);
  }

  // ─────────────────────────────────────────
  // RESPONSE HANDLER
  // ─────────────────────────────────────────
  dynamic _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: body['detail'] ?? 'Something went wrong',
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
