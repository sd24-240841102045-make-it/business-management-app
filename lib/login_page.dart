import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/supabase_service.dart';
import 'main.dart';

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

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController fullNameController =
      TextEditingController();

  final TextEditingController businessNameController =
      TextEditingController();

  final TextEditingController industryController =
      TextEditingController();

  final TextEditingController phoneController =
      TextEditingController();

  final TextEditingController countryController =
      TextEditingController();

  final TextEditingController inviteTokenController =
      TextEditingController();

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

    // ----------------------------------------------------------
    // SIGN IN VALIDATION
    // ----------------------------------------------------------

    if (authMode == AuthMode.signIn) {
      if (email.isEmpty || password.isEmpty) {
        _showSnackBar(
          'Please enter your email address and password.',
        );
        return;
      }
    }

    // ----------------------------------------------------------
    // BUSINESS CREATION VALIDATION
    // ----------------------------------------------------------

    if (authMode == AuthMode.createBusiness) {
      if (email.isEmpty ||
          password.isEmpty ||
          fullNameController.text.trim().isEmpty ||
          businessNameController.text.trim().isEmpty) {
        _showSnackBar(
          'Please fill in all required business fields.',
        );
        return;
      }
    }

    // ----------------------------------------------------------
    // INVITATION VALIDATION
    // ----------------------------------------------------------

    if (authMode == AuthMode.acceptInvite) {
      if (inviteTokenController.text.trim().isEmpty ||
          email.isEmpty ||
          password.isEmpty ||
          fullNameController.text.trim().isEmpty) {
        _showSnackBar(
          'Please fill in all invitation fields.',
        );
        return;
      }
    }

    // ----------------------------------------------------------
    // PASSWORD VALIDATION
    // ----------------------------------------------------------

    if (authMode == AuthMode.signIn) {
      if (password.isEmpty) {
        _showSnackBar('Please enter your password.');
        return;
      }
    } else {
      if (password.length < 8) {
        _showSnackBar('Password must be at least 8 characters long.');
        return;
      }
      if (!RegExp(r'[A-Z]').hasMatch(password)) {
        _showSnackBar('Password must contain at least one uppercase letter.');
        return;
      }
      if (!RegExp(r'[0-9]').hasMatch(password)) {
        _showSnackBar('Password must contain at least one number.');
        return;
      }
      if (!RegExp(r'[!@#\$&*~%\^\-\+]').hasMatch(password)) {
        _showSnackBar('Password must contain at least one special character.');
        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    try {

      // ========================================================
      // CREATE BUSINESS
      // ========================================================

      if (authMode == AuthMode.createBusiness) {
        final response = await SupabaseService().signUpBusinessAdmin(
          email: email,
          password: password,
          fullName: fullNameController.text.trim(),
          businessName: businessNameController.text.trim(),
          industry: industryController.text.trim().isEmpty
              ? 'Technology'
              : industryController.text.trim(),
          phone: phoneController.text.trim(),
          country: countryController.text.trim().isEmpty
              ? 'United States'
              : countryController.text.trim(),
        );

        if (!mounted) return;

        if (response.session == null) {
          // Email confirmation required — stay on login page
          _showSnackBar(
            'Business account created! Please check your email to confirm your account.',
            isError: false,
          );
          return;
        }

        // Session is live — AuthGate will handle navigation via onAuthStateChange.
        // Show a success message but DON'T return early, so the finally block runs
        // and the auth state listener picks up the new session.
        _showSnackBar(
          'Business account created successfully! Logging in...',
          isError: false,
        );

      // ========================================================
      // ACCEPT INVITATION
      // ========================================================

      } else if (authMode == AuthMode.acceptInvite) {
        await SupabaseService().acceptInvitation(
          token: inviteTokenController.text.trim(),
          email: email,
          password: password,
          fullName: fullNameController.text.trim(),
        );

        if (!mounted) return;

        _showSnackBar(
          'Invitation accepted successfully! Logging in...',
          isError: false,
        );
        // AuthGate will handle navigation via onAuthStateChange.

      // ========================================================
      // SIGN IN
      // ========================================================

      } else {
        await SupabaseService().signInWithEmail(
          email: email,
          password: password,
        );

        final actualRole = SupabaseService().currentRole;
        final expectedRoleStr = selectedRole.name;

        if (actualRole != expectedRoleStr) {
          await SupabaseService().client.auth.signOut();
          throw Exception(
              'Access denied. You are registered as an $actualRole, but tried to log in as a $expectedRoleStr.');
        }

        final user = SupabaseService().currentUser;
        final userName = user?.userMetadata?['full_name'] as String? ?? 'User';

        if (!mounted) return;

        _showSnackBar(
          'Welcome back, $userName ($email)!',
          isError: false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      final message = AuthErrorHandler.getFriendlyMessage(e);

      _showSnackBar(
        message.isEmpty
            ? 'Authentication failed. Please try again.'
            : message,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(
      text: emailController.text.trim(),
    );

    bool sending = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Reset Password',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your registered email address. '
                    'We will send you a password reset link.',
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: controller,
                    keyboardType:
                        TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final email =
                              controller.text.trim();

                          if (email.isEmpty) {
                            _showSnackBar(
                              'Please enter your email address.',
                            );
                            return;
                          }

                          setDialogState(() {
                            sending = true;
                          });

                          try {
                            await SupabaseService()
                                .resetPassword(email);

                            if (!mounted) return;

                            Navigator.pop(dialogContext);

                            _showSnackBar(
                              'Password reset email sent. '
                              'Please check your inbox.',
                              isError: false,
                            );
                          } catch (e) {
                            setDialogState(() {
                              sending = false;
                            });

                            _showSnackBar(
                              e.toString()
                                  .replaceAll(
                                    'AuthException:',
                                    '',
                                  )
                                  .replaceAll(
                                    'Exception:',
                                    '',
                                  )
                                  .trim(),
                            );
                          }
                        },
                  child: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Send Reset Link',
                        ),
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

  void _showSnackBar(
    String message, {
    bool isError = true,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.redAccent.shade700
            : Colors.green.shade700,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final bool isMobile = width < 600;

            final double horizontalPadding =
                width < 400
                    ? 12
                    : isMobile
                        ? 20
                        : 32;

            final double cardPadding =
                isMobile ? 20 : 32;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),

                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 520,
                  ),

                  child: Card(
                    elevation: 8,

                    shadowColor:
                        Colors.deepPurple.withOpacity(0.12),

                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(24),
                    ),

                    child: Padding(
                      padding:
                          EdgeInsets.all(cardPadding),

                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ==================================================
                          // LOGO
                          // ==================================================

                          Container(
                            width: 64,
                            height: 64,

                            decoration: BoxDecoration(
                              color: Colors.deepPurple
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),

                            child: const Icon(
                              Icons.business_center_outlined,
                              size: 32,
                              color: Colors.deepPurple,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ==================================================
                          // TITLE
                          // ==================================================

                          Text(
                            authMode ==
                                    AuthMode.createBusiness
                                ? 'Create Your Business'
                                : authMode ==
                                        AuthMode.acceptInvite
                                    ? 'Join Organization'
                                    : 'Business Management',

                            textAlign: TextAlign.center,

                            style: TextStyle(
                              fontSize:
                                  isMobile ? 22 : 26,
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Colors.deepPurple,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            authMode ==
                                    AuthMode.createBusiness
                                ? 'Create your organization and administrator account.'
                                : authMode ==
                                        AuthMode.acceptInvite
                                    ? 'Use your invitation code to join your organization.'
                                    : 'Sign in to manage your business.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ==================================================
                          // ROLE SELECTOR
                          // ==================================================

                          _buildRoleSelector(),

                          const SizedBox(height: 20),

                          // ==================================================
                          // MODE SELECTOR
                          // ==================================================

                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,

                            children: [
                              _buildModeChip(
                                'Sign In',
                                AuthMode.signIn,
                              ),

                              if (selectedRole ==
                                  AuthRole.admin)
                                _buildModeChip(
                                  'Create Business',
                                  AuthMode.createBusiness,
                                ),

                              _buildModeChip(
                                'Invitation',
                                AuthMode.acceptInvite,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ==================================================
                          // BUSINESS CREATION FIELDS
                          // ==================================================

                          if (authMode ==
                              AuthMode.createBusiness) ...[
                            _buildField(
                              controller:
                                  fullNameController,
                              label: 'Admin Full Name',
                              icon: Icons.person_outline,
                            ),

                            const SizedBox(height: 12),

                            _buildField(
                              controller:
                                  businessNameController,
                              label: 'Business Name',
                              icon: Icons.domain_outlined,
                            ),

                            const SizedBox(height: 12),

                            _buildField(
                              controller:
                                  industryController,
                              label: 'Industry',
                              icon:
                                  Icons.category_outlined,
                            ),

                            const SizedBox(height: 12),

                            _buildField(
                              controller:
                                  phoneController,
                              label: 'Phone',
                              icon: Icons.phone_outlined,
                              keyboardType:
                                  TextInputType.phone,
                            ),

                            const SizedBox(height: 12),

                            _buildField(
                              controller:
                                  countryController,
                              label: 'Country',
                              icon:
                                  Icons.public_outlined,
                            ),

                            const SizedBox(height: 12),
                          ],

                          // ==================================================
                          // INVITATION FIELDS
                          // ==================================================

                          if (authMode ==
                              AuthMode.acceptInvite) ...[
                            _buildField(
                              controller:
                                  inviteTokenController,
                              label: 'Invitation Token',
                              icon:
                                  Icons.vpn_key_outlined,
                            ),

                            const SizedBox(height: 12),

                            _buildField(
                              controller:
                                  fullNameController,
                              label: 'Your Full Name',
                              icon:
                                  Icons.person_outline,
                            ),

                            const SizedBox(height: 12),
                          ],

                          // ==================================================
                          // EMAIL
                          // ==================================================

                          _buildField(
                            controller:
                                emailController,
                            label: 'Email Address',
                            icon:
                                Icons.email_outlined,
                            keyboardType:
                                TextInputType.emailAddress,
                          ),

                          const SizedBox(height: 12),

                          // ==================================================
                          // PASSWORD
                          // ==================================================

                          _buildField(
                            controller:
                                passwordController,
                            label: 'Password',
                            icon:
                                Icons.lock_outline,
                            obscureText:
                                obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons
                                        .visibility_off_outlined
                                    : Icons
                                        .visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword =
                                      !obscurePassword;
                                });
                              },
                            ),
                          ),

                          // ==================================================
                          // FORGOT PASSWORD & REMEMBER ME
                          // ==================================================

                          if (authMode == AuthMode.signIn)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 8),

                          // ==================================================
                          // SUBMIT BUTTON
                          // ==================================================

                          SizedBox(
                            width: double.infinity,
                            height: 52,

                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : handleAuthSubmit,

                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.deepPurple,
                                foregroundColor:
                                    Colors.white,

                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                ),
                              ),

                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            Colors.white,
                                      ),
                                    )
                                  : Text(
                                      authMode ==
                                              AuthMode
                                                  .createBusiness
                                          ? 'Create Business'
                                          : authMode ==
                                                  AuthMode
                                                      .acceptInvite
                                              ? 'Join Organization'
                                              : 'Sign In',

                                      style:
                                          const TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ==================================================
                          // FOOTER
                          // ==================================================

                          Text(
                            'Secure business management powered by Supabase',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
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

  // ============================================================
  // ROLE SELECTOR
  // ============================================================

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),

      decoration: BoxDecoration(
        color: const Color(0xFFEEEEF5),
        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          _buildRoleTab(
            AuthRole.admin,
            'Admin',
            Icons.admin_panel_settings_outlined,
          ),
          
          _buildRoleTab(
            AuthRole.employee,
            'Employee',
            Icons.badge_outlined,
          ),

          _buildRoleTab(
            AuthRole.client,
            'Client',
            Icons.business_center_outlined,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROLE TAB
  // ============================================================

  Widget _buildRoleTab(
    AuthRole role,
    String title,
    IconData icon,
  ) {
    final bool selected = selectedRole == role;

    return Expanded(
      child: GestureDetector(
        onTap: isLoading
            ? null
            : () {
                setState(() {
                  selectedRole = role;

                  // Client cannot create a business.
                  if (role == AuthRole.client &&
                      authMode ==
                          AuthMode.createBusiness) {
                    authMode = AuthMode.signIn;
                  }
                });
              },

        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 200),

          padding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 8,
          ),

          decoration: BoxDecoration(
            color: selected
                ? Colors.deepPurple
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),

          child: FittedBox(
            fit: BoxFit.scaleDown,

            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? Colors.white
                      : Colors.black54,
                ),

                const SizedBox(width: 6),

                Text(
                  title,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.black54,
                    fontWeight:
                        FontWeight.bold,
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
  // MODE CHIP
  // ============================================================

  Widget _buildModeChip(
    String title,
    AuthMode mode,
  ) {
    return FilterChip(
      label: Text(title),

      selected: authMode == mode,

      onSelected: isLoading
          ? null
          : (_) {
              setState(() {
                authMode = mode;
              });
            },

      selectedColor:
          Colors.deepPurple.withOpacity(0.15),

      checkmarkColor: Colors.deepPurple,
    );
  }

  // ============================================================
  // TEXT FIELD
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

      textInputAction:
          TextInputAction.next,

      decoration: InputDecoration(
        labelText: label,

        prefixIcon: Icon(icon),

        suffixIcon: suffixIcon,

        filled: true,

        fillColor:
            const Color(0xFFF8F8FC),

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),

          borderSide: BorderSide.none,
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),

          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),

          borderSide: const BorderSide(
            color: Colors.deepPurple,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
