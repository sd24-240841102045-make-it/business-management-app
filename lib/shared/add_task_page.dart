import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final AppDataStore _store = AppDataStore();
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _selectedProjectId;
  String? _selectedEmployeeName;
  String _selectedPriority = 'Medium';
  String _selectedStatus = 'To Do';

  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);

  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (_store.projects.isNotEmpty) {
      _selectedProjectId = _store.projects.first.id;
    }
    if (_store.employees.isNotEmpty) {
      _selectedEmployeeName = _store.employees.first.name;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _startTime,
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _startDate = pickedDate;
          _startTime = pickedTime;
        });
      }
    }
  }

  Future<void> _pickEndDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _endTime,
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _endDate = pickedDate;
          _endTime = pickedTime;
        });
      }
    }
  }

  String _formatDateTimeDisplay(DateTime date, TimeOfDay time) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hourStr = time.hourOfPeriod == 0 ? '12' : time.hourOfPeriod.toString();
    final minStr = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$y-$m-$d  $hourStr:$minStr $period';
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final orgId = SupabaseService().currentOrganizationId;
      final dueIso = _formatDateTimeDisplay(_endDate, _endTime);

      bool isValidUuid(String? id) {
        if (id == null) return false;
        return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id.trim());
      }

      String? assigneeUserId;
      if (_selectedEmployeeName != null && _selectedEmployeeName!.isNotEmpty) {
        final emp = _store.employees.firstWhere(
          (e) => e.name == _selectedEmployeeName,
          orElse: () => Employee(id: '', name: '', role: '', department: '', email: '', phone: '', status: '', joiningDate: ''),
        );
        if (isValidUuid(emp.userId)) {
          assigneeUserId = emp.userId;
        } else if (isValidUuid(emp.id)) {
          assigneeUserId = emp.id;
        }
      }
      if (assigneeUserId == null && isValidUuid(SupabaseService().currentUser?.id)) {
        assigneeUserId = SupabaseService().currentUser?.id;
      }

      String dbStatus = _selectedStatus;
      if (_selectedStatus == 'To Do') {
        dbStatus = 'Todo';
      }

      final taskMap = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'priority': _selectedPriority,
        'status': dbStatus,
        'due_date': dueIso,
      };

      if (isValidUuid(assigneeUserId)) {
        taskMap['assigned_to'] = assigneeUserId;
      }
      if (isValidUuid(orgId)) {
        taskMap['organization_id'] = orgId;
      }
      if (_descCtrl.text.trim().isNotEmpty) {
        taskMap['description'] = _descCtrl.text.trim();
      }
      if (isValidUuid(_selectedProjectId)) {
        taskMap['project_id'] = _selectedProjectId!.trim();
      }

      try {
        await SupabaseService().client.from('tasks').insert(taskMap);
      } catch (insertErr) {
        if (insertErr.toString().contains('tasks_status_check')) {
          taskMap['status'] = dbStatus.toLowerCase();
          await SupabaseService().client.from('tasks').insert(taskMap);
        } else {
          rethrow;
        }
      }

      await AppDataStore().refreshFromSupabase();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kanban Task created successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error creating task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'low':
        return Colors.blueAccent;
      default:
        return kPremiumGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Add New Task', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
          backgroundColor: kPremiumBg,
          foregroundColor: kPremiumGold,
          elevation: 0,
        ),
        body: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).padding.bottom + 80.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: GlassCard(
                  padding: const EdgeInsets.all(28.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Task Specifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPremiumGold)),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _titleCtrl,
                          style: const TextStyle(color: kPremiumText),
                          decoration: InputDecoration(
                            labelText: 'Task Title *',
                            labelStyle: const TextStyle(color: kPremiumMuted),
                            prefixIcon: const Icon(Icons.assignment_outlined, color: kPremiumGold),
                            filled: true,
                            fillColor: kPremiumSurface.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Task title is required' : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 3,
                          style: const TextStyle(color: kPremiumText),
                          decoration: InputDecoration(
                            labelText: 'Task Description',
                            labelStyle: const TextStyle(color: kPremiumMuted),
                            prefixIcon: const Icon(Icons.description_outlined, color: kPremiumGold),
                            filled: true,
                            fillColor: kPremiumSurface.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text('Assignments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPremiumGold)),
                        const SizedBox(height: 14),

                        if (_store.projects.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedProjectId,
                            dropdownColor: kPremiumSurface,
                            style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Associated Project',
                              labelStyle: const TextStyle(color: kPremiumMuted),
                              prefixIcon: const Icon(Icons.folder_outlined, color: kPremiumGold),
                              filled: true,
                              fillColor: kPremiumSurface.withOpacity(0.5),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            items: _store.projects.map((p) {
                              return DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(color: kPremiumText)));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedProjectId = val),
                          ),
                          const SizedBox(height: 16),
                        ],

                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedEmployeeName,
                          dropdownColor: kPremiumSurface,
                          style: const TextStyle(color: kPremiumText),
                          decoration: InputDecoration(
                            labelText: 'Assign HR Employee',
                            labelStyle: const TextStyle(color: kPremiumMuted),
                            prefixIcon: const Icon(Icons.person_outline, color: kPremiumGold),
                            filled: true,
                            fillColor: kPremiumSurface.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Unassigned Staff', style: TextStyle(color: kPremiumMuted))),
                            ..._store.employees.map((e) {
                              return DropdownMenuItem(value: e.name, child: Text(e.name, style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.bold)));
                            }),
                          ],
                          onChanged: (val) => setState(() => _selectedEmployeeName = val),
                        ),
                        const SizedBox(height: 24),

                        // Priority Level Pill Selectors
                        const Text('Priority Level', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kPremiumGold)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: ['Low', 'Medium', 'High'].map((p) {
                            final isSel = _selectedPriority == p;
                            final pColor = _getPriorityColor(p);
                            return ChoiceChip(
                              avatar: CircleAvatar(radius: 4, backgroundColor: isSel ? kPremiumBg : pColor),
                              label: Text('$p Priority', style: TextStyle(color: isSel ? kPremiumBg : kPremiumText, fontWeight: FontWeight.bold)),
                              selected: isSel,
                              selectedColor: pColor,
                              backgroundColor: Colors.white.withOpacity(0.06),
                              side: BorderSide(color: isSel ? pColor : Colors.white10),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              onSelected: (val) {
                                if (val) setState(() => _selectedPriority = p);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Column Status Pill Selectors
                        const Text('Kanban Column Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kPremiumGold)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: ['To Do', 'In Progress', 'In Review', 'Completed'].map((st) {
                            final isSel = _selectedStatus == st;
                            return ChoiceChip(
                              label: Text(st, style: TextStyle(color: isSel ? kPremiumBg : kPremiumText, fontWeight: FontWeight.bold)),
                              selected: isSel,
                              selectedColor: kPremiumGold,
                              backgroundColor: Colors.white.withOpacity(0.06),
                              side: BorderSide(color: isSel ? kPremiumGold : Colors.white10),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              onSelected: (val) {
                                if (val) setState(() => _selectedStatus = st);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        const Text('Timeline & Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPremiumGold)),
                        const SizedBox(height: 14),

                        InkWell(
                          onTap: _pickStartDateTime,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: kPremiumSurface.withOpacity(0.5),
                              border: Border.all(color: Colors.white10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.play_circle_outline, color: Colors.greenAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Start Date & Time', style: TextStyle(fontSize: 12, color: kPremiumMuted)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDateTimeDisplay(_startDate, _startTime),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumText),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        InkWell(
                          onTap: _pickEndDateTime,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: kPremiumSurface.withOpacity(0.5),
                              border: Border.all(color: Colors.white10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Due Date & Deadline', style: TextStyle(fontSize: 12, color: kPremiumMuted)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDateTimeDisplay(_endDate, _endTime),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        GoldButton(
                          label: 'Create Task',
                          icon: Icons.check_circle_outline,
                          expand: true,
                          isLoading: _isSaving,
                          onPressed: _isSaving ? null : _saveTask,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
