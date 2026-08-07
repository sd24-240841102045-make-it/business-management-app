import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
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
    final List<Widget> pages = [
      HomeBody(onNavigate: _onItemTapped),
      EmployeesBody(key: _employeesKey, onNavigate: _onItemTapped),
      ClientsBody(key: _clientsKey),
      AttendanceLeaveBody(key: _attendanceKey),
      const ChatPage(),
      const ProfileBody(),
    ];

    final titles = [
      'Dashboard',
      'Employees',
      'Clients',
      'Attendance & Leave',
      'Live Chat Communications',
      'Profile',
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
                  const PopupMenuItem(
                    value: FinancePage(),
                    child: ListTile(
                      leading: Icon(Icons.account_balance, color: Colors.green),
                      title: Text('Finance & Ledger'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: InvoicePage(),
                    child: ListTile(
                      leading: Icon(Icons.receipt_long, color: Colors.purple),
                      title: Text('Invoices & Billing'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: ReportsPage(),
                    child: ListTile(
                      leading: Icon(Icons.assessment, color: Colors.indigo),
                      title: Text('Reports & Analytics'),
                    ),
                  ),
                ],
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
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  }
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
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('Home'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.people_outline),
                          selectedIcon: Icon(Icons.people),
                          label: Text('Employees'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.business_center_outlined),
                          selectedIcon: Icon(Icons.business_center),
                          label: Text('Clients'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.calendar_month_outlined),
                          selectedIcon: Icon(Icons.calendar_month),
                          label: Text('Attendance'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.chat_bubble_outline),
                          selectedIcon: Icon(Icons.chat_bubble),
                          label: Text('Chat'),
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
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: 'Employees',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.business_center_outlined),
                      selectedIcon: Icon(Icons.business_center),
                      label: 'Clients',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: 'Attendance',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline),
                      selectedIcon: Icon(Icons.chat_bubble),
                      label: 'Chat',
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
