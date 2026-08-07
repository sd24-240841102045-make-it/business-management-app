import 'package:flutter/material.dart';
import 'services/app_data_store.dart';

class AttendanceLeaveBody extends StatefulWidget {
  const AttendanceLeaveBody({super.key});

  @override
  AttendanceLeaveBodyState createState() => AttendanceLeaveBodyState();
}

class AttendanceLeaveBodyState extends State<AttendanceLeaveBody> {
  final AppDataStore _store = AppDataStore();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _store.leaveRequests.where((r) => r.status == 'Pending').length;
    final onLeaveCount = _store.employees.where((e) => e.status == 'On Leave').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isMobile = width < 550;
        final bool isDesktop = width >= 900;
        final bool isTablet = width >= 600 && width < 900;
        final double horizontalPadding = isDesktop ? 40 : isTablet ? 30 : (isMobile ? 12 : 20);

        return RefreshIndicator(
          onRefresh: () async {
            await _store.refreshFromSupabase();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_store.isLoadingFromSupabase) ...[
                      const LinearProgressIndicator(color: Colors.deepPurple),
                      const SizedBox(height: 10),
                    ],

                    // Attendance Punch Card Banner
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _store.isCheckedIn
                              ? [const Color(0xFF10B981), const Color(0xFF059669)]
                              : [const Color(0xFF6C63FF), const Color(0xFF8E7CFF)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
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
                                    const Text(
                                      'Daily Attendance Punch',
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _store.isCheckedIn ? 'Checked In' : 'Checked Out',
                                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _store.isCheckedIn ? Icons.check_circle : Icons.access_time_filled,
                                color: Colors.white,
                                size: isMobile ? 32 : 40,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _store.isCheckedIn ? Colors.redAccent : Colors.deepPurple,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => _store.toggleAttendance(),
                            icon: Icon(_store.isCheckedIn ? Icons.logout : Icons.login),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _store.isCheckedIn ? 'Punch Out Now' : 'Punch In Now',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Metrics Row - Responsive Layout
                    if (isMobile) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _metricCard('Pending Requests', '$pendingCount', Colors.orange, Icons.pending_actions),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metricCard('Staff On Leave', '$onLeaveCount', Colors.blue, Icons.beach_access),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _metricCard('Total Requests', '${_store.leaveRequests.length}', Colors.green, Icons.assignment),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _metricCard('Pending Requests', '$pendingCount', Colors.orange, Icons.pending_actions),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricCard('Staff On Leave', '$onLeaveCount', Colors.blue, Icons.beach_access),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricCard('Total Requests', '${_store.leaveRequests.length}', Colors.green, Icons.assignment),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 30),

                    // Section Title + Apply Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Leave Applications',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _showApplyLeaveDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Apply Leave'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Leave Request Cards List
                    _store.leaveRequests.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                            child: const Center(
                              child: Text('No leave applications recorded.', style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _store.leaveRequests.length,
                            itemBuilder: (context, index) {
                              final req = _store.leaveRequests[index];

                              Color statusColor = Colors.orange;
                              if (req.status == 'Approved') statusColor = Colors.green;
                              if (req.status == 'Rejected') statusColor = Colors.red;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: Colors.deepPurple.shade50,
                                                child: Text(
                                                  req.employeeName.isNotEmpty ? req.employeeName[0].toUpperCase() : 'L',
                                                  style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      req.employeeName,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Type: ${req.type} Leave',
                                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            req.status,
                                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Duration: ${req.startDate} to ${req.endDate}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Reason: ${req.reason}',
                                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                                    ),
                                    if (req.status == 'Pending') ...[
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () => _store.updateLeaveStatus(req.id, 'Rejected'),
                                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                            child: const Text('Reject'),
                                          ),
                                          const SizedBox(width: 10),
                                          ElevatedButton(
                                            onPressed: () => _store.updateLeaveStatus(req.id, 'Approved'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Approve'),
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Public method called by MainShell's FAB via GlobalKey
  void showApplyLeaveDialog() => _showApplyLeaveDialog();

  Widget _metricCard(String label, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showApplyLeaveDialog() {
    if (_store.employees.isEmpty) return;

    String selectedEmpId = _store.employees.first.id;
    String leaveType = 'Casual';
    final reasonController = TextEditingController();
    final startDateController = TextEditingController(text: '10 Aug 2026');
    final endDateController = TextEditingController(text: '12 Aug 2026');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Apply for Leave', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedEmpId,
                  decoration: const InputDecoration(labelText: 'Employee', prefixIcon: Icon(Icons.person)),
                  items: _store.employees.map((e) {
                    return DropdownMenuItem(value: e.id, child: Text(e.name));
                  }).toList(),
                  onChanged: (val) => selectedEmpId = val!,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: leaveType,
                  decoration: const InputDecoration(labelText: 'Leave Type', prefixIcon: Icon(Icons.category)),
                  items: ['Casual', 'Sick', 'Annual', 'Unpaid']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) => leaveType = val!,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: startDateController,
                  decoration: const InputDecoration(labelText: 'Start Date', prefixIcon: Icon(Icons.calendar_today)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: endDateController,
                  decoration: const InputDecoration(labelText: 'End Date', prefixIcon: Icon(Icons.calendar_month)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Reason for Leave', prefixIcon: Icon(Icons.notes)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              onPressed: () {
                final emp = _store.employees.firstWhere((e) => e.id == selectedEmpId);
                final newReq = LeaveRequest(
                  id: 'lv_${DateTime.now().millisecondsSinceEpoch}',
                  employeeId: emp.id,
                  employeeName: emp.name,
                  type: leaveType,
                  startDate: startDateController.text,
                  endDate: endDateController.text,
                  reason: reasonController.text.trim().isEmpty ? 'General leave request' : reasonController.text.trim(),
                );
                _store.addLeaveRequest(newReq);
                Navigator.pop(context);
              },
              child: const Text('Submit Request'),
            ),
          ],
        );
      },
    );
  }
}
