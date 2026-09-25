import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:business_managment_app/models/chat_models.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/services/messaging_service.dart';
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
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _biometricLock = false;
  String _selectedCurrency = '₹ (INR)';

  final List<String> _currencies = ['₹ (INR)', '\$ (USD)', '€ (EUR)', '£ (GBP)'];

  CommunicationSettingsModel? _commSettings;
  bool _loadingCommSettings = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
    _loadCommSettings();
  }

  Future<void> _loadCommSettings() async {
    setState(() => _loadingCommSettings = true);
    final settings = await MessagingService().getCommunicationSettings();
    if (mounted) {
      setState(() {
        _commSettings = settings;
        _loadingCommSettings = false;
      });
    }
  }

  Future<void> _updateCommSetting(CommunicationSettingsModel Function(CommunicationSettingsModel current) updater) async {
    if (_commSettings == null) return;
    final updated = updater(_commSettings!);
    setState(() => _commSettings = updated);
    final success = await MessagingService().updateCommunicationSettings(updated);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Communication policy updated successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update communication policy'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

                      // 5. BUSINESS COMMUNICATION & PRIVACY POLICIES (ADMINS)
                      if (userRole == 'ADMIN' || userRole == 'OWNER') ...[
                        _buildSectionHeader('Business Communication Policies'),
                        _buildSettingsCard([
                          SwitchListTile(
                            value: _commSettings?.enableEmployeeClientMessaging ?? true,
                            onChanged: (val) => _updateCommSetting((s) => CommunicationSettingsModel(
                              id: s.id,
                              organizationId: s.organizationId,
                              enableEmployeeClientMessaging: val,
                              restrictClientToProjects: s.restrictClientToProjects,
                              allowEmployeeEmployeeChat: s.allowEmployeeEmployeeChat,
                              showBusinessContactInfo: s.showBusinessContactInfo,
                              allowFileSharing: s.allowFileSharing,
                              allowMessageEditing: s.allowMessageEditing,
                              allowMessageDeletion: s.allowMessageDeletion,
                              maxMessageLength: s.maxMessageLength,
                            )),
                            secondary: const PremiumAvatar(
                              icon: Icons.forum_outlined,
                              style: AvatarStyle.glowIcon,
                              size: 40,
                            ),
                            title: const Text('Employee ↔ Client Messaging', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                            subtitle: const Text('Allow communication between staff and clients on assigned workflows', style: TextStyle(color: kPremiumMuted)),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          SwitchListTile(
                            value: _commSettings?.restrictClientToProjects ?? true,
                            onChanged: (val) => _updateCommSetting((s) => CommunicationSettingsModel(
                              id: s.id,
                              organizationId: s.organizationId,
                              enableEmployeeClientMessaging: s.enableEmployeeClientMessaging,
                              restrictClientToProjects: val,
                              allowEmployeeEmployeeChat: s.allowEmployeeEmployeeChat,
                              showBusinessContactInfo: s.showBusinessContactInfo,
                              allowFileSharing: s.allowFileSharing,
                              allowMessageEditing: s.allowMessageEditing,
                              allowMessageDeletion: s.allowMessageDeletion,
                              maxMessageLength: s.maxMessageLength,
                            )),
                            secondary: const PremiumAvatar(
                              icon: Icons.folder_shared_outlined,
                              style: AvatarStyle.glowIcon,
                              size: 40,
                            ),
                            title: const Text('Restrict Clients to Assigned Projects', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                            subtitle: const Text('Ensure clients can only communicate within projects they are assigned to', style: TextStyle(color: kPremiumMuted)),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          SwitchListTile(
                            value: _commSettings?.allowEmployeeEmployeeChat ?? true,
                            onChanged: (val) => _updateCommSetting((s) => CommunicationSettingsModel(
                              id: s.id,
                              organizationId: s.organizationId,
                              enableEmployeeClientMessaging: s.enableEmployeeClientMessaging,
                              restrictClientToProjects: s.restrictClientToProjects,
                              allowEmployeeEmployeeChat: val,
                              showBusinessContactInfo: s.showBusinessContactInfo,
                              allowFileSharing: s.allowFileSharing,
                              allowMessageEditing: s.allowMessageEditing,
                              allowMessageDeletion: s.allowMessageDeletion,
                              maxMessageLength: s.maxMessageLength,
                            )),
                            secondary: const PremiumAvatar(
                              icon: Icons.groups_outlined,
                              style: AvatarStyle.glowIcon,
                              size: 40,
                            ),
                            title: const Text('Employee ↔ Employee Chat', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                            subtitle: const Text('Allow colleagues within the same organization to communicate directly', style: TextStyle(color: kPremiumMuted)),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          SwitchListTile(
                            value: _commSettings?.showBusinessContactInfo ?? true,
                            onChanged: (val) => _updateCommSetting((s) => CommunicationSettingsModel(
                              id: s.id,
                              organizationId: s.organizationId,
                              enableEmployeeClientMessaging: s.enableEmployeeClientMessaging,
                              restrictClientToProjects: s.restrictClientToProjects,
                              allowEmployeeEmployeeChat: s.allowEmployeeEmployeeChat,
                              showBusinessContactInfo: val,
                              allowFileSharing: s.allowFileSharing,
                              allowMessageEditing: s.allowMessageEditing,
                              allowMessageDeletion: s.allowMessageDeletion,
                              maxMessageLength: s.maxMessageLength,
                            )),
                            secondary: const PremiumAvatar(
                              icon: Icons.contact_phone_outlined,
                              style: AvatarStyle.glowIcon,
                              size: 40,
                            ),
                            title: const Text('Display Business Contact Info', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                            subtitle: const Text('Display official business email and office extensions on work profiles', style: TextStyle(color: kPremiumMuted)),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          SwitchListTile(
                            value: _commSettings?.allowMessageDeletion ?? false,
                            onChanged: (val) => _updateCommSetting((s) => CommunicationSettingsModel(
                              id: s.id,
                              organizationId: s.organizationId,
                              enableEmployeeClientMessaging: s.enableEmployeeClientMessaging,
                              restrictClientToProjects: s.restrictClientToProjects,
                              allowEmployeeEmployeeChat: s.allowEmployeeEmployeeChat,
                              showBusinessContactInfo: s.showBusinessContactInfo,
                              allowFileSharing: s.allowFileSharing,
                              allowMessageEditing: s.allowMessageEditing,
                              allowMessageDeletion: val,
                              maxMessageLength: s.maxMessageLength,
                            )),
                            secondary: const PremiumAvatar(
                              icon: Icons.history_edu_outlined,
                              style: AvatarStyle.glowIcon,
                              size: 40,
                            ),
                            title: const Text('Allow Message Deletion', style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText)),
                            subtitle: const Text('When disabled, all sent messages remain archived as immutable business records', style: TextStyle(color: kPremiumMuted)),
                          ),
                        ]),
                        const SizedBox(height: 24),
                      ],

                      // 6. SYSTEM & ABOUT
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
                            final confirm = await showLogoutConfirmationDialog(context);
                            if (confirm) {
                              await SupabaseService().signOut();
                              if (context.mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginPage()),
                                );
                              }
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
