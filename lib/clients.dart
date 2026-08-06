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

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Client Overview',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_store.clients.length} Total Clients • $activeClientsCount Active Accounts',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
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
                          mainAxisExtent: 260,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = filteredClients[index];

                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.deepPurple.shade50,
                                      child: Text(
                                        client.name.substring(0, 1),
                                        style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            client.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                          ),
                                          Text(
                                            client.company,
                                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: client.status == 'Active' ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        client.status,
                                        style: TextStyle(
                                          color: client.status == 'Active' ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const Divider(height: 24),

                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(client.email, style: const TextStyle(fontSize: 13))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(client.phone, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // HR Employee Assignment Lead Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.badge, size: 16, color: Colors.deepPurple),
                                          const SizedBox(width: 8),
                                          Text(
                                            'HR Lead: ${client.assignedEmployeeName ?? "Unassigned"}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.deepPurple,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      InkWell(
                                        onTap: () => _showAssignEmployeeModal(client),
                                        child: const Text(
                                          'Change',
                                          style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Spacer(),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.deepPurple),
                                      onPressed: () => _editClient(client),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _store.deleteClient(client.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
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
