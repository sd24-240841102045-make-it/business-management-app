import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
// App Notification Model
// ─────────────────────────────────────────────
enum NotificationType {
  newEmployee,
  newClient,
  clientAllocated,
  taskAssigned,
  taskStatusChanged,
  consultationAssigned,
  newMessage,
  newInvoice,
  invoicePaid,
  newProject,
  leaveRequest,
  invitationAccepted,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  IconData get icon {
    switch (type) {
      case NotificationType.newEmployee:
        return Icons.person_add_rounded;
      case NotificationType.newClient:
        return Icons.business_rounded;
      case NotificationType.clientAllocated:
        return Icons.badge_rounded;
      case NotificationType.taskAssigned:
        return Icons.assignment_rounded;
      case NotificationType.taskStatusChanged:
        return Icons.task_alt_rounded;
      case NotificationType.consultationAssigned:
        return Icons.assignment_ind_rounded;
      case NotificationType.newMessage:
        return Icons.chat_bubble_rounded;
      case NotificationType.newInvoice:
        return Icons.receipt_rounded;
      case NotificationType.invoicePaid:
        return Icons.payments_rounded;
      case NotificationType.newProject:
        return Icons.folder_special_rounded;
      case NotificationType.leaveRequest:
        return Icons.event_busy_rounded;
      case NotificationType.invitationAccepted:
        return Icons.how_to_reg_rounded;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.newEmployee:
        return const Color(0xFF6C63FF);
      case NotificationType.newClient:
        return const Color(0xFF00B4D8);
      case NotificationType.clientAllocated:
        return const Color(0xFF06D6A0);
      case NotificationType.taskAssigned:
        return const Color(0xFFF4A261);
      case NotificationType.taskStatusChanged:
        return const Color(0xFF2EC4B6);
      case NotificationType.consultationAssigned:
        return const Color(0xFF9D4EDD);
      case NotificationType.newMessage:
        return const Color(0xFF4CC9F0);
      case NotificationType.newInvoice:
        return const Color(0xFFE63946);
      case NotificationType.invoicePaid:
        return const Color(0xFF57CC99);
      case NotificationType.newProject:
        return const Color(0xFFB5179E);
      case NotificationType.leaveRequest:
        return const Color(0xFFFF9F1C);
      case NotificationType.invitationAccepted:
        return const Color(0xFF80ED99);
    }
  }
}

// ─────────────────────────────────────────────
// Notification Service (Singleton)
// ─────────────────────────────────────────────
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final List<AppNotification> _notifications = [];
  final StreamController<List<AppNotification>> _streamController =
      StreamController<List<AppNotification>>.broadcast();

  // Callback that the UI registers to show a toast
  Function(AppNotification)? onToast;

  Stream<List<AppNotification>> get notificationsStream =>
      _streamController.stream;

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Track subscribed channels to avoid duplicates
  final List<RealtimeChannel> _channels = [];
  final Set<String> _myConversationIds = {};
  bool _initialized = false;
  String? _currentOrgId;
  String? _currentUserId;
  String? _currentEmployeeId;

  void registerConversationId(String conversationId) {
    if (conversationId.isNotEmpty) {
      _myConversationIds.add(conversationId);
    }
  }

  // ── Initialize & subscribe to all Supabase Realtime events ──
  Future<void> initialize({
    required String orgId,
    required String userId,
    required String role,
    String? employeeId,
  }) async {
    if (_initialized &&
        _currentOrgId == orgId &&
        _currentUserId == userId &&
        _currentEmployeeId == employeeId) {
      return;
    }

    // Cancel previous subscriptions
    dispose();
    _initialized = true;
    _currentOrgId = orgId;
    _currentUserId = userId;
    _currentEmployeeId = employeeId;

    final supabase = Supabase.instance.client;

    // Preload user's active conversation memberships for targeted chat notifications
    try {
      final memRes = await supabase
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', userId);
      if (memRes is List) {
        for (final row in memRes) {
          final cid = row['conversation_id']?.toString();
          if (cid != null && cid.isNotEmpty) {
            _myConversationIds.add(cid);
          }
        }
      }
    } catch (e) {
      debugPrint('NotificationService: notice loading conversation_members (run supabase_realtime_chat_fix.sql in Supabase to resolve): $e');
    }

    // Listen to new conversation memberships for this user
    try {
      _subscribe(
        supabase,
        table: 'conversation_members',
        filter: 'user_id=eq.$userId',
        event: PostgresChangeEvent.insert,
        onEvent: (payload) {
          final cid = payload.newRecord['conversation_id']?.toString();
          if (cid != null && cid.isNotEmpty) {
            _myConversationIds.add(cid);
          }
        },
      );
    } catch (_) {}

    // ── 1. Employees: Only notify Admins ──
    _subscribe(
      supabase,
      table: 'employees',
      filter: 'organization_id=eq.$orgId',
      event: PostgresChangeEvent.insert,
      onEvent: (payload) {
        if (role == 'admin' || role == 'owner') {
          final name = payload.newRecord['name']?.toString() ?? 'Someone';
          _addNotification(AppNotification(
            id: 'emp_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.newEmployee,
            title: 'New Employee Added',
            body: '$name has joined your team',
            timestamp: DateTime.now(),
          ));
        }
      },
    );

    // ── 2. Clients Insert: Notify Admin OR Allocated Employee ──
    _subscribeRaw(
      supabase,
      channelName: 'clients_insert_$orgId',
      table: 'clients',
      schema: 'public',
      event: PostgresChangeEvent.insert,
      onEvent: (payload) {
        final name = payload.newRecord['contact_name']?.toString() ??
            payload.newRecord['company_name']?.toString() ??
            payload.newRecord['name']?.toString() ??
            'A client';
        final assignedEmpId = payload.newRecord['assigned_employee_id']?.toString() ?? '';
        final isAllocatedToMe = assignedEmpId.isNotEmpty &&
            (assignedEmpId == userId || (employeeId != null && assignedEmpId == employeeId));

        if (role == 'admin' || role == 'owner') {
          _addNotification(AppNotification(
            id: 'cli_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.newClient,
            title: 'New Client Added',
            body: '$name has been added as a client account',
            timestamp: DateTime.now(),
          ));
        } else if (isAllocatedToMe) {
          _addNotification(AppNotification(
            id: 'cli_alloc_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.clientAllocated,
            title: '👤 Client Allocated to You',
            body: '$name has been assigned to you as client lead',
            timestamp: DateTime.now(),
          ));
        }
      },
    );

    // ── 2b. Clients Update: Notify Employee when Client is Allocated to them ──
    _subscribeRaw(
      supabase,
      channelName: 'clients_update_$orgId',
      table: 'clients',
      schema: 'public',
      event: PostgresChangeEvent.update,
      onEvent: (payload) {
        final oldEmp = payload.oldRecord['assigned_employee_id']?.toString() ?? '';
        final newEmp = payload.newRecord['assigned_employee_id']?.toString() ?? '';
        final name = payload.newRecord['contact_name']?.toString() ??
            payload.newRecord['company_name']?.toString() ??
            payload.newRecord['name']?.toString() ??
            'Client';

        final isNowAllocatedToMe = newEmp.isNotEmpty &&
            (newEmp == userId || (employeeId != null && newEmp == employeeId));

        if (isNowAllocatedToMe && oldEmp != newEmp) {
          _addNotification(AppNotification(
            id: 'cli_alloc_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.clientAllocated,
            title: '👤 Client Allocated to You',
            body: '$name has been allocated to you as client lead',
            timestamp: DateTime.now(),
          ));
        } else if ((role == 'admin' || role == 'owner') && oldEmp != newEmp && newEmp.isNotEmpty) {
          final leadName = payload.newRecord['assigned_employee_name']?.toString() ?? 'an employee';
          _addNotification(AppNotification(
            id: 'cli_lead_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.clientAllocated,
            title: 'Client Lead Assigned',
            body: '$name was assigned to $leadName',
            timestamp: DateTime.now(),
          ));
        }
      },
    );

    // ── 3. Tasks Insert: Only notify Admin OR the specific Allocated Employee ──
    _subscribeRaw(
      supabase,
      channelName: 'tasks_insert_$orgId',
      table: 'tasks',
      schema: 'public',
      event: PostgresChangeEvent.insert,
      onEvent: (payload) {
        final record = payload.newRecord;
        final assignedTo = record['assigned_to']?.toString() ??
            record['assigned_employee_id']?.toString() ??
            '';
        final taskTitle = record['title']?.toString() ?? 'A task';
        final isAllocatedToMe = assignedTo.isNotEmpty &&
            (assignedTo == userId || (employeeId != null && assignedTo == employeeId));

        if (isAllocatedToMe) {
          _addNotification(AppNotification(
            id: 'task_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.taskAssigned,
            title: '📋 Task Assigned to You',
            body: 'Task "$taskTitle" has been allocated to you',
            timestamp: DateTime.now(),
          ));
        } else if (role == 'admin' || role == 'owner') {
          _addNotification(AppNotification(
            id: 'task_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.taskAssigned,
            title: 'New Task Created',
            body: 'New task "$taskTitle" was created',
            timestamp: DateTime.now(),
          ));
        }
      },
    );

    // ── 4. Task status changes: Only notify Admin OR Allocated Employee ──
    _subscribeRaw(
      supabase,
      channelName: 'tasks_update_$orgId',
      table: 'tasks',
      schema: 'public',
      event: PostgresChangeEvent.update,
      onEvent: (payload) {
        final oldStatus = payload.oldRecord['status']?.toString() ?? '';
        final newStatus = payload.newRecord['status']?.toString() ?? '';
        if (oldStatus != newStatus && newStatus.isNotEmpty) {
          final taskTitle = payload.newRecord['title']?.toString() ?? 'A task';
          final assignedTo = payload.newRecord['assigned_to']?.toString() ??
              payload.newRecord['assigned_employee_id']?.toString() ??
              '';
          final isAllocatedToMe = assignedTo.isNotEmpty &&
              (assignedTo == userId || (employeeId != null && assignedTo == employeeId));

          if (isAllocatedToMe) {
            _addNotification(AppNotification(
              id: 'task_upd_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.taskStatusChanged,
              title: '📋 Your Task Updated',
              body: '"$taskTitle" moved to ${_formatStatus(newStatus)}',
              timestamp: DateTime.now(),
            ));
          } else if (role == 'admin' || role == 'owner') {
            _addNotification(AppNotification(
              id: 'task_upd_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.taskStatusChanged,
              title: 'Task Status Updated',
              body: '"$taskTitle" moved to ${_formatStatus(newStatus)}',
              timestamp: DateTime.now(),
            ));
          }
        }
      },
    );

    // ── 5. Consultations / Client Requests: Notify Admin & Allocated Employee ──
    _subscribeRaw(
      supabase,
      channelName: 'requests_insert_$orgId',
      table: 'client_requests',
      schema: 'public',
      event: PostgresChangeEvent.insert,
      onEvent: (payload) {
        final assignedEmp = payload.newRecord['assigned_employee_id']?.toString() ??
            payload.newRecord['assigned_to']?.toString() ??
            '';
        final title = payload.newRecord['title']?.toString() ??
            payload.newRecord['request_title']?.toString() ??
            'Consultation';
        final isAllocatedToMe = assignedEmp.isNotEmpty &&
            (assignedEmp == userId || (employeeId != null && assignedEmp == employeeId));

        if (isAllocatedToMe) {
          _addNotification(AppNotification(
            id: 'req_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.consultationAssigned,
            title: '📅 Consultation Allocated to You',
            body: 'Consultation "$title" has been assigned to you',
            timestamp: DateTime.now(),
          ));
        } else if (role == 'admin' || role == 'owner') {
          _addNotification(AppNotification(
            id: 'req_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.consultationAssigned,
            title: 'New Consultation Request',
            body: 'Request "$title" was submitted',
            timestamp: DateTime.now(),
          ));
        }
      },
    );

    _subscribeRaw(
      supabase,
      channelName: 'requests_update_$orgId',
      table: 'client_requests',
      schema: 'public',
      event: PostgresChangeEvent.update,
      onEvent: (payload) {
        final oldEmp = payload.oldRecord['assigned_employee_id']?.toString() ??
            payload.oldRecord['assigned_to']?.toString() ??
            '';
        final newEmp = payload.newRecord['assigned_employee_id']?.toString() ??
            payload.newRecord['assigned_to']?.toString() ??
            '';
        final title = payload.newRecord['title']?.toString() ??
            payload.newRecord['request_title']?.toString() ??
            'Consultation';
        final isNowAllocatedToMe = newEmp.isNotEmpty &&
            (newEmp == userId || (employeeId != null && newEmp == employeeId));

        if (isNowAllocatedToMe && oldEmp != newEmp) {
          _addNotification(AppNotification(
            id: 'req_alloc_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.consultationAssigned,
            title: '📅 Consultation Allocated to You',
            body: 'Consultation "$title" has been assigned to you',
            timestamp: DateTime.now(),
          ));
        }
      },
    );

    // ── 6. New chat messages: ONLY for conversations the user is a member of ──
    _subscribeRaw(
      supabase,
      channelName: 'messages_$userId',
      table: 'messages',
      schema: 'public',
      event: PostgresChangeEvent.insert,
      onEvent: (payload) {
        final senderId = payload.newRecord['sender_id']?.toString() ?? '';
        final convId = payload.newRecord['conversation_id']?.toString() ?? '';

        if (senderId != userId && senderId.isNotEmpty) {
          // If we have conversation membership tracking, only notify members of that conversation
          if (_myConversationIds.isEmpty || _myConversationIds.contains(convId)) {
            _addNotification(AppNotification(
              id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.newMessage,
              title: '💬 New Message',
              body: 'You received a new message',
              timestamp: DateTime.now(),
            ));
          }
        }
      },
    );

    // ── 7. Invoices: Only notify Admins ──
    if (role == 'admin' || role == 'owner') {
      _subscribeRaw(
        supabase,
        channelName: 'invoices_insert_$orgId',
        table: 'invoices',
        schema: 'public',
        event: PostgresChangeEvent.insert,
        onEvent: (payload) {
          final clientName = payload.newRecord['client_name']?.toString() ?? 'Client';
          _addNotification(AppNotification(
            id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.newInvoice,
            title: 'New Invoice Created',
            body: 'Invoice for $clientName has been created',
            timestamp: DateTime.now(),
          ));
        },
      );

      _subscribeRaw(
        supabase,
        channelName: 'invoices_update_$orgId',
        table: 'invoices',
        schema: 'public',
        event: PostgresChangeEvent.update,
        onEvent: (payload) {
          final oldStatus = payload.oldRecord['status']?.toString() ?? '';
          final newStatus = payload.newRecord['status']?.toString() ?? '';
          if (oldStatus != newStatus && newStatus.toLowerCase() == 'paid') {
            final clientName =
                payload.newRecord['client_name']?.toString() ?? 'Client';
            _addNotification(AppNotification(
              id: 'inv_paid_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.invoicePaid,
              title: '💰 Invoice Paid!',
              body: 'Invoice from $clientName has been marked as paid',
              timestamp: DateTime.now(),
            ));
          }
        },
      );
    }

    // ── 8. New Projects: Notify Admin or Members ──
    _subscribeRaw(
      supabase,
      channelName: 'projects_$orgId',
      table: 'projects',
      schema: 'public',
      event: PostgresChangeEvent.insert,
      onEvent: (payload) {
        if (role == 'admin' || role == 'owner') {
          final name = payload.newRecord['name']?.toString() ?? 'A project';
          _addNotification(AppNotification(
            id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.newProject,
            title: 'New Project Created',
            body: '"$name" project has been created',
            timestamp: DateTime.now(),
          ));
        }
      },
    );

    // ── 9. Leave Requests: Admin gets new submissions, Employee gets approval/status updates ──
    _subscribeRaw(
      supabase,
      channelName: 'leaves_$orgId',
      table: 'leave_requests',
      schema: 'public',
      event: PostgresChangeEvent.insert,
      onEvent: (payload) {
        if (role == 'admin' || role == 'owner') {
          final empName =
              payload.newRecord['employee_name']?.toString() ?? 'An employee';
          final leaveType =
              payload.newRecord['leave_type']?.toString() ?? 'leave';
          _addNotification(AppNotification(
            id: 'leave_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.leaveRequest,
            title: 'Leave Request Submitted',
            body: '$empName requested $leaveType leave',
            timestamp: DateTime.now(),
          ));
        }
      },
    );

    _subscribeRaw(
      supabase,
      channelName: 'leaves_upd_$orgId',
      table: 'leave_requests',
      schema: 'public',
      event: PostgresChangeEvent.update,
      onEvent: (payload) {
        final reqUserId = payload.newRecord['user_id']?.toString() ?? '';
        final oldStatus = payload.oldRecord['status']?.toString() ?? '';
        final newStatus = payload.newRecord['status']?.toString() ?? '';
        if (oldStatus != newStatus && newStatus.isNotEmpty) {
          if (reqUserId == userId) {
            _addNotification(AppNotification(
              id: 'leave_upd_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.leaveRequest,
              title: '🌴 Leave Request $newStatus',
              body: 'Your leave request has been marked as $newStatus',
              timestamp: DateTime.now(),
            ));
          } else if (role == 'admin' || role == 'owner') {
            _addNotification(AppNotification(
              id: 'leave_adm_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.leaveRequest,
              title: 'Leave Request Updated',
              body: 'Request status changed to $newStatus',
              timestamp: DateTime.now(),
            ));
          }
        }
      },
    );

    // ── 10. Invitation accepted: Only Admin ──
    _subscribeRaw(
      supabase,
      channelName: 'members_$orgId',
      table: 'organization_memberships',
      schema: 'public',
      event: PostgresChangeEvent.insert,
      onEvent: (payload) {
        if (role == 'admin' || role == 'owner') {
          _addNotification(AppNotification(
            id: 'inv_acc_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.invitationAccepted,
            title: 'Invitation Accepted',
            body: 'A new member has joined your organization',
            timestamp: DateTime.now(),
          ));
        }
      },
    );

    debugPrint('NotificationService: initialized with ${_channels.length} subscriptions for role=$role');
  }

  void _subscribe(
    SupabaseClient supabase, {
    required String table,
    required String filter,
    required PostgresChangeEvent event,
    required void Function(PostgresChangePayload) onEvent,
  }) {
    try {
      final channel = supabase
          .channel('notif_${table}_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: event,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: filter.split('=eq.').first,
              value: filter.split('=eq.').last,
            ),
            callback: onEvent,
          )
          .subscribe();
      _channels.add(channel);
    } catch (e) {
      debugPrint('NotificationService subscribe error for $table: $e');
    }
  }

  void _subscribeRaw(
    SupabaseClient supabase, {
    required String channelName,
    required String table,
    required String schema,
    required PostgresChangeEvent event,
    required void Function(PostgresChangePayload) onEvent,
  }) {
    try {
      final channel = supabase
          .channel(channelName)
          .onPostgresChanges(
            event: event,
            schema: schema,
            table: table,
            callback: onEvent,
          )
          .subscribe();
      _channels.add(channel);
    } catch (e) {
      debugPrint('NotificationService subscribeRaw error for $table: $e');
    }
  }

  void _addNotification(AppNotification notification) {
    _notifications.insert(0, notification); // newest first
    if (_notifications.length > 100) {
      _notifications.removeLast(); // cap at 100
    }
    _streamController.add(List.unmodifiable(_notifications));
    onToast?.call(notification);
  }

  void markAllRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    _streamController.add(List.unmodifiable(_notifications));
  }

  void markRead(String id) {
    final n = _notifications.firstWhere((n) => n.id == id, orElse: () => _notifications.first);
    n.isRead = true;
    _streamController.add(List.unmodifiable(_notifications));
  }

  void clearAll() {
    _notifications.clear();
    _streamController.add([]);
  }

  void dispose() {
    for (final ch in _channels) {
      try {
        Supabase.instance.client.removeChannel(ch);
      } catch (_) {}
    }
    _channels.clear();
    _myConversationIds.clear();
    _initialized = false;
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';
      case 'done':
      case 'completed':
        return 'Done ✅';
      case 'todo':
        return 'To Do';
      case 'review':
        return 'In Review';
      case 'approved':
        return 'Approved ✅';
      case 'rejected':
        return 'Rejected ❌';
      default:
        return status;
    }
  }
}

