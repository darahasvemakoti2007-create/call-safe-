import 'package:flutter/material.dart';
import '../core/services/auth_state.dart';
import '../features/auth/login_screen.dart';
import 'app_navigation.dart';
import 'app_theme.dart';

/// The root application widget for GuardCall.
class GuardCallApp extends StatelessWidget {
  const GuardCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuardCall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}

/// Lightweight authentication gate determining startup destination.
///
/// Ensures offline demo mode seamlessly launches the main application,
/// while cloud-configured environments present authentication with an
/// explicit demo fallback.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthState.instance,
      builder: (context, _) {
        final auth = AuthState.instance;

        // 1. In offline/demo mode, immediately grant access to full app
        if (auth.isOfflineDemo) {
          return const AppNavigation();
        }

        // 2. Authenticated via cloud backend
        if (auth.isAuthenticated) {
          return const AppNavigation();
        }

        // 3. Loading initial session
        if (auth.isLoading) {
          return const Scaffold(
            backgroundColor: AppTheme.navyBackground,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.tealPrimary),
            ),
          );
        }

        // 4. Supabase is configured and waiting for user login
        return const LoginScreen();
      },
    );
  }
}
