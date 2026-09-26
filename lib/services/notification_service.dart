import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  invitationSent,
  invitationAccepted,
  invitationRevoked,
  emailDelivery,
  system,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;
  final Map<String, dynamic>? payload;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.payload,
  });

  String get category {
    switch (type) {
      case NotificationType.invitationSent:
      case NotificationType.invitationAccepted:
      case NotificationType.invitationRevoked:
      case NotificationType.emailDelivery:
        return 'invitations';
      case NotificationType.taskAssigned:
      case NotificationType.taskStatusChanged:
        return 'tasks';
      case NotificationType.newMessage:
        return 'messages';
      case NotificationType.newInvoice:
      case NotificationType.invoicePaid:
        return 'billing';
      case NotificationType.newEmployee:
      case NotificationType.newClient:
      case NotificationType.clientAllocated:
      case NotificationType.leaveRequest:
        return 'team';
      case NotificationType.newProject:
      case NotificationType.consultationAssigned:
      case NotificationType.system:
        return 'general';
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'invitations':
        return 'Invitations';
      case 'tasks':
        return 'Tasks';
      case 'messages':
        return 'Messages';
      case 'billing':
        return 'Billing';
      case 'team':
        return 'Team';
      default:
        return 'General';
    }
  }

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
      case NotificationType.invitationSent:
        return Icons.forward_to_inbox_rounded;
      case NotificationType.invitationAccepted:
        return Icons.verified_user_rounded;
      case NotificationType.invitationRevoked:
        return Icons.cancel_schedule_send_rounded;
      case NotificationType.emailDelivery:
        return Icons.send_rounded;
      case NotificationType.system:
        return Icons.notifications_active_rounded;
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
      case NotificationType.invitationSent:
        return const Color(0xFFF39C12);
      case NotificationType.invitationAccepted:
        return const Color(0xFF2ECC71);
      case NotificationType.invitationRevoked:
        return const Color(0xFFE74C3C);
      case NotificationType.emailDelivery:
        return const Color(0xFF3498DB);
      case NotificationType.system:
        return const Color(0xFFA29BFE);
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  factory AppNotification.fromSupabase(Map<String, dynamic> row) {
    final eventType = row['event_type']?.toString().toLowerCase() ?? '';
    NotificationType type;
    switch (eventType) {
      case 'invitation_sent':
        type = NotificationType.invitationSent;
        break;
      case 'invitation_accepted':
        type = NotificationType.invitationAccepted;
        break;
      case 'invitation_revoked':
      case 'invitation_expired':
        type = NotificationType.invitationRevoked;
        break;
      case 'email_delivery':
      case 'email_sent':
        type = NotificationType.emailDelivery;
        break;
      case 'new_employee':
        type = NotificationType.newEmployee;
        break;
      case 'new_client':
        type = NotificationType.newClient;
        break;
      case 'client_allocated':
        type = NotificationType.clientAllocated;
        break;
      case 'task_assigned':
        type = NotificationType.taskAssigned;
        break;
      case 'task_status_changed':
        type = NotificationType.taskStatusChanged;
        break;
      case 'consultation_assigned':
        type = NotificationType.consultationAssigned;
        break;
      case 'new_message':
        type = NotificationType.newMessage;
        break;
      case 'new_invoice':
        type = NotificationType.newInvoice;
        break;
      case 'invoice_paid':
        type = NotificationType.invoicePaid;
        break;
      case 'new_project':
        type = NotificationType.newProject;
        break;
      case 'leave_request':
        type = NotificationType.leaveRequest;
        break;
      default:
        type = NotificationType.system;
    }

    DateTime ts = DateTime.now();
    if (row['created_at'] != null) {
      ts = DateTime.tryParse(row['created_at'].toString())?.toLocal() ?? DateTime.now();
    }

    return AppNotification(
      id: row['id']?.toString() ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: row['title']?.toString() ?? 'Notification',
      body: row['body']?.toString() ?? '',
      timestamp: ts,
      isRead: row['is_read'] == true,
      payload: row['payload'] is Map ? Map<String, dynamic>.from(row['payload']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'payload': payload,
    };
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
  final Set<String> _myClientProjectIds = {};
  final Set<String> _myAssignedClientIds = {};
  bool _initialized = false;
  String? _currentOrgId;
  String? _currentUserId;
  String? _currentRole;
  String? _currentEmployeeId;
  String? _currentClientId;

  void registerConversationId(String conversationId) {
    if (conversationId.isNotEmpty) {
      _myConversationIds.add(conversationId);
    }
  }

  void registerClientProjectId(String projectId) {
    if (projectId.isNotEmpty) {
      _myClientProjectIds.add(projectId);
    }
  }

  void registerAssignedClientId(String clientId) {
    if (clientId.isNotEmpty) {
      _myAssignedClientIds.add(clientId);
    }
  }

  // ── Initialize & subscribe to all Supabase Realtime events ──
  Future<void> initialize({
    required String orgId,
    required String userId,
    required String role,
    String? employeeId,
    String? clientId,
  }) async {
    if (_initialized &&
        _currentOrgId == orgId &&
        _currentUserId == userId &&
        _currentEmployeeId == employeeId &&
        _currentClientId == clientId &&
        _currentRole == role) {
      return;
    }

    // Cancel previous subscriptions
    dispose();
    _initialized = true;
    _currentOrgId = orgId;
    _currentUserId = userId;
    _currentRole = role;
    _currentEmployeeId = employeeId;
    _currentClientId = clientId;

    final supabase = Supabase.instance.client;

    // ── 0. Preload recent notifications from public.notifications ──
    try {
      final res = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(40);
      if (res.isNotEmpty) {
        _notifications.clear();
        for (final item in res) {
          _notifications.add(AppNotification.fromSupabase(item));
        }
        _streamController.add(List.unmodifiable(_notifications));
      }
    } catch (dbErr) {
      debugPrint('NotificationService: preloading notifications note: $dbErr');
    }

    // Preload user's active conversation memberships for targeted chat notifications
    try {
      final memRes = await supabase
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', userId);
      for (final row in memRes) {
        final cid = row['conversation_id']?.toString();
        if (cid != null && cid.isNotEmpty) {
          _myConversationIds.add(cid);
        }
      }
    } catch (e) {
      debugPrint('NotificationService: notice loading conversation_members: $e');
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

    // Preload Client Profile and Project IDs if user role is client
    if (role == 'client') {
      if (_currentClientId == null || _currentClientId!.isEmpty) {
        try {
          final clientRes = await supabase
              .from('clients')
              .select('id')
              .or('user_id.eq.$userId,email.ilike.${supabase.auth.currentUser?.email ?? ''}')
              .limit(1)
              .maybeSingle();
          if (clientRes != null && clientRes['id'] != null) {
            _currentClientId = clientRes['id'].toString();
          }
        } catch (e) {
          debugPrint('NotificationService: finding clientId note: $e');
        }
      }

      if (_currentClientId != null && _currentClientId!.isNotEmpty) {
        try {
          final projRes = await supabase
              .from('projects')
              .select('id')
              .eq('client_id', _currentClientId!);
          for (final row in projRes) {
            final pid = row['id']?.toString();
            if (pid != null && pid.isNotEmpty) {
              _myClientProjectIds.add(pid);
            }
          }
        } catch (e) {
          debugPrint('NotificationService: loading client projects note: $e');
        }
      }
    } else if (role == 'employee') {
      try {
        final filterCond = employeeId != null && employeeId.isNotEmpty
            ? 'assigned_employee_id.eq.$userId,assigned_employee_id.eq.$employeeId'
            : 'assigned_employee_id.eq.$userId';
        final clientRes = await supabase
            .from('clients')
            .select('id')
            .or(filterCond);
        for (final row in clientRes) {
          final cid = row['id']?.toString();
          if (cid != null && cid.isNotEmpty) {
            _myAssignedClientIds.add(cid);
          }
        }

        if (_myAssignedClientIds.isNotEmpty) {
          for (final cid in _myAssignedClientIds) {
            final pRes = await supabase
                .from('projects')
                .select('id')
                .eq('client_id', cid);
            for (final row in pRes) {
              final pid = row['id']?.toString();
              if (pid != null && pid.isNotEmpty) {
                _myClientProjectIds.add(pid);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('NotificationService: loading employee assigned client projects note: $e');
      }
    }

    // ── 0b. Listen to targeted user notifications from public.notifications ──
    try {
      _subscribeRaw(
        supabase,
        channelName: 'user_notifications_$userId',
        table: 'notifications',
        schema: 'public',
        event: PostgresChangeEvent.insert,
        onEvent: (payload) {
          final record = payload.newRecord;
          if (record['user_id']?.toString() == userId) {
            final notif = AppNotification.fromSupabase(record);
            if (!_notifications.any((n) => n.id == notif.id)) {
              _addNotification(notif);
            }
          }
        },
      );
    } catch (e) {
      debugPrint('NotificationService: notifications table channel notice: $e');
    }

    // ── 1. Employees: Only notify Admins (Never Clients) ──
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

    // ── 2b. Clients Update: Notify Employee or Specific Client if Account Manager Assigned ──
    _subscribeRaw(
      supabase,
      channelName: 'clients_update_$orgId',
      table: 'clients',
      schema: 'public',
      event: PostgresChangeEvent.update,
      onEvent: (payload) {
        final recId = payload.newRecord['id']?.toString() ?? '';
        final oldEmp = payload.oldRecord['assigned_employee_id']?.toString() ?? '';
        final newEmp = payload.newRecord['assigned_employee_id']?.toString() ?? '';
        final name = payload.newRecord['contact_name']?.toString() ??
            payload.newRecord['company_name']?.toString() ??
            payload.newRecord['name']?.toString() ??
            'Client';

        final isNowAllocatedToMe = newEmp.isNotEmpty &&
            (newEmp == userId || (employeeId != null && newEmp == employeeId));

        if (role == 'client') {
          // Client only gets notified if their own account was updated
          if (_currentClientId != null && recId == _currentClientId && oldEmp != newEmp && newEmp.isNotEmpty) {
            final leadName = payload.newRecord['assigned_employee_name']?.toString() ?? 'An account lead';
            _addNotification(AppNotification(
              id: 'cli_mgr_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.clientAllocated,
              title: '👤 Account Manager Assigned',
              body: '$leadName has been assigned as your dedicated account lead',
              timestamp: DateTime.now(),
            ));
          }
        } else if (isNowAllocatedToMe && oldEmp != newEmp) {
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

    // ── 3. Tasks Insert: Notify Admin, Allocated Employee, Client Lead, OR Client for their project works ──
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
        final taskProjectId = record['project_id']?.toString() ?? '';
        final isAllocatedToMe = assignedTo.isNotEmpty &&
            (assignedTo == userId || (employeeId != null && assignedTo == employeeId));

        if (role == 'client') {
          // Client receives notifications for tasks within their own enterprise projects
          if (taskProjectId.isNotEmpty && _myClientProjectIds.contains(taskProjectId)) {
            _addNotification(AppNotification(
              id: 'task_cli_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.taskAssigned,
              title: '📋 Work Started on Project',
              body: 'New task "$taskTitle" was added to your project workflow',
              timestamp: DateTime.now(),
              payload: {'task_id': record['id'], 'project_id': taskProjectId},
            ));
          }
        } else if (isAllocatedToMe) {
          _addNotification(AppNotification(
            id: 'task_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.taskAssigned,
            title: '📋 Task Assigned to You',
            body: 'Task "$taskTitle" has been allocated to you',
            timestamp: DateTime.now(),
            payload: {'task_id': record['id'], 'project_id': taskProjectId},
          ));
        } else if (role == 'employee' && taskProjectId.isNotEmpty && _myClientProjectIds.contains(taskProjectId)) {
          _addNotification(AppNotification(
            id: 'task_emp_lead_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.taskAssigned,
            title: '📋 Task Added to Client Project',
            body: 'Task "$taskTitle" was added to your client\'s project',
            timestamp: DateTime.now(),
            payload: {'task_id': record['id'], 'project_id': taskProjectId},
          ));
        } else if (role == 'admin' || role == 'owner') {
          _addNotification(AppNotification(
            id: 'task_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.taskAssigned,
            title: 'New Task Created',
            body: 'New task "$taskTitle" was created',
            timestamp: DateTime.now(),
            payload: {'task_id': record['id'], 'project_id': taskProjectId},
          ));
        }
      },
    );

    // ── 4. Task status changes: Notify Admin, Allocated Employee, Client Lead, OR Client ──
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
          final taskProjectId = payload.newRecord['project_id']?.toString() ?? '';
          final assignedTo = payload.newRecord['assigned_to']?.toString() ??
              payload.newRecord['assigned_employee_id']?.toString() ??
              '';
          final isAllocatedToMe = assignedTo.isNotEmpty &&
              (assignedTo == userId || (employeeId != null && assignedTo == employeeId));

          if (role == 'client') {
            // Client receives notifications for tasks within their own enterprise projects
            if (taskProjectId.isNotEmpty && _myClientProjectIds.contains(taskProjectId)) {
              _addNotification(AppNotification(
                id: 'task_upd_cli_${DateTime.now().millisecondsSinceEpoch}',
                type: NotificationType.taskStatusChanged,
                title: '📋 Project Work Progress',
                body: '"$taskTitle" moved to ${_formatStatus(newStatus)}',
                timestamp: DateTime.now(),
                payload: {'task_id': payload.newRecord['id'], 'project_id': taskProjectId},
              ));
            }
          } else if (isAllocatedToMe) {
            _addNotification(AppNotification(
              id: 'task_upd_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.taskStatusChanged,
              title: '📋 Your Task Updated',
              body: '"$taskTitle" moved to ${_formatStatus(newStatus)}',
              timestamp: DateTime.now(),
              payload: {'task_id': payload.newRecord['id'], 'project_id': taskProjectId},
            ));
          } else if (role == 'employee' && taskProjectId.isNotEmpty && _myClientProjectIds.contains(taskProjectId)) {
            _addNotification(AppNotification(
              id: 'task_upd_lead_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.taskStatusChanged,
              title: '📋 Client Task Progress',
              body: '"$taskTitle" moved to ${_formatStatus(newStatus)}',
              timestamp: DateTime.now(),
              payload: {'task_id': payload.newRecord['id'], 'project_id': taskProjectId},
            ));
          } else if (role == 'admin' || role == 'owner') {
            _addNotification(AppNotification(
              id: 'task_upd_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.taskStatusChanged,
              title: 'Task Status Updated',
              body: '"$taskTitle" moved to ${_formatStatus(newStatus)}',
              timestamp: DateTime.now(),
              payload: {'task_id': payload.newRecord['id'], 'project_id': taskProjectId},
            ));
          }
        }
      },
    );

    // ── 5. Consultations / Client Requests: Symmetrical notifications for Client, Admin & Employee ──
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
        final reqClientId = payload.newRecord['client_id']?.toString() ?? '';
        final reqUserId = payload.newRecord['user_id']?.toString() ?? '';
        final title = payload.newRecord['title']?.toString() ??
            payload.newRecord['request_title']?.toString() ??
            'Consultation';
        final isAllocatedToMe = assignedEmp.isNotEmpty &&
            (assignedEmp == userId || (employeeId != null && assignedEmp == employeeId));

        if (role == 'client') {
          if ((_currentClientId != null && reqClientId == _currentClientId) || (reqUserId.isNotEmpty && reqUserId == userId)) {
            _addNotification(AppNotification(
              id: 'req_cli_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.consultationAssigned,
              title: '📅 Consultation Request Logged',
              body: 'Your request "$title" has been received by your account team',
              timestamp: DateTime.now(),
              payload: {'request_id': payload.newRecord['id']},
            ));
          }
        } else if (isAllocatedToMe) {
          _addNotification(AppNotification(
            id: 'req_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.consultationAssigned,
            title: '📅 Consultation Allocated to You',
            body: 'Consultation "$title" has been assigned to you',
            timestamp: DateTime.now(),
            payload: {'request_id': payload.newRecord['id']},
          ));
        } else if (role == 'employee' && _myAssignedClientIds.contains(reqClientId)) {
          _addNotification(AppNotification(
            id: 'req_lead_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.consultationAssigned,
            title: '📅 Consultation Logged for Your Client',
            body: 'Request "$title" was submitted by your client',
            timestamp: DateTime.now(),
            payload: {'request_id': payload.newRecord['id']},
          ));
        } else if (role == 'admin' || role == 'owner') {
          _addNotification(AppNotification(
            id: 'req_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.consultationAssigned,
            title: 'New Consultation Request',
            body: 'Request "$title" was submitted by client',
            timestamp: DateTime.now(),
            payload: {'request_id': payload.newRecord['id']},
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
        final oldStatus = payload.oldRecord['status']?.toString() ?? '';
        final newStatus = payload.newRecord['status']?.toString() ?? '';
        final reqClientId = payload.newRecord['client_id']?.toString() ?? '';
        final reqUserId = payload.newRecord['user_id']?.toString() ?? '';
        final title = payload.newRecord['title']?.toString() ??
            payload.newRecord['request_title']?.toString() ??
            'Consultation';

        final isNowAllocatedToMe = newEmp.isNotEmpty &&
            (newEmp == userId || (employeeId != null && newEmp == employeeId));

        if (role == 'client') {
          if ((_currentClientId != null && reqClientId == _currentClientId) || (reqUserId.isNotEmpty && reqUserId == userId)) {
            if (oldStatus != newStatus && newStatus.isNotEmpty) {
              _addNotification(AppNotification(
                id: 'req_upd_cli_${DateTime.now().millisecondsSinceEpoch}',
                type: NotificationType.consultationAssigned,
                title: '📅 Consultation Status Update',
                body: 'Request "$title" is now ${_formatStatus(newStatus)}',
                timestamp: DateTime.now(),
                payload: {'request_id': payload.newRecord['id']},
              ));
            }
          }
        } else if (isNowAllocatedToMe && oldEmp != newEmp) {
          _addNotification(AppNotification(
            id: 'req_alloc_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.consultationAssigned,
            title: '📅 Consultation Allocated to You',
            body: 'Consultation "$title" has been assigned to you',
            timestamp: DateTime.now(),
            payload: {'request_id': payload.newRecord['id']},
          ));
        } else if (role == 'employee' && (_myAssignedClientIds.contains(reqClientId) || isNowAllocatedToMe)) {
          if (oldStatus != newStatus && newStatus.isNotEmpty) {
            _addNotification(AppNotification(
              id: 'req_upd_emp_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.consultationAssigned,
              title: '📅 Client Consultation Updated',
              body: 'Consultation "$title" is now ${_formatStatus(newStatus)}',
              timestamp: DateTime.now(),
              payload: {'request_id': payload.newRecord['id']},
            ));
          }
        } else if (role == 'admin' || role == 'owner') {
          if (oldStatus != newStatus && newStatus.isNotEmpty) {
            _addNotification(AppNotification(
              id: 'req_upd_adm_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.consultationAssigned,
              title: '📅 Consultation Status Updated',
              body: 'Request "$title" is now ${_formatStatus(newStatus)}',
              timestamp: DateTime.now(),
              payload: {'request_id': payload.newRecord['id']},
            ));
          }
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
          if (_myConversationIds.contains(convId)) {
            _addNotification(AppNotification(
              id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.newMessage,
              title: '💬 New Message',
              body: 'You received a new message',
              timestamp: DateTime.now(),
              payload: {'conversation_id': convId},
            ));
          }
        }
      },
    );

    // ── 7. Invoices: Notify Admins, Specific Client, and Assigned Employee ──
    _subscribeRaw(
      supabase,
      channelName: 'invoices_insert_$orgId',
      table: 'invoices',
      schema: 'public',
      event: PostgresChangeEvent.insert,
      onEvent: (payload) {
        final invClientId = payload.newRecord['client_id']?.toString() ?? '';
        final clientName = payload.newRecord['client_name']?.toString() ?? 'Client';
        final invNum = payload.newRecord['invoice_number']?.toString() ?? '';
        final total = payload.newRecord['total']?.toString() ?? '0';

        if (role == 'admin' || role == 'owner') {
          _addNotification(AppNotification(
            id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.newInvoice,
            title: 'New Invoice Created',
            body: 'Invoice for $clientName has been created',
            timestamp: DateTime.now(),
            payload: {'invoice_id': payload.newRecord['id']},
          ));
        } else if (role == 'client' && _currentClientId != null && invClientId == _currentClientId) {
          _addNotification(AppNotification(
            id: 'inv_cli_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.newInvoice,
            title: '🧾 New Invoice Issued',
            body: 'Invoice #$invNum for ₹$total is now available in your portal',
            timestamp: DateTime.now(),
            payload: {'invoice_id': payload.newRecord['id']},
          ));
        } else if (role == 'employee' && _myAssignedClientIds.contains(invClientId)) {
          _addNotification(AppNotification(
            id: 'inv_emp_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.newInvoice,
            title: '🧾 Client Invoice Issued',
            body: 'Invoice #$invNum (₹$total) issued for $clientName',
            timestamp: DateTime.now(),
            payload: {'invoice_id': payload.newRecord['id']},
          ));
        }
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
        final invClientId = payload.newRecord['client_id']?.toString() ?? '';
        final invNum = payload.newRecord['invoice_number']?.toString() ?? '';

        if (oldStatus != newStatus && newStatus.isNotEmpty) {
          if (role == 'admin' || role == 'owner') {
            if (newStatus.toLowerCase() == 'paid') {
              final clientName = payload.newRecord['client_name']?.toString() ?? 'Client';
              _addNotification(AppNotification(
                id: 'inv_paid_${DateTime.now().millisecondsSinceEpoch}',
                type: NotificationType.invoicePaid,
                title: '💰 Invoice Paid!',
                body: 'Invoice from $clientName has been marked as paid',
                timestamp: DateTime.now(),
                payload: {'invoice_id': payload.newRecord['id']},
              ));
            }
          } else if (role == 'client' && _currentClientId != null && invClientId == _currentClientId) {
            _addNotification(AppNotification(
              id: 'inv_upd_cli_${DateTime.now().millisecondsSinceEpoch}',
              type: newStatus.toLowerCase() == 'paid' ? NotificationType.invoicePaid : NotificationType.newInvoice,
              title: newStatus.toLowerCase() == 'paid' ? '💰 Payment Confirmed' : '🧾 Invoice Status Updated',
              body: 'Invoice #$invNum is now marked as $newStatus',
              timestamp: DateTime.now(),
              payload: {'invoice_id': payload.newRecord['id']},
            ));
          } else if (role == 'employee' && _myAssignedClientIds.contains(invClientId)) {
            final clientName = payload.newRecord['client_name']?.toString() ?? 'Client';
            _addNotification(AppNotification(
              id: 'inv_upd_emp_${DateTime.now().millisecondsSinceEpoch}',
              type: newStatus.toLowerCase() == 'paid' ? NotificationType.invoicePaid : NotificationType.newInvoice,
              title: newStatus.toLowerCase() == 'paid' ? '💰 Client Invoice Paid!' : '🧾 Client Invoice Updated',
              body: 'Invoice #$invNum for $clientName is now $newStatus',
              timestamp: DateTime.now(),
              payload: {'invoice_id': payload.newRecord['id']},
            ));
          }
        }
      },
    );

    // ── 8. Projects: Notify Admin, Specific Client, and Assigned Employee ──
    _subscribeRaw(
      supabase,
      channelName: 'projects_insert_$orgId',
      table: 'projects',
      schema: 'public',
      event: PostgresChangeEvent.insert,
      onEvent: (payload) {
        final record = payload.newRecord;
        final name = record['name']?.toString() ?? 'A project';
        final pClientId = record['client_id']?.toString() ?? '';

        if (role == 'admin' || role == 'owner') {
          _addNotification(AppNotification(
            id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.newProject,
            title: 'New Project Created',
            body: '"$name" project has been created',
            timestamp: DateTime.now(),
            payload: {'project_id': record['id']},
          ));
        } else if (role == 'client' && _currentClientId != null && pClientId == _currentClientId) {
          final pid = record['id']?.toString();
          if (pid != null && pid.isNotEmpty) {
            _myClientProjectIds.add(pid);
          }
          _addNotification(AppNotification(
            id: 'proj_cli_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.newProject,
            title: '📁 New Enterprise Project',
            body: 'Project "$name" has been initiated for your account',
            timestamp: DateTime.now(),
            payload: {'project_id': pid},
          ));
        } else if (role == 'employee' && _myAssignedClientIds.contains(pClientId)) {
          final pid = record['id']?.toString();
          if (pid != null && pid.isNotEmpty) {
            _myClientProjectIds.add(pid);
          }
          _addNotification(AppNotification(
            id: 'proj_emp_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.newProject,
            title: '📁 New Client Project',
            body: 'Project "$name" was initiated for your client',
            timestamp: DateTime.now(),
            payload: {'project_id': pid},
          ));
        }
      },
    );

    _subscribeRaw(
      supabase,
      channelName: 'projects_update_$orgId',
      table: 'projects',
      schema: 'public',
      event: PostgresChangeEvent.update,
      onEvent: (payload) {
        final oldStatus = payload.oldRecord['status']?.toString() ?? '';
        final newStatus = payload.newRecord['status']?.toString() ?? '';
        final pClientId = payload.newRecord['client_id']?.toString() ?? '';
        final name = payload.newRecord['name']?.toString() ?? 'Project';

        if (role == 'admin' || role == 'owner') {
          if (oldStatus != newStatus && newStatus.isNotEmpty) {
            _addNotification(AppNotification(
              id: 'proj_upd_adm_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.newProject,
              title: '📁 Project Status Updated',
              body: 'Project "$name" is now $newStatus',
              timestamp: DateTime.now(),
              payload: {'project_id': payload.newRecord['id']},
            ));
          }
        } else if (role == 'client' && _currentClientId != null && pClientId == _currentClientId) {
          if (oldStatus != newStatus && newStatus.isNotEmpty) {
            _addNotification(AppNotification(
              id: 'proj_upd_cli_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.newProject,
              title: '📁 Project Milestone Update',
              body: 'Project "$name" status is now $newStatus',
              timestamp: DateTime.now(),
              payload: {'project_id': payload.newRecord['id']},
            ));
          }
        } else if (role == 'employee' && _myAssignedClientIds.contains(pClientId)) {
          if (oldStatus != newStatus && newStatus.isNotEmpty) {
            _addNotification(AppNotification(
              id: 'proj_upd_emp_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.newProject,
              title: '📁 Client Project Update',
              body: 'Project "$name" for your client is now $newStatus',
              timestamp: DateTime.now(),
              payload: {'project_id': payload.newRecord['id']},
            ));
          }
        }
      },
    );

    // ── 9. Leave Requests: Strictly Admin and Requesting Employee (Never Clients) ──
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

    // ── 10. Invitations Table: Direct Realtime for Creation & Status Changes ──
    if (role == 'admin' || role == 'owner') {
      _subscribeRaw(
        supabase,
        channelName: 'invitations_insert_$orgId',
        table: 'invitations',
        schema: 'public',
        event: PostgresChangeEvent.insert,
        onEvent: (payload) {
          final email = payload.newRecord['email']?.toString() ?? 'member';
          final invRole = payload.newRecord['role']?.toString() ?? 'member';
          final token = payload.newRecord['token']?.toString() ?? '';

          _addNotification(AppNotification(
            id: 'inv_sent_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.invitationSent,
            title: '📩 Invitation Created',
            body: 'Access code generated for $email ($invRole)',
            timestamp: DateTime.now(),
            payload: {
              'email': email,
              'role': invRole,
              'code': token,
            },
          ));
        },
      );

      _subscribeRaw(
        supabase,
        channelName: 'invitations_update_$orgId',
        table: 'invitations',
        schema: 'public',
        event: PostgresChangeEvent.update,
        onEvent: (payload) {
          final oldStatus = payload.oldRecord['status']?.toString() ?? '';
          final newStatus = payload.newRecord['status']?.toString() ?? '';
          final email = payload.newRecord['email']?.toString() ?? 'A member';
          final invRole = payload.newRecord['role']?.toString() ?? 'member';
          final token = payload.newRecord['token']?.toString() ?? '';

          if (oldStatus != newStatus) {
            if (newStatus == 'accepted') {
              _addNotification(AppNotification(
                id: 'inv_acc_${DateTime.now().millisecondsSinceEpoch}',
                type: NotificationType.invitationAccepted,
                title: '🎉 Invitation Accepted!',
                body: '$email has joined the organization as $invRole',
                timestamp: DateTime.now(),
                payload: {
                  'email': email,
                  'role': invRole,
                  'code': token,
                },
              ));
            } else if (newStatus == 'expired') {
              _addNotification(AppNotification(
                id: 'inv_exp_${DateTime.now().millisecondsSinceEpoch}',
                type: NotificationType.invitationRevoked,
                title: '⏱️ Invitation Expired',
                body: 'Access code for $email has expired',
                timestamp: DateTime.now(),
                payload: {
                  'email': email,
                  'role': invRole,
                },
              ));
            }
          }
        },
      );
    }

    // ── 11. Organization Memberships: Fallback for member join ──
    _subscribeRaw(
      supabase,
      channelName: 'members_$orgId',
      table: 'organization_memberships',
      schema: 'public',
      event: PostgresChangeEvent.insert,
      onEvent: (payload) {
        if (role == 'admin' || role == 'owner') {
          final joinedRole = payload.newRecord['role']?.toString() ?? 'member';
          _addNotification(AppNotification(
            id: 'mem_join_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.invitationAccepted,
            title: '🎉 New Member Joined',
            body: 'A new user has joined the organization ($joinedRole)',
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

  /// Manually add a notification locally and trigger toast/badge
  Future<void> notifyLocal({
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    bool saveToDatabase = false,
  }) async {
    final notif = AppNotification(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      payload: payload,
    );
    _addNotification(notif);

    if (saveToDatabase && _currentOrgId != null && _currentUserId != null) {
      try {
        await Supabase.instance.client.from('notifications').insert({
          'organization_id': _currentOrgId,
          'user_id': _currentUserId,
          'title': title,
          'body': body,
          'event_type': _typeToEventType(type),
          'payload': payload ?? {},
          'is_read': false,
        });
      } catch (e) {
        debugPrint('NotificationService: saveToDatabase note: $e');
      }
    }
  }

  void _addNotification(AppNotification notification) {
    // Avoid exact duplicate
    if (_notifications.any((n) => n.id == notification.id)) return;

    _notifications.insert(0, notification); // newest first
    if (_notifications.length > 100) {
      _notifications.removeLast(); // cap at 100
    }
    _streamController.add(List.unmodifiable(_notifications));

    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    onToast?.call(notification);
  }

  Future<void> markAllRead() async {
    for (final n in _notifications) {
      n.isRead = true;
    }
    _streamController.add(List.unmodifiable(_notifications));

    if (_currentUserId != null) {
      try {
        await Supabase.instance.client
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', _currentUserId!);
      } catch (e) {
        debugPrint('NotificationService: markAllRead DB sync note: $e');
      }
    }
  }

  Future<void> markRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].isRead = true;
      _streamController.add(List.unmodifiable(_notifications));

      if (!id.startsWith('local_') && !id.contains('_')) {
        try {
          await Supabase.instance.client
              .from('notifications')
              .update({'is_read': true})
              .eq('id', id);
        } catch (_) {}
      }
    }
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    _streamController.add(List.unmodifiable(_notifications));

    if (!id.startsWith('local_') && !id.contains('_')) {
      try {
        await Supabase.instance.client
            .from('notifications')
            .delete()
            .eq('id', id);
      } catch (_) {}
    }
  }

  Future<void> clearAll() async {
    _notifications.clear();
    _streamController.add([]);

    if (_currentUserId != null) {
      try {
        await Supabase.instance.client
            .from('notifications')
            .delete()
            .eq('user_id', _currentUserId!);
      } catch (_) {}
    }
  }

  void dispose() {
    for (final ch in _channels) {
      try {
        Supabase.instance.client.removeChannel(ch);
      } catch (_) {}
    }
    _channels.clear();
    _myConversationIds.clear();
    _myClientProjectIds.clear();
    _myAssignedClientIds.clear();
    _currentClientId = null;
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

  String _typeToEventType(NotificationType type) {
    switch (type) {
      case NotificationType.invitationSent:
        return 'invitation_sent';
      case NotificationType.invitationAccepted:
        return 'invitation_accepted';
      case NotificationType.invitationRevoked:
        return 'invitation_revoked';
      case NotificationType.emailDelivery:
        return 'email_delivery';
      case NotificationType.newEmployee:
        return 'new_employee';
      case NotificationType.newClient:
        return 'new_client';
      case NotificationType.clientAllocated:
        return 'client_allocated';
      case NotificationType.taskAssigned:
        return 'task_assigned';
      case NotificationType.taskStatusChanged:
        return 'task_status_changed';
      case NotificationType.consultationAssigned:
        return 'consultation_assigned';
      case NotificationType.newMessage:
        return 'new_message';
      case NotificationType.newInvoice:
        return 'new_invoice';
      case NotificationType.invoicePaid:
        return 'invoice_paid';
      case NotificationType.newProject:
        return 'new_project';
      case NotificationType.leaveRequest:
        return 'leave_request';
      case NotificationType.system:
        return 'system';
    }
  }
}


