import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saas_models.dart';
import 'app_data_store.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;
  Session? get currentSession => client.auth.currentSession;

  Organization? _currentOrganization;
  OrganizationMembership? _currentMembership;

  Organization? get currentOrganization => _currentOrganization;
  OrganizationMembership? get currentMembership => _currentMembership;
  String get currentRole => _currentMembership?.role ?? 'admin';

  String getUserRole([User? user]) {
    if (_currentMembership != null) return _currentMembership!.role;
    final u = user ?? currentUser;
    if (u?.userMetadata != null && u!.userMetadata!.containsKey('role')) {
      return u.userMetadata!['role'].toString().toLowerCase();
    }
    return 'admin';
  }

  Future<void> resetPassword(String email, {String? redirectTo}) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectTo,
    );
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

    final user = response.user;
    if (user != null) {
      // 1. Try to sign in to establish active session if auto-confirm is off
      if (client.auth.currentSession == null) {
        try {
          await client.auth.signInWithPassword(email: email, password: password);
        } catch (e) {
          debugPrint('Post-signup auto sign-in note: $e');
        }
      }

      // 2. Check if organization was created via DB trigger or insert manually
      try {
        final existingMemberships = await client
            .from('organization_memberships')
            .select('organization_id')
            .eq('user_id', user.id);

        if ((existingMemberships as List).isEmpty) {
          final orgResponse = await client.from('organizations').insert({
            'name': businessName,
            'industry': industry,
            'phone': phone,
            'country': country,
            'subscription_status': 'active',
          }).select().single();

          final orgId = orgResponse['id'];

          await client.from('organization_memberships').insert({
            'organization_id': orgId,
            'user_id': user.id,
            'role': 'admin',
            'status': 'active',
          });
        }
      } catch (e) {
        debugPrint('Manual organization insert note: $e');
      }

      // Fetch active organization context
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

    if (response.user != null) {
      await loadUserOrganizationContext();
    }
    return response;
  }

  /// Accept Employee or Client Invitation via Token
  Future<AuthResponse> acceptInvitation({
    required String token,
    required String password,
    required String fullName,
  }) async {
    // 1. Verify invitation token
    final inviteData = await client
        .from('invitations')
        .select()
        .eq('token', token)
        .eq('status', 'pending')
        .single();

    final String email = inviteData['email'];
    final String orgId = inviteData['organization_id'];
    final String role = inviteData['role'];

    // 2. Create Supabase Auth Account
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    final user = response.user;
    if (user != null) {
      // 3. Create Organization Membership
      await client.from('organization_memberships').insert({
        'organization_id': orgId,
        'user_id': user.id,
        'role': role,
        'status': 'active',
      });

      // 4. If Employee, create Employee profile record
      if (role == 'employee') {
        await client.from('employees').insert({
          'organization_id': orgId,
          'user_id': user.id,
          'designation': 'Team Member',
          'department': 'Operations',
        });
      }

      // 5. Update invitation status
      await client
          .from('invitations')
          .update({'status': 'accepted'})
          .eq('token', token);

      await loadUserOrganizationContext();
    }

    return response;
  }

  /// Load current organization & membership details for logged-in user
  Future<void> loadUserOrganizationContext() async {
    final user = currentUser;
    if (user == null) return;

    try {
      final memberships = await client
          .from('organization_memberships')
          .select('*, organizations(*)')
          .eq('user_id', user.id)
          .eq('status', 'active');

      if ((memberships as List).isNotEmpty) {
        final firstMem = memberships.first;
        _currentMembership = OrganizationMembership.fromMap(firstMem);
        if (firstMem['organizations'] != null) {
          _currentOrganization = Organization.fromMap(firstMem['organizations']);
        }
      }
    } catch (e) {
      debugPrint('Error loading organization context: $e');
    }
  }

  Future<void> signOut() async {
    _currentOrganization = null;
    _currentMembership = null;
    await client.auth.signOut();
  }

  // ============================================================
  // 2. PROJECTS WORKSPACE SERVICES
  // ============================================================

  Future<List<ProjectDomainModel>> fetchProjects() async {
    if (_currentOrganization == null) return [];
    try {
      final response = await client
          .from('projects')
          .select('*, clients(*)')
          .eq('organization_id', _currentOrganization!.id);
      return (response as List).map((json) => ProjectDomainModel.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      return [];
    }
  }

  Future<bool> createProject(ProjectDomainModel project) async {
    if (_currentOrganization == null) return false;
    try {
      await client.from('projects').insert(project.toMap());
      return true;
    } catch (e) {
      debugPrint('Error creating project: $e');
      return false;
    }
  }

  // ============================================================
  // 3. TASKS & CLIENT REQUEST SERVICES
  // ============================================================

  Future<List<TaskDomainModel>> fetchTasks([String? projectId]) async {
    if (_currentOrganization == null) return [];
    try {
      var query = client.from('tasks').select('*, assignee:profiles!tasks_assigned_to_fkey(*)');
      query = query.eq('organization_id', _currentOrganization!.id);
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

  Future<bool> updateTaskStatus(String taskId, String newStatus) async {
    try {
      await client.from('tasks').update({
        'status': newStatus,
        if (newStatus == 'Completed') 'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);
      return true;
    } catch (e) {
      debugPrint('Error updating task status: $e');
      return false;
    }
  }

  Future<bool> createClientRequest(ClientRequestModel request) async {
    if (_currentOrganization == null) return false;
    try {
      await client.from('client_requests').insert(request.toMap());
      return true;
    } catch (e) {
      debugPrint('Error creating client request: $e');
      return false;
    }
  }

  // ============================================================
  // 4. CLIENTS & EMPLOYEES SERVICES (DOMAIN MODELS)
  // ============================================================

  Future<List<ClientDomainModel>> fetchClientsDomain() async {
    if (_currentOrganization == null) return [];
    try {
      final response = await client
          .from('clients')
          .select()
          .eq('organization_id', _currentOrganization!.id);
      return (response as List).map((json) => ClientDomainModel.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Error fetching clients: $e');
      return [];
    }
  }

  Future<bool> createClient(ClientDomainModel clientData) async {
    if (_currentOrganization == null) return false;
    try {
      await client.from('clients').insert(clientData.toMap());
      return true;
    } catch (e) {
      debugPrint('Error creating client: $e');
      return false;
    }
  }

  Future<List<EmployeeDomainModel>> fetchEmployeesDomain() async {
    if (_currentOrganization == null) return [];
    try {
      final response = await client
          .from('employees')
          .select('*, profiles(*)')
          .eq('organization_id', _currentOrganization!.id);
      return (response as List).map((json) => EmployeeDomainModel.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Error fetching employees: $e');
      return [];
    }
  }

  // ============================================================
  // 5. INVOICES & PAYMENTS SERVICES
  // ============================================================

  Future<List<InvoiceDomainModel>> fetchInvoices() async {
    if (_currentOrganization == null) return [];
    try {
      final response = await client
          .from('invoices')
          .select()
          .eq('organization_id', _currentOrganization!.id);
      return (response as List).map((json) => InvoiceDomainModel.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Error fetching invoices: $e');
      return [];
    }
  }

  Future<bool> recordPayment(PaymentRecordModel payment) async {
    if (_currentOrganization == null) return false;
    try {
      await client.from('payments').insert(payment.toMap());
      
      // Update Invoice Status to Paid or Partially Paid
      await client.from('invoices').update({
        'status': 'Paid',
      }).eq('id', payment.invoiceId);
      return true;
    } catch (e) {
      debugPrint('Error recording payment: $e');
      return false;
    }
  }

  // ============================================================
  // 6. LEGACY / APP_DATA_STORE COMPATIBILITY & REALTIME METHODS
  // ============================================================

  RealtimeChannel? _realtimeChannel;

  /// Subscribe to Realtime Postgres changes across all organization tables
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
      if (_currentOrganization != null) {
        query = query.eq('organization_id', _currentOrganization!.id);
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
      if (_currentOrganization == null) return false;
      final userId = currentUser?.id;
      if (userId == null) return false;

      await client.from('employees').upsert({
        'organization_id': _currentOrganization!.id,
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
      if (_currentOrganization != null) {
        query = query.eq('organization_id', _currentOrganization!.id);
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
      if (_currentOrganization == null) return false;
      await client.from('clients').insert({
        'organization_id': _currentOrganization!.id,
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
      if (_currentOrganization != null) {
        query = query.eq('organization_id', _currentOrganization!.id);
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
      if (_currentOrganization == null || currentUser == null) return false;
      await client.from('leave_requests').insert({
        'organization_id': _currentOrganization!.id,
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
        if (_currentOrganization == null) return false;
        final newConv = await client.from('conversations').insert({
          'organization_id': _currentOrganization!.id,
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
}
