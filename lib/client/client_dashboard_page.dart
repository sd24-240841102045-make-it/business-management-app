import 'package:flutter/material.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/core/premium_theme.dart';
import 'package:business_managment_app/shared/chat_page.dart';

class ClientDashboardPage extends StatefulWidget {
  const ClientDashboardPage({super.key});

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
  final AppDataStore _store = AppDataStore();
  bool _isLoading = true;

  String _clientName = 'Valued Partner';
  String _clientEmail = '';
  String _clientCompany = 'Partner Enterprise';
  String _projectType = 'Enterprise Consulting';
  double _budget = 15000.0;
  String _status = 'Active';
  String _assignedManager = 'Senior Account Lead';
  String? _adminNote;

  List<Map<String, dynamic>> _clientProjects = [];

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
    _fetchClientData();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) {
      _fetchClientData();
    }
  }

  Future<void> _fetchClientData() async {
    final user = SupabaseService().currentUser;
    final userEmail = user?.email ?? '';
    _clientEmail = userEmail;

    final metaName = user?.userMetadata?['full_name']?.toString() ?? '';
    final metaCompany = user?.userMetadata?['company']?.toString() ?? '';

    // Match ClientModel in AppDataStore
    ClientModel? matchedClient;
    for (final c in _store.clients) {
      if (c.id == user?.id || c.email.toLowerCase() == userEmail.toLowerCase()) {
        matchedClient = c;
        break;
      }
    }

    _clientName = matchedClient?.name ?? (metaName.isNotEmpty ? metaName : (userEmail.contains('@') ? userEmail.split('@')[0] : 'Client Partner'));
    _clientCompany = matchedClient?.company ?? (metaCompany.isNotEmpty ? metaCompany : 'Registered Partner Enterprise');
    _projectType = matchedClient?.projectType ?? 'Enterprise Consulting';
    _budget = matchedClient?.budget ?? 15000.0;
    _status = matchedClient?.status ?? 'Active';
    _assignedManager = matchedClient?.assignedEmployeeName ?? 'Senior Account Lead';
    _adminNote = matchedClient?.adminNote;

    // Fetch projects for this client
    List<Map<String, dynamic>> projectsData = [];
    try {
      if (matchedClient != null) {
        final res = await SupabaseService().client.from('projects').select().eq('client_id', matchedClient.id);
        projectsData = List<Map<String, dynamic>>.from(res as List);
      } else {
        final res = await SupabaseService().client.from('projects').select().limit(5);
        projectsData = List<Map<String, dynamic>>.from(res as List);
      }
    } catch (e) {
      debugPrint('Error fetching client projects: $e');
    }

    if (mounted) {
      setState(() {
        _clientProjects = projectsData;
        _isLoading = false;
      });
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
                onRefresh: () async {
                  await _store.refreshFromSupabase();
                  await _fetchClientData();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── HERO BANNER (SAME AS ADMIN) ──────────────────────────────
                          HeroBanner(
                            title: _clientCompany,
                            subtitle: 'Welcome back 👋, $_clientName',
                            badge: 'Client Portal',
                          ),

                          const SizedBox(height: 20),

                          // ── OVERVIEW BANNER CARD (SAME AS ADMIN) ─────────────────────
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
                                        'Unified Client Overview',
                                        style: TextStyle(color: kPremiumMuted, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _status == 'Active' ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: _status == 'Active' ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        _status,
                                        style: TextStyle(color: _status == 'Active' ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _clientCompany,
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
                                    final bool isCompact = overviewConstraints.maxWidth < 450;
                                    if (isCompact) {
                                      return Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(child: _overviewItem('Active Projects', '${_clientProjects.length}')),
                                              Expanded(child: _overviewItem('Allocated Budget', '\$${_budget.toStringAsFixed(0)}')),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            children: [
                                              Expanded(child: _overviewItem('Account Lead', _assignedManager.split(' ').first)),
                                              Expanded(child: _overviewItem('Support Tier', 'Priority')),
                                            ],
                                          ),
                                        ],
                                      );
                                    }
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('Active Projects', '${_clientProjects.length}'))),
                                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('Allocated Budget', '\$${_budget.toStringAsFixed(0)}'))),
                                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('Account Lead', _assignedManager.split(' ').first))),
                                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: _overviewItem('Support Tier', 'Priority'))),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ADMIN NOTICE BANNER
                          if (_adminNote != null && _adminNote!.isNotEmpty) ...[
                            GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: kPremiumGold.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.campaign_outlined, color: kPremiumGold, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Notice from Executive Management', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(_adminNote!, style: const TextStyle(color: kPremiumText, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // ── PORTAL MODULES (SAME AS ADMIN ACTION CARDS) ──────────────
                          const Text(
                            'Client Portal Modules',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 14),

                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: isDesktop ? 3 : (isTablet ? 3 : (width < 360 ? 1 : 2)),
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: isDesktop ? 1.6 : (isTablet ? 1.4 : 1.15),
                            children: [
                              _actionCard(
                                icon: Icons.folder_open_outlined,
                                title: 'My Projects',
                                subtitle: '${_clientProjects.length} Active Workflows',
                                color: kPremiumGold,
                                onTap: () {},
                              ),
                              _actionCard(
                                icon: Icons.person_pin_outlined,
                                title: 'Account Lead',
                                subtitle: _assignedManager,
                                color: kPremiumBlue,
                                onTap: () {},
                              ),
                              _actionCard(
                                icon: Icons.chat_bubble_outline,
                                title: 'Live Support Chat',
                                subtitle: 'Instant HR / Executive Lead',
                                color: kPremiumTeal,
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatPage()));
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          // ── MY LIVE ENTERPRISE PROJECTS ──────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'My Active Enterprise Projects',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text('${_clientProjects.length} Projects', style: const TextStyle(color: kPremiumMuted, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (_clientProjects.isEmpty)
                            GlassCard(
                              padding: const EdgeInsets.all(24),
                              child: const Center(
                                child: Text('No active projects currently assigned to your account in Supabase database.', style: TextStyle(color: kPremiumMuted, fontSize: 14)),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _clientProjects.length,
                              itemBuilder: (context, index) {
                                final p = _clientProjects[index];
                                final pName = p['name'] ?? 'Enterprise Project';
                                final pStatus = p['status'] ?? 'In Progress';
                                final pDeadline = p['deadline'] ?? 'Q4 2026';
                                final progress = ((p['progress'] ?? 65) as num).toDouble() / 100.0;

                                return GlassCard(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          PremiumAvatar(
                                            icon: Icons.folder_rounded,
                                            style: AvatarStyle.glowIcon,
                                            size: 44,
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  pName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPremiumText),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text('Target Deadline: $pDeadline', style: const TextStyle(fontSize: 12, color: kPremiumMuted)),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: kPremiumGold.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              pStatus,
                                              style: const TextStyle(color: kPremiumGold, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Delivery Progress', style: TextStyle(color: kPremiumMuted, fontSize: 12)),
                                          Text('${(progress * 100).toInt()}% Completed', style: const TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 6,
                                          color: kPremiumGold,
                                          backgroundColor: Colors.white10,
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
}
