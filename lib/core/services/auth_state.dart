import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'profile_service.dart';

/// Application-level authentication status.
enum AuthStatus {
  /// User is not authenticated with any account.
  unauthenticated,

  /// User is actively authenticated via Supabase cloud.
  authenticated,

  /// Operating in offline/demo mode without remote auth requirements.
  offlineDemo,

  /// In the middle of an authentication operation or checking initial session.
  loading,
}

/// Global authentication state notifier for GuardCall.
///
/// Provides a reactive bridge between [AuthService], [ProfileService],
/// and Flutter UI widgets without complex state management dependencies.
class AuthState extends ChangeNotifier {
  static final AuthState instance = AuthState._internal();

  AuthStatus _status = AuthStatus.loading;
  AuthUser? _currentUser;
  UserProfile? _currentProfile;
  String? _errorMessage;
  StreamSubscription<AuthSession?>? _authSubscription;

  AuthState._internal() {
    _initialize();
  }

  /// Current authentication status.
  AuthStatus get status => _status;

  /// Whether user is authenticated or in demo mode.
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isOfflineDemo => _status == AuthStatus.offlineDemo;
  bool get isUnauthenticated => _status == AuthStatus.unauthenticated;
  bool get isLoading => _status == AuthStatus.loading;

  /// Current user details if available.
  AuthUser? get currentUser => _currentUser;

  /// Current profile details if available.
  UserProfile? get currentProfile => _currentProfile;

  /// Display name to show across the UI.
  String get displayName =>
      _currentProfile?.name ??
      _currentUser?.name ??
      (isOfflineDemo ? 'Demo User' : 'Guest');

  /// Most recent authentication error message.
  String? get errorMessage => _errorMessage;

  /// Checks the initial session state and listens for auth changes.
  Future<void> _initialize() async {
    _status = AuthStatus.loading;
    notifyListeners();

    if (AuthService.instance.isOffline) {
      // In offline mode, default to safe demo mode
      _status = AuthStatus.offlineDemo;
      _currentUser = const AuthUser(
        id: 'demo-user-offline',
        email: 'demo@guardcall.local',
        name: 'Demo User',
      );
      _currentProfile = await ProfileService.instance.getProfile('demo-user-offline');
      notifyListeners();
      return;
    }

    final session = AuthService.instance.getCurrentSession();
    if (session != null) {
      _status = AuthStatus.authenticated;
      _currentUser = session.user;
      _currentProfile = await ProfileService.instance.getProfile(session.user.id);
    } else {
      _status = AuthStatus.unauthenticated;
      _currentUser = null;
      _currentProfile = null;
    }

    _authSubscription = AuthService.instance.authStateChanges.listen((session) async {
      if (session != null) {
        _status = AuthStatus.authenticated;
        _currentUser = session.user;
        _currentProfile = await ProfileService.instance.getProfile(session.user.id);
      } else {
        if (!AuthService.instance.isConfigured) {
          _status = AuthStatus.offlineDemo;
        } else {
          _status = AuthStatus.unauthenticated;
          _currentUser = null;
          _currentProfile = null;
        }
      }
      notifyListeners();
    });

    notifyListeners();
  }

  /// Attempts to sign in with email and password.
  Future<bool> signIn({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await AuthService.instance.signIn(
        email: email,
        password: password,
      );

      if (AuthService.instance.isConfigured) {
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.offlineDemo;
      }

      _currentUser = session.user;
      _currentProfile = await ProfileService.instance.getProfile(session.user.id);
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'An unexpected sign in error occurred.';
      notifyListeners();
      return false;
    }
  }

  /// Attempts to create an account and corresponding profile.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await AuthService.instance.signUp(
        email: email,
        password: password,
        name: name,
      );

      // Create initial profile row and default user_settings row
      final profile = await ProfileService.instance.createProfile(
        id: user.id,
        name: name,
      );

      if (AuthService.instance.isConfigured) {
        // If session was granted immediately (email confirmation disabled in Supabase):
        final session = AuthService.instance.getCurrentSession();
        if (session != null) {
          _status = AuthStatus.authenticated;
          _currentUser = session.user;
          _currentProfile = profile;
        } else {
          // Email confirmation is required by Supabase!
          _status = AuthStatus.unauthenticated;
          _errorMessage =
              'Registration successful! Please check your email to confirm your account.';
        }
      } else {
        _status = AuthStatus.offlineDemo;
        _currentUser = user;
        _currentProfile = profile;
      }

      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'An unexpected registration error occurred: $e';
      notifyListeners();
      return false;
    }
  }

  /// Continues into GuardCall in offline/demo mode without credentials.
  void continueInDemoMode() {
    _status = AuthStatus.offlineDemo;
    _currentUser = const AuthUser(
      id: 'demo-user-offline',
      email: 'demo@guardcall.local',
      name: 'Demo User',
    );
    _currentProfile = const UserProfile(
      id: 'demo-user-offline',
      name: 'Demo User',
    );
    AuthService.instance.enterDemoMode();
    notifyListeners();
  }

  /// Signs out the user and transitions to unauthenticated state.
  Future<void> signOut() async {
    await AuthService.instance.signOut();
    _currentUser = null;
    _currentProfile = null;
    _status = AuthService.instance.isConfigured
        ? AuthStatus.unauthenticated
        : AuthStatus.offlineDemo;
    notifyListeners();
  }

  /// Manually clears error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets mock authentication state for testing purposes.
  @visibleForTesting
  void setMockUser({AuthUser? user, UserProfile? profile, AuthStatus? status}) {
    _currentUser = user;
    _currentProfile = profile;
    if (status != null) _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
