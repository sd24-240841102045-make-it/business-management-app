import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/shared/task_board_page.dart';
import 'package:business_managment_app/shared/invoice_page.dart';

class ProjectDetailsPage extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailsPage({super.key, required this.project});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.project.status;
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() {
      _currentStatus = newStatus;
    });
    try {
      await SupabaseService().client.from('projects').update({'status': newStatus}).eq('id', widget.project.id);
    } catch (e) {
      debugPrint('Error updating project status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
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
                    Text(widget.project.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Client Account: ${widget.project.clientName}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    const Divider(height: 32),
                    ListTile(
                      leading: const Icon(Icons.attach_money, color: Colors.teal),
                      title: const Text('Total Project Budget'),
                      subtitle: Text('\$${widget.project.budget.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.event, color: Colors.teal),
                      title: const Text('Target Deadline'),
                      subtitle: Text(widget.project.deadline),
                    ),
                    ListTile(
                      leading: const Icon(Icons.flag, color: Colors.teal),
                      title: const Text('Current Milestone Status'),
                      subtitle: Text(_currentStatus, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Update Project Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: ['Planning', 'In Progress', 'On Hold', 'Completed'].map((st) {
                        final isSel = _currentStatus == st;
                        return ChoiceChip(
                          label: Text(st),
                          selected: isSel,
                          selectedColor: Colors.teal,
                          labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                          onSelected: (val) {
                            if (val) _updateStatus(st);
                          },
                        );
                      }).toList(),
                    ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskBoardPage()));
                            },
                            icon: const Icon(Icons.view_kanban),
                            label: const Text('View Kanban Tasks'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const InvoicePage()));
                            },
                            icon: const Icon(Icons.receipt_long),
                            label: const Text('Generate Invoice'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
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
    );
  }
}
