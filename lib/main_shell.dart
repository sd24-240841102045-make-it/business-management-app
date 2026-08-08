import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'pages/employee_dashboard_page.dart';
import 'employees_page.dart';
import 'clients.dart';
import 'attendance_leave_page.dart';
import 'emp_profile.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'chat_page.dart';
import 'pages/project_page.dart';
import 'pages/task_board_page.dart';
import 'pages/finance_page.dart';
import 'pages/invoice_page.dart';
import 'pages/reports_page.dart';
import 'pages/invite_page.dart';
import 'services/supabase_service.dart';

import 'pages/client_dashboard_page.dart';

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
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 2,
            actions: [
              PopupMenuButton<Widget>(
                icon: const Icon(Icons.apps),
                tooltip: 'More Enterprise Modules',
                onSelected: (pageWidget) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => pageWidget),
                  );
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: ProjectPage(),
                    child: ListTile(
                      leading: Icon(Icons.folder, color: Colors.teal),
                      title: Text('Projects Management'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: TaskBoardPage(),
                    child: ListTile(
                      leading: Icon(Icons.view_kanban, color: Colors.orange),
                      title: Text('Task Kanban Board'),
                    ),
                  ),
                  if (isAdmin)
                    const PopupMenuItem(
                      value: FinancePage(),
                      child: ListTile(
                        leading: Icon(Icons.account_balance, color: Colors.green),
                        title: Text('Finance & Ledger'),
                      ),
                    ),
                  if (isAdmin)
                    const PopupMenuItem(
                      value: InvoicePage(),
                      child: ListTile(
                        leading: Icon(Icons.receipt_long, color: Colors.purple),
                        title: Text('Invoices & Billing'),
                      ),
                    ),
                  if (isAdmin)
                    const PopupMenuItem(
                      value: ReportsPage(),
                      child: ListTile(
                        leading: Icon(Icons.assessment, color: Colors.indigo),
                        title: Text('Reports & Analytics'),
                      ),
                    ),
                ],
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
          body: isWideScreen
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _onItemTapped,
                      labelType: NavigationRailLabelType.all,
                      selectedIconTheme: const IconThemeData(color: Colors.deepPurple, size: 28),
                      selectedLabelTextStyle: const TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedIconTheme: const IconThemeData(color: Colors.grey),
                      destinations: railDestinations,
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: pages,
                      ),
                    ),
                  ],
                )
              : IndexedStack(
                  index: _selectedIndex,
                  children: pages,
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
}
