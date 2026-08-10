import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/app_data_store.dart';
import 'package:business_managment_app/core/premium_theme.dart';
import 'dart:math';

class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  String _selectedRole = 'employee';
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _generatedCode;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(Iterable.generate(
      length,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
  }

  Future<void> _generateInvite() async {
    setState(() {
      _isLoading = true;
      _generatedCode = null;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email address.';
        _isLoading = false;
      });
      return;
    }

    try {
      final orgId = SupabaseService().currentOrganizationId;
      if (orgId == null) throw Exception("No organization found. You must be an admin.");

      // Generate a 6-character code e.g. "AB4X9Z"
      final code = _generateRandomCode(6);
      
      // Calculate expiration (7 days from now)
      final expiresAt = DateTime.now().add(const Duration(days: 7)).toIso8601String();
      
      // Insert into invitations table
      await SupabaseService().client.from('invitations').insert({
        'organization_id': orgId,
        'token': code,
        'role': _selectedRole,
        'email': email,
        'invited_by': SupabaseService().currentUser!.id,
        'expires_at': expiresAt,
        'status': 'pending',
      });

      if (_selectedRole == 'client') {
        final namePart = email.contains('@') ? email.split('@').first : email;
        try {
          await SupabaseService().client.from('clients').upsert({
            'organization_id': orgId,
            'client_type': 'business',
            'contact_name': namePart,
            'company_name': namePart,
            'email': email,
            'status': 'Active',
          });
        } catch (e) {
          debugPrint('Error auto-upserting client record: $e');
        }
      }

      await AppDataStore().refreshFromSupabase();

      setState(() {
        _generatedCode = code;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kPremiumGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.arrow_back, color: kPremiumGold, size: 20),
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back to Dashboard',
                ),
              )
            : null,
        title: const Text(
          'Invite Members',
          style: TextStyle(color: kPremiumText, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < 600;
            final double cardPadding = isMobile ? 18.0 : 28.0;
            final double pagePadding = isMobile ? 12.0 : 20.0;
            final double bottomInset = MediaQuery.of(context).padding.bottom + 50.0;

            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: pagePadding,
                right: pagePadding,
                top: pagePadding,
                bottom: bottomInset,
              ),
              child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: EdgeInsets.all(pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HeroBanner(
                        title: 'Invite Team Members',
                        subtitle: 'Generate secure access tokens for new staff and client accounts',
                        badge: 'Access & Onboarding',
                      ),
                      const SizedBox(height: 20),
                      GlassCard(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: const [
                                PremiumAvatar(
                                  icon: Icons.person_add_alt_1_outlined,
                                  style: AvatarStyle.glowIcon,
                                  size: 44,
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Create Access Invitation',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: kPremiumText,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Generate a unique code to onboard employees or clients.',
                                        style: TextStyle(color: kPremiumMuted, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32, color: Colors.white10),

                            // Email Input
                            const Text(
                              'Invitee Email Address',
                              style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _emailController,
                              style: const TextStyle(color: kPremiumText),
                              decoration: InputDecoration(
                                hintText: 'e.g. member@company.com',
                                hintStyle: const TextStyle(color: kPremiumMuted),
                                prefixIcon: const Icon(Icons.email_outlined, color: kPremiumGold),
                                filled: true,
                                fillColor: kPremiumSurface.withOpacity(0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: kPremiumGold),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 24),
                            
                            // Role Selector
                            const Text(
                              'Select Target Account Role',
                              style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumText),
                            ),
                            const SizedBox(height: 10),
                            isMobile
                                ? Column(
                                    children: [
                                      _roleOptionCard(
                                        title: 'Employee',
                                        subtitle: 'Full staff portal access',
                                        value: 'employee',
                                        icon: Icons.badge_outlined,
                                      ),
                                      const SizedBox(height: 10),
                                      _roleOptionCard(
                                        title: 'Client',
                                        subtitle: 'Client portal lead',
                                        value: 'client',
                                        icon: Icons.business_outlined,
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: _roleOptionCard(
                                          title: 'Employee',
                                          subtitle: 'Full staff portal access',
                                          value: 'employee',
                                          icon: Icons.badge_outlined,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _roleOptionCard(
                                          title: 'Client',
                                          subtitle: 'Client portal lead',
                                          value: 'client',
                                          icon: Icons.business_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                            const SizedBox(height: 28),

                            // Generate Button
                            GoldButton(
                              label: 'Generate Invitation Code',
                              icon: Icons.send_rounded,
                              isLoading: _isLoading,
                              onPressed: _generateInvite,
                            ),
                            
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (_generatedCode != null) ...[
                              const SizedBox(height: 28),
                              GlassCard(
                                padding: EdgeInsets.all(isMobile ? 16 : 24),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Invitation Code Ready',
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 12 : 20,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kPremiumGold.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: kPremiumGold.withOpacity(0.3)),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: SelectableText(
                                          _generatedCode!,
                                          style: TextStyle(
                                            fontSize: isMobile ? 28 : 36,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: isMobile ? 4 : 8,
                                            color: kPremiumGold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Share this code with the invitee. It will expire in 7 days.',
                                      style: TextStyle(color: kPremiumMuted, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: _generatedCode!));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Invitation code copied to clipboard!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.copy, color: kPremiumGold, size: 18),
                                      label: const Text('Copy Code', style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: kPremiumGold),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

  Widget _roleOptionCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final bool isSelected = _selectedRole == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = value;
          _generatedCode = null;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? kPremiumGold.withOpacity(0.15) : kPremiumSurface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? kPremiumGold : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? kPremiumGold : kPremiumMuted,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? kPremiumGold : kPremiumText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: kPremiumMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
