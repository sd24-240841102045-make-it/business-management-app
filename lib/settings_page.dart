import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/app_data_store.dart';
import 'services/supabase_service.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AppDataStore _store = AppDataStore();

  // Local Settings State
  bool _darkMode = false;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _biometricLock = false;
  String _selectedCurrency = '\$ (USD)';
  Color _selectedColor = Colors.deepPurple;

  final List<String> _currencies = ['\$ (USD)', '₹ (INR)', '€ (EUR)', '£ (GBP)'];
  final List<Color> _themeColors = [
    Colors.deepPurple,
    Colors.indigo,
    Colors.teal,
    Colors.blue,
    const Color(0xFF10B981),
  ];

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

  void _showChangePasswordDialog(String userEmail) {
    final emailCtrl = TextEditingController(text: userEmail);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We will send a Supabase password reset link to your registered email.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SupabaseService().resetPassword(emailCtrl.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password reset link sent to ${emailCtrl.text.trim()}!'),
                      backgroundColor: Colors.green,
                    ),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Send Reset Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Business Management Suite',
      applicationVersion: 'v1.2.0 (Build 2026)',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.deepPurple,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.business_center, color: Colors.white, size: 32),
      ),
      children: const [
        Text(
          'Unified Enterprise Operations & CRM System integrated with Supabase Real-Time Backend & Authentication.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userEmail = user?.email ?? 'admin@business.com';
    final userRole = SupabaseService().getUserRole(user).toUpperCase();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width >= 900;
        final bool isTablet = width >= 600 && width < 900;
        final double horizontalPadding = isDesktop ? 40 : isTablet ? 30 : 20;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          appBar: AppBar(
            title: const Text('Application Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          body: RefreshIndicator(
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
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF8E7CFF)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.settings, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Preferences & Operations',
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Logged in as $userEmail ($userRole)',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 1. APPEARANCE & THEME
                      _buildSectionHeader('Appearance & Display'),
                      _buildSettingsCard([
                        SwitchListTile(
                          value: _store.isDarkMode,
                          onChanged: (val) {
                            setState(() {
                              _darkMode = val;
                            });
                            _store.toggleDarkMode(val);
                          },
                          secondary: const CircleAvatar(
                            backgroundColor: Color(0xFFEDE7F6),
                            child: Icon(Icons.dark_mode_outlined, color: Colors.deepPurple),
                          ),
                          title: const Text('Dark Mode Theme', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Enable dark background theme'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEDE7F6),
                            child: Icon(Icons.attach_money, color: Colors.deepPurple),
                          ),
                          title: const Text('Primary Currency Symbol', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Selected: $_selectedCurrency'),
                          trailing: DropdownButton<String>(
                            value: _selectedCurrency,
                            underline: const SizedBox(),
                            items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCurrency = val);
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // 2. NOTIFICATIONS & ALERTS
                      _buildSectionHeader('Notifications & Alert Rules'),
                      _buildSettingsCard([
                        SwitchListTile(
                          value: _pushNotifications,
                          onChanged: (val) => setState(() => _pushNotifications = val),
                          secondary: const CircleAvatar(
                            backgroundColor: Color(0xFFE0F2F1),
                            child: Icon(Icons.notifications_active_outlined, color: Colors.teal),
                          ),
                          title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Real-time alerts for leave requests & updates'),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _emailNotifications,
                          onChanged: (val) => setState(() => _emailNotifications = val),
                          secondary: const CircleAvatar(
                            backgroundColor: Color(0xFFE0F2F1),
                            child: Icon(Icons.mark_email_unread_outlined, color: Colors.teal),
                          ),
                          title: const Text('Email Digests', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Daily email summaries for operations'),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // 3. DATABASE & SUPABASE SYNC
                      _buildSectionHeader('Backend Sync & Database'),
                      _buildSettingsCard([
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE8EAF6),
                            child: Icon(Icons.cloud_sync_outlined, color: Colors.indigo),
                          ),
                          title: const Text('Re-sync Supabase Database', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(_store.isLoadingFromSupabase ? 'Syncing...' : 'Fetch latest remote tables'),
                          trailing: _store.isLoadingFromSupabase
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () async {
                                    await _store.refreshFromSupabase();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Supabase database successfully synced!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Sync Now'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE8EAF6),
                            child: Icon(Icons.dns_outlined, color: Colors.indigo),
                          ),
                          title: const Text('Supabase Connection Status', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Endpoint: sgadxqxwavjgnxmofeaw.supabase.co'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('CONNECTED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // 4. SECURITY & AUTHENTICATION
                      _buildSectionHeader('Security & Account'),
                      _buildSettingsCard([
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFEBEE),
                            child: Icon(Icons.lock_reset_outlined, color: Colors.redAccent),
                          ),
                          title: const Text('Reset Account Password', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Send password reset link via Supabase Auth'),
                          onTap: () => _showChangePasswordDialog(userEmail),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: _biometricLock,
                          onChanged: (val) => setState(() => _biometricLock = val),
                          secondary: const CircleAvatar(
                            backgroundColor: Color(0xFFFFEBEE),
                            child: Icon(Icons.fingerprint, color: Colors.redAccent),
                          ),
                          title: const Text('Biometric / PIN Lock', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Require biometric authentication on app resume'),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // 5. SYSTEM & ABOUT
                      _buildSectionHeader('System & Information'),
                      _buildSettingsCard([
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFF3E0),
                            child: Icon(Icons.info_outline, color: Colors.orange),
                          ),
                          title: const Text('About Business Management Suite', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Version 1.2.0 (Build 2026)'),
                          onTap: _showAboutDialog,
                        ),
                      ]),
                      const SizedBox(height: 30),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
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
                          label: const Text('Sign Out of Application', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(children: children),
    );
  }
}
