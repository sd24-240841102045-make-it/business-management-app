import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/shared/project_details_page.dart';
import 'package:business_managment_app/shared/add_project_page.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class ProjectPage extends StatefulWidget {
  const ProjectPage({super.key});

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  final AppDataStore _store = AppDataStore();
  List<String> _userProjectIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
    _loadUserProjects();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) setState(() {});
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
    if (_store.projects.isEmpty) {
      await _store.refreshFromSupabase();
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgId = SupabaseService().currentOrganizationId;
    final Stream<List<Map<String, dynamic>>>? projectsStream = (orgId != null)
        ? SupabaseService().client.from('projects').stream(primaryKey: ['id']).eq('organization_id', orgId)
        : null;

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Projects Portfolio', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
          backgroundColor: kPremiumBg,
          foregroundColor: kPremiumGold,
          elevation: 0,
          actions: [
            if (SupabaseService().currentRole == 'admin')
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 26, color: kPremiumGold),
                  tooltip: 'Create New Project',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProjectPage())),
                ),
              ),
          ],
        ),
        body: SafeArea(
          bottom: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final hPad = isMobile ? 16.0 : 28.0;

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: projectsStream,
                builder: (context, snapshot) {
                  List<Map<String, dynamic>> data = [];

                  if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                    data = snapshot.data!;
                  } else if (_store.projects.isNotEmpty) {
                    // Seamless fallback to store projects if realtime stream is empty/loading/error
                    data = _store.projects.map((p) => {
                      'id': p.id,
                      'name': p.name,
                      'client_id': p.clientId,
                      'status': p.status,
                      'budget': p.budget,
                      'deadline': p.deadline,
                    }).toList();
                  }

                  if (snapshot.connectionState == ConnectionState.waiting && data.isEmpty && _isLoading) {
                    return const Center(child: CircularProgressIndicator(color: kPremiumGold));
                  }

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
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: GlassCard(
                          padding: const EdgeInsets.all(36),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_open_outlined, size: 64, color: kPremiumMuted),
                              const SizedBox(height: 14),
                              const Text('No Active Projects Found', style: TextStyle(color: kPremiumText, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              const Text('Create your first project to start tracking deliverables and deadlines.', style: TextStyle(color: kPremiumMuted, fontSize: 13), textAlign: TextAlign.center),
                              const SizedBox(height: 20),
                              if (SupabaseService().currentRole == 'admin')
                                GoldButton(
                                  label: 'Create First Project',
                                  icon: Icons.add,
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProjectPage())),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: hPad,
                      right: hPad,
                      top: 20,
                      bottom: MediaQuery.of(context).padding.bottom + 80.0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HeroBanner(
                              title: 'Project Portfolio',
                              subtitle: '${data.length} Total Projects • Milestones, Deadlines & Deliverables',
                              badge: 'Project Management',
                            ),
                            const SizedBox(height: 20),
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

                                final isCompleted = p.status == 'Completed';

                                return FadeInSlide(
                                  delay: Duration(milliseconds: 50 * (index % 6)),
                                  child: GlassCard(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(18),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => ProjectDetailsPage(project: p)),
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        PremiumAvatar(
                                          icon: isCompleted ? Icons.check_circle_outline : Icons.folder_outlined,
                                          style: AvatarStyle.glowIcon,
                                          size: 48,
                                          radius: 24,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPremiumText),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Client: ${p.clientName}  •  Budget: \$${p.budget.toStringAsFixed(0)}',
                                                style: const TextStyle(fontSize: 13, color: kPremiumMuted),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(Icons.calendar_today_outlined, size: 13, color: kPremiumGold),
                                                  const SizedBox(width: 5),
                                                  Expanded(
                                                    child: Text(
                                                      'Deadline: ${p.deadline}',
                                                      style: const TextStyle(fontSize: 12, color: kPremiumGold),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: isCompleted ? Colors.green.withOpacity(0.15) : kPremiumGold.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: isCompleted ? Colors.green.withOpacity(0.3) : kPremiumGold.withOpacity(0.3)),
                                              ),
                                              child: Text(
                                                p.status,
                                                style: TextStyle(
                                                  color: isCompleted ? Colors.greenAccent : kPremiumGold,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            if (SupabaseService().currentRole == 'admin') ...[
                                              const SizedBox(height: 6),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                                onPressed: () => _confirmDeleteProject(p),
                                                tooltip: 'Delete Project',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
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
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmDeleteProject(ProjectModel project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kPremiumSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kPremiumBorder)),
        title: const Text('Delete Project?', style: TextStyle(color: kPremiumText, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${project.name}"? This action cannot be undone.', style: const TextStyle(color: kPremiumMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kPremiumMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              await SupabaseService().client.from('projects').delete().eq('id', project.id);
              await _store.refreshFromSupabase();
              if (mounted) setState(() {});
            },
            child: const Text('Delete Project'),
          ),
        ],
      ),
    );
  }
}
