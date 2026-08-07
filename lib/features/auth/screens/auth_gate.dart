import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth_service.dart';
import 'login_screen.dart';

// Note: Replace with your actual home screen
import '../../../main_shell.dart'; 

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final session = snapshot.data?.session;
        if (session != null) {
          // User is logged in
          return const MainShell();
        }

        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}
