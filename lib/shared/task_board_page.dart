import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/shared/add_task_page.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class TaskBoardPage extends StatefulWidget {
  const TaskBoardPage({super.key});

  @override
  State<TaskBoardPage> createState() => _TaskBoardPageState();
}

class _TaskBoardPageState extends State<TaskBoardPage> {
  final _tasksStream = SupabaseService().client.from('tasks').stream(primaryKey: ['id']);
  final AppDataStore _store = AppDataStore();

  void _showAddTaskDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    String? selectedProjectId = _store.projects.isNotEmpty ? _store.projects.first.id : null;
    String? selectedEmployeeName = _store.employees.isNotEmpty ? _store.employees.first.name : null;
    String selectedPriority = 'Medium';
    String selectedStatus = 'To Do';

    DateTime startDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);

    DateTime endDate = DateTime.now().add(const Duration(days: 7));
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

    bool isSaving = false;

    String formatDisplay(DateTime date, TimeOfDay time) {
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      final hourStr = time.hourOfPeriod == 0 ? '12' : time.hourOfPeriod.toString();
      final minStr = time.minute.toString().padLeft(2, '0');
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';
      return '$y-$m-$d  $hourStr:$minStr $period';
    }

    String formatIso(DateTime date, TimeOfDay time) {
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      final h = time.hour.toString().padLeft(2, '0');
      final min = time.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $h:$min:00';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickStart() async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: startDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null && context.mounted) {
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: startTime,
                );
                if (pickedTime != null && context.mounted) {
                  setModalState(() {
                    startDate = pickedDate;
                    startTime = pickedTime;
                  });
                }
              }
            }

            Future<void> pickEnd() async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: endDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null && context.mounted) {
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: endTime,
                );
                if (pickedTime != null && context.mounted) {
                  setModalState(() {
                    endDate = pickedDate;
                    endTime = pickedTime;
                  });
                }
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: GlassCard(
                  padding: const EdgeInsets.all(26),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Add Kanban Task', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPremiumGold)),
                            IconButton(
                              icon: const Icon(Icons.close, color: kPremiumMuted),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: titleCtrl,
                          style: const TextStyle(color: kPremiumText),
                          decoration: InputDecoration(
                            labelText: 'Task Title *',
                            labelStyle: const TextStyle(color: kPremiumMuted),
                            prefixIcon: const Icon(Icons.assignment_outlined, color: kPremiumGold),
                            filled: true,
                            fillColor: kPremiumSurface.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextField(
                          controller: descCtrl,
                          maxLines: 2,
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
                        const SizedBox(height: 14),

                        if (_store.projects.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedProjectId,
                            dropdownColor: kPremiumSurface,
                            style: const TextStyle(color: kPremiumText),
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
                            onChanged: (val) => setModalState(() => selectedProjectId = val),
                          ),
                          const SizedBox(height: 14),
                        ],

                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: selectedEmployeeName,
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
                            const DropdownMenuItem(value: null, child: Text('Unassigned', style: TextStyle(color: kPremiumMuted))),
                            ..._store.employees.map((e) {
                              return DropdownMenuItem(value: e.name, child: Text(e.name, style: const TextStyle(color: kPremiumText)));
                            }),
                          ],
                          onChanged: (val) => setModalState(() => selectedEmployeeName = val),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: selectedPriority,
                                dropdownColor: kPremiumSurface,
                                style: const TextStyle(color: kPremiumText),
                                decoration: InputDecoration(
                                  labelText: 'Priority',
                                  labelStyle: const TextStyle(color: kPremiumMuted),
                                  prefixIcon: const Icon(Icons.priority_high, color: kPremiumGold),
                                  filled: true,
                                  fillColor: kPremiumSurface.withOpacity(0.5),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Low', child: Text('Low Priority', style: TextStyle(color: Colors.blueAccent))),
                                  DropdownMenuItem(value: 'Medium', child: Text('Medium Priority', style: TextStyle(color: Colors.orangeAccent))),
                                  DropdownMenuItem(value: 'High', child: Text('High Priority', style: TextStyle(color: Colors.redAccent))),
                                ],
                                onChanged: (val) => setModalState(() => selectedPriority = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: selectedStatus,
                                dropdownColor: kPremiumSurface,
                                style: const TextStyle(color: kPremiumText),
                                decoration: InputDecoration(
                                  labelText: 'Column Status',
                                  labelStyle: const TextStyle(color: kPremiumMuted),
                                  prefixIcon: const Icon(Icons.view_column_outlined, color: kPremiumGold),
                                  filled: true,
                                  fillColor: kPremiumSurface.withOpacity(0.5),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'To Do', child: Text('To Do')),
                                  DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                                  DropdownMenuItem(value: 'In Review', child: Text('In Review')),
                                  DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                                ],
                                onChanged: (val) => setModalState(() => selectedStatus = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        const Text('Timeline & Deadlines', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kPremiumGold)),
                        const SizedBox(height: 10),

                        // Start Date Picker Tile
                        InkWell(
                          onTap: pickStart,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            decoration: BoxDecoration(
                              color: kPremiumSurface.withOpacity(0.5),
                              border: Border.all(color: Colors.white10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.play_circle_outline, color: Colors.greenAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Start Date & Time', style: TextStyle(fontSize: 11, color: kPremiumMuted)),
                                      Text(formatDisplay(startDate, startTime), style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumText, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // End Date Picker Tile (Due Date)
                        InkWell(
                          onTap: pickEnd,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            decoration: BoxDecoration(
                              color: kPremiumSurface.withOpacity(0.5),
                              border: Border.all(color: Colors.white10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Due Date & Deadline', style: TextStyle(fontSize: 11, color: kPremiumMuted)),
                                      Text(formatDisplay(endDate, endTime), style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        GoldButton(
                          label: 'Create Task',
                          icon: Icons.check_circle_outline,
                          expand: true,
                          isLoading: isSaving,
                          onPressed: isSaving ? null : () async {
                            if (titleCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a task title.'), backgroundColor: Colors.redAccent));
                              return;
                            }
                            setModalState(() => isSaving = true);
                            final orgId = SupabaseService().currentOrganizationId;
                            
                            try {
                              String projName = 'General Task';
                              if (selectedProjectId != null) {
                                final p = _store.projects.firstWhere((p) => p.id == selectedProjectId, orElse: () => ProjectModel(id: '', name: 'General Task', clientId: '', clientName: '', status: '', budget: 0.0, deadline: ''));
                                projName = p.name;
                              }

                              final startIso = formatIso(startDate, startTime);
                              final endIso = formatDisplay(endDate, endTime);

                              await SupabaseService().client.from('tasks').insert({
                                'organization_id': orgId,
                                'title': titleCtrl.text.trim(),
                                'description': descCtrl.text.trim(),
                                'project_id': selectedProjectId,
                                'project_name': projName,
                                'assigned_to': selectedEmployeeName ?? 'Staff Member',
                                'priority': selectedPriority,
                                'status': selectedStatus,
                                'start_date': startIso,
                                'due_date': endIso,
                              });
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              debugPrint('Error creating task: $e');
                            } finally {
                              setModalState(() => isSaving = false);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTaskEditModal(TaskModel task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kPremiumSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPremiumText)),
              const SizedBox(height: 4),
              Text('Assigned to: ${task.assignedToName}  •  Due: ${task.dueDate}', style: const TextStyle(color: kPremiumMuted, fontSize: 13)),
              const Divider(height: 24, color: Colors.white10),
              const Text('Move to Kanban Column:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kPremiumGold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['To Do', 'In Progress', 'In Review', 'Completed'].map((status) {
                  final isSelected = task.status == status;
                  return ChoiceChip(
                    label: Text(status, style: TextStyle(color: isSelected ? kPremiumBg : kPremiumText, fontWeight: FontWeight.bold)),
                    selected: isSelected,
                    selectedColor: kPremiumGold,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    side: BorderSide(color: isSelected ? kPremiumGold : Colors.white10),
                    onSelected: (selected) async {
                      if (selected) {
                        Navigator.pop(context);
                        final dbStatus = status == 'To Do' ? 'Todo' : status;
                        await SupabaseService().client.from('tasks').update({'status': dbStatus}).eq('id', task.id);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _confirmDeleteTask(task),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text('Delete Task', style: TextStyle(color: Colors.redAccent)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteTask(TaskModel task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kPremiumSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kPremiumBorder)),
        title: const Text('Delete Task?', style: TextStyle(color: kPremiumText, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${task.title}"?', style: const TextStyle(color: kPremiumMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kPremiumMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context);
              await SupabaseService().client.from('tasks').delete().eq('id', task.id);
              if (mounted) setState(() {});
            },
            child: const Text('Delete Task'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Task Kanban Board', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
          backgroundColor: kPremiumBg,
          foregroundColor: kPremiumGold,
          elevation: 0,
          actions: [
            if (SupabaseService().currentRole == 'admin')
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 26, color: kPremiumGold),
                  tooltip: 'Add Task',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTaskPage())),
                ),
              ),
          ],
        ),
        body: SafeArea(
          bottom: true,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _tasksStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kPremiumGold));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading tasks: ${snapshot.error}', style: const TextStyle(color: kPremiumDanger)));
              }

              final data = snapshot.data ?? [];
              
              final tasks = data.map((row) {
                final projId = row['project_id']?.toString();
                String projName = row['project_name']?.toString() ?? '';
                if (projName.isEmpty && projId != null && projId.isNotEmpty) {
                  final matched = _store.projects.firstWhere(
                    (p) => p.id == projId,
                    orElse: () => ProjectModel(id: '', name: 'General Task', clientId: '', clientName: '', status: '', budget: 0.0, deadline: ''),
                  );
                  projName = matched.name;
                }
                if (projName.isEmpty) projName = 'General Task';

                final rawAssignee = row['assigned_to']?.toString();
                String assigneeName = 'Staff Member';
                if (rawAssignee != null && rawAssignee.isNotEmpty) {
                  final emp = _store.employees.firstWhere(
                    (e) => e.userId == rawAssignee || e.id == rawAssignee,
                    orElse: () => Employee(id: '', name: rawAssignee, role: '', department: '', email: '', phone: '', status: '', joiningDate: ''),
                  );
                  assigneeName = emp.name.isNotEmpty ? emp.name : 'Staff Member';
                }

                return TaskModel(
                  id: row['id'],
                  title: row['title'] ?? 'Untitled Task',
                  projectName: projName,
                  assignedToName: assigneeName,
                  status: row['status'] ?? 'To Do',
                  priority: row['priority'] ?? 'Medium',
                  dueDate: row['due_date']?.toString() ?? 'No Due Date',
                );
              }).toList();

              final toDo = tasks.where((t) => t.status == 'To Do' || t.status.toLowerCase() == 'todo').toList();
              final inProgress = tasks.where((t) => t.status == 'In Progress' || t.status.toLowerCase() == 'in progress' || t.status.toLowerCase() == 'in_progress').toList();
              final inReview = tasks.where((t) => t.status == 'In Review' || t.status.toLowerCase() == 'in review' || t.status.toLowerCase() == 'review').toList();
              final completed = tasks.where((t) => t.status == 'Completed' || t.status.toLowerCase() == 'completed').toList();

              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 80.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kanbanColumn('To Do', toDo, Colors.blueAccent),
                          _kanbanColumn('In Progress', inProgress, Colors.orangeAccent),
                          _kanbanColumn('In Review', inReview, Colors.purpleAccent),
                          _kanbanColumn('Completed', completed, Colors.greenAccent),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
        ),
      ),
    );
  }

  Widget _kanbanColumn(String title, List<TaskModel> taskList, Color headerColor) {
    return Container(
      width: 290,
      margin: const EdgeInsets.only(right: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 5, backgroundColor: headerColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPremiumText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: headerColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${taskList.length}',
                    style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Colors.white10),
            taskList.isEmpty
                ? Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: const Text('No tasks in column', style: TextStyle(color: kPremiumMuted, fontSize: 12)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: taskList.length,
                    itemBuilder: (context, index) {
                      final task = taskList[index];
                      Color priorityColor = Colors.blueAccent;
                      if (task.priority.toLowerCase() == 'high') priorityColor = Colors.redAccent;
                      if (task.priority.toLowerCase() == 'medium') priorityColor = Colors.orangeAccent;

                      return FadeInSlide(
                        delay: Duration(milliseconds: 40 * (index % 5)),
                        child: GlassCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          onTap: () => _showTaskEditModal(task),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumText, fontSize: 14),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: priorityColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: priorityColor.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      task.priority,
                                      style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.folder_outlined, size: 13, color: kPremiumGold),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      task.projectName,
                                      style: const TextStyle(fontSize: 12, color: kPremiumGold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 13, color: kPremiumMuted),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            task.assignedToName,
                                            style: const TextStyle(fontSize: 11, color: kPremiumMuted),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.event_outlined, size: 13, color: kPremiumMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        task.dueDate,
                                        style: const TextStyle(fontSize: 11, color: kPremiumMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
