import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AttendanceRecord {
  final String id;
  final String userId;
  final String date;
  final String checkIn;
  final String? checkOut;
  final double totalHours;
  final String status; // 'On Time', 'Late', 'Half Day', 'Absent'

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.checkIn,
    this.checkOut,
    this.totalHours = 0.0,
    this.status = 'On Time',
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      date: map['date'] ?? '',
      checkIn: map['check_in'] ?? '',
      checkOut: map['check_out'],
      totalHours: (map['total_hours'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'On Time',
    );
  }
}

class HRRepository {
  final SupabaseClient _client = SupabaseService().client;

  /// Check in employee attendance for today
  Future<bool> checkIn() async {
    final currentOrg = SupabaseService().currentOrganization;
    final currentUser = SupabaseService().currentUser;
    if (currentOrg == null || currentUser == null) return false;

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      await _client.from('attendance').upsert({
        'organization_id': currentOrg.id,
        'user_id': currentUser.id,
        'date': today,
        'check_in': DateTime.now().toIso8601String(),
        'status': DateTime.now().hour > 10 ? 'Late' : 'On Time',
      });
      return true;
    } catch (e) {
      debugPrint('HRRepository.checkIn error: $e');
      return false;
    }
  }

  /// Check out employee attendance for today
  Future<bool> checkOut(String recordId, DateTime checkInTime) async {
    try {
      final now = DateTime.now();
      final hours = now.difference(checkInTime).inMinutes / 60.0;

      await _client.from('attendance').update({
        'check_out': now.toIso8601String(),
        'total_hours': hours,
      }).eq('id', recordId);
      return true;
    } catch (e) {
      debugPrint('HRRepository.checkOut error: $e');
      return false;
    }
  }

  /// Fetch user attendance history
  Future<List<AttendanceRecord>> fetchAttendanceHistory() async {
    final currentOrg = SupabaseService().currentOrganization;
    final currentUser = SupabaseService().currentUser;
    if (currentOrg == null || currentUser == null) return [];

    try {
      final response = await _client
          .from('attendance')
          .select()
          .eq('organization_id', currentOrg.id)
          .eq('user_id', currentUser.id)
          .order('date', ascending: false);

      return (response as List).map((json) => AttendanceRecord.fromMap(json)).toList();
    } catch (e) {
      debugPrint('HRRepository.fetchAttendanceHistory error: $e');
      return [];
    }
  }

  /// Log timesheet hours worked against a task/project
  Future<bool> logTimesheet({
    required String projectId,
    String? taskId,
    required double hours,
    String? description,
  }) async {
    final currentOrg = SupabaseService().currentOrganization;
    final currentUser = SupabaseService().currentUser;
    if (currentOrg == null || currentUser == null) return false;

    try {
      await _client.from('timesheets').insert({
        'organization_id': currentOrg.id,
        'user_id': currentUser.id,
        'project_id': projectId,
        'task_id': taskId,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'hours': hours,
        'description': description,
      });
      return true;
    } catch (e) {
      debugPrint('HRRepository.logTimesheet error: $e');
      return false;
    }
  }
}
