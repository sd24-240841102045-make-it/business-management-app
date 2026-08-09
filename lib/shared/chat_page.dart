import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';

class ChatPage extends StatefulWidget {
  final String? initialTargetId;
  final String? initialTargetName;

  const ChatPage({
    super.key,
    this.initialTargetId,
    this.initialTargetName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final AppDataStore _store = AppDataStore();
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedTargetId;
  String _selectedTargetName = '';
  String _selectedTargetSubtitle = '';
  String _selectedTargetType = 'client'; // 'client' or 'employee'
  String _selectedTargetEmail = '';
  String _selectedTargetPhone = '';
  
  String? _activeConversationId;
  bool _isLoadingConversation = false;
  String _searchQuery = '';
  bool _showProfileInfo = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
    _store.refreshFromSupabase();

    if (widget.initialTargetId != null) {
      _selectTarget(
        widget.initialTargetId!,
        widget.initialTargetName ?? 'Contact',
        '',
        'employee',
      );
    }
  }

  Future<void> _selectTarget(String id, String name, String subtitle, String type, [String email = '', String phone = '']) async {
    if (!mounted) return;
    setState(() {
      _selectedTargetId = id;
      _selectedTargetName = name;
      _selectedTargetSubtitle = subtitle;
      _selectedTargetType = type;
      _selectedTargetEmail = email;
      _selectedTargetPhone = phone;
      _isLoadingConversation = true;
    });

    final convId = await SupabaseService().getOrCreateDirectConversation(id);
    
    if (mounted) {
      setState(() {
        _activeConversationId = convId;
        _isLoadingConversation = false;
      });
    }
  }

  void _backToInbox() {
    setState(() {
      _selectedTargetId = null;
      _activeConversationId = null;
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

  Future<void> _sendMessage() async {
    if (_activeConversationId == null) return;
    
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    
    await SupabaseService().sendChatMessage(_activeConversationId!, text);

    Future.delayed(const Duration(milliseconds: 250), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Map<String, String> _getSenderInfo(String senderId, bool isClient) {
    if (senderId == Supabase.instance.client.auth.currentUser?.id) {
      return {'name': 'Me', 'role': isClient ? 'client' : 'admin'};
    }
    for (final c in _store.clients) {
      if (c.id == senderId) return {'name': c.name, 'role': 'client'};
    }
    for (final e in _store.employees) {
      if (e.id == senderId) return {'name': e.name, 'role': e.role};
    }
    for (final a in _store.admins) {
      if (a.id == senderId) return {'name': a.name, 'role': 'admin'};
    }
    return {'name': 'User', 'role': 'user'};
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in to use Chat')));
    }

    final currentRole = SupabaseService().getUserRole(user);
    final isClient = currentRole == 'client';
    final canPop = Navigator.of(context).canPop();

    // ─────────────────────────────────────────────────────────────────────────
    // SCREEN STATE 1: PROFESSIONAL ENTERPRISE MESSAGES INBOX (ALL PEOPLE LISTED DOWN)
    // ─────────────────────────────────────────────────────────────────────────
    if (_selectedTargetId == null) {
      final filteredEmployees = _store.employees.where((e) {
        final q = _searchQuery.toLowerCase();
        return e.name.toLowerCase().contains(q) || e.role.toLowerCase().contains(q);
      }).toList();

      final filteredClients = _store.clients.where((c) {
        final q = _searchQuery.toLowerCase();
        return c.name.toLowerCase().contains(q) || c.company.toLowerCase().contains(q);
      }).toList();

      Widget inboxView = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            children: [
              // Enterprise Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search employees or client accounts...',
                    prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),

              // CONTINUOUS LIST OF ALL PEOPLE (EMPLOYEES & CLIENTS LISTED DOWN)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // Employees Category Header
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: Text(
                        'EMPLOYEES & HR TEAM',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepPurple, letterSpacing: 0.8),
                      ),
                    ),
                    if (filteredEmployees.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No employee contacts found', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...filteredEmployees.map((e) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.orange.shade50,
                                child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : 'E', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 16)),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                ),
                              ),
                            ],
                          ),
                          title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Text('${e.role} • ${e.department}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                            child: const Text('Staff', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          onTap: () => _selectTarget(e.userId.isNotEmpty ? e.userId : e.id, e.name, e.role, 'employee', e.email, e.phone),
                        ),
                      )),

                    const SizedBox(height: 16),

                    // Clients Category Header
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: Text(
                        'CLIENTS & BUSINESS ACCOUNTS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue, letterSpacing: 0.8),
                      ),
                    ),
                    if (filteredClients.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No client accounts found', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...filteredClients.map((c) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.blue.shade50,
                                child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                ),
                              ),
                            ],
                          ),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Text('${c.company} • ${c.email}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                            child: const Text('Client', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          onTap: () => _selectTarget(c.id, c.name, c.company, 'client', c.email, c.phone),
                        ),
                      )),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      if (canPop) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Enterprise Messages', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          body: inboxView,
        );
      }
      return inboxView;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SCREEN STATE 2: ACTIVE ENTERPRISE CONVERSATION THREAD
    // ─────────────────────────────────────────────────────────────────────────
    Widget conversationView = Column(
      children: [
        // Professional Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
                tooltip: 'Back to all chats',
                onPressed: _backToInbox,
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: _selectedTargetType == 'client' ? Colors.blue : Colors.deepOrange,
                child: Text(
                  _selectedTargetName.isNotEmpty ? _selectedTargetName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _showProfileInfo = !_showProfileInfo),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedTargetName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Active • ${_selectedTargetSubtitle.isNotEmpty ? _selectedTargetSubtitle : _selectedTargetType.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(_showProfileInfo ? Icons.info : Icons.info_outline, color: Colors.deepPurple),
                tooltip: 'Contact Information',
                onPressed: () => setState(() => _showProfileInfo = !_showProfileInfo),
              ),
            ],
          ),
        ),

        // Conversation Window + Profile Info Drawer
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF121218) : const Color(0xFFF4F6FA),
                  child: _isLoadingConversation
                      ? const Center(child: CircularProgressIndicator())
                      : _activeConversationId == null
                          ? const Center(child: Text('Loading conversation...'))
                          : StreamBuilder<List<ChatMessage>>(
                              stream: SupabaseService().getMessagesStream(_activeConversationId!),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (snapshot.hasError) {
                                  return Center(child: Text('Error loading messages: ${snapshot.error}'));
                                }

                                final messages = snapshot.data ?? [];

                                if (messages.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.mark_chat_unread_outlined, size: 50, color: Colors.grey),
                                        const SizedBox(height: 12),
                                        Text('Encrypted Channel with $_selectedTargetName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        const Text('Send a message below to start chatting', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  );
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
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = messages[index];
                                    final isMe = msg.senderId == user.id;
                                    final senderInfo = _getSenderInfo(msg.senderId, isClient);

                                    return Align(
                                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? Colors.deepPurple
                                              : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF262630) : Colors.white),
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                                          ),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                          children: [
                                            if (!isMe)
                                              Text(
                                                '${senderInfo['name']} • ${senderInfo['role']?.toUpperCase()}',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                                              ),
                                            if (!isMe) const SizedBox(height: 3),
                                            Text(
                                              msg.message,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isMe ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              msg.createdAt.contains('T') ? msg.createdAt.split('T')[1].substring(0, 5) : msg.createdAt,
                                              style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                ),
              ),

              if (_showProfileInfo)
                Container(
                  width: 250,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(left: BorderSide(color: Colors.grey.withOpacity(0.15))),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.deepPurple.shade100,
                        child: Text(_selectedTargetName.isNotEmpty ? _selectedTargetName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                      ),
                      const SizedBox(height: 12),
                      Text(_selectedTargetName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                      Text(_selectedTargetSubtitle, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                      const Divider(height: 24),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.email_outlined, size: 18, color: Colors.deepPurple),
                        title: const Text('Email', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        subtitle: Text(_selectedTargetEmail.isNotEmpty ? _selectedTargetEmail : 'contact@org.com', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.phone_outlined, size: 18, color: Colors.deepPurple),
                        title: const Text('Phone', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        subtitle: Text(_selectedTargetPhone.isNotEmpty ? _selectedTargetPhone : '+1 (555) 019-2831', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Enterprise Message Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Write a message...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C36) : const Color(0xFFF0F0F8),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Send'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (canPop) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_selectedTargetName, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: conversationView,
      );
    }

    return conversationView;
  }
}
