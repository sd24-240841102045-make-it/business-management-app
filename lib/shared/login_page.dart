import 'package:flutter/material.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/core/premium_theme.dart';

enum AuthRole {
  admin,
  employee,
  client,
}

enum AuthMode {
  signIn,
  createBusiness,
  acceptInvite,
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController industryController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController countryController = TextEditingController();
  final TextEditingController inviteTokenController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  AuthRole selectedRole = AuthRole.admin;
  AuthMode authMode = AuthMode.signIn;
  bool obscurePassword = true;
  bool isLoading = false;

  // Code verification state
  bool isVerifyingCode = false;
  String? verifiedInviteEmail;
  String? verifiedInviteRole;
  String? verifiedOrgName;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    emailController.dispose();
    passwordController.dispose();
    fullNameController.dispose();
    businessNameController.dispose();
    industryController.dispose();
    phoneController.dispose();
    countryController.dispose();
    inviteTokenController.dispose();
    super.dispose();
  }

  // ============================================================
  // LIVE INVITE CODE VERIFICATION
  // ============================================================

  Future<void> _checkInviteCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length != 6) {
      if (verifiedInviteEmail != null) {
        setState(() {
          verifiedInviteEmail = null;
          verifiedInviteRole = null;
          verifiedOrgName = null;
        });
      }
      return;
    }

    setState(() => isVerifyingCode = true);
    try {
      final details = await SupabaseService().checkInviteDetails(cleanCode);
      if (!mounted) return;
      if (details != null && details['valid'] == true) {
        final email = details['email']?.toString();
        final role = details['role']?.toString();
        final org = details['organization_name']?.toString();

        setState(() {
          verifiedInviteEmail = email;
          verifiedInviteRole = role;
          verifiedOrgName = org;
          if (email != null && email.isNotEmpty && emailController.text.trim().isEmpty) {
            emailController.text = email;
          }
          if (role != null) {
            if (role.toLowerCase() == 'employee') {
              selectedRole = AuthRole.employee;
            } else if (role.toLowerCase() == 'client') {
              selectedRole = AuthRole.client;
            }
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => isVerifyingCode = false);
      }
    }
  }

  // ============================================================
  // AUTH SUBMIT
  // ============================================================

  Future<void> handleAuthSubmit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (authMode == AuthMode.signIn) {
      if (email.isEmpty || password.isEmpty) {
        _showSnackBar('Please enter your email address and password.');
        return;
      }
    }

    if (authMode == AuthMode.createBusiness) {
      if (email.isEmpty ||
          password.isEmpty ||
          fullNameController.text.trim().isEmpty ||
          businessNameController.text.trim().isEmpty) {
        _showSnackBar('Please fill in all required business fields.');
        return;
      }
      if (password.length < 8) {
        _showSnackBar('Password must be at least 8 characters long.');
        return;
      }
    }

    if (authMode == AuthMode.acceptInvite) {
      final code = inviteTokenController.text.trim().toUpperCase();
      if (code.isEmpty) {
        _showSnackBar('Please enter the 6-character invitation code from your email.');
        return;
      }
      if (email.isEmpty || !email.contains('@')) {
        _showSnackBar('Please enter your email address.');
        return;
      }
      if (password.isEmpty || password.length < 6) {
        _showSnackBar('Please create a password of at least 6 characters.');
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      if (authMode == AuthMode.createBusiness) {
        await SupabaseService().signUpBusinessAdmin(
          email: email,
          password: password,
          fullName: fullNameController.text.trim(),
          businessName: businessNameController.text.trim(),
          industry: industryController.text.trim().isNotEmpty ? industryController.text.trim() : 'General',
          phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : 'N/A',
          country: countryController.text.trim().isNotEmpty ? countryController.text.trim() : 'USA',
        );

        if (!mounted) return;

        _showSnackBar('Business account created successfully! Logging in...', isError: false);
      } else if (authMode == AuthMode.acceptInvite) {
        final cleanCode = inviteTokenController.text.trim().toUpperCase();
        await SupabaseService().acceptInvitation(
          token: cleanCode,
          email: email,
          password: password,
          fullName: fullNameController.text.trim().isNotEmpty
              ? fullNameController.text.trim()
              : (email.contains('@') ? email.split('@').first : 'Team Member'),
        );

        if (!mounted) return;

        _showSnackBar('Invitation accepted! Logged in successfully.', isError: false);
      } else {
        // Sign In Flow
        try {
          await SupabaseService().signInWithEmail(
            email: email,
            password: password,
          );
        } catch (signInErr) {
          // If standard sign-in fails, check if the user entered their 6-letter invitation code in the password field
          final possibleCode = password.trim().toUpperCase();
          if (possibleCode.length == 6) {
            final check = await SupabaseService().checkInviteDetails(possibleCode);
            if (check != null && check['valid'] == true) {
              await SupabaseService().acceptInvitation(
                token: possibleCode,
                email: email,
                password: password,
                fullName: email.contains('@') ? email.split('@').first : 'Team Member',
              );
              if (!mounted) return;
              _showSnackBar('Invitation code verified! Logged in successfully.', isError: false);
              return;
            }
          }
          rethrow;
        }

        final actualRole = SupabaseService().currentRole;
        final expectedRoleStr = selectedRole.name;

        if (actualRole != expectedRoleStr) {
          await SupabaseService().client.auth.signOut();
          throw Exception('Access denied. You are registered as an $actualRole, but tried to log in as a $expectedRoleStr.');
        }

        final user = SupabaseService().currentUser;
        final userName = user?.userMetadata?['full_name'] as String? ?? 'User';

        if (!mounted) return;

        _showSnackBar('Welcome back, $userName!', isError: false);
      }
    } catch (e) {
      if (!mounted) return;
      final message = AuthErrorHandler.getFriendlyMessage(e);
      _showSnackBar(message.isEmpty ? 'Authentication failed. Please try again.' : message);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(text: emailController.text.trim());
    bool sending = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: kPremiumSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: kPremiumBorder),
              ),
              title: const Text(
                'Reset Password',
                style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your registered email address. We will send you a password reset link.',
                    style: TextStyle(color: kPremiumMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: const TextStyle(color: kPremiumText),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: const TextStyle(color: kPremiumMuted),
                      prefixIcon: const Icon(Icons.email_outlined, color: kPremiumGold),
                      filled: true,
                      fillColor: kPremiumSurface.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: kPremiumMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPremiumGold,
                    foregroundColor: kPremiumBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: sending
                      ? null
                      : () async {
                          final email = controller.text.trim();
                          if (email.isEmpty) {
                            _showSnackBar('Please enter your email address.');
                            return;
                          }
                          setDialogState(() => sending = true);
                          try {
                            await SupabaseService().resetPassword(email);
                            if (!mounted) return;
                            Navigator.pop(dialogContext);
                            _showSnackBar('Password reset email sent. Please check your inbox.', isError: false);
                          } catch (e) {
                            setDialogState(() => sending = false);
                            _showSnackBar(e.toString().replaceAll('AuthException:', '').replaceAll('Exception:', '').trim());
                          }
                        },
                  child: sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kPremiumBg))
                      : const Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade700 : const Color(0xFF1E8E5A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final bool isTablet = width >= 600;
                final bool isMobile = width < 600;
                final bool isCompactMobile = width < 380;

                return Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? (isCompactMobile ? 12 : 20) : 32,
                      vertical: isMobile ? 16 : 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 480,
                      ),
                      child: _buildCardContent(context, isTablet, isMobile, isCompactMobile),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CARD CONTENT
  // ============================================================

  Widget _buildCardContent(BuildContext context, bool isTablet, bool isMobile, bool isCompactMobile) {
    final double cardPadding = isCompactMobile ? 18 : (isMobile ? 22 : 32);

    return GlassCard(
      padding: EdgeInsets.all(cardPadding),
      radius: isMobile ? 22 : 26,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            // LOGO & HEADER
            Center(
              child: Container(
                width: isMobile ? 54 : 64,
                height: isMobile ? 54 : 64,
                decoration: BoxDecoration(
                  color: kPremiumGold.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: kPremiumGold.withOpacity(0.35), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: kPremiumGold.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  authMode == AuthMode.acceptInvite
                      ? Icons.how_to_reg_rounded
                      : (authMode == AuthMode.createBusiness
                          ? Icons.add_business_rounded
                          : Icons.business_center_rounded),
                  size: isMobile ? 26 : 30,
                  color: kPremiumGold,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // PORTAL TITLE
            Text(
              authMode == AuthMode.createBusiness
                  ? 'Create Your Business'
                  : authMode == AuthMode.acceptInvite
                      ? 'Join Organization'
                      : 'Sign In',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isCompactMobile ? 20 : (isMobile ? 23 : 26),
                fontWeight: FontWeight.bold,
                color: kPremiumGold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),

            // SUBTITLE
            Text(
              authMode == AuthMode.createBusiness
                  ? 'Initialize your business and administrator account.'
                  : authMode == AuthMode.acceptInvite
                      ? 'Enter the 6-character access token sent to your email.'
                      : 'Sign in to access your dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kPremiumMuted,
                fontSize: isCompactMobile ? 11.5 : 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),

            // ROLE SELECTOR
            _buildRoleSelector(isCompactMobile),
            const SizedBox(height: 8),

            // ROLE DESCRIPTION CAPTION
            _buildRoleDescriptionBanner(),
            const SizedBox(height: 18),

            // AUTH MODE SEGMENTED TABS
            _buildModeSegmentedControl(isCompactMobile),
            const SizedBox(height: 20),

            // INVITATION CODE HELPER BANNER ON SIGN IN MODE
            if (authMode == AuthMode.signIn) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kPremiumGold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kPremiumGold.withOpacity(0.22)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: kPremiumGold.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mark_email_read_outlined, color: kPremiumGold, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Invited by an Administrator?',
                            style: TextStyle(color: kPremiumText, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Activate your workspace with your 6-char code.',
                            style: TextStyle(color: kPremiumMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() => authMode = AuthMode.acceptInvite);
                      },
                      child: const Text('Join →', style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            // FORM FIELDS - ADAPTIVE LAYOUT
            if (authMode == AuthMode.createBusiness) ...[
              _buildBusinessFields(isWide: !isMobile),
            ],

            if (authMode == AuthMode.acceptInvite) ...[
              _buildField(
                controller: inviteTokenController,
                label: '6-Character Invitation Code',
                icon: Icons.vpn_key_outlined,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                onChanged: _checkInviteCode,
                helperText: 'Enter the 6-character code sent to your email (e.g. AB4X9Z)',
                suffixIcon: isVerifyingCode
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kPremiumGold),
                        ),
                      )
                    : (verifiedInviteRole != null
                        ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                        : null),
              ),

              if (verifiedInviteRole != null) ...[
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verified for ${verifiedInviteEmail ?? 'your account'} (${(verifiedInviteRole ?? 'member').toUpperCase()})',
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              _buildField(
                controller: fullNameController,
                label: 'Your Full Name (Optional)',
                icon: Icons.person_outline,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 12),
            ],

            // EMAIL ADDRESS
            _buildField(
              controller: emailController,
              label: 'Email Address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),

            // PASSWORD
            _buildField(
              controller: passwordController,
              label: authMode == AuthMode.acceptInvite ? 'Create Password' : 'Password',
              icon: Icons.lock_outline,
              obscureText: obscurePassword,
              autofillHints: authMode == AuthMode.createBusiness || authMode == AuthMode.acceptInvite
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!isLoading) handleAuthSubmit();
              },
              helperText: authMode == AuthMode.acceptInvite
                  ? 'Set a password to use when signing in next time (min 6 characters)'
                  : null,
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: kPremiumMuted,
                  size: 20,
                ),
                onPressed: () => setState(() => obscurePassword = !obscurePassword),
              ),
            ),

            if (authMode == AuthMode.signIn) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _showForgotPasswordDialog,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // SUBMIT BUTTON
            GoldButton(
              label: authMode == AuthMode.createBusiness
                  ? 'Create Business'
                  : authMode == AuthMode.acceptInvite
                      ? 'Login with Invitation Code'
                      : 'Sign In as ${selectedRole.name[0].toUpperCase()}${selectedRole.name.substring(1)}',
              icon: authMode == AuthMode.acceptInvite
                  ? Icons.verified_user_rounded
                  : (authMode == AuthMode.createBusiness ? Icons.add_business_rounded : Icons.login_rounded),
              expand: true,
              isLoading: isLoading,
              onPressed: isLoading ? null : handleAuthSubmit,
            ),

            const SizedBox(height: 22),

            // FOOTER BADGE
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.shield_outlined, size: 14, color: kPremiumMuted),
                SizedBox(width: 6),
                Text(
                  'Secure Cloud Workspace',
                  style: TextStyle(fontSize: 11.5, color: kPremiumMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
    );
  }

  // ============================================================
  // ADAPTIVE BUSINESS REGISTRATION FORM
  // ============================================================

  Widget _buildBusinessFields({required bool isWide}) {
    if (isWide) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildField(
                  controller: fullNameController,
                  label: 'Admin Full Name',
                  icon: Icons.person_outline,
                  autofillHints: const [AutofillHints.name],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  controller: businessNameController,
                  label: 'Business Name',
                  icon: Icons.domain_outlined,
                  autofillHints: const [AutofillHints.organizationName],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildField(
                  controller: industryController,
                  label: 'Industry',
                  icon: Icons.category_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  controller: phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: countryController,
            label: 'Country / Headquarters',
            icon: Icons.public_outlined,
            autofillHints: const [AutofillHints.countryName],
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    return Column(
      children: [
        _buildField(
          controller: fullNameController,
          label: 'Admin Full Name',
          icon: Icons.person_outline,
          autofillHints: const [AutofillHints.name],
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: businessNameController,
          label: 'Business Name',
          icon: Icons.domain_outlined,
          autofillHints: const [AutofillHints.organizationName],
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: industryController,
          label: 'Industry',
          icon: Icons.category_outlined,
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: phoneController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: countryController,
          label: 'Country / Headquarters',
          icon: Icons.public_outlined,
          autofillHints: const [AutofillHints.countryName],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ============================================================
  // ROLE SELECTOR
  // ============================================================

  Widget _buildRoleSelector(bool isCompactMobile) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kPremiumSurface.withOpacity(0.7),
        border: Border.all(color: kPremiumBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildRoleTab(AuthRole.admin, 'Admin', Icons.admin_panel_settings_outlined, isCompactMobile),
          _buildRoleTab(AuthRole.employee, 'Employee', Icons.badge_outlined, isCompactMobile),
          _buildRoleTab(AuthRole.client, 'Client', Icons.business_center_outlined, isCompactMobile),
        ],
      ),
    );
  }

  Widget _buildRoleTab(AuthRole role, String title, IconData icon, bool isCompactMobile) {
    final bool selected = selectedRole == role;

    return Expanded(
      child: GestureDetector(
        onTap: isLoading
            ? null
            : () {
                setState(() {
                  selectedRole = role;
                  // If switching away from Admin while on createBusiness, reset to signIn
                  if (role != AuthRole.admin && authMode == AuthMode.createBusiness) {
                    authMode = AuthMode.signIn;
                  }
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(vertical: isCompactMobile ? 8 : 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? kPremiumGold : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: kPremiumGold.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isCompactMobile ? 15 : 17,
                  color: selected ? kPremiumBg : kPremiumMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? kPremiumBg : kPremiumMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: isCompactMobile ? 12 : 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDescriptionBanner() {
    String description;
    switch (selectedRole) {
      case AuthRole.admin:
        description = 'Executive controls, workforce governance & organization settings';
        break;
      case AuthRole.employee:
        description = 'Assigned projects, task boards, attendance & team chats';
        break;
      case AuthRole.client:
        description = 'Project milestones, consultations, shared deliverables & invoices';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      alignment: Alignment.center,
      child: Text(
        description,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: kPremiumMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ============================================================
  // UNIFIED MODE SEGMENTED CONTROL (No wrapping chips)
  // ============================================================

  Widget _buildModeSegmentedControl(bool isCompactMobile) {
    final bool showCreate = selectedRole == AuthRole.admin;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          _buildModeTabItem('Sign In', AuthMode.signIn, isCompactMobile),
          if (showCreate)
            _buildModeTabItem(
              isCompactMobile ? 'Create' : 'Create Business',
              AuthMode.createBusiness,
              isCompactMobile,
            ),
          _buildModeTabItem(
            isCompactMobile ? 'Code' : 'Join with Code',
            AuthMode.acceptInvite,
            isCompactMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabItem(String label, AuthMode mode, bool isCompactMobile) {
    final bool selected = authMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: isLoading
            ? null
            : () {
                setState(() => authMode = mode);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(vertical: isCompactMobile ? 8 : 9, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? kPremiumGold.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? kPremiumGold.withOpacity(0.6) : Colors.transparent,
              width: 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? kPremiumGold : kPremiumMuted,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                fontSize: isCompactMobile ? 11.5 : 12.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TEXT FIELD WIDGET
  // ============================================================

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    TextInputAction textInputAction = TextInputAction.next,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<String>? autofillHints,
    String? helperText,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      style: const TextStyle(color: kPremiumText, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kPremiumMuted, fontSize: 13.5),
        helperText: helperText,
        helperMaxLines: 2,
        helperStyle: const TextStyle(color: kPremiumMuted, fontSize: 11),
        counterText: '',
        prefixIcon: Icon(icon, color: kPremiumGold, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: kPremiumSurface.withOpacity(0.55),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPremiumGold, width: 1.5),
        ),
      ),
    );
  }
}
