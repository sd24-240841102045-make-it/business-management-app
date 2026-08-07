import 'package:flutter/material.dart';
import 'services/app_data_store.dart';

class EmployeesBody extends StatefulWidget {
  final void Function(int index)? onNavigate;
  const EmployeesBody({super.key, this.onNavigate});

  @override
  EmployeesBodyState createState() => EmployeesBodyState();
}

class EmployeesBodyState extends State<EmployeesBody> {
  final AppDataStore _store = AppDataStore();
  String _searchText = '';
  String _selectedDepartment = 'All';
  String _selectedStatus = 'All';

  final List<String> _departments = ['All', 'Human Resources', 'Client Relations', 'Engineering', 'Design', 'Sales', 'Finance'];
  final List<String> _statuses = ['All', 'Active', 'On Leave', 'Inactive'];

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
    final filteredEmployees = _store.employees.where((emp) {
      final matchesSearch = emp.name.toLowerCase().contains(_searchText.toLowerCase()) ||
          emp.role.toLowerCase().contains(_searchText.toLowerCase()) ||
          emp.department.toLowerCase().contains(_searchText.toLowerCase());

      final matchesDept = _selectedDepartment == 'All' || emp.department == _selectedDepartment;
      final matchesStatus = _selectedStatus == 'All' || emp.status == _selectedStatus;

      return matchesSearch && matchesDept && matchesStatus;
    }).toList();

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
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9F43), Color(0xFFFFC048)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.badge, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Human Resource Directory',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_store.employees.length} Total Workforce • ${_store.employees.where((e) => e.status == "Active").length} Active Now',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                  onChanged: (val) => setState(() => _searchText = val),
                  decoration: InputDecoration(
                    hintText: 'Search by employee name, role, or department...',
                    prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Filter Dropdowns Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDepartment,
                            isExpanded: true,
                            icon: const Icon(Icons.filter_list, color: Colors.deepPurple),
                            items: _departments.map((dept) {
                              return DropdownMenuItem(value: dept, child: Text(dept, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedDepartment = val!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatus,
                            isExpanded: true,
                            icon: const Icon(Icons.tune, color: Colors.deepPurple),
                            items: _statuses.map((status) {
                              return DropdownMenuItem(value: status, child: Text(status, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedStatus = val!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // Employee Cards Grid / List
                filteredEmployees.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          children: const [
                            Icon(Icons.people_outline, size: 60, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No employees found matching filter', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 3 : isTablet ? 2 : 1,
                          mainAxisExtent: 220,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredEmployees.length,
                        itemBuilder: (context, index) {
                          final emp = filteredEmployees[index];
                          final assignedClients = _store.clients.where((c) => c.assignedEmployeeId == emp.id).length;

                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
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
                                        emp.name.substring(0, 1),
                                        style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            emp.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            emp.role,
                                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: emp.status == 'Active'
                                            ? Colors.green.withOpacity(0.12)
                                            : Colors.orange.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        emp.status,
                                        style: TextStyle(
                                          color: emp.status == 'Active' ? Colors.green : Colors.orange,
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
                                    const Icon(Icons.business_center_outlined, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(emp.department, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                Row(
                                  children: [
                                    const Icon(Icons.people_alt_outlined, size: 16, color: Colors.deepPurple),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$assignedClients Assigned Client${assignedClients == 1 ? '' : 's'}',
                                      style: const TextStyle(fontSize: 13, color: Colors.deepPurple, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => widget.onNavigate?.call(4),
                                      icon: const Icon(Icons.person_outline, size: 16),
                                      label: const Text('View Profile'),
                                      style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () => _confirmDelete(emp),
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
          ),
        ),
      ),
    );
  },
);
  }

  // Public method called by MainShell's FAB via GlobalKey
  void showAddEmployeeDialog() => _showAddEmployeeDialog();

  void _showAddEmployeeDialog() {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String dept = 'Human Resources';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add HR Employee', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roleController,
                  decoration: const InputDecoration(labelText: 'Job Title / Role', prefixIcon: Icon(Icons.work)),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: dept,
                  decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.domain)),
                  items: ['Human Resources', 'Client Relations', 'Engineering', 'Design', 'Sales', 'Finance']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) => dept = val!,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  final newEmp = Employee(
                    id: 'emp_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameController.text.trim(),
                    role: roleController.text.trim().isEmpty ? 'Employee' : roleController.text.trim(),
                    department: dept,
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim(),
                    status: 'Active',
                    joiningDate: 'Today',
                  );
                  _store.addEmployee(newEmp);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save Employee'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(Employee emp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee?'),
        content: Text('Are you sure you want to remove ${emp.name} from HR directory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _store.deleteEmployee(emp.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
