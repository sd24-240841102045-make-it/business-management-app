import 'package:flutter/material.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class EmployeeDashboardPage extends StatefulWidget {
  const EmployeeDashboardPage({super.key});

  @override
  State<EmployeeDashboardPage> createState() => _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends State<EmployeeDashboardPage> {
  final AppDataStore _store = AppDataStore();
  bool _isLoading = true;

  int _activeTasksCount = 0;
  int _tasksDueTodayCount = 0;
  int _activeProjectsCount = 0;
  int _pendingLeavesCount = 0;

  String _userName = 'Employee';
  String _userEmail = '';
  String _userRole = 'Employee';
  String _userDept = 'Operations';

  List<Map<String, dynamic>> _myTasks = [];
  List<Map<String, dynamic>> _myProjects = [];
  List<Map<String, dynamic>> _myLeaves = [];

  @override
  void initState() {
    super.initState();
    _fetchEmployeeData();
  }

  Future<void> _fetchEmployeeData() async {
    final user = SupabaseService().currentUser;
    final userId = user?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      _userEmail = user?.email ?? '';
      final fullName = user?.userMetadata?['full_name']?.toString() ?? 'Employee';
      _userName = fullName;
      _userRole = user?.userMetadata?['role']?.toString().toUpperCase() ?? 'STAFF MEMBER';

      // Match with employee store if present
      for (final e in _store.employees) {
        if (e.id == userId || e.email.toLowerCase() == _userEmail.toLowerCase()) {
          _userDept = e.department;
          break;
        }
      }

      // 1. Fetch My Live Assigned Tasks
      List<Map<String, dynamic>> tasksData = [];
      try {
        final res = await SupabaseService().client
            .from('tasks')
            .select()
            .eq('assigned_to', userId)
            .order('due_date', ascending: true);
        tasksData = List<Map<String, dynamic>>.from(res as List);
      } catch (e) {
        debugPrint('Error fetching tasks for employee: $e');
      }

      // 2. Fetch My Assigned Projects
      List<Map<String, dynamic>> projectsData = [];
      try {
        final res = await SupabaseService().client
            .from('project_members')
            .select('project_id, role_in_project, projects(*)')
            .eq('user_id', userId);
        projectsData = List<Map<String, dynamic>>.from(res as List);
      } catch (e) {
        debugPrint('Error fetching projects for employee: $e');
      }

      // 3. Fetch My Leave Requests
      List<Map<String, dynamic>> leavesData = [];
      try {
        final res = await SupabaseService().client
            .from('leave_requests')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        leavesData = List<Map<String, dynamic>>.from(res as List);
      } catch (e) {
        debugPrint('Error fetching leave requests for employee: $e');
      }

      // Calculate Stat Metrics
      int activeTasks = 0;
      int dueToday = 0;
      final today = DateTime.now();

      for (var t in tasksData) {
        final status = t['status']?.toString() ?? 'To Do';
        if (status != 'Completed') activeTasks++;

        final dueStr = t['due_date']?.toString();
        if (dueStr != null && dueStr.isNotEmpty) {
          try {
            final dueDate = DateTime.parse(dueStr);
            if (dueDate.year == today.year && dueDate.month == today.month && dueDate.day == today.day) {
              dueToday++;
            }
          } catch (_) {}
        }
      }

      int pendingLeaves = leavesData.where((l) => l['status']?.toString() == 'Pending').length;

      if (mounted) {
        setState(() {
          _myTasks = tasksData;
          _myProjects = projectsData;
          _myLeaves = leavesData;
          _activeTasksCount = activeTasks;
          _tasksDueTodayCount = dueToday;
          _activeProjectsCount = projectsData.length;
          _pendingLeavesCount = pendingLeaves;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching employee dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
      final dbStatus = newStatus == 'To Do' ? 'Todo' : newStatus;
      await SupabaseService().client.from('tasks').update({'status': dbStatus}).eq('id', taskId);
      await _fetchEmployeeData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task status updated to $newStatus'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error updating task status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showRequestLeaveDialog() {
    final typeCtrl = TextEditingController(text: 'Vacation');
    final reasonCtrl = TextEditingController();
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime endDate = DateTime.now().add(const Duration(days: 3));
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: kPremiumSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kPremiumBorder)),
              title: const Text('Request Time Off / Leave', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: typeCtrl.text,
                      dropdownColor: kPremiumSurface,
                      style: const TextStyle(color: kPremiumText),
                      decoration: InputDecoration(
                        labelText: 'Leave Category',
                        labelStyle: const TextStyle(color: kPremiumMuted),
                        prefixIcon: const Icon(Icons.category_outlined, color: kPremiumGold),
                        filled: true,
                        fillColor: kPremiumSurface.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Vacation', child: Text('Vacation Leave', style: TextStyle(color: kPremiumText))),
                        DropdownMenuItem(value: 'Sick', child: Text('Sick Leave', style: TextStyle(color: kPremiumText))),
                        DropdownMenuItem(value: 'Personal', child: Text('Personal Leave', style: TextStyle(color: kPremiumText))),
                        DropdownMenuItem(value: 'Maternity/Paternity', child: Text('Maternity / Paternity', style: TextStyle(color: kPremiumText))),
                      ],
                      onChanged: (val) => setModalState(() => typeCtrl.text = val!),
                    ),
                    const SizedBox(height: 14),

                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime.now(), lastDate: DateTime(2100));
                        if (picked != null) setModalState(() => startDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: kPremiumSurface.withOpacity(0.5), border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.date_range, color: Colors.greenAccent),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Date', style: TextStyle(color: kPremiumMuted, fontSize: 12)),
                                Text('${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}', style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: endDate, firstDate: startDate, lastDate: DateTime(2100));
                        if (picked != null) setModalState(() => endDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: kPremiumSurface.withOpacity(0.5), border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_busy, color: Colors.redAccent),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('End Date', style: TextStyle(color: kPremiumMuted, fontSize: 12)),
                                Text('${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}', style: const TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: kPremiumText),
                      decoration: InputDecoration(
                        labelText: 'Reason for leave',
                        labelStyle: const TextStyle(color: kPremiumMuted),
                        prefixIcon: const Icon(Icons.description_outlined, color: kPremiumGold),
                        filled: true,
                        fillColor: kPremiumSurface.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: kPremiumMuted))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kPremiumGold, foregroundColor: kPremiumBg),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final user = SupabaseService().currentUser;
                          final orgId = SupabaseService().currentOrganizationId;
                          if (user == null) return;
                          setModalState(() => isSaving = true);
                          try {
                            final sStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
                            final eStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

                            await SupabaseService().client.from('leave_requests').insert({
                              if (orgId != null) 'organization_id': orgId,
                              'user_id': user.id,
                              'employee_id': user.id,
                              'leave_type': typeCtrl.text,
                              'start_date': sStr,
                              'end_date': eStr,
                              'reason': reasonCtrl.text.trim(),
                              'status': 'Pending',
                            });

                            if (mounted) {
                              Navigator.pop(dialogContext);
                              _fetchEmployeeData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Leave request submitted!'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error submitting leave: $e');
                            setModalState(() => isSaving = false);
                          }
                        },
                  child: isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kPremiumBg)) : const Text('Submit Request'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'low':
        return Colors.blueAccent;
      default:
        return kPremiumGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const PremiumBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator(color: kPremiumGold)),
        ),
      );
    }

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;
              final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth <= 800;

              return RefreshIndicator(
                color: kPremiumGold,
                onRefresh: _fetchEmployeeData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).padding.bottom + 80.0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HERO BANNER & PROFILE BADGE
                          FadeInSlide(
                            index: 0,
                            child: GlassCard(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  PremiumAvatar(
                                    label: _userName,
                                    style: AvatarStyle.gradient,
                                    size: 64,
                                    radius: 32,
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('Welcome, $_userName 👋', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPremiumGold)),
                                        const SizedBox(height: 4),
                                        Text('$_userRole • $_userDept • $_userEmail', style: const TextStyle(fontSize: 13, color: kPremiumMuted)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // STAT METRICS GRID
                          GridView.count(
                            crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 1),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: isDesktop ? 2.2 : (isTablet ? 2.5 : 3.2),
                            children: [
                              FadeInSlide(index: 1, child: _buildStatCard('Active Tasks', _activeTasksCount.toString(), Icons.assignment_outlined, Colors.orangeAccent)),
                              FadeInSlide(index: 2, child: _buildStatCard('Due Today', _tasksDueTodayCount.toString(), Icons.warning_amber_rounded, Colors.redAccent)),
                              FadeInSlide(index: 3, child: _buildStatCard('My Projects', _activeProjectsCount.toString(), Icons.folder_open_outlined, Colors.blueAccent)),
                              FadeInSlide(index: 4, child: _buildStatCard('Pending Leaves', _pendingLeavesCount.toString(), Icons.event_note_outlined, Colors.purpleAccent)),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // SECTION 1: MY LIVE ASSIGNED TASKS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('My Assigned Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPremiumGold)),
                              Text('${_myTasks.length} Total Tasks', style: const TextStyle(color: kPremiumMuted, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (_myTasks.isEmpty)
                            GlassCard(
                              padding: const EdgeInsets.all(24),
                              child: const Center(
                                child: Text('No tasks currently assigned to you in Supabase database.', style: TextStyle(color: kPremiumMuted, fontSize: 14)),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _myTasks.length,
                              itemBuilder: (context, index) {
                                final task = _myTasks[index];
                                final title = task['title'] ?? 'Untitled Task';
                                final priority = task['priority'] ?? 'Medium';
                                final status = task['status'] ?? 'To Do';
                                final dueDate = task['due_date'] ?? 'No Deadline';
                                final pColor = _getPriorityColor(priority);

                                return FadeInSlide(
                                  index: index + 5,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPremiumText)),
                                              ),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: pColor.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: pColor.withOpacity(0.4)),
                                                ),
                                                child: Text('$priority Priority', style: TextStyle(color: pColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(task['description'].toString(), style: const TextStyle(color: kPremiumMuted, fontSize: 13)),
                                          ],
                                          const Divider(height: 20, color: Colors.white10),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.schedule_outlined, size: 14, color: kPremiumGold),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  'Due: $dueDate',
                                                  style: const TextStyle(color: kPremiumMuted, fontSize: 12),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              PopupMenuButton<String>(
                                                color: kPremiumSurface,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: kPremiumGold.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      Text(status, style: const TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold, fontSize: 12)),
                                                      const SizedBox(width: 2),
                                                      const Icon(Icons.arrow_drop_down, color: kPremiumGold, size: 16),
                                                    ],
                                                  ),
                                                ),
                                                onSelected: (val) => _updateTaskStatus(task['id'], val),
                                                itemBuilder: (context) => const [
                                                  PopupMenuItem(value: 'To Do', child: Text('To Do', style: TextStyle(color: kPremiumText))),
                                                  PopupMenuItem(value: 'In Progress', child: Text('In Progress', style: TextStyle(color: kPremiumText))),
                                                  PopupMenuItem(value: 'In Review', child: Text('In Review', style: TextStyle(color: kPremiumText))),
                                                  PopupMenuItem(value: 'Completed', child: Text('Completed', style: TextStyle(color: kPremiumText))),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 32),

                          // SECTION 2: MY ASSIGNED PROJECTS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('My Assigned Projects', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPremiumGold)),
                              Text('${_myProjects.length} Projects', style: const TextStyle(color: kPremiumMuted, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (_myProjects.isEmpty)
                            GlassCard(
                              padding: const EdgeInsets.all(24),
                              child: const Center(
                                child: Text('No projects assigned to your account in Supabase database.', style: TextStyle(color: kPremiumMuted, fontSize: 14)),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _myProjects.length,
                              itemBuilder: (context, index) {
                                final pMap = _myProjects[index]['projects'] as Map<String, dynamic>? ?? {};
                                final pName = pMap['name'] ?? 'Project';
                                final pStatus = pMap['status'] ?? 'In Progress';
                                final pDeadline = pMap['deadline'] ?? 'No Deadline';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: GlassCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                              child: const Icon(Icons.folder_outlined, color: Colors.blueAccent, size: 22),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumText, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Text('Status: $pStatus', style: const TextStyle(color: kPremiumMuted, fontSize: 12)),
                                            Text('Deadline: $pDeadline', style: const TextStyle(color: kPremiumGold, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 32),

                          // SECTION 3: MY ATTENDANCE & LEAVE REQUESTS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(
                                child: Text(
                                  'My Attendance & Leave',
                                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: kPremiumGold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: _showRequestLeaveDialog,
                                icon: const Icon(Icons.add_circle_outline, color: kPremiumGold, size: 18),
                                label: const Text('Request Time Off', style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (_myLeaves.isEmpty)
                            GlassCard(
                              padding: const EdgeInsets.all(24),
                              child: const Center(
                                child: Text('No leave requests submitted yet.', style: TextStyle(color: kPremiumMuted, fontSize: 14)),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _myLeaves.length,
                              itemBuilder: (context, index) {
                                final l = _myLeaves[index];
                                final lType = l['leave_type'] ?? 'Leave';
                                final lStatus = l['status'] ?? 'Pending';
                                final sDate = l['start_date'] ?? '';
                                final eDate = l['end_date'] ?? '';
                                final reason = l['reason'] ?? '';

                                Color sColor = Colors.orangeAccent;
                                if (lStatus == 'Approved') sColor = Colors.greenAccent;
                                if (lStatus == 'Rejected') sColor = Colors.redAccent;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: GlassCard(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: sColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                          child: Icon(Icons.event_note_outlined, color: sColor, size: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(lType, style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumText, fontSize: 15)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$sDate  →  $eDate ${reason.isNotEmpty ? "($reason)" : ""}',
                                                style: const TextStyle(color: kPremiumMuted, fontSize: 12),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: sColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: sColor.withOpacity(0.4)),
                                          ),
                                          child: Text(lStatus, style: TextStyle(color: sColor, fontSize: 12, fontWeight: FontWeight.bold)),
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: kPremiumMuted, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPremiumText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
