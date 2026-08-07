import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/app_data_store.dart';
import 'login_page.dart';
import 'settings_page.dart';

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
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  children: [
                // Profile Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8E7CFF)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$userRole • $empDept',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () => user != null ? _editProfileDialog(user, matchingEmp) : null,
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text('Edit Profile'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
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
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  static Widget _infoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.deepPurple.withOpacity(0.1),
            child: Icon(icon, color: Colors.deepPurple),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.withOpacity(0.1),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
