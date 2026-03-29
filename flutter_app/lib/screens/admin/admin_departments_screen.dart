// lib/screens/admin/admin_departments_screen.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class AdminDepartmentsScreen extends StatefulWidget {
  const AdminDepartmentsScreen({super.key});
  @override
  State<AdminDepartmentsScreen> createState() => _AdminDepartmentsScreenState();
}

class _AdminDepartmentsScreenState extends State<AdminDepartmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _departments = [];
  List<dynamic> _subjects = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final depts = await ApiService().getDepartments();
      final subjects = await ApiService().getSubjects();
      setState(() { _departments = depts; _subjects = subjects; });
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
    setState(() => _loading = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(AppColors.error) : const Color(AppColors.success),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showAddDepartmentDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Department'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Department name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              try {
                await ApiService().createDepartment(ctrl.text.trim());
                _showSnack('Department created');
                await _loadData();
              } catch (e) {
                _showSnack(e.toString(), isError: true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddSubjectDialog() {
    if (_departments.isEmpty) {
      _showSnack('Add a department first', isError: true);
      return;
    }
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String? selectedDeptId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Subject'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Subject Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Subject Code', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedDeptId,
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                items: _departments.map<DropdownMenuItem<String>>((d) =>
                    DropdownMenuItem(value: d['id'] as String, child: Text(d['name'] as String))
                ).toList(),
                onChanged: (v) => setModalState(() => selectedDeptId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty || selectedDeptId == null) return;
                Navigator.pop(ctx);
                try {
                  await ApiService().createSubject(
                    name: nameCtrl.text.trim(),
                    code: codeCtrl.text.trim().toUpperCase(),
                    departmentId: selectedDeptId!,
                  );
                  _showSnack('Subject created');
                  await _loadData();
                } catch (e) {
                  _showSnack(e.toString(), isError: true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments & Subjects'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Departments (${_departments.length})'),
            Tab(text: 'Subjects (${_subjects.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) _showAddDepartmentDialog();
          else _showAddSubjectDialog();
        },
        backgroundColor: const Color(AppColors.primary),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildDepartments(), _buildSubjects()],
            ),
    );
  }

  Widget _buildDepartments() {
    if (_departments.isEmpty) {
      return EmptyState(
        icon: Icons.business_rounded,
        title: 'No departments yet',
        action: TextButton.icon(
          onPressed: _showAddDepartmentDialog,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Department'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _departments.length,
      itemBuilder: (_, i) {
        final dept = _departments[i];
        final subjectCount = _subjects.where((s) => s['department_id'] == dept['id']).length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(AppColors.facultyColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business_rounded,
                      color: Color(AppColors.facultyColor), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dept['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('$subjectCount subjects',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          )),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: const Color(AppColors.error).withOpacity(0.7), size: 20),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Delete Department?'),
                        content: Text('Delete "${dept['name']}"? This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(AppColors.error)),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ApiService().deleteDepartment(dept['id']);
                      _showSnack('Department deleted');
                      await _loadData();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubjects() {
    if (_subjects.isEmpty) {
      return EmptyState(
        icon: Icons.book_rounded,
        title: 'No subjects yet',
        action: TextButton.icon(
          onPressed: _showAddSubjectDialog,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Subject'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      itemBuilder: (_, i) {
        final subj = _subjects[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(AppColors.primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.book_rounded,
                      color: Color(AppColors.primary), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subj['name'],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(subj['code'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                )),
                          ),
                          const SizedBox(width: 8),
                          Text(subj['department_name'] ?? '',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 12,
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: const Color(AppColors.error).withOpacity(0.7), size: 20),
                  onPressed: () async {
                    await ApiService().deleteSubject(subj['id']);
                    _showSnack('Subject deleted');
                    await _loadData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
