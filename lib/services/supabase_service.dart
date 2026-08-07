import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saas_models.dart';
import 'app_data_store.dart';

class SupabaseService {
  SupabaseService._internal();

  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() => _instance;

  SupabaseClient get client => Supabase.instance.client;

  // ============================================================
  // CURRENT USER & SESSION
  // ============================================================

  User? get currentUser => client.auth.currentUser;
  Session? get currentSession => client.auth.currentSession;

  // ============================================================
  // CURRENT ORGANIZATION & MEMBERSHIP CONTEXT
  // ============================================================

  Map<String, dynamic>? _currentOrganization;
  Map<String, dynamic>? _currentMembership;

  Map<String, dynamic>? get currentOrganization => _currentOrganization;
  Map<String, dynamic>? get currentMembership => _currentMembership;

  String get currentRole => _currentMembership?['role']?.toString() ?? 'admin';
  String? get currentOrganizationId => _currentMembership?['organization_id']?.toString();

  String getUserRole([User? user]) {
    if (_currentMembership != null && _currentMembership!['role'] != null) {
      return _currentMembership!['role'].toString().toLowerCase();
    }
    final u = user ?? currentUser;
    if (u?.userMetadata != null && u!.userMetadata!.containsKey('role')) {
      return u.userMetadata!['role'].toString().toLowerCase();
    }
    return 'admin';
  }

  // ============================================================
  // 1. AUTHENTICATION & MULTI-TENANT ONBOARDING
  // ============================================================

  /// Sign up a new Business Admin and create Organization tenant
  Future<AuthResponse> signUpBusinessAdmin({
    required String email,
    required String password,
    required String fullName,
    required String businessName,
    required String industry,
    required String phone,
    required String country,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'business_name': businessName,
        'industry': industry,
        'phone': phone,
        'country': country,
        'role': 'admin',
      },
    );

    if (response.user == null) {
      throw Exception('Business account could not be created.');
    }

    if (response.session != null) {
      await loadUserOrganizationContext();
    }

    return response;
  }

  /// Sign in existing user & populate multi-tenant context
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Login failed.');
    }

    await loadUserOrganizationContext();
    return response;
  }

  /// Accept Employee or Client Invitation via Token
  Future<AuthResponse> acceptInvitation({
    required String token,
    String? email,
    required String password,
    required String fullName,
  }) async {
    final cleanToken = token.trim();
    final cleanName = fullName.trim();
    final targetEmail = email?.trim().toLowerCase();

    if (cleanToken.isEmpty) {
      throw Exception('Please enter your invitation code.');
    }
    if (targetEmail == null || targetEmail.isEmpty) {
      throw Exception('Email is required.');
    }

    // 1. Create Supabase Auth Account (The trigger creates a basic profile)
    final response = await client.auth.signUp(
      email: targetEmail,
      password: password,
      data: {
        'full_name': cleanName,
      },
    );

    if (response.user == null) {
      throw Exception('Could not create account for invitation.');
    }

    // 2. Call the secure RPC to accept the invitation
    await client.rpc('accept_invitation', params: {
      'invite_code': cleanToken,
    });

    // 3. Load the new multi-tenant context
    if (response.session != null) {
      await loadUserOrganizationContext();
    }

    return response;
  }

  /// Load current organization & membership details for logged-in user
  Future<void> loadUserOrganizationContext() async {
    final user = currentUser;
    if (user == null) {
      _currentOrganization = null;
      _currentMembership = null;
      return;
    }

    try {
      final result = await client
          .from('organization_members')
          .select('*, organizations(*)')
          .eq('profile_id', user.id);

      final List<dynamic> memberships = result as List<dynamic>;

      if (memberships.isNotEmpty) {
        final firstMem = Map<String, dynamic>.from(memberships.first);
        _currentMembership = firstMem;
        if (firstMem['organizations'] != null) {
          _currentOrganization = Map<String, dynamic>.from(firstMem['organizations']);
        }
      } else {
        _currentMembership = null;
        _currentOrganization = null;
      }
    } catch (e) {
      debugPrint('Error loading organization context: $e');
      _currentMembership = null;
      _currentOrganization = null;
    }
  }

  Future<void> resetPassword(String email, {String? redirectTo}) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectTo,
    );
  }

  Future<void> signOut() async {
    _currentOrganization = null;
    _currentMembership = null;
    await client.auth.signOut();
  }

  // ============================================================
  // 2. REALTIME & REPOSITORY COMPATIBILITY METHODS
  // ============================================================

  RealtimeChannel? _realtimeChannel;

  void subscribeToRealtimeChanges(VoidCallback onDataChanged) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = client
        .channel('public:org_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          callback: (payload) {
            debugPrint('Supabase Realtime event received: ${payload.eventType}');
            onDataChanged();
          },
        )
        .subscribe();
  }

  Future<List<Employee>?> fetchEmployees() async {
    try {
      var query = client.from('employees').select('*, profiles(*)');
      if (currentOrganizationId != null) {
        query = query.eq('organization_id', currentOrganizationId!);
      }
      final response = await query;
      final list = (response as List).map((json) {
        final profile = json['profiles'] as Map<String, dynamic>?;
        return Employee(
          id: json['id']?.toString() ?? '',
          name: profile?['full_name']?.toString() ?? 'Team Member',
          role: json['designation']?.toString() ?? 'Staff',
          department: json['department']?.toString() ?? 'General',
          email: profile?['email']?.toString() ?? '',
          phone: profile?['phone']?.toString() ?? '',
          avatarUrl: profile?['avatar_url']?.toString() ?? '',
          status: json['status']?.toString() ?? 'Active',
          joiningDate: json['joining_date']?.toString() ?? '',
        );
      }).toList();
      return list;
    } catch (e) {
      debugPrint('Supabase fetchEmployees error: $e');
      return null;
    }
  }

  Future<bool> insertEmployee(Employee emp) async {
    try {
      if (currentOrganizationId == null) return false;
      final userId = currentUser?.id;
      if (userId == null) return false;

      await client.from('employees').upsert({
        'organization_id': currentOrganizationId,
        'user_id': userId,
        'designation': emp.role.isEmpty ? 'Staff' : emp.role,
        'department': emp.department.isEmpty ? 'General' : emp.department,
        'status': emp.status.isEmpty ? 'Active' : emp.status,
      });
      return true;
    } catch (e) {
      debugPrint('Supabase insertEmployee error: $e');
      return false;
    }
  }

  Future<bool> updateEmployee(Employee emp) async {
    try {
      await client.from('employees').update({
        'designation': emp.role,
        'department': emp.department,
        'status': emp.status,
      }).eq('id', emp.id);
      return true;
    } catch (e) {
      debugPrint('Supabase updateEmployee error: $e');
      return false;
    }
  }

  Future<bool> deleteEmployee(String id) async {
    try {
      await client.from('employees').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Supabase deleteEmployee error: $e');
      return false;
    }
  }

  Future<List<ClientModel>?> fetchClients() async {
    try {
      var query = client.from('clients').select();
      if (currentOrganizationId != null) {
        query = query.eq('organization_id', currentOrganizationId!);
      }
      final response = await query;
      final list = (response as List).map((json) {
        return ClientModel(
          id: json['id']?.toString() ?? '',
          name: json['contact_name']?.toString() ?? json['name']?.toString() ?? '',
          company: json['company_name']?.toString() ?? json['company']?.toString() ?? '',
          email: json['email']?.toString() ?? '',
          phone: json['phone']?.toString() ?? '',
          status: 'Active',
          projectType: 'General Consulting',
          budget: 0.0,
        );
      }).toList();
      return list;
    } catch (e) {
      debugPrint('Supabase fetchClients error: $e');
      return null;
    }
  }

  Future<bool> insertClient(ClientModel clientData) async {
    try {
      if (currentOrganizationId == null) return false;
      await client.from('clients').insert({
        'organization_id': currentOrganizationId,
        'client_type': clientData.company.isNotEmpty ? 'business' : 'individual',
        'company_name': clientData.company,
        'contact_name': clientData.name.isEmpty ? clientData.company : clientData.name,
        'email': clientData.email,
        'phone': clientData.phone,
      });
      return true;
    } catch (e) {
      debugPrint('Supabase insertClient error: $e');
      return false;
    }
  }

  Future<bool> updateClient(ClientModel clientData) async {
    try {
      await client.from('clients').update({
        'company_name': clientData.company,
        'contact_name': clientData.name,
        'email': clientData.email,
        'phone': clientData.phone,
      }).eq('id', clientData.id);
      return true;
    } catch (e) {
      debugPrint('Supabase updateClient error: $e');
      return false;
    }
  }

  Future<bool> deleteClient(String id) async {
    try {
      await client.from('clients').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Supabase deleteClient error: $e');
      return false;
    }
  }

  Future<List<LeaveRequest>?> fetchLeaveRequests() async {
    try {
      var query = client.from('leave_requests').select('*, profiles(*)');
      if (currentOrganizationId != null) {
        query = query.eq('organization_id', currentOrganizationId!);
      }
      final response = await query;
      final list = (response as List).map((json) {
        final profile = json['profiles'] as Map<String, dynamic>?;
        return LeaveRequest(
          id: json['id']?.toString() ?? '',
          employeeId: json['user_id']?.toString() ?? '',
          employeeName: profile?['full_name']?.toString() ?? 'Staff',
          type: json['leave_type']?.toString() ?? 'Casual',
          startDate: json['start_date']?.toString() ?? '',
          endDate: json['end_date']?.toString() ?? '',
          reason: json['reason']?.toString() ?? '',
          status: json['status']?.toString() ?? 'Pending',
        );
      }).toList();
      return list;
    } catch (e) {
      debugPrint('Supabase fetchLeaveRequests error: $e');
      return null;
    }
  }

  Future<bool> insertLeaveRequest(LeaveRequest request) async {
    try {
      if (currentOrganizationId == null || currentUser == null) return false;
      await client.from('leave_requests').insert({
        'organization_id': currentOrganizationId,
        'user_id': currentUser!.id,
        'leave_type': request.type.isEmpty ? 'Casual' : request.type,
        'start_date': request.startDate.isEmpty ? DateTime.now().toIso8601String().split('T')[0] : request.startDate,
        'end_date': request.endDate.isEmpty ? DateTime.now().toIso8601String().split('T')[0] : request.endDate,
        'reason': request.reason,
        'status': request.status,
      });
      return true;
    } catch (e) {
      debugPrint('Supabase insertLeaveRequest error: $e');
      return false;
    }
  }

  Future<bool> updateLeaveStatus(String requestId, String status) async {
    try {
      await client.from('leave_requests').update({'status': status}).eq('id', requestId);
      return true;
    } catch (e) {
      debugPrint('Supabase updateLeaveStatus error: $e');
      return false;
    }
  }

  Future<List<ChatMessage>?> fetchChatMessages() async {
    try {
      var query = client.from('messages').select('*, sender:profiles(*)').order('created_at', ascending: true);
      final response = await query;
      final list = (response as List).map((json) {
        final senderProfile = json['sender'] as Map<String, dynamic>?;
        return ChatMessage(
          id: json['id']?.toString() ?? '',
          senderId: json['sender_id']?.toString() ?? '',
          senderName: senderProfile?['full_name']?.toString() ?? 'User',
          senderRole: 'admin',
          receiverId: '',
          receiverName: 'General',
          message: json['content']?.toString() ?? '',
          createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        );
      }).toList();
      return list;
    } catch (e) {
      debugPrint('Supabase fetchChatMessages error: $e');
      return null;
    }
  }

  Future<bool> sendChatMessage(ChatMessage message) async {
    try {
      if (currentUser == null) return false;
      final convs = await client.from('conversations').select('id').limit(1);
      String convId;
      if ((convs as List).isNotEmpty) {
        convId = convs.first['id'];
      } else {
        if (currentOrganizationId == null) return false;
        final newConv = await client.from('conversations').insert({
          'organization_id': currentOrganizationId,
          'type': 'direct',
          'title': 'General Chat',
        }).select().single();
        convId = newConv['id'];
      }

      await client.from('messages').insert({
        'conversation_id': convId,
        'sender_id': currentUser!.id,
        'content': message.message,
      });
      return true;
    } catch (e) {
      debugPrint('Supabase sendChatMessage error: $e');
      return false;
    }
  }

  Future<List<ProjectDomainModel>> fetchProjects() async {
    if (currentOrganizationId == null) return [];
    try {
      final response = await client
          .from('projects')
          .select('*, clients(*)')
          .eq('organization_id', currentOrganizationId!);
      return (response as List).map((json) => ProjectDomainModel.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      return [];
    }
  }

  Future<List<TaskDomainModel>> fetchTasks([String? projectId]) async {
    if (currentOrganizationId == null) return [];
    try {
      var query = client.from('tasks').select('*, assignee:profiles!tasks_assigned_to_fkey(*)');
      query = query.eq('organization_id', currentOrganizationId!);
      if (projectId != null && projectId.isNotEmpty) {
        query = query.eq('project_id', projectId);
      }
      final response = await query;
      return (response as List).map((json) => TaskDomainModel.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Error fetching tasks: $e');
      return [];
    }
  }

  Future<List<InvoiceDomainModel>> fetchInvoices() async {
    if (currentOrganizationId == null) return [];
    try {
      final response = await client
          .from('invoices')
          .select()
          .eq('organization_id', currentOrganizationId!);
      return (response as List).map((json) => InvoiceDomainModel.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Error fetching invoices: $e');
      return [];
    }
  }
}
