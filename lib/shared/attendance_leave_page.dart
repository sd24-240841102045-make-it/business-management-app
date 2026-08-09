import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/hr_repository.dart';
import 'package:business_managment_app/services/supabase_service.dart';

class AttendanceLeaveBody extends StatefulWidget {
  const AttendanceLeaveBody({super.key});

  @override
  AttendanceLeaveBodyState createState() => AttendanceLeaveBodyState();
}

class AttendanceLeaveBodyState extends State<AttendanceLeaveBody> {
  final AppDataStore _store = AppDataStore();
  final HRRepository _hrRepo = HRRepository();

  List<AttendanceRecord> _attendanceLogs = [];
  bool _isLoadingLogs = false;
  DateTime? _checkInTime;
  String _searchQuery = '';
  final DateTime _selectedFilterDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() => _isLoadingLogs = true);
    await _store.refreshFromSupabase();
    final logs = await _hrRepo.fetchAttendanceHistory();
    if (mounted) {
      setState(() {
        _attendanceLogs = logs;
        _isLoadingLogs = false;
      });
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _handlePunchAction() async {
    if (_store.isCheckedIn) {
      _store.toggleAttendance();
      if (_attendanceLogs.isNotEmpty && _attendanceLogs.first.checkOut == null) {
        await _hrRepo.checkOut(_attendanceLogs.first.id, _checkInTime ?? DateTime.now());
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Punched Out Successfully!'), backgroundColor: Colors.redAccent),
      );
    } else {
      _store.toggleAttendance();
      _checkInTime = DateTime.now();
      await _hrRepo.checkIn();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Punched In Successfully! Have a great workday!'), backgroundColor: Colors.green),
      );
    }
    _loadAttendanceData();
  }

  void showApplyLeaveDialog() => _showApplyLeaveDialog();

  void _showApplyLeaveDialog() {
    if (_store.employees.isEmpty) return;

    String selectedEmpId = _store.employees.first.id;
    String leaveType = 'Casual';
    final reasonController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 2));
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

    String _fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    String _fmtTime(TimeOfDay t) =>
        '${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickStartDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setDialogState(() => startDate = picked);
            }

            Future<void> pickEndDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                firstDate: startDate,
                lastDate: DateTime(2030),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setDialogState(() => endDate = picked);
            }

            Future<void> pickStartTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: startTime,
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setDialogState(() => startTime = picked);
            }

            Future<void> pickEndTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: endTime,
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setDialogState(() => endTime = picked);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.event_note, color: Colors.deepPurple, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('Apply for Leave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 340,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Employee Selector
                      DropdownButtonFormField<String>(
                        value: selectedEmpId,
                        decoration: InputDecoration(
                          labelText: 'Employee',
                          prefixIcon: const Icon(Icons.person, color: Colors.deepPurple),
                          filled: true,
                          fillColor: Colors.deepPurple.withOpacity(0.04),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: _store.employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                        onChanged: (val) => setDialogState(() => selectedEmpId = val!),
                      ),
                      const SizedBox(height: 12),

                      // Leave Type Selector
                      DropdownButtonFormField<String>(
                        value: leaveType,
                        decoration: InputDecoration(
                          labelText: 'Leave Type',
                          prefixIcon: const Icon(Icons.category, color: Colors.deepPurple),
                          filled: true,
                          fillColor: Colors.deepPurple.withOpacity(0.04),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: ['Casual', 'Sick', 'Annual', 'Unpaid']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) => setDialogState(() => leaveType = val!),
                      ),
                      const SizedBox(height: 16),

                      // ── Start Date & Time ─────────────────────────────
                      Text('Start Date & Time', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: pickStartDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.deepPurple),
                                    const SizedBox(width: 8),
                                    Text(_fmtDate(startDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: pickStartTime,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16, color: Colors.deepPurple),
                                    const SizedBox(width: 8),
                                    Text(_fmtTime(startTime), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── End Date & Time ─────────────────────────────
                      Text('End Date & Time', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: pickEndDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month, size: 16, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(_fmtDate(endDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: pickEndTime,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(_fmtTime(endTime), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Duration summary chip
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timelapse, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              '${endDate.difference(startDate).inDays + 1} day(s) leave duration',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Reason
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Reason for Leave',
                          prefixIcon: const Icon(Icons.notes, color: Colors.deepPurple),
                          filled: true,
                          fillColor: Colors.deepPurple.withOpacity(0.04),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Submit Request'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () {
                    final emp = _store.employees.firstWhere((e) => e.id == selectedEmpId);
                    final newReq = LeaveRequest(
                      id: 'lv_${DateTime.now().millisecondsSinceEpoch}',
                      employeeId: emp.id,
                      employeeName: emp.name,
                      type: leaveType,
                      startDate: '${_fmtDate(startDate)} ${_fmtTime(startTime)}',
                      endDate: '${_fmtDate(endDate)} ${_fmtTime(endTime)}',
                      reason: reasonController.text.trim().isEmpty ? 'General leave request' : reasonController.text.trim(),
                    );
                    _store.addLeaveRequest(newReq);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Leave application submitted successfully!'), backgroundColor: Colors.green),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final currentRole = user != null ? SupabaseService().getUserRole(user) : 'admin';
    final isAdmin = currentRole == 'admin';

    final onLeaveCount = _store.employees.where((e) => e.status == 'On Leave').length;
    final presentCount = _store.employees.length - onLeaveCount;
    final pendingCount = _store.leaveRequests.where((r) => r.status == 'Pending').length;

    final dateStr = "${_selectedFilterDate.day} ${_getMonthAbbr(_selectedFilterDate.month)} ${_selectedFilterDate.year}";

    return RefreshIndicator(
      onRefresh: _loadAttendanceData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: DefaultTabController(
              length: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Daily Attendance Punch Banner (Always Available) ────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _store.isCheckedIn
                            ? [const Color(0xFF10B981), const Color(0xFF059669)]
                            : [const Color(0xFF6C63FF), const Color(0xFF4A148C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: Colors.deepPurple.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Workday Attendance Punch', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _store.isCheckedIn ? 'Checked In' : 'Checked Out',
                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _store.isCheckedIn ? 'Active shift in progress...' : 'Ready to start shift today',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              child: Icon(
                                _store.isCheckedIn ? Icons.check_circle : Icons.timer,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _store.isCheckedIn ? Colors.redAccent : Colors.deepPurple,
                            minimumSize: const Size(double.infinity, 46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          onPressed: _handlePunchAction,
                          icon: Icon(_store.isCheckedIn ? Icons.logout : Icons.login, size: 18),
                          label: Text(
                            _store.isCheckedIn ? 'Punch Out Shift' : 'Punch In Shift Now',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Overflow-Safe Responsive Header Bar ──────────────────────────
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Attendance & Leave Suite', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Live Employee Check-In & Check-Out Times', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.deepPurple.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.deepPurple),
                            const SizedBox(width: 6),
                            Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── KPI Summary Cards Banner ────────────────────────────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isMobile = constraints.maxWidth < 600;
                      return isMobile
                          ? Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _metricCard('Total Staff', '${_store.employees.length}', Colors.deepPurple, Icons.people)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _metricCard('Present', '$presentCount', Colors.green, Icons.how_to_reg)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _metricCard('On Leave', '$onLeaveCount', Colors.blue, Icons.beach_access)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _metricCard('Pending', '$pendingCount', Colors.orange, Icons.pending_actions)),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: _metricCard('Total Staff', '${_store.employees.length}', Colors.deepPurple, Icons.people)),
                                const SizedBox(width: 12),
                                Expanded(child: _metricCard('Present Today', '$presentCount', Colors.green, Icons.how_to_reg)),
                                const SizedBox(width: 12),
                                Expanded(child: _metricCard('On Leave', '$onLeaveCount', Colors.blue, Icons.beach_access)),
                                const SizedBox(width: 12),
                                Expanded(child: _metricCard('Pending Leaves', '$pendingCount', Colors.orange, Icons.pending_actions)),
                              ],
                            );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Tab Bar Navigation ──────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
                    ),
                    child: const TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      labelColor: Colors.deepPurple,
                      indicatorColor: Colors.deepPurple,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(
                          icon: Icon(Icons.people_alt, size: 20),
                          child: FittedBox(child: Text('Staff Roster & Times')),
                        ),
                        Tab(
                          icon: Icon(Icons.event_available, size: 20),
                          child: FittedBox(child: Text('Leave Applications')),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Search Bar ─────────────────────────────────────────
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search employee name or department...',
                      prefixIcon: const Icon(Icons.search, color: Colors.deepPurple, size: 20),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Tab Bar Views ───────────────────────────────────────────────
                  SizedBox(
                    height: 550,
                    child: TabBarView(
                      children: [
                        _buildEmployeeAttendanceRoster(context, dateStr),
                        _buildLeaveApplicationsTab(context, isAdmin),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeAttendanceRoster(BuildContext context, String dateStr) {
    final filteredEmployees = _store.employees.where((e) {
      final q = _searchQuery.toLowerCase();
      return e.name.toLowerCase().contains(q) || e.department.toLowerCase().contains(q) || e.role.toLowerCase().contains(q);
    }).toList();

    if (filteredEmployees.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_outlined, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('No employees found matching your search.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredEmployees.length,
      itemBuilder: (context, index) {
        final emp = filteredEmployees[index];
        final isOnLeave = emp.status == 'On Leave';

        AttendanceRecord? record;
        for (final r in _attendanceLogs) {
          if (r.userId == emp.id || r.id == emp.id) {
            record = r;
            break;
          }
        }

        final checkInDisplay = record != null && record.checkIn.isNotEmpty
            ? (record.checkIn.contains('T') ? record.checkIn.split('T')[1].substring(0, 5) : record.checkIn)
            : (isOnLeave ? 'On Leave' : '09:00 AM');

        final checkOutDisplay = record != null && record.checkOut != null
            ? (record.checkOut!.contains('T') ? record.checkOut!.split('T')[1].substring(0, 5) : record.checkOut!)
            : (isOnLeave ? 'N/A' : '05:30 PM');

        final statusTag = isOnLeave
            ? 'On Leave'
            : (record?.status ?? 'Present (On Time)');

        Color statusColor = Colors.green;
        if (isOnLeave) statusColor = Colors.blue;
        if (statusTag.contains('Late')) statusColor = Colors.orange;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: statusColor.withOpacity(0.15),
                          child: Text(
                            emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  emp.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  statusTag,
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${emp.role} • ${emp.department}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // 100% Overflow-Safe Responsive Time Pills Bar
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.login, size: 14, color: Colors.green),
                          const SizedBox(width: 6),
                          Text('In: $checkInDisplay', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.logout, size: 14, color: Colors.redAccent),
                          const SizedBox(width: 6),
                          Text('Out: $checkOutDisplay', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event, size: 14, color: Colors.deepPurple),
                          const SizedBox(width: 6),
                          Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepPurple)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeaveApplicationsTab(BuildContext context, bool isAdmin) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('Employee Leave Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            if (!isAdmin)
              ElevatedButton.icon(
              onPressed: _showApplyLeaveDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Apply Leave'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _store.leaveRequests.isEmpty
              ? Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: Text('No leave applications recorded.')),
                )
              : ListView.builder(
                  itemCount: _store.leaveRequests.length,
                  itemBuilder: (context, index) {
                    final req = _store.leaveRequests[index];
                    Color statusColor = Colors.orange;
                    if (req.status == 'Approved') statusColor = Colors.green;
                    if (req.status == 'Rejected') statusColor = Colors.red;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(req.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Text(req.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Type: ${req.type} Leave  •  ${req.startDate} to ${req.endDate}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text('Reason: ${req.reason}', style: const TextStyle(fontSize: 12)),
                            if (req.status == 'Pending' && isAdmin) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _store.updateLeaveStatus(req.id, 'Rejected'),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                    child: const Text('Reject', style: TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _store.updateLeaveStatus(req.id, 'Approved'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                                    child: const Text('Approve', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _metricCard(String label, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey))),
        ],
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
