import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/app_data_store.dart';
import 'main_shell.dart';
import 'client_shell.dart';

enum AuthRole { admin, employee, client }
enum AuthMode { signIn, createBusiness, acceptInvite }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for Sign In
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Controllers for Business Creation (Admin)
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController industryController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController countryController = TextEditingController();

  // Controller for Invitations
  final TextEditingController inviteTokenController = TextEditingController();

  AuthRole selectedRole = AuthRole.admin;
  AuthMode authMode = AuthMode.signIn;
  bool obscurePassword = true;
  bool isLoading = false;

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

  Future<void> handleAuthSubmit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (authMode == AuthMode.signIn) {
      if (email.isEmpty || password.isEmpty) {
        _showSnackBar('Please enter your email address and password');
        return;
      }
    } else if (authMode == AuthMode.createBusiness) {
      if (email.isEmpty ||
          password.isEmpty ||
          fullNameController.text.trim().isEmpty ||
          businessNameController.text.trim().isEmpty) {
        _showSnackBar('Please fill in all required business creation fields');
        return;
      }
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters long');
      return;
    }

    setState(() => isLoading = true);

    try {
      if (authMode == AuthMode.createBusiness) {
        // Create new organization & register user as Business Admin
        await SupabaseService().signUpBusinessAdmin(
          email: email,
          password: password,
          fullName: fullNameController.text.trim(),
          businessName: businessNameController.text.trim(),
          industry: industryController.text.trim().isEmpty ? 'Technology' : industryController.text.trim(),
          phone: phoneController.text.trim(),
          country: countryController.text.trim().isEmpty ? 'United States' : countryController.text.trim(),
        );
        await AppDataStore().refreshFromSupabase();
        if (!mounted) return;
        _showSnackBar('Organization & Admin account created successfully!', isError: false);
        _navigateToShell(AuthRole.admin);
      } else if (authMode == AuthMode.acceptInvite) {
        final token = inviteTokenController.text.trim();
        if (token.isEmpty) {
          _showSnackBar('Please enter your invitation code/token');
          return;
        }
        await SupabaseService().acceptInvitation(
          token: token,
          password: password,
          fullName: fullNameController.text.trim(),
        );
        await AppDataStore().refreshFromSupabase();
        if (!mounted) return;
        _showSnackBar('Invitation accepted! Welcome to the team.', isError: false);
        _navigateToShell(selectedRole);
      } else {
        // Strict Database Sign In
        final res = await SupabaseService().signInWithEmail(
          email: email,
          password: password,
        );
        await AppDataStore().refreshFromSupabase();

        if (!mounted) return;

        if (res.user != null) {
          final userRole = SupabaseService().currentRole;
          final roleEnum = userRole == 'client'
              ? AuthRole.client
              : (userRole == 'employee' ? AuthRole.employee : AuthRole.admin);

          _showSnackBar('Welcome back!', isError: false);
          _navigateToShell(roleEnum);
        } else {
          _showSnackBar('Login failed: Invalid email or password', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('rate limit') || errStr.contains('rate_limit') || errStr.contains('over_email_send_rate_limit')) {
          _showSnackBar('Supabase default email rate limit reached (max 3-4 emails/hr). Please wait a few minutes or disable "Confirm Email" in Supabase settings.', isError: true);
        } else {
          final msg = e.toString().replaceAll('AuthException:', '').replaceAll('Exception:', '').trim();
          _showSnackBar('Authentication failed: $msg', isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _demoLogin(AuthRole role) async {
    final demoEmail = role == AuthRole.admin ? 'admin@business.com' : 'client@acme.com';
    final demoPassword = role == AuthRole.admin ? 'admin123' : 'client123';

    emailController.text = demoEmail;
    passwordController.text = demoPassword;

    setState(() => isLoading = true);
    try {
      final res = await SupabaseService().signInWithEmail(
        email: demoEmail,
        password: demoPassword,
      );
      await AppDataStore().refreshFromSupabase();

      if (!mounted) return;

      if (res.user != null) {
        final userRole = SupabaseService().currentRole;
        final roleEnum = userRole == 'client'
            ? AuthRole.client
            : (userRole == 'employee' ? AuthRole.employee : AuthRole.admin);

        _showSnackBar('Logged in as ${role == AuthRole.client ? "Client" : "Admin"}', isError: false);
        _navigateToShell(roleEnum);
      } else {
        _showSnackBar('Demo user not found in database. Please click "Create Business".', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Account not found in database: ${e.toString().replaceAll('AuthException:', '').trim()}. Use "Create Business" to register.', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _navigateToShell(AuthRole role) {
    if (role == AuthRole.client) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ClientShell()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainShell()),
      );
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: emailController.text.trim());

    showDialog(
      context: context,
      builder: (context) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter your registered email address below. We will send password reset instructions to your inbox.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
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
                  onPressed: isSending
                      ? null
                      : () async {
                          final email = resetEmailController.text.trim();
                          if (email.isEmpty) {
                            _showSnackBar('Please enter your email address', isError: true);
                            return;
                          }
                          setDialogState(() => isSending = true);
                          try {
                            await SupabaseService().resetPassword(email);
                            if (mounted) {
                              Navigator.pop(context);
                              _showSnackBar('Password reset email sent! Check your inbox.', isError: false);
                            }
                          } catch (e) {
                            setDialogState(() => isSending = false);
                            _showSnackBar('Error sending reset link: ${e.toString().replaceAll('AuthException:', '').trim()}', isError: true);
                          }
                        },
                  child: isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send Reset Link'),
                ),
              ],
            );
          },
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final activeThemeColor = selectedRole == AuthRole.client ? Colors.indigo : Colors.deepPurple;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 480;
            final horizontalPadding = isMobile ? 12.0 : 24.0;
            final cardPadding = isMobile ? 16.0 : 28.0;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    elevation: 8,
                    shadowColor: activeThemeColor.withOpacity(0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Role Selector Bar
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEEEF5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                _buildRoleTab(AuthRole.admin, 'Business / Admin', Icons.admin_panel_settings),
                                _buildRoleTab(AuthRole.client, 'Client Portal', Icons.business_center),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Header Icon & Title
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: activeThemeColor.withOpacity(0.1),
                            child: Icon(
                              selectedRole == AuthRole.client ? Icons.business_center_outlined : Icons.shield_outlined,
                              color: activeThemeColor,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            authMode == AuthMode.createBusiness
                                ? 'Register New Business'
                                : (authMode == AuthMode.acceptInvite
                                    ? 'Accept Invitation'
                                    : '${selectedRole == AuthRole.admin ? "Business & Admin" : "Client"} Login'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 22,
                              fontWeight: FontWeight.bold,
                              color: activeThemeColor,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Action Chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              FilterChip(
                                label: const Text('Sign In'),
                                selected: authMode == AuthMode.signIn,
                                onSelected: (_) => setState(() => authMode = AuthMode.signIn),
                              ),
                              if (selectedRole == AuthRole.admin)
                                FilterChip(
                                  label: const Text('Create Business'),
                                  selected: authMode == AuthMode.createBusiness,
                                  onSelected: (_) => setState(() => authMode = AuthMode.createBusiness),
                                ),
                              FilterChip(
                                label: const Text('Invite Code'),
                                selected: authMode == AuthMode.acceptInvite,
                                onSelected: (_) => setState(() => authMode = AuthMode.acceptInvite),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Form Fields
                          if (authMode == AuthMode.createBusiness) ...[
                            _buildField(fullNameController, 'Admin Full Name', Icons.person_outline),
                            const SizedBox(height: 12),
                            _buildField(businessNameController, 'Business Name', Icons.domain),
                            const SizedBox(height: 12),
                            _buildField(industryController, 'Industry', Icons.category_outlined),
                            const SizedBox(height: 12),
                            _buildField(phoneController, 'Contact Phone', Icons.phone_outlined),
                            const SizedBox(height: 12),
                          ],

                          if (authMode == AuthMode.acceptInvite) ...[
                            _buildField(inviteTokenController, 'Invitation Token', Icons.vpn_key_outlined),
                            const SizedBox(height: 12),
                            _buildField(fullNameController, 'Your Full Name', Icons.person_outline),
                            const SizedBox(height: 12),
                          ],

                          // Email & Password Fields
                          _buildField(emailController, 'Email Address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _buildField(
                            passwordController,
                            'Password',
                            Icons.lock_outline,
                            obscureText: obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => obscurePassword = !obscurePassword),
                            ),
                          ),

                          if (authMode == AuthMode.signIn) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: activeThemeColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : handleAuthSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activeThemeColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isLoading
                                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        authMode == AuthMode.createBusiness
                                            ? 'Create Business & Launch Workspace'
                                            : (authMode == AuthMode.acceptInvite ? 'Join Organization' : 'Sign In'),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),

                          // Quick Demo Logins
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _demoLogin(AuthRole.admin),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Demo Admin', style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _demoLogin(AuthRole.client),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Demo Client', style: TextStyle(fontSize: 12)),
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

  Widget _buildRoleTab(AuthRole role, String title, IconData icon) {
    final isSelected = selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? (role == AuthRole.client ? Colors.indigo : Colors.deepPurple) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.black54),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
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

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8F8FC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
