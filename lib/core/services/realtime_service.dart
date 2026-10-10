import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'family_alert_service.dart';
import 'supabase_service.dart';

/// Operational connection state for Realtime listeners.
enum RealtimeAlertState {
  disconnected,
  connecting,
  subscribed,
  error,
}

/// Service managing Supabase Realtime WebSocket subscriptions for emergency alert events.
///
/// ZERO-TRUST RLS COMPLIANCE & ARCHITECTURAL BOUNDARY:
/// - A client listener NEVER subscribes to a global unfiltered stream.
/// - Only subscribes to the authenticated user's channel/filter.
/// - Database-level RLS policies on `public.alerts` strictly enforce that a client
///   only receives rows matching `call_sessions.user_id = auth.uid()`.
///
/// CAREGIVER RECIPIENT LIMITATION NOTICE:
/// - In the current Step 8 schema, `public.family_contacts` stores contact strings
///   (`contact_identifier`) without a foreign key to a separate caregiver Supabase Auth ID.
/// - Therefore, this listener safely enables the caller to monitor their own alert
///   lifecycle state (e.g. status changes). External family recipient delivery must be
///   handled via backend webhooks / push notifications rather than weakening client RLS.
class RealtimeService {
  static final RealtimeService instance = RealtimeService._internal();

  RealtimeService._internal();

  final StreamController<FamilyAlertRecord> _alertController =
      StreamController<FamilyAlertRecord>.broadcast();

  final StreamController<RealtimeAlertState> _statusController =
      StreamController<RealtimeAlertState>.broadcast();

  RealtimeChannel? _channel;
  RealtimeAlertState _state = RealtimeAlertState.disconnected;
  String? _lastError;

  /// Stream of incoming family alert events.
  Stream<FamilyAlertRecord> get alertStream => _alertController.stream;

  /// Stream of connection status changes.
  Stream<RealtimeAlertState> get statusStream => _statusController.stream;

  /// Current connection status.
  RealtimeAlertState get state => _state;

  /// Last error encountered during subscription.
  String? get lastError => _lastError;

  /// Whether Supabase backend is configured and ready.
  bool get isConfigured => SupabaseService.instance.isConfigured;

  /// Subscribes to Realtime alerts for the authenticated user.
  ///
  /// In offline demo mode, transitions safely to disconnected with zero network calls.
  Future<void> subscribeToUserAlerts({required String userId}) async {
    _lastError = null;

    if (!isConfigured) {
      _setState(RealtimeAlertState.disconnected);
      developer.log(
        'Offline mode: Realtime alert subscription skipped.',
        name: 'RealtimeService',
      );
      return;
    }

    final client = SupabaseService.instance.client;
    if (client == null) {
      _setState(RealtimeAlertState.disconnected);
      return;
    }

    final currentAuthId = client.auth.currentUser?.id;
    if (currentAuthId == null || currentAuthId != userId) {
      _setState(RealtimeAlertState.error);
      _lastError = 'Security Violation: Cannot subscribe to another user\'s alert stream.';
      throw ArgumentError(_lastError);
    }

    await unsubscribe();

    _setState(RealtimeAlertState.connecting);

    try {
      final channelName = 'user-alerts-$userId';
      _channel = client.channel(channelName);

      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'alerts',
        callback: (payload) {
          try {
            final recordMap = payload.newRecord;
            if (recordMap.isNotEmpty) {
              final alert = FamilyAlertRecord.fromMap(recordMap);
              _alertController.add(alert);
              developer.log(
                'Realtime alert received: ${alert.id} status=${alert.status}',
                name: 'RealtimeService',
              );
            }
          } catch (e) {
            developer.log(
              'Error parsing Realtime alert record: $e',
              name: 'RealtimeService',
              error: e,
            );
          }
        },
      );

      _channel!.subscribe((status, error) {
        final statusStr = status.toString().toLowerCase();
        if (error != null) {
          _lastError = error.toString();
          _setState(RealtimeAlertState.error);
          developer.log(
            'Realtime subscription error: $error',
            name: 'RealtimeService',
            error: error,
          );
        } else if (statusStr.contains('subscribed')) {
          _setState(RealtimeAlertState.subscribed);
          developer.log(
            'Realtime alert channel subscribed: $channelName',
            name: 'RealtimeService',
          );
        } else if (statusStr.contains('closed') ||
            statusStr.contains('unsubscribed')) {
          _setState(RealtimeAlertState.disconnected);
        }
      });
    } catch (e) {
      _lastError = e.toString();
      _setState(RealtimeAlertState.error);
      developer.log(
        'Failed to initiate Realtime subscription: $e',
        name: 'RealtimeService',
        error: e,
      );
    }
  }

  /// Unsubscribes from the active Realtime channel and cleans up resources.
  Future<void> unsubscribe() async {
    if (_channel != null) {
      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          await client.removeChannel(_channel!);
        }
      } catch (e) {
        developer.log('Error removing Realtime channel: $e', name: 'RealtimeService');
      }
      _channel = null;
    }
    _setState(RealtimeAlertState.disconnected);
  }

  /// Emits a local simulated alert for testing or offline demo playback.
  void emitSimulatedAlert(FamilyAlertRecord alert) {
    _alertController.add(alert);
  }

  void _setState(RealtimeAlertState newState) {
    _state = newState;
    _statusController.add(newState);
  }

  /// Resets state for unit testing.
  Future<void> resetForTesting() async {
    await unsubscribe();
    _lastError = null;
    _state = RealtimeAlertState.disconnected;
  }
}
