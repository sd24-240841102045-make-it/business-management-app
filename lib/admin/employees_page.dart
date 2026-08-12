import 'package:flutter/material.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/employee/emp_profile.dart';
import 'package:business_managment_app/shared/chat_page.dart';
import 'package:business_managment_app/core/premium_theme.dart';

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
                        const LinearProgressIndicator(color: kPremiumGold),
                        const SizedBox(height: 10),
                      ],
                HeroBanner(
                  title: 'Human Resource Directory',
                  subtitle: '${_store.employees.length} Total Workforce • ${_store.employees.where((e) => e.status == "Active").length} Active Now',
                  badge: 'HR Directory',
                ),

                const SizedBox(height: 20),

                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _searchText = val),
                  decoration: InputDecoration(
                    hintText: 'Search by employee name, role, or department...',
                    prefixIcon: Icon(Icons.search, color: kPremiumGold),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),

                const SizedBox(height: 15),

                // Filter Dropdowns Row
                Row(
                  children: [
                    Expanded(
                      child: GlassCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDepartment,
                            isExpanded: true,
                            dropdownColor: kPremiumSurface,
                            icon: const Icon(Icons.filter_list, color: kPremiumGold),
                            items: _departments.map((dept) {
                              return DropdownMenuItem(value: dept, child: Text(dept, style: const TextStyle(fontSize: 13, color: kPremiumText)));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedDepartment = val!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatus,
                            isExpanded: true,
                            dropdownColor: kPremiumSurface,
                            icon: const Icon(Icons.tune, color: kPremiumGold),
                            items: _statuses.map((status) {
                              return DropdownMenuItem(value: status, child: Text(status, style: const TextStyle(fontSize: 13, color: kPremiumText)));
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
                    ? GlassCard(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: const [
                            Icon(Icons.people_outline, size: 60, color: kPremiumMuted),
                            SizedBox(height: 12),
                            Text('No employees found matching filter', style: TextStyle(color: kPremiumMuted, fontSize: 16)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 3 : isTablet ? 2 : 1,
                          mainAxisExtent: 135,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filteredEmployees.length,
                        itemBuilder: (context, index) {
                          final emp = filteredEmployees[index];
                          final assignedClients = _store.clients.where((c) => c.assignedEmployeeId == emp.id).length;

                          return FadeInSlide(
                            delay: Duration(milliseconds: 50 * (index % 6)),
                            child: GlassCard(
                              margin: EdgeInsets.zero,
                              padding: const EdgeInsets.all(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EmployeeProfilePage(employee: emp),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      PremiumAvatar(
                                        label: emp.name,
                                        style: AvatarStyle.gradient,
                                        size: 38,
                                        radius: 19,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              emp.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kPremiumText),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${emp.role} • ${emp.department}',
                                              style: const TextStyle(color: kPremiumMuted, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: emp.status == 'Active'
                                              ? Colors.green.withOpacity(0.15)
                                              : Colors.orange.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: emp.status == 'Active' ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          emp.status,
                                          style: TextStyle(
                                            color: emp.status == 'Active' ? Colors.greenAccent : Colors.orangeAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  const Divider(height: 1, color: Colors.white10),
                                  const SizedBox(height: 8),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.people_alt_outlined, size: 14, color: kPremiumGold),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$assignedClients Client${assignedClients == 1 ? '' : 's'}',
                                            style: const TextStyle(fontSize: 12, color: kPremiumGold, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.chat_bubble_outline, color: kPremiumGold, size: 18),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ChatPage(
                                                    initialTargetId: emp.userId.isNotEmpty ? emp.userId : emp.id,
                                                    initialTargetName: emp.name,
                                                    initialTargetSubtitle: '${emp.role} • ${emp.department}',
                                                    initialTargetType: 'employee',
                                                    initialTargetEmail: emp.email,
                                                    initialTargetPhone: emp.phone,
                                                  ),
                                                ),
                                              );
                                            },
                                            tooltip: 'Message Employee',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                            onPressed: () => _confirmDelete(emp),
                                            tooltip: 'Delete Employee',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                          ),
                                        ],
                                      ),
                                    ],
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
              style: ElevatedButton.styleFrom(backgroundColor: kPremiumGold, foregroundColor: kPremiumBg),
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
        backgroundColor: kPremiumSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.white10)),
        title: const Text('Delete Employee?', style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove ${emp.name} from the HR directory?', style: const TextStyle(color: kPremiumText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: kPremiumMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _store.deleteEmployee(emp.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Employee ${emp.name} deleted successfully'),
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
}
