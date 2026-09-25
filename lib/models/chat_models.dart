import 'dart:convert';

enum MessageDeliveryStatus {
  sending,
  sent,
  delivered,
  error,
}

enum ConversationType {
  direct,
  group,
  project,
}

class ConversationMemberModel {
  final String id;
  final String conversationId;
  final String userId;
  final DateTime joinedAt;
  final DateTime lastReadAt;
  final String? fullName;
  final String? avatarUrl;
  final String? role;

  const ConversationMemberModel({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.joinedAt,
    required this.lastReadAt,
    this.fullName,
    this.avatarUrl,
    this.role,
  });

  factory ConversationMemberModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] is Map ? map['profiles'] as Map<String, dynamic> : null;
    return ConversationMemberModel(
      id: map['id']?.toString() ?? '',
      conversationId: map['conversation_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      joinedAt: map['joined_at'] != null
          ? DateTime.tryParse(map['joined_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastReadAt: map['last_read_at'] != null
          ? DateTime.tryParse(map['last_read_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fullName: profile?['full_name']?.toString() ?? map['full_name']?.toString(),
      avatarUrl: profile?['avatar_url']?.toString() ?? map['avatar_url']?.toString(),
      role: profile?['role']?.toString() ?? map['role']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'user_id': userId,
      'joined_at': joinedAt.toIso8601String(),
      'last_read_at': lastReadAt.toIso8601String(),
    };
  }
}

class ConversationModel {
  final String id;
  final String? organizationId;
  final String? projectId;
  final ConversationType conversationType;
  final String title;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ConversationMemberModel> members;
  final ChatMessageModel? lastMessage;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    this.organizationId,
    this.projectId,
    this.conversationType = ConversationType.direct,
    required this.title,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.members = const [],
    this.lastMessage,
    this.unreadCount = 0,
  });

  bool get isProjectChat => conversationType == ConversationType.project || (projectId != null && projectId!.isNotEmpty);

  ConversationModel copyWith({
    String? id,
    String? organizationId,
    String? projectId,
    ConversationType? conversationType,
    String? title,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ConversationMemberModel>? members,
    ChatMessageModel? lastMessage,
    int? unreadCount,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      projectId: projectId ?? this.projectId,
      conversationType: conversationType ?? this.conversationType,
      title: title ?? this.title,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  factory ConversationModel.fromMap(
    Map<String, dynamic> map, {
    String? currentUserId,
    List<ConversationMemberModel>? membersList,
    ChatMessageModel? lastMsg,
  }) {
    final typeStr = (map['conversation_type'] ?? map['type'] ?? 'direct').toString().toLowerCase();
    final cType = typeStr == 'group'
        ? ConversationType.group
        : (typeStr == 'project' ? ConversationType.project : ConversationType.direct);

    return ConversationModel(
      id: map['id']?.toString() ?? '',
      organizationId: map['organization_id']?.toString(),
      projectId: map['project_id']?.toString(),
      conversationType: cType,
      title: map['title']?.toString() ?? 'Direct Chat',
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      members: membersList ?? [],
      lastMessage: lastMsg,
      unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'project_id': projectId,
      'conversation_type': conversationType.name,
      'title': title,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String message;
  final String messageType; // 'text', 'image', 'file', 'system'
  final String? attachmentUrl;
  final String? replyToId;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final MessageDeliveryStatus deliveryStatus;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName = 'User',
    this.senderRole = 'user',
    required this.message,
    this.messageType = 'text',
    this.attachmentUrl,
    this.replyToId,
    this.isDeleted = false,
    required this.createdAt,
    this.updatedAt,
    this.deliveryStatus = MessageDeliveryStatus.delivered,
  });

  ChatMessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? message,
    String? messageType,
    String? attachmentUrl,
    String? replyToId,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      message: message ?? this.message,
      messageType: messageType ?? this.messageType,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      replyToId: replyToId ?? this.replyToId,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, {String? defaultName, String? defaultRole}) {
    final rawMsg = map['message'] ?? map['content'] ?? '';
    final profile = map['profiles'] is Map ? map['profiles'] as Map<String, dynamic> : null;

    return ChatMessageModel(
      id: map['id']?.toString() ?? '',
      conversationId: map['conversation_id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      senderName: profile?['full_name']?.toString() ?? map['sender_name']?.toString() ?? defaultName ?? 'User',
      senderRole: profile?['role']?.toString() ?? map['sender_role']?.toString() ?? defaultRole ?? 'user',
      message: rawMsg.toString(),
      messageType: map['message_type']?.toString() ?? 'text',
      attachmentUrl: map['attachment_url']?.toString(),
      replyToId: map['reply_to_id']?.toString(),
      isDeleted: map['is_deleted'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      deliveryStatus: MessageDeliveryStatus.delivered,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message': message,
      'content': message, // Backwards-compatibility
      'message_type': messageType,
      'attachment_url': attachmentUrl,
      'reply_to_id': replyToId,
      'is_deleted': isDeleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String() ?? createdAt.toIso8601String(),
    };
  }
}

class CommunicationSettingsModel {
  final String id;
  final String organizationId;
  final bool enableEmployeeClientMessaging;
  final bool restrictClientToProjects;
  final bool allowEmployeeEmployeeChat;
  final bool showBusinessContactInfo;
  final bool allowFileSharing;
  final bool allowMessageEditing;
  final bool allowMessageDeletion;
  final int maxMessageLength;

  const CommunicationSettingsModel({
    required this.id,
    required this.organizationId,
    this.enableEmployeeClientMessaging = true,
    this.restrictClientToProjects = true,
    this.allowEmployeeEmployeeChat = true,
    this.showBusinessContactInfo = true,
    this.allowFileSharing = true,
    this.allowMessageEditing = true,
    this.allowMessageDeletion = false,
    this.maxMessageLength = 4000,
  });

  factory CommunicationSettingsModel.fromMap(Map<String, dynamic> map) {
    return CommunicationSettingsModel(
      id: map['id']?.toString() ?? '',
      organizationId: map['organization_id']?.toString() ?? '',
      enableEmployeeClientMessaging: map['enable_employee_client_messaging'] != false,
      restrictClientToProjects: map['restrict_client_to_projects'] != false,
      allowEmployeeEmployeeChat: map['allow_employee_employee_chat'] != false,
      showBusinessContactInfo: map['show_business_contact_info'] != false,
      allowFileSharing: map['allow_file_sharing'] != false,
      allowMessageEditing: map['allow_message_editing'] != false,
      allowMessageDeletion: map['allow_message_deletion'] == true,
      maxMessageLength: (map['max_message_length'] as num?)?.toInt() ?? 4000,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organization_id': organizationId,
      'enable_employee_client_messaging': enableEmployeeClientMessaging,
      'restrict_client_to_projects': restrictClientToProjects,
      'allow_employee_employee_chat': allowEmployeeEmployeeChat,
      'show_business_contact_info': showBusinessContactInfo,
      'allow_file_sharing': allowFileSharing,
      'allow_message_editing': allowMessageEditing,
      'allow_message_deletion': allowMessageDeletion,
      'max_message_length': maxMessageLength,
    };
  }
}
