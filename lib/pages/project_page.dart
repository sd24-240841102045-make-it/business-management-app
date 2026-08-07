import 'package:flutter/material.dart';
import '../services/app_data_store.dart';
import 'project_details_page.dart';

class ProjectPage extends StatefulWidget {
  const ProjectPage({super.key});

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  final AppDataStore _store = AppDataStore();

  @override
  Widget build(BuildContext context) {
    // Initial sample projects if empty
    final projects = _store.projects.isNotEmpty
        ? _store.projects
        : [
            ProjectModel(id: 'p1', name: 'ERP System Migration', clientId: 'c1', clientName: 'Tesla Motors', budget: 45000, deadline: '15 Sep 2026', status: 'In Progress'),
            ProjectModel(id: 'p2', name: 'Mobile App Redesign', clientId: 'c2', clientName: 'Apple Inc.', budget: 28000, deadline: '30 Oct 2026', status: 'In Progress'),
            ProjectModel(id: 'p3', name: 'Cloud Infrastructure Setup', clientId: 'c3', clientName: 'Amazon Web', budget: 62000, deadline: '10 Nov 2026', status: 'Completed'),
          ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final hPad = isMobile ? 12.0 : 24.0;

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
                      itemCount: projects.length,
                      itemBuilder: (context, index) {
                        final p = projects[index];
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
                            subtitle: Text('Client: ${p.clientName} • Deadline: ${p.deadline}'),
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
      ),
    );
  }
}
