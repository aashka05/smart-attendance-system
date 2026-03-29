// lib/screens/admin/admin_events_screen.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../config.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});
  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _events = [];
  List<dynamic> _cancelledLectures = [];
  List<dynamic> _departments = [];
  bool _loading = false;
  String? _selectedType;

  static const _eventTypeColors = {
    'holiday': Color(0xFFF59E0B),
    'exam': Color(0xFF8B5CF6),
    'fest': Color(0xFF3B82F6),
    'expert_talk': Color(0xFF3B82F6),
  };

  static const _eventTypes = ['holiday', 'exam', 'fest', 'expert_talk'];

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
      final events = await ApiService().getEvents();
      final cancelled = await ApiService().getCancelledLectures();
      final depts = await ApiService().getDepartments();
      setState(() {
        _events = events;
        _cancelledLectures = cancelled;
        _departments = depts;
      });
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
    setState(() => _loading = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? const Color(AppColors.error) : const Color(AppColors.success),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  List<dynamic> get _filteredEvents {
    if (_selectedType == null) return _events;
    return _events
        .where((e) => e['event_type'] == _selectedType)
        .toList();
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(AppColors.error)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService().deleteEvent(eventId);
        _showSnack('Event deleted');
        await _loadData();
      } catch (e) {
        _showSnack(e.toString(), isError: true);
      }
    }
  }

  Future<void> _restoreLecture(String cancelId) async {
    try {
      await ApiService().restoreLecture(cancelId);
      _showSnack('Lecture restored');
      await _loadData();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = EventTypes.holiday;
    String? selectedDeptId;
    int? selectedYear;
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'Title',
                  controller: titleCtrl,
                  prefixIcon: Icons.title_rounded,
                ),
                const SizedBox(height: 14),
                // Date picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today_rounded,
                          size: 20,
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5)),
                    ),
                    child: Text(
                      selectedDate != null
                          ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                          : 'Tap to select date',
                      style: TextStyle(
                        color: selectedDate != null
                            ? Theme.of(ctx).colorScheme.onSurface
                            : Theme.of(ctx)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Event type dropdown
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Event Type'),
                  items: _eventTypes
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(EventTypes.display(t)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedType = v);
                  },
                ),
                const SizedBox(height: 14),
                // Department dropdown
                DropdownButtonFormField<String?>(
                  value: selectedDeptId,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Departments'),
                    ),
                    ..._departments.map((d) => DropdownMenuItem<String?>(
                          value: d['id'] as String,
                          child: Text(d['name'] as String),
                        )),
                  ],
                  onChanged: (v) => setDialogState(() => selectedDeptId = v),
                ),
                const SizedBox(height: 14),
                // Year dropdown
                DropdownButtonFormField<int?>(
                  value: selectedYear,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Years'),
                    ),
                    ...[1, 2, 3, 4].map((y) => DropdownMenuItem<int?>(
                          value: y,
                          child: Text('Year $y'),
                        )),
                  ],
                  onChanged: (v) => setDialogState(() => selectedYear = v),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Description (optional)',
                  controller: descCtrl,
                  maxLines: 3,
                  prefixIcon: Icons.description_rounded,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || selectedDate == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Title and date are required'),
                    behavior: SnackBarBehavior.floating,
                  ));
                  return;
                }
                try {
                  final dateStr =
                      '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
                  await ApiService().createEvent(
                    title: titleCtrl.text.trim(),
                    date: dateStr,
                    eventType: selectedType,
                    departmentId: selectedDeptId,
                    year: selectedYear,
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                  );
                  Navigator.pop(ctx);
                  _showSnack('Event created');
                  await _loadData();
                } catch (e) {
                  _showSnack(e.toString(), isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primary),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
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
        title: const Text('Events & Holidays'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Events'),
            Tab(text: 'Cancelled Lectures'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildEventsTab(), _buildCancelledTab()],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(AppColors.primary),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEventsTab() {
    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: FilterChipRow(
            options: _eventTypes.map((t) => EventTypes.display(t)).toList(),
            selected: _selectedType != null
                ? EventTypes.display(_selectedType!)
                : null,
            onSelected: (displayVal) {
              setState(() {
                if (displayVal == null) {
                  _selectedType = null;
                } else {
                  // Map display string back to raw type
                  _selectedType = _eventTypes.firstWhere(
                    (t) => EventTypes.display(t) == displayVal,
                    orElse: () => _eventTypes.first,
                  );
                }
              });
            },
          ),
        ),
        // Event list
        Expanded(
          child: _filteredEvents.isEmpty
              ? const EmptyState(
                  icon: Icons.event_rounded,
                  title: 'No events found',
                  subtitle: 'Tap + to create a new event',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: _filteredEvents.length,
                  itemBuilder: (_, i) =>
                      _buildEventCard(_filteredEvents[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final type = event['event_type'] as String? ?? 'holiday';
    final color = _eventTypeColors[type] ?? const Color(0xFF3B82F6);
    final deptName = event['department_name'] as String?;
    final year = event['year'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(event['id'].toString()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: const Color(AppColors.error).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_rounded,
              color: Color(AppColors.error)),
        ),
        confirmDismiss: (_) async {
          await _deleteEvent(event['id'].toString());
          return false; // We handle deletion manually
        },
        child: AppCard(
          child: Row(
            children: [
              Container(
                width: 4,
                height: 70,
                decoration: BoxDecoration(
                  color: color,
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
                            event['title'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            EventTypes.display(type),
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event['date'] ?? ''}${deptName != null ? ' • $deptName' : ' • All Depts'}${year != null ? ' • Year $year' : ''}',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    if (event['description'] != null &&
                        (event['description'] as String).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event['description'],
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCancelledTab() {
    if (_cancelledLectures.isEmpty) {
      return const EmptyState(
        icon: Icons.event_available_rounded,
        title: 'No cancelled lectures',
        subtitle: 'Cancelled lectures will appear here',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cancelledLectures.length,
      itemBuilder: (_, i) {
        final cl = _cancelledLectures[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(AppColors.cancelled),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cl['date'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cancelled by: ${cl['cancelled_by_name'] ?? 'Unknown'}',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      if (cl['reason'] != null &&
                          (cl['reason'] as String).isNotEmpty)
                        Text(
                          'Reason: ${cl['reason']}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.restore_rounded,
                      color: Color(AppColors.success)),
                  tooltip: 'Restore',
                  onPressed: () => _restoreLecture(cl['id'].toString()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
