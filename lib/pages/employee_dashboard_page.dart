import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class EmployeeDashboardPage extends StatefulWidget {
  const EmployeeDashboardPage({super.key});

  @override
  State<EmployeeDashboardPage> createState() => _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends State<EmployeeDashboardPage> {
  bool _isLoading = true;
  int _activeTasks = 0;
  int _tasksDueToday = 0;
  int _activeProjects = 0;
  String _userName = 'Employee';

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final userId = SupabaseService().currentUser?.id;
    if (userId == null) return;

    try {
      final name = SupabaseService().currentUser?.userMetadata?['full_name'] ?? 'Employee';
      setState(() => _userName = name.split(' ').first);

      // Fetch Tasks
      final tasks = await SupabaseService().client
          .from('tasks')
          .select('id, status, due_date')
          .eq('assigned_to', userId)
          .neq('status', 'Completed');

      // Fetch Projects
      final projects = await SupabaseService().client
          .from('project_members')
          .select('project_id')
          .eq('user_id', userId);

      int dueToday = 0;
      final today = DateTime.now();
      for (var t in tasks) {
        if (t['due_date'] != null) {
          final dueDate = DateTime.parse(t['due_date']);
          if (dueDate.year == today.year && dueDate.month == today.month && dueDate.day == today.day) {
            dueToday++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _activeTasks = tasks.length;
          _tasksDueToday = dueToday;
          _activeProjects = projects.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching employee dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good Morning, $_userName 👋',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: isDesktop ? 3 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isDesktop ? 2.5 : 3.0,
                children: [
                  _buildStatCard('Active Tasks', _activeTasks.toString(), Icons.check_circle_outline, Colors.orange),
                  _buildStatCard('Due Today', _tasksDueToday.toString(), Icons.warning_amber_rounded, Colors.red),
                  _buildStatCard('My Projects', _activeProjects.toString(), Icons.folder_open, Colors.blue),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Recent Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: const ListTile(
                  leading: Icon(Icons.notifications_active, color: Colors.deepPurple),
                  title: Text('Welcome to your new dashboard!'),
                  subtitle: Text('Just now'),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
