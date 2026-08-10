import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/shared/login_page.dart';
import 'package:business_managment_app/core/premium_theme.dart';

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

  final List<String> _currencies = ['\$ (USD)', '₹ (INR)', '€ (EUR)', '£ (GBP)'];

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
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Application Settings', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold)),
            backgroundColor: kPremiumBg,
            foregroundColor: kPremiumGold,
            elevation: 0,
          ),
          body: SafeArea(
            bottom: true,
            child: RefreshIndicator(
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
                      HeroBanner(
                        title: 'Preferences & Settings',
                        subtitle: 'Logged in as $userEmail ($userRole)',
                        badge: 'Platform Configuration',
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
                          secondary: const PremiumAvatar(
                            icon: Icons.contrast_outlined,
                            style: AvatarStyle.glowIcon,
                            size: 40,
                          ),
                          title: const Text('High Contrast Glass Mode', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                          subtitle: const Text('Enhance obsidian dark glass contrast & gold highlights', style: TextStyle(color: kPremiumMuted)),
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        ListTile(
                          leading: const PremiumAvatar(
                            icon: Icons.attach_money,
                            style: AvatarStyle.glowIcon,
                            size: 40,
                          ),
                          title: const Text('Primary Currency Symbol', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                          subtitle: Text('Selected: $_selectedCurrency', style: const TextStyle(color: kPremiumMuted)),
                          trailing: DropdownButton<String>(
                            value: _selectedCurrency,
                            dropdownColor: kPremiumSurface,
                            underline: const SizedBox(),
                            items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: kPremiumText)))).toList(),
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
                          secondary: const PremiumAvatar(
                            icon: Icons.notifications_active_outlined,
                            style: AvatarStyle.glowIcon,
                            size: 40,
                          ),
                          title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                          subtitle: const Text('Real-time alerts for leave requests & updates', style: TextStyle(color: kPremiumMuted)),
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        SwitchListTile(
                          value: _emailNotifications,
                          onChanged: (val) => setState(() => _emailNotifications = val),
                          secondary: const PremiumAvatar(
                            icon: Icons.mark_email_unread_outlined,
                            style: AvatarStyle.glowIcon,
                            size: 40,
                          ),
                          title: const Text('Email Digests', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                          subtitle: const Text('Daily email summaries for operations', style: TextStyle(color: kPremiumMuted)),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // 3. DATABASE & SUPABASE SYNC
                      _buildSectionHeader('Backend Sync & Database'),
                      _buildSettingsCard([
                        ListTile(
                          leading: const PremiumAvatar(
                            icon: Icons.cloud_sync_outlined,
                            style: AvatarStyle.glowIcon,
                            size: 40,
                          ),
                          title: const Text('Re-sync Supabase Database', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                          subtitle: Text(_store.isLoadingFromSupabase ? 'Syncing...' : 'Fetch latest remote tables', style: const TextStyle(color: kPremiumMuted)),
                          trailing: _store.isLoadingFromSupabase
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: kPremiumGold),
                                )
                              : GoldButton(
                                  label: 'Sync Now',
                                  icon: Icons.refresh,
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
                                ),
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        ListTile(
                          leading: const PremiumAvatar(
                            icon: Icons.dns_outlined,
                            style: AvatarStyle.glowIcon,
                            size: 40,
                          ),
                          title: const Text('Supabase Connection Status', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                          subtitle: const Text('Endpoint: sgadxqxwavjgnxmofeaw.supabase.co', style: TextStyle(color: kPremiumMuted)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: const Text('CONNECTED', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // 4. SECURITY & AUTHENTICATION
                      _buildSectionHeader('Security & Account'),
                      _buildSettingsCard([
                        ListTile(
                          leading: const PremiumAvatar(
                            icon: Icons.lock_reset_outlined,
                            style: AvatarStyle.glowIcon,
                            size: 40,
                          ),
                          title: const Text('Reset Account Password', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                          subtitle: const Text('Send password reset link via Supabase Auth', style: TextStyle(color: kPremiumMuted)),
                          onTap: () => _showChangePasswordDialog(userEmail),
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        SwitchListTile(
                          value: _biometricLock,
                          onChanged: (val) => setState(() => _biometricLock = val),
                          secondary: const PremiumAvatar(
                            icon: Icons.fingerprint,
                            style: AvatarStyle.glowIcon,
                            size: 40,
                          ),
                          title: const Text('Biometric / PIN Lock', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                          subtitle: const Text('Require biometric authentication on app resume', style: TextStyle(color: kPremiumMuted)),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // 5. SYSTEM & ABOUT
                      _buildSectionHeader('System & Information'),
                      _buildSettingsCard([
                        ListTile(
                          leading: const PremiumAvatar(
                            icon: Icons.info_outline,
                            style: AvatarStyle.glowIcon,
                            size: 40,
                          ),
                          title: const Text('About Business Management Suite', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                          subtitle: const Text('Version 1.2.0 (Build 2026)', style: TextStyle(color: kPremiumMuted)),
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
                          icon: const Icon(Icons.logout, color: Colors.redAccent),
                          label: const Text('Sign Out of Application', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
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
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kPremiumGold),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: children),
    );
  }
}
