import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class ChatPage extends StatefulWidget {
  final String? initialTargetId;
  final String? initialTargetName;
  final String? initialTargetSubtitle;
  final String? initialTargetType; // 'employee' or 'client'
  final String? initialTargetEmail;
  final String? initialTargetPhone;

  const ChatPage({
    super.key,
    this.initialTargetId,
    this.initialTargetName,
    this.initialTargetSubtitle,
    this.initialTargetType,
    this.initialTargetEmail,
    this.initialTargetPhone,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final AppDataStore _store = AppDataStore();
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Cache the stream per conversationId so StreamBuilder doesn't re-subscribe on setState
  String? _streamedConversationId;
  Stream<List<ChatMessage>>? _messagesStream;

  String? _selectedTargetId;
  String _selectedTargetName = '';
  String _selectedTargetSubtitle = '';
  String _selectedTargetType = 'client';
  String _selectedTargetEmail = '';
  String _selectedTargetPhone = '';
  
  String? _activeConversationId;
  bool _isLoadingConversation = false;
  String _searchQuery = '';
  bool _showProfileInfo = false;
  int _filterTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
    _store.refreshFromSupabase();

    if (widget.initialTargetId != null) {
      _selectTarget(
        widget.initialTargetId!,
        widget.initialTargetName ?? 'Contact',
        widget.initialTargetSubtitle ?? '',
        widget.initialTargetType ?? 'employee',
        widget.initialTargetEmail ?? '',
        widget.initialTargetPhone ?? '',
      );
    }
  }

  Future<void> _selectTarget(
    String id,
    String name,
    String subtitle,
    String type, [
    String email = '',
    String phone = '',
  ]) async {
    if (!mounted) return;

    String resolvedEmail = email.trim();
    String resolvedPhone = phone.trim();

    // Dynamically lookup phone & email if not provided
    if (resolvedPhone.isEmpty || resolvedEmail.isEmpty) {
      for (final emp in _store.employees) {
        if (emp.id == id || emp.userId == id || emp.name.toLowerCase() == name.toLowerCase()) {
          if (resolvedEmail.isEmpty && emp.email.trim().isNotEmpty) resolvedEmail = emp.email.trim();
          if (resolvedPhone.isEmpty && emp.phone.trim().isNotEmpty) resolvedPhone = emp.phone.trim();
          break;
        }
      }

      for (final client in _store.clients) {
        if (client.id == id || client.name.toLowerCase() == name.toLowerCase()) {
          if (resolvedEmail.isEmpty && client.email.trim().isNotEmpty) resolvedEmail = client.email.trim();
          if (resolvedPhone.isEmpty && client.phone.trim().isNotEmpty) resolvedPhone = client.phone.trim();
          break;
        }
      }
    }

    setState(() {
      _selectedTargetId = id;
      _selectedTargetName = name;
      _selectedTargetSubtitle = subtitle;
      _selectedTargetType = type;
      _selectedTargetEmail = resolvedEmail;
      _selectedTargetPhone = resolvedPhone;
      _isLoadingConversation = true;
      _showProfileInfo = false;
    });

    final convId = await SupabaseService().getOrCreateDirectConversation(id);
    
    if (mounted) {
      setState(() {
        _activeConversationId = convId;
        _isLoadingConversation = false;
        // Only create a new stream if conversation changed
        if (_streamedConversationId != convId) {
          _streamedConversationId = convId;
          _messagesStream = SupabaseService().getMessagesStream(convId);
        }
      });
    }
  }

  void _backToInbox() {
    setState(() {
      _selectedTargetId = null;
      _activeConversationId = null;
      _streamedConversationId = null;
      _messagesStream = null;
      _showProfileInfo = false;
    });
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    _msgController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendMessage([String? predefinedText]) async {
    final textToSend = predefinedText ?? _msgController.text.trim();
    if (textToSend.isEmpty) return;

    if (_activeConversationId == null && _selectedTargetId != null) {
      final fallbackConv = await SupabaseService().getOrCreateDirectConversation(_selectedTargetId!);
      if (mounted) {
        setState(() {
          _activeConversationId = fallbackConv;
        });
      }
    }

    if (_activeConversationId == null) return;

    if (predefinedText == null) {
      _msgController.clear();
    }
    
    await SupabaseService().sendChatMessage(_activeConversationId!, textToSend);

    if (mounted) {
      setState(() {});
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Map<String, String> _getSenderInfo(String senderId, bool isClient) {
    if (senderId == Supabase.instance.client.auth.currentUser?.id) {
      return {'name': 'Me', 'role': isClient ? 'Client' : 'Admin'};
    }
    for (final c in _store.clients) {
      if (c.id == senderId) return {'name': c.name, 'role': 'Client'};
    }
    for (final e in _store.employees) {
      if (e.id == senderId) return {'name': e.name, 'role': e.role};
    }
    for (final a in _store.admins) {
      if (a.id == senderId) return {'name': a.name, 'role': 'Admin'};
    }
    return {'name': 'User', 'role': 'Member'};
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (_) {
      if (isoString.contains('T')) {
        return isoString.split('T')[1].substring(0, 5);
      }
      return isoString;
    }
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) {
      return 'Today';
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to access Live Chat', style: TextStyle(color: kPremiumText)),
        ),
      );
    }

    final currentRole = SupabaseService().getUserRole(user);
    final isClient = currentRole == 'client';
    final canPop = Navigator.of(context).canPop();

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: canPop
            ? AppBar(
                title: const Text(
                  'Enterprise Live Chat',
                  style: TextStyle(fontWeight: FontWeight.w800, color: kPremiumGold, letterSpacing: 0.3),
                ),
                backgroundColor: kPremiumBg.withOpacity(0.85),
                foregroundColor: kPremiumGold,
                elevation: 0,
              )
            : null,
        body: SafeArea(
          top: !canPop,
          bottom: false, // Handled inside bottom bars so container backgrounds extend smoothly
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 750;

              if (isDesktop) {
                // Desktop split-pane view
                return Row(
                  children: [
                    SizedBox(
                      width: 350,
                      child: _buildInboxView(isDesktop: true),
                    ),
                    Container(
                      width: 1,
                      color: kPremiumBorder,
                    ),
                    Expanded(
                      child: _selectedTargetId != null
                          ? _buildConversationView(isDesktop: true, user: user, isClient: isClient)
                          : _buildEmptyWorkspaceView(),
                    ),
                  ],
                );
              } else {
                // Mobile view with navigation state
                if (_selectedTargetId == null) {
                  return _buildInboxView(isDesktop: false);
                } else {
                  return _buildConversationView(isDesktop: false, user: user, isClient: isClient);
                }
              }
            },
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // INBOX & CONTACTS LIST VIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildInboxView({required bool isDesktop}) {
    final filteredAdmins = _store.admins.where((a) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = a.name.toLowerCase().contains(q) ||
          a.email.toLowerCase().contains(q);
      if (!matchesSearch) return false;
      return _filterTabIndex == 0 || _filterTabIndex == 1;
    }).toList();

    final filteredEmployees = _store.employees.where((e) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = e.name.toLowerCase().contains(q) ||
          e.role.toLowerCase().contains(q) ||
          e.department.toLowerCase().contains(q);
      if (!matchesSearch) return false;
      return _filterTabIndex == 0 || _filterTabIndex == 1;
    }).toList();

    final filteredClients = _store.clients.where((c) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = c.name.toLowerCase().contains(q) ||
          c.company.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q);
      if (!matchesSearch) return false;
      return _filterTabIndex == 0 || _filterTabIndex == 2;
    }).toList();

    final totalCount = filteredAdmins.length + filteredEmployees.length + filteredClients.length;

    return Column(
      children: [
        // Inbox Top Header & Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: kPremiumText,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kPremiumGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                    ),
                    child: Text(
                      '$totalCount contacts',
                      style: const TextStyle(
                        color: kPremiumGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Bar
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: kPremiumText, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search contacts or accounts...',
                  hintStyle: const TextStyle(color: kPremiumMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: kPremiumGold, size: 20),
                  filled: true,
                  fillColor: kPremiumSurface.withOpacity(0.7),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: kPremiumBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: kPremiumBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: kPremiumGold, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Category Filter Tabs
              Row(
                children: [
                  _filterTabChip('All', 0),
                  const SizedBox(width: 8),
                  _filterTabChip('Staff & HR', 1),
                  const SizedBox(width: 8),
                  _filterTabChip('Clients', 2),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 16, color: kPremiumBorder),

        // Contacts List
        Expanded(
          child: (filteredAdmins.isEmpty && filteredEmployees.isEmpty && filteredClients.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_search_outlined, size: 48, color: kPremiumMuted.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      const Text(
                        'No contacts found',
                        style: TextStyle(color: kPremiumMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  top: false,
                  bottom: !isDesktop,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [
                      if (_filterTabIndex != 2 && filteredAdmins.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
                          child: Text(
                            'ADMIN & EXECUTIVE LEADS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: kPremiumGold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        ...filteredAdmins.map((a) => _buildContactCard(
                              id: a.id,
                              name: a.name,
                              subtitle: 'Executive Admin • ${a.email}',
                              type: 'admin',
                              email: a.email,
                              phone: a.phone,
                              badgeColor: kPremiumGold,
                              badgeLabel: 'Admin',
                            )),
                        const SizedBox(height: 12),
                      ],

                      if (_filterTabIndex != 2 && filteredEmployees.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
                          child: Text(
                            'EMPLOYEES & HR TEAM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: kPremiumViolet,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        ...filteredEmployees.map((e) => _buildContactCard(
                              id: e.userId.isNotEmpty ? e.userId : e.id,
                              name: e.name,
                              subtitle: '${e.role} • ${e.department}',
                              type: 'employee',
                              email: e.email,
                              phone: e.phone,
                              badgeColor: kPremiumViolet,
                              badgeLabel: 'Staff',
                            )),
                      ],

                      if (_filterTabIndex != 1 && filteredClients.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
                          child: Text(
                            'CLIENTS & BUSINESS ACCOUNTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: kPremiumBlue,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        ...filteredClients.map((c) => _buildContactCard(
                              id: (c.userId != null && c.userId!.isNotEmpty) ? c.userId! : c.id,
                              name: c.name,
                              subtitle: '${c.company} • ${c.email}',
                              type: 'client',
                              email: c.email,
                              phone: c.phone,
                              badgeColor: kPremiumBlue,
                              badgeLabel: 'Client',
                            )),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterTabChip(String label, int index) {
    final isSelected = _filterTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filterTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? kPremiumGold : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? kPremiumGold : kPremiumBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? kPremiumBg : kPremiumMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required String id,
    required String name,
    required String subtitle,
    required String type,
    required String email,
    required String phone,
    required Color badgeColor,
    required String badgeLabel,
  }) {
    final isSelected = _selectedTargetId == id;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 16,
      glow: isSelected ? kPremiumGold : null,
      onTap: () => _selectTarget(id, name, subtitle, type, email, phone),
      child: Row(
        children: [
          Stack(
            children: [
              PremiumAvatar(
                label: name,
                size: 42,
                radius: 14,
                style: AvatarStyle.gradient,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: kPremiumSuccess,
                    shape: BoxShape.circle,
                    border: Border.all(color: kPremiumBg, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: kPremiumSuccess.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: isSelected ? kPremiumGold : kPremiumText,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: kPremiumSuccess,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: kPremiumSuccess,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DESKTOP UNSELECTED EMPTY WORKSPACE STATE
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildEmptyWorkspaceView() {
    return Center(
      child: FadeInSlide(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kPremiumGold.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: kPremiumGold.withOpacity(0.2)),
              ),
              child: const Icon(Icons.forum_outlined, size: 64, color: kPremiumGold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Enterprise Communications Workspace',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kPremiumText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select a team member or client account from the list to start chatting.',
              style: TextStyle(color: kPremiumMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kPremiumGold.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: kPremiumGold.withOpacity(0.3)),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: kPremiumGold, size: 44),
            ),
            const SizedBox(height: 16),
            Text(
              'Encrypted Session with $_selectedTargetName',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: kPremiumText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Messages are end-to-end encrypted. Type a message below or tap a quick prompt to start chatting.',
              style: TextStyle(color: kPremiumMuted, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  avatar: const Text('👋'),
                  label: const Text('Say Hello', style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold, fontSize: 12)),
                  backgroundColor: kPremiumGold.withOpacity(0.12),
                  side: BorderSide(color: kPremiumGold.withOpacity(0.3)),
                  onPressed: () => _sendMessage('Hello! Hope you are doing well.'),
                ),
                ActionChip(
                  avatar: const Text('📋'),
                  label: const Text('Request Update', style: TextStyle(color: kPremiumBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                  backgroundColor: kPremiumBlue.withOpacity(0.12),
                  side: BorderSide(color: kPremiumBlue.withOpacity(0.3)),
                  onPressed: () => _sendMessage('Could you please share an update on current deliverables?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CONVERSATION THREAD & PROFILE DRAWER VIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildConversationView({
    required bool isDesktop,
    required User user,
    required bool isClient,
  }) {
    return Column(
      children: [
        // Thread Top Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kPremiumSurface.withOpacity(0.85),
            border: const Border(bottom: BorderSide(color: kPremiumBorder)),
          ),
          child: Row(
            children: [
              if (!isDesktop)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kPremiumGold, size: 20),
                  tooltip: 'Back to contacts',
                  onPressed: _backToInbox,
                ),
              PremiumAvatar(
                label: _selectedTargetName,
                size: 40,
                radius: 13,
                style: AvatarStyle.gradient,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _showProfileInfo = !_showProfileInfo),
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedTargetName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: kPremiumText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: kPremiumSuccess,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: kPremiumSuccess,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _showProfileInfo ? Icons.info_rounded : Icons.info_outline_rounded,
                  color: _showProfileInfo ? kPremiumGold : kPremiumMuted,
                ),
                tooltip: 'View Profile & Contact Info',
                onPressed: () => setState(() => _showProfileInfo = !_showProfileInfo),
              ),
            ],
          ),
        ),

        // Conversation Body + Profile Side Drawer
        Expanded(
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        // Chat Messages Area
                        Expanded(
                          child: _isLoadingConversation
                              ? const Center(child: CircularProgressIndicator(color: kPremiumGold))
                              : _messagesStream == null
                                  ? _buildEmptyChatState()
                                  : StreamBuilder<List<ChatMessage>>(
                                      stream: _messagesStream,
                                      builder: (context, snapshot) {
                                        if (snapshot.hasError) {
                                          return Center(
                                            child: Text('Error: ${snapshot.error}',
                                                style: const TextStyle(color: Colors.redAccent)),
                                          );
                                        }
                                        final messages = snapshot.data ?? [];
                                        if (messages.isEmpty) {
                                          return _buildEmptyChatState();
                                        }
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (_scrollController.hasClients) {
                                            _scrollController.animateTo(
                                              _scrollController.position.maxScrollExtent,
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeOut,
                                            );
                                          }
                                        });
                                        return ListView.builder(
                                          controller: _scrollController,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          itemCount: messages.length,
                                          itemBuilder: (ctx, index) {
                                            final msg = messages[index];
                                            final isMe = msg.senderId == user.id;
                                            final senderInfo = _getSenderInfo(msg.senderId, isClient);
                                            bool showDateDivider = false;
                                            DateTime? msgDate;
                                            try {
                                              msgDate = DateTime.parse(msg.createdAt).toLocal();
                                              if (index == 0) {
                                                showDateDivider = true;
                                              } else {
                                                final prev = DateTime.parse(messages[index - 1].createdAt).toLocal();
                                                if (msgDate.day != prev.day || msgDate.month != prev.month || msgDate.year != prev.year) {
                                                  showDateDivider = true;
                                                }
                                              }
                                            } catch (_) {}
                                            return Column(
                                              children: [
                                                if (showDateDivider && msgDate != null)
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.06),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: kPremiumBorder),
                                                      ),
                                                      child: Text(
                                                        _formatDateHeader(msgDate),
                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kPremiumMuted),
                                                      ),
                                                    ),
                                                  ),
                                                Align(
                                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                                  child: Container(
                                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                                    constraints: BoxConstraints(
                                                      maxWidth: MediaQuery.of(ctx).size.width * (isDesktop ? 0.6 : 0.78),
                                                    ),
                                                    decoration: BoxDecoration(
                                                      gradient: isMe ? kGradBlue : null,
                                                      color: isMe ? null : kPremiumCard,
                                                      borderRadius: BorderRadius.only(
                                                        topLeft: const Radius.circular(18),
                                                        topRight: const Radius.circular(18),
                                                        bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(3),
                                                        bottomRight: isMe ? const Radius.circular(3) : const Radius.circular(18),
                                                      ),
                                                      border: isMe ? Border.all(color: kPremiumBlue.withOpacity(0.4)) : Border.all(color: kPremiumBorder),
                                                      boxShadow: [BoxShadow(color: (isMe ? kPremiumBlue : Colors.black).withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
                                                    ),
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                    child: Column(
                                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                                      children: [
                                                        if (!isMe) ...[
                                                          Text(
                                                            senderInfo['name'] ?? 'User',
                                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: kPremiumGold),
                                                          ),
                                                          const SizedBox(height: 4),
                                                        ],
                                                        Text(msg.message, style: const TextStyle(fontSize: 14, height: 1.35, color: Colors.white)),
                                                        const SizedBox(height: 4),
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              _formatTime(msg.createdAt),
                                                              style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : kPremiumMuted),
                                                            ),
                                                            if (isMe) ...[
                                                              const SizedBox(width: 4),
                                                              const Icon(Icons.done_all_rounded, size: 13, color: Colors.white70),
                                                            ],
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                        ),

                        // Quick Prompt Suggestions
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _quickPromptChip('👋 Quick Hello', 'Hello! Hope you are doing well.'),
                              _quickPromptChip('📋 Request Update', 'Could you please share an update on current deliverables?'),
                              _quickPromptChip('📅 Schedule Call', 'Let\'s schedule a brief sync when you are available.'),
                              _quickPromptChip('✅ Approved', 'Thanks! Looks good to proceed.'),
                            ],
                          ),
                        ),

                        // Enterprise Message Input Bar with System Navigation Safe Area
                        Container(
                          decoration: BoxDecoration(
                            color: kPremiumSurface.withOpacity(0.95),
                            border: const Border(top: BorderSide(color: kPremiumBorder)),
                          ),
                          child: SafeArea(
                            top: false,
                            left: true,
                            right: true,
                            bottom: true,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _msgController,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _sendMessage(),
                                      style: const TextStyle(color: kPremiumText, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'Write an encrypted message...',
                                        hintStyle: const TextStyle(color: kPremiumMuted, fontSize: 13),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(24),
                                          borderSide: const BorderSide(color: kPremiumBorder),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(24),
                                          borderSide: const BorderSide(color: kPremiumBorder),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(24),
                                          borderSide: const BorderSide(color: kPremiumGold, width: 1.5),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.04),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: kGradBlue,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: kPremiumBlue.withOpacity(0.4),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                      tooltip: 'Send Message',
                                      onPressed: () => _sendMessage(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Desktop Side Drawer
                  if (isDesktop && _showProfileInfo) _buildProfileDrawer(),
                ],
              ),

              // Mobile Floating Drawer Overlay
              if (!isDesktop && _showProfileInfo)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.55),
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: _buildProfileDrawer(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickPromptChip(String label, String messageText) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kPremiumGold),
        ),
        backgroundColor: kPremiumGold.withOpacity(0.08),
        side: BorderSide(color: kPremiumGold.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _sendMessage(messageText),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PROFILE & CONTACT DETAILS SIDE DRAWER
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildProfileDrawer() {
    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: kPremiumSurface.withOpacity(0.95),
        border: const Border(left: BorderSide(color: kPremiumBorder)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Contact Information',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kPremiumGold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: kPremiumMuted),
                  onPressed: () => setState(() => _showProfileInfo = false),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kPremiumBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Center(
                  child: Column(
                    children: [
                      PremiumAvatar(
                        label: _selectedTargetName,
                        size: 72,
                        radius: 22,
                        style: AvatarStyle.pattern,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _selectedTargetName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kPremiumText),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedTargetSubtitle,
                        style: const TextStyle(color: kPremiumMuted, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_selectedTargetType == 'client' ? kPremiumBlue : kPremiumViolet).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_selectedTargetType == 'client' ? kPremiumBlue : kPremiumViolet).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _selectedTargetType.toUpperCase(),
                          style: TextStyle(
                            color: _selectedTargetType == 'client' ? kPremiumBlue : kPremiumViolet,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'DIRECT CONTACT DETAILS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPremiumMuted, letterSpacing: 0.8),
                ),
                const SizedBox(height: 10),

                // Email Detail Card
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  radius: 14,
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 18, color: kPremiumGold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Email', style: TextStyle(fontSize: 10, color: kPremiumMuted)),
                            Text(
                              _selectedTargetEmail.isNotEmpty ? _selectedTargetEmail : 'Not provided',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPremiumText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_selectedTargetEmail.isNotEmpty)
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _selectedTargetEmail));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Email copied to clipboard!')),
                            );
                          },
                          child: const Icon(Icons.copy_rounded, size: 16, color: kPremiumMuted),
                        ),
                    ],
                  ),
                ),

                // Phone Detail Card (100% Dynamic Number)
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  radius: 14,
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 18, color: kPremiumGold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Phone', style: TextStyle(fontSize: 10, color: kPremiumMuted)),
                            Text(
                              _selectedTargetPhone.isNotEmpty ? _selectedTargetPhone : 'Not provided',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPremiumText),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedTargetPhone.isNotEmpty)
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _selectedTargetPhone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Phone number copied to clipboard!')),
                            );
                          },
                          child: const Icon(Icons.copy_rounded, size: 16, color: kPremiumMuted),
                        ),
                    ],
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
