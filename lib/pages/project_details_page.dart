import 'package:flutter/material.dart';
import '../services/app_data_store.dart';

class ProjectDetailsPage extends StatelessWidget {
  final ProjectModel project;

  const ProjectDetailsPage({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Client Account: ${project.clientName}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    const Divider(height: 32),
                    ListTile(
                      leading: const Icon(Icons.attach_money, color: Colors.teal),
                      title: const Text('Total Project Budget'),
                      subtitle: Text('\$${project.budget.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.event, color: Colors.teal),
                      title: const Text('Target Deadline'),
                      subtitle: Text(project.deadline),
                    ),
                    ListTile(
                      leading: const Icon(Icons.flag, color: Colors.teal),
                      title: const Text('Current Milestone Status'),
                      subtitle: Text(project.status, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
