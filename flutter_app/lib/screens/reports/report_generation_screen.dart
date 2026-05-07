// lib/screens/reports/report_generation_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../services/report_service.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import 'pdf_viewer_screen.dart';

class ReportGenerationScreen extends StatefulWidget {
  final UserModel currentUser;

  const ReportGenerationScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<ReportGenerationScreen> createState() => _ReportGenerationScreenState();
}

class _ReportGenerationScreenState extends State<ReportGenerationScreen> {
  final _reportService = ReportService();
  final _apiService = ApiService();

  late ReportOptions _reportOptions;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  // Filters
  List<String> _selectedDepartments = [];
  List<int> _selectedYears = [];
  List<String> _selectedSubjects = [];
  List<dynamic> _allSubjects = [];
  String _studentThreshold = 'all'; // all, above, below
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadReportOptions();
  }

  Future<void> _loadReportOptions() async {
    try {
      final options = await _reportService.getReportOptions();
      setState(() {
        _reportOptions = options;
        _loading = false;
      });
      if (widget.currentUser.role == 'admin' || widget.currentUser.role == 'hod' || widget.currentUser.role == 'principal') {
        await _loadAllSubjects();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadAllSubjects() async {
    try {
      final subjects = await _apiService.getSubjects();
      setState(() {
        _allSubjects = subjects;
      });
    } catch (_) {
      setState(() {
        _allSubjects = [];
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _generateReport() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date range')),
      );
      return;
    }

    setState(() => _generating = true);

    try {
      final startDate = DateFormat('yyyy-MM-dd').format(_startDate!);
      final endDate = DateFormat('yyyy-MM-dd').format(_endDate!);

      ReportResponse response;

      switch (widget.currentUser.role) {
        case 'admin':
        case 'principal':
          response = await _reportService.generateDepartmentReport(
            departmentIds: _selectedDepartments.isNotEmpty ? _selectedDepartments : null,
            years: _selectedYears.isNotEmpty ? _selectedYears : null,
            subjectIds: _selectedSubjects.isNotEmpty ? _selectedSubjects : null,
            studentThreshold: _studentThreshold != 'all' ? _studentThreshold : null,
            startDate: startDate,
            endDate: endDate,
          );
          break;

        case 'hod':
          response = await _reportService.generateHodReport(
            years: _selectedYears.isNotEmpty ? _selectedYears : null,
            subjectIds: _selectedSubjects.isNotEmpty ? _selectedSubjects : null,
            studentThreshold: _studentThreshold != 'all' ? _studentThreshold : null,
            startDate: startDate,
            endDate: endDate,
          );
          break;

        case 'faculty':
          response = await _reportService.generateFacultyReport(
            subjectIds: _selectedSubjects.isNotEmpty ? _selectedSubjects : null,
            studentThreshold: _studentThreshold != 'all' ? _studentThreshold : null,
            startDate: startDate,
            endDate: endDate,
          );
          break;

        case 'student':
          response = await _reportService.generateStudentReport(
            studentId: widget.currentUser.id,
            startDate: startDate,
            endDate: endDate,
          );
          break;

        default:
          throw Exception('Unknown role: ${widget.currentUser.role}');
      }

      if (!mounted) return;

      // Convert base64 to bytes
      final pdfBytes = Uint8List.fromList(
        base64Decode(response.pdfBase64),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            pdfBytes: pdfBytes,
            fileName: 'attendance_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Generate Report')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Generate Report')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadReportOptions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Report'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Role-specific filters
          if (widget.currentUser.role == 'admin' ||
              widget.currentUser.role == 'principal')
            ..._buildAdminFilters(),
          if (widget.currentUser.role == 'hod') ..._buildHodFilters(),
          if (widget.currentUser.role == 'faculty')
            ..._buildFacultyFilters(),
          if (widget.currentUser.role == 'student')
            ..._buildStudentFilters(),

          const SizedBox(height: 24),

          // Date range section
          _buildDateRangeSection(),

          const SizedBox(height: 24),

          // Generate button
          ElevatedButton(
            onPressed: _generating ? null : _generateReport,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              disabledBackgroundColor: Colors.grey,
            ),
            child: _generating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text(
                    'Generate Report',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAdminFilters() {
    return [
      _buildSectionTitle('Department'),
      _buildDepartmentSelector(),
      const SizedBox(height: 16),
      _buildSectionTitle('Year'),
      _buildYearSelector(),
      const SizedBox(height: 16),
      _buildSectionTitle('Subject'),
      _buildSubjectSelector(),
      const SizedBox(height: 16),
      _buildSectionTitle('Student Filter'),
      _buildStudentThresholdSelector(),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildHodFilters() {
    return [
      _buildSectionTitle('Year'),
      _buildYearSelector(),
      const SizedBox(height: 16),
      _buildSectionTitle('Subject'),
      _buildSubjectSelector(),
      const SizedBox(height: 16),
      _buildSectionTitle('Student Filter'),
      _buildStudentThresholdSelector(),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildFacultyFilters() {
    return [
      _buildSectionTitle('Subject'),
      _buildSubjectSelector(),
      const SizedBox(height: 16),
      _buildSectionTitle('Student Filter'),
      _buildStudentThresholdSelector(),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildStudentFilters() {
    return [
      _buildSectionTitle('Your Attendance Report'),
      const Text(
        'This report shows your cumulative attendance across all subjects',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildDepartmentSelector() {
    final departments = _reportOptions.filters['departments'] as List? ?? [];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var dept in departments)
          FilterChip(
            label: Text(dept['name'] ?? ''),
            selected: _selectedDepartments.contains(dept['id'].toString()),
            onSelected: (selected) {
              setState(() {
                final deptId = dept['id'].toString();
                if (selected) {
                  _selectedDepartments.add(deptId);
                } else {
                  _selectedDepartments.remove(deptId);
                }
              });
            },
          ),
      ],
    );
  }

  Widget _buildYearSelector() {
    final years = _reportOptions.filters['years'] as List? ?? [1, 2, 3, 4];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var year in years)
          FilterChip(
            label: Text('Year $year'),
            selected: _selectedYears.contains(year),
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedYears.add(year);
                } else {
                  _selectedYears.remove(year);
                }
              });
            },
          ),
      ],
    );
  }

  Widget _buildSubjectSelector() {
    final subjects = _getSelectableSubjects();

    if (subjects.isEmpty) {
      return const Text('No subjects available for the selected filters');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var subject in subjects)
          FilterChip(
            label: Text('${subject['code']} - ${subject['name']}'),
            selected: _selectedSubjects.contains(subject['id'].toString()),
            onSelected: (selected) {
              setState(() {
                final subjectId = subject['id'].toString();
                if (selected) {
                  _selectedSubjects.add(subjectId);
                } else {
                  _selectedSubjects.remove(subjectId);
                }
              });
            },
          ),
      ],
    );
  }

  List<dynamic> _getSelectableSubjects() {
    final loadedSubjects = _reportOptions.filters['subjects'] as List? ?? [];
    if (loadedSubjects.isNotEmpty) {
      return loadedSubjects;
    }

    if (_allSubjects.isEmpty) {
      return [];
    }

    return _allSubjects.where((subject) {
      final deptFilter = _selectedDepartments.isEmpty || _selectedDepartments.contains(subject['department_id'].toString());
      final yearFilter = _selectedYears.isEmpty || _selectedYears.contains(subject['year']);
      return deptFilter && yearFilter;
    }).toList();
  }

  Widget _buildStudentThresholdSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('All Students'),
          selected: _studentThreshold == 'all',
          onSelected: (selected) {
            if (selected) {
              setState(() => _studentThreshold = 'all');
            }
          },
        ),
        FilterChip(
          label: const Text('Below 75%'),
          selected: _studentThreshold == 'below',
          onSelected: (selected) {
            if (selected) {
              setState(() => _studentThreshold = 'below');
            }
          },
        ),
        FilterChip(
          label: const Text('Above 75%'),
          selected: _studentThreshold == 'above',
          onSelected: (selected) {
            if (selected) {
              setState(() => _studentThreshold = 'above');
            }
          },
        ),
      ],
    );
  }

  Widget _buildDateRangeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Date Range',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  'Start Date',
                  _startDate,
                  () => _selectDate(context, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  'End Date',
                  _endDate,
                  () => _selectDate(context, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? date,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? DateFormat('dd/MM/yyyy').format(date)
                  : 'Select date',
              style: TextStyle(
                fontSize: 14,
                color: date != null ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension for base64 decode
Uint8List base64Decode(String source) {
  return Uint8List.fromList(
    const Base64Decoder().convert(source),
  );
}

class Base64Decoder extends Converter<String, List<int>> {
  const Base64Decoder();

  @override
  List<int> convert(String input) {
    return _base64StringToList(input);
  }

  static List<int> _base64StringToList(String input) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final List<int> bytes = [];

    int byte1, byte2, byte3;

    for (int i = 0; i < input.length; i += 4) {
      byte1 = chars.indexOf(input[i]);
      byte2 = i + 1 < input.length ? chars.indexOf(input[i + 1]) : 0;
      byte3 = i + 2 < input.length ? chars.indexOf(input[i + 2]) : 0;

      bytes.add((byte1 << 2) | (byte2 >> 4));

      if (input[i + 2] != '=') {
        bytes.add(((byte2 & 15) << 4) | (byte3 >> 2));
      }

      if (input[i + 3] != '=' && i + 3 < input.length) {
        bytes.add(((byte3 & 3) << 6) |
            chars.indexOf(input[i + 3]));
      }
    }

    return bytes;
  }
}
