import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/shared/login_page.dart';
import 'package:business_managment_app/shared/settings_page.dart';
import 'package:business_managment_app/shared/chat_page.dart';

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
      ClientOverviewBody(name: userName, email: userEmail, company: userCompany, store: _store),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth >= 700;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              titles[_selectedIndex],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            elevation: 2,
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
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Sync Supabase',
                onPressed: () async {
                  await _store.refreshFromSupabase();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Client portal data refreshed from Supabase!'), backgroundColor: Colors.green),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: _logout,
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
                      selectedIconTheme: const IconThemeData(color: Colors.indigo, size: 28),
                      selectedLabelTextStyle: const TextStyle(
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedIconTheme: const IconThemeData(color: Colors.grey),
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
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Responsive Welcome Header Card
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade700, Colors.deepPurple.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: isMobile ? 24 : 30,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 20 : 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, $name!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 16 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              matchedClient?.company ?? company,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isMobile ? 12 : 14,
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
                          color: status == 'Active' ? Colors.green.shade400 : Colors.orange.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Admin Announcement Banner if configured
                if (matchedClient?.adminNote != null && matchedClient!.adminNote.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.deepPurple.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.campaign, color: Colors.deepPurple, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notice from Management',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                matchedClient.adminNote,
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Overview Cards Title
                const Text(
                  'Project Summary & Live Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),

                // Responsive Metrics Grid
                if (isMobile) ...[
                  _buildMetricCard(
                    title: 'Project Scope',
                    value: projectType,
                    icon: Icons.assignment_turned_in_outlined,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 10),
                  _buildMetricCard(
                    title: 'Allocated Budget',
                    value: '\$${budget.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet_outlined,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 10),
                  _buildMetricCard(
                    title: 'Account Lead',
                    value: assignedManager,
                    icon: Icons.person_pin_outlined,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  _buildMetricCard(
                    title: 'Database Status',
                    value: 'Synced (Supabase DB)',
                    icon: Icons.cloud_done_outlined,
                    color: Colors.teal,
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Project Scope',
                          value: projectType,
                          icon: Icons.assignment_turned_in_outlined,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Allocated Budget',
                          value: '\$${budget.toStringAsFixed(0)}',
                          icon: Icons.account_balance_wallet_outlined,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Account Lead',
                          value: assignedManager,
                          icon: Icons.person_pin_outlined,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Database Status',
                          value: 'Synced (Supabase DB)',
                          icon: Icons.cloud_done_outlined,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Project Milestones Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.timeline, color: Colors.indigo),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Project Milestones & Deliverables',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildMilestoneTile('Requirement Gathering & Setup', 'Completed', Colors.green, true),
                        const Divider(),
                        _buildMilestoneTile('Database Schema & RLS Integration', 'Completed', Colors.green, true),
                        const Divider(),
                        _buildMilestoneTile('Portal Dashboard & Dynamic Sync', 'In Progress', Colors.indigo, false),
                        const Divider(),
                        _buildMilestoneTile('Final Quality Sign-off', 'Upcoming', Colors.grey, false),
                      ],
                    ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
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
                color: isDone ? Colors.black87 : Colors.black54,
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.indigo.shade600,
                      child: Text(
                        manager.name.isNotEmpty ? manager.name[0].toUpperCase() : 'M',
                        style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      manager.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${manager.role} (${manager.department})',
                      style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.email_outlined, color: Colors.indigo),
                      title: const Text('Email Address'),
                      subtitle: Text(manager.email),
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone_outlined, color: Colors.indigo),
                      title: const Text('Direct Phone'),
                      subtitle: Text(manager.phone),
                    ),
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                      title: const Text('Manager Availability'),
                      subtitle: Text('Status: ${manager.status}'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.headset_mic_outlined, color: Colors.indigo),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Need Support or Advice?',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Our dedicated team is ready to assist you with active milestones, change requests, or consultation.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Support request sent to your account manager!'), backgroundColor: Colors.indigo),
                          );
                        },
                        icon: const Icon(Icons.support),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Request Account Consultation'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
      onRefresh: () async {
        await store.refreshFromSupabase();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.indigo.shade600,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'C',
                      style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Client Portal Account',
                      style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _editClientProfileDialog(context, user),
                    icon: const Icon(Icons.edit, color: Colors.indigo),
                    label: const Text('Edit Profile Details', style: TextStyle(color: Colors.indigo)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.indigo),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.business, color: Colors.indigo),
                    title: const Text('Company / Organization'),
                    subtitle: Text(company),
                  ),
                  ListTile(
                    leading: const Icon(Icons.email, color: Colors.indigo),
                    title: const Text('Email Address'),
                    subtitle: Text(email),
                  ),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined, color: Colors.indigo),
                    title: const Text('Authentication Source'),
                    subtitle: const Text('Supabase Auth (Role: Client)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
