import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'supabase_service.dart';

/// Clean user model decoupled from external Supabase SDK types.
class AuthUser {
  final String id;
  final String email;
  final String? name;
  final DateTime? createdAt;

  const AuthUser({
    required this.id,
    required this.email,
    this.name,
    this.createdAt,
  });

  @override
  String toString() => 'AuthUser(id: $id, email: $email, name: $name)';
}

/// Active user session information.
class AuthSession {
  final String accessToken;
  final DateTime? expiresAt;
  final AuthUser user;

  const AuthSession({
    required this.accessToken,
    this.expiresAt,
    required this.user,
  });
}

/// Standardized authentication error codes.
enum AuthErrorCode {
  invalidEmail,
  invalidPassword,
  emailAlreadyRegistered,
  invalidCredentials,
  networkUnavailable,
  supabaseUnavailable,
  sessionExpired,
  unknown,
}

/// Typed authentication exception with human-readable messaging.
class AuthException implements Exception {
  final AuthErrorCode code;
  final String message;

  const AuthException(this.code, this.message);

  @override
  String toString() => 'AuthException($code): $message';
}

/// Authentication service providing unified access to Supabase Auth
/// when configured, with a safe offline/demo mode when unconfigured.
class AuthService {
  static final AuthService instance = AuthService._internal();

  AuthService._internal();

  final StreamController<AuthSession?> _authStateController =
      StreamController<AuthSession?>.broadcast();

  AuthUser? _demoUser;
  bool _isDemoLoggedIn = false;

  /// Stream emitting auth session changes.
  Stream<AuthSession?> get authStateChanges => _authStateController.stream;

  /// Whether the app is operating in offline demo mode.
  bool get isOffline => SupabaseService.instance.isOffline;

  /// Whether Supabase is active and configured.
  bool get isConfigured => SupabaseService.instance.isConfigured;

  /// Registers a new user account with email and password.
  ///
  /// Never stores passwords locally.
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final cleanEmail = email.trim();
    if (!_isValidEmail(cleanEmail)) {
      throw const AuthException(
        AuthErrorCode.invalidEmail,
        'Please enter a valid email address.',
      );
    }
    if (password.length < 6) {
      throw const AuthException(
        AuthErrorCode.invalidPassword,
        'Password must be at least 6 characters.',
      );
    }

    if (!isConfigured) {
      // Safe offline demo registration simulation
      _demoUser = AuthUser(
        id: 'demo-user-${DateTime.now().millisecondsSinceEpoch}',
        email: cleanEmail,
        name: name.trim(),
        createdAt: DateTime.now(),
      );
      _isDemoLoggedIn = true;
      _emitDemoSession();
      return _demoUser!;
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      throw const AuthException(
        AuthErrorCode.supabaseUnavailable,
        'Supabase client is not available.',
      );
    }

    try {
      final res = await client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'name': name.trim()},
      );

      final user = res.user;
      if (user == null) {
        throw const AuthException(
          AuthErrorCode.unknown,
          'User registration failed to return an account.',
        );
      }

      final authUser = AuthUser(
        id: user.id,
        email: user.email ?? cleanEmail,
        name: name.trim(),
        createdAt: DateTime.tryParse(user.createdAt),
      );

      return authUser;
    } on supa.AuthException catch (e) {
      throw _mapSupabaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        AuthErrorCode.unknown,
        'Registration error: ${e.toString()}',
      );
    }
  }

  /// Signs in an existing user with email and password.
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (!_isValidEmail(cleanEmail)) {
      throw const AuthException(
        AuthErrorCode.invalidEmail,
        'Please enter a valid email address.',
      );
    }
    if (password.isEmpty) {
      throw const AuthException(
        AuthErrorCode.invalidPassword,
        'Password cannot be empty.',
      );
    }

    if (!isConfigured) {
      // Safe offline demo sign in
      _demoUser = AuthUser(
        id: 'demo-user-offline',
        email: cleanEmail,
        name: 'Demo User',
        createdAt: DateTime.now(),
      );
      _isDemoLoggedIn = true;
      final session = _buildDemoSession();
      _authStateController.add(session);
      return session;
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      throw const AuthException(
        AuthErrorCode.supabaseUnavailable,
        'Supabase client is not available.',
      );
    }

    try {
      final res = await client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      final session = res.session;
      final user = res.user;

      if (session == null || user == null) {
        throw const AuthException(
          AuthErrorCode.invalidCredentials,
          'Invalid email or password.',
        );
      }

      final authUser = AuthUser(
        id: user.id,
        email: user.email ?? cleanEmail,
        name: user.userMetadata?['name'] as String?,
        createdAt: DateTime.tryParse(user.createdAt),
      );

      final authSession = AuthSession(
        accessToken: session.accessToken,
        expiresAt: session.expiresAt != null
            ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
            : null,
        user: authUser,
      );

      developer.log(
        'AUTH_VERIFIED: login success userId=${user.id} email=${user.email}',
        name: 'AuthService',
      );

      _authStateController.add(authSession);
      return authSession;
    } on supa.AuthException catch (e) {
      throw _mapSupabaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        AuthErrorCode.unknown,
        'Sign in failed: ${e.toString()}',
      );
    }
  }

  /// Signs out the currently authenticated user.
  Future<void> signOut() async {
    if (!isConfigured) {
      _demoUser = null;
      _isDemoLoggedIn = false;
      _authStateController.add(null);
      return;
    }

    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.auth.signOut();
        developer.log('AUTH_VERIFIED: logout success', name: 'AuthService');
      } catch (_) {
        // Silently continue local state clearance
      }
    }

    _authStateController.add(null);
  }

  /// Obtains the current authenticated user if one exists.
  AuthUser? getCurrentUser() {
    if (!isConfigured) {
      return _isDemoLoggedIn ? _demoUser : null;
    }

    final client = SupabaseService.instance.client;
    final supaUser = client?.auth.currentUser;
    if (supaUser == null) return null;

    return AuthUser(
      id: supaUser.id,
      email: supaUser.email ?? '',
      name: supaUser.userMetadata?['name'] as String?,
      createdAt: DateTime.tryParse(supaUser.createdAt),
    );
  }

  /// Obtains the current active session if one exists.
  AuthSession? getCurrentSession() {
    if (!isConfigured) {
      return _isDemoLoggedIn ? _buildDemoSession() : null;
    }

    final client = SupabaseService.instance.client;
    final session = client?.auth.currentSession;
    final user = client?.auth.currentUser;

    if (session == null || user == null) return null;

    developer.log(
      'AUTH_VERIFIED: session restored userId=${user.id}',
      name: 'AuthService',
    );

    return AuthSession(
      accessToken: session.accessToken,
      expiresAt: session.expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
          : null,
      user: AuthUser(
        id: user.id,
        email: user.email ?? '',
        name: user.userMetadata?['name'] as String?,
        createdAt: DateTime.tryParse(user.createdAt),
      ),
    );
  }

  /// Activates explicit demo mode credentials for offline exploration.
  void enterDemoMode() {
    _demoUser = const AuthUser(
      id: 'demo-user-offline',
      email: 'demo@guardcall.local',
      name: 'Demo User',
    );
    _isDemoLoggedIn = true;
    _emitDemoSession();
  }

  void _emitDemoSession() {
    _authStateController.add(_buildDemoSession());
  }

  AuthSession _buildDemoSession() {
    return AuthSession(
      accessToken: 'offline-demo-token',
      expiresAt: DateTime.now().add(const Duration(days: 365)),
      user: _demoUser ??
          const AuthUser(
            id: 'demo-user-offline',
            email: 'demo@guardcall.local',
            name: 'Demo User',
          ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  AuthException _mapSupabaseAuthException(supa.AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid username or password')) {
      return const AuthException(
        AuthErrorCode.invalidCredentials,
        'Incorrect email or password. Please try again.',
      );
    }
    if (msg.contains('already registered') ||
        msg.contains('user already exists')) {
      return const AuthException(
        AuthErrorCode.emailAlreadyRegistered,
        'An account with this email already exists.',
      );
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return const AuthException(
        AuthErrorCode.networkUnavailable,
        'Network error. Please check your internet connection.',
      );
    }
    if (msg.contains('invalid email')) {
      return const AuthException(
        AuthErrorCode.invalidEmail,
        'Please enter a valid email address.',
      );
    }
    if (msg.contains('password')) {
      return AuthException(
        AuthErrorCode.invalidPassword,
        e.message,
      );
    }
    return AuthException(
      AuthErrorCode.unknown,
      e.message,
    );
  }

  /// Clears demo state for unit testing.
  void resetForTesting() {
    _demoUser = null;
    _isDemoLoggedIn = false;
  }
}
