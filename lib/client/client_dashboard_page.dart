import 'package:flutter/material.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/core/premium_theme.dart';
import 'package:business_managment_app/shared/chat_page.dart';
import 'package:business_managment_app/shared/project_details_page.dart';
import 'package:business_managment_app/employee/assigned_consultations_page.dart';
import 'package:business_managment_app/shared/project_page.dart';
import 'package:business_managment_app/shared/invoice_page.dart';

class ClientDashboardPage extends StatefulWidget {
  const ClientDashboardPage({super.key});

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
  final AppDataStore _store = AppDataStore();
  bool _isLoading = true;
  String _clientName = '';
  String _clientCompany = '';
  double _budget = 0.0;
  String _status = 'Active';
  String _assignedManager = 'Unassigned';
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

    final metaName = user?.userMetadata?['full_name']?.toString() ?? '';
    final metaCompany = user?.userMetadata?['company']?.toString() ?? '';

    if (_store.clients.isEmpty) {
      await _store.refreshFromSupabase();
    }

    // Match ClientModel in AppDataStore
    ClientModel? matchedClient;
    for (final c in _store.clients) {
      if ((user?.id != null && (c.id == user!.id || c.userId == user.id)) ||
          (userEmail.isNotEmpty && c.email.trim().toLowerCase() == userEmail.trim().toLowerCase())) {
        matchedClient = c;
        break;
      }
    }

    // Direct Supabase lookup if not found in store
    if (matchedClient == null && user != null) {
      try {
        final dbRes = await SupabaseService().client
            .from('clients')
            .select('*, profiles(*)')
            .or('user_id.eq.${user.id},email.ilike.$userEmail')
            .maybeSingle();

        if (dbRes != null) {
          final profile = dbRes['profiles'] as Map<String, dynamic>?;
          final name = dbRes['contact_name']?.toString() ?? dbRes['name']?.toString() ?? profile?['full_name']?.toString() ?? '';
          final email = dbRes['email']?.toString() ?? profile?['email']?.toString() ?? userEmail;
          final company = dbRes['company_name']?.toString() ?? dbRes['company']?.toString() ?? name;
          matchedClient = ClientModel(
            id: dbRes['id']?.toString() ?? '',
            userId: dbRes['user_id']?.toString() ?? user.id,
            name: name.isNotEmpty ? name : 'Client',
            company: company.isNotEmpty ? company : 'Client Business',
            email: email,
            phone: dbRes['phone']?.toString() ?? profile?['phone']?.toString() ?? '',
            status: dbRes['status']?.toString() ?? 'Active',
            assignedEmployeeId: dbRes['assigned_employee_id']?.toString(),
            assignedEmployeeName: dbRes['assigned_employee_name']?.toString(),
            projectType: dbRes['project_type']?.toString() ?? 'General Consulting',
            budget: (dbRes['budget'] as num?)?.toDouble() ?? 0.0,
          );

          if (dbRes['user_id'] == null || dbRes['user_id'].toString().isEmpty) {
            try {
              await SupabaseService().client.from('clients').update({'user_id': user.id}).eq('id', dbRes['id']);
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Direct client fetch notice: $e');
      }
    }

    if (matchedClient != null) {
      _clientName = matchedClient.name;
      _clientCompany = matchedClient.company;
      _budget = matchedClient.budget;
      _status = matchedClient.status;
      _assignedManager = matchedClient.assignedEmployeeName ?? 'Unassigned';
      _adminNote = matchedClient.adminNote;
    } else {
      _clientName = metaName.isNotEmpty ? metaName : (userEmail.contains('@') ? userEmail.split('@')[0] : 'Client User');
      _clientCompany = metaCompany.isNotEmpty ? metaCompany : 'Client Account';
      _budget = 0.0;
      _status = 'Active';
      _assignedManager = 'Unassigned';
      _adminNote = null;
    }

    // Fetch projects for this client
    List<Map<String, dynamic>> projectsData = [];
    try {
      if (matchedClient != null && matchedClient.id.isNotEmpty) {
        final res = await SupabaseService().client
            .from('projects')
            .select('*, clients(*)')
            .eq('client_id', matchedClient.id)
            .order('created_at', ascending: false);
        projectsData = List<Map<String, dynamic>>.from(res);
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
              final double hPad = isDesktop ? 32.0 : (isTablet ? 20.0 : 14.0);

              return RefreshIndicator(
                color: kPremiumGold,
                onRefresh: () async {
                  await _store.refreshFromSupabase();
                  await _fetchClientData();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: hPad,
                    right: hPad,
                    top: 14,
                    bottom: MediaQuery.of(context).padding.bottom + 80.0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // -- HERO BANNER ------------------------------
                          HeroBanner(
                            title: _clientCompany,
                            subtitle: 'Welcome back \u{1F44B}, $_clientName',
                            badge: 'Client Portal',
                          ),

                          const SizedBox(height: 18),

                          // -- OVERVIEW BANNER CARD ---------------------
                          GlassCard(
                            padding: const EdgeInsets.all(18),
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),

                                // Responsive Overview Stats
                                LayoutBuilder(
                                  builder: (context, overviewConstraints) {
                                    final bool isCompact = overviewConstraints.maxWidth < 480;
                                    if (isCompact) {
                                      return Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(child: _overviewItem('Active Projects', '${_clientProjects.length}')),
                                              Expanded(child: _overviewItem('Allocated Budget', '\u{20B9}${_budget.toStringAsFixed(0)}')),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            children: [
                                              Expanded(child: _overviewItem('Account Lead', _assignedManager.isNotEmpty ? _assignedManager.split(' ').first : 'Unassigned')),
                                              Expanded(child: _overviewItem('Support Tier', 'Priority')),
                                            ],
                                          ),
                                        ],
                                      );
                                    }
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: _overviewItem('Active Projects', '${_clientProjects.length}')),
                                        Expanded(child: _overviewItem('Allocated Budget', '\u{20B9}${_budget.toStringAsFixed(0)}')),
                                        Expanded(child: _overviewItem('Account Lead', _assignedManager.isNotEmpty ? _assignedManager.split(' ').first : 'Unassigned')),
                                        Expanded(child: _overviewItem('Support Tier', 'Priority')),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ADMIN NOTICE BANNER
                          if (_adminNote != null && _adminNote!.isNotEmpty) ...[
                            GlassCard(
                              padding: const EdgeInsets.all(16),
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
                                        const Text('Notice from Executive Management', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(_adminNote!, style: const TextStyle(color: kPremiumText, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // -- PORTAL MODULES --------------
                          const Text(
                            'Client Portal Modules',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          LayoutBuilder(
                            builder: (context, moduleConstraints) {
                              final mWidth = moduleConstraints.maxWidth;
                              final bool singleCol = mWidth < 500;

                              if (singleCol) {
                                return Column(
                                  children: [
                                    _actionCard(
                                      icon: Icons.folder_open_outlined,
                                      title: 'My Projects',
                                      subtitle: '${_clientProjects.length} Active Workflows',
                                      color: kPremiumGold,
                                      onTap: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectPage()));
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    _actionCard(
                                      icon: Icons.receipt_long_outlined,
                                      title: 'Invoices & Billing',
                                      subtitle: 'Account Billing & Slips',
                                      color: Colors.purpleAccent,
                                      onTap: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => const InvoicePage()));
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    _actionCard(
                                      icon: Icons.person_pin_outlined,
                                      title: 'Consultations & Lead',
                                      subtitle: _assignedManager,
                                      color: kPremiumBlue,
                                      onTap: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AssignedConsultationsPage()));
                                      },
                                    ),
                                    const SizedBox(height: 10),
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
                                );
                              }

                              return GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 4,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.3,
                                children: [
                                  _actionCard(
                                    icon: Icons.folder_open_outlined,
                                    title: 'My Projects',
                                    subtitle: '${_clientProjects.length} Active Workflows',
                                    color: kPremiumGold,
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectPage()));
                                    },
                                  ),
                                  _actionCard(
                                    icon: Icons.receipt_long_outlined,
                                    title: 'Invoices & Billing',
                                    subtitle: 'Account Invoices',
                                    color: Colors.purpleAccent,
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const InvoicePage()));
                                    },
                                  ),
                                  _actionCard(
                                    icon: Icons.person_pin_outlined,
                                    title: 'Consultations & Lead',
                                    subtitle: _assignedManager,
                                    color: kPremiumBlue,
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AssignedConsultationsPage()));
                                    },
                                  ),
                                  _actionCard(
                                    icon: Icons.chat_bubble_outline,
                                    title: 'Live Support Chat',
                                    subtitle: 'Instant HR / Exec Lead',
                                    color: kPremiumTeal,
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatPage()));
                                    },
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // -- MY LIVE ENTERPRISE PROJECTS ------------------------------
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'My Active Enterprise Projects',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${_clientProjects.length} Projects', style: const TextStyle(color: kPremiumMuted, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_clientProjects.isEmpty)
                            GlassCard(
                              padding: const EdgeInsets.all(22),
                              child: const Center(
                                child: Text('No active projects currently assigned to your account in Supabase database.', style: TextStyle(color: kPremiumMuted, fontSize: 13)),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _clientProjects.length,
                              itemBuilder: (context, index) {
                                final p = _clientProjects[index];
                                final pName = p['name']?.toString() ?? 'Enterprise Project';
                                final pStatus = p['status']?.toString() ?? 'In Progress';
                                final pDeadline = p['deadline']?.toString().split(' ').first ?? 'No deadline set';
                                final double budgetVal = (p['budget'] as num?)?.toDouble() ?? 0.0;
                                final double progress = pStatus == 'Completed' ? 1.0 : 0.65;

                                return GlassCard(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  onTap: () {
                                    final projModel = ProjectModel(
                                      id: p['id']?.toString() ?? '',
                                      name: pName,
                                      clientId: p['client_id']?.toString() ?? '',
                                      clientName: _clientName,
                                      status: pStatus,
                                      budget: budgetVal,
                                      deadline: pDeadline,
                                    );
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProjectDetailsPage(project: projModel),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          PremiumAvatar(
                                            icon: Icons.folder_rounded,
                                            style: AvatarStyle.glowIcon,
                                            size: 40,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  pName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPremiumText),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Target Deadline: $pDeadline \u2022 Budget: \u{20B9}${budgetVal.toStringAsFixed(0)}',
                                                  style: const TextStyle(fontSize: 12, color: kPremiumMuted),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                      const SizedBox(height: 12),
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: kPremiumGold,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: kPremiumMuted,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: kPremiumMuted, size: 14),
        ],
      ),
    );
  }
}
