import 'package:flutter/material.dart';
import 'services/app_data_store.dart';
import 'services/supabase_service.dart';

/// Body-only Dashboard widget — Scaffold lives in MainShell.
class HomeBody extends StatefulWidget {
  final void Function(int index) onNavigate;
  const HomeBody({super.key, required this.onNavigate});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  final AppDataStore _store = AppDataStore();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) setState(() {});
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    String greeting = 'Good Day';
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    final user = SupabaseService().currentUser;
    final name = user?.userMetadata?['full_name'] as String? ?? 'User';
    final firstName = name.split(' ').first;
    return '$greeting 👋, $firstName';
  }

  String _getBusinessName() {
    final user = SupabaseService().currentUser;
    return user?.userMetadata?['business_name'] as String? ?? 'CRM & HR Operations';
  }

  @override
  Widget build(BuildContext context) {
    final totalClients = _store.clients.length;
    final activeEmployees =
        _store.employees.where((e) => e.status == 'Active').length;
    final staffOnLeave =
        _store.employees.where((e) => e.status == 'On Leave').length;
    final pendingLeaves =
        _store.leaveRequests.where((r) => r.status == 'Pending').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bool isDesktop = width >= 900;
        final bool isTablet = width >= 600 && width < 900;
        final double hPad = isDesktop ? 40 : isTablet ? 28 : 16;

        return RefreshIndicator(
          onRefresh: () async {
            await _store.refreshFromSupabase();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_store.isLoadingFromSupabase) ...[
                      const LinearProgressIndicator(color: Colors.deepPurple),
                      const SizedBox(height: 10),
                    ],
              // ── Welcome ───────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFC084FC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          _getBusinessName(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.0,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Overview Banner ───────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF8E7CFF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unified Platform Overview',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Project Life Solutions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _overviewItem('Clients', '$totalClients'),
                        _overviewItem('Active HR', '$activeEmployees'),
                        _overviewItem('On Leave', '$staffOnLeave'),
                        _overviewItem('Pending', '$pendingLeaves'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Management Modules ────────────────────────
              const Text(
                'Management Modules',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              isDesktop
                  ? Row(
                      children: [
                        Expanded(
                          child: _actionCard(
                            icon: Icons.people,
                            title: 'Clients (CRM)',
                            subtitle: '$totalClients Accounts',
                            color: Colors.blue,
                            onTap: () => widget.onNavigate(1),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _actionCard(
                            icon: Icons.badge,
                            title: 'Employees (HR)',
                            subtitle: '${_store.employees.length} Members',
                            color: Colors.orange,
                            onTap: () => widget.onNavigate(2),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _actionCard(
                            icon: Icons.calendar_month,
                            title: 'Attendance & Leave',
                            subtitle: '$pendingLeaves Pending',
                            color: Colors.green,
                            onTap: () => widget.onNavigate(3),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _actionCard(
                            icon: Icons.bar_chart,
                            title: 'Reports & Stats',
                            subtitle: 'Business Analytics',
                            color: Colors.purple,
                            onTap: () => _showReportsBottomSheet(context),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _actionCard(
                                icon: Icons.people,
                                title: 'Clients (CRM)',
                                subtitle: '$totalClients Accounts',
                                color: Colors.blue,
                                onTap: () => widget.onNavigate(1),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _actionCard(
                                icon: Icons.badge,
                                title: 'Employees (HR)',
                                subtitle:
                                    '${_store.employees.length} Members',
                                color: Colors.orange,
                                onTap: () => widget.onNavigate(2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _actionCard(
                                icon: Icons.calendar_month,
                                title: 'Attendance & Leave',
                                subtitle: '$pendingLeaves Pending',
                                color: Colors.green,
                                onTap: () => widget.onNavigate(3),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _actionCard(
                                icon: Icons.bar_chart,
                                title: 'Reports & Stats',
                                subtitle: 'Business Analytics',
                                color: Colors.purple,
                                onTap: () => _showReportsBottomSheet(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

              const SizedBox(height: 30),

              // ── Recent Clients ────────────────────────────
              const Text(
                'Recent Client Account Leads',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _store.clients.length,
                itemBuilder: (context, index) {
                  final client = _store.clients[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.deepPurple.shade50,
                          child: Icon(
                            client.status == 'Active'
                                ? Icons.business
                                : Icons.business_center_outlined,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                client.company,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Contact: ${client.name} • ${client.projectType}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            client.assignedEmployeeName ?? 'Unassigned',
                            style: const TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
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
);
  }

  // ── Helper widgets ──────────────────────────────────────────

  Widget _overviewItem(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Operational Reports',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.assessment, color: Colors.white),
                ),
                title: const Text('Client Account Distribution'),
                subtitle: Text('${_store.clients.length} Total Accounts'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orangeAccent,
                  child: Icon(Icons.pie_chart, color: Colors.white),
                ),
                title: const Text('HR Workforce Utilization'),
                subtitle: Text('${_store.employees.length} Total Staff'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.bar_chart, color: Colors.white),
                ),
                title: const Text('Monthly Attendance Summary'),
                subtitle: Text(
                  '${_store.leaveRequests.length} Leave Records',
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}







