import 'package:flutter/material.dart';
import 'services/app_data_store.dart';
import 'edit_clients.dart';

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
                // Header Stat Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8E7CFF)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.people_alt, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Client Overview',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${_store.clients.length} Total Clients • $activeClientsCount Active Accounts',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Search Bar
                TextField(
                  onChanged: (value) => setState(() => searchText = value),
                  decoration: InputDecoration(
                    hintText: 'Search by client, company, or assigned HR lead...',
                    prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Client List / Grid
                filteredClients.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: const Center(
                          child: Text('No matching clients found', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 2 : 1,
                          mainAxisExtent: 175,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = filteredClients[index];

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ClientProfilePage(client: client),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.deepPurple.shade50,
                                        child: Text(
                                          client.name.isNotEmpty ? client.name[0].toUpperCase() : 'C',
                                          style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              client.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              client.company,
                                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: client.status == 'Active' ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          client.status,
                                          style: TextStyle(
                                            color: client.status == 'Active' ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.deepPurple, size: 18),
                                        onPressed: () => _editClient(client),
                                        tooltip: 'Edit Client',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                        onPressed: () => _store.deleteClient(client.id),
                                        tooltip: 'Delete Client',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),

                                  const Divider(height: 18),

                                  Row(
                                    children: [
                                      const Icon(Icons.email_outlined, size: 15, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(client.email, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 15, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(client.phone, style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // HR Employee Assignment Lead Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(Icons.badge, size: 15, color: Colors.deepPurple),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'HR Lead: ${client.assignedEmployeeName ?? "Unassigned"}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.deepPurple,
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
                                            style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 11),
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

  // Public method called by MainShell's FAB via GlobalKey
  void showAddClientDialog() => _showAddClientDialog();

  void _showAssignEmployeeModal(ClientModel client) {
    String? selectedEmpId = client.assignedEmployeeId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Assign HR Lead for ${client.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select an employee from your HR directory to manage this client account:'),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String?>(
                    value: selectedEmpId,
                    decoration: const InputDecoration(labelText: 'Assigned HR Lead', prefixIcon: Icon(Icons.badge)),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                      ..._store.employees.map((emp) {
                        return DropdownMenuItem<String?>(
                          value: emp.id,
                          child: Text('${emp.name} (${emp.role})'),
                        );
                      }),
                    ],
                    onChanged: (val) => setModalState(() => selectedEmpId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: () {
                    _store.assignEmployeeToClient(client.id, selectedEmpId);
                    Navigator.pop(context);
                  },
                  child: const Text('Save Assignment'),
                ),
              ],
            );
          },
        );
      },
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
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add New Client', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Client Name', prefixIcon: Icon(Icons.person))),
                const SizedBox(height: 10),
                TextField(controller: companyController, decoration: const InputDecoration(labelText: 'Company Name', prefixIcon: Icon(Icons.business))),
                const SizedBox(height: 10),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email))),
                const SizedBox(height: 10),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: empId,
                  decoration: const InputDecoration(labelText: 'Assign HR Account Lead', prefixIcon: Icon(Icons.badge)),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                    ..._store.employees.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name))),
                  ],
                  onChanged: (val) => empId = val,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  String? empName;
                  if (empId != null) {
                    empName = _store.employees.firstWhere((e) => e.id == empId).name;
                  }
                  final newClient = ClientModel(
                    id: 'cli_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameController.text.trim(),
                    company: companyController.text.trim(),
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim(),
                    status: 'Active',
                    assignedEmployeeId: empId,
                    assignedEmployeeName: empName,
                  );
                  _store.addClient(newClient);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Client'),
            ),
          ],
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
    Color statusColor = _currentClient.status == 'Active' ? Colors.green : Colors.orange;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentClient.name}\'s Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Client Details',
            onPressed: _editClientProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Profile Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.deepPurple.shade100,
                        child: Text(
                          _currentClient.name.isNotEmpty ? _currentClient.name[0].toUpperCase() : 'C',
                          style: const TextStyle(fontSize: 36, color: Colors.deepPurple, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _currentClient.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentClient.company,
                        style: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Account Status: ${_currentClient.status}',
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _editClientProfile,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Client Info'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Account Information
                const Text('Client Account Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                const Text('Assigned Account Lead', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFEDE7F6),
                        child: Icon(Icons.badge, color: Colors.deepPurple),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentClient.assignedEmployeeName ?? 'Unassigned HR Lead',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            const Text('Account Manager & HR Contact', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.deepPurple.withOpacity(0.08),
            child: Icon(icon, color: Colors.deepPurple, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
