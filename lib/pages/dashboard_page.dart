import 'package:flutter/material.dart';
import '../services/app_data_store.dart';

class DashboardPage extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardPage({super.key, this.onNavigate});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
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

  @override
  Widget build(BuildContext context) {
    final activeEmployees = _store.employees.where((e) => e.status == 'Active').length;
    final activeClients = _store.clients.where((c) => c.status == 'Active').length;
    final pendingLeaves = _store.leaveRequests.where((l) => l.status == 'Pending').length;
    final activeProjects = _store.projects.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width >= 900;
        final bool isTablet = width >= 600 && width < 900;
        final double hPad = isDesktop ? 36 : isTablet ? 24 : 16;

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
                    // Header Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Executive Dashboard 👋',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Real-time overview of business operations, team status, and financials.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Responsive Metrics Grid / Wrap
                    LayoutBuilder(
                      builder: (context, box) {
                        final double boxWidth = box.maxWidth;
                        if (boxWidth < 600) {
                          // Mobile layout: Stacked cards to prevent any pixel overflow
                          return Column(
                            children: [
                              _statCard('Total Employees', '$activeEmployees Active', Icons.people, Colors.purple, () => widget.onNavigate?.call(1)),
                              const SizedBox(height: 12),
                              _statCard('Active Clients', '$activeClients Accounts', Icons.business_center, Colors.indigo, () => widget.onNavigate?.call(2)),
                              const SizedBox(height: 12),
                              _statCard('Projects', '$activeProjects Running', Icons.folder_special, Colors.teal, () {}),
                              const SizedBox(height: 12),
                              _statCard('Pending Leaves', '$pendingLeaves Requests', Icons.event_note, Colors.orange, () => widget.onNavigate?.call(3)),
                            ],
                          );
                        }

                        final colCount = boxWidth >= 900 ? 4 : 2;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: colCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 2.2,
                          children: [
                            _statCard('Total Employees', '$activeEmployees Active', Icons.people, Colors.purple, () => widget.onNavigate?.call(1)),
                            _statCard('Active Clients', '$activeClients Accounts', Icons.business_center, Colors.indigo, () => widget.onNavigate?.call(2)),
                            _statCard('Projects', '$activeProjects Running', Icons.folder_special, Colors.teal, () {}),
                            _statCard('Pending Leaves', '$pendingLeaves Requests', Icons.event_note, Colors.orange, () => widget.onNavigate?.call(3)),
                          ],
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

  Widget _statCard(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
