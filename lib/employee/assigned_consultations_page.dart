import 'package:flutter/material.dart';
import 'package:business_managment_app/core/premium_theme.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';

class AssignedConsultationsPage extends StatefulWidget {
  const AssignedConsultationsPage({super.key});

  @override
  State<AssignedConsultationsPage> createState() => _AssignedConsultationsPageState();
}

class _AssignedConsultationsPageState extends State<AssignedConsultationsPage> {
  final AppDataStore _store = AppDataStore();
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    await _store.refreshFromSupabase();

    final role = SupabaseService().currentRole;
    final bool isAdmin = role == 'admin' || role == 'owner';

    List<Map<String, dynamic>> requests = [];
    if (isAdmin) {
      requests = await SupabaseService().fetchAllConsultationRequests();
    } else {
      requests = await SupabaseService().fetchMyAssignedConsultationRequests();
    }

    if (mounted) {
      setState(() {
        _requests = requests;
        _loading = false;
      });
    }
  }

  Future<void> _showCreateConsultationDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    String? selectedClientId = _store.clients.isNotEmpty ? _store.clients.first.id : null;
    String? selectedEmployeeId;
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final validClientId = _store.clients.any((c) => c.id == selectedClientId)
              ? selectedClientId
              : (_store.clients.isNotEmpty ? _store.clients.first.id : null);

          final validEmployeeId = _store.employees.any((e) => e.id == selectedEmployeeId)
              ? selectedEmployeeId
              : null;

          return SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: kPremiumGold, width: 1.5)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: kPremiumGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.assignment_ind_outlined, color: kPremiumGold, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request Client Consultation',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPremiumText),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Submit request to connect assigned staff leads & advisory',
                                style: TextStyle(fontSize: 12, color: kPremiumMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),

                    const Text('Select Client Partner *', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: validClientId,
                          hint: const Text('Select Client', style: TextStyle(color: kPremiumMuted, fontSize: 13)),
                          dropdownColor: const Color(0xFF1E293B),
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: kPremiumGold),
                          items: _store.clients.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.id,
                              child: Text('${c.name} • ${c.company}', style: const TextStyle(color: kPremiumText, fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedClientId = val),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text('Consultation Subject / Title *', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: kPremiumText),
                      decoration: InputDecoration(
                        hintText: 'e.g. Enterprise Architecture Review',
                        hintStyle: const TextStyle(color: kPremiumMuted, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: kPremiumGold.withOpacity(0.3))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: kPremiumGold.withOpacity(0.3))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPremiumGold, width: 1.5)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text('Request Details / Objectives', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: kPremiumText),
                      decoration: InputDecoration(
                        hintText: 'Describe key goals, timeline requirements, or technical scope...',
                        hintStyle: const TextStyle(color: kPremiumMuted, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: kPremiumGold.withOpacity(0.3))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: kPremiumGold.withOpacity(0.3))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPremiumGold, width: 1.5)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text('Assign Staff Lead (Optional)', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: validEmployeeId,
                          hint: const Text('Unassigned (Pending Admin Review)', style: TextStyle(color: kPremiumMuted, fontSize: 13)),
                          dropdownColor: const Color(0xFF1E293B),
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: kPremiumGold),
                          items: _store.employees.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.id,
                              child: Text('${e.name} (${e.role})', style: const TextStyle(color: kPremiumText, fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedEmployeeId = val),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kPremiumMuted,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GoldButton(
                            label: isSaving ? 'Submitting...' : 'Submit Request',
                            icon: Icons.send_rounded,
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final title = titleCtrl.text.trim();
                                    final desc = descCtrl.text.trim();
                                    if (title.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please enter a consultation subject title.')),
                                      );
                                      return;
                                    }

                                    setModalState(() => isSaving = true);
                                    final success = await SupabaseService().createConsultationRequest(
                                      clientId: validClientId ?? '',
                                      title: title,
                                      description: desc.isNotEmpty ? desc : 'Consultation requested for executive evaluation.',
                                      assignedEmployeeId: validEmployeeId,
                                    );

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(success ? 'Consultation request created successfully!' : 'Failed to create request.'),
                                          backgroundColor: success ? Colors.green : Colors.redAccent,
                                        ),
                                      );
                                      _loadRequests();
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _acceptAndConnectClientDialog(Map<String, dynamic> request) async {
    final clientId = request['client_id']?.toString() ?? '';
    final requestId = request['id']?.toString() ?? '';

    final clients = _store.clients.where((c) => c.id == clientId);
    final client = clients.isEmpty ? null : clients.first;

    String? selectedEmployeeId = _store.employees.isNotEmpty ? _store.employees.first.id : null;

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final validEmployeeId = _store.employees.any((e) => e.id == selectedEmployeeId)
              ? selectedEmployeeId
              : (_store.employees.isNotEmpty ? _store.employees.first.id : null);

          return SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: kPremiumGold, width: 1.5)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.link_rounded, color: Colors.greenAccent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Accept & Connect Staff Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPremiumText)),
                            SizedBox(height: 2),
                            Text('Bind assigned employee to client account profile in database', style: TextStyle(fontSize: 12, color: kPremiumMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 14),

                  GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Client: ${client?.name ?? 'Client Partner'} (${client?.company ?? ''})', style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Request: ${request['title'] ?? 'Consultation Request'}', style: const TextStyle(color: kPremiumText, fontSize: 13)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Text('Select Employee Lead to Connect *', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: validEmployeeId,
                        hint: const Text('Select Employee Lead', style: TextStyle(color: kPremiumMuted, fontSize: 13)),
                        dropdownColor: const Color(0xFF1E293B),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: kPremiumGold),
                        items: _store.employees.map((e) {
                          return DropdownMenuItem<String>(
                            value: e.id,
                            child: Text('${e.name} (${e.role})', style: const TextStyle(color: kPremiumText, fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedEmployeeId = val),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPremiumMuted,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: GoldButton(
                          label: 'Accept & Connect',
                          icon: Icons.check_circle_outline,
                          onPressed: validEmployeeId == null ? null : () => Navigator.pop(context, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (confirm == true && selectedEmployeeId != null) {
      final selectedEmpList = _store.employees.where((e) => e.id == selectedEmployeeId);
      final selectedEmp = selectedEmpList.isNotEmpty ? selectedEmpList.first : null;

      if (selectedEmp != null) {
        setState(() => _loading = true);
        final success = await SupabaseService().acceptConsultationAndConnectClient(
          requestId: requestId,
          clientId: clientId,
          employeeId: selectedEmp.id,
          employeeName: selectedEmp.name,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Consultation accepted! Employee ${selectedEmp.name} is now connected to client.' : 'Failed to connect client.'),
              backgroundColor: success ? Colors.green : Colors.redAccent,
            ),
          );
          _loadRequests();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = SupabaseService().currentRole;
    final bool isAdmin = role == 'admin' || role == 'owner';

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Assigned Consultations'),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: kPremiumGold),
              tooltip: 'New Consultation Request',
              onPressed: _showCreateConsultationDialog,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: kPremiumGold,
          foregroundColor: kPremiumBg,
          icon: const Icon(Icons.add),
          label: const Text('New Request', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _showCreateConsultationDialog,
        ),
        body: SafeArea(
          bottom: true,
          child: RefreshIndicator(
            onRefresh: _loadRequests,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                HeroBanner(
                  title: isAdmin ? 'Client Consultations Management' : 'My Client Consultations',
                  subtitle: '${_requests.length} consultation request${_requests.length == 1 ? '' : 's'}',
                  badge: isAdmin ? 'ADMIN' : 'EMPLOYEE',
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: kPremiumGold)))
                else if (_requests.isEmpty)
                  GlassCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const Icon(Icons.assignment_ind_outlined, size: 48, color: kPremiumMuted),
                        const SizedBox(height: 14),
                        const Text(
                          'No Consultation Requests Recorded',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPremiumText),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Create a new client consultation request to assign employee leads and manage advisory sessions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kPremiumMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        GoldButton(
                          label: 'Request First Consultation',
                          icon: Icons.add,
                          onPressed: _showCreateConsultationDialog,
                        ),
                      ],
                    ),
                  )
                else
                  ..._requests.map((request) {
                    final clientId = request['client_id']?.toString() ?? '';
                    final clients = _store.clients.where((client) => client.id == clientId);
                    final client = clients.isEmpty ? null : clients.first;
                    final status = request['status']?.toString() ?? 'Pending';
                    final assignedEmpId = request['assigned_employee_id']?.toString() ?? '';
                    final matchingEmps = _store.employees.where((e) => e.id == assignedEmpId || e.userId == assignedEmpId);
                    final assignedEmp = matchingEmps.isEmpty ? null : matchingEmps.first;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    request['title']?.toString() ?? 'Consultation Request',
                                    style: const TextStyle(color: kPremiumGold, fontSize: 16, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status == 'Approved' ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: status == 'Approved' ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(color: status == 'Approved' ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              client == null ? 'Client account' : '${client.name} • ${client.company}',
                              style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            if (assignedEmp != null) ...[
                              const SizedBox(height: 4),
                              Text('Assigned Lead: ${assignedEmp.name} (${assignedEmp.role})', style: const TextStyle(color: kPremiumGold, fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                            const SizedBox(height: 8),
                            Text(request['description']?.toString() ?? 'Client consultation request submitted for review.', style: const TextStyle(color: kPremiumMuted, fontSize: 13)),
                            if (isAdmin || status == 'Pending') ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.link_rounded, size: 18),
                                  label: Text(status == 'Approved' ? 'Re-assign / Connect Employee' : 'Accept & Connect Employee to Client'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kPremiumGold,
                                    side: BorderSide(color: kPremiumGold.withOpacity(0.5)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () => _acceptAndConnectClientDialog(request),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
