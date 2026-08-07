import 'package:flutter/foundation.dart';

// ============================================================
// 1. ORGANIZATIONS & SUBSCRIPTIONS
// ============================================================

class SubscriptionPlan {
  final String id;
  final String name;
  final int maxEmployees;
  final int maxClients;
  final int maxProjects;
  final double maxStorageGb;
  final double priceMonthly;
  final Map<String, dynamic> features;

  SubscriptionPlan({
    required this.id,
    required this.name,
    this.maxEmployees = 5,
    this.maxClients = 10,
    this.maxProjects = 5,
    this.maxStorageGb = 5.0,
    this.priceMonthly = 0.0,
    this.features = const {},
  });

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlan(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Starter',
      maxEmployees: map['max_employees'] ?? 5,
      maxClients: map['max_clients'] ?? 10,
      maxProjects: map['max_projects'] ?? 5,
      maxStorageGb: (map['max_storage_gb'] as num?)?.toDouble() ?? 5.0,
      priceMonthly: (map['price_monthly'] as num?)?.toDouble() ?? 0.0,
      features: Map<String, dynamic>.from(map['features'] ?? {}),
    );
  }
}

class Organization {
  final String id;
  final String name;
  final String? slug;
  final String? industry;
  final String? phone;
  final String? country;
  final String? logoUrl;
  final String? planId;
  final String subscriptionStatus; // 'active', 'past_due', 'canceled'
  final DateTime createdAt;

  Organization({
    required this.id,
    required this.name,
    this.slug,
    this.industry,
    this.phone,
    this.country,
    this.logoUrl,
    this.planId,
    this.subscriptionStatus = 'active',
    required this.createdAt,
  });

  factory Organization.fromMap(Map<String, dynamic> map) {
    return Organization(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      slug: map['slug'],
      industry: map['industry'],
      phone: map['phone'],
      country: map['country'],
      logoUrl: map['logo_url'],
      planId: map['plan_id'],
      subscriptionStatus: map['subscription_status'] ?? 'active',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'industry': industry,
      'phone': phone,
      'country': country,
      'logo_url': logoUrl,
      'plan_id': planId,
      'subscription_status': subscriptionStatus,
    };
  }
}

// ============================================================
// 2. PROFILES & MEMBERSHIPS
// ============================================================

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String? fcmToken;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    this.fcmToken,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      fullName: map['full_name'] ?? '',
      phone: map['phone'],
      avatarUrl: map['avatar_url'],
      fcmToken: map['fcm_token'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'fcm_token': fcmToken,
    };
  }
}

class OrganizationMembership {
  final String id;
  final String organizationId;
  final String userId;
  final String role; // 'admin', 'employee', 'client'
  final String status; // 'active', 'invited', 'suspended'

  OrganizationMembership({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.role,
    this.status = 'active',
  });

  factory OrganizationMembership.fromMap(Map<String, dynamic> map) {
    return OrganizationMembership(
      id: map['id'] ?? '',
      organizationId: map['organization_id'] ?? '',
      userId: map['user_id'] ?? '',
      role: map['role'] ?? 'employee',
      status: map['status'] ?? 'active',
    );
  }
}

// ============================================================
// 3. CLIENT & EMPLOYEE DOMAIN MODELS
// ============================================================

class ClientDomainModel {
  final String id;
  final String organizationId;
  final String? userId;
  final String clientType; // 'individual' or 'business'
  final String? companyName;
  final String contactName;
  final String email;
  final String? phone;
  final String? address;

  ClientDomainModel({
    required this.id,
    required this.organizationId,
    this.userId,
    required this.clientType,
    this.companyName,
    required this.contactName,
    required this.email,
    this.phone,
    this.address,
  });

  bool get isBusiness => clientType == 'business';

  String get displayName => isBusiness && companyName != null && companyName!.isNotEmpty
      ? '$companyName ($contactName)'
      : contactName;

  factory ClientDomainModel.fromMap(Map<String, dynamic> map) {
    return ClientDomainModel(
      id: map['id'] ?? '',
      organizationId: map['organization_id'] ?? '',
      userId: map['user_id'],
      clientType: map['client_type'] ?? 'individual',
      companyName: map['company_name'],
      contactName: map['contact_name'] ?? map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      address: map['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'user_id': userId,
      'client_type': clientType,
      'company_name': companyName,
      'contact_name': contactName,
      'email': email,
      'phone': phone,
      'address': address,
    };
  }
}

class EmployeeDomainModel {
  final String id;
  final String organizationId;
  final String userId;
  final String designation;
  final String department;
  final String joiningDate;
  final String status; // 'Active', 'On Leave', 'Terminated'
  final double hourlyRate;
  final UserProfile? profile;

  EmployeeDomainModel({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.designation,
    required this.department,
    required this.joiningDate,
    this.status = 'Active',
    this.hourlyRate = 0.0,
    this.profile,
  });

  factory EmployeeDomainModel.fromMap(Map<String, dynamic> map) {
    return EmployeeDomainModel(
      id: map['id'] ?? '',
      organizationId: map['organization_id'] ?? '',
      userId: map['user_id'] ?? '',
      designation: map['designation'] ?? '',
      department: map['department'] ?? '',
      joiningDate: map['joining_date'] ?? DateTime.now().toString().split(' ')[0],
      status: map['status'] ?? 'Active',
      hourlyRate: (map['hourly_rate'] as num?)?.toDouble() ?? 0.0,
      profile: map['profiles'] != null ? UserProfile.fromMap(map['profiles']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'user_id': userId,
      'designation': designation,
      'department': department,
      'joining_date': joiningDate,
      'status': status,
      'hourly_rate': hourlyRate,
    };
  }
}

// ============================================================
// 4. PROJECTS & TASKS DOMAIN MODELS
// ============================================================

class ProjectDomainModel {
  final String id;
  final String organizationId;
  final String clientId;
  final String? managerId;
  final String name;
  final String? description;
  final String status; // 'In Progress', 'Completed', 'On Hold', 'Cancelled'
  final String health; // 'On Track', 'At Risk', 'Delayed'
  final double budget;
  final String? startDate;
  final String? deadline;
  final ClientDomainModel? client;

  ProjectDomainModel({
    required this.id,
    required this.organizationId,
    required this.clientId,
    this.managerId,
    required this.name,
    this.description,
    this.status = 'In Progress',
    this.health = 'On Track',
    this.budget = 0.0,
    this.startDate,
    this.deadline,
    this.client,
  });

  factory ProjectDomainModel.fromMap(Map<String, dynamic> map) {
    return ProjectDomainModel(
      id: map['id'] ?? '',
      organizationId: map['organization_id'] ?? '',
      clientId: map['client_id'] ?? '',
      managerId: map['manager_id'],
      name: map['name'] ?? '',
      description: map['description'],
      status: map['status'] ?? 'In Progress',
      health: map['health'] ?? 'On Track',
      budget: (map['budget'] as num?)?.toDouble() ?? 0.0,
      startDate: map['start_date'],
      deadline: map['deadline'],
      client: map['clients'] != null ? ClientDomainModel.fromMap(map['clients']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'client_id': clientId,
      'manager_id': managerId,
      'name': name,
      'description': description,
      'status': status,
      'health': health,
      'budget': budget,
      'start_date': startDate,
      'deadline': deadline,
    };
  }
}

class TaskDomainModel {
  final String id;
  final String organizationId;
  final String projectId;
  final String title;
  final String? description;
  final String? assignedTo;
  final String? createdBy;
  final String status; // 'Todo', 'In Progress', 'Review', 'Completed', 'Blocked'
  final String priority; // 'Low', 'Medium', 'High', 'Urgent'
  final String? dueDate;
  final int timeSpentMinutes;
  final UserProfile? assignee;

  TaskDomainModel({
    required this.id,
    required this.organizationId,
    required this.projectId,
    required this.title,
    this.description,
    this.assignedTo,
    this.createdBy,
    this.status = 'Todo',
    this.priority = 'Medium',
    this.dueDate,
    this.timeSpentMinutes = 0,
    this.assignee,
  });

  factory TaskDomainModel.fromMap(Map<String, dynamic> map) {
    return TaskDomainModel(
      id: map['id'] ?? '',
      organizationId: map['organization_id'] ?? '',
      projectId: map['project_id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      assignedTo: map['assigned_to'],
      createdBy: map['created_by'],
      status: map['status'] ?? 'Todo',
      priority: map['priority'] ?? 'Medium',
      dueDate: map['due_date'],
      timeSpentMinutes: map['time_spent_minutes'] ?? 0,
      assignee: map['assignee'] != null ? UserProfile.fromMap(map['assignee']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'project_id': projectId,
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'created_by': createdBy,
      'status': status,
      'priority': priority,
      'due_date': dueDate,
      'time_spent_minutes': timeSpentMinutes,
    };
  }
}

// ============================================================
// 5. CLIENT REQUESTS & APPROVALS
// ============================================================

class ClientRequestModel {
  final String id;
  final String organizationId;
  final String projectId;
  final String clientId;
  final String title;
  final String description;
  final String priority;
  final String status; // 'Pending', 'Converted to Task', 'Rejected', 'Resolved'
  final String? convertedTaskId;
  final DateTime createdAt;

  ClientRequestModel({
    required this.id,
    required this.organizationId,
    required this.projectId,
    required this.clientId,
    required this.title,
    required this.description,
    this.priority = 'Medium',
    this.status = 'Pending',
    this.convertedTaskId,
    required this.createdAt,
  });

  factory ClientRequestModel.fromMap(Map<String, dynamic> map) {
    return ClientRequestModel(
      id: map['id'] ?? '',
      organizationId: map['organization_id'] ?? '',
      projectId: map['project_id'] ?? '',
      clientId: map['client_id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      priority: map['priority'] ?? 'Medium',
      status: map['status'] ?? 'Pending',
      convertedTaskId: map['converted_task_id'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'project_id': projectId,
      'client_id': clientId,
      'title': title,
      'description': description,
      'priority': priority,
      'status': status,
      'converted_task_id': convertedTaskId,
    };
  }
}

class DeliverableApprovalModel {
  final String id;
  final String organizationId;
  final String projectId;
  final String? taskId;
  final String title;
  final String? description;
  final String? deliverableUrl;
  final String requestedBy;
  final String? approverId;
  final String status; // 'Pending', 'Approved', 'Changes Requested'
  final String? feedback;

  DeliverableApprovalModel({
    required this.id,
    required this.organizationId,
    required this.projectId,
    this.taskId,
    required this.title,
    this.description,
    this.deliverableUrl,
    required this.requestedBy,
    this.approverId,
    this.status = 'Pending',
    this.feedback,
  });

  factory DeliverableApprovalModel.fromMap(Map<String, dynamic> map) {
    return DeliverableApprovalModel(
      id: map['id'] ?? '',
      organizationId: map['organization_id'] ?? '',
      projectId: map['project_id'] ?? '',
      taskId: map['task_id'],
      title: map['title'] ?? '',
      description: map['description'],
      deliverableUrl: map['deliverable_url'],
      requestedBy: map['requested_by'] ?? '',
      approverId: map['approver_id'],
      status: map['status'] ?? 'Pending',
      feedback: map['feedback'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'project_id': projectId,
      'task_id': taskId,
      'title': title,
      'description': description,
      'deliverable_url': deliverableUrl,
      'requested_by': requestedBy,
      'approver_id': approverId,
      'status': status,
      'feedback': feedback,
    };
  }
}

// ============================================================
// 6. INVOICES & PAYMENTS DOMAIN MODELS
// ============================================================

class InvoiceDomainModel {
  final String id;
  final String organizationId;
  final String clientId;
  final String? projectId;
  final String invoiceNumber;
  final String issueDate;
  final String dueDate;
  final double subtotal;
  final double tax;
  final double total;
  final String status; // 'Draft', 'Pending', 'Partially Paid', 'Paid', 'Overdue'
  final String? notes;

  InvoiceDomainModel({
    required this.id,
    required this.organizationId,
    required this.clientId,
    this.projectId,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    this.subtotal = 0.0,
    this.tax = 0.0,
    required this.total,
    this.status = 'Pending',
    this.notes,
  });

  factory InvoiceDomainModel.fromMap(Map<String, dynamic> map) {
    return InvoiceDomainModel(
      id: map['id'] ?? '',
      organizationId: map['organization_id'] ?? '',
      clientId: map['client_id'] ?? '',
      projectId: map['project_id'],
      invoiceNumber: map['invoice_number'] ?? '',
      issueDate: map['issue_date'] ?? '',
      dueDate: map['due_date'] ?? '',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'Pending',
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'client_id': clientId,
      'project_id': projectId,
      'invoice_number': invoiceNumber,
      'issue_date': issueDate,
      'due_date': dueDate,
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'status': status,
      'notes': notes,
    };
  }
}

class PaymentRecordModel {
  final String id;
  final String organizationId;
  final String invoiceId;
  final double amount;
  final String paymentMethod; // 'UPI', 'Bank Transfer', 'Cash', 'Cheque', 'Card'
  final String? paymentProofUrl;
  final String? referenceNumber;
  final String status; // 'Pending Verification', 'Confirmed', 'Rejected'
  final DateTime recordedAt;

  PaymentRecordModel({
    required this.id,
    required this.organizationId,
    required this.invoiceId,
    required this.amount,
    required this.paymentMethod,
    this.paymentProofUrl,
    this.referenceNumber,
    this.status = 'Confirmed',
    required this.recordedAt,
  });

  factory PaymentRecordModel.fromMap(Map<String, dynamic> map) {
    return PaymentRecordModel(
      id: map['id'] ?? '',
      organizationId: map['organization_id'] ?? '',
      invoiceId: map['invoice_id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_method'] ?? 'UPI',
      paymentProofUrl: map['payment_proof_url'],
      referenceNumber: map['reference_number'],
      status: map['status'] ?? 'Confirmed',
      recordedAt: map['recorded_at'] != null ? DateTime.parse(map['recorded_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'invoice_id': invoiceId,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_proof_url': paymentProofUrl,
      'reference_number': referenceNumber,
      'status': status,
    };
  }
}
