import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/shared/login_page.dart';
import 'package:business_managment_app/shared/settings_page.dart';
import 'package:business_managment_app/shared/chat_page.dart';
import 'package:business_managment_app/client/client_dashboard_page.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _selectedIndex = 0;
  final AppDataStore _store = AppDataStore();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
    _store.refreshFromSupabase();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) setState(() {});
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of Client Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService().signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userEmail = user?.email ?? 'User Email Not Found';
    final metaName = user?.userMetadata?['full_name']?.toString() ?? '';
    final metaCompany = user?.userMetadata?['company']?.toString() ?? '';

    // Search matching client in store
    ClientModel? matchingClient;
    for (final c in _store.clients) {
      if (c.id == user?.id || c.email.toLowerCase() == userEmail.toLowerCase()) {
        matchingClient = c;
        break;
      }
    }

    final userName = matchingClient?.name ??
        (metaName.isNotEmpty ? metaName : (userEmail.contains('@') ? userEmail.split('@')[0] : 'Client User'));
    final userCompany = matchingClient?.company ??
        (metaCompany.isNotEmpty ? metaCompany : 'Registered Partner Enterprise');

    final pages = [
      const ClientDashboardPage(),
      ClientManagerBody(userEmail: userEmail, store: _store),
      const ChatPage(),
      ClientProfileBody(name: userName, email: userEmail, company: userCompany, store: _store, onLogout: _logout),
    ];

    final titles = [
      'Client Dashboard',
      'Account Manager',
      'Live Chat Support',
      'Client Profile',
    ];

    return PremiumBackground(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWideScreen = constraints.maxWidth >= 700;

          return Scaffold(
            backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              titles[_selectedIndex],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Live Support Chat',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatPage()),
                  );
                },
              ),
            ],
          ),
          body: isWideScreen
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _onItemTapped,
                      labelType: NavigationRailLabelType.all,
                      backgroundColor: kPremiumBg2,
                      selectedIconTheme: const IconThemeData(color: kPremiumGold, size: 28),
                      selectedLabelTextStyle: const TextStyle(
                        color: kPremiumGold,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedIconTheme: const IconThemeData(color: kPremiumMuted),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('Overview'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.support_agent_outlined),
                          selectedIcon: Icon(Icons.support_agent),
                          label: Text('Account Manager'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.chat_bubble_outline),
                          selectedIcon: Icon(Icons.chat_bubble),
                          label: Text('Support Chat'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person),
                          label: Text('Profile'),
                        ),
                      ],
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: pages,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: pages,
                    ),
                  ),
                ),
          bottomNavigationBar: isWideScreen
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.support_agent_outlined),
                      selectedIcon: Icon(Icons.support_agent),
                      label: 'Account Manager',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline),
                      selectedIcon: Icon(Icons.chat_bubble),
                      label: 'Support Chat',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                  ],
                ),
          );
        },
      ),
    );
  }
}

class ClientOverviewBody extends StatelessWidget {
  final String name;
  final String email;
  final String company;
  final AppDataStore store;

  const ClientOverviewBody({
    super.key,
    required this.name,
    required this.email,
    required this.company,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamically check matching client from AppDataStore
    ClientModel? matchedClient;
    for (final c in store.clients) {
      if (c.email.toLowerCase() == email.toLowerCase() ||
          c.name.toLowerCase() == name.toLowerCase() ||
          c.company.toLowerCase() == company.toLowerCase()) {
        matchedClient = c;
        break;
      }
    }

    final projectType = matchedClient?.projectType ?? 'Enterprise Consulting';
    final budget = matchedClient?.budget ?? 12500.0;
    final status = matchedClient?.status ?? 'Active';
    final assignedManager = matchedClient?.assignedEmployeeName ?? 'Senior Account Manager';

    return RefreshIndicator(
      onRefresh: () async {
        await store.refreshFromSupabase();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 550;
          final padding = isMobile ? 12.0 : 20.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: padding,
              right: padding,
              top: padding,
              bottom: MediaQuery.of(context).padding.bottom + 80.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Welcome Header Card
                GlassCard(
                  padding: EdgeInsets.all(isMobile ? 16 : 22),
                  child: Row(
                    children: [
                      PremiumAvatar(
                        label: name,
                        style: AvatarStyle.gradient,
                        size: isMobile ? 52 : 64,
                        radius: isMobile ? 26 : 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, $name!',
                              style: TextStyle(
                                color: kPremiumText,
                                fontSize: isMobile ? 16 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              matchedClient?.company ?? company,
                              style: const TextStyle(
                                color: kPremiumMuted,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'Active' ? kPremiumSuccess.withOpacity(0.15) : kPremiumWarning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: status == 'Active' ? kPremiumSuccess.withOpacity(0.4) : kPremiumWarning.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: status == 'Active' ? kPremiumSuccess : kPremiumWarning,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Admin Announcement Banner if configured
                if (matchedClient?.adminNote != null && matchedClient!.adminNote.isNotEmpty) ...[
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.campaign, color: kPremiumGold, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notice from Management',
                                style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                matchedClient.adminNote,
                                style: const TextStyle(fontSize: 13, color: kPremiumText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Overview Cards Title
                const Text(
                  'Project Summary & Live Metrics',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kPremiumGold),
                ),
                const SizedBox(height: 12),

                // Responsive Metrics Grid
                if (isMobile) ...[
                  _buildMetricCard(title: 'Project Scope', value: projectType, icon: Icons.assignment_turned_in_outlined, color: kPremiumBlue),
                  const SizedBox(height: 10),
                  _buildMetricCard(title: 'Allocated Budget', value: '\$${budget.toStringAsFixed(0)}', icon: Icons.account_balance_wallet_outlined, color: kPremiumSuccess),
                  const SizedBox(height: 10),
                  _buildMetricCard(title: 'Account Lead', value: assignedManager, icon: Icons.person_pin_outlined, color: kPremiumTeal),
                  const SizedBox(height: 10),
                  _buildMetricCard(title: 'Support Tier', value: 'Executive Priority', icon: Icons.star_outline, color: kPremiumGold),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard(title: 'Project Scope', value: projectType, icon: Icons.assignment_turned_in_outlined, color: kPremiumBlue)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMetricCard(title: 'Allocated Budget', value: '\$${budget.toStringAsFixed(0)}', icon: Icons.account_balance_wallet_outlined, color: kPremiumSuccess)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard(title: 'Account Lead', value: assignedManager, icon: Icons.person_pin_outlined, color: kPremiumTeal)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMetricCard(title: 'Support Tier', value: 'Executive Priority', icon: Icons.star_outline, color: kPremiumGold)),
                    ],
                  ),
                ],

                const SizedBox(height: 22),

                // Project Milestones Card
                GlassCard(
                  padding: EdgeInsets.all(isMobile ? 14 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.timeline, color: kPremiumGold),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Project Milestones & Deliverables',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kPremiumText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMilestoneTile('Requirement Gathering & Setup', 'Completed', kPremiumSuccess, true),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 10),
                      _buildMilestoneTile('Database Schema & RLS Integration', 'Completed', kPremiumSuccess, true),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 10),
                      _buildMilestoneTile('Portal Dashboard & Dynamic Sync', 'In Progress', kPremiumBlue, false),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 10),
                      _buildMilestoneTile('Final Quality Sign-off', 'Upcoming', kPremiumMuted, false),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: kPremiumMuted),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kPremiumText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneTile(String title, String status, Color color, bool isDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
                color: isDone ? kPremiumText : kPremiumMuted,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              status,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class ClientManagerBody extends StatelessWidget {
  final String userEmail;
  final AppDataStore store;

  const ClientManagerBody({super.key, required this.userEmail, required this.store});

  @override
  Widget build(BuildContext context) {
    // Find client and assigned employee
    ClientModel? matchedClient;
    for (final c in store.clients) {
      if (c.email.toLowerCase() == userEmail.toLowerCase()) {
        matchedClient = c;
        break;
      }
    }

    Employee? manager;
    if (matchedClient?.assignedEmployeeId != null) {
      for (final e in store.employees) {
        if (e.id == matchedClient!.assignedEmployeeId) {
          manager = e;
          break;
        }
      }
    }

    manager ??= store.employees.isNotEmpty
        ? store.employees.first
        : Employee(
            id: 'E101',
            name: 'Priya Sharma',
            role: 'Senior Account Manager',
            department: 'Client Relations',
            email: 'priya.s@company.com',
            phone: '+91 98765 00002',
            joiningDate: '2022-01-15',
            status: 'Active',
          );

    return RefreshIndicator(
      onRefresh: () async {
        await store.refreshFromSupabase();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            const Text('Your Dedicated Account Manager', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kPremiumGold)),
            const SizedBox(height: 14),

            // Manager Profile Card
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  PremiumAvatar(
                    label: manager.name,
                    style: AvatarStyle.gradient,
                    size: 80,
                    radius: 40,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    manager.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPremiumText),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: kPremiumGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${manager.role} • ${manager.department}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kPremiumGold, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  _managerInfoTile(Icons.email_outlined, 'Email Address', manager.email),
                  _managerInfoTile(Icons.phone_outlined, 'Direct Phone', manager.phone.isNotEmpty ? manager.phone : 'Not provided'),
                  _managerInfoTile(
                    Icons.circle,
                    'Availability Status',
                    manager.status,
                    valueColor: manager.status == 'Active' ? kPremiumSuccess : kPremiumWarning,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Support Section
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.headset_mic_outlined, color: kPremiumGold),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Need Support or Advice?',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kPremiumText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Our dedicated team is ready to assist you with active milestones, change requests, or consultation.',
                    style: TextStyle(color: kPremiumMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  GoldButton(
                    label: 'Request Account Consultation',
                    icon: Icons.support_agent,
                    expand: true,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Support request sent to your account manager!'),
                          backgroundColor: kPremiumSuccess,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _managerInfoTile(IconData icon, String title, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          PremiumAvatar(
            icon: icon,
            style: AvatarStyle.glowIcon,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: kPremiumMuted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: valueColor ?? kPremiumText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ClientProfileBody extends StatelessWidget {
  final String name;
  final String email;
  final String company;
  final AppDataStore store;
  final VoidCallback onLogout;

  const ClientProfileBody({
    super.key,
    required this.name,
    required this.email,
    required this.company,
    required this.store,
    required this.onLogout,
  });

  void _editClientProfileDialog(BuildContext context, User? user) {
    final nameCtrl = TextEditingController(text: name);
    final companyCtrl = TextEditingController(text: company);
    final phoneCtrl = TextEditingController(text: user?.userMetadata?['phone'] ?? '+91 98765 43210');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Client Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Contact Name', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: companyCtrl,
                decoration: const InputDecoration(labelText: 'Company / Organization', prefixIcon: Icon(Icons.business)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newComp = companyCtrl.text.trim();
              final newPhone = phoneCtrl.text.trim();

              if (newName.isNotEmpty && user != null) {
                // Update Supabase Auth metadata
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(
                      data: {
                        'full_name': newName,
                        'company': newComp,
                        'phone': newPhone,
                      },
                    ),
                  );
                } catch (e) {
                  debugPrint('Error updating user metadata: $e');
                }

                // Update Client record in AppDataStore & Supabase DB
                ClientModel? clientToUpdate;
                for (final c in store.clients) {
                  if (c.email.toLowerCase() == email.toLowerCase() || c.id == user.id) {
                    clientToUpdate = c;
                    break;
                  }
                }

                if (clientToUpdate != null) {
                  final updatedClient = clientToUpdate.copyWith(
                    name: newName,
                    company: newComp,
                    phone: newPhone,
                  );
                  store.updateClient(updatedClient);
                } else {
                  final newClient = ClientModel(
                    id: user.id,
                    name: newName,
                    company: newComp,
                    email: email,
                    phone: newPhone,
                    status: 'Active',
                  );
                  store.addClient(newClient);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Client profile updated in Supabase!'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return RefreshIndicator(
      color: kPremiumGold,
      onRefresh: () async {
        await store.refreshFromSupabase();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Column(
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      PremiumAvatar(
                        label: name,
                        style: AvatarStyle.gradient,
                        size: 72,
                        radius: 36,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPremiumGold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: kPremiumGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'Client Partner Account',
                          style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: kPremiumGold, foregroundColor: kPremiumBg),
                        onPressed: () => _editClientProfileDialog(context, user),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Profile Details', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 10),
                      ListTile(
                        leading: const Icon(Icons.business_outlined, color: kPremiumGold),
                        title: const Text('Company / Organization', style: TextStyle(color: kPremiumMuted, fontSize: 12)),
                        subtitle: Text(company, style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.email_outlined, color: kPremiumGold),
                        title: const Text('Email Address', style: TextStyle(color: kPremiumMuted, fontSize: 12)),
                        subtitle: Text(email, style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined, color: kPremiumGold),
                        title: const Text('Authentication Source', style: TextStyle(color: kPremiumMuted, fontSize: 12)),
                        subtitle: const Text('Supabase Auth (Role: Client)', style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // PORTAL PREFERENCES & ACTIONS CARD
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Portal Actions & Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPremiumGold)),
                      const SizedBox(height: 12),

                      // Settings Tile
                      ListTile(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.settings_outlined, color: Colors.blueAccent, size: 20),
                        ),
                        title: const Text('Account & App Settings', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                        subtitle: const Text('Configure portal themes, notifications, and security', style: TextStyle(color: kPremiumMuted, fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios, color: kPremiumMuted, size: 14),
                      ),
                      const Divider(color: Colors.white10),

                      // Refresh Data Tile
                      ListTile(
                        onTap: () async {
                          await store.refreshFromSupabase();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Client portal data refreshed from Supabase!'), backgroundColor: Colors.green),
                            );
                          }
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.refresh_outlined, color: Colors.tealAccent, size: 20),
                        ),
                        title: const Text('Sync Portal Data', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                        subtitle: const Text('Fetch latest active projects and workspace updates', style: TextStyle(color: kPremiumMuted, fontSize: 12)),
                        trailing: const Icon(Icons.cloud_sync_outlined, color: kPremiumMuted, size: 16),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // SIGN OUT BUTTON
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
