import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class InvitationModel {
  final String id;
  final String organizationId;
  final String email;
  final String role; // 'employee' or 'client'
  final String token;
  final String invitedBy;
  final String status; // 'pending', 'accepted', 'expired', 'revoked'
  final DateTime expiresAt;
  final DateTime createdAt;

  InvitationModel({
    required this.id,
    required this.organizationId,
    required this.email,
    required this.role,
    required this.token,
    required this.invitedBy,
    this.status = 'pending',
    required this.expiresAt,
    required this.createdAt,
  });

  factory InvitationModel.fromMap(Map<String, dynamic> map) {
    return InvitationModel(
      id: map['id'] ?? '',
      organizationId: map['organization_id'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'employee',
      token: map['token'] ?? '',
      invitedBy: map['invited_by'] ?? '',
      status: map['status'] ?? 'pending',
      expiresAt: map['expires_at'] != null ? DateTime.parse(map['expires_at']) : DateTime.now().add(const Duration(days: 7)),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organization_id': organizationId,
      'email': email,
      'role': role,
      'token': token,
      'invited_by': invitedBy,
      'status': status,
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}

class InvitationService {
  final SupabaseClient _client = SupabaseService().client;

  /// Generate cryptographically random token string
  String _generateSecureToken() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  /// Create a new employee or client invitation
  Future<InvitationModel?> createInvitation({
    required String email,
    required String role,
  }) async {
    final currentOrg = SupabaseService().currentOrganization;
    final currentUser = SupabaseService().currentUser;
    if (currentOrg == null || currentUser == null) {
      debugPrint('Cannot create invitation: Active organization context missing');
      return null;
    }

    try {
      final token = _generateSecureToken();
      final expiresAt = DateTime.now().add(const Duration(days: 7));

      final response = await _client.from('invitations').insert({
        'organization_id': currentOrg['id'],
        'email': email,
        'role': role,
        'token': token,
        'invited_by': currentUser.id,
        'expires_at': expiresAt.toIso8601String(),
        'status': 'pending',
      }).select().single();

      return InvitationModel.fromMap(response);
    } catch (e) {
      debugPrint('Error creating invitation: $e');
      return null;
    }
  }

  /// Fetch list of all invitations for current active organization
  Future<List<InvitationModel>> fetchInvitations() async {
    final currentOrg = SupabaseService().currentOrganization;
    if (currentOrg == null) return [];

    try {
      final response = await _client
          .from('invitations')
          .select()
          .eq('organization_id', currentOrg['id'])
          .order('created_at', ascending: false);

      return (response as List).map((json) => InvitationModel.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Error fetching invitations: $e');
      return [];
    }
  }

  /// Validate invitation token and return payload
  Future<InvitationModel?> verifyToken(String token) async {
    try {
      final response = await _client
          .from('invitations')
          .select()
          .eq('token', token)
          .eq('status', 'pending')
          .single();

      final invite = InvitationModel.fromMap(response);
      if (invite.expiresAt.isBefore(DateTime.now())) {
        // Token expired
        await _client.from('invitations').update({'status': 'expired'}).eq('id', invite.id);
        return null;
      }
      return invite;
    } catch (e) {
      debugPrint('Error verifying invitation token: $e');
      return null;
    }
  }

  /// Revoke an existing invitation
  Future<bool> revokeInvitation(String invitationId) async {
    try {
      await _client
          .from('invitations')
          .update({'status': 'revoked'})
          .eq('id', invitationId);
      return true;
    } catch (e) {
      debugPrint('Error revoking invitation: $e');
      return false;
    }
  }
}
