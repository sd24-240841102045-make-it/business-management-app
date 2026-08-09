import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/shared/project_details_page.dart';
import 'package:business_managment_app/shared/add_project_page.dart';

class ProjectPage extends StatefulWidget {
  const ProjectPage({super.key});

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  final _projectsStream = SupabaseService().client.from('projects').stream(primaryKey: ['id']);
  final AppDataStore _store = AppDataStore();
  List<String> _userProjectIds = [];

  @override
  void initState() {
    super.initState();
    _loadUserProjects();
  }

  Future<void> _loadUserProjects() async {
    final userId = SupabaseService().currentUser?.id;
    if (userId != null && SupabaseService().currentRole != 'admin') {
      final ids = await SupabaseService().fetchUserProjectIds(userId);
      if (mounted) {
        setState(() {
          _userProjectIds = ids;
        });
      }
    }
  }

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
              icon: const Icon(Icons.add_circle_outline, size: 26),
              tooltip: 'Create New Project',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProjectPage())),
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
                return Center(child: Text('Error loading projects: ${snapshot.error}'));
              }

              var data = snapshot.data ?? [];
              
              if (SupabaseService().currentRole != 'admin') {
                final userId = SupabaseService().currentUser?.id;
                data = data.where((row) {
                  final managerId = row['manager_id']?.toString();
                  final projectId = row['id']?.toString();
                  return managerId == userId || _userProjectIds.contains(projectId);
                }).toList();
              }

              if (data.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open, size: 60, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No projects found.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 16),
                      if (SupabaseService().currentRole == 'admin')
                        ElevatedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProjectPage())),
                          icon: const Icon(Icons.add),
                          label: const Text('Create First Project'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        ),
                    ],
                  ),
                );
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
                            final clientId = row['client_id']?.toString() ?? '';
                            final matchedClient = _store.clients.firstWhere(
                              (c) => c.id == clientId,
                              orElse: () => ClientModel(id: '', name: 'General Client', company: '', email: '', phone: '', status: ''),
                            );

                            final p = ProjectModel(
                              id: row['id'],
                              name: row['name'] ?? 'Untitled Project',
                              clientId: clientId,
                              clientName: matchedClient.name,
                              status: row['status'] ?? 'Planning',
                              budget: (row['budget'] as num?)?.toDouble() ?? 0.0,
                              deadline: row['deadline']?.toString() ?? 'No deadline',
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 14),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: p.status == 'Completed' ? Colors.green.shade50 : Colors.teal.shade50,
                                  child: Icon(Icons.folder, color: p.status == 'Completed' ? Colors.green : Colors.teal),
                                ),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Client: ${p.clientName} • Budget: \$${p.budget.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                    Text('Deadline: ${p.deadline}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Chip(
                                      label: Text(p.status),
                                      backgroundColor: p.status == 'Completed' ? Colors.green.withOpacity(0.12) : Colors.teal.withOpacity(0.12),
                                      labelStyle: TextStyle(color: p.status == 'Completed' ? Colors.green : Colors.teal, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                    if (SupabaseService().currentRole == 'admin')
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        onPressed: () async {
                                          await SupabaseService().client.from('projects').delete().eq('id', p.id);
                                        },
                                      ),
                                  ],
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
