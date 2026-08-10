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

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
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
  // AUTH SUBMIT
  // ============================================================

  Future<void> handleAuthSubmit() async {
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
    }

    if (authMode == AuthMode.acceptInvite) {
      if (inviteTokenController.text.trim().isEmpty ||
          email.isEmpty ||
          password.isEmpty ||
          fullNameController.text.trim().isEmpty) {
        _showSnackBar('Please fill in all invitation fields.');
        return;
      }
    }

    if (authMode != AuthMode.signIn && password.length < 8) {
      _showSnackBar('Password must be at least 8 characters long.');
      return;
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
        await SupabaseService().acceptInvitation(
          token: inviteTokenController.text.trim(),
          email: email,
          password: password,
          fullName: fullNameController.text.trim(),
        );

        if (!mounted) return;

        _showSnackBar('Invitation accepted successfully! Logging in...', isError: false);
      } else {
        await SupabaseService().signInWithEmail(
          email: email,
          password: password,
        );

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kPremiumBorder)),
              title: const Text(
                'Reset Password',
                style: TextStyle(fontWeight: FontWeight.bold, color: kPremiumGold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your registered email address. We will send you a password reset link.',
                    style: TextStyle(color: kPremiumMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
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
                  style: ElevatedButton.styleFrom(backgroundColor: kPremiumGold, foregroundColor: kPremiumBg),
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
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final bool isMobile = width < 600;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 32,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: GlassCard(
                      padding: EdgeInsets.all(isMobile ? 22 : 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // LOGO AVATAR
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: kPremiumGold.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: kPremiumGold.withOpacity(0.3), width: 1.5),
                            ),
                            child: const Icon(Icons.business_center_rounded, size: 34, color: kPremiumGold),
                          ),
                          const SizedBox(height: 16),

                          // TITLE
                          Text(
                            authMode == AuthMode.createBusiness
                                ? 'Create Your Business'
                                : authMode == AuthMode.acceptInvite
                                    ? 'Join Organization'
                                    : 'Enterprise Portal',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isMobile ? 22 : 26,
                              fontWeight: FontWeight.bold,
                              color: kPremiumGold,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            authMode == AuthMode.createBusiness
                                ? 'Create your organization and administrator account.'
                                : authMode == AuthMode.acceptInvite
                                    ? 'Use your invitation code to join your organization.'
                                    : 'Sign in to access your executive dashboard.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: kPremiumMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 24),

                          // ROLE SELECTOR
                          _buildRoleSelector(),
                          const SizedBox(height: 20),

                          // MODE SELECTOR
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildModeChip('Sign In', AuthMode.signIn),
                              if (selectedRole == AuthRole.admin)
                                _buildModeChip('Create Business', AuthMode.createBusiness),
                              _buildModeChip('Invitation', AuthMode.acceptInvite),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // FORM FIELDS
                          if (authMode == AuthMode.createBusiness) ...[
                            _buildField(controller: fullNameController, label: 'Admin Full Name', icon: Icons.person_outline),
                            const SizedBox(height: 12),
                            _buildField(controller: businessNameController, label: 'Business Name', icon: Icons.domain_outlined),
                            const SizedBox(height: 12),
                            _buildField(controller: industryController, label: 'Industry', icon: Icons.category_outlined),
                            const SizedBox(height: 12),
                            _buildField(controller: phoneController, label: 'Phone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                            const SizedBox(height: 12),
                            _buildField(controller: countryController, label: 'Country', icon: Icons.public_outlined),
                            const SizedBox(height: 12),
                          ],

                          if (authMode == AuthMode.acceptInvite) ...[
                            _buildField(controller: inviteTokenController, label: 'Invitation Token', icon: Icons.vpn_key_outlined),
                            const SizedBox(height: 12),
                            _buildField(controller: fullNameController, label: 'Your Full Name', icon: Icons.person_outline),
                            const SizedBox(height: 12),
                          ],

                          _buildField(
                            controller: emailController,
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),

                          _buildField(
                            controller: passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: kPremiumMuted,
                              ),
                              onPressed: () => setState(() => obscurePassword = !obscurePassword),
                            ),
                          ),

                          if (authMode == AuthMode.signIn) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(color: kPremiumGold, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // SUBMIT BUTTON
                          GoldButton(
                            label: authMode == AuthMode.createBusiness
                                ? 'Create Business'
                                : authMode == AuthMode.acceptInvite
                                    ? 'Join Organization'
                                    : 'Sign In',
                            icon: Icons.login_rounded,
                            expand: true,
                            isLoading: isLoading,
                            onPressed: isLoading ? null : handleAuthSubmit,
                          ),

                          const SizedBox(height: 24),

                          // FOOTER
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.shield_outlined, size: 14, color: kPremiumMuted),
                              SizedBox(width: 6),
                              Text(
                                'Secure enterprise cloud workspace',
                                style: TextStyle(fontSize: 12, color: kPremiumMuted),
                              ),
                            ],
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
      ),
    );
  }

  // ============================================================
  // ROLE SELECTOR WIDGET
  // ============================================================

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kPremiumSurface.withOpacity(0.6),
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildRoleTab(AuthRole.admin, 'Admin', Icons.admin_panel_settings_outlined),
          _buildRoleTab(AuthRole.employee, 'Employee', Icons.badge_outlined),
          _buildRoleTab(AuthRole.client, 'Client', Icons.business_center_outlined),
        ],
      ),
    );
  }

  Widget _buildRoleTab(AuthRole role, String title, IconData icon) {
    final bool selected = selectedRole == role;

    return Expanded(
      child: GestureDetector(
        onTap: isLoading
            ? null
            : () {
                setState(() {
                  selectedRole = role;
                  if (role == AuthRole.client && authMode == AuthMode.createBusiness) {
                    authMode = AuthMode.signIn;
                  }
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? kPremiumGold : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: selected ? kPremiumBg : kPremiumMuted),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? kPremiumBg : kPremiumMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MODE CHIP WIDGET
  // ============================================================

  Widget _buildModeChip(String title, AuthMode mode) {
    final bool selected = authMode == mode;
    return ChoiceChip(
      label: Text(
        title,
        style: TextStyle(
          color: selected ? kPremiumBg : kPremiumText,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      selected: selected,
      selectedColor: kPremiumGold,
      backgroundColor: Colors.white.withOpacity(0.06),
      side: BorderSide(color: selected ? kPremiumGold : Colors.white10),
      onSelected: isLoading
          ? null
          : (_) {
              setState(() => authMode = mode);
            },
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
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: kPremiumText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kPremiumMuted),
        prefixIcon: Icon(icon, color: kPremiumGold),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: kPremiumSurface.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPremiumGold, width: 1.5),
        ),
      ),
    );
  }
}
