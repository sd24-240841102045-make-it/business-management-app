import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_data_store.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  bool get isInitialized => true;

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  String getUserRole([User? user]) {
    final u = user ?? currentUser;
    if (u == null) return 'admin';
    final metadata = u.userMetadata;
    if (metadata != null && metadata.containsKey('role')) {
      return metadata['role'].toString().toLowerCase();
    }
    return 'admin';
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String role,
    String? company,
    String? phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': name,
        'role': role,
        'company': company ?? '',
        'phone': phone ?? '',
      },
    );

    // Sync user data to Supabase Database tables based on role
    final userId = response.user?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    if (role.toLowerCase() == 'client') {
      final newClient = ClientModel(
        id: userId,
        name: name,
        company: (company != null && company.isNotEmpty) ? company : '$name\'s Enterprise',
        email: email,
        phone: phone ?? '+1 555-0199',
        status: 'Active',
        projectType: 'General Consulting',
        budget: 5000.0,
      );
      await insertClient(newClient);
      AppDataStore().addClient(newClient);
    } else {
      final newEmployee = Employee(
        id: userId,
        name: name,
        role: 'Administrator',
        department: 'Management',
        email: email,
        phone: phone ?? '+1 555-0100',
        status: 'Active',
        joiningDate: DateTime.now().toString().split(' ')[0],
      );
      await insertEmployee(newEmployee);
      AppDataStore().addEmployee(newEmployee);
    }

    return response;
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Supabase signOut error: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ============================================================
  // EMPLOYEES
  // ============================================================

  Future<List<Employee>?> fetchEmployees() async {
    try {
      final response = await _client.from('employees').select();
      final list = (response as List).map((json) => Employee.fromMap(json)).toList();
      return list;
    } catch (e) {
      debugPrint('Supabase fetchEmployees error: $e');
      return null;
    }
  }

  Future<bool> insertEmployee(Employee emp) async {
    try {
      await _client.from('employees').upsert(emp.toMap());
      return true;
    } catch (e) {
      debugPrint('Supabase insertEmployee error: $e');
      return false;
    }
  }

  Future<bool> updateEmployee(Employee emp) async {
    try {
      await _client.from('employees').update(emp.toMap()).eq('id', emp.id);
      return true;
    } catch (e) {
      debugPrint('Supabase updateEmployee error: $e');
      return false;
    }
  }

  Future<bool> deleteEmployee(String id) async {
    try {
      await _client.from('employees').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Supabase deleteEmployee error: $e');
      return false;
    }
  }

  // ============================================================
  // CLIENTS
  // ============================================================

  Future<List<ClientModel>?> fetchClients() async {
    try {
      final response = await _client.from('clients').select();
      final list = (response as List).map((json) => ClientModel.fromMap(json)).toList();
      return list;
    } catch (e) {
      debugPrint('Supabase fetchClients error: $e');
      return null;
    }
  }

  Future<bool> insertClient(ClientModel client) async {
    try {
      await _client.from('clients').upsert(client.toMap());
      return true;
    } catch (e) {
      debugPrint('Supabase insertClient error: $e');
      return false;
    }
  }

  Future<bool> updateClient(ClientModel client) async {
    try {
      await _client.from('clients').update(client.toMap()).eq('id', client.id);
      return true;
    } catch (e) {
      debugPrint('Supabase updateClient error: $e');
      return false;
    }
  }

  Future<bool> deleteClient(String id) async {
    try {
      await _client.from('clients').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Supabase deleteClient error: $e');
      return false;
    }
  }

  // ============================================================
  // LEAVE REQUESTS
  // ============================================================

  Future<List<LeaveRequest>?> fetchLeaveRequests() async {
    try {
      final response = await _client.from('leave_requests').select();
      final list = (response as List).map((json) => LeaveRequest.fromMap(json)).toList();
      return list;
    } catch (e) {
      debugPrint('Supabase fetchLeaveRequests error: $e');
      return null;
    }
  }

  Future<bool> insertLeaveRequest(LeaveRequest request) async {
    try {
      await _client.from('leave_requests').upsert(request.toMap());
      return true;
    } catch (e) {
      debugPrint('Supabase insertLeaveRequest error: $e');
      return false;
    }
  }

  Future<bool> updateLeaveStatus(String requestId, String status) async {
    try {
      await _client
          .from('leave_requests')
          .update({'status': status})
          .eq('id', requestId);
      return true;
    } catch (e) {
      debugPrint('Supabase updateLeaveStatus error: $e');
      return false;
    }
  }
}
