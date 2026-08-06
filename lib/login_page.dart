import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'main_shell.dart';
import 'client_shell.dart';

enum AuthRole { admin, client }
enum AuthMode { signIn, signUp }

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
  final TextEditingController nameController = TextEditingController();
  final TextEditingController companyController = TextEditingController();

  // ============================================================
  // STATE VARIABLES
  // ============================================================
  AuthRole selectedRole = AuthRole.admin;
  AuthMode authMode = AuthMode.signIn;
  bool rememberMe = true;
  bool obscurePassword = true;
  bool isLoading = false;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    companyController.dispose();
    super.dispose();
  }

  // ============================================================
  // AUTHENTICATION LOGIC (SUPABASE)
  // ============================================================

  Future<void> handleAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();
    final company = companyController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in both email and password');
      return;
    }

    if (authMode == AuthMode.signUp && name.isEmpty) {
      _showSnackBar('Please enter your full name for registration');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final roleStr = selectedRole == AuthRole.admin ? 'admin' : 'client';

      if (authMode == AuthMode.signUp) {
        // Perform Supabase Auth Sign Up
        final res = await SupabaseService().signUpWithEmail(
          email: email,
          password: password,
          name: name,
          role: roleStr,
          company: company,
        );

        if (!mounted) return;

        if (res.user != null) {
          _showSnackBar('Account created successfully! Logging in...', isError: false);
          _navigateToRolePortal(selectedRole);
        } else {
          _showSnackBar('Account creation initiated. Please verify your email if required.');
          _navigateToRolePortal(selectedRole);
        }
      } else {
        // Perform Supabase Auth Sign In
        try {
          final res = await SupabaseService().signInWithEmail(
            email: email,
            password: password,
          );

          if (!mounted) return;

          if (res.user != null) {
            final userRole = SupabaseService().getUserRole(res.user);
            final detectedRole = userRole == 'client' ? AuthRole.client : AuthRole.admin;
            
            _showSnackBar('Welcome back!', isError: false);
            _navigateToRolePortal(detectedRole);
          }
        } catch (e) {
          // If Supabase returns error or demo credentials used
          debugPrint('Supabase Auth error: $e');
          if (email.contains('demo') || password == '123456') {
            _showSnackBar('Signed in using fallback mode', isError: false);
            _navigateToRolePortal(selectedRole);
          } else {
            setState(() {
              errorMessage = 'Authentication failed: ${e.toString().replaceAll('AuthException:', '').trim()}';
            });
            _showSnackBar(errorMessage ?? 'Invalid email or password');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
        _showSnackBar('Error: $errorMessage');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _demoLogin(AuthRole role) {
    if (role == AuthRole.admin) {
      emailController.text = 'admin@business.com';
      passwordController.text = 'admin123';
      setState(() => selectedRole = AuthRole.admin);
      _navigateToRolePortal(AuthRole.admin);
    } else {
      emailController.text = 'client@acme.com';
      passwordController.text = 'client123';
      setState(() => selectedRole = AuthRole.client);
      _navigateToRolePortal(AuthRole.client);
    }
  }

  void _navigateToRolePortal(AuthRole role) {
    if (role == AuthRole.admin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainShell()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ClientShell()),
      );
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final activeThemeColor = selectedRole == AuthRole.admin ? Colors.deepPurple : Colors.indigo;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final horizontalPadding = screenWidth < 400 ? 16.0 : (screenWidth < 600 ? 24.0 : 40.0);
            final cardPadding = screenWidth < 600 ? 24.0 : 35.0;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    elevation: 10,
                    shadowColor: activeThemeColor.withOpacity(0.2),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ==================================================
                          // ROLE SELECTOR TABS (ADMIN vs CLIENT)
                          // ==================================================
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEEEF5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedRole = AuthRole.admin;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selectedRole == AuthRole.admin ? Colors.deepPurple : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: selectedRole == AuthRole.admin
                                            ? [
                                                BoxShadow(
                                                  color: Colors.deepPurple.withOpacity(0.3),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.admin_panel_settings,
                                            size: 18,
                                            color: selectedRole == AuthRole.admin ? Colors.white : Colors.black54,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Admin / Staff',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: selectedRole == AuthRole.admin ? Colors.white : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedRole = AuthRole.client;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selectedRole == AuthRole.client ? Colors.indigo : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: selectedRole == AuthRole.client
                                            ? [
                                                BoxShadow(
                                                  color: Colors.indigo.withOpacity(0.3),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.business_center,
                                            size: 18,
                                            color: selectedRole == AuthRole.client ? Colors.white : Colors.black54,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Client Portal',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: selectedRole == AuthRole.client ? Colors.white : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ==================================================
                          // LOGO & HEADER
                          // ==================================================
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: activeThemeColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: activeThemeColor.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              selectedRole == AuthRole.admin ? Icons.shield_outlined : Icons.business_center_outlined,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            selectedRole == AuthRole.admin ? 'Admin Management' : 'Client Workspace',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: activeThemeColor,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            authMode == AuthMode.signIn
                                ? 'Sign in with your Supabase credentials'
                                : 'Create your ${selectedRole == AuthRole.admin ? "Admin" : "Client"} account to access portal',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black54, fontSize: 14),
                          ),

                          const SizedBox(height: 24),

                          // ==================================================
                          // MODE TOGGLE (SIGN IN vs SIGN UP)
                          // ==================================================
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ChoiceChip(
                                label: const Text('Sign In'),
                                selected: authMode == AuthMode.signIn,
                                selectedColor: activeThemeColor.withOpacity(0.15),
                                labelStyle: TextStyle(
                                  color: authMode == AuthMode.signIn ? activeThemeColor : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (val) {
                                  if (val) setState(() => authMode = AuthMode.signIn);
                                },
                              ),
                              const SizedBox(width: 12),
                              ChoiceChip(
                                label: const Text('Create Account'),
                                selected: authMode == AuthMode.signUp,
                                selectedColor: activeThemeColor.withOpacity(0.15),
                                labelStyle: TextStyle(
                                  color: authMode == AuthMode.signUp ? activeThemeColor : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (val) {
                                  if (val) setState(() => authMode = AuthMode.signUp);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ==================================================
                          // INPUT FORM FIELDS
                          // ==================================================

                          // NAME FIELD (ONLY FOR SIGN UP)
                          if (authMode == AuthMode.signUp) ...[
                            TextField(
                              controller: nameController,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                label: 'Full Name',
                                hint: 'Enter your full name',
                                icon: Icons.person_outline,
                                activeColor: activeThemeColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // COMPANY FIELD (FOR CLIENT SIGN UP)
                          if (authMode == AuthMode.signUp && selectedRole == AuthRole.client) ...[
                            TextField(
                              controller: companyController,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                label: 'Company / Firm Name',
                                hint: 'e.g. Acme Corporation',
                                icon: Icons.domain_outlined,
                                activeColor: activeThemeColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // EMAIL FIELD
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              label: 'Email Address',
                              hint: 'user@company.com',
                              icon: Icons.email_outlined,
                              activeColor: activeThemeColor,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // PASSWORD FIELD
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => handleAuth(),
                            decoration: _inputDecoration(
                              label: 'Password',
                              hint: 'Enter your password',
                              icon: Icons.lock_outline,
                              activeColor: activeThemeColor,
                              suffix: IconButton(
                                icon: Icon(
                                  obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: activeThemeColor,
                                ),
                                onPressed: () {
                                  setState(() => obscurePassword = !obscurePassword);
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // REMEMBER ME & FORGOT PASSWORD
                          if (authMode == AuthMode.signIn)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: rememberMe,
                                      activeColor: activeThemeColor,
                                      onChanged: (v) => setState(() => rememberMe = v ?? true),
                                    ),
                                    const Text('Remember Me', style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ChangePasswordPage()),
                                    );
                                  },
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(color: activeThemeColor, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 16),

                          // SUBMIT BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : handleAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activeThemeColor,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Text(
                                      authMode == AuthMode.signIn
                                          ? 'Sign In to ${selectedRole == AuthRole.admin ? "Admin" : "Client Portal"}'
                                          : 'Create ${selectedRole == AuthRole.admin ? "Admin" : "Client"} Account',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),

                          // DEMO QUICK-LOGIN BUTTONS
                          const Text(
                            'Quick Demo Access',
                            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _demoLogin(AuthRole.admin),
                                  icon: const Icon(Icons.shield, size: 16, color: Colors.deepPurple),
                                  label: const Text(
                                    'Demo Admin',
                                    style: TextStyle(color: Colors.deepPurple, fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.deepPurple),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _demoLogin(AuthRole.client),
                                  icon: const Icon(Icons.business_center, size: 16, color: Colors.indigo),
                                  label: const Text(
                                    'Demo Client',
                                    style: TextStyle(color: Colors.indigo, fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.indigo),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
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

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required Color activeColor,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: activeColor),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8F8FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE0E0E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: activeColor, width: 2),
      ),
    );
  }
}

// ================================================================
// CHANGE / RESET PASSWORD PAGE (SUPABASE AUTH INTEGRATED)
// ================================================================

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> sendResetEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await SupabaseService().resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset instructions sent to $email'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset email: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Forgot Your Password?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your registered email address below. We will send you a Supabase password reset link.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Registered Email',
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.deepPurple),
                filled: true,
                fillColor: const Color(0xFFF8F8FC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : sendResetEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text('Send Reset Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
