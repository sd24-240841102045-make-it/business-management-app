import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/hr_repository.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/core/premium_theme.dart';

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
  int _activeTab = 0;
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
    String selectedEmpId = _store.employees.isNotEmpty ? _store.employees.first.id : (SupabaseService().currentUser?.id ?? 'emp_1');
    String selectedEmpName = _store.employees.isNotEmpty ? _store.employees.first.name : 'Staff Member';
    String leaveType = 'Casual';
    final reasonController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 1));
    bool isSubmitting = false;

    String _fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
                    colorScheme: const ColorScheme.dark(
                      primary: kPremiumGold,
                      onPrimary: kPremiumBg,
                      surface: kPremiumSurface,
                      onSurface: kPremiumText,
                    ),
                    dialogBackgroundColor: kPremiumSurface,
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setDialogState(() {
                  startDate = picked;
                  if (endDate.isBefore(startDate)) {
                    endDate = startDate;
                  }
                });
              }
            }

            Future<void> pickEndDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                firstDate: startDate,
                lastDate: DateTime(2030),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: kPremiumGold,
                      onPrimary: kPremiumBg,
                      surface: kPremiumSurface,
                      onSurface: kPremiumText,
                    ),
                    dialogBackgroundColor: kPremiumSurface,
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setDialogState(() => endDate = picked);
            }

            final durationDays = endDate.difference(startDate).inDays + 1;

            return Dialog(
              backgroundColor: kPremiumSurface,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: kPremiumBorder),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kPremiumGold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.event_note, color: kPremiumGold, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Apply for Leave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kPremiumText)),
                                SizedBox(height: 2),
                                Text('Submit a time-off request', style: TextStyle(color: kPremiumMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Employee Selector (if multiple employees available)
                      if (_store.employees.length > 1) ...[
                        DropdownButtonFormField<String>(
                          value: _store.employees.any((e) => e.id == selectedEmpId) ? selectedEmpId : _store.employees.first.id,
                          isExpanded: true,
                          dropdownColor: kPremiumSurface,
                          style: const TextStyle(color: kPremiumText),
                          decoration: InputDecoration(
                            labelText: 'Employee',
                            labelStyle: const TextStyle(color: kPremiumMuted),
                            prefixIcon: const Icon(Icons.person_outlined, color: kPremiumGold),
                            filled: true,
                            fillColor: kPremiumBg.withOpacity(0.6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumGold)),
                          ),
                          items: _store.employees
                              .map((e) => DropdownMenuItem(
                                    value: e.id,
                                    child: Text(
                                      '${e.name} (${e.role.isNotEmpty ? e.role : 'Staff'})',
                                      style: const TextStyle(color: kPremiumText),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedEmpId = val;
                                final found = _store.employees.firstWhere((e) => e.id == val);
                                selectedEmpName = found.name;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Leave Type Selector
                      DropdownButtonFormField<String>(
                        value: leaveType,
                        isExpanded: true,
                        dropdownColor: kPremiumSurface,
                        style: const TextStyle(color: kPremiumText),
                        decoration: InputDecoration(
                          labelText: 'Leave Type',
                          labelStyle: const TextStyle(color: kPremiumMuted),
                          prefixIcon: const Icon(Icons.category_outlined, color: kPremiumGold),
                          filled: true,
                          fillColor: kPremiumBg.withOpacity(0.6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumGold)),
                        ),
                        items: ['Casual', 'Sick', 'Annual', 'Vacation', 'Unpaid', 'Personal', 'Maternity/Paternity']
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t,
                                    style: const TextStyle(color: kPremiumText),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) => setDialogState(() => leaveType = val!),
                      ),
                      const SizedBox(height: 16),

                      // Dates Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Date', style: TextStyle(fontWeight: FontWeight.w600, color: kPremiumMuted, fontSize: 12)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: pickStartDate,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: kPremiumBg.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kPremiumGold.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 16, color: kPremiumGold),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(_fmtDate(startDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPremiumText)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('End Date', style: TextStyle(fontWeight: FontWeight.w600, color: kPremiumMuted, fontSize: 12)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: pickEndDate,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: kPremiumBg.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.event, size: 16, color: Colors.orangeAccent),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(_fmtDate(endDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPremiumText)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Duration summary chip
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timelapse, size: 18, color: Colors.greenAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$durationDays ${durationDays == 1 ? "day" : "days"} leave duration',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Reason
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        style: const TextStyle(color: kPremiumText),
                        decoration: InputDecoration(
                          labelText: 'Reason for Leave',
                          labelStyle: const TextStyle(color: kPremiumMuted),
                          prefixIcon: const Icon(Icons.notes, color: kPremiumGold),
                          filled: true,
                          fillColor: kPremiumBg.withOpacity(0.6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPremiumGold)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: kPremiumMuted)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: isSubmitting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kPremiumBg))
                                : const Icon(Icons.send, size: 16),
                            label: Text(isSubmitting ? 'Submitting...' : 'Submit Request'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPremiumGold,
                              foregroundColor: kPremiumBg,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setDialogState(() => isSubmitting = true);
                                    
                                    final emp = _store.employees.firstWhere(
                                      (e) => e.id == selectedEmpId || e.userId == selectedEmpId,
                                      orElse: () => Employee(id: selectedEmpId, name: selectedEmpName, role: '', department: '', email: '', phone: '', status: '', joiningDate: ''),
                                    );
                                    
                                    final reqUserId = emp.userId.isNotEmpty
                                        ? emp.userId
                                        : (emp.id.startsWith('mem_') ? emp.id.replaceFirst('mem_', '') : emp.id);

                                    final newReq = LeaveRequest(
                                      id: 'lv_${DateTime.now().millisecondsSinceEpoch}',
                                      employeeId: reqUserId,
                                      employeeName: emp.name,
                                      type: leaveType,
                                      startDate: _fmtDate(startDate),
                                      endDate: _fmtDate(endDate),
                                      reason: reasonController.text.trim().isEmpty ? 'General leave request' : reasonController.text.trim(),
                                    );

                                    final success = await _store.addLeaveRequest(newReq);

                                    if (mounted) setState(() {});
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(success ? 'Leave application submitted successfully!' : 'Leave request recorded locally.'),
                                          backgroundColor: success ? Colors.green : Colors.orange,
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 80.0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HeroBanner(
                  title: 'Attendance & Leave Operations',
                  subtitle: 'Real-time punch records, shift tracking, and leave management',
                  badge: 'Workforce Operations',
                ),
                const SizedBox(height: 20),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Workday Attendance Punch', style: TextStyle(color: kPremiumMuted, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(
                                  _store.isCheckedIn ? 'Checked In' : 'Checked Out',
                                  style: const TextStyle(color: kPremiumText, fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _store.isCheckedIn ? 'Active shift in progress...' : 'Ready to start shift today',
                                  style: const TextStyle(color: kPremiumMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          PremiumAvatar(
                            icon: _store.isCheckedIn ? Icons.check_circle_rounded : Icons.timer_outlined,
                            style: AvatarStyle.glowIcon,
                            size: 48,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GoldButton(
                        label: _store.isCheckedIn ? 'Punch Out Shift' : 'Punch In Shift Now',
                        icon: _store.isCheckedIn ? Icons.logout : Icons.login,
                        onPressed: _handlePunchAction,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // -- Overflow-Safe Responsive Header Bar --------------------------
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Attendance & Leave Suite', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPremiumText)),
                        Text('Live Employee Check-In & Check-Out Times', style: TextStyle(color: kPremiumMuted, fontSize: 12)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: kPremiumGold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: kPremiumGold),
                          const SizedBox(width: 6),
                          Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // -- KPI Summary Cards Banner ------------------------------------
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isMobile = constraints.maxWidth < 600;
                    return isMobile
                        ? Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _metricCard('Total Staff', '${_store.employees.length}', kPremiumGold, Icons.people)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _metricCard('Present', '$presentCount', Colors.greenAccent, Icons.how_to_reg)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _metricCard('On Leave', '$onLeaveCount', kPremiumBlue, Icons.beach_access)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _metricCard('Pending', '$pendingCount', Colors.orangeAccent, Icons.pending_actions)),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: _metricCard('Total Staff', '${_store.employees.length}', kPremiumGold, Icons.people)),
                              const SizedBox(width: 12),
                              Expanded(child: _metricCard('Present Today', '$presentCount', Colors.greenAccent, Icons.how_to_reg)),
                              const SizedBox(width: 12),
                              Expanded(child: _metricCard('On Leave', '$onLeaveCount', kPremiumBlue, Icons.beach_access)),
                              const SizedBox(width: 12),
                              Expanded(child: _metricCard('Pending Leaves', '$pendingCount', Colors.orangeAccent, Icons.pending_actions)),
                            ],
                          );
                  },
                ),

                const SizedBox(height: 24),

                // -- Interactive Tab Selector ------------------------------------------
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeTab = 0),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _activeTab == 0 ? kPremiumGold.withOpacity(0.15) : kPremiumSurface.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _activeTab == 0 ? kPremiumGold : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_alt, size: 18, color: _activeTab == 0 ? kPremiumGold : kPremiumMuted),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Staff Roster & Times',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _activeTab == 0 ? kPremiumGold : kPremiumText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeTab = 1),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _activeTab == 1 ? kPremiumGold.withOpacity(0.15) : kPremiumSurface.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _activeTab == 1 ? kPremiumGold : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_available, size: 18, color: _activeTab == 1 ? kPremiumGold : kPremiumMuted),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Leave Applications',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _activeTab == 1 ? kPremiumGold : kPremiumText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (_activeTab == 0) ...[
                  // -- Search Bar -----------------------------------------
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: kPremiumText),
                    decoration: InputDecoration(
                      hintText: 'Search employee name or department...',
                      hintStyle: const TextStyle(color: kPremiumMuted),
                      prefixIcon: const Icon(Icons.search, color: kPremiumGold, size: 20),
                      filled: true,
                      fillColor: kPremiumSurface.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPremiumGold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEmployeeAttendanceRoster(context, dateStr),
                ] else ...[
                  _buildLeaveApplicationsTab(context, isAdmin),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeAttendanceRoster(BuildContext context, String dateStr) {
    if (_isLoadingLogs) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: kPremiumGold)));
    }
    final filteredEmployees = _store.employees.where((e) {
      final q = _searchQuery.toLowerCase();
      return e.name.toLowerCase().contains(q) || e.department.toLowerCase().contains(q) || e.role.toLowerCase().contains(q);
    }).toList();

    if (filteredEmployees.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(30),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_outlined, size: 40, color: kPremiumMuted),
              SizedBox(height: 8),
              Text('No employees found matching your search.', style: TextStyle(color: kPremiumMuted, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
            ? (record.checkIn.contains('T') ? (record.checkIn.split('T')[1].length >= 5 ? record.checkIn.split('T')[1].substring(0, 5) : record.checkIn.split('T')[1]) : record.checkIn)
            : (isOnLeave ? 'On Leave' : '09:00 AM');

        final checkOutDisplay = record != null && record.checkOut != null
            ? (record.checkOut!.contains('T') ? (record.checkOut!.split('T')[1].length >= 5 ? record.checkOut!.split('T')[1].substring(0, 5) : record.checkOut!.split('T')[1]) : record.checkOut!)
            : (isOnLeave ? 'N/A' : '05:30 PM');

        final statusTag = isOnLeave
            ? 'On Leave'
            : (record?.status ?? 'Present (On Time)');

        Color statusColor = Colors.greenAccent;
        if (isOnLeave) statusColor = kPremiumBlue;
        if (statusTag.contains('Late')) statusColor = Colors.orangeAccent;

        return GlassCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PremiumAvatar(
                    label: emp.name,
                    style: AvatarStyle.gradient,
                    size: 40,
                    radius: 20,
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kPremiumText),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  statusTag,
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${emp.role} \u2022 ${emp.department}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: kPremiumMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16, color: Colors.white10),

              // Overflow-Safe Time Pills Bar
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.login, size: 14, color: Colors.greenAccent),
                        const SizedBox(width: 6),
                        Text('In: $checkInDisplay', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.greenAccent)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
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
                      color: kPremiumGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event, size: 14, color: kPremiumGold),
                        const SizedBox(width: 6),
                        Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kPremiumGold)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaveApplicationsTab(BuildContext context, bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Text('Employee Leave Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPremiumGold)),
            if (!isAdmin)
              GoldButton(
                label: 'Apply Leave',
                icon: Icons.add,
                onPressed: _showApplyLeaveDialog,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _store.leaveRequests.isEmpty
            ? GlassCard(
                padding: const EdgeInsets.all(30),
                child: const Center(
                  child: Text('No leave applications recorded.', style: TextStyle(color: kPremiumMuted)),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _store.leaveRequests.length,
                itemBuilder: (context, index) {
                  final req = _store.leaveRequests[index];
                  Color statusColor = Colors.orangeAccent;
                  if (req.status == 'Approved') statusColor = Colors.greenAccent;
                  if (req.status == 'Rejected') statusColor = Colors.redAccent;

                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(req.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPremiumText), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(req.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Type: ${req.type} Leave  \u2022  ${req.startDate} to ${req.endDate}',
                          style: const TextStyle(fontSize: 12, color: kPremiumMuted),
                          softWrap: true,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reason: ${req.reason}',
                          style: const TextStyle(fontSize: 12, color: kPremiumMuted),
                          softWrap: true,
                        ),
                        if (req.status == 'Pending' && isAdmin) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => _store.updateLeaveStatus(req.id, 'Rejected'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _store.updateLeaveStatus(req.id, 'Approved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _metricCard(String label, String count, Color color, IconData icon) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: kPremiumMuted))),
        ],
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
