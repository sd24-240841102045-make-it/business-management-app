import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
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
  bool _isAuthActionInProgress = false;

  final Set<String> _deletedClientIds = {};
  final Set<String> _deletedClientEmails = {};
  final Set<String> _deletedEmployeeIds = {};
  final Set<String> _deletedEmployeeEmails = {};
  final Set<String> _deletedProjectIds = {};

  bool isProjectDeleted(String id) => _deletedProjectIds.contains(id);

  final Map<String, List<ChatMessage>> _localMessagesCache = {};
  final Map<String, RealtimeChannel> _activeChannels = {};
  final Map<String, StreamSubscription> _streamSubscriptions = {};

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

  /// Verify an invitation code and get details (email, role, organization)
  Future<Map<String, dynamic>?> checkInviteDetails(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length < 3) return null;

    // 1. Try RPC get_invite_details
    try {
      final res = await client.rpc('get_invite_details', params: {'invite_code_param': cleanCode});
      if (res is Map && res['valid'] == true) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}

    // 2. Try RPC verify_invite_code
    try {
      final res = await client.rpc('verify_invite_code', params: {'invite_code_param': cleanCode});
      if (res == true) {
        return {'valid': true, 'token': cleanCode};
      }
    } catch (_) {}

    // 3. Fallback: direct table query
    try {
      final res = await client
          .from('invitations')
          .select()
          .eq('token', cleanCode)
          .eq('status', 'pending')
          .maybeSingle();
      if (res != null) {
        return {
          'valid': true,
          'email': res['email'],
          'role': res['role'],
          'organization_id': res['organization_id'],
          'token': cleanCode,
        };
      }
    } catch (_) {}

    return null;
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
      final targetEmail = email?.trim().toLowerCase();
      final cleanName = fullName.trim().isNotEmpty
          ? fullName.trim()
          : (targetEmail != null && targetEmail.contains('@')
              ? targetEmail.split('@').first
              : 'Team Member');

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

      if (authResp.user == null) {
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

  /// Returns the set of user IDs that have role='admin' in this organization.
  /// Used to exclude admins from employee and client lists.
  Future<Set<String>> _fetchAdminUserIds() async {
    try {
      if (currentOrganizationId == null) return {};
      final rows = await client
          .from('organization_memberships')
          .select('user_id')
          .eq('organization_id', currentOrganizationId!)
          .eq('role', 'admin');
      return (rows as List)
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toSet();
    } catch (_) {
      return {};
    }
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

      final adminUserIds = await _fetchAdminUserIds();

      final list = (rawList)
          .where((json) {
            final eId = json['id']?.toString();
            final eUserId = json['user_id']?.toString();
            final profile = json['profiles'] as Map<String, dynamic>?;
            final eEmail = profile?['email']?.toString().trim().toLowerCase();
            if (eId != null && _deletedEmployeeIds.contains(eId)) return false;
            if (eEmail != null && _deletedEmployeeEmails.contains(eEmail)) return false;
            // Exclude admins from the employee list
            if (eUserId != null && adminUserIds.contains(eUserId)) return false;
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

      final targetEmail = email?.trim().toLowerCase();
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
      if (records.isNotEmpty) {
        for (final rec in records) {
          final dbId = rec['id']?.toString();
          final dbUserId = rec['user_id']?.toString();
          String? dbEmail = rec['email']?.toString().trim().toLowerCase();
          if ((dbEmail == null || dbEmail.isEmpty) && rec['profiles'] != null && rec['profiles'] is Map) {
            dbEmail = (rec['profiles'] as Map)['email']?.toString().trim().toLowerCase();
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

      var response = await client
          .from('clients')
          .select('*, profiles(*)')
          .eq('organization_id', currentOrganizationId!);

      bool hasNew = false;
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

      if (hasNew) {
        try {
          response = await client.from('clients').select('*, profiles(*)').eq('organization_id', currentOrganizationId!);
        } catch (_) {}
      }

      final adminUserIds = await _fetchAdminUserIds();

      final list = (response as List)
          .where((json) {
            final cId = json['id']?.toString();
            final cEmail = json['email']?.toString().trim().toLowerCase();
            final cUserId = json['user_id']?.toString();
            if (cId != null && _deletedClientIds.contains(cId)) return false;
            if (cEmail != null && _deletedClientEmails.contains(cEmail)) return false;
            // Exclude admins from the client list
            if (cUserId != null && adminUserIds.contains(cUserId)) return false;
            return true;
          })
          .map((json) {
        final profile = json['profiles'] as Map<String, dynamic>?;
        final name = json['contact_name']?.toString() ?? json['name']?.toString() ?? profile?['full_name']?.toString() ?? '';
        final email = json['email']?.toString() ?? profile?['email']?.toString() ?? '';
        final company = json['company_name']?.toString() ?? json['company']?.toString() ?? name;
        return ClientModel(
          id: json['id']?.toString() ?? '',
          userId: json['user_id']?.toString(),
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

      final targetEmail = email?.trim().toLowerCase();
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
      if (records.isNotEmpty) {
        for (final rec in records) {
          final dbId = rec['id']?.toString();
          final dbUserId = rec['user_id']?.toString();
          final dbEmail = rec['email']?.toString().trim().toLowerCase();

          if (dbId != null) _deletedClientIds.add(dbId);
          if (dbEmail != null) _deletedClientEmails.add(dbEmail);

          if (dbId != null) {
            try {
              final clientProjs = await client.from('projects').select('id').eq('client_id', dbId);
              if (clientProjs.isNotEmpty) {
                for (final cp in clientProjs) {
                  final cpId = cp['id']?.toString();
                  if (cpId != null && cpId.isNotEmpty) {
                    _deletedProjectIds.add(cpId);
                    try { await client.from('tasks').delete().eq('project_id', cpId); } catch (_) {}
                    try { await client.from('invoices').delete().eq('project_id', cpId); } catch (_) {}
                    try { await client.from('project_members').delete().eq('project_id', cpId); } catch (_) {}
                  }
                }
              }
            } catch (_) {}
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
      
      return (res as List).isNotEmpty;
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

  Future<List<AdminModel>> fetchAdmins() async {
    try {
      if (currentOrganizationId == null) {
        await loadUserOrganizationContext();
      }

      final list = <AdminModel>[];
      final seenAdminIds = <String>{};

      // 1. Primary: Fetch from organization_memberships with role='admin' or 'owner' in current organization
      if (currentOrganizationId != null && currentOrganizationId!.isNotEmpty) {
        try {
          final mems = await client
              .from('organization_memberships')
              .select('user_id, role')
              .eq('organization_id', currentOrganizationId!)
              .or('role.eq.admin,role.eq.owner');

          final adminUserIds = (mems as List)
              .map((m) => m['user_id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toSet();

          if (adminUserIds.isNotEmpty) {
            final profilesRes = await client
                .from('profiles')
                .select('*')
                .inFilter('id', adminUserIds.toList());

            for (final p in (profilesRes as List)) {
              final uId = p['id']?.toString() ?? '';
              if (uId.isNotEmpty && !seenAdminIds.contains(uId)) {
                seenAdminIds.add(uId);
                list.add(AdminModel(
                  id: uId,
                  name: p['full_name']?.toString() ?? 'Executive Admin',
                  email: p['email']?.toString() ?? 'admin@company.com',
                  phone: p['phone']?.toString() ?? p['phone_number']?.toString() ?? '',
                  avatarUrl: p['avatar_url']?.toString() ?? '',
                ));
              }
            }
          }
        } catch (memErr) {
          debugPrint('Error fetching admin memberships: $memErr');
        }
      }

      // 2. Secondary: Check profiles table directly in case role column exists on profiles
      try {
        final res = await client.from('profiles').select('*');
        for (final p in (res as List)) {
          final role = p['role']?.toString().toLowerCase() ?? '';
          final uId = p['id']?.toString() ?? '';
          if ((role == 'admin' || role == 'owner') && uId.isNotEmpty && !seenAdminIds.contains(uId)) {
            seenAdminIds.add(uId);
            list.add(AdminModel(
              id: uId,
              name: p['full_name']?.toString() ?? 'Executive Admin',
              email: p['email']?.toString() ?? 'admin@company.com',
              phone: p['phone']?.toString() ?? p['phone_number']?.toString() ?? '',
              avatarUrl: p['avatar_url']?.toString() ?? '',
            ));
          }
        }
      } catch (_) {}

      // 3. Fallback: Only if current user IS an admin and no admin was found, add self
      if (list.isEmpty) {
        final u = currentUser;
        final myRole = currentRole;
        if (u != null && (myRole == 'admin' || myRole == 'owner')) {
          list.add(AdminModel(
            id: u.id,
            name: 'Executive Admin',
            email: u.email ?? 'admin@company.com',
          ));
        }
      }

      return list;
    } catch (e) {
      debugPrint('Error in fetchAdmins: $e');
      return [];
    }
  }

  // ============================================================
  // REAL-TIME CHAT & MESSAGING ENGINE
  // ============================================================

  /// Returns deterministic UUID v3 for direct 1-on-1 conversations between two user IDs
  String _generateDeterministicConversationUuid(String idA, String idB) {
    final pair = [idA.trim().toLowerCase(), idB.trim().toLowerCase()]..sort();
    final hash = md5.convert(utf8.encode('direct_chat_${pair[0]}_${pair[1]}')).toString();
    final p1 = hash.substring(0, 8);
    final p2 = hash.substring(8, 12);
    final p3 = '3${hash.substring(13, 16)}'; // UUID v3 (MD5 based)
    final p4 = 'a${hash.substring(17, 20)}'; // RFC 4122 variant
    final p5 = hash.substring(20, 32);
    return '$p1-$p2-$p3-$p4-$p5';
  }

  /// Generates a valid UUID v4 for individual messages
  String _generateMessageUuid() {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    final rand = '${DateTime.now().millisecondsSinceEpoch}_${currentUser?.id ?? 'anon'}';
    final hash = md5.convert(utf8.encode('msg_${now}_$rand')).toString();
    final p1 = hash.substring(0, 8);
    final p2 = hash.substring(8, 12);
    final p3 = '4${hash.substring(13, 16)}'; // UUID v4 format
    final p4 = 'a${hash.substring(17, 20)}'; // RFC 4122 variant
    final p5 = hash.substring(20, 32);
    return '$p1-$p2-$p3-$p4-$p5';
  }

  /// Returns the current user's display name for chat messages
  String get currentUserName {
    final uid = currentUser?.id;
    if (uid == null) return 'Me';
    for (final a in AppDataStore().admins) {
      if (a.id == uid) return a.name;
    }
    for (final e in AppDataStore().employees) {
      if (e.userId == uid || e.id == uid) return e.name;
    }
    for (final c in AppDataStore().clients) {
      if (c.userId == uid || c.id == uid) return c.name;
    }
    return currentUser?.email?.split('@').first ?? 'Me';
  }

  Future<String> getOrCreateDirectConversation(String targetId) async {
    try {
      final user = currentUser;
      final myId = user?.id ?? 'guest_user';

      // Step 1: Resolve targetId to real Supabase Auth UUID if targetId is a Client/Employee record ID or email
      String otherUserId = targetId;
      for (final c in AppDataStore().clients) {
        if ((c.id == targetId || c.email.toLowerCase() == targetId.toLowerCase()) &&
            c.userId != null && c.userId!.isNotEmpty) {
          otherUserId = c.userId!;
          break;
        }
      }
      if (otherUserId == targetId) {
        for (final emp in AppDataStore().employees) {
          if ((emp.id == targetId || emp.email.toLowerCase() == targetId.toLowerCase()) &&
              emp.userId.isNotEmpty) {
            otherUserId = emp.userId;
            break;
          }
        }
      }
      if (otherUserId == targetId) {
        for (final admin in AppDataStore().admins) {
          if ((admin.id == targetId || admin.email.toLowerCase() == targetId.toLowerCase()) &&
              admin.id.isNotEmpty) {
            otherUserId = admin.id;
            break;
          }
        }
      }

      // Step 2: Compute deterministic UUID — both sides always get the same conversation ID
      final convId = _generateDeterministicConversationUuid(myId, otherUserId);

      if (user == null) return convId;

      // Step 3: Robust orgId resolution — try 3 methods before giving up
      String? orgId = currentOrganizationId;
      if (orgId == null || orgId.isEmpty) {
        try {
          await loadUserOrganizationContext();
          orgId = currentOrganizationId;
        } catch (_) {}
      }
      if (orgId == null || orgId.isEmpty) {
        try {
          final memberships = await client
              .from('organization_memberships')
              .select('organization_id')
              .eq('user_id', myId)
              .limit(1);
          if ((memberships as List).isNotEmpty) {
            orgId = memberships.first['organization_id']?.toString();
          }
        } catch (_) {}
      }
      if (orgId == null || orgId.isEmpty) {
        try {
          final orgRes = await client
              .from('organizations')
              .select('id')
              .limit(1)
              .maybeSingle();
          orgId = orgRes?['id']?.toString();
        } catch (_) {}
      }

      // Step 4: Ensure conversation row exists (upsert is idempotent)
      if (orgId != null && orgId.isNotEmpty) {
        try {
          await client.from('conversations').upsert(
            {
              'id': convId,
              'organization_id': orgId,
              'type': 'direct',
              'title': 'Direct Chat',
            },
            onConflict: 'id',
            ignoreDuplicates: true,
          );
          debugPrint('Conversation ensured in DB: $convId (org: $orgId)');
        } catch (convErr) {
          debugPrint('Notice creating conversation row: $convErr');
        }
      } else {
        // No orgId found — try without it (requires organization_id to be nullable in schema)
        try {
          await client.from('conversations').upsert(
            {'id': convId, 'type': 'direct', 'title': 'Direct Chat'},
            onConflict: 'id',
            ignoreDuplicates: true,
          );
          debugPrint('Conversation ensured in DB (no orgId): $convId');
        } catch (convErr2) {
          debugPrint('Notice creating conversation (no orgId): $convErr2');
        }
      }

      // Step 5: Add each member individually using INSERT ... ON CONFLICT DO NOTHING
      // (avoids RLS infinite recursion that batch upsert triggers)
      for (final uid in {myId, otherUserId}) {
        try {
          await client.from('conversation_members').insert(
            {'conversation_id': convId, 'user_id': uid},
          );
        } catch (memErr) {
          // Ignore duplicate key errors (code 23505 = unique_violation) — member already exists
          final errStr = memErr.toString();
          if (!errStr.contains('23505') && !errStr.contains('duplicate') && !errStr.contains('unique')) {
            debugPrint('Notice adding member $uid to conversation: $memErr');
          }
        }
      }

      debugPrint('getOrCreateDirectConversation done. convId=$convId otherUserId=$otherUserId');
      return convId;
    } catch (e) {
      debugPrint('Supabase getOrCreateDirectConversation error: $e');
      final myId = currentUser?.id ?? 'anon';
      return _generateDeterministicConversationUuid(myId, targetId);
    }
  }

  // Per-conversation stream controllers (stable across UI rebuilds)
  final Map<String, StreamController<List<ChatMessage>>> _convStreamControllers = {};

  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {
    if (!_convStreamControllers.containsKey(conversationId) || _convStreamControllers[conversationId]!.isClosed) {
      final controller = StreamController<List<ChatMessage>>.broadcast();
      _convStreamControllers[conversationId] = controller;
      _subscribeToConversation(conversationId, controller);
    } else {
      // Re-emit local cached messages immediately so UI populates without delay
      final currentList = _localMessagesCache[conversationId] ?? [];
      if (currentList.isNotEmpty) {
        Future.microtask(() {
          final ctrl = _convStreamControllers[conversationId];
          if (ctrl != null && !ctrl.isClosed) {
            ctrl.add(List.unmodifiable(currentList));
          }
        });
      }
    }
    return _convStreamControllers[conversationId]!.stream;
  }

  void _subscribeToConversation(String conversationId, StreamController<List<ChatMessage>> controller) {
    // 1. Immediately emit whatever is already in local cache
    final localList = _localMessagesCache[conversationId] ?? [];
    if (localList.isNotEmpty && !controller.isClosed) {
      controller.add(List.unmodifiable(localList));
    }

    // 2. Load historical messages from Supabase Postgres database
    _fetchHistoricalMessages(conversationId, controller);

    // 3. Connect to Supabase Realtime Broadcast channel for instant peer-to-peer WebSocket messaging
    _subscribeRealtimeBroadcast(conversationId);

    // 4. Connect to Postgres Change Data Capture stream for database writes
    _subscribePostgresStream(conversationId, controller);
  }

  Future<void> _fetchHistoricalMessages(String conversationId, StreamController<List<ChatMessage>> controller) async {
    try {
      final response = await client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final historicalMessages = (response as List).map((json) {
        final content = json['content']?.toString() ?? '';
        return ChatMessage(
          id: json['id']?.toString() ?? '',
          senderId: json['sender_id']?.toString() ?? '',
          senderName: 'User',
          senderRole: 'user',
          conversationId: conversationId,
          message: content,
          createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        );
      }).toList();

      _pushMergedMessages(conversationId, controller, historicalMessages);
    } catch (e) {
      debugPrint('Notice loading historical messages: $e');
    }
  }

  void _subscribeRealtimeBroadcast(String conversationId) {
    if (_activeChannels.containsKey(conversationId)) return;

    try {
      final channel = client.channel('chat_$conversationId');
      channel.onBroadcast(
        event: 'chat_msg',
        callback: (payload) {
          try {
            final senderId = payload['sender_id']?.toString() ?? '';
            // Do not duplicate messages sent by current user on this device
            if (senderId == (currentUser?.id ?? '')) return;

            // Use plain_content first (direct), fall back to content field
            final content = (payload['plain_content']?.toString() ?? '').isNotEmpty
                ? payload['plain_content'].toString()
                : (payload['content']?.toString() ?? '');

            final msg = ChatMessage(
              id: payload['id']?.toString() ?? 'bc_${DateTime.now().millisecondsSinceEpoch}',
              senderId: senderId,
              senderName: payload['sender_name']?.toString() ?? 'User',
              senderRole: payload['sender_role']?.toString() ?? 'user',
              conversationId: conversationId,
              message: content,
              createdAt: payload['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            );

            _addAndPushMessage(conversationId, msg);
          } catch (err) {
            debugPrint('Error processing broadcast message: $err');
          }
        },
      ).subscribe();

      _activeChannels[conversationId] = channel;
      debugPrint('Realtime WebSocket broadcast channel subscribed for: chat_$conversationId');
    } catch (e) {
      debugPrint('Realtime channel subscription notice: $e');
    }
  }

  void _subscribePostgresStream(String conversationId, StreamController<List<ChatMessage>> controller) {
    try {
      _streamSubscriptions[conversationId]?.cancel();
      final streamSub = client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .listen((list) {
            if (controller.isClosed) return;
            final remoteMessages = list.map((json) {
              final content = json['content']?.toString() ?? '';
              return ChatMessage(
                id: json['id']?.toString() ?? '',
                senderId: json['sender_id']?.toString() ?? '',
                senderName: 'User',
                senderRole: 'user',
                conversationId: conversationId,
                message: content,
                createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
              );
            }).toList();

            _pushMergedMessages(conversationId, controller, remoteMessages);
          }, onError: (err) {
            debugPrint('Postgres realtime stream notice for $conversationId: $err');
          });

      _streamSubscriptions[conversationId] = streamSub;
    } catch (e) {
      debugPrint('getMessagesStream subscribe error: $e');
    }
  }

  void _addAndPushMessage(String conversationId, ChatMessage msg) {
    final list = _localMessagesCache.putIfAbsent(conversationId, () => []);
    final alreadyExists = list.any((m) =>
      m.id == msg.id ||
      (m.senderId == msg.senderId &&
       m.message == msg.message &&
       (DateTime.tryParse(m.createdAt)?.difference(DateTime.tryParse(msg.createdAt) ?? DateTime.now()).inSeconds.abs() ?? 999) < 4));

    if (!alreadyExists) {
      list.add(msg);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final controller = _convStreamControllers[conversationId];
      if (controller != null && !controller.isClosed) {
        controller.add(List.unmodifiable(list));
      }
    }
  }

  void _pushMergedMessages(
    String conversationId,
    StreamController<List<ChatMessage>> controller,
    List<ChatMessage> remoteMessages,
  ) {
    if (controller.isClosed) return;
    final localList = _localMessagesCache.putIfAbsent(conversationId, () => []);

    for (final remote in remoteMessages) {
      final exists = localList.any((loc) =>
        loc.id == remote.id ||
        (loc.senderId == remote.senderId && loc.message == remote.message));
      if (!exists) {
        localList.add(remote);
      }
    }

    localList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    controller.add(List.unmodifiable(localList));
  }

  Future<bool> sendChatMessage(String conversationId, String content) async {
    final senderId = currentUser?.id ?? 'anonymous';
    final messageId = _generateMessageUuid();
    final createdAt = DateTime.now().toIso8601String();
    final senderName = currentUserName;

    final newMsg = ChatMessage(
      id: messageId,
      senderId: senderId,
      senderName: 'Me',
      senderRole: 'user',
      conversationId: conversationId,
      message: content,
      createdAt: createdAt,
    );

    // 1. Immediately add to local cache and stream so sender UI updates with 0ms latency
    _addAndPushMessage(conversationId, newMsg);

    // 2. Store the plain message content
    final messageContent = content;

    // 3. Broadcast instantly via Supabase WebSocket channel for sub-50ms peer-to-peer delivery
    try {
      RealtimeChannel? channel = _activeChannels[conversationId];
      if (channel == null) {
        channel = client.channel('chat_$conversationId');
        channel.subscribe();
        _activeChannels[conversationId] = channel;
      }
      await channel.sendBroadcastMessage(
        event: 'chat_msg',
        payload: {
          'id': messageId,
          'sender_id': senderId,
          'sender_name': senderName,
          'sender_role': 'user',
          'content': messageContent,
          'plain_content': messageContent,
          'conversation_id': conversationId,
          'created_at': createdAt,
        },
      );
      debugPrint('Realtime broadcast sent for conversation: $conversationId');
    } catch (bcErr) {
      debugPrint('Realtime broadcast notice: $bcErr');
    }

    // 4. Persist plain text to Postgres database for message history
    if (currentUser == null) return true;
    try {
      await client.from('messages').insert({
        'id': messageId,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': messageContent,
        'created_at': createdAt,
      });
      debugPrint('Message persisted to DB: $messageId');
      return true;
    } catch (insertErr) {
      final errStr = insertErr.toString();
      // If conversation FK constraint fails, recreate the conversation row then retry once
      if (errStr.contains('conversation_id') || errStr.contains('foreign key') || errStr.contains('violates')) {
        debugPrint('Conversation FK missing — recreating conversation and retrying message insert...');
        try {
          await getOrCreateDirectConversation(conversationId);
        } catch (_) {}
        try {
          await client.from('messages').insert({
            'id': _generateMessageUuid(),
            'conversation_id': conversationId,
            'sender_id': senderId,
            'content': messageContent,
            'created_at': DateTime.now().toIso8601String(),
          });
          debugPrint('Message persisted after conversation recreation.');
        } catch (retryErr) {
          debugPrint('Message retry notice: $retryErr');
        }
      } else {
        debugPrint('sendChatMessage DB notice: $insertErr');
      }
      return true;
    }
  }

  void closeConversationStream(String conversationId) {
    _streamSubscriptions[conversationId]?.cancel();
    _streamSubscriptions.remove(conversationId);

    final channel = _activeChannels.remove(conversationId);
    if (channel != null) {
      try {
        client.removeChannel(channel);
      } catch (_) {}
    }

    _convStreamControllers[conversationId]?.close();
    _convStreamControllers.remove(conversationId);
  }

  Future<List<ProjectDomainModel>> fetchProjects() async {
    if (currentOrganizationId == null) return [];
    try {
      final response = await client
          .from('projects')
          .select('*, clients(*)')
          .eq('organization_id', currentOrganizationId!);
      return (response as List)
          .where((json) => !_deletedProjectIds.contains(json['id']?.toString()))
          .map((json) => ProjectDomainModel.fromMap(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      return [];
    }
  }

  Future<bool> deleteProject(String projectId) async {
    try {
      _deletedProjectIds.add(projectId);

      try { await client.from('tasks').delete().eq('project_id', projectId); } catch (_) {}
      try { await client.from('invoices').delete().eq('project_id', projectId); } catch (_) {}
      try { await client.from('project_members').delete().eq('project_id', projectId); } catch (_) {}
      try { await client.from('client_requests').delete().eq('project_id', projectId); } catch (_) {}
      try { await client.from('approvals').delete().eq('project_id', projectId); } catch (_) {}
      try { await client.from('conversations').delete().eq('project_id', projectId); } catch (_) {}

      await client.from('projects').delete().eq('id', projectId);
      return true;
    } catch (e) {
      debugPrint('Supabase deleteProject error: $e');
      return false;
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
      return (response as List)
          .where((json) => !_deletedProjectIds.contains(json['project_id']?.toString()))
          .map((json) => TaskDomainModel.fromMap(json))
          .toList();
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

  Future<bool> insertInvoice(InvoiceModel invoice) async {
    if (currentOrganizationId == null) return false;
    try {
      final orgId = currentOrganizationId!;

      // Try to find client_id by matching clientName in AppDataStore first
      String? clientId;
      try {
        final store = AppDataStore();
        final matchedClient = store.clients.cast<ClientModel?>().firstWhere(
              (c) => c?.name.toLowerCase() == invoice.clientName.toLowerCase(),
              orElse: () => store.clients.isNotEmpty ? store.clients.first : null,
            );
        if (matchedClient != null && matchedClient.id.isNotEmpty) {
          clientId = matchedClient.id;
        } else {
          // Fallback: fetch from DB
          final clientResp = await client
              .from('clients')
              .select('id')
              .eq('organization_id', orgId)
              .limit(1)
              .maybeSingle();
          if (clientResp != null) {
            clientId = clientResp['id'].toString();
          }
        }
      } catch (_) {}

      if (clientId == null) {
        debugPrint('insertInvoice: no client found, skipping DB insert');
        return false;
      }

      // Format dates as ISO 8601 (YYYY-MM-DD) for the DATE column
      final now = DateTime.now();
      final issueDateIso =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Parse due date - if already ISO skip, else default to 30 days from now
      String dueDateIso;
      try {
        final parsedDue = DateTime.parse(invoice.dueDate);
        dueDateIso =
            '${parsedDue.year}-${parsedDue.month.toString().padLeft(2, '0')}-${parsedDue.day.toString().padLeft(2, '0')}';
      } catch (_) {
        final due = now.add(const Duration(days: 30));
        dueDateIso =
            '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
      }

      // Do NOT send 'id' -- let Supabase generate the UUID
      await client.from('invoices').insert({
        'organization_id': orgId,
        'client_id': clientId,
        'invoice_number': invoice.invoiceNumber,
        'issue_date': issueDateIso,
        'due_date': dueDateIso,
        'subtotal': invoice.amount,
        'tax': 0.0,
        'total': invoice.amount,
        'status': invoice.status,
      });
      return true;
    } catch (e) {
      debugPrint('Error inserting invoice: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyAssignedConsultationRequests() async {
    try {
      final user = currentUser;
      if (user == null) return [];

      try {
        final res = await client
            .from('client_requests')
            .select('*')
            .or('assigned_employee_id.eq.${user.id},assigned_to.eq.${user.id}')
            .order('created_at', ascending: false);
        if (res.isNotEmpty) {
          return List<Map<String, dynamic>>.from(res);
        }
      } catch (_) {}

      try {
        final res = await client
            .from('consultations')
            .select('*')
            .or('assigned_employee_id.eq.${user.id},assigned_to.eq.${user.id}')
            .order('created_at', ascending: false);
        if (res.isNotEmpty) {
          return List<Map<String, dynamic>>.from(res);
        }
      } catch (_) {}

      return [];
    } catch (e) {
      debugPrint('Error fetching consultation requests: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllConsultationRequests() async {
    try {
      try {
        final res = await client.from('client_requests').select('*').order('created_at', ascending: false);
        if (res.isNotEmpty) {
          return List<Map<String, dynamic>>.from(res);
        }
      } catch (_) {}

      try {
        final res = await client.from('consultations').select('*').order('created_at', ascending: false);
        if (res.isNotEmpty) {
          return List<Map<String, dynamic>>.from(res);
        }
      } catch (_) {}

      return [];
    } catch (e) {
      debugPrint('Error fetching all consultation requests: $e');
      return [];
    }
  }

  Future<bool> acceptConsultationAndConnectClient({
    required String requestId,
    required String clientId,
    required String employeeId,
    required String employeeName,
  }) async {
    try {
      // 1. Update client_requests or consultations status & assignee
      try {
        await client.from('client_requests').update({
          'status': 'Approved',
          'assigned_employee_id': employeeId,
        }).eq('id', requestId);
      } catch (_) {}

      try {
        await client.from('consultations').update({
          'status': 'Approved',
          'assigned_employee_id': employeeId,
        }).eq('id', requestId);
      } catch (_) {}

      // 2. Connect Employee to Client in database
      if (clientId.isNotEmpty) {
        try {
          await client.from('clients').update({
            'assigned_employee_id': employeeId,
            'assigned_employee_name': employeeName,
          }).eq('id', clientId);
        } catch (e) {
          debugPrint('Error connecting employee to client: $e');
        }
      }

      await AppDataStore().refreshFromSupabase();
      return true;
    } catch (e) {
      debugPrint('Error accepting consultation and connecting client: $e');
      return false;
    }
  }

  Future<bool> createConsultationRequest({
    required String clientId,
    required String title,
    required String description,
    String? assignedEmployeeId,
  }) async {
    try {
      final user = currentUser;
      final orgId = currentOrganizationId;
      final payload = {
        if (orgId != null) 'organization_id': orgId,
        if (clientId.isNotEmpty) 'client_id': clientId,
        if (user?.id != null) 'created_by': user!.id,
        'title': title,
        'description': description,
        'status': assignedEmployeeId != null && assignedEmployeeId.isNotEmpty ? 'Approved' : 'Pending',
        if (assignedEmployeeId != null && assignedEmployeeId.isNotEmpty) 'assigned_employee_id': assignedEmployeeId,
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        await client.from('client_requests').insert(payload);
        return true;
      } catch (_) {}

      try {
        await client.from('consultations').insert(payload);
        return true;
      } catch (err) {
        debugPrint('Error inserting into consultations: $err');
        return false;
      }
    } catch (e) {
      debugPrint('Error creating consultation request: $e');
      return false;
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
