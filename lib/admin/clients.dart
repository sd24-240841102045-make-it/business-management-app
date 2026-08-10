import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/admin/edit_clients.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class ClientsBody extends StatefulWidget {
  const ClientsBody({super.key});

  @override
  ClientsBodyState createState() => ClientsBodyState();
}

class ClientsBodyState extends State<ClientsBody> {
  final AppDataStore _store = AppDataStore();
  String searchText = '';

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
    final filteredClients = _store.clients.where((client) {
      final name = client.name.toLowerCase();
      final company = client.company.toLowerCase();
      final empLead = (client.assignedEmployeeName ?? '').toLowerCase();
      final query = searchText.toLowerCase();

      return name.contains(query) || company.contains(query) || empLead.contains(query);
    }).toList();

    final activeClientsCount = _store.clients.where((c) => c.status == 'Active').length;

    return LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          final bool isDesktop = width >= 900;
          final bool isTablet = width >= 600 && width < 900;
          final double horizontalPadding = isDesktop ? 40 : isTablet ? 30 : 20;

          return RefreshIndicator(
            onRefresh: () async {
              await _store.refreshFromSupabase();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 80.0,
              ),
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
                HeroBanner(
                  title: 'Client CRM Directory',
                  subtitle: '${_store.clients.length} Total Accounts • $activeClientsCount Active Partners',
                  badge: 'CRM Directory',
                ),

                const SizedBox(height: 20),

                // Search Bar
                TextField(
                  onChanged: (value) => setState(() => searchText = value),
                  decoration: InputDecoration(
                    hintText: 'Search by client, company, or assigned HR lead...',
                    prefixIcon: Icon(Icons.search, color: kPremiumGold),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),

                const SizedBox(height: 20),

                // Client List / Grid
                filteredClients.isEmpty
                    ? GlassCard(
                        padding: const EdgeInsets.all(30),
                        child: const Center(
                          child: Text('No matching clients found', style: TextStyle(color: kPremiumMuted)),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 2 : 1,
                          mainAxisExtent: 200,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = filteredClients[index];

                          return FadeInSlide(
                            delay: Duration(milliseconds: 50 * (index % 6)),
                            child: GlassCard(
                              margin: EdgeInsets.zero,
                              padding: const EdgeInsets.all(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ClientProfilePage(client: client),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    PremiumAvatar(
                                      label: client.name,
                                      style: AvatarStyle.gradient,
                                      size: 44,
                                      radius: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            client.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kPremiumText),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            client.company,
                                            style: const TextStyle(color: kPremiumMuted, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: client.status == 'Active' ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: client.status == 'Active' ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        client.status,
                                        style: TextStyle(
                                          color: client.status == 'Active' ? Colors.greenAccent : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: kPremiumMuted, size: 18),
                                      onPressed: () => _editClient(client),
                                      tooltip: 'Edit Client',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                      onPressed: () => _confirmDeleteClient(client),
                                      tooltip: 'Delete Client',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),

                                const Divider(height: 18, color: Colors.white10),

                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined, size: 15, color: kPremiumMuted),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(client.email, style: const TextStyle(fontSize: 12, color: kPremiumMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 15, color: kPremiumMuted),
                                    const SizedBox(width: 6),
                                    Text(client.phone, style: const TextStyle(fontSize: 12, color: kPremiumMuted)),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // HR Employee Assignment Lead Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: kPremiumGold.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.badge, size: 15, color: kPremiumGold),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'HR Lead: ${client.assignedEmployeeName ?? "Unassigned"}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: kPremiumGold,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _showAssignEmployeeModal(client),
                                        child: const Text(
                                          'Change',
                                          style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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

  void _showClientPortalConfigModal(ClientModel client) {
    bool showProjects = client.showProjects;
    bool showTasks = client.showTasks;
    bool showInvoices = client.showInvoices;
    bool showTimesheets = client.showTimesheets;
    bool allowChat = client.allowChat;
    final noteController = TextEditingController(text: client.adminNote);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: kPremiumSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
              title: Row(
                children: [
                  const Icon(Icons.tune, color: kPremiumGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Portal Visibility: ${client.company.isNotEmpty ? client.company : client.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPremiumGold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configure what data & features this client can access in their Client Portal:',
                      style: TextStyle(fontSize: 12, color: kPremiumMuted),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Show Projects & Progress', style: TextStyle(fontSize: 14, color: kPremiumText, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Allow client to view project status & deadlines', style: TextStyle(fontSize: 11, color: kPremiumMuted)),
                      value: showProjects,
                      activeColor: kPremiumGold,
                      onChanged: (val) => setModalState(() => showProjects = val),
                    ),
                    SwitchListTile(
                      title: const Text('Show Deliverables & Approvals', style: TextStyle(fontSize: 14, color: kPremiumText, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Allow client to review & approve task deliverables', style: TextStyle(fontSize: 11, color: kPremiumMuted)),
                      value: showTasks,
                      activeColor: kPremiumGold,
                      onChanged: (val) => setModalState(() => showTasks = val),
                    ),
                    SwitchListTile(
                      title: const Text('Show Invoices & Payments', style: TextStyle(fontSize: 14, color: kPremiumText, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Allow client to view invoices & record payments', style: TextStyle(fontSize: 11, color: kPremiumMuted)),
                      value: showInvoices,
                      activeColor: kPremiumGold,
                      onChanged: (val) => setModalState(() => showInvoices = val),
                    ),
                    SwitchListTile(
                      title: const Text('Show Timesheets / Hours Worked', style: TextStyle(fontSize: 14, color: kPremiumText, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Allow client to view team hours spent on projects', style: TextStyle(fontSize: 11, color: kPremiumMuted)),
                      value: showTimesheets,
                      activeColor: kPremiumGold,
                      onChanged: (val) => setModalState(() => showTimesheets = val),
                    ),
                    SwitchListTile(
                      title: const Text('Enable Support Chat', style: TextStyle(fontSize: 14, color: kPremiumText, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Allow client to message project manager', style: TextStyle(fontSize: 11, color: kPremiumMuted)),
                      value: allowChat,
                      activeColor: kPremiumGold,
                      onChanged: (val) => setModalState(() => allowChat = val),
                    ),
                    const SizedBox(height: 12),
                    const Text('Admin Announcement for Client Dashboard:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kPremiumGold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      style: const TextStyle(color: kPremiumText),
                      decoration: InputDecoration(
                        hintText: 'e.g. Welcome! Please review the Q3 Deliverable approval above.',
                        hintStyle: const TextStyle(color: kPremiumMuted),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                        filled: true,
                        fillColor: Colors.black26,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: kPremiumMuted))),
                GoldButton(
                  label: 'Save Controls',
                  icon: Icons.save,
                  onPressed: () {
                    final updated = client.copyWith(
                      showProjects: showProjects,
                      showTasks: showTasks,
                      showInvoices: showInvoices,
                      showTimesheets: showTimesheets,
                      allowChat: allowChat,
                      adminNote: noteController.text.trim(),
                    );
                    _store.updateClient(updated);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Client portal visibility rules updated!'), backgroundColor: Colors.green),
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

  // Public method called by MainShell's FAB via GlobalKey
  void showAddClientDialog() => _showAddClientDialog();

  void _showAssignEmployeeModal(ClientModel client) {
    String? selectedEmpId = client.assignedEmployeeId;
    // Prevent Flutter dropdown assertion crash (line 1852) if assigned employee ID no longer exists in directory
    if (selectedEmpId != null && !_store.employees.any((e) => e.id == selectedEmpId)) {
      selectedEmpId = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: kPremiumSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
              title: Row(
                children: [
                  const Icon(Icons.badge_outlined, color: kPremiumGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assign HR Lead: ${client.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: kPremiumGold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select an employee from your HR directory to manage this client account:',
                    style: TextStyle(color: kPremiumMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: selectedEmpId,
                        dropdownColor: kPremiumSurface,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: kPremiumGold),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Unassigned (No HR Lead)', style: TextStyle(color: kPremiumMuted, fontWeight: FontWeight.w600)),
                          ),
                          ..._store.employees.map((emp) {
                            return DropdownMenuItem<String?>(
                              value: emp.id,
                              child: Text('${emp.name} (${emp.role})', style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.bold)),
                            );
                          }),
                        ],
                        onChanged: (val) => setModalState(() => selectedEmpId = val),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: kPremiumMuted)),
                ),
                GoldButton(
                  label: 'Save Assignment',
                  icon: Icons.check_circle_outline,
                  onPressed: () {
                    _store.assignEmployeeToClient(client.id, selectedEmpId);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('HR Lead assignment saved successfully'),
                        backgroundColor: Colors.green,
                      ),
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

  void _confirmDeleteClient(ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kPremiumSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.white10)),
        title: const Text('Delete Client?', style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${client.name}? This will remove all associated project records.', style: const TextStyle(color: kPremiumText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kPremiumMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _store.deleteClient(client.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Client ${client.name} deleted successfully'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddClientDialog() {
    final nameController = TextEditingController();
    final companyController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String? empId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (empId != null && !_store.employees.any((e) => e.id == empId)) {
              empId = null;
            }

            return AlertDialog(
              backgroundColor: kPremiumSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
              title: const Text('Add New Client', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: kPremiumText),
                      decoration: const InputDecoration(
                        labelText: 'Client Name',
                        labelStyle: TextStyle(color: kPremiumMuted),
                        prefixIcon: Icon(Icons.person_outline, color: kPremiumGold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: companyController,
                      style: const TextStyle(color: kPremiumText),
                      decoration: const InputDecoration(
                        labelText: 'Company Name',
                        labelStyle: TextStyle(color: kPremiumMuted),
                        prefixIcon: Icon(Icons.business_outlined, color: kPremiumGold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: kPremiumText),
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: TextStyle(color: kPremiumMuted),
                        prefixIcon: Icon(Icons.email_outlined, color: kPremiumGold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      style: const TextStyle(color: kPremiumText),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: TextStyle(color: kPremiumMuted),
                        prefixIcon: Icon(Icons.phone_outlined, color: kPremiumGold),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: empId,
                          dropdownColor: kPremiumSurface,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: kPremiumGold),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Unassigned HR Lead', style: TextStyle(color: kPremiumMuted))),
                            ..._store.employees.map((e) => DropdownMenuItem<String?>(
                              value: e.id,
                              child: Text(e.name, style: const TextStyle(color: kPremiumText, fontWeight: FontWeight.bold)),
                            )),
                          ],
                          onChanged: (val) => setDialogState(() => empId = val),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: kPremiumMuted)),
                ),
                GoldButton(
                  label: 'Add Client',
                  icon: Icons.person_add_outlined,
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      String? empName;
                      if (empId != null) {
                        final found = _store.employees.where((e) => e.id == empId);
                        if (found.isNotEmpty) {
                          empName = found.first.name;
                        }
                      }
                      _store.addClient(ClientModel(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text.trim(),
                        company: companyController.text.trim().isNotEmpty ? companyController.text.trim() : 'Company',
                        email: emailController.text.trim(),
                        phone: phoneController.text.trim(),
                        status: 'Active',
                        assignedEmployeeId: empId,
                        assignedEmployeeName: empName,
                      ));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New client added successfully'), backgroundColor: Colors.green),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editClient(ClientModel client) async {
    final clientMap = {
      'name': client.name,
      'company': client.company,
      'email': client.email,
      'phone': client.phone,
      'status': client.status,
    };

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => EditClientPage(client: clientMap)),
    );

    if (result != null) {
      final updated = client.copyWith(
        name: result['name'],
        company: result['company'],
        email: result['email'],
        phone: result['phone'],
        status: result['status'],
      );
      _store.updateClient(updated);
    }
  }
}

class ClientProfilePage extends StatefulWidget {
  final ClientModel client;
  const ClientProfilePage({super.key, required this.client});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  final AppDataStore _store = AppDataStore();
  late ClientModel _currentClient;

  @override
  void initState() {
    super.initState();
    _currentClient = widget.client;
    _store.addListener(_onStoreUpdate);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) {
      for (final c in _store.clients) {
        if (c.id == _currentClient.id) {
          setState(() {
            _currentClient = c;
          });
          break;
        }
      }
    }
  }

  Future<void> _editClientProfile() async {
    final clientMap = {
      'name': _currentClient.name,
      'company': _currentClient.company,
      'email': _currentClient.email,
      'phone': _currentClient.phone,
      'status': _currentClient.status,
    };

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => EditClientPage(client: clientMap)),
    );

    if (result != null) {
      final updated = _currentClient.copyWith(
        name: result['name'],
        company: result['company'],
        email: result['email'],
        phone: result['phone'],
        status: result['status'],
      );
      _store.updateClient(updated);
      setState(() {
        _currentClient = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = _currentClient.status == 'Active' ? Colors.greenAccent : Colors.orangeAccent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('${_currentClient.name}\'s Profile', style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
        backgroundColor: kPremiumBg,
        foregroundColor: kPremiumGold,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: kPremiumGold),
            tooltip: 'Edit Client Details',
            onPressed: _editClientProfile,
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).padding.bottom + 80.0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Profile Card
                  SizedBox(
                    width: double.infinity,
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PremiumAvatar(
                            label: _currentClient.name,
                            style: AvatarStyle.gradient,
                            size: 80,
                            radius: 40,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _currentClient.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPremiumText),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentClient.company,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: kPremiumGold, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              'Account Status: ${_currentClient.status}',
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GoldButton(
                            label: 'Edit Client Details',
                            icon: Icons.edit,
                            onPressed: _editClientProfile,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account Information
                  const Text('Client Account Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPremiumGold)),
                  const SizedBox(height: 12),
                  _buildInfoCard(Icons.fingerprint, 'Client ID', _currentClient.id),
                  _buildInfoCard(Icons.person_outline, 'Primary Contact', _currentClient.name),
                  _buildInfoCard(Icons.business_outlined, 'Company / Organization', _currentClient.company),
                  _buildInfoCard(Icons.email_outlined, 'Email Address', _currentClient.email),
                  _buildInfoCard(Icons.phone_outlined, 'Direct Phone', _currentClient.phone.isNotEmpty ? _currentClient.phone : 'Not provided'),
                  _buildInfoCard(Icons.assignment_outlined, 'Project Scope', _currentClient.projectType ?? 'Enterprise Consulting'),
                  _buildInfoCard(Icons.account_balance_wallet_outlined, 'Allocated Budget', '\$${(_currentClient.budget ?? 12500).toStringAsFixed(0)}'),

                  const SizedBox(height: 24),

                  // Assigned HR Account Lead
                  const Text('Assigned Account Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPremiumGold)),
                  const SizedBox(height: 12),
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const PremiumAvatar(
                          icon: Icons.badge,
                          style: AvatarStyle.glowIcon,
                          size: 40,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentClient.assignedEmployeeName ?? 'Unassigned HR Lead',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPremiumText),
                              ),
                              const SizedBox(height: 2),
                              const Text('Account Manager & HR Contact', style: TextStyle(fontSize: 12, color: kPremiumMuted)),
                            ],
                          ),
                        ),
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

  Widget _buildInfoCard(IconData icon, String title, String value) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          PremiumAvatar(
            icon: icon,
            style: AvatarStyle.glowIcon,
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: kPremiumMuted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kPremiumText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
