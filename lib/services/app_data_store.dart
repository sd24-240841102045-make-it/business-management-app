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

class AppDataStore extends ChangeNotifier {
  static final AppDataStore _instance = AppDataStore._internal();
  factory AppDataStore() => _instance;

  AppDataStore._internal() {
    _initInitialData();
    refreshFromSupabase();
  }

  final List<Employee> _employees = [];
  final List<ClientModel> _clients = [];
  final List<LeaveRequest> _leaveRequests = [];

  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  bool _isLoadingFromSupabase = false;

  List<Employee> get employees => List.unmodifiable(_employees);
  List<ClientModel> get clients => List.unmodifiable(_clients);
  List<LeaveRequest> get leaveRequests => List.unmodifiable(_leaveRequests);
  bool get isCheckedIn => _isCheckedIn;
  DateTime? get checkInTime => _checkInTime;
  bool get isLoadingFromSupabase => _isLoadingFromSupabase;

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

    final remoteEmployees = await SupabaseService().fetchEmployees();
    if (remoteEmployees != null && remoteEmployees.isNotEmpty) {
      _employees.clear();
      _employees.addAll(remoteEmployees);
    }

    final remoteClients = await SupabaseService().fetchClients();
    if (remoteClients != null && remoteClients.isNotEmpty) {
      _clients.clear();
      _clients.addAll(remoteClients);
    }

    final remoteLeaves = await SupabaseService().fetchLeaveRequests();
    if (remoteLeaves != null && remoteLeaves.isNotEmpty) {
      _leaveRequests.clear();
      _leaveRequests.addAll(remoteLeaves);
    }

    _isLoadingFromSupabase = false;
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
