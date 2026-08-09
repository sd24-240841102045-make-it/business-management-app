import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';

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
    final dueDateCtrl = TextEditingController();
    String selectedPriority = 'Medium';
    String selectedStatus = 'To Do';
    String? selectedEmployeeName = _store.employees.isNotEmpty ? _store.employees.first.name : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Add Kanban Task', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        prefixIcon: const Icon(Icons.assignment),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedEmployeeName,
                      decoration: InputDecoration(
                        labelText: 'Assign HR Employee',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _store.employees.map((e) {
                        return DropdownMenuItem(value: e.name, child: Text(e.name));
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedEmployeeName = val),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: const Icon(Icons.priority_high),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Low', child: Text('Low Priority')),
                        DropdownMenuItem(value: 'Medium', child: Text('Medium Priority')),
                        DropdownMenuItem(value: 'High', child: Text('High Priority')),
                      ],
                      onChanged: (val) => setModalState(() => selectedPriority = val!),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Column Status',
                        prefixIcon: const Icon(Icons.view_column),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'To Do', child: Text('To Do')),
                        DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                        DropdownMenuItem(value: 'In Review', child: Text('In Review')),
                        DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                      ],
                      onChanged: (val) => setModalState(() => selectedStatus = val!),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: dueDateCtrl,
                      decoration: InputDecoration(
                        labelText: 'Due Date (e.g. 15 Dec)',
                        prefixIcon: const Icon(Icons.event),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final orgId = SupabaseService().currentOrganizationId;
                    
                    try {
                      await SupabaseService().client.from('tasks').insert({
                        'organization_id': orgId,
                        'title': titleCtrl.text.trim(),
                        'assigned_to': selectedEmployeeName ?? 'Staff',
                        'priority': selectedPriority,
                        'status': selectedStatus,
                        'due_date': dueDateCtrl.text.trim().isNotEmpty ? dueDateCtrl.text.trim() : 'Tomorrow',
                      });
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      debugPrint('Error creating task: $e');
                    }
                  },
                  child: const Text('Add Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTaskEditModal(TaskModel task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Assigned to: ${task.assignedToName} • Due: ${task.dueDate}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const Divider(height: 24),
              const Text('Move to Kanban Column:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: ['To Do', 'In Progress', 'In Review', 'Completed'].map((status) {
                  final isSelected = task.status == status;
                  return ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    selectedColor: Colors.deepPurple,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                    onSelected: (selected) async {
                      if (selected) {
                        Navigator.pop(context);
                        await SupabaseService().client.from('tasks').update({'status': status}).eq('id', task.id);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await SupabaseService().client.from('tasks').delete().eq('id', task.id);
                  },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Kanban Board', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (SupabaseService().currentRole == 'admin')
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 26),
              tooltip: 'Add Task',
              onPressed: _showAddTaskDialog,
            ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _tasksStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading tasks: ${snapshot.error}'));
          }

          final data = snapshot.data ?? [];
          
          final tasks = data.map((row) => TaskModel(
            id: row['id'],
            title: row['title'] ?? 'Untitled Task',
            projectName: row['project_name']?.toString() ?? 'General Task',
            assignedToName: row['assigned_to']?.toString() ?? 'Staff Member',
            status: row['status'] ?? 'To Do',
            priority: row['priority'] ?? 'Medium',
            dueDate: row['due_date']?.toString() ?? 'No Due Date',
          )).toList();

          final toDo = tasks.where((t) => t.status == 'To Do').toList();
          final inProgress = tasks.where((t) => t.status == 'In Progress').toList();
          final inReview = tasks.where((t) => t.status == 'In Review').toList();
          final completed = tasks.where((t) => t.status == 'Completed').toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kanbanColumn('To Do', toDo, Colors.blue),
                        _kanbanColumn('In Progress', inProgress, Colors.orange),
                        _kanbanColumn('In Review', inReview, Colors.purple),
                        _kanbanColumn('Completed', completed, Colors.green),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _kanbanColumn(String title, List<TaskModel> taskList, Color headerColor) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 6, backgroundColor: headerColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Chip(
                label: Text('${taskList.length}'),
                padding: EdgeInsets.zero,
                backgroundColor: headerColor.withOpacity(0.12),
                labelStyle: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const Divider(height: 20),
          Expanded(
            child: taskList.isEmpty
                ? const Center(child: Text('No tasks', style: TextStyle(color: Colors.grey, fontSize: 12)))
                : ListView.builder(
                    itemCount: taskList.length,
                    itemBuilder: (context, index) {
                      final task = taskList[index];
                      return InkWell(
                        onTap: () => _showTaskEditModal(task),
                        child: Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(task.projectName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        task.assignedToName,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(task.dueDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
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
