import 'dart:async';
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

  final Set<String> _deletedClientIds = {};
  final Set<String> _deletedClientEmails = {};
  final Set<String> _deletedEmployeeIds = {};
  final Set<String> _deletedEmployeeEmails = {};

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

    // Enforcement: Reject if no valid membership is found.
    // This can happen if:
    //   a) The user was removed from their organization, OR
    //   b) They accepted an invite but the `redeem_invite_code` RPC failed
    //      (account exists in auth but was never added to organization_memberships).
    if (_currentMembership == null || _currentMembership!['status'] != 'active') {
      await client.auth.signOut();
      throw Exception(
        'Access denied: your account is not linked to any active organization. '
        'If you joined via an invitation code, please use "Accept Invite" on the login screen and re-enter your code.',
      );
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
      final cleanToken = token.trim().toUpperCase();
      final cleanName = fullName.trim();
      final targetEmail = email?.trim().toLowerCase();

      if (cleanToken.isEmpty) {
        throw Exception('Please enter your invitation code.');
      }
      if (targetEmail == null || targetEmail.isEmpty) {
        throw Exception('Email is required.');
      }
      if (password.isEmpty) {
        throw Exception('Password is required.');
      }

      // 1. Create or Sign In to Supabase Auth Account FIRST
      // This establishes an authenticated session so Supabase RLS permits database access.
      AuthResponse? authResp;
      try {
        authResp = await client.auth.signUp(
          email: targetEmail,
          password: password,
          data: {
            'full_name': cleanName,
          },
        );
      } catch (signUpErr) {
        final errStr = signUpErr.toString().toLowerCase();
        if (errStr.contains('already registered') || errStr.contains('already exists')) {
          try {
            authResp = await client.auth.signInWithPassword(
              email: targetEmail,
              password: password,
            );
          } catch (signInErr) {
            throw Exception('This email is already registered. Please enter your correct password to join.');
          }
        } else {
          rethrow;
        }
      }

      if (authResp == null || authResp.user == null) {
        throw Exception('Could not authenticate user account for invitation.');
      }

      // 2. Ensure we have an active session
      if (authResp.session == null) {
        try {
          authResp = await client.auth.signInWithPassword(
            email: targetEmail,
            password: password,
          );
        } catch (_) {
          throw Exception(
            'Account created! If email confirmation is enabled in your Supabase project, please confirm your email first.',
          );
        }
      }

      final userId = authResp.user!.id;

      // 3. Redeem the invitation code (RPC first, direct query fallback second)
      bool redeemed = false;
      String? lastError;

      // Method A: RPC redeem_invite_code
      for (final paramName in ['invite_code_param', 'invite_code', 'code', 'token', 'p_code', 'p_token']) {
        try {
          await client.rpc('redeem_invite_code', params: {
            paramName: cleanToken,
          });
          redeemed = true;
          debugPrint('RPC redeem_invite_code succeeded with parameter "$paramName"');
          break;
        } catch (rpcErr) {
          lastError = rpcErr.toString();
          debugPrint('RPC redeem_invite_code with "$paramName" failed: $rpcErr');
        }
      }

      // Method B: Direct database operations (Authenticated Context)
      if (!redeemed) {
        try {
          Map<String, dynamic>? inv;

          // Lookup invite by token / invite_code / code
          for (final col in ['token', 'invite_code', 'code']) {
            try {
              final res = await client
                  .from('invitations')
                  .select()
                  .eq(col, cleanToken)
                  .maybeSingle();
              if (res != null) {
                inv = Map<String, dynamic>.from(res);
                break;
              }
            } catch (e) {
              debugPrint('Lookup by column $col error: $e');
            }
          }

          // Case-insensitive fallback lookup if exact case didn't match
          if (inv == null) {
            try {
              final allInv = await client.from('invitations').select();
              for (final row in (allInv as List)) {
                final t = row['token']?.toString() ?? row['invite_code']?.toString() ?? row['code']?.toString() ?? '';
                if (t.trim().toUpperCase() == cleanToken) {
                  inv = Map<String, dynamic>.from(row);
                  break;
                }
              }
            } catch (_) {}
          }

          if (inv != null) {
            final orgId = inv['organization_id'];
            final role = inv['role']?.toString() ?? 'employee';

            // Insert or update organization_memberships
            await client.from('organization_memberships').upsert({
              'organization_id': orgId,
              'user_id': userId,
              'role': role,
              'status': 'active',
            });

            // Automatically create corresponding employee or client record
            if (role == 'employee') {
              try {
                await client.from('employees').upsert({
                  'organization_id': orgId,
                  'user_id': userId,
                  'designation': 'Staff',
                  'department': 'General',
                  'status': 'Active',
                });
              } catch (e) {
                debugPrint('Auto-creating employee record notice: $e');
              }
            } else if (role == 'client') {
              try {
                await client.from('clients').upsert({
                  'organization_id': orgId,
                  'user_id': userId,
                  'client_type': 'business',
                  'contact_name': cleanName,
                  'company_name': cleanName,
                  'email': targetEmail,
                  'status': 'Active',
                });
              } catch (e) {
                debugPrint('Auto-creating client record notice: $e');
              }
            }

            // Mark invitation as accepted
            try {
              final invId = inv['id'];
              if (invId != null) {
                await client.from('invitations').update({
                  'status': 'accepted',
                }).eq('id', invId);
              }
            } catch (_) {}

            redeemed = true;
          } else {
            lastError = 'Invitation code "$cleanToken" was not found in the database. Please verify the code generated by your admin.';
          }
        } catch (fallbackErr) {
          debugPrint('Direct membership insertion error: $fallbackErr');
          lastError = fallbackErr.toString();
        }
      }

      if (!redeemed) {
        // Sign out if redemption failed so user isn't stuck in an unlinked auth state
        await client.auth.signOut();
        throw Exception(
          AuthErrorHandler.getFriendlyMessage(lastError ?? 'Invalid or expired invitation code.'),
        );
      }

      // 4. Load full organization and role context
      await loadUserOrganizationContext();

      return authResp;
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
          // Fallback: direct table query (without joining organizations to avoid RLS 42501 error)
          debugPrint('RPC get_my_memberships failed, falling back to direct query: $rpcError');
          try {
            final result = await client
                .from('organization_memberships')
                .select()
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
          // Fetch organization details separately with fallback for employee RLS
          try {
            final orgResult = await client
                .from('organizations')
                .select()
                .eq('id', firstMem['organization_id'])
                .maybeSingle();
            if (orgResult != null) {
              _currentOrganization = Map<String, dynamic>.from(orgResult);
            } else {
              _currentOrganization = {
                'id': firstMem['organization_id'],
                'name': 'Enterprise Workspace',
              };
            }
          } catch (e) {
            debugPrint('Error fetching organization details: $e');
            _currentOrganization = {
              'id': firstMem['organization_id'],
              'name': 'Enterprise Workspace',
            };
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
  Timer? _realtimeDebounceTimer;

  void subscribeToRealtimeChanges(VoidCallback onDataChanged) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = client
        .channel('public:org_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          callback: (payload) {
            debugPrint('Supabase Realtime event received: ${payload.eventType}');
            _realtimeDebounceTimer?.cancel();
            _realtimeDebounceTimer = Timer(const Duration(milliseconds: 1000), () {
              onDataChanged();
            });
          },
        )
        .subscribe();
  }

  Future<List<Employee>?> fetchEmployees() async {
    try {
      if (currentOrganizationId == null) {
        await loadUserOrganizationContext();
      }
      if (currentOrganizationId == null) {
        return [];
      }

      // Fetch employees existing in employees table
      final response = await client
          .from('employees')
          .select('*, profiles(*)')
          .eq('organization_id', currentOrganizationId!);

      final rawList = List<Map<String, dynamic>>.from(response as List);

      // Synthesize any missing members from organization_memberships in memory (read-only, no DB writes)
      try {
        final mems = await client
            .from('organization_memberships')
            .select('user_id, role')
            .eq('organization_id', currentOrganizationId!);

        final existingUserIds = rawList
            .map((e) => e['user_id']?.toString())
            .whereType<String>()
            .toSet();

        for (final mem in (mems as List)) {
          final uId = mem['user_id']?.toString();
          final r = mem['role']?.toString() ?? 'employee';
          if (uId != null && uId.isNotEmpty && !existingUserIds.contains(uId) && r == 'employee') {
            if (_deletedEmployeeIds.contains(uId)) continue;
            rawList.add({
              'id': 'mem_$uId',
              'user_id': uId,
              'designation': 'Staff',
              'department': 'General',
              'status': 'Active',
              'joining_date': DateTime.now().toString().split(' ')[0],
              'profiles': null,
            });
          }
        }
      } catch (syncErr) {
        debugPrint('Employees auto-sync notice: $syncErr');
      }

      final list = (response as List)
          .where((json) {
            final eId = json['id']?.toString();
            final profile = json['profiles'] as Map<String, dynamic>?;
            final eEmail = profile?['email']?.toString()?.trim()?.toLowerCase();
            if (eId != null && _deletedEmployeeIds.contains(eId)) return false;
            if (eEmail != null && _deletedEmployeeEmails.contains(eEmail)) return false;
            return true;
          })
          .map((json) {
        final profile = json['profiles'] as Map<String, dynamic>?;
        return Employee(
          id: json['id']?.toString() ?? '',
          userId: json['user_id']?.toString() ?? '',
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

  Future<bool> deleteEmployee(String id, {String? email}) async {
    try {
      if (currentOrganizationId == null) {
        await loadUserOrganizationContext();
      }
      _deletedEmployeeIds.add(id);

      final targetEmail = email?.trim()?.toLowerCase();
      if (targetEmail != null && targetEmail.isNotEmpty) {
        _deletedEmployeeEmails.add(targetEmail);
      }

      var query = client.from('employees').select('id, user_id, email, profiles(email)');
      if (targetEmail != null && targetEmail.isNotEmpty) {
        query = query.or('id.eq.$id,email.eq.$targetEmail');
      } else {
        query = query.eq('id', id);
      }

      final records = await query;
      if (records is List && records.isNotEmpty) {
        for (final rec in records) {
          final dbId = rec['id']?.toString();
          final dbUserId = rec['user_id']?.toString();
          String? dbEmail = rec['email']?.toString()?.trim()?.toLowerCase();
          if ((dbEmail == null || dbEmail.isEmpty) && rec['profiles'] != null && rec['profiles'] is Map) {
            dbEmail = (rec['profiles'] as Map)['email']?.toString()?.trim()?.toLowerCase();
          }

          if (dbId != null) _deletedEmployeeIds.add(dbId);
          if (dbEmail != null) _deletedEmployeeEmails.add(dbEmail);

          if (dbId != null) {
            try { await client.from('attendance_logs').delete().eq('user_id', dbId); } catch (_) {}
            try { await client.from('attendance_logs').delete().eq('employee_id', dbId); } catch (_) {}
            try { await client.from('leave_requests').delete().eq('employee_id', dbId); } catch (_) {}
            try { await client.from('tasks').delete().eq('assigned_employee_id', dbId); } catch (_) {}
            try { await client.from('clients').update({'assigned_employee_id': null, 'assigned_employee_name': null}).eq('assigned_employee_id', dbId); } catch (_) {}
          }

          if (currentOrganizationId != null) {
            if (dbUserId != null && dbUserId.isNotEmpty) {
              try { await client.from('organization_memberships').delete().eq('organization_id', currentOrganizationId!).eq('user_id', dbUserId); } catch (_) {}
            }
            if (dbEmail != null && dbEmail.isNotEmpty) {
              try { await client.from('invitations').delete().eq('organization_id', currentOrganizationId!).eq('email', dbEmail); } catch (_) {}
            }
          }

          if (dbId != null) {
            await client.from('employees').delete().eq('id', dbId);
          }
        }
      }

      if (targetEmail != null && targetEmail.isNotEmpty) {
        await client.from('employees').delete().eq('email', targetEmail);
      }
      await client.from('employees').delete().eq('id', id);

      return true;
    } catch (e) {
      debugPrint('Supabase deleteEmployee error: $e');
      return false;
    }
  }

  Future<List<ClientModel>?> fetchClients() async {
    try {
      if (currentOrganizationId == null) {
        await loadUserOrganizationContext();
      }
      if (currentOrganizationId == null) {
        return [];
      }

      final response = await client
          .from('clients')
          .select('*, profiles(*)')
          .eq('organization_id', currentOrganizationId!);

      // Auto-sync any client invitations, client memberships, or client profiles missing in clients table
      try {
        final existingEmails = (response as List)
            .map((c) => c['email']?.toString().trim().toLowerCase())
            .whereType<String>()
            .toSet();

        final existingUserIds = (response as List)
            .map((c) => c['user_id']?.toString())
            .whereType<String>()
            .toSet();

        bool hasNew = false;

        // 1. Check invitations table for role == 'client'
        final clientInvites = await client
            .from('invitations')
            .select('email, status')
            .eq('organization_id', currentOrganizationId!)
            .eq('role', 'client');

        for (final inv in (clientInvites as List)) {
          final invEmail = inv['email']?.toString().trim().toLowerCase();
          if (invEmail != null && invEmail.isNotEmpty && !existingEmails.contains(invEmail)) {
            final namePart = invEmail.contains('@') ? invEmail.split('@').first : invEmail;
            try {
              await client.from('clients').upsert({
                'organization_id': currentOrganizationId,
                'client_type': 'business',
                'contact_name': namePart,
                'company_name': namePart,
                'email': invEmail,
                'status': 'Active',
              });
              existingEmails.add(invEmail);
              hasNew = true;
            } catch (e) {
              debugPrint('Syncing client invitation error: $e');
            }
          }
        }

        // 2. Check organization_memberships table for role == 'client'
        final clientMems = await client
            .from('organization_memberships')
            .select('user_id, role')
            .eq('organization_id', currentOrganizationId!)
            .eq('role', 'client');

        for (final mem in (clientMems as List)) {
          final uId = mem['user_id']?.toString();
          if (uId != null && uId.isNotEmpty && !existingUserIds.contains(uId)) {
            try {
              final prof = await client
                  .from('profiles')
                  .select('full_name, email, phone')
                  .eq('id', uId)
                  .maybeSingle();
              if (prof != null) {
                final pEmail = prof['email']?.toString().trim().toLowerCase();
                final pName = prof['full_name']?.toString() ?? 'Client';
                if (pEmail != null && pEmail.isNotEmpty && !existingEmails.contains(pEmail)) {
                  await client.from('clients').upsert({
                    'organization_id': currentOrganizationId,
                    'user_id': uId,
                    'client_type': 'business',
                    'contact_name': pName,
                    'company_name': pName,
                    'email': pEmail,
                    'phone': prof['phone']?.toString() ?? '',
                    'status': 'Active',
                  });
                  existingEmails.add(pEmail);
                  existingUserIds.add(uId);
                  hasNew = true;
                }
              }
            } catch (e) {
              debugPrint('Syncing client membership error: $e');
            }
          }
        }

      } catch (syncErr) {
        debugPrint('Clients auto-sync notice: $syncErr');
      }

      final list = (response as List)
          .where((json) {
            final cId = json['id']?.toString();
            final cEmail = json['email']?.toString()?.trim()?.toLowerCase();
            if (cId != null && _deletedClientIds.contains(cId)) return false;
            if (cEmail != null && _deletedClientEmails.contains(cEmail)) return false;
            return true;
          })
          .map((json) {
        final profile = json['profiles'] as Map<String, dynamic>?;
        final name = json['contact_name']?.toString() ?? json['name']?.toString() ?? profile?['full_name']?.toString() ?? '';
        final email = json['email']?.toString() ?? profile?['email']?.toString() ?? '';
        final company = json['company_name']?.toString() ?? json['company']?.toString() ?? name;
        return ClientModel(
          id: json['id']?.toString() ?? '',
          name: name.isNotEmpty ? name : 'Client',
          company: company.isNotEmpty ? company : 'Client Business',
          email: email,
          phone: json['phone']?.toString() ?? profile?['phone']?.toString() ?? '',
          status: json['status']?.toString() ?? 'Active',
          assignedEmployeeId: json['assigned_employee_id']?.toString(),
          assignedEmployeeName: json['assigned_employee_name']?.toString(),
          projectType: json['project_type']?.toString() ?? 'General Consulting',
          budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
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
        'assigned_employee_id': clientData.assignedEmployeeId,
        'assigned_employee_name': clientData.assignedEmployeeName,
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
        'assigned_employee_id': clientData.assignedEmployeeId,
        'assigned_employee_name': clientData.assignedEmployeeName,
      }).eq('id', clientData.id);
      return true;
    } catch (e) {
      debugPrint('Supabase updateClient error: $e');
      return false;
    }
  }

  Future<bool> deleteClient(String id, {String? email}) async {
    try {
      if (currentOrganizationId == null) {
        await loadUserOrganizationContext();
      }
      _deletedClientIds.add(id);

      final targetEmail = email?.trim()?.toLowerCase();
      if (targetEmail != null && targetEmail.isNotEmpty) {
        _deletedClientEmails.add(targetEmail);
      }

      var query = client.from('clients').select('id, user_id, email');
      if (targetEmail != null && targetEmail.isNotEmpty) {
        query = query.or('id.eq.$id,email.eq.$targetEmail');
      } else {
        query = query.eq('id', id);
      }

      final records = await query;
      if (records is List && records.isNotEmpty) {
        for (final rec in records) {
          final dbId = rec['id']?.toString();
          final dbUserId = rec['user_id']?.toString();
          final dbEmail = rec['email']?.toString()?.trim()?.toLowerCase();

          if (dbId != null) _deletedClientIds.add(dbId);
          if (dbEmail != null) _deletedClientEmails.add(dbEmail);

          if (dbId != null) {
            try { await client.from('projects').delete().eq('client_id', dbId); } catch (_) {}
            try { await client.from('invoices').delete().eq('client_id', dbId); } catch (_) {}
            try { await client.from('chat_messages').delete().eq('client_id', dbId); } catch (_) {}
            try { await client.from('tasks').delete().eq('client_id', dbId); } catch (_) {}
          }

          if (currentOrganizationId != null) {
            if (dbEmail != null && dbEmail.isNotEmpty) {
              try { await client.from('invitations').delete().eq('organization_id', currentOrganizationId!).eq('email', dbEmail); } catch (_) {}
            }
            if (dbUserId != null && dbUserId.isNotEmpty) {
              try { await client.from('organization_memberships').delete().eq('organization_id', currentOrganizationId!).eq('user_id', dbUserId); } catch (_) {}
            }
          }

          if (dbId != null) {
            await client.from('clients').delete().eq('id', dbId);
          }
        }
      }

      if (targetEmail != null && targetEmail.isNotEmpty) {
        await client.from('clients').delete().eq('email', targetEmail);
      }
      await client.from('clients').delete().eq('id', id);

      return true;
    } catch (e) {
      debugPrint('Supabase deleteClient error: $e');
      return false;
    }
  }

  Future<List<LeaveRequest>?> fetchLeaveRequests() async {
    try {
      if (currentOrganizationId == null) {
        await loadUserOrganizationContext();
      }
      if (currentOrganizationId == null) {
        return [];
      }
      final response = await client
          .from('leave_requests')
          .select('*, profiles:profiles!leave_requests_user_id_fkey(*)')
          .eq('organization_id', currentOrganizationId!)
          .order('created_at', ascending: false);
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

  String _parseToIsoDate(String rawDate) {
    if (rawDate.isEmpty) return DateTime.now().toIso8601String().split('T')[0];
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(rawDate)) {
      return rawDate.substring(0, 10);
    }
    final parts = rawDate.split(' ')[0].split('/');
    if (parts.length == 3) {
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[2];
      return '$year-$month-$day';
    }
    return DateTime.now().toIso8601String().split('T')[0];
  }

  Future<bool> insertLeaveRequest(LeaveRequest request) async {
    try {
      if (currentOrganizationId == null || currentUser == null) return false;
      final isoStart = _parseToIsoDate(request.startDate);
      final isoEnd = _parseToIsoDate(request.endDate);
      
      // Resolve target user_id (if request.employeeId is a valid user ID/UUID, use it; otherwise currentUser.id)
      final targetUserId = (request.employeeId.isNotEmpty &&
              !request.employeeId.startsWith('lv_') &&
              !request.employeeId.startsWith('emp_'))
          ? request.employeeId
          : currentUser!.id;

      final allowedTypes = {'Casual', 'Sick', 'Paid', 'Unpaid', 'Annual', 'Vacation', 'Personal', 'Maternity/Paternity'};
      final type = allowedTypes.contains(request.type) ? request.type : 'Casual';

      final res = await client.from('leave_requests').insert({
        'organization_id': currentOrganizationId,
        'user_id': targetUserId,
        'leave_type': type,
        'start_date': isoStart,
        'end_date': isoEnd,
        'reason': request.reason.isEmpty ? 'General leave request' : request.reason,
        'status': request.status.isEmpty ? 'Pending' : request.status,
      }).select();
      
      return res != null && (res as List).isNotEmpty;
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

  final Map<String, List<ChatMessage>> _localMessagesCache = {};

  Future<String> getOrCreateDirectConversation(String otherUserId) async {
    try {
      if (currentUser == null || currentOrganizationId == null) {
        final cleanOther = otherUserId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        return 'conv_$cleanOther';
      }
      final myId = currentUser!.id;
      
      try {
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
      } catch (checkErr) {
        debugPrint('Direct conversation lookup notice: $checkErr');
      }
      
      try {
        final newConv = await client.from('conversations').insert({
          'organization_id': currentOrganizationId,
          'type': 'direct',
          'title': 'Direct Chat',
        }).select().single();
        
        final convId = newConv['id'] as String;
        
        try {
          await client.from('conversation_members').insert([
            {'conversation_id': convId, 'user_id': myId},
            {'conversation_id': convId, 'user_id': otherUserId},
          ]);
        } catch (memErr) {
          debugPrint('conversation_members insert notice: $memErr');
        }
        
        return convId;
      } catch (convErr) {
        debugPrint('conversations insert notice: $convErr');
      }

      final safeOther = otherUserId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final safeMy = myId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      return 'conv_${safeMy}_$safeOther';
    } catch (e) {
      debugPrint('Supabase getOrCreateDirectConversation error: $e');
      final safeOther = otherUserId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      return 'conv_$safeOther';
    }
  }

  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    Stream<List<ChatMessage>> remoteStream;
    try {
      remoteStream = client
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
    } catch (e) {
      debugPrint('getMessagesStream init notice: $e');
      remoteStream = Stream.value([]);
    }

    return remoteStream.map((remoteList) {
      final localList = _localMessagesCache[conversationId] ?? [];
      final combined = [...remoteList];
      for (final loc in localList) {
        if (!combined.any((r) => r.id == loc.id || (r.message == loc.message && r.senderId == loc.senderId))) {
          combined.add(loc);
        }
      }
      return combined;
    }).handleError((err) {
      debugPrint('getMessagesStream error notice: $err');
      return _localMessagesCache[conversationId] ?? [];
    });
  }

  Future<bool> sendChatMessage(String conversationId, String content) async {
    final senderId = currentUser?.id ?? 'user';
    final newMsg = ChatMessage(
      id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: 'Me',
      senderRole: 'user',
      conversationId: conversationId,
      message: content,
      createdAt: DateTime.now().toIso8601String(),
    );

    if (!_localMessagesCache.containsKey(conversationId)) {
      _localMessagesCache[conversationId] = [];
    }
    _localMessagesCache[conversationId]!.add(newMsg);

    try {
      if (currentUser == null) return true;
      final encryptedContent = EncryptionService.encrypt(content);
      
      final payload = <String, dynamic>{
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': encryptedContent,
      };
      if (currentOrganizationId != null) {
        payload['organization_id'] = currentOrganizationId;
      }

      await client.from('messages').insert(payload);
      return true;
    } catch (e) {
      debugPrint('Supabase sendChatMessage notice (cached locally): $e');
      return true;
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

  Future<void> assignProjectMembers(String projectId, List<String> userIds) async {
    if (userIds.isEmpty) return;
    try {
      final membersToInsert = userIds.map((userId) => {
        'project_id': projectId,
        'user_id': userId,
        'role_in_project': 'member',
      }).toList();
      await client.from('project_members').insert(membersToInsert);
    } catch (e) {
      debugPrint('Error assigning project members: $e');
    }
  }

  Future<List<String>> fetchUserProjectIds(String userId) async {
    try {
      final response = await client
          .from('project_members')
          .select('project_id')
          .eq('user_id', userId);
      return (response as List).map((json) => json['project_id'].toString()).toList();
    } catch (e) {
      debugPrint('Error fetching user project ids: $e');
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
      if (str.contains('42501') || str.contains('permission denied')) {
        return 'Access restricted: Your employee account does not have permission for this database table. Please contact your organization administrator.';
      }
      return str.replaceAll('PostgrestException:', '').replaceAll('AuthException:', '').replaceAll('Exception:', '').trim();
    } else if (str.contains('Failed host lookup') || str.contains('SocketException')) {
      return 'Network error. Please check your internet connection.';
    } else {
      return str.replaceAll('AuthException:', '').replaceAll('Exception:', '').trim();
    }
  }
}
