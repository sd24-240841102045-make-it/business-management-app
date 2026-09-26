import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/core/premium_theme.dart';
import 'package:business_managment_app/models/chat_models.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/messaging_service.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/widgets/chat/conversation_tile.dart';
import 'package:business_managment_app/widgets/chat/message_bubble.dart';
import 'package:business_managment_app/widgets/chat/message_input.dart';

class ChatPage extends StatefulWidget {
  final String? initialTargetId;
  final String? initialTargetName;
  final String? initialTargetSubtitle;
  final String? initialTargetType; // 'employee', 'client', 'admin'
  final String? initialTargetEmail;
  final String? initialTargetPhone;
  final String? initialProjectId;
  final String? initialProjectTitle;

  const ChatPage({
    super.key,
    this.initialTargetId,
    this.initialTargetName,
    this.initialTargetSubtitle,
    this.initialTargetType,
    this.initialTargetEmail,
    this.initialTargetPhone,
    this.initialProjectId,
    this.initialProjectTitle,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final MessagingService _messagingService = MessagingService();
  final AppDataStore _store = AppDataStore();

  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _inChatSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // In-chat search state
  bool _showInChatSearch = false;
  String _inChatSearchQuery = '';

  // Active conversation state
  String? _activeConversationId;
  String? _selectedTargetId;
  String? _activeProjectId;
  String _selectedTargetName = '';
  String _selectedTargetSubtitle = '';
  String _selectedTargetType = 'client'; // 'employee', 'client', 'admin', 'project'
  String _selectedTargetEmail = '';
  String _selectedTargetPhone = '';

  Stream<List<ChatMessageModel>>? _messagesStream;
  Stream<Set<String>>? _typingStream;
  String? _streamedConversationId;

  bool _isLoadingConversation = false;
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;
  bool _showProfileInfo = false;
  bool _showScrollToBottom = false;
  bool _isSending = false;

  String _searchQuery = '';
  int _inboxTab = 0; // 0 = Directory, 1 = Recent Chats

  List<ConversationModel> _recentConversations = [];
  bool _loadingRecentChats = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
    _store.refreshFromSupabase();

    _scrollController.addListener(_onScroll);
    _loadRecentConversations();

    if (widget.initialProjectId != null) {
      _selectProject(
        widget.initialProjectId!,
        widget.initialProjectTitle ?? 'Project Chat',
      );
    } else if (widget.initialTargetId != null) {
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

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _msgController.dispose();
    _searchController.dispose();
    _inChatSearchController.dispose();
    _store.removeListener(_onStoreUpdate);

    if (_activeConversationId != null) {
      _messagingService.sendTyping(_activeConversationId!, isTyping: false);
      _messagingService.unsubscribeFromConversation(_activeConversationId!);
    }

    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRecentConversations() async {
    if (!mounted) return;
    setState(() => _loadingRecentChats = true);

    final convs = await _messagingService.getConversations();

    if (mounted) {
      setState(() {
        _recentConversations = convs;
        _loadingRecentChats = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final isNearBottom = (maxScroll - currentScroll) < 150;

    if (_showScrollToBottom != !isNearBottom) {
      setState(() => _showScrollToBottom = !isNearBottom);
    }

    if (currentScroll <= 60 && !_isLoadingOlder && _hasMoreOlder && _activeConversationId != null) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    final convId = _activeConversationId;
    if (convId == null || _isLoadingOlder || !_hasMoreOlder) return;

    final prevMaxScroll = _scrollController.hasClients ? _scrollController.position.maxScrollExtent : 0.0;
    final prevPixels = _scrollController.hasClients ? _scrollController.position.pixels : 0.0;

    setState(() => _isLoadingOlder = true);

    final cached = _messagingService.loadInitialMessages(convId);
    final messages = await cached;
    if (messages.isEmpty) {
      if (mounted) setState(() => _isLoadingOlder = false);
      return;
    }

    final oldestTimestamp = messages.first.createdAt;
    final older = await _messagingService.loadOlderMessages(
      convId,
      beforeTimestamp: oldestTimestamp,
      limit: 30,
    );

    if (mounted) {
      setState(() {
        _isLoadingOlder = false;
        if (older.isEmpty || older.length < 30) {
          _hasMoreOlder = false;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final newMaxScroll = _scrollController.position.maxScrollExtent;
          final diff = newMaxScroll - prevMaxScroll;
          if (diff > 0) {
            _scrollController.jumpTo(prevPixels + diff);
          }
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // PROJECT-BASED CHAT SELECTION
  // ---------------------------------------------------------------------------
  Future<void> _selectProject(String projectId, String projectTitle) async {
    if (!mounted) return;

    if (_activeConversationId != null) {
      _messagingService.sendTyping(_activeConversationId!, isTyping: false);
      _messagingService.unsubscribeFromConversation(_activeConversationId!);
    }

    setState(() {
      _activeProjectId = projectId;
      _selectedTargetId = projectId;
      _selectedTargetName = projectTitle;
      _selectedTargetSubtitle = 'Project Communications';
      _selectedTargetType = 'project';
      _selectedTargetEmail = '';
      _selectedTargetPhone = '';
      _isLoadingConversation = true;
      _showProfileInfo = false;
      _hasMoreOlder = true;
    });

    final convId = await _messagingService.getOrCreateProjectConversation(
      projectId,
      projectTitle: projectTitle,
    );

    if (mounted && convId != null) {
      setState(() {
        _activeConversationId = convId;
        _isLoadingConversation = false;
        _streamedConversationId = convId;
        _messagesStream = _messagingService.getMessagesStream(convId);
        _typingStream = _messagingService.getTypingStream(convId);
      });
      _scrollToBottom(smooth: false);
    }
  }

  // ---------------------------------------------------------------------------
  // DIRECT USER CHAT SELECTION (RELATIONSHIP CONTROLLED)
  // ---------------------------------------------------------------------------
  void _showCommunicationRestrictionDialog({
    required String targetId,
    required String targetName,
    required String targetRole,
    String? email,
  }) {
    final myRole = SupabaseService().currentRole.toLowerCase();
    final isAdmin = myRole == 'admin' || myRole == 'owner';
    final sharedProjects = _messagingService.getSharedProjects(targetId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPremiumSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: kPremiumBorder),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPremiumDanger.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_person_outlined, color: kPremiumDanger, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Direct Chat Restricted',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPremiumText),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Direct 1-on-1 messaging with $targetName (${targetRole.toUpperCase()}) is restricted under current organizational communication policies.',
              style: const TextStyle(color: kPremiumMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),

            // Shared Project Rectification Option
            if (sharedProjects.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kPremiumGold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPremiumGold.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.hub_outlined, size: 16, color: kPremiumGold),
                        SizedBox(width: 6),
                        Text(
                          'Available Shared Project Channel',
                          style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You and $targetName collaborate on "${sharedProjects.first.name}". You can communicate securely through that project thread.',
                      style: const TextStyle(color: kPremiumText, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: Text('Open ${sharedProjects.first.name} Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPremiumGold,
                          foregroundColor: kPremiumBg,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _selectProject(sharedProjects.first.id, sharedProjects.first.name);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: kPremiumBlue),
                        SizedBox(width: 6),
                        Text(
                          'Policy Reason & Guidance',
                          style: TextStyle(color: kPremiumBlue, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      myRole == 'client'
                          ? 'Client accounts are organized around projects. Specialists can be contacted directly once assigned to an active project or client account.'
                          : 'Direct communication between these roles requires an active project assignment or permission from an organization administrator.',
                      style: const TextStyle(color: kPremiumMuted, fontSize: 11.5, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (isAdmin)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showCommunicationSettingsDialog();
              },
              child: const Text('Configure Policies', style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold)),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white12,
              foregroundColor: Colors.white,
            ),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
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

    if (_activeConversationId != null) {
      _messagingService.sendTyping(_activeConversationId!, isTyping: false);
      _messagingService.unsubscribeFromConversation(_activeConversationId!);
    }

    // Check business relationship permission
    final canChat = await _messagingService.canDirectChatWith(
      targetUserId: id,
      targetRole: type,
    );

    if (!canChat) {
      if (mounted) {
        _showCommunicationRestrictionDialog(
          targetId: id,
          targetName: name,
          targetRole: type,
          email: email,
        );
      }
      return;
    }

    String resolvedEmail = email.trim();
    String resolvedPhone = phone.trim();

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
      _activeProjectId = null;
      _selectedTargetId = id;
      _selectedTargetName = name;
      _selectedTargetSubtitle = subtitle;
      _selectedTargetType = type;
      _selectedTargetEmail = resolvedEmail;
      _selectedTargetPhone = resolvedPhone;
      _isLoadingConversation = true;
      _showProfileInfo = false;
      _hasMoreOlder = true;
    });

    final convId = await _messagingService.getOrCreateDirectConversation(id, targetName: name);

    if (mounted) {
      setState(() {
        _activeConversationId = convId;
        _isLoadingConversation = false;
        _streamedConversationId = convId;
        _messagesStream = _messagingService.getMessagesStream(convId);
        _typingStream = _messagingService.getTypingStream(convId);
      });
      _scrollToBottom(smooth: false);
    }
  }

  void _selectConversationModel(ConversationModel conv) {
    if (!mounted) return;

    if (_activeConversationId != null) {
      _messagingService.sendTyping(_activeConversationId!, isTyping: false);
      _messagingService.unsubscribeFromConversation(_activeConversationId!);
    }

    if (conv.isProjectChat) {
      setState(() {
        _activeProjectId = conv.projectId;
        _selectedTargetId = conv.projectId ?? conv.id;
        _selectedTargetName = conv.title.isNotEmpty ? conv.title : 'Project Chat';
        _selectedTargetSubtitle = 'Project Communications';
        _selectedTargetType = 'project';
        _activeConversationId = conv.id;
        _streamedConversationId = conv.id;
        _messagesStream = _messagingService.getMessagesStream(conv.id);
        _typingStream = _messagingService.getTypingStream(conv.id);
        _hasMoreOlder = true;
        _showProfileInfo = false;
      });
    } else {
      final myId = _messagingService.currentUserId;
      final otherMember = conv.members.firstWhere(
        (m) => m.userId != myId,
        orElse: () => conv.members.isNotEmpty ? conv.members.first : ConversationMemberModel(
          id: '',
          conversationId: conv.id,
          userId: '',
          joinedAt: DateTime.now(),
          lastReadAt: DateTime.now(),
        ),
      );

      setState(() {
        _activeProjectId = null;
        _selectedTargetId = otherMember.userId.isNotEmpty ? otherMember.userId : conv.id;
        _selectedTargetName = conv.title.isNotEmpty ? conv.title : (otherMember.fullName ?? 'Direct Conversation');
        _selectedTargetSubtitle = otherMember.role ?? conv.conversationType.name;
        _selectedTargetType = otherMember.role?.toLowerCase() ?? 'user';
        _activeConversationId = conv.id;
        _streamedConversationId = conv.id;
        _messagesStream = _messagingService.getMessagesStream(conv.id);
        _typingStream = _messagingService.getTypingStream(conv.id);
        _hasMoreOlder = true;
        _showProfileInfo = false;
      });
    }

    _messagingService.markAsRead(conv.id);
    _scrollToBottom(smooth: false);
  }

  void _backToInbox() {
    if (_activeConversationId != null) {
      _messagingService.sendTyping(_activeConversationId!, isTyping: false);
      _messagingService.unsubscribeFromConversation(_activeConversationId!);
    }

    setState(() {
      _selectedTargetId = null;
      _activeProjectId = null;
      _activeConversationId = null;
      _streamedConversationId = null;
      _messagesStream = null;
      _typingStream = null;
      _showProfileInfo = false;
    });

    _loadRecentConversations();
  }

  Future<void> _sendMessage([String? predefinedText]) async {
    final textToSend = predefinedText ?? _msgController.text.trim();
    if (textToSend.isEmpty || _isSending) return;

    if (_activeConversationId == null && _selectedTargetId != null) {
      if (_selectedTargetType == 'project' && _activeProjectId != null) {
        final fallbackConv = await _messagingService.getOrCreateProjectConversation(_activeProjectId!);
        if (mounted) setState(() => _activeConversationId = fallbackConv);
      } else {
        final fallbackConv = await _messagingService.getOrCreateDirectConversation(_selectedTargetId!);
        if (mounted) setState(() => _activeConversationId = fallbackConv);
      }
    }

    final convId = _activeConversationId;
    if (convId == null) return;

    if (predefinedText == null) {
      _msgController.clear();
    }

    setState(() => _isSending = true);

    await _messagingService.sendMessage(
      conversationId: convId,
      content: textToSend,
    );

    if (mounted) {
      setState(() => _isSending = false);
    }

    _scrollToBottom(smooth: true);
  }

  void _scrollToBottom({bool smooth = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (smooth) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
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
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  // ---------------------------------------------------------------------------
  // MESSAGE RETRY, EDIT & DELETE ACTIONS
  // ---------------------------------------------------------------------------
  Future<void> _handleRetryMessage(ChatMessageModel msg) async {
    final convId = _activeConversationId;
    if (convId == null) return;

    final result = await _messagingService.retrySendMessage(
      conversationId: convId,
      failedMessage: msg,
    );

    if (result == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Message delivery failed. Please check your connection or organization permissions.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: kPremiumDanger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _handleRetryMessage(msg),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleEditMessage(ChatMessageModel msg) async {
    final editCtrl = TextEditingController(text: msg.message);
    final convId = _activeConversationId;
    if (convId == null) return;

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPremiumSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: kPremiumBorder)),
        title: const Text('Edit Message', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          style: const TextStyle(color: kPremiumText),
          decoration: InputDecoration(
            hintText: 'Edit your message...',
            hintStyle: const TextStyle(color: kPremiumMuted),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumGold)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kPremiumMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = editCtrl.text.trim();
              if (text.isNotEmpty && text != msg.message) {
                Navigator.pop(ctx, text);
              } else {
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPremiumGold, foregroundColor: kPremiumBg),
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty && mounted) {
      final success = await _messagingService.editMessage(convId, msg.id, updated);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to edit message. Please check organization permissions.'), backgroundColor: kPremiumDanger),
        );
      }
    }
  }

  Future<void> _handleDeleteMessage(ChatMessageModel msg) async {
    final convId = _activeConversationId;
    if (convId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPremiumSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: kPremiumBorder)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: kPremiumDanger, size: 24),
            SizedBox(width: 8),
            Text('Delete Message?', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this message? It will be marked as deleted in the chat thread.',
          style: TextStyle(color: kPremiumMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kPremiumMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kPremiumDanger, foregroundColor: Colors.white),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await _messagingService.deleteMessage(convId, msg.id, softDelete: true);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete message. Retention policy may restrict deletion.'), backgroundColor: kPremiumDanger),
        );
      }
    }
  }

  Future<void> _confirmClearMessages() async {
    final convId = _activeConversationId;
    if (convId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPremiumSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: kPremiumBorder)),
        title: const Text('Clear Chat History?', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
        content: const Text(
          'This will clear all messages in this conversation thread for everyone.',
          style: TextStyle(color: kPremiumMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kPremiumMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _messagingService.clearMessages(convId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat messages cleared'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _confirmDeleteConversation([String? targetConvId]) async {
    final convId = targetConvId ?? _activeConversationId;
    if (convId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPremiumSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: kPremiumBorder)),
        title: const Text('Delete Entire Chat?', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumDanger)),
        content: const Text(
          'Are you sure you want to permanently delete this chat thread and all its history?',
          style: TextStyle(color: kPremiumMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kPremiumMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kPremiumDanger, foregroundColor: Colors.white),
            child: const Text('Delete Chat', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _messagingService.deleteConversation(convId);
      if (_activeConversationId == convId) {
        _backToInbox();
      } else {
        _loadRecentConversations();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat thread deleted successfully'), backgroundColor: Colors.green),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ADMIN COMMUNICATION SETTINGS MODAL
  // ---------------------------------------------------------------------------
  Future<void> _showCommunicationSettingsDialog() async {
    final currentSettings = await _messagingService.getCommunicationSettings();
    bool enableEmpClient = currentSettings.enableEmployeeClientMessaging;
    bool restrictToProjects = currentSettings.restrictClientToProjects;
    bool allowEmpEmp = currentSettings.allowEmployeeEmployeeChat;
    bool showContact = currentSettings.showBusinessContactInfo;
    bool allowDeletion = currentSettings.allowMessageDeletion;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: kPremiumBg2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kPremiumBorder)),
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: kPremiumGold, size: 22),
                  SizedBox(width: 10),
                  Text('Communication Settings', style: TextStyle(color: kPremiumText, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Configure organizational relationship permissions. Changes take effect immediately via database policies.',
                      style: TextStyle(color: kPremiumMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      activeColor: kPremiumGold,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Restrict Client Chat to Assigned Projects', style: TextStyle(color: kPremiumText, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Clients can only communicate with employees assigned to their workflows', style: TextStyle(color: kPremiumMuted, fontSize: 11)),
                      value: restrictToProjects,
                      onChanged: (val) => setModalState(() => restrictToProjects = val),
                    ),
                    const Divider(color: Colors.white10),
                    SwitchListTile(
                      activeColor: kPremiumGold,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Employee-Client Messaging', style: TextStyle(color: kPremiumText, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Allows communication between authorized project members and clients', style: TextStyle(color: kPremiumMuted, fontSize: 11)),
                      value: enableEmpClient,
                      onChanged: (val) => setModalState(() => enableEmpClient = val),
                    ),
                    const Divider(color: Colors.white10),
                    SwitchListTile(
                      activeColor: kPremiumGold,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow Employee-to-Employee Chat', style: TextStyle(color: kPremiumText, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Permits direct messaging between internal team members', style: TextStyle(color: kPremiumMuted, fontSize: 11)),
                      value: allowEmpEmp,
                      onChanged: (val) => setModalState(() => allowEmpEmp = val),
                    ),
                    const Divider(color: Colors.white10),
                    SwitchListTile(
                      activeColor: kPremiumGold,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show Business Contact Details', style: TextStyle(color: kPremiumText, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Display official role and business contact info on profiles', style: TextStyle(color: kPremiumMuted, fontSize: 11)),
                      value: showContact,
                      onChanged: (val) => setModalState(() => showContact = val),
                    ),
                    const Divider(color: Colors.white10),
                    SwitchListTile(
                      activeColor: kPremiumDanger,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow Message Deletion', style: TextStyle(color: kPremiumText, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Disabling keeps business project records intact for audit history', style: TextStyle(color: kPremiumMuted, fontSize: 11)),
                      value: allowDeletion,
                      onChanged: (val) => setModalState(() => allowDeletion = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: kPremiumMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kPremiumGold, foregroundColor: kPremiumBg),
                  onPressed: () async {
                    final updated = CommunicationSettingsModel(
                      id: currentSettings.id,
                      organizationId: currentSettings.organizationId,
                      enableEmployeeClientMessaging: enableEmpClient,
                      restrictClientToProjects: restrictToProjects,
                      allowEmployeeEmployeeChat: allowEmpEmp,
                      showBusinessContactInfo: showContact,
                      allowMessageDeletion: allowDeletion,
                    );
                    await _messagingService.updateCommunicationSettings(updated);
                    if (context.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Communication settings saved successfully')),
                      );
                      setState(() {});
                    }
                  },
                  child: const Text('Save Policy', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _messagingService.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to access Communications', style: TextStyle(color: kPremiumText)),
        ),
      );
    }

    final canPop = Navigator.of(context).canPop();

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: canPop
            ? AppBar(
                title: const Text(
                  'Enterprise Communications',
                  style: TextStyle(fontWeight: FontWeight.w800, color: kPremiumGold, letterSpacing: 0.3),
                ),
                backgroundColor: kPremiumBg.withOpacity(0.85),
                foregroundColor: kPremiumGold,
                elevation: 0,
              )
            : null,
        body: SafeArea(
          top: !canPop,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 760;

              if (isDesktop) {
                return Row(
                  children: [
                    SizedBox(
                      width: 370,
                      child: _buildInboxView(isDesktop: true),
                    ),
                    Container(width: 1, color: kPremiumBorder),
                    Expanded(
                      child: _selectedTargetId != null
                          ? _buildConversationView(isDesktop: true, user: user)
                          : _buildEmptyWorkspaceView(),
                    ),
                  ],
                );
              } else {
                if (_selectedTargetId == null) {
                  return _buildInboxView(isDesktop: false);
                } else {
                  return _buildConversationView(isDesktop: false, user: user);
                }
              }
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INBOX & RELATIONSHIP-BASED DIRECTORY
  // ---------------------------------------------------------------------------
  Widget _buildInboxView({required bool isDesktop}) {
    final myRole = SupabaseService().currentRole.toLowerCase();
    final isAdmin = myRole == 'admin' || myRole == 'owner';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Workspace Chat',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: kPremiumText,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Row(
                    children: [
                      if (isAdmin)
                        IconButton(
                          icon: const Icon(Icons.shield_outlined, size: 20, color: kPremiumGold),
                          tooltip: 'Communication Policies',
                          onPressed: _showCommunicationSettingsDialog,
                        ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20, color: kPremiumMuted),
                        tooltip: 'Refresh',
                        onPressed: () {
                          _loadRecentConversations();
                          _store.refreshFromSupabase();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: kPremiumText, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search projects or contacts...',
                  hintStyle: const TextStyle(color: kPremiumMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: kPremiumGold, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: kPremiumMuted, size: 18),
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
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

              // Navigation Tabs
              Row(
                children: [
                  _inboxTabChip('Directory & Projects', 0),
                  const SizedBox(width: 8),
                  _inboxTabChip('Recent Chats', 1),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: _inboxTab == 0
              ? _buildControlledDirectoryList()
              : _buildRecentChatsList(),
        ),
      ],
    );
  }

  Widget _inboxTabChip(String label, int index) {
    final isSelected = _inboxTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _inboxTab = index),
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

  Widget _buildControlledDirectoryList() {
    final q = _searchQuery.toLowerCase();
    final myUserId = _messagingService.currentUserId;
    final myRole = SupabaseService().currentRole.toLowerCase();
    final isClient = myRole == 'client';
    final isEmployee = myRole == 'employee';

    // 1. Authorized Projects List
    final List<ProjectModel> authorizedProjects = _store.projects.where((p) {
      if (q.isNotEmpty && !p.name.toLowerCase().contains(q) && !p.clientName.toLowerCase().contains(q)) {
        return false;
      }
      if (isClient) {
        // Client only sees their own projects
        final clientRec = _store.clients.firstWhere(
          (c) => c.userId == myUserId || c.id == myUserId,
          orElse: () => ClientModel(id: '', name: '', company: '', email: '', phone: '', status: ''),
        );
        return p.clientId == clientRec.id;
      } else if (isEmployee) {
        // Employee only sees projects they are assigned to
        return p.teamMembers.contains(myUserId) ||
            _store.tasks.any((t) => t.projectId == p.id && t.assignedToId == myUserId);
      }
      return true; // Admin sees all projects
    }).toList();

    // 2. Authorized Admins
    final filteredAdmins = _store.admins.where((a) {
      if (myUserId != null && a.id == myUserId) return false;
      if (q.isEmpty) return true;
      return a.name.toLowerCase().contains(q) || a.email.toLowerCase().contains(q);
    }).toList();

    // 3. Authorized Employees
    final filteredEmployees = _store.employees.where((e) {
      final eUid = e.userId.isNotEmpty ? e.userId : e.id;
      if (myUserId != null && (e.userId == myUserId || e.id == myUserId)) return false;

      if (isClient) {
        // CLIENT CANNOT SEE UNRELATED EMPLOYEES
        // Client only sees employees assigned to their active projects or account manager
        final clientRec = _store.clients.firstWhere(
          (c) => c.userId == myUserId || c.id == myUserId,
          orElse: () => ClientModel(id: '', name: '', company: '', email: '', phone: '', status: ''),
        );
        if (clientRec.assignedEmployeeId == e.id || clientRec.assignedEmployeeId == e.userId) return true;
        final hasSharedProject = _store.projects.any((p) =>
            p.clientId == clientRec.id &&
            (p.teamMembers.contains(eUid) || _store.tasks.any((t) => t.projectId == p.id && t.assignedToId == eUid)));
        if (!hasSharedProject) return false;
      }

      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) || e.role.toLowerCase().contains(q);
    }).toList();

    // 4. Authorized Clients
    final filteredClients = _store.clients.where((c) {
      if (myUserId != null && (c.userId == myUserId || c.id == myUserId)) return false;

      if (isClient) {
        // CLIENTS CAN NEVER CHAT WITH OTHER CLIENTS
        return false;
      }

      if (isEmployee) {
        // EMPLOYEE ONLY SEES CLIENTS WITH WHOM THEY SHARE A WORKFLOW OR ACCOUNT
        final hasAssignment = c.assignedEmployeeId == myUserId ||
            _store.employees.any((e) => e.userId == myUserId && e.id == c.assignedEmployeeId);
        final hasProject = _store.projects.any((p) =>
            p.clientId == c.id &&
            (p.teamMembers.contains(myUserId) || _store.tasks.any((t) => t.projectId == p.id && t.assignedToId == myUserId)));
        if (!hasAssignment && !hasProject) return false;
      }

      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) || c.company.toLowerCase().contains(q);
    }).toList();

    final totalMatches = authorizedProjects.length +
        filteredAdmins.length +
        filteredEmployees.length +
        (isClient ? 0 : filteredClients.length);

    if (q.isNotEmpty && totalMatches == 0) {
      return _buildSearchEmptyState(tabIndex: 0);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Controlled Communication Notice for Clients
        if (isClient)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPremiumBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kPremiumBlue.withOpacity(0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_clock_outlined, size: 18, color: kPremiumBlue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Project-Centered Workspace: Communications are organized around your active project workflows and assigned managers.',
                    style: TextStyle(fontSize: 11, color: kPremiumMuted, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

        // 1. PRIMARY: PROJECT WORKFLOW CHATS
        if (authorizedProjects.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 6, 4, 8),
            child: Text(
              'PROJECT WORKFLOW COMMUNICATIONS',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: kPremiumGold, letterSpacing: 1.0),
            ),
          ),
          ...authorizedProjects.map((p) => ConversationTile(
            title: p.name,
            subtitle: 'Client: ${p.clientName} \u2022 ${p.status}',
            isSelected: _selectedTargetId == p.id,
            badgeLabel: 'Project',
            badgeColor: kPremiumGold,
            onTap: () => _selectProject(p.id, p.name),
          )),
        ],

        // 2. MANAGEMENT & ACCOUNT EXECUTIVES
        if (filteredAdmins.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              'MANAGEMENT & EXECUTIVE LEAD',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: kPremiumGoldSoft, letterSpacing: 1.0),
            ),
          ),
          ...filteredAdmins.map((a) => ConversationTile(
            title: a.name,
            subtitle: a.email,
            isSelected: _selectedTargetId == a.id,
            badgeLabel: 'Admin',
            badgeColor: kPremiumGold,
            onTap: () => _selectTarget(a.id, a.name, 'Admin', 'admin', a.email),
          )),
        ],

        // 3. ASSIGNED EMPLOYEES (Only shown if authorized)
        if (filteredEmployees.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              isClient ? 'ASSIGNED PROJECT SPECIALISTS' : 'TEAM MEMBERS & SPECIALISTS',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: kPremiumViolet, letterSpacing: 1.0),
            ),
          ),
          ...filteredEmployees.map((e) => ConversationTile(
            title: e.name,
            subtitle: '${e.role} \u2022 ${e.department}',
            isSelected: _selectedTargetId == (e.userId.isNotEmpty ? e.userId : e.id),
            badgeLabel: e.role.isNotEmpty ? e.role : 'Specialist',
            badgeColor: kPremiumViolet,
            onTap: () => _selectTarget(
              e.userId.isNotEmpty ? e.userId : e.id,
              e.name,
              e.role,
              'employee',
              e.email,
              e.phone,
            ),
          )),
        ],

        // 4. CLIENTS & BUSINESS ACCOUNTS (Only shown to authorized employees / admins)
        if (filteredClients.isNotEmpty && !isClient) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              'CLIENTS & BUSINESS PARTNERS',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: kPremiumBlue, letterSpacing: 1.0),
            ),
          ),
          ...filteredClients.map((c) => ConversationTile(
            title: c.name,
            subtitle: '${c.company} \u2022 ${c.email}',
            isSelected: _selectedTargetId == (c.userId != null && c.userId!.isNotEmpty ? c.userId! : c.id),
            badgeLabel: 'Client',
            badgeColor: kPremiumBlue,
            onTap: () => _selectTarget(
              c.userId != null && c.userId!.isNotEmpty ? c.userId! : c.id,
              c.name,
              c.company,
              'client',
              c.email,
              c.phone,
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildSearchEmptyState({required int tabIndex}) {
    final myRole = SupabaseService().currentRole.toLowerCase();
    final isClient = myRole == 'client';
    final isEmployee = myRole == 'employee';
    final isAdmin = myRole == 'admin' || myRole == 'owner';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kPremiumGold.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: kPremiumGold.withOpacity(0.2)),
              ),
              child: const Icon(Icons.search_off_rounded, size: 36, color: kPremiumGold),
            ),
            const SizedBox(height: 14),
            Text(
              'No matches for "$_searchQuery"',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kPremiumText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              tabIndex == 1
                  ? 'No prior conversations match your search query.'
                  : 'No contacts or projects match your search in this view.',
              style: const TextStyle(color: kPremiumMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),

            // Diagnostic card explaining visibility boundaries
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPremiumSurface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kPremiumBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: kPremiumGold),
                      SizedBox(width: 8),
                      Text(
                        'Search Diagnostics & Visibility',
                        style: TextStyle(
                          color: kPremiumGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (tabIndex == 1) ...[
                    const Text(
                      '• Recent Chats only includes conversations that already have a message history.',
                      style: TextStyle(color: kPremiumMuted, fontSize: 11.5, height: 1.35),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '• Try searching the "Directory & Projects" tab to find contacts or projects to start a new chat.',
                      style: TextStyle(color: kPremiumMuted, fontSize: 11.5, height: 1.35),
                    ),
                  ] else if (isClient) ...[
                    const Text(
                      '• Client accounts can only view active assigned projects, their designated account manager, and specialists on their active projects.',
                      style: TextStyle(color: kPremiumMuted, fontSize: 11.5, height: 1.35),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '• Unassigned staff and other client accounts are restricted to protect client confidentiality.',
                      style: TextStyle(color: kPremiumMuted, fontSize: 11.5, height: 1.35),
                    ),
                  ] else if (isEmployee) ...[
                    const Text(
                      '• Specialists and staff only view assigned projects, teammates on those projects, and clients with active task assignments.',
                      style: TextStyle(color: kPremiumMuted, fontSize: 11.5, height: 1.35),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '• If you need to communicate with this contact, request assignment to their project from management.',
                      style: TextStyle(color: kPremiumMuted, fontSize: 11.5, height: 1.35),
                    ),
                  ] else ...[
                    const Text(
                      '• Check for typos or alternative spellings in name, email, or project title.',
                      style: TextStyle(color: kPremiumMuted, fontSize: 11.5, height: 1.35),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '• Refresh the directory data to fetch recently added users or organizations.',
                      style: TextStyle(color: kPremiumMuted, fontSize: 11.5, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Actionable rectification buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Clear Search'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPremiumText,
                    side: const BorderSide(color: kPremiumBorder),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
                if (tabIndex == 1)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.people_outline_rounded, size: 16),
                    label: const Text('Search in Directory'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPremiumGold,
                      foregroundColor: kPremiumBg,
                    ),
                    onPressed: () => setState(() => _inboxTab = 0),
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.forum_outlined, size: 16),
                    label: const Text('Search in Recent Chats'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPremiumGold,
                      foregroundColor: kPremiumBg,
                    ),
                    onPressed: () => setState(() => _inboxTab = 1),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh Data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPremiumGold,
                    side: const BorderSide(color: kPremiumBorder),
                  ),
                  onPressed: () {
                    _store.refreshFromSupabase();
                    _loadRecentConversations();
                  },
                ),
                if (isAdmin)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.shield_outlined, size: 16),
                    label: const Text('Policy Settings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPremiumBlue,
                      side: const BorderSide(color: kPremiumBorder),
                    ),
                    onPressed: _showCommunicationSettingsDialog,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentChatsList() {
    if (_loadingRecentChats) {
      return const Center(child: CircularProgressIndicator(color: kPremiumGold));
    }

    if (_recentConversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 40, color: kPremiumMuted.withOpacity(0.5)),
              const SizedBox(height: 12),
              const Text(
                'No recent conversations',
                style: TextStyle(color: kPremiumText, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a project or contact from the Directory to open communication.',
                style: TextStyle(color: kPremiumMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                icon: const Icon(Icons.people_outline_rounded, size: 16),
                label: const Text('Open Directory'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPremiumGold,
                  foregroundColor: kPremiumBg,
                ),
                onPressed: () => setState(() => _inboxTab = 0),
              ),
            ],
          ),
        ),
      );
    }

    // Filter recent conversations by query
    final q = _searchQuery.trim().toLowerCase();
    final filtered = _recentConversations.where((conv) {
      if (q.isEmpty) return true;
      if (conv.title.toLowerCase().contains(q)) return true;
      if (conv.lastMessage != null && conv.lastMessage!.message.toLowerCase().contains(q)) return true;
      if (conv.members.any((m) =>
          (m.fullName?.toLowerCase().contains(q) ?? false) ||
          (m.role?.toLowerCase().contains(q) ?? false))) {
        return true;
      }
      return false;
    }).toList();

    if (q.isNotEmpty && filtered.isEmpty) {
      return _buildSearchEmptyState(tabIndex: 1);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (ctx, index) {
        final conv = filtered[index];
        final isSelected = _activeConversationId == conv.id;
        final lastMsg = conv.lastMessage;

        return GestureDetector(
          onSecondaryTap: () => _confirmDeleteConversation(conv.id),
          child: ConversationTile(
            conversation: conv,
            title: conv.title,
            subtitle: lastMsg != null
                ? (lastMsg.isDeleted ? 'Message deleted' : lastMsg.message)
                : (conv.isProjectChat ? 'Project communication thread' : 'No messages yet'),
            timeText: lastMsg != null ? _formatDateHeader(lastMsg.createdAt) : null,
            unreadCount: conv.unreadCount,
            badgeLabel: conv.isProjectChat ? 'Project' : null,
            badgeColor: conv.isProjectChat ? kPremiumGold : null,
            isSelected: isSelected,
            onTap: () => _selectConversationModel(conv),
          ),
        );
      },
    );
  }

  Widget _buildEmptyWorkspaceView() {
    return Center(
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
            'Secure Business Communications Workspace',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kPremiumText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select an assigned project or team member from the directory to start.',
            style: TextStyle(color: kPremiumMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONVERSATION VIEW & REAL-TIME STREAM
  // ---------------------------------------------------------------------------
  Widget _buildConversationView({
    required bool isDesktop,
    required User user,
  }) {
    final isProject = _selectedTargetType == 'project';

    return Column(
      children: [
        // Top Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kPremiumSurface.withOpacity(0.88),
            border: const Border(bottom: BorderSide(color: kPremiumBorder)),
          ),
          child: Row(
            children: [
              if (!isDesktop)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kPremiumGold, size: 20),
                  tooltip: 'Back to directory',
                  onPressed: _backToInbox,
                ),
              PremiumAvatar(
                label: _selectedTargetName,
                size: 40,
                radius: 13,
                style: isProject ? AvatarStyle.pattern : AvatarStyle.gradient,
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
                          Text(
                            isProject ? 'Project Workspace Channel' : 'Active Direct Session',
                            style: const TextStyle(
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
                  _showInChatSearch ? Icons.search_off_rounded : Icons.search_rounded,
                  color: _showInChatSearch ? kPremiumGold : kPremiumMuted,
                  size: 20,
                ),
                tooltip: _showInChatSearch ? 'Close Search' : 'Search in Conversation',
                onPressed: () {
                  setState(() {
                    _showInChatSearch = !_showInChatSearch;
                    if (!_showInChatSearch) {
                      _inChatSearchController.clear();
                      _inChatSearchQuery = '';
                    }
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  _showProfileInfo ? Icons.info_rounded : Icons.info_outline_rounded,
                  color: _showProfileInfo ? kPremiumGold : kPremiumMuted,
                ),
                tooltip: isProject ? 'Project Info' : 'Contact Details',
                onPressed: () => setState(() => _showProfileInfo = !_showProfileInfo),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: kPremiumMuted, size: 20),
                color: kPremiumSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: kPremiumBorder),
                ),
                onSelected: (val) {
                  if (val == 'clear') {
                    _confirmClearMessages();
                  } else if (val == 'delete_conv') {
                    _confirmDeleteConversation();
                  } else if (val == 'info') {
                    setState(() => _showProfileInfo = !_showProfileInfo);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'info',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: kPremiumGold),
                        SizedBox(width: 10),
                        Text('Channel Details', style: TextStyle(color: kPremiumText, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.cleaning_services_outlined, size: 18, color: Colors.amberAccent),
                        SizedBox(width: 10),
                        Text('Clear Messages', style: TextStyle(color: kPremiumText, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete_conv',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever_outlined, size: 18, color: kPremiumDanger),
                        SizedBox(width: 10),
                        Text('Delete Chat', style: TextStyle(color: kPremiumDanger, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // In-Chat Search Bar
        if (_showInChatSearch)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: kPremiumSurface.withOpacity(0.95),
              border: const Border(bottom: BorderSide(color: kPremiumBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: kPremiumGold, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _inChatSearchController,
                    autofocus: true,
                    style: const TextStyle(color: kPremiumText, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search messages in this conversation...',
                      hintStyle: const TextStyle(color: kPremiumMuted, fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kPremiumBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kPremiumBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kPremiumGold, width: 1.2),
                      ),
                    ),
                    onChanged: (val) => setState(() => _inChatSearchQuery = val),
                  ),
                ),
                if (_inChatSearchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16, color: kPremiumMuted),
                    tooltip: 'Clear search',
                    onPressed: () {
                      _inChatSearchController.clear();
                      setState(() => _inChatSearchQuery = '');
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: kPremiumMuted),
                  tooltip: 'Close search',
                  onPressed: () {
                    setState(() {
                      _showInChatSearch = false;
                      _inChatSearchController.clear();
                      _inChatSearchQuery = '';
                    });
                  },
                ),
              ],
            ),
          ),

        // Conversation Body + Profile Drawer
        Expanded(
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        // Messages Stream Area
                        Expanded(
                          child: _isLoadingConversation
                              ? const Center(child: CircularProgressIndicator(color: kPremiumGold))
                              : _messagesStream == null
                                  ? _buildEmptyChatState()
                                  : StreamBuilder<List<ChatMessageModel>>(
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

                                        final hasSearch = _showInChatSearch && _inChatSearchQuery.trim().isNotEmpty;
                                        final searchClean = _inChatSearchQuery.trim().toLowerCase();
                                        final matchCount = hasSearch
                                            ? messages.where((m) => !m.isDeleted && m.message.toLowerCase().contains(searchClean)).length
                                            : 0;

                                        if (!_showScrollToBottom) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (_scrollController.hasClients) {
                                              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                                            }
                                          });
                                        }

                                        return Column(
                                          children: [
                                            if (hasSearch)
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: matchCount > 0
                                                      ? kPremiumGold.withOpacity(0.12)
                                                      : kPremiumDanger.withOpacity(0.12),
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color: (matchCount > 0 ? kPremiumGold : kPremiumDanger).withOpacity(0.3),
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          matchCount > 0 ? Icons.search_rounded : Icons.info_outline_rounded,
                                                          size: 15,
                                                          color: matchCount > 0 ? kPremiumGold : kPremiumDanger,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          matchCount > 0
                                                              ? '$matchCount matching message${matchCount == 1 ? "" : "s"} found'
                                                              : 'No messages contain "$_inChatSearchQuery" in this chat',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: matchCount > 0 ? kPremiumGold : kPremiumDanger,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (matchCount == 0)
                                                      GestureDetector(
                                                        onTap: () {
                                                          _inChatSearchController.clear();
                                                          setState(() => _inChatSearchQuery = '');
                                                        },
                                                        child: const Text(
                                                          'Clear Filter',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: kPremiumMuted,
                                                            decoration: TextDecoration.underline,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            Expanded(
                                              child: ListView.builder(
                                                controller: _scrollController,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                itemCount: messages.length + (_isLoadingOlder ? 1 : 0),
                                                itemBuilder: (ctx, index) {
                                                  if (_isLoadingOlder && index == 0) {
                                                    return const Padding(
                                                      padding: EdgeInsets.symmetric(vertical: 8),
                                                      child: Center(
                                                        child: SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor: AlwaysStoppedAnimation<Color>(kPremiumGold),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  final msgIndex = _isLoadingOlder ? index - 1 : index;
                                                  final msg = messages[msgIndex];
                                                  final isMe = msg.senderId == user.id;

                                                  bool showDateDivider = false;
                                                  if (msgIndex == 0) {
                                                    showDateDivider = true;
                                                  } else {
                                                    final prev = messages[msgIndex - 1].createdAt;
                                                    if (msg.createdAt.day != prev.day ||
                                                        msg.createdAt.month != prev.month ||
                                                        msg.createdAt.year != prev.year) {
                                                      showDateDivider = true;
                                                    }
                                                  }

                                                  return Column(
                                                    children: [
                                                      if (showDateDivider)
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
                                                              _formatDateHeader(msg.createdAt),
                                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kPremiumMuted),
                                                            ),
                                                          ),
                                                        ),
                                                      MessageBubble(
                                                        message: msg,
                                                        isMe: isMe,
                                                        isDesktop: isDesktop,
                                                        showSenderHeader: !isMe,
                                                        searchQuery: _showInChatSearch ? _inChatSearchQuery : null,
                                                        onRetry: () => _handleRetryMessage(msg),
                                                        onEdit: isMe && !msg.isDeleted ? () => _handleEditMessage(msg) : null,
                                                        onDelete: !msg.isDeleted ? () => _handleDeleteMessage(msg) : null,
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                        ),

                        // Typing Indicator Banner
                        if (_typingStream != null)
                          StreamBuilder<Set<String>>(
                            stream: _typingStream,
                            builder: (context, snapshot) {
                              final typers = snapshot.data ?? {};
                              if (typers.isEmpty) return const SizedBox.shrink();

                              final typingText = typers.length == 1
                                  ? '${typers.first} is typing...'
                                  : '${typers.join(", ")} are typing...';

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                                color: kPremiumSurface.withOpacity(0.5),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(kPremiumGold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      typingText,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: kPremiumGold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                        // Message Input
                        MessageInput(
                          controller: _msgController,
                          isSending: _isSending,
                          onSend: (text) => _sendMessage(text),
                          onTypingChanged: (isTyping) {
                            if (_activeConversationId != null) {
                              _messagingService.sendTyping(_activeConversationId!, isTyping: isTyping);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  // Desktop Profile / Project Drawer
                  if (isDesktop && _showProfileInfo) _buildInfoDrawer(),
                ],
              ),

              // "New Messages" Floating Button
              if (_showScrollToBottom)
                Positioned(
                  right: 20,
                  bottom: 75,
                  child: FloatingActionButton.small(
                    backgroundColor: kPremiumGold,
                    foregroundColor: kPremiumBg,
                    tooltip: 'Scroll to bottom',
                    onPressed: () => _scrollToBottom(smooth: true),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
                  ),
                ),

              // Mobile Floating Info Drawer
              if (!isDesktop && _showProfileInfo)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.55),
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.85,
                      child: _buildInfoDrawer(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChatState() {
    final isProject = _selectedTargetType == 'project';
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
              child: Icon(
                isProject ? Icons.folder_special_outlined : Icons.lock_outline_rounded,
                color: kPremiumGold,
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isProject ? 'Project Communications: $_selectedTargetName' : 'Business Session: $_selectedTargetName',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: kPremiumText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isProject
                  ? 'All project members, assignees, and managers have access to this workflow log. Messages are preserved for project history.'
                  : 'Relationship-controlled communication. Type a message below to coordinate on business deliverables.',
              style: const TextStyle(color: kPremiumMuted, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROFILE / PROJECT DRAWER (WITH PRIVACY PROTECTIONS)
  // ---------------------------------------------------------------------------
  Widget _buildInfoDrawer() {
    final myRole = SupabaseService().currentRole.toLowerCase();
    final isViewerClient = myRole == 'client';
    final isProject = _selectedTargetType == 'project';

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: kPremiumSurface.withOpacity(0.96),
        border: const Border(left: BorderSide(color: kPremiumBorder)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isProject ? 'Project Details' : 'Contact Information',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kPremiumGold),
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
                        style: isProject ? AvatarStyle.pattern : AvatarStyle.gradient,
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
                          color: (isProject ? kPremiumGold : (_selectedTargetType == 'client' ? kPremiumBlue : kPremiumViolet)).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isProject ? kPremiumGold : (_selectedTargetType == 'client' ? kPremiumBlue : kPremiumViolet)).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _selectedTargetType.toUpperCase(),
                          style: TextStyle(
                            color: isProject ? kPremiumGold : (_selectedTargetType == 'client' ? kPremiumBlue : kPremiumViolet),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (isProject) ...[
                  const Text(
                    'WORKFLOW SCOPE & SECURITY',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPremiumMuted, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    radius: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 16, color: kPremiumGold),
                            SizedBox(width: 8),
                            Text('Project-Bounded Access', style: TextStyle(color: kPremiumText, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Only assigned specialists, managers, and the designated client account can participate in this channel.',
                          style: TextStyle(color: kPremiumMuted, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text(
                    'BUSINESS CONTACT DETAILS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPremiumMuted, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),

                  // Privacy Notice for Clients Viewing Employees
                  if (isViewerClient && _selectedTargetType == 'employee') ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.privacy_tip_outlined, size: 15, color: kPremiumGold),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Personal phone and email are protected. Please coordinate via project channels.',
                              style: TextStyle(color: kPremiumMuted, fontSize: 10.5, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Email Card (Only for non-clients or admin-configured)
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
                                const Text('Business Email', style: TextStyle(fontSize: 10, color: kPremiumMuted)),
                                Text(
                                  _selectedTargetEmail.isNotEmpty ? _selectedTargetEmail : 'Confidential / Workspace Chat',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPremiumText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Phone Card
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
                                const Text('Office Contact', style: TextStyle(fontSize: 10, color: kPremiumMuted)),
                                Text(
                                  _selectedTargetPhone.isNotEmpty ? _selectedTargetPhone : 'Office / Internal Channel',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPremiumText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
