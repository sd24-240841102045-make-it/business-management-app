import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/shared/login_page.dart';
import 'package:business_managment_app/shared/settings_page.dart';
import 'package:business_managment_app/core/premium_theme.dart';

class ProfileBody extends StatefulWidget {
  const ProfileBody({super.key});

  @override
  State<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<ProfileBody> {
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

  void _editProfileDialog(User user, Employee? emp) {
    final nameCtrl = TextEditingController(text: user.userMetadata?['full_name'] ?? emp?.name ?? 'Admin User');
    final phoneCtrl = TextEditingController(text: user.userMetadata?['phone'] ?? emp?.phone ?? '+1 555-0100');
    final deptCtrl = TextEditingController(text: emp?.department ?? 'Management');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Admin Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deptCtrl,
                decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.business_center)),
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
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newPhone = phoneCtrl.text.trim();
              final newDept = deptCtrl.text.trim();

              if (newName.isNotEmpty) {
                // Update Supabase Auth user metadata
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(
                      data: {
                        'full_name': newName,
                        'phone': newPhone,
                      },
                    ),
                  );
                } catch (e) {
                  debugPrint('Error updating auth metadata: $e');
                }

                // Update employee record if exists
                if (emp != null) {
                  final updatedEmp = emp.copyWith(
                    name: newName,
                    phone: newPhone,
                    department: newDept,
                  );
                  _store.updateEmployee(updatedEmp);
                } else {
                  final newEmp = Employee(
                    id: user.id,
                    name: newName,
                    role: 'Administrator',
                    department: newDept,
                    email: user.email ?? '',
                    phone: newPhone,
                    status: 'Active',
                    joiningDate: DateTime.now().toString().split(' ')[0],
                  );
                  _store.addEmployee(newEmp);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully in Supabase!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userEmail = user?.email ?? 'Not Logged In';
    final metaName = user?.userMetadata?['full_name']?.toString() ?? '';
    final metaRole = user?.userMetadata?['role']?.toString().toUpperCase() ?? 'ADMINISTRATOR';

    // Match with employee in store
    Employee? matchingEmp;
    for (final e in _store.employees) {
      if (e.email.toLowerCase() == userEmail.toLowerCase() || e.id == user?.id) {
        matchingEmp = e;
        break;
      }
    }

    final userName = matchingEmp?.name ??
        (metaName.isNotEmpty ? metaName : (userEmail.contains('@') ? userEmail.split('@')[0] : 'Admin User'));
    final userRole = matchingEmp?.role.toUpperCase() ?? metaRole;
    final empPhone = matchingEmp?.phone ?? user?.userMetadata?['phone']?.toString() ?? 'Contact Not Provided';
    final empDept = matchingEmp?.department ?? 'Executive Management';

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
                  children: [
                // Profile Header Banner
                SizedBox(
                  width: double.infinity,
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PremiumAvatar(
                          label: userName,
                          style: AvatarStyle.gradient,
                          size: 80,
                          radius: 40,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          userName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: kPremiumText,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: kPremiumGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                          ),
                          child: Text(
                            '$userRole • $empDept',
                            style: const TextStyle(
                              color: kPremiumGold,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        GoldButton(
                          label: 'Edit Profile',
                          icon: Icons.edit,
                          onPressed: () => user != null ? _editProfileDialog(user, matchingEmp) : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // Business & Account Info
                _sectionTitle('Admin Profile Details'),
                const SizedBox(height: 10),

                _infoTile(
                  icon: Icons.business,
                  title: 'Organization',
                  subtitle: 'Project Life Solutions',
                ),
                _infoTile(
                  icon: Icons.email,
                  title: 'Email Address',
                  subtitle: userEmail,
                ),
                _infoTile(
                  icon: Icons.phone,
                  title: 'Phone',
                  subtitle: empPhone,
                ),
                _infoTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Supabase Authentication Status',
                  subtitle: 'Authenticated Active Session',
                ),

                const SizedBox(height: 25),

                // Action Controls
                _sectionTitle('App & Sync Settings'),
                const SizedBox(height: 10),

                _settingTile(
                  icon: Icons.settings_outlined,
                  title: 'Application Settings & Preferences',
                  subtitle: 'Theme, notifications, currency, security',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsPage()),
                    );
                  },
                ),

                _settingTile(
                  icon: Icons.refresh,
                  title: 'Sync Supabase Database',
                  subtitle: _store.isLoadingFromSupabase ? 'Syncing...' : 'Pull latest remote records',
                  onTap: () async {
                    await _store.refreshFromSupabase();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Database synced with Supabase!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                ),

                _settingTile(
                  icon: Icons.security,
                  title: 'Password & Security',
                  subtitle: 'Reset password via Supabase Auth',
                  onTap: () async {
                    try {
                      await SupabaseService().resetPassword(userEmail);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Password reset email sent to $userEmail')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),

                const SizedBox(height: 25),

                // Logout
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await SupabaseService().signOut();
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Logout',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  },
);
  }

  static Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPremiumGold),
      ),
    );
  }

  static Widget _infoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: kPremiumMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ListTile(
        leading: PremiumAvatar(
          icon: icon,
          style: AvatarStyle.glowIcon,
          size: 40,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
        subtitle: Text(subtitle, style: const TextStyle(color: kPremiumMuted)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: kPremiumGold),
      ),
    );
  }
}

class EmployeeProfilePage extends StatefulWidget {
  final Employee employee;
  const EmployeeProfilePage({super.key, required this.employee});

  @override
  State<EmployeeProfilePage> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends State<EmployeeProfilePage> {
  final AppDataStore _store = AppDataStore();
  late Employee _currentEmp;

  @override
  void initState() {
    super.initState();
    _currentEmp = widget.employee;
    _store.addListener(_onStoreUpdate);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) {
      for (final e in _store.employees) {
        if (e.id == _currentEmp.id) {
          setState(() {
            _currentEmp = e;
          });
          break;
        }
      }
    }
  }

  void _editEmployeeDialog() {
    final nameCtrl = TextEditingController(text: _currentEmp.name);
    final roleCtrl = TextEditingController(text: _currentEmp.role);
    final deptCtrl = TextEditingController(text: _currentEmp.department);
    final phoneCtrl = TextEditingController(text: _currentEmp.phone);
    String status = _currentEmp.status;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Edit ${_currentEmp.name}\'s Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(labelText: 'Role / Designation', prefixIcon: Icon(Icons.badge)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: deptCtrl,
                decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.business_center)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (context, setDialogState) => DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.check_circle)),
                  items: ['Active', 'On Leave', 'Inactive']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => status = val);
                    }
                  },
                ),
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
            onPressed: () {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                final updated = _currentEmp.copyWith(
                  name: newName,
                  role: roleCtrl.text.trim(),
                  department: deptCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  status: status,
                );
                _store.updateEmployee(updated);
                setState(() {
                  _currentEmp = updated;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${updated.name}\'s profile updated successfully!'), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignedClients = _store.clients.where((c) => c.assignedEmployeeId == _currentEmp.id).toList();
    final leaveHistory = _store.leaveRequests.where((r) => r.employeeId == _currentEmp.id).toList();

    Color statusColor = Colors.green;
    if (_currentEmp.status == 'On Leave') statusColor = Colors.orange;
    if (_currentEmp.status == 'Inactive') statusColor = Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentEmp.name}\'s Profile', style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
        backgroundColor: kPremiumBg,
        foregroundColor: kPremiumGold,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: kPremiumGold),
            tooltip: 'Edit Profile',
            onPressed: _editEmployeeDialog,
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
                          label: _currentEmp.name,
                          style: AvatarStyle.gradient,
                          size: 80,
                          radius: 40,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _currentEmp.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPremiumText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_currentEmp.role} • ${_currentEmp.department}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kPremiumMuted, fontWeight: FontWeight.w600, fontSize: 14),
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
                            'Status: ${_currentEmp.status}',
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GoldButton(
                          label: 'Edit Employee Details',
                          icon: Icons.edit,
                          onPressed: _editEmployeeDialog,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Personal & Work Information
                const Text('Workforce Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPremiumGold)),
                const SizedBox(height: 12),
                _buildInfoCard(Icons.fingerprint, 'Employee ID', _currentEmp.id),
                _buildInfoCard(Icons.email_outlined, 'Email Address', _currentEmp.email),
                _buildInfoCard(Icons.phone_outlined, 'Direct Phone', _currentEmp.phone.isNotEmpty ? _currentEmp.phone : 'Not provided'),
                _buildInfoCard(Icons.business_center_outlined, 'Department', _currentEmp.department),
                _buildInfoCard(Icons.badge_outlined, 'Role / Designation', _currentEmp.role),
                _buildInfoCard(Icons.calendar_today_outlined, 'Joining Date', _currentEmp.joiningDate),

                const SizedBox(height: 24),

                // Assigned Client Accounts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Assigned Client Accounts (${assignedClients.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPremiumGold)),
                  ],
                ),
                const SizedBox(height: 12),
                assignedClients.isEmpty
                    ? GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: const Text('No clients currently assigned to this employee.', style: TextStyle(color: kPremiumMuted)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: assignedClients.length,
                        itemBuilder: (context, index) {
                          final c = assignedClients[index];
                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: PremiumAvatar(
                                icon: Icons.business,
                                style: AvatarStyle.glowIcon,
                                size: 40,
                              ),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                              subtitle: Text(c.company, style: const TextStyle(color: kPremiumMuted)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.status == 'Active' ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: c.status == 'Active' ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
                                ),
                                child: Text(c.status, style: TextStyle(color: c.status == 'Active' ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ),
                          );
                        },
                      ),

                const SizedBox(height: 24),

                // Leave History
                const Text('Leave & Attendance History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPremiumGold)),
                const SizedBox(height: 12),
                leaveHistory.isEmpty
                    ? GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: const Text('No leave applications recorded for this employee.', style: TextStyle(color: kPremiumMuted)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: leaveHistory.length,
                        itemBuilder: (context, index) {
                          final req = leaveHistory[index];
                          Color lColor = req.status == 'Approved' ? Colors.greenAccent : (req.status == 'Rejected' ? Colors.redAccent : Colors.orangeAccent);
                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text('${req.type} Leave (${req.startDate} - ${req.endDate})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kPremiumText)),
                              subtitle: Text('Reason: ${req.reason}', style: const TextStyle(color: kPremiumMuted)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: lColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: lColor.withOpacity(0.3)),
                                ),
                                child: Text(req.status, style: TextStyle(color: lColor, fontWeight: FontWeight.bold, fontSize: 11)),
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
