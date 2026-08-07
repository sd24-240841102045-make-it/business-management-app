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
  String _selectedTargetRole = 'employee';

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
    _store.refreshFromSupabase();

    if (widget.initialTargetId != null) {
      _selectedTargetId = widget.initialTargetId;
      _selectedTargetName = widget.initialTargetName ?? 'Account Manager';
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
    if (mounted) setState(() {});
  }

  void _sendMessage(User currentUser, String currentRole) {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final senderName = currentUser.userMetadata?['full_name'] ?? currentUser.email ?? 'User';
    final targetId = _selectedTargetId ?? 'ALL';
    final targetName = _selectedTargetName;

    final msg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUser.id,
      senderName: senderName,
      senderRole: currentRole,
      receiverId: targetId,
      receiverName: targetName,
      message: text,
      createdAt: DateTime.now().toIso8601String(),
    );

    _store.addChatMessage(msg);
    _msgController.clear();

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to use Chat'));
    }

    final currentRole = SupabaseService().getUserRole(user);
    final isClient = currentRole == 'client';

    // Auto-select contact if not set
    if (_selectedTargetId == null) {
      if (isClient) {
        // Find assigned manager or admin
        ClientModel? client;
        for (final c in _store.clients) {
          if (c.email.toLowerCase() == user.email?.toLowerCase() || c.id == user.id) {
            client = c;
            break;
          }
        }
        _selectedTargetId = client?.assignedEmployeeId ?? 'ADMIN_GENERAL';
        _selectedTargetName = client?.assignedEmployeeName ?? 'Account Manager & Operations';
      } else {
        if (_store.clients.isNotEmpty) {
          _selectedTargetId = _store.clients.first.id;
          _selectedTargetName = _store.clients.first.name;
        } else if (_store.employees.isNotEmpty) {
          _selectedTargetId = _store.employees.first.id;
          _selectedTargetName = _store.employees.first.name;
        } else {
          _selectedTargetId = 'ALL';
          _selectedTargetName = 'General Channel';
        }
      }
    }

    // Filter relevant messages
    final messages = _store.chatMessages.where((m) {
      if (isClient) {
        return m.senderId == user.id || m.receiverId == user.id || m.receiverId == 'ALL' || m.senderId == _selectedTargetId;
      } else {
        return m.senderId == _selectedTargetId || m.receiverId == _selectedTargetId || m.senderId == user.id;
      }
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width >= 900;
        final bool isTablet = width >= 600 && width < 900;
        final double horizontalPadding = isDesktop ? 40 : isTablet ? 24 : 16;

        return RefreshIndicator(
          onRefresh: () async {
            await _store.refreshFromSupabase();
          },
          child: Center(
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
                                setState(() {
                                  _selectedTargetId = val['id'];
                                  _selectedTargetName = val['name'] ?? 'Contact';
                                });
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
                        child: messages.isEmpty
                            ? Center(
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
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final msg = messages[index];
                                  final isMe = msg.senderId == user.id;

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
                                              '${msg.senderName} (${msg.senderRole.toUpperCase()})',
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
                              onSubmitted: (_) => _sendMessage(user, currentRole),
                              decoration: const InputDecoration(
                                hintText: 'Type your message...',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: isClient ? Colors.indigo : Colors.deepPurple,
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.white, size: 20),
                              onPressed: () => _sendMessage(user, currentRole),
                            ),
                          ),
                        ],
                      ),
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
}
