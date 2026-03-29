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
  String? _filterDay;
  String? _filterDept;
  int? _filterYear;

  final _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final _lectureTypes = ['lecture', 'practical', 'tutorial', 'open_elective', 'program_elective'];

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
      backgroundColor: isError ? const Color(AppColors.error) : const Color(AppColors.success),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  List<dynamic> get _filteredSlots {
    return _slots.where((s) {
      final matchDay = _filterDay == null || s['day_of_week'] == _filterDay;
      final matchDept = _filterDept == null || s['department_id'] == _filterDept;
      final matchYear = _filterYear == null || s['year'] == _filterYear;
      return matchDay && matchDept && matchYear;
    }).toList();
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
    String selectedLectureType = 'lecture';
    int? selectedYear;
    String? selectedBatch;
    final sectionCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '09:00');
    final endCtrl = TextEditingController(text: '10:00');
    final roomCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedSubjectId,
                  decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                  items: _subjects
                      .where((s) => selectedDeptId == null || s['department_id'] == selectedDeptId)
                      .map<DropdownMenuItem<String>>((s) =>
                          DropdownMenuItem(value: s['id'] as String, child: Text('${s['name']} (${s['code']})')))
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedSubjectId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedFacultyId,
                  decoration: const InputDecoration(labelText: 'Faculty', border: OutlineInputBorder()),
                  items: _faculty.map<DropdownMenuItem<String>>((f) =>
                      DropdownMenuItem(value: f['id'] as String, child: Text(f['full_name'] as String))
                  ).toList(),
                  onChanged: (v) => setModalState(() => selectedFacultyId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedLectureType,
                  decoration: const InputDecoration(labelText: 'Lecture Type', border: OutlineInputBorder()),
                  items: _lectureTypes.map((t) => DropdownMenuItem(
                    value: t, child: Text(LectureTypes.display(t)),
                  )).toList(),
                  onChanged: (v) => setModalState(() => selectedLectureType = v!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: selectedYear,
                  decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                  hint: const Text('Select Year'),
                  items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                  onChanged: (v) => setModalState(() => selectedYear = v),
                ),
                const SizedBox(height: 10),
                if (selectedLectureType == 'practical' || selectedLectureType == 'tutorial') ...[
                  TextField(
                    onChanged: (v) => selectedBatch = v,
                    decoration: InputDecoration(
                      labelText: selectedLectureType == 'practical' ? 'Batch (A/B/C/D/E)' : 'Batch (P/Q/R)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  decoration: const InputDecoration(labelText: 'Day', border: OutlineInputBorder()),
                  items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setModalState(() => selectedDay = v!),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(labelText: 'Start (HH:MM)', border: OutlineInputBorder()),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(labelText: 'End (HH:MM)', border: OutlineInputBorder()),
                    )),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roomCtrl,
                  decoration: const InputDecoration(labelText: 'Room', border: OutlineInputBorder()),
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
                    section: sectionCtrl.text.trim().isEmpty ? null : sectionCtrl.text.trim(),
                    dayOfWeek: selectedDay,
                    startTime: startCtrl.text.trim(),
                    endTime: endCtrl.text.trim(),
                    room: roomCtrl.text.trim(),
                    year: selectedYear,
                    lectureType: selectedLectureType,
                    batch: selectedBatch,
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
      appBar: AppBar(
        title: const Text('Timetable'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSlotDialog,
        backgroundColor: const Color(AppColors.primary),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // Day filter
                ...[null, ..._days].map((day) {
                  final selected = _filterDay == day;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filterDay = day),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? const Color(AppColors.primary) : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? const Color(AppColors.primary) : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          day ?? 'All Days',
                          style: TextStyle(
                            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSlots.isEmpty
                    ? const EmptyState(icon: Icons.calendar_today_rounded, title: 'No slots found')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredSlots.length,
                        itemBuilder: (_, i) {
                          final slot = _filteredSlots[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Container(
                                    width: 4, height: 64,
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
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${slot['subject_name']} (${slot['subject_code'] ?? ''})',
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                              ),
                                            ),
                                            LectureTypeBadge(type: slot['lecture_type'] ?? 'lecture'),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${slot['faculty_name']} • ${slot['room']}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '${slot['day_of_week']} ${slot['start_time']}–${slot['end_time']}${slot['year'] != null ? ' • Year ${slot['year']}' : ''}${slot['batch'] != null ? ' • Batch ${slot['batch']}' : ''}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
