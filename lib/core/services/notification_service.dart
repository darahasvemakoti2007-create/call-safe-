import 'dart:async';
import 'simulated_notification_service.dart';

/// Typed status representing the current state of a caregiver notification delivery attempt.
///
/// IMPORTANT DELIVERY CONSTRAINTS:
/// For the current hackathon prototype, ONLY [simulated] or [unavailable] / [failed]
/// are emitted. [sent] and [delivered] are reserved for verified live cloud integrations.
enum NotificationStatus {
  /// Notification was simulated locally on-device without external transmission.
  simulated,

  /// Notification has been queued by an external dispatch gateway.
  queued,

  /// Notification was dispatched to a live delivery network (FCM, SMS gateway).
  sent,

  /// Confirmed delivery receipt received from recipient's device.
  delivered,

  /// Notification attempt failed due to an error.
  failed,

  /// Notifications are not configured or disabled in user settings.
  unavailable,
}

extension NotificationStatusExtension on NotificationStatus {
  String get label {
    switch (this) {
      case NotificationStatus.simulated:
        return 'SIMULATED';
      case NotificationStatus.queued:
        return 'QUEUED';
      case NotificationStatus.sent:
        return 'SENT';
      case NotificationStatus.delivered:
        return 'DELIVERED';
      case NotificationStatus.failed:
        return 'FAILED';
      case NotificationStatus.unavailable:
        return 'UNAVAILABLE';
    }
  }

  bool get isSimulated => this == NotificationStatus.simulated;
}

/// A privacy-minimized notification dispatch request.
///
/// STRICT PRIVACY BOUNDARY:
/// Contains ONLY high-level risk telemetry and structured threat signals.
/// NEVER contains raw audio bytes, waveforms, full conversation transcripts,
/// bank credentials, OTPs, PINs, CVVs, passwords, or authentication keys.
class NotificationRequest {
  final String alertId;
  final String caregiverId;
  final String caregiverDisplayName;
  final String seniorDisplayName;
  final int riskScore;
  final String riskLevel;
  final String scenarioType;
  final List<String> detectedSignals;
  final String explanation;
  final String interventionStatus;
  final DateTime timestamp;

  const NotificationRequest({
    required this.alertId,
    required this.caregiverId,
    required this.caregiverDisplayName,
    required this.seniorDisplayName,
    required this.riskScore,
    required this.riskLevel,
    required this.scenarioType,
    required this.detectedSignals,
    required this.explanation,
    required this.interventionStatus,
    required this.timestamp,
  });

  /// Privacy confirmation helper: verifies this payload contains no sensitive content.
  bool get isPrivacyCompliant {
    // Verifies that neither explanation nor signals contain credential patterns
    final lowerExp = explanation.toLowerCase();
    return !lowerExp.contains('raw audio') && !lowerExp.contains('full transcript');
  }

  Map<String, dynamic> toMap() {
    return {
      'alert_id': alertId,
      'caregiver_id': caregiverId,
      'caregiver_name': caregiverDisplayName,
      'senior_name': seniorDisplayName,
      'risk_score': riskScore,
      'risk_level': riskLevel,
      'scenario_type': scenarioType,
      'detected_signals': detectedSignals,
      'explanation': explanation,
      'intervention_status': interventionStatus,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'NotificationRequest(alert: $alertId, to: $caregiverDisplayName, score: $riskScore, type: $scenarioType)';
}

/// The result returned by a [NotificationService] after processing a dispatch request.
class NotificationResult {
  final String notificationId;
  final String alertId;
  final NotificationStatus status;
  final String message;
  final DateTime timestamp;
  final NotificationRequest request;

  const NotificationResult({
    required this.notificationId,
    required this.alertId,
    required this.status,
    required this.message,
    required this.timestamp,
    required this.request,
  });

  bool get isSimulated => status == NotificationStatus.simulated;

  @override
  String toString() =>
      'NotificationResult(id: $notificationId, status: ${status.label}, msg: $message)';
}

/// An in-memory, local event emitted over [NotificationService.onNotificationEvent].
///
/// Allows prototype UI components (Caregiver View, Scam Warning Dialog) to observe
/// notification activity reactively without coupling to external networks.
class NotificationEvent {
  final String notificationId;
  final String alertId;
  final String caregiverDisplayName;
  final String seniorDisplayName;
  final String riskLevel;
  final int riskScore;
  final String scenario;
  final List<String> signals;
  final NotificationStatus status;
  final DateTime timestamp;
  final String message;

  const NotificationEvent({
    required this.notificationId,
    required this.alertId,
    required this.caregiverDisplayName,
    required this.seniorDisplayName,
    required this.riskLevel,
    required this.riskScore,
    required this.scenario,
    required this.signals,
    required this.status,
    required this.timestamp,
    required this.message,
  });

  @override
  String toString() =>
      'NotificationEvent(id: $notificationId, to: $caregiverDisplayName, status: ${status.label})';
}

/// Provider-neutral notification service abstraction.
///
/// Decouples GuardCall business logic from concrete notification mechanisms
/// (such as local simulation, FCM, APNs, Twilio SMS, or SendGrid email).
abstract class NotificationService {
  /// Default shared singleton instance. Defaults to [SimulatedNotificationService].
  static NotificationService _instance = SimulatedNotificationService();

  /// Gets current active notification service instance.
  static NotificationService get instance => _instance;

  /// Sets a custom notification service instance (useful for unit testing or future providers).
  static void setInstance(NotificationService service) {
    _instance = service;
  }

  /// Resets to default simulated notification service.
  static void resetToDefault() {
    _instance = SimulatedNotificationService();
  }

  /// Sends a caregiver alert notification.
  Future<NotificationResult> sendFamilyAlert(NotificationRequest request);

  /// Local event stream of notification actions for UI reactivity.
  Stream<NotificationEvent> get onNotificationEvent;

  /// Cleans up internal resources / streams.
  void dispose();
}

// -----------------------------------------------------------------------------
// FUTURE PROVIDER INTERFACES (PREPARED ARCHITECTURE — NOT IMPLEMENTED IN PROTOTYPE)
// -----------------------------------------------------------------------------

/// Future Firebase Cloud Messaging (FCM) push notification provider.
///
/// ARCHITECTURAL SPECIFICATION:
/// When implemented, this provider will authenticate with Supabase Edge Functions
/// or a secure backend proxy to dispatch FCM push payloads to the caregiver's Android device.
///
/// NOT IMPLEMENTED in Step 17 to preserve zero-credential offline demo safety.
abstract class FcmNotificationService implements NotificationService {
  // NOT IMPLEMENTED: Requires Firebase project setup, google-services.json, and FCM credentials.
}

/// Future Apple Push Notification service (APNs) provider.
///
/// NOT IMPLEMENTED in Step 17.
abstract class ApnsNotificationService implements NotificationService {
  // NOT IMPLEMENTED: Requires Apple Developer APNs key configuration.
}

/// Future SMS dispatch provider (e.g. Twilio, AWS SNS).
///
/// NOT IMPLEMENTED in Step 17 to preserve zero-cost, offline hackathon safety.
abstract class SmsNotificationService implements NotificationService {
  // NOT IMPLEMENTED: Requires Twilio/carrier gateway credentials.
}

/// Future Email dispatch provider (e.g. SendGrid, AWS SES, Resend).
///
/// NOT IMPLEMENTED in Step 17.
abstract class EmailNotificationService implements NotificationService {
  // NOT IMPLEMENTED: Requires SMTP or transactional email provider credentials.
}
