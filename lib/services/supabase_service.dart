import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saas_models.dart';
import 'encryption_service.dart';
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
  bool _isAuthActionInProgress = false;

  bool get isAuthActionInProgress => _isAuthActionInProgress;

  Map<String, dynamic>? get currentOrganization => _currentOrganization;
  Map<String, dynamic>? get currentMembership => _currentMembership;

  String get currentRole {
    if (_currentMembership != null && _currentMembership!['role'] != null) {
      return _currentMembership!['role'].toString().toLowerCase();
    }
    return getUserRole();
  }
  
  String? get currentOrganizationId => _currentMembership?['organization_id']?.toString();

  String getUserRole([User? user]) {
    if (_currentMembership != null && _currentMembership!['role'] != null) {
      return _currentMembership!['role'].toString().toLowerCase();
    }
    final u = user ?? currentUser;
    if (u?.userMetadata != null && u!.userMetadata!.containsKey('role')) {
      return u.userMetadata!['role'].toString().toLowerCase();
    }
    return 'employee'; // Safest fallback
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
    _isAuthActionInProgress = true;
    try {
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
    } finally {
      _isAuthActionInProgress = false;
    }
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw Exception('Email and password cannot be empty.');
    }

    final response = await client.auth.signInWithPassword(
      email: cleanEmail,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Login failed.');
    }

    await loadUserOrganizationContext();

    // Enforcement: Reject if no valid membership is found
    if (_currentMembership == null || _currentMembership!['status'] != 'active') {
       await client.auth.signOut();
       throw Exception('Your account has no active organization membership.');
    }

    return response;
  }

  /// Accept Employee or Client Invitation via Token
  Future<AuthResponse> acceptInvitation({
    required String token,
    String? email,
    required String password,
    required String fullName,
  }) async {
    _isAuthActionInProgress = true;
    try {
      final cleanToken = token.trim();
      final cleanName = fullName.trim();
      final targetEmail = email?.trim().toLowerCase();

      if (cleanToken.isEmpty) {
        throw Exception('Please enter your invitation code.');
      }
      if (targetEmail == null || targetEmail.isEmpty) {
        throw Exception('Email is required.');
      }

      // 1. Verify the code FIRST before creating any account
      final bool isValid = await client.rpc('verify_invite_code', params: {
        'invite_code_param': cleanToken,
      });

      if (!isValid) {
        throw Exception('Invalid or expired invitation code.');
      }

      // 2. Create Supabase Auth Account (The trigger creates a basic profile)
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

      // 3. Redeem the code to join the organization
      try {
        await client.rpc('redeem_invite_code', params: {
          'invite_code_param': cleanToken,
        });
      } catch (e) {
        // If redemption fails, the account was created but has no org membership.
        // Clean up the session locally so they aren't incorrectly routed.
        await client.auth.signOut();
        rethrow;
      }

      // 4. Load the new multi-tenant context
      if (response.session != null) {
        await loadUserOrganizationContext();
      }

      return response;
    } finally {
      _isAuthActionInProgress = false;
    }
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
      int attempts = 0;
      List<dynamic> memberships = [];
      
      while (attempts < 5) {
        try {
          // Use RPC to bypass RLS for membership lookup.
          // This avoids the circular dependency where the SELECT RLS policy
          // on organization_memberships uses current_user_org_ids() which
          // itself queries organization_memberships.
          final result = await client.rpc('get_my_memberships');
          memberships = result as List<dynamic>;
        } catch (rpcError) {
          // Fallback: direct table query (works if RPC doesn't exist)
          debugPrint('RPC get_my_memberships failed, falling back to direct query: $rpcError');
          try {
            final result = await client
                .from('organization_memberships')
                .select('*, organizations(*)')
                .eq('user_id', user.id);
            memberships = result as List<dynamic>;
          } catch (directError) {
            debugPrint('Direct membership query also failed: $directError');
          }
        }
        
        if (memberships.isNotEmpty) {
          break; // Found it!
        }
        
        attempts++;
        if (attempts < 5) {
          // Wait 1 second to allow PostgreSQL triggers to commit
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }

      if (memberships.isNotEmpty) {
        final firstMem = Map<String, dynamic>.from(memberships.first);
        _currentMembership = firstMem;
        if (firstMem['organizations'] != null) {
          _currentOrganization = Map<String, dynamic>.from(firstMem['organizations']);
        } else if (firstMem['organization_id'] != null) {
          // RPC may not join organizations — fetch separately
          try {
            final orgResult = await client
                .from('organizations')
                .select()
                .eq('id', firstMem['organization_id'])
                .maybeSingle();
            if (orgResult != null) {
              _currentOrganization = Map<String, dynamic>.from(orgResult);
            }
          } catch (e) {
            debugPrint('Error fetching organization details: $e');
          }
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

  Future<String?> getOrCreateDirectConversation(String otherUserId) async {
    try {
      if (currentUser == null || currentOrganizationId == null) return null;
      final myId = currentUser!.id;
      
      final res = await client
          .from('conversations')
          .select('id, conversation_members!inner(user_id)')
          .eq('organization_id', currentOrganizationId!)
          .eq('type', 'direct');
      
      for (final conv in (res as List)) {
        final members = (conv['conversation_members'] as List).map((m) => m['user_id'] as String).toList();
        if (members.length == 2 && members.contains(myId) && members.contains(otherUserId)) {
          return conv['id'] as String;
        }
      }
      
      final newConv = await client.from('conversations').insert({
        'organization_id': currentOrganizationId,
        'type': 'direct',
        'title': 'Direct Chat',
      }).select().single();
      
      final convId = newConv['id'] as String;
      
      await client.from('conversation_members').insert([
        {'conversation_id': convId, 'user_id': myId},
        {'conversation_id': convId, 'user_id': otherUserId},
      ]);
      
      return convId;
    } catch (e) {
      debugPrint('Supabase getOrCreateDirectConversation error: $e');
      return null;
    }
  }

  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((list) {
          return list.map((json) {
            final decryptedMessage = EncryptionService.decrypt(json['content']?.toString() ?? '');
            return ChatMessage(
              id: json['id']?.toString() ?? '',
              senderId: json['sender_id']?.toString() ?? '',
              senderName: 'User', // Re-mapped on UI
              senderRole: 'client', // Re-mapped on UI
              conversationId: conversationId,
              message: decryptedMessage,
              createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            );
          }).toList();
        });
  }

  Future<bool> sendChatMessage(String conversationId, String content) async {
    try {
      if (currentUser == null) return false;
      final encryptedContent = EncryptionService.encrypt(content);
      
      await client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUser!.id,
        'content': encryptedContent,
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

class AuthErrorHandler {
  static String getFriendlyMessage(dynamic error) {
    final str = error.toString();
    if (str.contains('Invalid login credentials')) {
      return 'Incorrect email or password.';
    } else if (str.contains('User already registered') || str.contains('already exists')) {
      return 'This email address is already registered.';
    } else if (str.contains('Invalid or expired invitation code')) {
      return 'The invitation code you entered is invalid or has already been used.';
    } else if (str.contains('PostgrestException')) {
      return 'Database access denied or configuration error.';
    } else if (str.contains('Failed host lookup') || str.contains('SocketException')) {
      return 'Network error. Please check your internet connection.';
    } else {
      return str.replaceAll('AuthException:', '').replaceAll('Exception:', '').trim();
    }
  }
}
