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
  final AppDataStore _store = AppDataStore();
  String _selectedFilterEmployeeId = 'ALL';

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
    _loadInitialData();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadInitialData() async {
    if (_store.tasks.isEmpty) {
      await _store.refreshFromSupabase();
      if (mounted) setState(() {});
    }
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
              Text('Assigned to: ${task.assignedToName}  \u2022  Due: ${task.dueDate}', style: const TextStyle(color: kPremiumMuted, fontSize: 13)),
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
                        try {
                          await SupabaseService().client.from('tasks').update({'status': dbStatus}).eq('id', task.id);
                        } catch (e) {
                          debugPrint('Error updating task status: $e');
                        }
                        await _store.refreshFromSupabase();
                        if (mounted) setState(() {});
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
              await _store.refreshFromSupabase();
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
    final orgId = SupabaseService().currentOrganizationId;
    final Stream<List<Map<String, dynamic>>>? tasksStream = (orgId != null)
        ? SupabaseService().client.from('tasks').stream(primaryKey: ['id']).eq('organization_id', orgId)
        : null;

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Task Kanban Board', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 18)),
              if (SupabaseService().currentRole != 'admin' && SupabaseService().currentRole != 'owner')
                const Text('Showing tasks allocated to you', style: TextStyle(color: kPremiumMuted, fontSize: 11)),
            ],
          ),
          backgroundColor: kPremiumBg,
          foregroundColor: kPremiumGold,
          elevation: 0,
          actions: [
            if (SupabaseService().currentRole == 'admin' || SupabaseService().currentRole == 'owner') ...[
              if (_store.employees.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: kPremiumSurface,
                      value: _selectedFilterEmployeeId,
                      style: const TextStyle(color: kPremiumText, fontSize: 12),
                      icon: const Icon(Icons.filter_list, color: kPremiumGold, size: 20),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Employees', style: TextStyle(color: kPremiumText, fontSize: 12))),
                        ..._store.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, style: const TextStyle(color: kPremiumText, fontSize: 12)))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedFilterEmployeeId = val);
                      },
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: IconButton(
                  icon: const Icon(Icons.add_task_rounded, size: 26, color: kPremiumGold),
                  tooltip: 'Create New Task',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddTaskPage()),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        body: SafeArea(
          bottom: true,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: tasksStream,
            builder: (context, snapshot) {
              List<Map<String, dynamic>> data = [];

              if (_store.tasks.isNotEmpty) {
                data = _store.tasks.map((t) => {
                  'id': t.id,
                  'title': t.title,
                  'project_id': t.projectId,
                  'project_name': t.projectName,
                  'assigned_to': t.assignedToId.isNotEmpty ? t.assignedToId : t.assignedToName,
                  'assigned_to_name': t.assignedToName,
                  'status': t.status,
                  'priority': t.priority,
                  'due_date': t.dueDate,
                }).toList();
              } else if (snapshot.hasData && snapshot.data != null) {
                data = snapshot.data!;
              }

              if (snapshot.connectionState == ConnectionState.waiting && data.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: kPremiumGold));
              }

              final role = SupabaseService().currentRole;
              final bool isAdmin = role == 'admin' || role == 'owner';
              final user = SupabaseService().currentUser;
              final userId = user?.id;
              final userEmail = user?.email?.toLowerCase().trim() ?? '';
              final userName = user?.userMetadata?['full_name']?.toString().toLowerCase().trim() ?? '';

              String? myEmployeeId;
              String? myEmployeeName;
              for (final e in _store.employees) {
                if (e.userId == userId || e.id == userId || (userEmail.isNotEmpty && e.email.toLowerCase().trim() == userEmail)) {
                  myEmployeeId = e.id;
                  myEmployeeName = e.name.toLowerCase().trim();
                  break;
                }
              }

              // Strict allocation filter:
              // Non-admins ONLY see tasks allocated directly to them!
              if (!isAdmin) {
                data = data.where((row) {
                  final assignedTo = row['assigned_to']?.toString().trim();
                  final assignedName = row['assigned_to_name']?.toString().toLowerCase().trim() ?? '';

                  if ((assignedTo == null || assignedTo.isEmpty) && assignedName.isEmpty) {
                    return false;
                  }

                  final bool matchesUserId = userId != null && assignedTo == userId;
                  final bool matchesEmpId = myEmployeeId != null && assignedTo == myEmployeeId;
                  final bool matchesEmpName = (myEmployeeName != null && myEmployeeName!.isNotEmpty && (assignedTo?.toLowerCase() == myEmployeeName || assignedName == myEmployeeName)) ||
                      (userName.isNotEmpty && (assignedTo?.toLowerCase() == userName || assignedName == userName));

                  return matchesUserId || matchesEmpId || matchesEmpName;
                }).toList();
              } else if (_selectedFilterEmployeeId != 'ALL') {
                final emp = _store.employees.firstWhere(
                  (e) => e.id == _selectedFilterEmployeeId,
                  orElse: () => Employee(id: '', name: '', role: '', department: '', email: '', phone: '', status: '', joiningDate: ''),
                );
                data = data.where((row) {
                  final assignedTo = row['assigned_to']?.toString().trim();
                  final assignedName = row['assigned_to_name']?.toString().toLowerCase().trim() ?? '';
                  return assignedTo == _selectedFilterEmployeeId ||
                      (emp.userId.isNotEmpty && assignedTo == emp.userId) ||
                      (emp.name.isNotEmpty && (assignedTo?.toLowerCase() == emp.name.toLowerCase() || assignedName == emp.name.toLowerCase()));
                }).toList();
              }
              
              final activeProjectIds = _store.projects.map((p) => p.id).toSet();

              final tasks = data.where((row) {
                final projId = row['project_id']?.toString();
                if (projId != null && projId.isNotEmpty) {
                  if (SupabaseService().isProjectDeleted(projId)) return false;
                  if (!activeProjectIds.contains(projId)) return false;
                }
                return true;
              }).map((row) {
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
                String assigneeName = row['assigned_to_name']?.toString() ?? 'Staff Member';
                if (rawAssignee != null && rawAssignee.isNotEmpty) {
                  final emp = _store.employees.firstWhere(
                    (e) => e.userId == rawAssignee || e.id == rawAssignee,
                    orElse: () => Employee(id: '', name: rawAssignee, role: '', department: '', email: '', phone: '', status: '', joiningDate: ''),
                  );
                  if (emp.name.isNotEmpty) assigneeName = emp.name;
                }

                return TaskModel(
                  id: row['id'],
                  title: row['title'] ?? 'Untitled Task',
                  projectId: projId ?? '',
                  projectName: projName,
                  assignedToId: rawAssignee ?? '',
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
