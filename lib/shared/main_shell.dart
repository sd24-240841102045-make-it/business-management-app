import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/admin/home_page.dart';
import 'package:business_managment_app/employee/employee_dashboard_page.dart';
import 'package:business_managment_app/admin/employees_page.dart';
import 'package:business_managment_app/admin/clients.dart';
import 'package:business_managment_app/shared/attendance_leave_page.dart';
import 'package:business_managment_app/employee/emp_profile.dart';
import 'package:business_managment_app/shared/login_page.dart';
import 'package:business_managment_app/shared/settings_page.dart';
import 'package:business_managment_app/shared/chat_page.dart';
import 'package:business_managment_app/shared/project_page.dart';
import 'package:business_managment_app/shared/task_board_page.dart';
import 'package:business_managment_app/admin/finance_page.dart';
import 'package:business_managment_app/shared/invoice_page.dart';
import 'package:business_managment_app/admin/reports_page.dart';
import 'package:business_managment_app/admin/invite_page.dart';
import 'package:business_managment_app/client/client_dashboard_page.dart';
import 'package:business_managment_app/employee/assigned_consultations_page.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final GlobalKey<EmployeesBodyState> _employeesKey = GlobalKey<EmployeesBodyState>();
  final GlobalKey<ClientsBodyState> _clientsKey = GlobalKey<ClientsBodyState>();
  final GlobalKey<AttendanceLeaveBodyState> _attendanceKey = GlobalKey<AttendanceLeaveBodyState>();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = SupabaseService().currentRole;
    final isAdmin = role == 'admin';
    final isEmployee = role == 'employee';
    final isClient = role == 'client';

    // 1. Dynamic Main Navigation
    final List<Widget> pages = [];
    final List<String> titles = [];
    final List<NavigationRailDestination> railDestinations = [];
    final List<NavigationDestination> bottomDestinations = [];

    // Dashboard
    if (isAdmin) {
      pages.add(HomeBody(onNavigate: _onItemTapped));
      titles.add('Dashboard');
    } else if (isEmployee) {
      pages.add(const EmployeeDashboardPage());
      titles.add('My Dashboard');
    } else {
      pages.add(const ClientDashboardPage());
      titles.add('Client Portal');
    }
    
    railDestinations.add(const NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Home'),
    ));
    bottomDestinations.add(const NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Home',
    ));

    // Admin Only: Employees
    if (isAdmin) {
      pages.add(EmployeesBody(key: _employeesKey, onNavigate: _onItemTapped));
      titles.add('Employees');
      railDestinations.add(const NavigationRailDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: Text('Employees'),
      ));
      bottomDestinations.add(const NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: 'Employees',
      ));
    }

    // Admin Only: Clients
    if (isAdmin) {
      pages.add(ClientsBody(key: _clientsKey));
      titles.add('Clients');
      railDestinations.add(const NavigationRailDestination(
        icon: Icon(Icons.business_center_outlined),
        selectedIcon: Icon(Icons.business_center),
        label: Text('Clients'),
      ));
      bottomDestinations.add(const NavigationDestination(
        icon: Icon(Icons.business_center_outlined),
        selectedIcon: Icon(Icons.business_center),
        label: 'Clients',
      ));
    }


    // Employee & Admin: Attendance
    if (isAdmin || isEmployee) {
      pages.add(AttendanceLeaveBody(key: _attendanceKey));
      titles.add('Attendance & Leave');
      railDestinations.add(const NavigationRailDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month),
        label: Text('Attendance'),
      ));
      bottomDestinations.add(const NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month),
        label: 'Attendance',
      ));
    }

    // All Roles: Profile
    pages.add(const ProfileBody());
    titles.add('Profile');
    railDestinations.add(const NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text('Profile'),
    ));
    bottomDestinations.add(const NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ));

    // Ensure selectedIndex doesn't crash if we switch roles and shrink the array
    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth >= 700;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              titles[_selectedIndex],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            actions: [
              Builder(
                builder: (drawerContext) => IconButton(
                  icon: const Icon(Icons.apps),
                  tooltip: 'Enterprise Drawer & Modules',
                  onPressed: () {
                    Scaffold.of(drawerContext).openEndDrawer();
                  },
                ),
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1),
                  tooltip: 'Invite Members',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const InvitePage()),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Live Chat',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatPage()),
                  );
                },
              ),
            ],
          ),
          drawer: _buildEnterpriseDrawer(context, isAdmin, isEmployee, isClient),
          endDrawer: _buildEnterpriseDrawer(context, isAdmin, isEmployee, isClient),
          body: isWideScreen
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _onItemTapped,
                      labelType: NavigationRailLabelType.all,
                      selectedIconTheme: const IconThemeData(color: kPremiumGold, size: 28),
                      selectedLabelTextStyle: const TextStyle(
                        color: kPremiumGold,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedIconTheme: const IconThemeData(color: kPremiumMuted),
                      destinations: railDestinations,
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(
                      child: SafeArea(
                        bottom: true,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.04),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey<int>(_selectedIndex),
                            child: pages[_selectedIndex],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : SafeArea(
                  bottom: true,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(_selectedIndex),
                      child: pages[_selectedIndex],
                    ),
                  ),
                ),
          bottomNavigationBar: isWideScreen
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  destinations: bottomDestinations,
                ),
        );
      },
    );
  }

  Widget _buildEnterpriseDrawer(BuildContext context, bool isAdmin, bool isEmployee, bool isClient) {
    final user = SupabaseService().currentUser;
    final role = SupabaseService().currentRole ?? 'User';
    final orgName = SupabaseService().currentOrganization?['name'] ?? 'Enterprise Workspace';

    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: kGradBg,
            ),
            accountName: Text(
              orgName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kPremiumText),
            ),
            accountEmail: Row(
              children: [
                Expanded(
                  child: Text(
                    user?.email ?? 'user@organization.com',
                    style: const TextStyle(fontSize: 12, color: kPremiumMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kPremiumGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPremiumGold.withOpacity(0.4)),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kPremiumGold),
                  ),
                ),
              ],
            ),
            currentAccountPicture: PremiumAvatar(
              label: orgName,
              icon: Icons.business_center_rounded,
              style: AvatarStyle.glowIcon,
              gradient: kGradGold,
              size: 54,
              radius: 18,
            ),
          ),

          // Drawer Navigation Items List
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text('CORE PLATFORM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined, color: Colors.deepPurple),
                  title: const Text('Dashboard'),
                  selected: _selectedIndex == 0,
                  onTap: () {
                    Navigator.pop(context);
                    _onItemTapped(0);
                  },
                ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.people_outline, color: Colors.blue),
                    title: const Text('Employees (HR)'),
                    selected: _selectedIndex == 1,
                    onTap: () {
                      Navigator.pop(context);
                      _onItemTapped(1);
                    },
                  ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.business_center_outlined, color: Colors.teal),
                    title: const Text('Clients (CRM)'),
                    selected: _selectedIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      _onItemTapped(2);
                    },
                  ),
                if (isAdmin || isEmployee)
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined, color: Colors.green),
                    title: const Text('Attendance & Leave'),
                    selected: _selectedIndex == (isAdmin ? 3 : 1),
                    onTap: () {
                      Navigator.pop(context);
                      _onItemTapped(isAdmin ? 3 : 1);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: Colors.indigo),
                  title: const Text('Live Internal Chat'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatPage()));
                  },
                ),

                const Divider(height: 24),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Text('ENTERPRISE MODULES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_special_outlined, color: Colors.teal),
                  title: const Text('Projects Management'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.view_kanban_outlined, color: Colors.deepOrange),
                  title: const Text('Task Kanban Board'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskBoardPage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment_ind_outlined, color: Colors.purpleAccent),
                  title: const Text('Assigned Consultations'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AssignedConsultationsPage()));
                  },
                ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.account_balance_outlined, color: Colors.green),
                    title: const Text('Finance & Ledger'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancePage()));
                    },
                  ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined, color: Colors.purple),
                    title: const Text('Invoices & Billing'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const InvoicePage()));
                    },
                  ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.analytics_outlined, color: Colors.indigo),
                    title: const Text('Reports & Analytics'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsPage()));
                    },
                  ),

                const Divider(height: 24),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Text('ADMIN & PREFERENCES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
                ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_outlined, color: Colors.orange),
                    title: const Text('Invite Team Members'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const InvitePage()));
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: Colors.blueGrey),
                  title: const Text('Settings & Security'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                  },
                ),
              ],
            ),
          ),

          // Drawer Footer (Sign Out)
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () async {
              Navigator.pop(context);
              final confirm = await showLogoutConfirmationDialog(context);
              if (confirm) {
                await SupabaseService().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
