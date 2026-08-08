import 'package:flutter/material.dart';
import '../services/app_data_store.dart';
import '../services/supabase_service.dart';
import 'project_details_page.dart';

class ProjectPage extends StatefulWidget {
  const ProjectPage({super.key});

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  final _projectsStream = SupabaseService().client.from('projects').stream(primaryKey: ['id']);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (SupabaseService().currentRole == 'admin')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                // Add project logic
              },
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final hPad = isMobile ? 12.0 : 24.0;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _projectsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final data = snapshot.data ?? [];
              if (data.isEmpty) {
                return const Center(child: Text('No projects found. Add one!'));
              }

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: data.length,
                          itemBuilder: (context, index) {
                            final row = data[index];
                            final p = ProjectModel(
                              id: row['id'],
                              name: row['name'],
                              clientId: row['client_id'] ?? '',
                              clientName: 'Assigned Client', 
                              status: row['status'] ?? 'Planning',
                              budget: (row['budget'] as num?)?.toDouble() ?? 0.0,
                              deadline: row['deadline']?.toString() ?? 'No deadline',
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 14),
                              elevation: 3,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFE0F2F1),
                                  child: Icon(Icons.folder, color: Colors.teal),
                                ),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Text('Deadline: ${p.deadline}'),
                                trailing: Chip(
                                  label: Text(p.status),
                                  backgroundColor: p.status == 'Completed' ? Colors.green.withOpacity(0.12) : Colors.teal.withOpacity(0.12),
                                  labelStyle: TextStyle(color: p.status == 'Completed' ? Colors.green : Colors.teal, fontWeight: FontWeight.bold),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => ProjectDetailsPage(project: p)),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
