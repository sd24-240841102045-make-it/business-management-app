import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/core/result.dart';
import 'package:business_managment_app/core/pagination.dart';
import 'package:business_managment_app/services/cache_service.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/app_data_store.dart';

// ─────────────────────────────────────────────
// Client Repository (Clean Architecture Layer)
// ─────────────────────────────────────────────
class ClientRepository {
  static final ClientRepository _instance = ClientRepository._();
  factory ClientRepository() => _instance;
  ClientRepository._();

  final SupabaseClient _client = Supabase.instance.client;
  final CacheService _cache = CacheService();

  /// Fetch paginated clients with optional search and employee assignment filter
  Future<Result<PaginatedList<ClientModel>>> getClients({
    required PaginationParams params,
    String? status,
    String? assignedEmployeeId,
    bool forceRefresh = false,
  }) async {
    final orgId = SupabaseService().currentOrganizationId;
    if (orgId == null) {
      return const Result.failure(AuthFailure('No active organization selected'));
    }

    final cacheKey = 'clients_${orgId}_${params.page}_${status ?? 'all'}_${assignedEmployeeId ?? 'all'}';

    if (!forceRefresh) {
      final cached = _cache.getMemory<PaginatedList<ClientModel>>(cacheKey);
      if (cached != null) {
        return Result.success(cached);
      }
    }

    try {
      var query = _client
          .from('clients')
          .select('*')
          .eq('organization_id', orgId);

      if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
        query = query.eq('status', status);
      }
      if (assignedEmployeeId != null && assignedEmployeeId.isNotEmpty) {
        query = query.eq('assigned_employee_id', assignedEmployeeId);
      }
      if (params.searchQuery != null && params.searchQuery!.isNotEmpty) {
        query = query.or('contact_name.ilike.%${params.searchQuery}%,company_name.ilike.%${params.searchQuery}%,email.ilike.%${params.searchQuery}%');
      }

      final response = await query
          .order('created_at', ascending: params.ascending)
          .range(params.rangeFrom, params.rangeTo)
          .count(CountOption.exact);

      final dataList = response.data as List<dynamic>? ?? [];
      final totalCount = response.count;

      final items = dataList.map((row) {
        return ClientModel.fromMap(row as Map<String, dynamic>);
      }).toList();

      final paginated = PaginatedList<ClientModel>(
        items: items,
        page: params.page,
        pageSize: params.pageSize,
        totalCount: totalCount,
        hasMore: (params.offset + items.length) < totalCount,
      );

      _cache.setMemory(cacheKey, paginated, ttl: const Duration(minutes: 5));
      return Result.success(paginated);
    } catch (e) {
      debugPrint('ClientRepository: getClients error: $e');
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  /// Allocate a client lead to an employee
  Future<Result<void>> allocateClient({
    required String clientId,
    required String employeeId,
    required String employeeName,
  }) async {
    try {
      await _client.from('clients').update({
        'assigned_employee_id': employeeId,
        'assigned_employee_name': employeeName,
      }).eq('id', clientId);

      await _cache.clearAll();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }
}
