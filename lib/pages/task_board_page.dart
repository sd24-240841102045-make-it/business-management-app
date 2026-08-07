import 'package:flutter/material.dart';
import '../services/app_data_store.dart';

class TaskBoardPage extends StatefulWidget {
  const TaskBoardPage({super.key});

  @override
  State<TaskBoardPage> createState() => _TaskBoardPageState();
}

class _TaskBoardPageState extends State<TaskBoardPage> {
  final AppDataStore _store = AppDataStore();

  final List<TaskModel> _sampleTasks = [
    TaskModel(id: 't1', title: 'Setup Supabase RLS Policies', projectName: 'Database Security', assignedToName: 'John Doe', status: 'In Progress', priority: 'High', dueDate: '10 Aug'),
    TaskModel(id: 't2', title: 'Design Client Portal Dashboard', projectName: 'Web Redesign', assignedToName: 'Sarah Jenkins', status: 'To Do', priority: 'Medium', dueDate: '12 Aug'),
    TaskModel(id: 't3', title: 'Audit Attendance Punch Logs', projectName: 'Operations', assignedToName: 'Rohan Verma', status: 'In Review', priority: 'Low', dueDate: '08 Aug'),
    TaskModel(id: 't4', title: 'Deploy Flutter Mobile APK Build', projectName: 'Release v1.2', assignedToName: 'John Doe', status: 'Completed', priority: 'High', dueDate: '06 Aug'),
  ];

  @override
  Widget build(BuildContext context) {
    final tasks = _store.tasks.isNotEmpty ? _store.tasks : _sampleTasks;

    final toDo = tasks.where((t) => t.status == 'To Do').toList();
    final inProgress = tasks.where((t) => t.status == 'In Progress').toList();
    final inReview = tasks.where((t) => t.status == 'In Review').toList();
    final completed = tasks.where((t) => t.status == 'Completed').toList();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Task Kanban Board', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
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
                            Text(task.assignedToName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
