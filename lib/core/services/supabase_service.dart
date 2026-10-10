import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Current operational state of the backend service.
enum SupabaseBackendState {
  /// Operating 100% offline. No credentials provided or demo mode forced.
  offlineDemo,

  /// Valid credentials provided and Supabase client successfully initialized.
  configured,

  /// Credentials provided but client initialization or network verification failed.
  unavailable,
}

/// Central gateway service managing the Supabase Flutter client.
///
/// Designed with offline-first resiliency:
/// - Never crashes the application if credentials are missing or invalid.
/// - Gracefully falls back to [SupabaseBackendState.offlineDemo].
/// - Never contains hard-coded secrets or credentials.
/// - Isolates all direct Supabase SDK interaction from UI widgets.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();

  SupabaseBackendState _state = SupabaseBackendState.offlineDemo;
  String? _lastError;
  bool _initialized = false;

  SupabaseService._internal();

  /// Current backend operational state.
  SupabaseBackendState get state => _state;

  /// Whether Supabase is active and ready for cloud requests.
  bool get isConfigured => _state == SupabaseBackendState.configured;

  /// Whether the app is running in offline demo mode.
  bool get isOffline => _state == SupabaseBackendState.offlineDemo;

  /// Error message if initialization or network connectivity failed.
  String? get lastError => _lastError;

  /// Active [SupabaseClient] instance, or null if running in offline mode.
  SupabaseClient? get client {
    if (!isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initializes the Supabase client according to [AppConfig].
  ///
  /// If [config.isSupabaseConfigured] is false, transitions safely to
  /// [SupabaseBackendState.offlineDemo] without throwing exceptions.
  Future<void> initialize(AppConfig config) async {
    _lastError = null;

    if (!config.isSupabaseConfigured) {
      _state = SupabaseBackendState.offlineDemo;
      _initialized = true;
      developer.log(
        'GuardCall starting in OFFLINE DEMO mode. Supabase not configured.',
        name: 'SupabaseService',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: config.supabaseAnonKey,
        debug: false,
      );
      _state = SupabaseBackendState.configured;
      _initialized = true;
      developer.log(
        'Supabase initialized successfully.',
        name: 'SupabaseService',
      );
    } catch (e) {
      _state = SupabaseBackendState.unavailable;
      _lastError = e.toString();
      _initialized = true;
      developer.log(
        'Supabase initialization failed: $e. Falling back to offline mode.',
        name: 'SupabaseService',
        error: e,
      );
    }
  }

  /// Resets the service state for testing purposes.
  void resetForTesting() {
    _state = SupabaseBackendState.offlineDemo;
    _lastError = null;
    _initialized = false;
  }

  /// Whether [initialize] has been called at least once.
  bool get isInitialized => _initialized;
}
