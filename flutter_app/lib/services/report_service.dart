// lib/services/report_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'api_service.dart';

class ReportOptions {
  final String role;
  final Map<String, dynamic> filters;
  final List<String> availableReports;

  ReportOptions({
    required this.role,
    required this.filters,
    required this.availableReports,
  });

  factory ReportOptions.fromJson(Map<String, dynamic> json) {
    return ReportOptions(
      role: json['role'] ?? '',
      filters: json['filters'] ?? {},
      availableReports: List<String>.from(json['available_reports'] ?? []),
    );
  }
}

class ReportResponse {
  final bool success;
  final String message;
  final String pdfBase64;
  final int totalRecords;

  ReportResponse({
    required this.success,
    required this.message,
    required this.pdfBase64,
    required this.totalRecords,
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      pdfBase64: json['pdf_base64'] ?? '',
      totalRecords: json['total_records'] ?? 0,
    );
  }
}

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final _apiService = ApiService();

  // ─────────────────────────────────────────
  // GET REPORT OPTIONS
  // ─────────────────────────────────────────
  Future<ReportOptions> getReportOptions() async {
    try {
      final token = await _apiService.getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/reports/options'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return ReportOptions.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to fetch report options: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching report options: $e');
    }
  }

  // ─────────────────────────────────────────
  // ADMIN & PRINCIPAL: DEPARTMENT REPORT
  // ─────────────────────────────────────────
  Future<ReportResponse> generateDepartmentReport({
    List<String>? departmentIds,
    List<int>? years,
    List<String>? subjectIds,
    String? studentThreshold,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await _apiService.getToken();
      
      final queryParams = <String, dynamic>{};
      if (departmentIds != null && departmentIds.isNotEmpty) {
        queryParams['department_ids'] = departmentIds;
      }
      if (years != null && years.isNotEmpty) {
        queryParams['years'] = years;
      }
      if (subjectIds != null && subjectIds.isNotEmpty) {
        queryParams['subject_ids'] = subjectIds;
      }
      if (studentThreshold != null && studentThreshold.isNotEmpty) {
        queryParams['student_threshold'] = studentThreshold;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      final uri = Uri.parse('${AppConfig.baseUrl}/reports/department')
          .replace(queryParameters: queryParams);

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return ReportResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to generate report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating department report: $e');
    }
  }

  // ─────────────────────────────────────────
  // HOD REPORT
  // ─────────────────────────────────────────
  Future<ReportResponse> generateHodReport({
    List<int>? years,
    List<String>? subjectIds,
    String? studentThreshold,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await _apiService.getToken();

      final queryParams = <String, dynamic>{};
      if (years != null && years.isNotEmpty) {
        queryParams['years'] = years;
      }
      if (subjectIds != null && subjectIds.isNotEmpty) {
        queryParams['subject_ids'] = subjectIds;
      }
      if (studentThreshold != null && studentThreshold.isNotEmpty) {
        queryParams['student_threshold'] = studentThreshold;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      final uri = Uri.parse('${AppConfig.baseUrl}/reports/hod')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return ReportResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to generate report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating HOD report: $e');
    }
  }

  // ─────────────────────────────────────────
  // FACULTY REPORT
  // ─────────────────────────────────────────
  Future<ReportResponse> generateFacultyReport({
    List<String>? subjectIds,
    String? studentThreshold,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await _apiService.getToken();

      final queryParams = <String, dynamic>{};
      if (subjectIds != null && subjectIds.isNotEmpty) {
        queryParams['subject_ids'] = subjectIds;
      }
      if (studentThreshold != null && studentThreshold.isNotEmpty) {
        queryParams['student_threshold'] = studentThreshold;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      final uri = Uri.parse('${AppConfig.baseUrl}/reports/faculty')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return ReportResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to generate report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating faculty report: $e');
    }
  }

  // ─────────────────────────────────────────
  // STUDENT REPORT
  // ─────────────────────────────────────────
  Future<ReportResponse> generateStudentReport({
    required String studentId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await _apiService.getToken();

      final queryParams = <String, dynamic>{};
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      final uri = Uri.parse('${AppConfig.baseUrl}/reports/student/$studentId')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return ReportResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to generate report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating student report: $e');
    }
  }
}
