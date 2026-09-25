import 'package:flutter/material.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/core/premium_theme.dart';
import 'package:business_managment_app/employee/assigned_consultations_page.dart';
import 'package:business_managment_app/shared/chat_page.dart';
import 'package:business_managment_app/shared/task_board_page.dart';
import 'package:business_managment_app/shared/project_page.dart';
import 'package:business_managment_app/shared/invoice_page.dart';

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
  List<ClientModel> _myAllocatedClients = [];

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
      String? myEmployeeId;
      for (final e in _store.employees) {
        if (e.id == userId || e.userId == userId || e.email.toLowerCase() == _userEmail.toLowerCase()) {
          _userDept = e.department;
          myEmployeeId = e.id;
          break;
        }
      }

      // 1. Fetch My Live Assigned Tasks
      List<Map<String, dynamic>> tasksData = [];
      try {
        var query = SupabaseService().client.from('tasks').select();
        if (myEmployeeId != null && myEmployeeId.isNotEmpty && myEmployeeId != userId) {
          query = query.or('assigned_to.eq.$userId,assigned_to.eq.$myEmployeeId');
        } else {
          query = query.eq('assigned_to', userId);
        }
        final res = await query.order('due_date', ascending: true);
        tasksData = List<Map<String, dynamic>>.from(res as List);
      } catch (e) {
        debugPrint('Error fetching tasks for employee: $e');
      }

      if (tasksData.isEmpty && _store.tasks.isNotEmpty) {
        final myTasks = _store.tasks.where((t) {
          final aid = t.assignedToId.trim();
          final aname = t.assignedToName.toLowerCase().trim();
          final myName = _userName.toLowerCase().trim();
          return (aid.isNotEmpty && (aid == userId || (myEmployeeId != null && aid == myEmployeeId))) ||
              (aname.isNotEmpty && (aname == myName || (_userName.isNotEmpty && aname.contains(myName))));
        }).toList();

        tasksData = myTasks.map((t) => {
          'id': t.id,
          'title': t.title,
          'project_id': t.projectId,
          'project_name': t.projectName,
          'assigned_to': t.assignedToId,
          'assigned_to_name': t.assignedToName,
          'status': t.status,
          'priority': t.priority,
          'due_date': t.dueDate,
        }).toList();
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

      // 4. Fetch My Allocated Clients & Accounts
      List<ClientModel> allocatedClients = [];
      try {
        await _store.refreshFromSupabase();
        allocatedClients = _store.clients.where((c) {
          final aid = c.assignedEmployeeId;
          return aid != null &&
              aid.isNotEmpty &&
              (aid == userId || (myEmployeeId != null && aid == myEmployeeId));
        }).toList();
      } catch (e) {
        debugPrint('Error fetching allocated clients for employee: $e');
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
          _myAllocatedClients = allocatedClients;
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
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kPremiumBorder)),
              title: const Text('Request Time Off / Leave', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: typeCtrl.text,
                      isExpanded: true,
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
                        DropdownMenuItem(value: 'Vacation', child: Text('Vacation Leave', style: TextStyle(color: kPremiumText), overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Sick', child: Text('Sick Leave', style: TextStyle(color: kPremiumText), overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Casual', child: Text('Casual Leave', style: TextStyle(color: kPremiumText), overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Personal', child: Text('Personal Leave', style: TextStyle(color: kPremiumText), overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Maternity/Paternity', child: Text('Maternity / Paternity', style: TextStyle(color: kPremiumText), overflow: TextOverflow.ellipsis, maxLines: 1)),
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
                          if (user == null) return;
                          setModalState(() => isSaving = true);
                          try {
                            final sStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
                            final eStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

                            final newReq = LeaveRequest(
                              id: 'lv_${DateTime.now().millisecondsSinceEpoch}',
                              employeeId: user.id,
                              employeeName: user.userMetadata?['full_name']?.toString() ?? 'Staff Member',
                              type: typeCtrl.text,
                              startDate: sStr,
                              endDate: eStr,
                              reason: reasonCtrl.text.trim().isEmpty ? 'General leave request' : reasonCtrl.text.trim(),
                            );

                            final success = await _store.addLeaveRequest(newReq);

                            if (mounted) {
                              Navigator.pop(dialogContext);
                              _fetchEmployeeData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? 'Leave request submitted successfully!' : 'Leave request recorded locally.'),
                                  backgroundColor: success ? Colors.green : Colors.orange,
                                ),
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
              final width = constraints.maxWidth;
              final bool isDesktop = width >= 900;
              final bool isTablet = width >= 600 && width < 900;
              final double hPad = isDesktop ? 40 : (isTablet ? 24 : 16);

              return RefreshIndicator(
                color: kPremiumGold,
                onRefresh: _fetchEmployeeData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // -- HERO BANNER (SAME AS ADMIN) ------------------------------
                          HeroBanner(
                            title: '$_userDept Operations',
                            subtitle: 'Welcome back \u{1F44B}, $_userName',
                            badge: 'Employee Portal',
                          ),

                          const SizedBox(height: 20),

                          // -- OVERVIEW BANNER CARD (SAME AS ADMIN) ---------------------
                          GlassCard(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Unified Operations Overview',
                                        style: TextStyle(color: kPremiumMuted, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: kPremiumGold.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        '$_userRole',
                                        style: const TextStyle(color: kPremiumGold, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _userName,
                                  style: const TextStyle(
                                    color: kPremiumText,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),

                                // Responsive Overview Stats Layout
                                LayoutBuilder(
                                  builder: (context, overviewConstraints) {
                                    final bool isCompact = overviewConstraints.maxWidth < 520;
                                    if (isCompact) {
                                      return Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(child: _overviewItem('Active Tasks', '$_activeTasksCount')),
                                              Expanded(child: _overviewItem('Due Today', '$_tasksDueTodayCount')),
                                              Expanded(child: _overviewItem('My Projects', '$_activeProjectsCount')),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            children: [
                                              Expanded(child: _overviewItem('Allocated Clients', '${_myAllocatedClients.length}')),
                                              Expanded(child: _overviewItem('Pending Leave', '$_pendingLeavesCount')),
                                            ],
                                          ),
                                        ],
                                      );
                                    }
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('Active Tasks', '$_activeTasksCount'))),
                                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('Due Today', '$_tasksDueTodayCount'))),
                                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('My Projects', '$_activeProjectsCount'))),
                                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('Allocated Clients', '${_myAllocatedClients.length}'))),
                                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('Pending Leave', '$_pendingLeavesCount'))),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // -- OPERATIONS MODULES (SAME AS ADMIN ACTION CARDS) ----------
                          const Text(
                            'Staff Operations Modules',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 14),

                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : (width < 360 ? 1 : 2)),
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: isDesktop ? 1.4 : (isTablet ? 1.3 : 1.15),
                            children: [
                              _actionCard(
                                icon: Icons.assignment_outlined,
                                title: 'My Tasks',
                                subtitle: '$_activeTasksCount Active Tasks',
                                color: kPremiumGold,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const TaskBoardPage()),
                                  );
                                },
                              ),
                              _actionCard(
                                icon: Icons.view_kanban_outlined,
                                title: 'Task Kanban',
                                subtitle: 'Agile Task Board',
                                color: Colors.deepOrangeAccent,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const TaskBoardPage()),
                                  );
                                },
                              ),
                              _actionCard(
                                icon: Icons.folder_open_outlined,
                                title: 'My Projects',
                                subtitle: '$_activeProjectsCount Projects',
                                color: kPremiumBlue,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ProjectPage()),
                                  );
                                },
                              ),
                              _actionCard(
                                icon: Icons.business_center_outlined,
                                title: 'My Clients',
                                subtitle: '${_myAllocatedClients.length} Allocated Accounts',
                                color: Colors.tealAccent,
                                onTap: () {
                                  if (_myAllocatedClients.isNotEmpty) {
                                    _showClientDetails(_myAllocatedClients.first);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No allocated client accounts currently assigned to you.')),
                                    );
                                  }
                                },
                              ),
                              _actionCard(
                                icon: Icons.event_note_outlined,
                                title: 'Attendance & Leave',
                                subtitle: '$_pendingLeavesCount Pending Requests',
                                color: kPremiumTeal,
                                onTap: _showRequestLeaveDialog,
                              ),
                              _actionCard(
                                icon: Icons.assignment_ind_outlined,
                                title: 'Consultations',
                                subtitle: 'Assigned Requests',
                                color: Colors.purpleAccent,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const AssignedConsultationsPage()),
                                  );
                                },
                              ),
                              _actionCard(
                                icon: Icons.chat_bubble_outline,
                                title: 'Live Chat',
                                subtitle: 'Team & Client Channels',
                                color: Colors.cyanAccent,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ChatPage()),
                                  );
                                },
                              ),
                              _actionCard(
                                icon: Icons.receipt_long_outlined,
                                title: 'Invoices & Billing',
                                subtitle: 'Client Invoices & Slips',
                                color: Colors.purple,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const InvoicePage()),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

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

                          // SECTION 3: MY ALLOCATED CLIENTS & ACCOUNTS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  const Text('My Allocated Clients', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPremiumGold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.teal.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      '${_myAllocatedClients.length}',
                                      style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              Text('${_myAllocatedClients.length} Accounts', style: const TextStyle(color: kPremiumMuted, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (_myAllocatedClients.isEmpty)
                            GlassCard(
                              padding: const EdgeInsets.all(24),
                              child: const Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.business_center_outlined, size: 36, color: Colors.teal),
                                    SizedBox(height: 8),
                                    Text('No client accounts currently allocated to you.', style: TextStyle(color: kPremiumMuted, fontSize: 14)),
                                    SizedBox(height: 4),
                                    Text('When an administrator assigns client leads to you, they will appear here.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _myAllocatedClients.length,
                              itemBuilder: (context, index) {
                                final client = _myAllocatedClients[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: GlassCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: Colors.teal.withOpacity(0.2),
                                              child: Text(
                                                client.name.isNotEmpty ? client.name[0].toUpperCase() : 'C',
                                                style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    client.name,
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPremiumText),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    client.company,
                                                    style: const TextStyle(color: kPremiumMuted, fontSize: 13),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (client.status == 'Active' ? Colors.green : Colors.orange).withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: (client.status == 'Active' ? Colors.green : Colors.orange).withOpacity(0.4)),
                                              ),
                                              child: Text(
                                                client.status,
                                                style: TextStyle(
                                                  color: client.status == 'Active' ? Colors.greenAccent : Colors.orangeAccent,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 20, color: Colors.white10),
                                        Row(
                                          children: [
                                            if (client.email.isNotEmpty) ...[
                                              const Icon(Icons.email_outlined, size: 14, color: kPremiumMuted),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  client.email,
                                                  style: const TextStyle(color: kPremiumMuted, fontSize: 12),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                            if (client.phone.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              const Icon(Icons.phone_outlined, size: 14, color: kPremiumMuted),
                                              const SizedBox(width: 4),
                                              Text(
                                                client.phone,
                                                style: const TextStyle(color: kPremiumMuted, fontSize: 12),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Colors.teal),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.tealAccent),
                                              label: const Text('Message Client', style: TextStyle(color: Colors.tealAccent, fontSize: 12)),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChatPage(
                                                      initialTargetId: client.id,
                                                      initialTargetName: client.name,
                                                      initialTargetSubtitle: client.company,
                                                      initialTargetType: 'client',
                                                      initialTargetEmail: client.email,
                                                      initialTargetPhone: client.phone,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: kPremiumGold,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              ),
                                              icon: const Icon(Icons.info_outline, size: 16),
                                              label: const Text('Account Details', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _showClientDetails(client),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 32),

                          // SECTION 4: MY ATTENDANCE & LEAVE REQUESTS
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
                                                '$sDate  \u2192  $eDate ${reason.isNotEmpty ? "($reason)" : ""}',
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

  Widget _overviewItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: kPremiumGold,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: kPremiumMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: kPremiumText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: kPremiumMuted,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showClientDetails(ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kPremiumSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: kPremiumBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.business_center_outlined, color: Colors.tealAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                client.name,
                style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _clientDetailRow('Company', client.company),
            _clientDetailRow('Status', client.status),
            _clientDetailRow('Email', client.email),
            _clientDetailRow('Phone', client.phone.isNotEmpty ? client.phone : 'Not provided'),
            _clientDetailRow('Project Type', client.projectType),
            if (client.budget > 0)
              _clientDetailRow('Allocated Budget', '₹${client.budget.toStringAsFixed(0)}'),
            if (client.adminNote.isNotEmpty)
              _clientDetailRow('Admin Note', client.adminNote),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: kPremiumMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.chat, size: 16),
            label: const Text('Open Chat'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                    initialTargetId: client.id,
                    initialTargetName: client.name,
                    initialTargetSubtitle: client.company,
                    initialTargetType: 'client',
                    initialTargetEmail: client.email,
                    initialTargetPhone: client.phone,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _clientDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: kPremiumMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
