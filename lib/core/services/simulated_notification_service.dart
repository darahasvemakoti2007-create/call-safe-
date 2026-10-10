import 'dart:async';
import '../logging/app_logger.dart';
import 'notification_preferences.dart';
import 'notification_service.dart';

/// Concrete in-memory notification service for offline hackathon demonstrations.
///
/// KEY GUARANTEES:
/// 1. Exactly ZERO network requests are made.
/// 2. No SMS, WhatsApp, email, FCM, or APNs delivery is attempted or claimed.
/// 3. Notification events are recorded purely in local device RAM.
/// 4. Dispatches an in-memory [NotificationEvent] to notify local reactive listeners.
/// 5. Strictly labels all output as [NotificationStatus.simulated] or [NotificationStatus.unavailable].
class SimulatedNotificationService implements NotificationService {
  final List<NotificationResult> _history = [];
  final StreamController<NotificationEvent> _eventController =
      StreamController<NotificationEvent>.broadcast();

  /// Stream of local notification events for UI reactivity.
  @override
  Stream<NotificationEvent> get onNotificationEvent => _eventController.stream;

  /// Audit history of simulated notification results recorded in this session.
  List<NotificationResult> get dispatchedNotifications =>
      List.unmodifiable(_history);

  @override
  Future<NotificationResult> sendFamilyAlert(NotificationRequest request) async {
    // Check user preference toggle first
    if (!NotificationPreferences.instance.familyAlertsEnabled) {
      final unavailableResult = NotificationResult(
        notificationId: 'notif_unavail_${DateTime.now().millisecondsSinceEpoch}',
        alertId: request.alertId,
        status: NotificationStatus.unavailable,
        message: 'Family notifications are disabled in Settings.',
        timestamp: DateTime.now(),
        request: request,
      );
      _history.insert(0, unavailableResult);
      AppLogger.warning(
        'Dispatch rejected — Family notifications disabled in Settings.',
        tag: 'SimulatedNotificationService',
      );
      return unavailableResult;
    }

    final notifId = 'notif_sim_${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now();

    final result = NotificationResult(
      notificationId: notifId,
      alertId: request.alertId,
      status: NotificationStatus.simulated,
      message:
          'Family alert simulated in hackathon demo mode. No external message was sent.',
      timestamp: timestamp,
      request: request,
    );

    _history.insert(0, result);

    // Broadcast local in-memory event
    final event = NotificationEvent(
      notificationId: notifId,
      alertId: request.alertId,
      caregiverDisplayName: request.caregiverDisplayName,
      seniorDisplayName: request.seniorDisplayName,
      riskLevel: request.riskLevel,
      riskScore: request.riskScore,
      scenario: request.scenarioType,
      signals: request.detectedSignals,
      status: NotificationStatus.simulated,
      timestamp: timestamp,
      message:
          '${request.caregiverDisplayName} would receive a ${request.riskLevel.toLowerCase()} GuardCall alert.',
    );

    _eventController.add(event);

    AppLogger.info(
      'Simulated family alert notification dispatched for ${request.caregiverDisplayName} (Score: ${request.riskScore}). Zero network calls made.',
      tag: 'SimulatedNotificationService',
    );

    return result;
  }

  /// Clears in-memory history (useful between test runs or user reset).
  void clearHistory() {
    _history.clear();
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
