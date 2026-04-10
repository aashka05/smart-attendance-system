import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../config.dart';

class AdminImportScreen extends StatefulWidget {
  const AdminImportScreen({super.key});

  @override
  State<AdminImportScreen> createState() => _AdminImportScreenState();
}

class _AdminImportScreenState extends State<AdminImportScreen> {
  bool _isLoading = false;

  Future<void> _pickAndUpload(String endpoint, String title) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        final file = File(result.files.single.path!);
        
        final response = await ApiService().importCsv(endpoint, file.path);
        
        if (!mounted) return;
        
        final imported = response['imported'] ?? 0;
        final skipped = response['skipped'] ?? 0;
        final errors = List.from(response['errors'] ?? []);
        
        String msg = '$title uploaded: $imported imported, $skipped skipped.';
        bool hasErrors = errors.isNotEmpty;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: hasErrors ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        if (hasErrors) {
          _showErrorDialog(title, errors);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, List<dynamic> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$title Import Errors'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: errors.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('• ${errors[index]}', style: const TextStyle(color: Colors.red, fontSize: 13)),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildImportCard({
    required String title,
    required String subtitle,
    required String endpoint,
    required IconData icon,
    required int step,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: const Color(AppColors.adminColor).withOpacity(0.1),
          foregroundColor: const Color(AppColors.adminColor),
          child: Text('$step', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle, style: const TextStyle(fontSize: 13)),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.upload_file_rounded, color: Color(AppColors.primary)),
          onPressed: _isLoading ? null : () => _pickAndUpload(endpoint, title),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Import Data'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1, // optional
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Import order matters. Please upload CSV files in the sequence listed below to ensure relations are mapped correctly.',
                        style: TextStyle(color: Colors.blue, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildImportCard(
                step: 1,
                icon: Icons.business_rounded,
                title: 'Departments',
                subtitle: 'Columns: name',
                endpoint: 'departments',
              ),
              _buildImportCard(
                step: 2,
                icon: Icons.book_rounded,
                title: 'Subjects',
                subtitle: 'Columns: name, code, department_name, year',
                endpoint: 'subjects',
              ),
              _buildImportCard(
                step: 3,
                icon: Icons.person_outline_rounded,
                title: 'Faculty',
                subtitle: 'Columns: full_name, email, password, department_name, employee_id',
                endpoint: 'faculty',
              ),
              _buildImportCard(
                step: 4,
                icon: Icons.people_alt_rounded,
                title: 'Students',
                subtitle: 'Columns: full_name, email, password, department_name, enrollment_number, year',
                endpoint: 'students',
              ),
              _buildImportCard(
                step: 5,
                icon: Icons.calendar_month_rounded,
                title: 'Timetable',
                subtitle: 'Columns: subject_code, faculty_email, department_name, year, day_of_week, start_time, end_time, room, lecture_type',
                endpoint: 'timetable',
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
