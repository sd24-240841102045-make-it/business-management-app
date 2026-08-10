import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/core/premium_theme.dart';

/// Body-only Dashboard widget — Scaffold lives in MainShell.
class HomeBody extends StatefulWidget {
  final void Function(int index) onNavigate;
  const HomeBody({super.key, required this.onNavigate});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  final AppDataStore _store = AppDataStore();

  int? _totalClients;
  int? _activeEmployees;
  int? _staffOnLeave;
  int? _pendingLeaves;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final client = SupabaseService().client;
    var orgId = SupabaseService().currentOrganizationId;
    if (orgId == null) {
      await SupabaseService().loadUserOrganizationContext();
      orgId = SupabaseService().currentOrganizationId;
    }
    if (orgId == null) {
      if (mounted) {
        setState(() {
          _totalClients = _store.clients.length;
          _activeEmployees = _store.employees.where((e) => e.status == 'Active').length;
          _staffOnLeave = _store.employees.where((e) => e.status == 'On Leave').length;
          _pendingLeaves = _store.leaveRequests.where((r) => r.status == 'Pending').length;
          _isLoadingStats = false;
        });
      }
      return;
    }

    try {
      final clientsData = await client.from('clients').select('id, email').eq('organization_id', orgId);
      final clientInvitesData = await client.from('invitations').select('email').eq('organization_id', orgId).eq('role', 'client');
      final activeEmpData = await client.from('employees').select('id').eq('organization_id', orgId).eq('status', 'Active');
      final leaveEmpData = await client.from('employees').select('id').eq('organization_id', orgId).eq('status', 'On Leave');
      final leavesData = await client.from('leave_requests').select('id').eq('organization_id', orgId).eq('status', 'Pending');
      
      final uniqueClientKeys = <String>{};
      if (clientsData is List) {
        for (final item in clientsData) {
          final email = item['email']?.toString().trim().toLowerCase();
          final id = item['id']?.toString();
          final key = (email != null && email.isNotEmpty) ? email : id;
          if (key != null) uniqueClientKeys.add(key);
        }
      }
      if (clientInvitesData is List) {
        for (final item in clientInvitesData) {
          final email = item['email']?.toString().trim().toLowerCase();
          if (email != null && email.isNotEmpty) uniqueClientKeys.add(email);
        }
      }

      if (mounted) {
        setState(() {
          final dbCount = uniqueClientKeys.length;
          final storeCount = _store.clients.length;
          _totalClients = dbCount > storeCount ? dbCount : storeCount;
          _activeEmployees = (activeEmpData as List).length;
          _staffOnLeave = (leaveEmpData as List).length;
          _pendingLeaves = (leavesData as List).length;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      if (mounted) {
        setState(() {
          _totalClients = _store.clients.length;
          _activeEmployees = _store.employees.where((e) => e.status == 'Active').length;
          _staffOnLeave = _store.employees.where((e) => e.status == 'On Leave').length;
          _pendingLeaves = _store.leaveRequests.where((r) => r.status == 'Pending').length;
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) {
      setState(() {
        _totalClients = _store.clients.length;
        _activeEmployees = _store.employees.where((e) => e.status == 'Active').length;
        _staffOnLeave = _store.employees.where((e) => e.status == 'On Leave').length;
        _pendingLeaves = _store.leaveRequests.where((r) => r.status == 'Pending').length;
        _isLoadingStats = false;
      });
    }
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bool isDesktop = width >= 900;
        final bool isTablet = width >= 600 && width < 900;
        final double hPad = isDesktop ? 40 : isTablet ? 28 : 16;

        return RefreshIndicator(
          onRefresh: () async {
            await _store.refreshFromSupabase();
            await _fetchStats();
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
                      const LinearProgressIndicator(color: kPremiumGold),
                      const SizedBox(height: 10),
                    ],
              HeroBanner(
                title: _getBusinessName(),
                subtitle: _getGreeting(),
                badge: 'Enterprise Dashboard',
              ),

              const SizedBox(height: 20),

              // ── Overview Banner ───────────────────────────
              GlassCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Unified Platform Overview',
                          style: TextStyle(color: kPremiumMuted, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kPremiumGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'Live Metrics',
                            style: TextStyle(color: kPremiumGold, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      SupabaseService().currentOrganization?['name'] ?? 'Your Organization',
                      style: const TextStyle(
                        color: kPremiumText,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('Clients', _isLoadingStats ? '-' : '${_totalClients ?? 0}'))),
                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('Active HR', _isLoadingStats ? '-' : '${_activeEmployees ?? 0}'))),
                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('On Leave', _isLoadingStats ? '-' : '${_staffOnLeave ?? 0}'))),
                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('Pending', _isLoadingStats ? '-' : '${_pendingLeaves ?? 0}'))),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Management Modules ────────────────────────
              const Text(
                'Management Modules',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 3 : isTablet ? 3 : (width < 360 ? 1 : 2),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: isDesktop ? 1.6 : isTablet ? 1.4 : 1.15,
                children: [
                  _actionCard(
                    icon: Icons.badge_outlined,
                    title: 'Employees (HR)',
                    subtitle: '${_store.employees.length} Members',
                    color: kPremiumGold,
                    onTap: () => widget.onNavigate(1),
                  ),
                  _actionCard(
                    icon: Icons.people_outline,
                    title: 'Clients (CRM)',
                    subtitle: _isLoadingStats ? '...' : '${_totalClients ?? 0} Accounts',
                    color: kPremiumBlue,
                    onTap: () => widget.onNavigate(2),
                  ),
                  _actionCard(
                    icon: Icons.calendar_month_outlined,
                    title: 'Attendance & Leave',
                    subtitle: _isLoadingStats ? '...' : '${_pendingLeaves ?? 0} Pending',
                    color: kPremiumTeal,
                    onTap: () => widget.onNavigate(3),
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
                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        PremiumAvatar(
                          icon: client.status == 'Active' ? Icons.business_rounded : Icons.business_center_outlined,
                          style: AvatarStyle.glowIcon,
                          size: 44,
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
                                  color: kPremiumMuted,
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
                            color: kPremiumGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                          ),
                          child: Text(
                            client.assignedEmployeeName ?? 'Unassigned',
                            style: const TextStyle(
                              color: kPremiumGold,
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
            color: kPremiumGold,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: kPremiumMuted, fontSize: 12),
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
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.16),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: kPremiumMuted, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showReportsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassCard(
          margin: const EdgeInsets.all(16),
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPremiumGold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: kPremiumMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const PremiumAvatar(
                  icon: Icons.assessment_rounded,
                  style: AvatarStyle.glowIcon,
                  size: 42,
                ),
                title: const Text('Client Account Distribution'),
                subtitle: Text('${_store.clients.length} Total Accounts', style: const TextStyle(color: kPremiumMuted)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const PremiumAvatar(
                  icon: Icons.pie_chart_rounded,
                  style: AvatarStyle.glowIcon,
                  size: 42,
                ),
                title: const Text('HR Workforce Utilization'),
                subtitle: Text('${_store.employees.length} Total Staff', style: const TextStyle(color: kPremiumMuted)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const PremiumAvatar(
                  icon: Icons.bar_chart_rounded,
                  style: AvatarStyle.glowIcon,
                  size: 42,
                ),
                title: const Text('Monthly Attendance Summary'),
                subtitle: Text(
                  '${_store.leaveRequests.length} Leave Records',
                  style: const TextStyle(color: kPremiumMuted),
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
