import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:business_managment_app/shared/login_page.dart';
import 'package:business_managment_app/client/client_shell.dart';
import 'package:business_managment_app/shared/main_shell.dart';
import 'package:business_managment_app/services/supabase_service.dart';
import 'package:business_managment_app/services/app_data_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://sgadxqxwavjgnxmofeaw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnYWR4cXh3YXZqZ254bW9mZWF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5OTY5MDAsImV4cCI6MjEwMTU3MjkwMH0.MSJlyKMzEMtQPK56Wvd_4SLApclyVzrKvLVA9mHShZw',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppDataStore _store = AppDataStore();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChange);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChange);
    super.dispose();
  }

  void _onStoreChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Business Management Suite',

      themeMode: _store.themeMode,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121218),
        cardColor: const Color(0xFF1E1E26),
        useMaterial3: true,
      ),

      home: const AuthGate(),
    );
  }
}


// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;
  bool _isLoading = true;
  String? _role;
  String? _error;
  int _authRequestId = 0;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        _initializeAuth();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _initializeAuth() async {
    final requestId = ++_authRequestId;
    try {
      final supabase = Supabase.instance.client;

      final session = supabase.auth.currentSession;

      // --------------------------------------------------------
      // No logged-in user
      // --------------------------------------------------------
      if (session == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _role = null;
          });
        }
        return;
      }
      // --------------------------------------------------------
      // Load organization + role
      // --------------------------------------------------------
      // Wait if the UI is actively creating an account or accepting an invite
      while (SupabaseService().isAuthActionInProgress) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (requestId != _authRequestId) return;
      }

      await SupabaseService().loadUserOrganizationContext();

      if (SupabaseService().currentMembership == null) {
        // The user was deleted from their organization or has no valid role.
        // Sign them out locally so they gracefully fall back to the login screen.
        await supabase.auth.signOut();
        if (mounted) {
          setState(() {
            _role = null;
            _isLoading = false;
          });
        }
        return;
      }

      // --------------------------------------------------------
      // Refresh application data
      // --------------------------------------------------------
      await AppDataStore().refreshFromSupabase();

      // Fast load transition
      await Future.delayed(const Duration(milliseconds: 100));

      if (requestId != _authRequestId) return; // Prevent race conditions

      // --------------------------------------------------------
      // Get user's role
      // --------------------------------------------------------
      final role = SupabaseService().getUserRole(session.user);

      if (mounted) {
        setState(() {
          _role = role;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (requestId != _authRequestId) return;
      debugPrint('AuthGate error: $e');

      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ----------------------------------------------------------
    // Loading
    // ----------------------------------------------------------
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.deepPurple,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cool pulsing logo or icon
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.8, end: 1.2),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: const Icon(
                  Icons.business_center,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Preparing Workspace...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // Error
    // ----------------------------------------------------------
    if (_error != null) {
      return _AuthErrorPage(
        error: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });

          _initializeAuth();
        },
      );
    }

    // ----------------------------------------------------------
    // No role/session
    // ----------------------------------------------------------
    if (_role == null) {
      return const LoginPage();
    }

    // ----------------------------------------------------------
    // Client
    // ----------------------------------------------------------
    if (_role == 'client') {
      return const ClientShell();
    }

    // ----------------------------------------------------------
    // Admin / Employee
    // ----------------------------------------------------------
    if (_role == 'admin' || _role == 'employee') {
      return MainShell();
    }

    // ----------------------------------------------------------
    // Unknown role
    // ----------------------------------------------------------
    return const LoginPage();
  }
}


// ============================================================
// AUTH ERROR PAGE
// ============================================================

class _AuthErrorPage extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _AuthErrorPage({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 500,
            ),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Unable to load your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onRetry,
                        child: const Text('Try Again'),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();

                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}