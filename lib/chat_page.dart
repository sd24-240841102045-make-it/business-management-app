import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/app_data_store.dart';
import 'services/supabase_service.dart';

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
  final ScrollController _scrollController = ScrollController();

  String? _selectedTargetId;
  String _selectedTargetName = 'Select Contact';
  
  String? _activeConversationId;
  bool _isLoadingConversation = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
    _store.refreshFromSupabase();

    _initializeTarget();
  }
  
  Future<void> _initializeTarget() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    final currentRole = SupabaseService().getUserRole(user);
    final isClient = currentRole == 'client';
    
    String? targetId = widget.initialTargetId;
    String? targetName = widget.initialTargetName;
    
    if (targetId == null) {
      if (isClient) {
        // Find assigned manager or admin
        ClientModel? client;
        for (final c in _store.clients) {
          if (c.email.toLowerCase() == user.email?.toLowerCase() || c.id == user.id) {
            client = c;
            break;
          }
        }
        targetId = client?.assignedEmployeeId;
        targetName = client?.assignedEmployeeName ?? 'Account Manager';
      } else {
        if (_store.clients.isNotEmpty) {
          targetId = _store.clients.first.id;
          targetName = _store.clients.first.name;
        } else if (_store.employees.isNotEmpty) {
          targetId = _store.employees.first.id;
          targetName = _store.employees.first.name;
        }
      }
    }
    
    if (targetId != null && _selectedTargetId == null) {
      await _selectTarget(targetId, targetName ?? 'Contact');
    }
  }

  Future<void> _selectTarget(String id, String name) async {
    if (!mounted) return;
    setState(() {
      _selectedTargetId = id;
      _selectedTargetName = name;
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

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) {
      setState(() {});
      if (_selectedTargetId == null && !_store.isLoadingFromSupabase) {
        _initializeTarget();
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_activeConversationId == null) return;
    
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    
    await SupabaseService().sendChatMessage(_activeConversationId!, text);

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Helper to map senderId to real name/role
  Map<String, String> _getSenderInfo(String senderId, bool isClient) {
    if (senderId == Supabase.instance.client.auth.currentUser?.id) {
      return {'name': 'Me', 'role': isClient ? 'client' : 'admin'};
    }
    // Check clients
    for (final c in _store.clients) {
      if (c.id == senderId) return {'name': c.name, 'role': 'client'};
    }
    // Check employees
    for (final e in _store.employees) {
      if (e.id == senderId) return {'name': e.name, 'role': e.role};
    }
    // Check admins
    for (final a in _store.admins) {
      if (a.id == senderId) return {'name': a.name, 'role': 'admin'};
    }
    return {'name': 'User', 'role': 'user'};
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to use Chat'));
    }

    final currentRole = SupabaseService().getUserRole(user);
    final isClient = currentRole == 'client';

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width >= 900;
        final bool isTablet = width >= 600 && width < 900;
        final double horizontalPadding = isDesktop ? 40 : isTablet ? 24 : 16;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              child: Column(
                children: [
                  // Chat Contact Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isClient ? Colors.indigo : Colors.deepPurple,
                          child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chatting With', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                _selectedTargetName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        if (!isClient) ...[
                          PopupMenuButton<Map<String, String>>(
                            icon: const Icon(Icons.person_search),
                            tooltip: 'Select Contact',
                            onSelected: (val) {
                              _selectTarget(val['id']!, val['name'] ?? 'Contact');
                            },
                            itemBuilder: (context) {
                              final items = <PopupMenuEntry<Map<String, String>>>[];
                              items.add(const PopupMenuItem(
                                enabled: false,
                                child: Text('CLIENTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                              ));
                              for (final c in _store.clients) {
                                items.add(PopupMenuItem(
                                  value: {'id': c.id, 'name': c.name},
                                  child: Text('🏢 ${c.name} (${c.company})'),
                                ));
                              }
                              items.add(const PopupMenuItem(
                                enabled: false,
                                child: Text('EMPLOYEES / STAFF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                              ));
                              for (final e in _store.employees) {
                                items.add(PopupMenuItem(
                                  value: {'id': e.id, 'name': e.name},
                                  child: Text('👤 ${e.name} (${e.role})'),
                                ));
                              }
                              return items;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Chat Messages List
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isLoadingConversation
                          ? const Center(child: CircularProgressIndicator())
                          : _activeConversationId == null
                              ? Center(
                                  child: Text(
                                    'Select a contact to start chatting.',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                )
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
                                            Icon(Icons.forum_outlined, size: 60, color: Colors.grey.shade400),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No messages yet with $_selectedTargetName.\nSend a message below to start chatting!',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    
                                    // Auto scroll to bottom when new messages arrive
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
                                            margin: const EdgeInsets.symmetric(vertical: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                            decoration: BoxDecoration(
                                              color: isMe
                                                  ? (isClient ? Colors.indigo : Colors.deepPurple)
                                                  : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C36) : const Color(0xFFF0F0F8)),
                                              borderRadius: BorderRadius.only(
                                                topLeft: const Radius.circular(16),
                                                topRight: const Radius.circular(16),
                                                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                              children: [
                                                if (!isMe)
                                                  Text(
                                                    '${senderInfo['name']} (${senderInfo['role']?.toUpperCase()})',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isMe ? Colors.white70 : Colors.indigo,
                                                    ),
                                                  ),
                                                if (!isMe) const SizedBox(height: 4),
                                                Text(
                                                  msg.message,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: isMe
                                                        ? Colors.white
                                                        : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  msg.createdAt.contains('T')
                                                      ? msg.createdAt.split('T')[1].substring(0, 5)
                                                      : msg.createdAt,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isMe ? Colors.white70 : Colors.grey,
                                                  ),
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
                  const SizedBox(height: 14),

                  // Chat Input Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            enabled: _activeConversationId != null,
                            decoration: InputDecoration(
                              hintText: _activeConversationId != null ? 'Type an encrypted message...' : 'Waiting for connection...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: isClient ? Colors.indigo : Colors.deepPurple,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: _activeConversationId != null ? _sendMessage : null,
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
      },
    );
  }
}
