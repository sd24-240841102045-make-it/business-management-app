import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream of auth state changes (logged in, logged out, etc)
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Sign up a new business (admin)
  Future<AuthResponse> signUpBusinessAdmin({
    required String email,
    required String password,
    required String fullName,
    required String businessName,
    required String industry,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'is_admin_signup': 'true',
        'full_name': fullName,
        'business_name': businessName,
        'industry': industry,
      },
    );
  }

  // Sign in
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }
}
