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
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  void _showAddDepartmentDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Department'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Department name', border: OutlineInputBorder()),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      backgroundColor: const Color(AppColors.surface),
      appBar: AppBar(
        title: const Text('Departments & Subjects', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(AppColors.primary),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(AppColors.primary),
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
        child: const Icon(Icons.add, color: Colors.white),
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
      return _EmptyState(message: 'No departments yet', icon: Icons.business_outlined, onAdd: _showAddDepartmentDialog);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _departments.length,
      itemBuilder: (_, i) {
        final dept = _departments[i];
        final subjectCount = _subjects.where((s) => s['department_id'] == dept['id']).length;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF137333).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.business_outlined, color: Color(0xFF137333), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dept['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text('$subjectCount subjects', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete Department?'),
                      content: Text('This will delete "${dept['name']}". This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
        );
      },
    );
  }

  Widget _buildSubjects() {
    if (_subjects.isEmpty) {
      return _EmptyState(message: 'No subjects yet', icon: Icons.book_outlined, onAdd: _showAddSubjectDialog);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      itemBuilder: (_, i) {
        final subj = _subjects[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(AppColors.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.book_outlined, color: Color(AppColors.primary), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subj['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(subj['code'], style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontFamily: 'monospace')),
                        ),
                        const SizedBox(width: 8),
                        Text(subj['department_name'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () async {
                  await ApiService().deleteSubject(subj['id']);
                  _showSnack('Subject deleted');
                  await _loadData();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback onAdd;

  const _EmptyState({required this.message, required this.icon, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add one now'),
          ),
        ],
      ),
    );
  }
}
