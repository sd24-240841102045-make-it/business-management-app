import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saas_models.dart';
import 'supabase_service.dart';

class ProjectRepository {
  final SupabaseClient _client = SupabaseService().client;

  /// Fetch all projects belonging to the active organization
  Future<List<ProjectDomainModel>> fetchProjects() async {
    final currentOrg = SupabaseService().currentOrganization;
    if (currentOrg == null) return [];

    try {
      final response = await _client
          .from('projects')
          .select('*, clients(*)')
          .eq('organization_id', currentOrg['id'])
          .order('created_at', ascending: false);

      return (response as List).map((json) => ProjectDomainModel.fromMap(json)).toList();
    } catch (e) {
      debugPrint('ProjectRepository.fetchProjects error: $e');
      return [];
    }
  }

  /// Create a new project workspace
  Future<bool> createProject({
    required String name,
    required String clientId,
    String? description,
    double budget = 0.0,
    String? deadline,
  }) async {
    final currentOrg = SupabaseService().currentOrganization;
    final currentUser = SupabaseService().currentUser;
    if (currentOrg == null || currentUser == null) return false;

    try {
      await _client.from('projects').insert({
        'organization_id': currentOrg['id'],
        'client_id': clientId,
        'manager_id': currentUser.id,
        'name': name,
        'description': description,
        'status': 'In Progress',
        'health': 'On Track',
        'budget': budget,
        'start_date': DateTime.now().toIso8601String().split('T')[0],
        'deadline': deadline ?? DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0],
      });
      return true;
    } catch (e) {
      debugPrint('ProjectRepository.createProject error: $e');
      return false;
    }
  }

  /// Update project status (e.g. In Progress, Completed, On Hold)
  Future<bool> updateProjectStatus(String projectId, String status) async {
    try {
      await _client.from('projects').update({'status': status}).eq('id', projectId);
      return true;
    } catch (e) {
      debugPrint('ProjectRepository.updateProjectStatus error: $e');
      return false;
    }
  }

  /// Assign employee team member to project
  Future<bool> addProjectMember(String projectId, String userId, {String role = 'member'}) async {
    try {
      await _client.from('project_members').insert({
        'project_id': projectId,
        'user_id': userId,
        'role_in_project': role,
      });
      return true;
    } catch (e) {
      debugPrint('ProjectRepository.addProjectMember error: $e');
      return false;
    }
  }

  /// Create client deliverable approval request
  Future<bool> submitDeliverableForApproval(DeliverableApprovalModel approval) async {
    final currentOrg = SupabaseService().currentOrganization;
    if (currentOrg == null) return false;

    try {
      await _client.from('approvals').insert({
        'organization_id': currentOrg['id'],
        'project_id': approval.projectId,
        'task_id': approval.taskId,
        'title': approval.title,
        'description': approval.description,
        'deliverable_url': approval.deliverableUrl,
        'requested_by': approval.requestedBy,
        'status': 'Pending',
      });
      return true;
    } catch (e) {
      debugPrint('ProjectRepository.submitDeliverableForApproval error: $e');
      return false;
    }
  }

  /// Update deliverable approval status (e.g. Approved, Changes Requested)
  Future<bool> updateApprovalStatus(String approvalId, String status, {String? feedback}) async {
    final currentUser = SupabaseService().currentUser;
    try {
      await _client.from('approvals').update({
        'status': status,
        'feedback': feedback,
        'approver_id': currentUser?.id,
        'decided_at': DateTime.now().toIso8601String(),
      }).eq('id', approvalId);
      return true;
    } catch (e) {
      debugPrint('ProjectRepository.updateApprovalStatus error: $e');
      return false;
    }
  }
}
