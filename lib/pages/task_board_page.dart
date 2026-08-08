import 'package:flutter/material.dart';
import '../services/app_data_store.dart';
import '../services/supabase_service.dart';

class TaskBoardPage extends StatefulWidget {
  const TaskBoardPage({super.key});

  @override
  State<TaskBoardPage> createState() => _TaskBoardPageState();
}

class _TaskBoardPageState extends State<TaskBoardPage> {
  final _tasksStream = SupabaseService().client.from('tasks').stream(primaryKey: ['id']);

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
              icon: const Icon(Icons.add),
              onPressed: () {
                // Add task logic
              },
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
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data ?? [];
          
          final tasks = data.map((row) => TaskModel(
            id: row['id'],
            title: row['title'],
            projectName: 'Assigned Project',
            assignedToName: 'Assigned Employee',
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
            child: ListView.builder(
              itemCount: taskList.length,
              itemBuilder: (context, index) {
                final task = taskList[index];
                return Card(
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
