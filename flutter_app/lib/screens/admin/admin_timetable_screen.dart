// lib/screens/admin/admin_timetable_screen.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class AdminTimetableScreen extends StatefulWidget {
  const AdminTimetableScreen({super.key});
  @override
  State<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends State<AdminTimetableScreen> {
  List<dynamic> _slots = [];
  List<dynamic> _departments = [];
  List<dynamic> _subjects = [];
  List<dynamic> _faculty = [];
  bool _loading = false;

  final _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  String _filterDay = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final slots = await ApiService().getTimetable();
      final depts = await ApiService().getDepartments();
      final subjects = await ApiService().getSubjects();
      final allUsers = await ApiService().getAllUsers();
      setState(() {
        _slots = slots;
        _departments = depts;
        _subjects = subjects;
        _faculty = allUsers.where((u) => u['role'] == 'faculty' && u['status'] == 'approved').toList();
      });
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

  List<dynamic> get _filteredSlots {
    if (_filterDay == 'All') return _slots;
    return _slots.where((s) => s['day_of_week'] == _filterDay).toList();
  }

  void _showAddSlotDialog() {
    if (_departments.isEmpty || _subjects.isEmpty || _faculty.isEmpty) {
      _showSnack('Add departments, subjects, and approve faculty first', isError: true);
      return;
    }

    String? selectedSubjectId;
    String? selectedFacultyId;
    String? selectedDeptId;
    String selectedDay = _days[0];
    final sectionCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '09:00');
    final endCtrl = TextEditingController(text: '10:00');
    final roomCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Timetable Slot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDeptId,
                  decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                  items: _departments.map<DropdownMenuItem<String>>((d) =>
                    DropdownMenuItem(value: d['id'] as String, child: Text(d['name'] as String))
                  ).toList(),
                  onChanged: (v) => setModalState(() { selectedDeptId = v; selectedSubjectId = null; }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSubjectId,
                  decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                  items: _subjects
                    .where((s) => selectedDeptId == null || s['department_id'] == selectedDeptId)
                    .map<DropdownMenuItem<String>>((s) =>
                      DropdownMenuItem(value: s['id'] as String, child: Text('${s['name']} (${s['code']})'))
                    ).toList(),
                  onChanged: (v) => setModalState(() => selectedSubjectId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedFacultyId,
                  decoration: const InputDecoration(labelText: 'Faculty', border: OutlineInputBorder()),
                  items: _faculty.map<DropdownMenuItem<String>>((f) =>
                    DropdownMenuItem(value: f['id'] as String, child: Text(f['full_name'] as String))
                  ).toList(),
                  onChanged: (v) => setModalState(() => selectedFacultyId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  decoration: const InputDecoration(labelText: 'Day', border: OutlineInputBorder()),
                  items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setModalState(() => selectedDay = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(labelText: 'Start (HH:MM)', border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(labelText: 'End (HH:MM)', border: OutlineInputBorder()),
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sectionCtrl,
                  decoration: const InputDecoration(labelText: 'Section (e.g. CSE-3B)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomCtrl,
                  decoration: const InputDecoration(labelText: 'Room (e.g. Room 204)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedSubjectId == null || selectedFacultyId == null || selectedDeptId == null) return;
                Navigator.pop(ctx);
                try {
                  await ApiService().createSlot(
                    subjectId: selectedSubjectId!,
                    facultyId: selectedFacultyId!,
                    departmentId: selectedDeptId!,
                    section: sectionCtrl.text.trim(),
                    dayOfWeek: selectedDay,
                    startTime: startCtrl.text.trim(),
                    endTime: endCtrl.text.trim(),
                    room: roomCtrl.text.trim(),
                  );
                  _showSnack('Slot created');
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
        title: const Text('Timetable', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSlotDialog,
        backgroundColor: const Color(AppColors.primary),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Day filter
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: ['All', ..._days].map((day) {
                final selected = _filterDay == day;
                return GestureDetector(
                  onTap: () => setState(() => _filterDay = day),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? const Color(AppColors.primary) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? const Color(AppColors.primary) : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      day,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.grey.shade700,
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSlots.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No slots found', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredSlots.length,
                        itemBuilder: (_, i) {
                          final slot = _filteredSlots[i];
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
                                  width: 4, height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(AppColors.primary),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${slot['subject_name']} (${slot['subject_code']})',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text('${slot['faculty_name']} • ${slot['section']}',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      Text('${slot['day_of_week']} ${slot['start_time']}–${slot['end_time']} • ${slot['room']}',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
