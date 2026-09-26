import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/models/chat_models.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/notification_service.dart';

class MessagingService {
  static final MessagingService _instance = MessagingService._();
  factory MessagingService() => _instance;
  MessagingService._();

  final SupabaseClient _client = Supabase.instance.client;

  // Active broadcast & postgres channels: conversationId -> RealtimeChannel
  final Map<String, RealtimeChannel> _activeChannels = {};

  // Per-conversation message streams for reactive UI
  final Map<String, StreamController<List<ChatMessageModel>>> _messageControllers = {};

  // In-memory cache of messages: conversationId -> List<ChatMessageModel>
  final Map<String, List<ChatMessageModel>> _messagesCache = {};

  // Typing state: conversationId -> Map<userId, userName>
  final Map<String, StreamController<Set<String>>> _typingControllers = {};
  final Map<String, Timer?> _typingDebounceTimers = {};
  final Map<String, Timer?> _incomingTypingTimeouts = {};

  // Throttled mark-as-read tracking to prevent hammering DB
  final Map<String, DateTime> _lastMarkReadTimestamps = {};

  // Current authenticated user helper
  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => currentUser?.id;

  // ---------------------------------------------------------------------------
  // UUID GENERATORS
  // ---------------------------------------------------------------------------
  String generateDeterministicConversationUuid(String idA, String idB) {
    final pair = [idA.trim().toLowerCase(), idB.trim().toLowerCase()]..sort();
    final hash = md5.convert(utf8.encode('direct_chat_${pair[0]}_${pair[1]}')).toString();
    final p1 = hash.substring(0, 8);
    final p2 = hash.substring(8, 12);
    final p3 = '3${hash.substring(13, 16)}'; // UUID v3 (MD5 based)
    final p4 = 'a${hash.substring(17, 20)}'; // RFC 4122 variant
    final p5 = hash.substring(20, 32);
    return '$p1-$p2-$p3-$p4-$p5';
  }

  String generateMessageUuid() {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    final rand = '${DateTime.now().millisecondsSinceEpoch}_${currentUserId ?? 'anon'}';
    final hash = md5.convert(utf8.encode('msg_${now}_$rand')).toString();
    final p1 = hash.substring(0, 8);
    final p2 = hash.substring(8, 12);
    final p3 = '4${hash.substring(13, 16)}'; // UUID v4 format
    final p4 = 'a${hash.substring(17, 20)}'; // RFC 4122 variant
    final p5 = hash.substring(20, 32);
    return '$p1-$p2-$p3-$p4-$p5';
  }

  // ---------------------------------------------------------------------------
  // SENDER DISPLAY DETAILS
  // ---------------------------------------------------------------------------
  Map<String, String> getSenderInfo(String senderId) {
    final myId = currentUserId;
    if (senderId == myId) {
      return {'name': 'Me', 'role': 'User'};
    }

    final store = AppDataStore();
    for (final a in store.admins) {
      if (a.id == senderId) return {'name': a.name, 'role': 'Admin'};
    }
    for (final e in store.employees) {
      if (e.userId == senderId || e.id == senderId) {
        return {'name': e.name, 'role': e.role.isNotEmpty ? e.role : 'Employee'};
      }
    }
    for (final c in store.clients) {
      if (c.userId == senderId || c.id == senderId) {
        return {'name': c.name, 'role': 'Client'};
      }
    }

    return {'name': 'User', 'role': 'Member'};
  }

  // ---------------------------------------------------------------------------
  // CONVERSATIONS MANAGEMENT
  // ---------------------------------------------------------------------------
  Future<String> getOrCreateDirectConversation(String targetId, {String? targetName}) async {
    final myId = currentUserId ?? 'guest_user';
    
    // 1. Resolve targetId to real Auth UUID
    String resolvedTargetUserId = targetId;
    final store = AppDataStore();

    for (final c in store.clients) {
      if ((c.id == targetId || c.email.toLowerCase() == targetId.toLowerCase()) &&
          c.userId != null && c.userId!.isNotEmpty) {
        resolvedTargetUserId = c.userId!;
        break;
      }
    }
    if (resolvedTargetUserId == targetId) {
      for (final emp in store.employees) {
        if ((emp.id == targetId || emp.email.toLowerCase() == targetId.toLowerCase()) &&
            emp.userId.isNotEmpty) {
          resolvedTargetUserId = emp.userId;
          break;
        }
      }
    }
    if (resolvedTargetUserId == targetId) {
      for (final admin in store.admins) {
        if ((admin.id == targetId || admin.email.toLowerCase() == targetId.toLowerCase()) &&
            admin.id.isNotEmpty) {
          resolvedTargetUserId = admin.id;
          break;
        }
      }
    }

    // 1.1 DB Fallback Resolution: If targetId is an employee record ID or client record ID
    if (resolvedTargetUserId == targetId && currentUser != null) {
      try {
        final empRow = await _client
            .from('employees')
            .select('user_id')
            .eq('id', targetId)
            .maybeSingle();
        if (empRow != null && empRow['user_id'] != null && empRow['user_id'].toString().isNotEmpty) {
          resolvedTargetUserId = empRow['user_id'].toString();
        }
      } catch (_) {}
    }
    if (resolvedTargetUserId == targetId && currentUser != null) {
      try {
        final clientRow = await _client
            .from('clients')
            .select('user_id')
            .eq('id', targetId)
            .maybeSingle();
        if (clientRow != null && clientRow['user_id'] != null && clientRow['user_id'].toString().isNotEmpty) {
          resolvedTargetUserId = clientRow['user_id'].toString();
        }
      } catch (_) {}
    }

    // 1.2 Prevent self-conversation when an employee/client wants to chat with Admin
    if (myId == resolvedTargetUserId && currentUser != null) {
      final orgId = SupabaseService().currentOrganizationId;
      if (orgId != null && orgId.isNotEmpty) {
        try {
          final adminMem = await _client
              .from('organization_memberships')
              .select('user_id')
              .eq('organization_id', orgId)
              .or('role.eq.admin,role.eq.owner')
              .neq('user_id', myId)
              .limit(1)
              .maybeSingle();
          if (adminMem != null && adminMem['user_id'] != null) {
            resolvedTargetUserId = adminMem['user_id'].toString();
            debugPrint('Rerouted self-chat to real Admin ID: $resolvedTargetUserId');
          }
        } catch (err) {
          debugPrint('Error finding real admin counterpart: $err');
        }
      }
    }

    final convId = generateDeterministicConversationUuid(myId, resolvedTargetUserId);
    if (currentUser == null) return convId;

    final orgId = SupabaseService().currentOrganizationId;

    // 2. Ensure conversation row exists
    try {
      final insertData = <String, dynamic>{
        'id': convId,
        'conversation_type': 'direct',
        'type': 'direct',
        'title': targetName ?? 'Direct Chat',
        'created_by': myId,
      };
      if (orgId != null && orgId.isNotEmpty) {
        insertData['organization_id'] = orgId;
      }

      await _client.from('conversations').upsert(
        insertData,
        onConflict: 'id',
        ignoreDuplicates: true,
      );
    } catch (e) {
      debugPrint('Notice upserting conversation: $e');
    }

    // 3. Ensure members exist
    for (final uid in {myId, resolvedTargetUserId}) {
      try {
        await _client.from('conversation_members').upsert(
          {
            'conversation_id': convId,
            'user_id': uid,
            'last_read_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'conversation_id,user_id',
          ignoreDuplicates: true,
        );
      } catch (memErr) {
        debugPrint('Notice adding member $uid: $memErr');
      }
    }

    // Register with notification service
    NotificationService().registerConversationId(convId);

    return convId;
  }

  Future<String> createGroupConversation({
    required String title,
    required List<String> memberUserIds,
    String? projectId,
  }) async {
    final myId = currentUserId ?? 'guest_user';
    final orgId = SupabaseService().currentOrganizationId;
    final convId = generateMessageUuid();

    final insertData = <String, dynamic>{
      'id': convId,
      'conversation_type': 'group',
      'type': 'group',
      'title': title,
      'created_by': myId,
    };
    if (orgId != null && orgId.isNotEmpty) insertData['organization_id'] = orgId;
    if (projectId != null && projectId.isNotEmpty) insertData['project_id'] = projectId;

    try {
      await _client.from('conversations').insert(insertData);
    } catch (e) {
      debugPrint('Notice inserting group conversation: $e');
      // If DB has CHECK (type IN (\'project\', \'direct\')), fallback to type: \'direct\'
      try {
        insertData['type'] = 'direct';
        await _client.from('conversations').upsert(insertData, onConflict: 'id');
      } catch (retryE) {
        debugPrint('Retry group conversation failed: $retryE');
      }
    }

    final allMembers = {myId, ...memberUserIds};
    final nowIso = DateTime.now().toIso8601String();
    for (final uid in allMembers) {
      try {
        await _client.from('conversation_members').upsert(
          {
            'conversation_id': convId,
            'user_id': uid,
            'joined_at': nowIso,
            'last_read_at': nowIso,
          },
          onConflict: 'conversation_id,user_id',
          ignoreDuplicates: true,
        );
      } catch (memErr) {
        debugPrint('Notice adding group member $uid: $memErr');
      }
    }

    NotificationService().registerConversationId(convId);
    return convId;
  }

  // ---------------------------------------------------------------------------
  // PROJECT-BASED CONTROLLED COMMUNICATION
  // ---------------------------------------------------------------------------
  Future<String?> getOrCreateProjectConversation(String projectId, {String? projectTitle}) async {
    final myId = currentUserId;
    if (myId == null) return null;

    final orgId = SupabaseService().currentOrganizationId;
    final convId = generateDeterministicConversationUuid('project_chat', projectId);

    try {
      // 1. Fetch project details and client information
      final projRes = await _client
          .from('projects')
          .select('id, name, organization_id, client_id, clients(id, user_id, contact_name)')
          .eq('id', projectId)
          .maybeSingle();

      if (projRes == null) return null;

      final pOrgId = projRes['organization_id']?.toString() ?? orgId;
      final pTitle = projectTitle ?? projRes['name']?.toString() ?? 'Project Chat';

      // 2. Identify legitimate project members
      final authorizedUserIds = <String>{};

      // Add Client user
      final clientMap = projRes['clients'] is Map ? projRes['clients'] as Map<String, dynamic> : null;
      final clientUserId = clientMap?['user_id']?.toString();
      if (clientUserId != null && clientUserId.isNotEmpty) {
        authorizedUserIds.add(clientUserId);
      }

      // Add Assigned Project Members (project_members)
      try {
        final pmRes = await _client
            .from('project_members')
            .select('user_id')
            .eq('project_id', projectId);
        for (final row in pmRes) {
          final u = row['user_id']?.toString();
          if (u != null && u.isNotEmpty) authorizedUserIds.add(u);
        }
      } catch (_) {}

      // Add Task Assignees
      try {
        final taskRes = await _client
            .from('tasks')
            .select('assigned_to')
            .eq('project_id', projectId);
        for (final row in taskRes) {
          final u = row['assigned_to']?.toString();
          if (u != null && u.isNotEmpty) authorizedUserIds.add(u);
        }
      } catch (_) {}

      // Add Admins
      if (pOrgId != null) {
        try {
          final adminsRes = await _client
              .from('organization_memberships')
              .select('user_id')
              .eq('organization_id', pOrgId)
              .or('role.eq.admin,role.eq.owner');
          for (final row in adminsRes) {
            final u = row['user_id']?.toString();
            if (u != null && u.isNotEmpty) authorizedUserIds.add(u);
          }
        } catch (_) {}
      }

      // Always include current user if triggered
      authorizedUserIds.add(myId);

      // 3. Upsert Conversation row safely
      final bool isUuidProject = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(projectId);

      final insertData = <String, dynamic>{
        'id': convId,
        'conversation_type': 'project',
        'type': 'project',
        'title': pTitle,
        'created_by': myId,
      };
      if (isUuidProject) {
        insertData['project_id'] = projectId;
      }
      if (pOrgId != null && pOrgId.isNotEmpty) {
        insertData['organization_id'] = pOrgId;
      }

      try {
        await _client.from('conversations').upsert(
          insertData,
          onConflict: 'id',
          ignoreDuplicates: false,
        );
      } catch (e) {
        debugPrint('Notice upserting conversation: $e');
        try {
          insertData.remove('project_id');
          await _client.from('conversations').upsert(insertData, onConflict: 'id');
        } catch (_) {}
      }

      // 4. Upsert authorized members
      for (final uid in authorizedUserIds) {
        try {
          await _client.from('conversation_members').upsert(
            {
              'conversation_id': convId,
              'user_id': uid,
              'last_read_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'conversation_id,user_id',
            ignoreDuplicates: true,
          );
        } catch (_) {}
      }

      NotificationService().registerConversationId(convId);
      return convId;
    } catch (e) {
      debugPrint('Error getting or creating project conversation: $e');
      return convId;
    }
  }

  // ---------------------------------------------------------------------------
  // COMMUNICATION SETTINGS & RELATIONSHIP PERMISSIONS
  // ---------------------------------------------------------------------------
  CommunicationSettingsModel? _cachedSettings;

  Future<CommunicationSettingsModel> getCommunicationSettings() async {
    if (_cachedSettings != null) return _cachedSettings!;
    final orgId = SupabaseService().currentOrganizationId;
    if (orgId == null || orgId.isEmpty) {
      return const CommunicationSettingsModel(id: '', organizationId: '');
    }

    try {
      final res = await _client
          .from('communication_settings')
          .select('*')
          .eq('organization_id', orgId)
          .maybeSingle();

      if (res != null) {
        _cachedSettings = CommunicationSettingsModel.fromMap(res);
        return _cachedSettings!;
      }
    } catch (e) {
      debugPrint('Notice loading communication settings: $e');
    }

    _cachedSettings = CommunicationSettingsModel(id: '', organizationId: orgId);
    return _cachedSettings!;
  }

  Future<bool> updateCommunicationSettings(CommunicationSettingsModel settings) async {
    final orgId = SupabaseService().currentOrganizationId;
    if (orgId == null) return false;

    try {
      await _client.from('communication_settings').upsert(
        settings.toMap()..['organization_id'] = orgId,
        onConflict: 'organization_id',
      );
      _cachedSettings = settings;
      return true;
    } catch (e) {
      debugPrint('Error updating communication settings: $e');
      return false;
    }
  }

  /// Verifies legitimate business relationship before initiating direct chat
  Future<bool> canDirectChatWith({
    required String targetUserId,
    required String targetRole, // 'admin', 'employee', 'client'
  }) async {
    final myId = currentUserId;
    if (myId == null || myId == targetUserId) return false;

    final myRole = SupabaseService().currentRole.toLowerCase();
    final tRole = targetRole.toLowerCase();

    // 1. Admin can always chat with anyone in their organization
    if (myRole == 'admin' || myRole == 'owner' || tRole == 'admin' || tRole == 'owner') {
      return true;
    }

    // 2. Client <-> Client is never allowed
    if (myRole == 'client' && tRole == 'client') {
      return false;
    }

    final settings = await getCommunicationSettings();

    // 3. Employee <-> Employee
    if (myRole == 'employee' && tRole == 'employee') {
      return settings.allowEmployeeEmployeeChat;
    }

    // 4. Employee <-> Client (Legitimate project or client assignment relationship required)
    if ((myRole == 'employee' && tRole == 'client') || (myRole == 'client' && tRole == 'employee')) {
      if (!settings.enableEmployeeClientMessaging) return false;

      final store = AppDataStore();
      final clientUserId = myRole == 'client' ? myId : targetUserId;
      final empUserId = myRole == 'employee' ? myId : targetUserId;

      // Find client record
      final client = store.clients.firstWhere(
        (c) => c.userId == clientUserId || c.id == clientUserId,
        orElse: () => ClientModel(id: '', name: '', company: '', email: '', phone: '', status: ''),
      );

      if (client.id.isNotEmpty) {
        // Direct assignment check
        if (client.assignedEmployeeId == empUserId ||
            store.employees.any((e) => e.userId == empUserId && e.id == client.assignedEmployeeId)) {
          return true;
        }

        // Shared Project check
        for (final p in store.projects) {
          if (p.clientId == client.id) {
            if (p.teamMembers.contains(empUserId)) return true;
            if (store.tasks.any((t) => t.projectId == p.id && t.assignedToId == empUserId)) return true;
          }
        }
      }

      if (settings.restrictClientToProjects) {
        return false;
      }
      return true;
    }

    return false;
  }

  /// Returns shared projects between current user and target user
  List<ProjectModel> getSharedProjects(String targetUserId) {
    final myId = currentUserId;
    if (myId == null) return [];

    final store = AppDataStore();
    final shared = <ProjectModel>[];

    // Identify if target or current user is client
    String? clientRecordId;
    for (final c in store.clients) {
      if (c.userId == targetUserId || c.id == targetUserId) {
        clientRecordId = c.id;
        break;
      }
    }
    String? myClientRecordId;
    for (final c in store.clients) {
      if (c.userId == myId || c.id == myId) {
        myClientRecordId = c.id;
        break;
      }
    }

    for (final p in store.projects) {
      bool meInProject = false;
      bool targetInProject = false;

      // Check current user
      if (myClientRecordId != null && p.clientId == myClientRecordId) meInProject = true;
      if (p.teamMembers.contains(myId)) meInProject = true;
      if (store.tasks.any((t) => t.projectId == p.id && t.assignedToId == myId)) meInProject = true;

      // Check target user
      if (clientRecordId != null && p.clientId == clientRecordId) targetInProject = true;
      if (p.teamMembers.contains(targetUserId)) targetInProject = true;
      if (store.tasks.any((t) => t.projectId == p.id && t.assignedToId == targetUserId)) targetInProject = true;

      if (meInProject && targetInProject) {
        shared.add(p);
      }
    }

    return shared;
  }

  /// Search messages across database and cached messages
  Future<List<ChatMessageModel>> searchMessages({
    required String query,
    String? conversationId,
    int limit = 50,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final results = <ChatMessageModel>[];
    final seenIds = <String>{};

    // 1. Search locally cached messages first for instant response
    if (conversationId != null && conversationId.isNotEmpty) {
      final cached = _messagesCache[conversationId];
      if (cached != null) {
        for (final m in cached) {
          if (!m.isDeleted && m.message.toLowerCase().contains(cleanQuery.toLowerCase())) {
            if (seenIds.add(m.id)) {
              results.add(m);
            }
          }
        }
      }
    } else {
      for (final list in _messagesCache.values) {
        for (final m in list) {
          if (!m.isDeleted && m.message.toLowerCase().contains(cleanQuery.toLowerCase())) {
            if (seenIds.add(m.id)) {
              results.add(m);
            }
          }
        }
      }
    }

    // 2. Query Supabase Postgres database
    try {
      var filterBuilder = _client
          .from('messages')
          .select()
          .ilike('message', '%$cleanQuery%');

      if (conversationId != null && conversationId.isNotEmpty) {
        filterBuilder = filterBuilder.eq('conversation_id', conversationId);
      }

      final res = await filterBuilder
          .order('created_at', ascending: false)
          .limit(limit);
      for (final row in res) {
        final id = row['id']?.toString() ?? '';
        if (seenIds.add(id)) {
          final sInfo = getSenderInfo(row['sender_id']?.toString() ?? '');
          results.add(ChatMessageModel.fromMap(
            row,
            defaultName: sInfo['name'],
            defaultRole: sInfo['role'],
          ));
        }
      }
    } catch (e) {
      debugPrint('Notice searching messages: $e');
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  Future<List<ConversationModel>> getConversations({int limit = 50}) async {
    final myId = currentUserId;
    if (myId == null) return [];

    try {
      // 1. Fetch conversations the current user is a member of
      final memRes = await _client
          .from('conversation_members')
          .select('conversation_id, last_read_at, conversations(*)')
          .eq('user_id', myId)
          .order('joined_at', ascending: false)
          .limit(limit);

      if (memRes.isEmpty) return [];

      final conversations = <ConversationModel>[];

      for (final row in memRes) {
        final convData = row['conversations'] is Map ? row['conversations'] as Map<String, dynamic> : null;
        if (convData == null) continue;

        final convId = convData['id']?.toString() ?? '';
        final lastReadAtStr = row['last_read_at']?.toString();
        final lastReadAt = lastReadAtStr != null ? DateTime.tryParse(lastReadAtStr) : null;

        // Fetch members of this conversation safely
        dynamic membersRes;
        try {
          membersRes = await _client
              .from('conversation_members')
              .select('id, conversation_id, user_id, joined_at, last_read_at, profiles(full_name, avatar_url)')
              .eq('conversation_id', convId);
        } catch (_) {
          try {
            membersRes = await _client
                .from('conversation_members')
                .select('id, conversation_id, user_id, joined_at, last_read_at')
                .eq('conversation_id', convId);
          } catch (_) {}
        }

        final members = (membersRes is List ? membersRes : [])
            .map((m) => ConversationMemberModel.fromMap(m as Map<String, dynamic>))
            .toList();

        // Fetch last message
        final lastMsgRes = await _client
            .from('messages')
            .select()
            .eq('conversation_id', convId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        ChatMessageModel? lastMessage;
        if (lastMsgRes != null) {
          final sInfo = getSenderInfo(lastMsgRes['sender_id']?.toString() ?? '');
          lastMessage = ChatMessageModel.fromMap(
            lastMsgRes,
            defaultName: sInfo['name'],
            defaultRole: sInfo['role'],
          );
        }

        // Calculate unread count
        int unreadCount = 0;
        if (lastReadAt != null) {
          final unreadRes = await _client
              .from('messages')
              .select('id')
              .eq('conversation_id', convId)
              .gt('created_at', lastReadAt.toIso8601String())
              .neq('sender_id', myId);
          unreadCount = unreadRes.length;
        }

        conversations.add(ConversationModel.fromMap(
          convData,
          currentUserId: myId,
          membersList: members,
          lastMsg: lastMessage,
        ).copyWith(unreadCount: unreadCount));
      }

      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return conversations;
    } catch (e) {
      debugPrint('Error in getConversations: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // MESSAGES STREAM & PAGINATION
  // ---------------------------------------------------------------------------
  Stream<List<ChatMessageModel>> getMessagesStream(String conversationId) {
    if (!_messageControllers.containsKey(conversationId) || _messageControllers[conversationId]!.isClosed) {
      final controller = StreamController<List<ChatMessageModel>>.broadcast();
      _messageControllers[conversationId] = controller;
      _subscribeToConversation(conversationId, controller);
    } else {
      // Re-emit cached messages immediately
      final cached = _messagesCache[conversationId] ?? [];
      if (cached.isNotEmpty) {
        Future.microtask(() {
          final ctrl = _messageControllers[conversationId];
          if (ctrl != null && !ctrl.isClosed) {
            ctrl.add(List.unmodifiable(cached));
          }
        });
      }
    }
    return _messageControllers[conversationId]!.stream;
  }

  Future<void> _subscribeToConversation(
    String conversationId,
    StreamController<List<ChatMessageModel>> controller,
  ) async {
    // 1. Emit existing in-memory cache
    final localList = _messagesCache[conversationId] ?? [];
    if (localList.isNotEmpty && !controller.isClosed) {
      controller.add(List.unmodifiable(localList));
    }

    // 2. Fetch initial page of messages (last 40 messages)
    await loadInitialMessages(conversationId, limit: 40);

    // 3. Mark conversation as read
    markAsRead(conversationId);

    // 4. Subscribe to Realtime Broadcast (sub-50ms peer-to-peer delivery)
    _subscribeRealtimeBroadcast(conversationId);

    // 5. Subscribe to Postgres Changes (persisted writes, edits, deletes)
    _subscribePostgresChanges(conversationId);
  }

  Future<List<ChatMessageModel>> loadInitialMessages(String conversationId, {int limit = 40}) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);

      final list = response.reversed.map((json) {
        final sInfo = getSenderInfo(json['sender_id']?.toString() ?? '');
        return ChatMessageModel.fromMap(
          json,
          defaultName: sInfo['name'],
          defaultRole: sInfo['role'],
        );
      }).toList();

      _mergeMessages(conversationId, list);
      return list;
    } catch (e) {
      debugPrint('Error loading initial messages: $e');
      return [];
    }
  }

  /// Cursor-based pagination: loads older messages created before [beforeTimestamp]
  Future<List<ChatMessageModel>> loadOlderMessages(
    String conversationId, {
    required DateTime beforeTimestamp,
    int limit = 30,
  }) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .lt('created_at', beforeTimestamp.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      if (response.isEmpty) return [];

      final olderMessages = response.reversed.map((json) {
        final sInfo = getSenderInfo(json['sender_id']?.toString() ?? '');
        return ChatMessageModel.fromMap(
          json,
          defaultName: sInfo['name'],
          defaultRole: sInfo['role'],
        );
      }).toList();

      _mergeMessages(conversationId, olderMessages);
      return olderMessages;
    } catch (e) {
      debugPrint('Error loading older messages: $e');
      return [];
    }
  }

  void _subscribeRealtimeBroadcast(String conversationId) {
    if (_activeChannels.containsKey(conversationId)) return;

    try {
      final channel = _client.channel('chat_$conversationId');

      // Listen for instant messages
      channel.onBroadcast(
        event: 'chat_msg',
        callback: (payload) {
          final senderId = payload['sender_id']?.toString() ?? '';
          if (senderId == currentUserId) return; // Ignore own messages broadcasted back

          final rawText = (payload['message'] ?? payload['content'] ?? '').toString();
          final sInfo = getSenderInfo(senderId);

          final msg = ChatMessageModel(
            id: payload['id']?.toString() ?? 'bc_${DateTime.now().millisecondsSinceEpoch}',
            conversationId: conversationId,
            senderId: senderId,
            senderName: payload['sender_name']?.toString() ?? sInfo['name']!,
            senderRole: payload['sender_role']?.toString() ?? sInfo['role']!,
            message: rawText,
            messageType: payload['message_type']?.toString() ?? 'text',
            attachmentUrl: payload['attachment_url']?.toString(),
            createdAt: payload['created_at'] != null
                ? DateTime.tryParse(payload['created_at'].toString()) ?? DateTime.now()
                : DateTime.now(),
            deliveryStatus: MessageDeliveryStatus.delivered,
          );

          _addSingleMessage(conversationId, msg);
        },
      );

      // Listen for typing events
      channel.onBroadcast(
        event: 'typing',
        callback: (payload) {
          final senderId = payload['sender_id']?.toString() ?? '';
          if (senderId == currentUserId) return;

          final isTyping = payload['is_typing'] == true;
          final senderName = payload['sender_name']?.toString() ?? 'Someone';

          _handleIncomingTyping(conversationId, senderName, isTyping);
        },
      );

      // Listen for instant message edits
      channel.onBroadcast(
        event: 'edit_msg',
        callback: (payload) {
          final msgId = payload['id']?.toString() ?? '';
          final newMsg = (payload['message'] ?? payload['content'] ?? '').toString();
          if (msgId.isEmpty) return;

          final list = _messagesCache[conversationId];
          if (list == null) return;
          final idx = list.indexWhere((m) => m.id == msgId);
          if (idx >= 0) {
            list[idx] = list[idx].copyWith(
              message: newMsg,
              updatedAt: DateTime.now(),
            );
            _notifyController(conversationId);
          }
        },
      );

      // Listen for instant message deletions
      channel.onBroadcast(
        event: 'delete_msg',
        callback: (payload) {
          final msgId = payload['id']?.toString() ?? '';
          final isSoft = payload['soft_delete'] != false;
          if (msgId.isEmpty) return;

          final list = _messagesCache[conversationId];
          if (list == null) return;
          final idx = list.indexWhere((m) => m.id == msgId);
          if (idx >= 0) {
            if (isSoft) {
              list[idx] = list[idx].copyWith(
                isDeleted: true,
                message: 'This message was deleted',
                updatedAt: DateTime.now(),
              );
            } else {
              list.removeAt(idx);
            }
            _notifyController(conversationId);
          }
        },
      );

      channel.subscribe();
      _activeChannels[conversationId] = channel;
    } catch (e) {
      debugPrint('Notice subscribing realtime broadcast for $conversationId: $e');
    }
  }

  void _subscribePostgresChanges(String conversationId) {
    final postgresChannelName = 'pg_changes_$conversationId';
    if (_activeChannels.containsKey(postgresChannelName)) return;

    try {
      final pgChannel = _client.channel(postgresChannelName);

      // INSERT event
      pgChannel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (payload) {
          final record = payload.newRecord;
          if (record.isEmpty) return;

          final senderId = record['sender_id']?.toString() ?? '';
          final sInfo = getSenderInfo(senderId);

          final msg = ChatMessageModel.fromMap(
            record,
            defaultName: sInfo['name'],
            defaultRole: sInfo['role'],
          );

          _addSingleMessage(conversationId, msg);
        },
      );

      // UPDATE event (edits, soft deletes)
      pgChannel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (payload) {
          final record = payload.newRecord;
          if (record.isEmpty) return;

          final updatedId = record['id']?.toString() ?? '';
          final sInfo = getSenderInfo(record['sender_id']?.toString() ?? '');
          final updatedMsg = ChatMessageModel.fromMap(
            record,
            defaultName: sInfo['name'],
            defaultRole: sInfo['role'],
          );

          _updateSingleMessage(conversationId, updatedId, updatedMsg);
        },
      );

      // DELETE event
      pgChannel.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (payload) {
          final oldId = payload.oldRecord['id']?.toString() ?? '';
          if (oldId.isNotEmpty) {
            _removeSingleMessage(conversationId, oldId);
          }
        },
      );

      pgChannel.subscribe();
      _activeChannels[postgresChannelName] = pgChannel;
    } catch (e) {
      debugPrint('Notice subscribing postgres changes for $conversationId: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MESSAGE DEDUPLICATION & STATE UPDATES
  // ---------------------------------------------------------------------------
  void _addSingleMessage(String conversationId, ChatMessageModel msg) {
    final list = _messagesCache.putIfAbsent(conversationId, () => []);

    // Check duplicate by exact ID or optimistic match (same sender + same text within 3s)
    final existingIndex = list.indexWhere((m) =>
        m.id == msg.id ||
        (m.senderId == msg.senderId &&
            m.message == msg.message &&
            m.createdAt.difference(msg.createdAt).inSeconds.abs() < 4));

    if (existingIndex >= 0) {
      // Update optimistic message with real server data
      list[existingIndex] = msg;
    } else {
      list.add(msg);
    }

    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _notifyController(conversationId);
  }

  void _updateSingleMessage(String conversationId, String msgId, ChatMessageModel updatedMsg) {
    final list = _messagesCache[conversationId];
    if (list == null) return;

    final index = list.indexWhere((m) => m.id == msgId);
    if (index >= 0) {
      list[index] = updatedMsg;
      _notifyController(conversationId);
    }
  }

  void _removeSingleMessage(String conversationId, String msgId) {
    final list = _messagesCache[conversationId];
    if (list == null) return;

    list.removeWhere((m) => m.id == msgId);
    _notifyController(conversationId);
  }

  void _mergeMessages(String conversationId, List<ChatMessageModel> incoming) {
    final list = _messagesCache.putIfAbsent(conversationId, () => []);

    for (final inc in incoming) {
      final exists = list.any((loc) =>
          loc.id == inc.id ||
          (loc.senderId == inc.senderId &&
              loc.message == inc.message &&
              loc.createdAt.difference(inc.createdAt).inSeconds.abs() < 4));
      if (!exists) {
        list.add(inc);
      }
    }

    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _notifyController(conversationId);
  }

  void _notifyController(String conversationId) {
    final list = _messagesCache[conversationId] ?? [];
    final controller = _messageControllers[conversationId];
    if (controller != null && !controller.isClosed) {
      controller.add(List.unmodifiable(list));
    }
  }

  // ---------------------------------------------------------------------------
  // SEND MESSAGE WITH OPTIMISTIC UPDATE & RETRY
  // ---------------------------------------------------------------------------
  /// Resilient self-healing helper to persist a message to Postgres
  Future<bool> _persistMessageToDatabase({
    required String msgId,
    required String conversationId,
    required String senderId,
    required String content,
    String messageType = 'text',
    String? attachmentUrl,
    required DateTime createdAt,
  }) async {
    final orgId = SupabaseService().currentOrganizationId;
    final nowIso = createdAt.toIso8601String();

    // 1. Ensure conversation exists in DB with both schema formats
    try {
      await _client.from('conversations').upsert({
        'id': conversationId,
        'type': 'direct',
        'conversation_type': 'direct',
        'title': 'Direct Conversation',
        'created_by': senderId,
        if (orgId != null && orgId.isNotEmpty) 'organization_id': orgId,
      }, onConflict: 'id', ignoreDuplicates: true);
    } catch (e) {
      debugPrint('Notice ensuring conversation in persist: $e');
    }

    // 2. Ensure current user is registered in conversation_members
    try {
      await _client.from('conversation_members').upsert({
        'conversation_id': conversationId,
        'user_id': senderId,
        'last_read_at': nowIso,
      }, onConflict: 'conversation_id,user_id', ignoreDuplicates: true);
    } catch (e) {
      debugPrint('Notice ensuring member in persist: $e');
    }

    // 3. Ensure profile row exists in public.profiles to satisfy foreign keys
    try {
      final user = currentUser;
      if (user != null) {
        await _client.from('profiles').upsert({
          'id': senderId,
          'email': user.email ?? '',
          'full_name': user.userMetadata?['full_name'] ?? user.email ?? 'User',
        }, onConflict: 'id', ignoreDuplicates: true);
      }
    } catch (_) {}

    // 4. Adaptive Insert Strategy:
    // Strategy A: Full production schema (message + content + message_type + attachment_url)
    try {
      await _client.from('messages').upsert({
        'id': msgId,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'message': content,
        'content': content,
        'message_type': messageType,
        'attachment_url': attachmentUrl,
        'created_at': nowIso,
      }, onConflict: 'id');
      return true;
    } catch (eA) {
      debugPrint('Strategy A (full schema) notice: $eA');

      // Strategy B: Legacy schema (content only - from original supabase_schema.sql)
      try {
        await _client.from('messages').upsert({
          'id': msgId,
          'conversation_id': conversationId,
          'sender_id': senderId,
          'content': content,
          'attachment_url': attachmentUrl,
          'created_at': nowIso,
        }, onConflict: 'id');
        return true;
      } catch (eB) {
        debugPrint('Strategy B (legacy content) notice: $eB');

        // Strategy C: Production schema (message only - from supabase_messaging_production.sql)
        try {
          await _client.from('messages').upsert({
            'id': msgId,
            'conversation_id': conversationId,
            'sender_id': senderId,
            'message': content,
            'message_type': messageType,
            'attachment_url': attachmentUrl,
            'created_at': nowIso,
          }, onConflict: 'id');
          return true;
        } catch (eC) {
          debugPrint('Strategy C (message only) notice: $eC');

          // Strategy D: Minimal payload (id, conversation_id, sender_id, content)
          try {
            await _client.from('messages').insert({
              'id': msgId,
              'conversation_id': conversationId,
              'sender_id': senderId,
              'content': content,
            });
            return true;
          } catch (eD) {
            debugPrint('Strategy D (minimal insert) error: $eD');
            return false;
          }
        }
      }
    }
  }

  Future<ChatMessageModel?> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? attachmentUrl,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty && (attachmentUrl == null || attachmentUrl.isEmpty)) {
      return null;
    }

    final senderId = currentUserId ?? 'anonymous';
    final msgId = generateMessageUuid();
    final now = DateTime.now();
    final sInfo = getSenderInfo(senderId);

    // 1. Optimistic Local Message (immediate UI feedback)
    final optimisticMsg = ChatMessageModel(
      id: msgId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: 'Me',
      senderRole: sInfo['role']!,
      message: trimmed,
      messageType: messageType,
      attachmentUrl: attachmentUrl,
      createdAt: now,
      deliveryStatus: MessageDeliveryStatus.sending,
    );

    _addSingleMessage(conversationId, optimisticMsg);

    // 2. Broadcast immediately over WebSocket channel (<50ms delivery to connected users)
    try {
      final channel = _activeChannels[conversationId] ?? _client.channel('chat_$conversationId');
      channel.sendBroadcastMessage(
        event: 'chat_msg',
        payload: {
          'id': msgId,
          'conversation_id': conversationId,
          'sender_id': senderId,
          'sender_name': sInfo['name'],
          'sender_role': sInfo['role'],
          'message': trimmed,
          'content': trimmed,
          'message_type': messageType,
          'attachment_url': attachmentUrl,
          'created_at': now.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Notice broadcasting chat_msg: $e');
    }

    // 3. Persist to Postgres database with self-healing adaptive fallbacks
    final persisted = await _persistMessageToDatabase(
      msgId: msgId,
      conversationId: conversationId,
      senderId: senderId,
      content: trimmed,
      messageType: messageType,
      attachmentUrl: attachmentUrl,
      createdAt: now,
    );

    if (persisted) {
      final confirmedMsg = optimisticMsg.copyWith(deliveryStatus: MessageDeliveryStatus.sent);
      _updateSingleMessage(conversationId, msgId, confirmedMsg);
      return confirmedMsg;
    }

    // Check if Realtime channel already confirmed or delivered the message from Postgres
    final currentList = _messagesCache[conversationId];
    final currentMsg = currentList?.firstWhere(
      (m) => m.id == msgId,
      orElse: () => optimisticMsg,
    );
    if (currentMsg != null &&
        (currentMsg.deliveryStatus == MessageDeliveryStatus.sent ||
            currentMsg.deliveryStatus == MessageDeliveryStatus.delivered)) {
      return currentMsg;
    }

    final errorMsg = optimisticMsg.copyWith(deliveryStatus: MessageDeliveryStatus.error);
    _updateSingleMessage(conversationId, msgId, errorMsg);
    return null;
  }

  /// Retries sending a previously failed message with immediate optimistic feedback
  Future<ChatMessageModel?> retrySendMessage({
    required String conversationId,
    required ChatMessageModel failedMessage,
  }) async {
    final senderId = currentUserId ?? failedMessage.senderId;
    final msgId = failedMessage.id;
    final content = failedMessage.message;
    final sInfo = getSenderInfo(senderId);

    // 1. Immediately update local message status to sending
    final sendingMsg = failedMessage.copyWith(
      deliveryStatus: MessageDeliveryStatus.sending,
      createdAt: DateTime.now(),
    );
    _updateSingleMessage(conversationId, msgId, sendingMsg);

    // 2. Broadcast again over WebSocket
    try {
      final channel = _activeChannels[conversationId] ?? _client.channel('chat_$conversationId');
      channel.sendBroadcastMessage(
        event: 'chat_msg',
        payload: {
          'id': msgId,
          'conversation_id': conversationId,
          'sender_id': senderId,
          'sender_name': sInfo['name'],
          'sender_role': sInfo['role'],
          'message': content,
          'content': content,
          'message_type': failedMessage.messageType,
          'attachment_url': failedMessage.attachmentUrl,
          'created_at': sendingMsg.createdAt.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Notice broadcasting retry chat_msg: $e');
    }

    // 3. Persist to Postgres database via adaptive strategy
    final persisted = await _persistMessageToDatabase(
      msgId: msgId,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      messageType: failedMessage.messageType,
      attachmentUrl: failedMessage.attachmentUrl,
      createdAt: sendingMsg.createdAt,
    );

    if (persisted) {
      final confirmedMsg = sendingMsg.copyWith(deliveryStatus: MessageDeliveryStatus.sent);
      _updateSingleMessage(conversationId, msgId, confirmedMsg);
      return confirmedMsg;
    } else {
      final errorMsg = sendingMsg.copyWith(deliveryStatus: MessageDeliveryStatus.error);
      _updateSingleMessage(conversationId, msgId, errorMsg);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // EDIT & DELETE
  // ---------------------------------------------------------------------------
  Future<bool> editMessage(String conversationId, String messageId, String newContent) async {
    final trimmed = newContent.trim();
    if (trimmed.isEmpty) return false;

    // 1. Optimistic local update
    final list = _messagesCache[conversationId];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(
          message: trimmed,
          updatedAt: DateTime.now(),
        );
        _notifyController(conversationId);
      }
    }

    // 2. Broadcast edit over WebSocket channel for instant delivery (<50ms)
    try {
      final channel = _activeChannels[conversationId] ?? _client.channel('chat_$conversationId');
      channel.sendBroadcastMessage(
        event: 'edit_msg',
        payload: {
          'id': messageId,
          'conversation_id': conversationId,
          'message': trimmed,
        },
      );
    } catch (_) {}

    // 3. Persist to Postgres database
    try {
      await _client.from('messages').update({
        'message': trimmed,
        'content': trimmed,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);

      return true;
    } catch (e) {
      debugPrint('Error editing message: $e');
      return false;
    }
  }

  Future<bool> deleteMessage(String conversationId, String messageId, {bool softDelete = true}) async {
    // 1. Optimistic local update
    final list = _messagesCache[conversationId];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        if (softDelete) {
          list[idx] = list[idx].copyWith(
            isDeleted: true,
            message: 'This message was deleted',
            updatedAt: DateTime.now(),
          );
        } else {
          list.removeAt(idx);
        }
        _notifyController(conversationId);
      }
    }

    // 2. Broadcast delete over WebSocket channel for instant delivery
    try {
      final channel = _activeChannels[conversationId] ?? _client.channel('chat_$conversationId');
      channel.sendBroadcastMessage(
        event: 'delete_msg',
        payload: {
          'id': messageId,
          'conversation_id': conversationId,
          'soft_delete': softDelete,
        },
      );
    } catch (_) {}

    // 3. Persist to Postgres database
    try {
      if (softDelete) {
        await _client.from('messages').update({
          'is_deleted': true,
          'message': 'This message was deleted',
          'content': 'This message was deleted',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', messageId);
      } else {
        await _client.from('messages').delete().eq('id', messageId);
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return false;
    }
  }

  Future<bool> deleteConversation(String conversationId) async {
    try {
      try {
        await _client.from('messages').delete().eq('conversation_id', conversationId);
      } catch (_) {}
      try {
        await _client.from('conversation_members').delete().eq('conversation_id', conversationId);
      } catch (_) {}
      try {
        await _client.from('conversations').delete().eq('id', conversationId);
      } catch (_) {}

      _messagesCache.remove(conversationId);
      _notifyController(conversationId);
      return true;
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      _messagesCache.remove(conversationId);
      _notifyController(conversationId);
      return false;
    }
  }

  Future<bool> clearMessages(String conversationId) async {
    try {
      await _client.from('messages').delete().eq('conversation_id', conversationId);
      _messagesCache[conversationId]?.clear();
      _notifyController(conversationId);
      return true;
    } catch (e) {
      debugPrint('Error clearing messages: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // READ RECEIPTS
  // ---------------------------------------------------------------------------
  Future<void> markAsRead(String conversationId) async {
    final myId = currentUserId;
    if (myId == null) return;

    // Throttle to at most once every 10 seconds per conversation
    final lastTime = _lastMarkReadTimestamps[conversationId];
    if (lastTime != null && DateTime.now().difference(lastTime).inSeconds < 10) {
      return;
    }
    _lastMarkReadTimestamps[conversationId] = DateTime.now();

    try {
      await _client
          .from('conversation_members')
          .update({'last_read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', myId);
    } catch (e) {
      debugPrint('Notice updating last_read_at: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // TYPING INDICATOR (PRESENCE / BROADCAST - ZERO DB WRITES)
  // ---------------------------------------------------------------------------
  Stream<Set<String>> getTypingStream(String conversationId) {
    if (!_typingControllers.containsKey(conversationId) || _typingControllers[conversationId]!.isClosed) {
      _typingControllers[conversationId] = StreamController<Set<String>>.broadcast();
    }
    return _typingControllers[conversationId]!.stream;
  }

  final Map<String, Set<String>> _activeTypingUsers = {};

  void sendTyping(String conversationId, {required bool isTyping}) {
    final myId = currentUserId;
    if (myId == null) return;

    // Debounce typing broadcast
    _typingDebounceTimers[conversationId]?.cancel();

    _typingDebounceTimers[conversationId] = Timer(const Duration(milliseconds: 300), () {
      try {
        final channel = _activeChannels[conversationId] ?? _client.channel('chat_$conversationId');
        final sInfo = getSenderInfo(myId);

        channel.sendBroadcastMessage(
          event: 'typing',
          payload: {
            'sender_id': myId,
            'sender_name': sInfo['name'],
            'is_typing': isTyping,
          },
        );
      } catch (_) {}
    });
  }

  void _handleIncomingTyping(String conversationId, String userName, bool isTyping) {
    final set = _activeTypingUsers.putIfAbsent(conversationId, () => <String>{});

    if (isTyping) {
      set.add(userName);
      _incomingTypingTimeouts[conversationId]?.cancel();
      // Auto-clear typing indicator after 4 seconds of inactivity
      _incomingTypingTimeouts[conversationId] = Timer(const Duration(seconds: 4), () {
        set.remove(userName);
        final ctrl = _typingControllers[conversationId];
        if (ctrl != null && !ctrl.isClosed) {
          ctrl.add(Set.unmodifiable(set));
        }
      });
    } else {
      set.remove(userName);
    }

    final ctrl = _typingControllers[conversationId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(Set.unmodifiable(set));
    }
  }

  // ---------------------------------------------------------------------------
  // CLEANUP & LIFECYCLE
  // ---------------------------------------------------------------------------
  void unsubscribeFromConversation(String conversationId) {
    _typingDebounceTimers[conversationId]?.cancel();
    _typingDebounceTimers.remove(conversationId);
    _incomingTypingTimeouts[conversationId]?.cancel();
    _incomingTypingTimeouts.remove(conversationId);

    // Remove broadcast channel
    final bcChannel = _activeChannels.remove(conversationId);
    if (bcChannel != null) {
      try {
        _client.removeChannel(bcChannel);
      } catch (_) {}
    }

    // Remove postgres channel
    final pgChannel = _activeChannels.remove('pg_changes_$conversationId');
    if (pgChannel != null) {
      try {
        _client.removeChannel(pgChannel);
      } catch (_) {}
    }

    _messageControllers[conversationId]?.close();
    _messageControllers.remove(conversationId);

    _typingControllers[conversationId]?.close();
    _typingControllers.remove(conversationId);
    _activeTypingUsers.remove(conversationId);
  }

  void dispose() {
    for (final channel in _activeChannels.values) {
      try {
        _client.removeChannel(channel);
      } catch (_) {}
    }
    _activeChannels.clear();

    for (final ctrl in _messageControllers.values) {
      ctrl.close();
    }
    _messageControllers.clear();

    for (final ctrl in _typingControllers.values) {
      ctrl.close();
    }
    _typingControllers.clear();

    for (final timer in _typingDebounceTimers.values) {
      timer?.cancel();
    }
    _typingDebounceTimers.clear();

    for (final timer in _incomingTypingTimeouts.values) {
      timer?.cancel();
    }
    _incomingTypingTimeouts.clear();
  }
}
