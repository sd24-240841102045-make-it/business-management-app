import 'package:flutter/material.dart';
import 'supabase_service.dart';

class Employee {
  final String id;
  final String name;
  final String role;
  final String department;
  final String email;
  final String phone;
  final String avatarUrl;
  final String status; // 'Active', 'On Leave', 'Inactive'
  final String joiningDate;
  final List<String> assignedClientIds;

  Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.department,
    required this.email,
    required this.phone,
    this.avatarUrl = '',
    required this.status,
    required this.joiningDate,
    this.assignedClientIds = const [],
  });

  Employee copyWith({
    String? id,
    String? name,
    String? role,
    String? department,
    String? email,
    String? phone,
    String? avatarUrl,
    String? status,
    String? joiningDate,
    List<String>? assignedClientIds,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      joiningDate: joiningDate ?? this.joiningDate,
      assignedClientIds: assignedClientIds ?? this.assignedClientIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'department': department,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'status': status,
      'joining_date': joiningDate,
      'assigned_client_ids': assignedClientIds,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      department: map['department'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      avatarUrl: map['avatar_url'] ?? '',
      status: map['status'] ?? 'Active',
      joiningDate: map['joining_date'] ?? '',
      assignedClientIds: (map['assigned_client_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class ClientModel {
  final String id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final String status; // 'Active', 'Prospect', 'Inactive'
  final String? assignedEmployeeId;
  final String? assignedEmployeeName;
  final String projectType;
  final double budget;

  ClientModel({
    required this.id,
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    required this.status,
    this.assignedEmployeeId,
    this.assignedEmployeeName,
    this.projectType = 'General Consulting',
    this.budget = 0.0,
  });

  ClientModel copyWith({
    String? id,
    String? name,
    String? company,
    String? email,
    String? phone,
    String? status,
    String? assignedEmployeeId,
    String? assignedEmployeeName,
    String? projectType,
    double? budget,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
      assignedEmployeeName: assignedEmployeeName ?? this.assignedEmployeeName,
      projectType: projectType ?? this.projectType,
      budget: budget ?? this.budget,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'company': company,
      'email': email,
      'phone': phone,
      'status': status,
      'assigned_employee_id': assignedEmployeeId,
      'assigned_employee_name': assignedEmployeeName,
      'project_type': projectType,
      'budget': budget,
    };
  }

  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      company: map['company'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      status: map['status'] ?? 'Active',
      assignedEmployeeId: map['assigned_employee_id'],
      assignedEmployeeName: map['assigned_employee_name'],
      projectType: map['project_type'] ?? 'General Consulting',
      budget: (map['budget'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LeaveRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String type; // 'Casual', 'Sick', 'Annual', 'Unpaid'
  final String startDate;
  final String endDate;
  final String reason;
  String status; // 'Pending', 'Approved', 'Rejected'

  LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = 'Pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'type': type,
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
      'status': status,
    };
  }

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    return LeaveRequest(
      id: map['id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      employeeName: map['employee_name'] ?? '',
      type: map['type'] ?? 'Casual',
      startDate: map['start_date'] ?? '',
      endDate: map['end_date'] ?? '',
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'Pending',
    );
  }
}

class AdminModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String avatarUrl;

  AdminModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.avatarUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
    };
  }

  factory AdminModel.fromMap(Map<String, dynamic> map) {
    return AdminModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      avatarUrl: map['avatar_url'] ?? '',
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole; // 'admin', 'employee', 'client'
  final String receiverId;
  final String receiverName;
  final String message;
  final String createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.receiverId,
    required this.receiverName,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'receiver_id': receiverId,
      'receiver_name': receiverName,
      'message': message,
      'created_at': createdAt,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      senderId: map['sender_id'] ?? '',
      senderName: map['sender_name'] ?? '',
      senderRole: map['sender_role'] ?? 'client',
      receiverId: map['receiver_id'] ?? '',
      receiverName: map['receiver_name'] ?? '',
      message: map['message'] ?? '',
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class ProjectModel {
  final String id;
  final String name;
  final String clientId;
  final String clientName;
  final String status;
  final double budget;
  final String deadline;
  final List<String> teamMembers;

  ProjectModel({
    required this.id,
    required this.name,
    required this.clientId,
    required this.clientName,
    this.status = 'In Progress',
    required this.budget,
    required this.deadline,
    this.teamMembers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'client_id': clientId,
      'client_name': clientName,
      'status': status,
      'budget': budget,
      'deadline': deadline,
      'team_members': teamMembers,
    };
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      clientId: map['client_id'] ?? '',
      clientName: map['client_name'] ?? '',
      status: map['status'] ?? 'In Progress',
      budget: (map['budget'] as num?)?.toDouble() ?? 0.0,
      deadline: map['deadline'] ?? '',
      teamMembers: (map['team_members'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class TaskModel {
  final String id;
  final String title;
  final String projectId;
  final String projectName;
  final String assignedToName;
  final String status;
  final String priority;
  final String dueDate;

  TaskModel({
    required this.id,
    required this.title,
    this.projectId = '',
    this.projectName = 'General Work',
    required this.assignedToName,
    this.status = 'To Do',
    this.priority = 'Medium',
    required this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'project_id': projectId,
      'project_name': projectName,
      'assigned_to_name': assignedToName,
      'status': status,
      'priority': priority,
      'due_date': dueDate,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      projectId: map['project_id'] ?? '',
      projectName: map['project_name'] ?? 'General Work',
      assignedToName: map['assigned_to_name'] ?? '',
      status: map['status'] ?? 'To Do',
      priority: map['priority'] ?? 'Medium',
      dueDate: map['due_date'] ?? '',
    );
  }
}

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String clientName;
  final double amount;
  final String status;
  final String issueDate;
  final String dueDate;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.clientName,
    required this.amount,
    this.status = 'Pending',
    required this.issueDate,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'client_name': clientName,
      'amount': amount,
      'status': status,
      'issue_date': issueDate,
      'due_date': dueDate,
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'] ?? '',
      invoiceNumber: map['invoice_number'] ?? '',
      clientName: map['client_name'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'Pending',
      issueDate: map['issue_date'] ?? '',
      dueDate: map['due_date'] ?? '',
    );
  }
}

class AppDataStore extends ChangeNotifier {
  static final AppDataStore _instance = AppDataStore._internal();
  factory AppDataStore() => _instance;

  AppDataStore._internal() {
    _initInitialData();
    refreshFromSupabase();
    SupabaseService().subscribeToRealtimeChanges(refreshFromSupabase);
  }

  final List<AdminModel> _admins = [];
  final List<Employee> _employees = [];
  final List<ClientModel> _clients = [];
  final List<ProjectModel> _projects = [];
  final List<TaskModel> _tasks = [];
  final List<InvoiceModel> _invoices = [];
  final List<LeaveRequest> _leaveRequests = [];
  final List<ChatMessage> _chatMessages = [];

  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  bool _isLoadingFromSupabase = false;
  ThemeMode _themeMode = ThemeMode.light;

  List<AdminModel> get admins => List.unmodifiable(_admins);
  List<Employee> get employees => List.unmodifiable(_employees);
  List<ClientModel> get clients => List.unmodifiable(_clients);
  List<ProjectModel> get projects => List.unmodifiable(_projects);
  List<TaskModel> get tasks => List.unmodifiable(_tasks);
  List<InvoiceModel> get invoices => List.unmodifiable(_invoices);
  List<LeaveRequest> get leaveRequests => List.unmodifiable(_leaveRequests);
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  bool get isCheckedIn => _isCheckedIn;
  DateTime? get checkInTime => _checkInTime;
  bool get isLoadingFromSupabase => _isLoadingFromSupabase;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggleDarkMode(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void _initInitialData() {
    _employees.addAll([
      Employee(
        id: 'emp_1',
        name: 'John Doe',
        role: 'HR & Business Lead',
        department: 'Human Resources',
        email: 'john.doe@company.com',
        phone: '+91 98765 00001',
        status: 'Active',
        joiningDate: '15 Jan 2023',
      ),
      Employee(
        id: 'emp_2',
        name: 'Priya Sharma',
        role: 'Senior Account Manager',
        department: 'Client Relations',
        email: 'priya.s@company.com',
        phone: '+91 98765 00002',
        status: 'Active',
        joiningDate: '01 Mar 2022',
      ),
      Employee(
        id: 'emp_3',
        name: 'Rohan Verma',
        role: 'Technical Lead',
        department: 'Engineering',
        email: 'rohan.v@company.com',
        phone: '+91 98765 00003',
        status: 'On Leave',
        joiningDate: '10 Aug 2021',
      ),
      Employee(
        id: 'emp_4',
        name: 'Ananya Roy',
        role: 'UI/UX Designer',
        department: 'Design',
        email: 'ananya.r@company.com',
        phone: '+91 98765 00004',
        status: 'Active',
        joiningDate: '05 Nov 2023',
      ),
    ]);

    _clients.addAll([
      ClientModel(
        id: 'cli_1',
        name: 'Rahul Sharma',
        company: 'Sharma Technologies',
        email: 'rahul@example.com',
        phone: '+91 98765 43210',
        status: 'Active',
        assignedEmployeeId: 'emp_2',
        assignedEmployeeName: 'Priya Sharma',
        projectType: 'Mobile App Development',
        budget: 15000,
      ),
      ClientModel(
        id: 'cli_2',
        name: 'Anjan Patel',
        company: 'Patel Enterprises',
        email: 'anjan@example.com',
        phone: '+91 98765 12345',
        status: 'Active',
        assignedEmployeeId: 'emp_1',
        assignedEmployeeName: 'John Doe',
        projectType: 'ERP Integration',
        budget: 28000,
      ),
      ClientModel(
        id: 'cli_3',
        name: 'Amit Shah',
        company: 'Shah Solutions',
        email: 'amit@example.com',
        phone: '+91 99887 66554',
        status: 'Inactive',
        assignedEmployeeId: 'emp_3',
        assignedEmployeeName: 'Rohan Verma',
        projectType: 'Web Portal Design',
        budget: 9500,
      ),
    ]);

    _leaveRequests.addAll([
      LeaveRequest(
        id: 'lv_1',
        employeeId: 'emp_3',
        employeeName: 'Rohan Verma',
        type: 'Sick',
        startDate: '06 Aug 2026',
        endDate: '08 Aug 2026',
        reason: 'Viral Fever and rest recommended by doctor.',
        status: 'Approved',
      ),
      LeaveRequest(
        id: 'lv_2',
        employeeId: 'emp_4',
        employeeName: 'Ananya Roy',
        type: 'Casual',
        startDate: '12 Aug 2026',
        endDate: '13 Aug 2026',
        reason: 'Personal family event.',
        status: 'Pending',
      ),
    ]);
  }

  /// Sync database from Supabase
  Future<void> refreshFromSupabase() async {
    _isLoadingFromSupabase = true;
    notifyListeners();

    try {
      final remoteEmployees = await SupabaseService().fetchEmployees();
      if (remoteEmployees != null && remoteEmployees.isNotEmpty) {
        _employees.clear();
        _employees.addAll(remoteEmployees);
      } else if (SupabaseService().currentOrganization != null) {
        for (final emp in _employees) {
          await SupabaseService().insertEmployee(emp);
        }
      }

      final remoteClients = await SupabaseService().fetchClients();
      if (remoteClients != null && remoteClients.isNotEmpty) {
        _clients.clear();
        _clients.addAll(remoteClients);
      } else if (SupabaseService().currentOrganization != null) {
        for (final cli in _clients) {
          await SupabaseService().insertClient(cli);
        }
      }

      final remoteLeaves = await SupabaseService().fetchLeaveRequests();
      if (remoteLeaves != null && remoteLeaves.isNotEmpty) {
        _leaveRequests.clear();
        _leaveRequests.addAll(remoteLeaves);
      } else if (SupabaseService().currentOrganization != null) {
        for (final req in _leaveRequests) {
          await SupabaseService().insertLeaveRequest(req);
        }
      }

      final remoteChats = await SupabaseService().fetchChatMessages();
      if (remoteChats != null && remoteChats.isNotEmpty) {
        _chatMessages.clear();
        _chatMessages.addAll(remoteChats);
      }

      final remoteProjects = await SupabaseService().fetchProjects();
      if (remoteProjects.isNotEmpty) {
        _projects.clear();
        for (final p in remoteProjects) {
          _projects.add(ProjectModel(
            id: p.id,
            name: p.name,
            clientId: p.clientId,
            clientName: p.client?.displayName ?? 'Client',
            status: p.status,
            budget: p.budget,
            deadline: p.deadline ?? '',
          ));
        }
      }

      final remoteTasks = await SupabaseService().fetchTasks();
      if (remoteTasks.isNotEmpty) {
        _tasks.clear();
        for (final t in remoteTasks) {
          _tasks.add(TaskModel(
            id: t.id,
            title: t.title,
            projectId: t.projectId,
            projectName: 'Project',
            assignedToName: t.assignee?.fullName ?? 'Unassigned',
            status: t.status,
            priority: t.priority,
            dueDate: t.dueDate ?? '',
          ));
        }
      }

      final remoteInvoices = await SupabaseService().fetchInvoices();
      if (remoteInvoices.isNotEmpty) {
        _invoices.clear();
        for (final inv in remoteInvoices) {
          _invoices.add(InvoiceModel(
            id: inv.id,
            invoiceNumber: inv.invoiceNumber,
            clientName: 'Client',
            amount: inv.total,
            status: inv.status,
            issueDate: inv.issueDate,
            dueDate: inv.dueDate,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error syncing with Supabase: $e');
    } finally {
      _isLoadingFromSupabase = false;
      notifyListeners();
    }
  }

  // --- CHAT MESSAGING ---
  void addChatMessage(ChatMessage msg) {
    _chatMessages.add(msg);
    SupabaseService().sendChatMessage(msg);
    notifyListeners();
  }

  // --- EMPLOYEE MANAGEMENT ---
  void addEmployee(Employee emp) {
    _employees.add(emp);
    SupabaseService().insertEmployee(emp);
    notifyListeners();
  }

  void updateEmployee(Employee updatedEmp) {
    final index = _employees.indexWhere((e) => e.id == updatedEmp.id);
    if (index != -1) {
      _employees[index] = updatedEmp;
      SupabaseService().updateEmployee(updatedEmp);
      notifyListeners();
    }
  }

  void deleteEmployee(String id) {
    _employees.removeWhere((e) => e.id == id);
    SupabaseService().deleteEmployee(id);
    notifyListeners();
  }

  // --- CLIENT MANAGEMENT ---
  void addClient(ClientModel client) {
    _clients.add(client);
    SupabaseService().insertClient(client);
    notifyListeners();
  }

  void updateClient(ClientModel updatedClient) {
    final index = _clients.indexWhere((c) => c.id == updatedClient.id);
    if (index != -1) {
      _clients[index] = updatedClient;
      SupabaseService().updateClient(updatedClient);
      notifyListeners();
    }
  }

  void deleteClient(String id) {
    _clients.removeWhere((c) => c.id == id);
    SupabaseService().deleteClient(id);
    notifyListeners();
  }

  void assignEmployeeToClient(String clientId, String? employeeId) {
    final clientIndex = _clients.indexWhere((c) => c.id == clientId);
    if (clientIndex != -1) {
      String? empName;
      if (employeeId != null && employeeId.isNotEmpty) {
        final emp = _employees.firstWhere(
          (e) => e.id == employeeId,
          orElse: () => Employee(
            id: '',
            name: 'Unassigned',
            role: '',
            department: '',
            email: '',
            phone: '',
            status: '',
            joiningDate: '',
          ),
        );
        empName = emp.name;
      }
      final updated = _clients[clientIndex].copyWith(
        assignedEmployeeId: employeeId,
        assignedEmployeeName: empName,
      );
      _clients[clientIndex] = updated;
      SupabaseService().updateClient(updated);
      notifyListeners();
    }
  }

  // --- LEAVE & ATTENDANCE ---
  void toggleAttendance() {
    _isCheckedIn = !_isCheckedIn;
    _checkInTime = _isCheckedIn ? DateTime.now() : null;
    notifyListeners();
  }

  void addLeaveRequest(LeaveRequest request) {
    _leaveRequests.insert(0, request);
    SupabaseService().insertLeaveRequest(request);
    notifyListeners();
  }

  void updateLeaveStatus(String requestId, String newStatus) {
    final index = _leaveRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _leaveRequests[index].status = newStatus;
      SupabaseService().updateLeaveStatus(requestId, newStatus);

      // Also update employee status if leave is approved
      if (newStatus == 'Approved') {
        final empIndex =
            _employees.indexWhere((e) => e.id == _leaveRequests[index].employeeId);
        if (empIndex != -1) {
          final updatedEmp = _employees[empIndex].copyWith(status: 'On Leave');
          _employees[empIndex] = updatedEmp;
          SupabaseService().updateEmployee(updatedEmp);
        }
      }
      notifyListeners();
    }
  }
}
