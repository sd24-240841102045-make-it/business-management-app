import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/shared/task_board_page.dart';
import 'package:business_managment_app/shared/invoice_page.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class ProjectDetailsPage extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailsPage({super.key, required this.project});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  final AppDataStore _store = AppDataStore();
  late String _currentStatus;
  
  bool _isLoading = true;
  String _description = '';
  String _health = 'On Track';
  String _startDate = 'Not set';
  String _deadline = 'Not set';
  String _managerName = 'Unassigned';
  int _totalTasks = 0;
  int _completedTasks = 0;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.project.status;
    _fetchProjectDetails();
  }

  Future<void> _fetchProjectDetails() async {
    try {
      final pRes = await SupabaseService().client
          .from('projects')
          .select('description, health, start_date, deadline, manager_id')
          .eq('id', widget.project.id)
          .maybeSingle();

      if (pRes != null) {
        _description = pRes['description']?.toString() ?? '';
        _health = pRes['health']?.toString() ?? 'On Track';
        _startDate = pRes['start_date']?.toString()?.split(' ').first ?? 'Not set';
        _deadline = pRes['deadline']?.toString()?.split(' ').first ?? widget.project.deadline;
        
        final mId = pRes['manager_id']?.toString();
        if (mId != null && mId.isNotEmpty) {
          final emp = _store.employees.firstWhere(
            (e) => e.userId == mId || e.id == mId,
            orElse: () => Employee(id: '', name: 'Assigned PM', role: '', department: '', email: '', phone: '', status: '', joiningDate: ''),
          );
          _managerName = emp.name.isNotEmpty ? emp.name : 'Assigned PM';
        }
      }

      // Fetch Tasks Stats
      try {
        final tasksRes = await SupabaseService().client
            .from('tasks')
            .select('id, status')
            .eq('project_id', widget.project.id);
        if (tasksRes is List) {
          _totalTasks = tasksRes.length;
          _completedTasks = tasksRes.where((t) => t['status'] == 'Completed').length;
        }
      } catch (_) {}

    } catch (e) {
      debugPrint('Error fetching project details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() {
      _currentStatus = newStatus;
    });
    try {
      await SupabaseService().client.from('projects').update({'status': newStatus}).eq('id', widget.project.id);
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  Color _getHealthColor(String health) {
    switch (health.toLowerCase()) {
      case 'on track':
        return Colors.greenAccent;
      case 'at risk':
        return Colors.orangeAccent;
      case 'delayed':
        return Colors.redAccent;
      default:
        return kPremiumGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalTasks > 0 ? (_completedTasks / _totalTasks) : (_currentStatus == 'Completed' ? 1.0 : 0.35);

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Project Overview', style: TextStyle(fontWeight: FontWeight.w700, color: kPremiumGold, fontSize: 18)),
          backgroundColor: kPremiumBg,
          foregroundColor: kPremiumGold,
          elevation: 0,
        ),
        body: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 80.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 750),
                child: FadeInSlide(
                  child: GlassCard(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Clean Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kPremiumGold.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.folder_outlined, color: kPremiumGold, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.project.name,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPremiumText),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Client: ${widget.project.clientName}',
                                    style: const TextStyle(fontSize: 13, color: kPremiumMuted),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getHealthColor(_health).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _getHealthColor(_health).withOpacity(0.3)),
                              ),
                              child: Text(
                                _health,
                                style: TextStyle(color: _getHealthColor(_health), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),

                        if (_description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            _description,
                            style: const TextStyle(color: kPremiumMuted, fontSize: 13, height: 1.4),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Minimal Progress Bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Progress', style: TextStyle(color: kPremiumMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                                Text('${(progress * 100).toInt()}% Completed', style: const TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                color: kPremiumGold,
                                backgroundColor: Colors.white.withOpacity(0.06),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Divider(height: 1, color: Colors.white10),
                        const SizedBox(height: 20),

                        // Minimal 2x2 Metadata Grid
                        Row(
                          children: [
                            Expanded(child: _buildMinimalField('Budget', '\$${widget.project.budget.toStringAsFixed(0)}', Icons.attach_money)),
                            Expanded(child: _buildMinimalField('Project Manager', _managerName, Icons.person_outline)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildMinimalField('Start Date', _startDate, Icons.play_arrow_outlined)),
                            Expanded(child: _buildMinimalField('Deadline', _deadline, Icons.event_outlined)),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Divider(height: 1, color: Colors.white10),
                        const SizedBox(height: 20),

                        // Minimal Status Selector
                        const Text('Status Milestone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kPremiumGold)),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['Planning', 'In Progress', 'On Hold', 'Completed'].map((st) {
                              final isSel = _currentStatus == st;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(st, style: TextStyle(color: isSel ? kPremiumBg : kPremiumText, fontWeight: FontWeight.bold, fontSize: 12)),
                                  selected: isSel,
                                  selectedColor: kPremiumGold,
                                  backgroundColor: Colors.white.withOpacity(0.04),
                                  side: BorderSide(color: isSel ? kPremiumGold : Colors.white10),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  onSelected: (val) {
                                    if (val) _updateStatus(st);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Sleek Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: GoldButton(
                                label: 'Kanban Board ($_completedTasks/$_totalTasks)',
                                icon: Icons.view_kanban_outlined,
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskBoardPage()));
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GoldButton(
                                label: 'View Invoices',
                                icon: Icons.receipt_outlined,
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const InvoicePage()));
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalField(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kPremiumMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: kPremiumMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
