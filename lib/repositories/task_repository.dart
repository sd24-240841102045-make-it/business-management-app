import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/core/result.dart';
import 'package:business_managment_app/core/pagination.dart';
import 'package:business_managment_app/services/cache_service.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/app_data_store.dart';

// ─────────────────────────────────────────────
// Task Repository (Clean Architecture Layer)
// ─────────────────────────────────────────────
class TaskRepository {
  static final TaskRepository _instance = TaskRepository._();
  factory TaskRepository() => _instance;
  TaskRepository._();

  final SupabaseClient _client = Supabase.instance.client;
  final CacheService _cache = CacheService();

  /// Fetch paginated tasks with optional status and assignee filters
  Future<Result<PaginatedList<TaskModel>>> getTasks({
    required PaginationParams params,
    String? status,
    String? assignedTo,
    String? projectId,
    bool forceRefresh = false,
  }) async {
    final orgId = SupabaseService().currentOrganizationId;
    if (orgId == null) {
      return const Result.failure(AuthFailure('No active organization selected'));
    }

    final cacheKey = 'tasks_${orgId}_${params.page}_${status ?? 'all'}_${assignedTo ?? 'all'}';

    // 1. Check memory cache unless forceRefresh
    if (!forceRefresh) {
      final cached = _cache.getMemory<PaginatedList<TaskModel>>(cacheKey);
      if (cached != null) {
        return Result.success(cached);
      }
    }

    try {
      var query = _client
          .from('tasks')
          .select('*, assignee:employees!assigned_to(*)')
          .eq('organization_id', orgId);

      if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
        query = query.eq('status', status);
      }
      if (assignedTo != null && assignedTo.isNotEmpty) {
        query = query.eq('assigned_to', assignedTo);
      }
      if (projectId != null && projectId.isNotEmpty) {
        query = query.eq('project_id', projectId);
      }
      if (params.searchQuery != null && params.searchQuery!.isNotEmpty) {
        query = query.ilike('title', '%${params.searchQuery}%');
      }

      final response = await query
          .order('created_at', ascending: params.ascending)
          .range(params.rangeFrom, params.rangeTo)
          .count(CountOption.exact);

      final dataList = response.data as List<dynamic>? ?? [];
      final totalCount = response.count;

      final items = dataList.map((row) {
        final map = row as Map<String, dynamic>;
        final assignee = map['assignee'] is Map ? map['assignee'] as Map<String, dynamic> : null;
        return TaskModel(
          id: map['id']?.toString() ?? '',
          title: map['title']?.toString() ?? '',
          projectId: map['project_id']?.toString() ?? '',
          projectName: 'General Work',
          assignedToId: map['assigned_to']?.toString() ?? '',
          assignedToName: assignee?['name']?.toString() ?? 'Unassigned',
          status: map['status']?.toString() ?? 'To Do',
          priority: map['priority']?.toString() ?? 'Medium',
          dueDate: map['due_date']?.toString() ?? '',
        );
      }).toList();

      final paginated = PaginatedList<TaskModel>(
        items: items,
        page: params.page,
        pageSize: params.pageSize,
        totalCount: totalCount,
        hasMore: (params.offset + items.length) < totalCount,
      );

      _cache.setMemory(cacheKey, paginated, ttl: const Duration(minutes: 5));
      return Result.success(paginated);
    } catch (e) {
      debugPrint('TaskRepository: getTasks error: $e');
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  /// Create a new task and invalidate cached queries
  Future<Result<TaskModel>> createTask({
    required String title,
    required String projectId,
    required String assignedTo,
    required String priority,
    required String dueDate,
    String status = 'To Do',
  }) async {
    final orgId = SupabaseService().currentOrganizationId;
    if (orgId == null) {
      return const Result.failure(AuthFailure('No active organization'));
    }

    try {
      final res = await _client.from('tasks').insert({
        'organization_id': orgId,
        'title': title,
        'project_id': projectId,
        'assigned_to': assignedTo,
        'priority': priority,
        'due_date': dueDate,
        'status': status,
      }).select().single();

      final task = TaskModel(
        id: res['id']?.toString() ?? '',
        title: title,
        projectId: projectId,
        projectName: 'General Work',
        assignedToId: assignedTo,
        assignedToName: 'Assigned',
        status: status,
        priority: priority,
        dueDate: dueDate,
      );

      await _cache.clearAll();
      return Result.success(task);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  /// Update task status
  Future<Result<void>> updateStatus(String taskId, String newStatus) async {
    try {
      await _client
          .from('tasks')
          .update({'status': newStatus})
          .eq('id', taskId);

      await _cache.clearAll();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }
}
