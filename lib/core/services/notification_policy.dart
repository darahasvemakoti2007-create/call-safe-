import '../widgets/risk_badge.dart';
import 'notification_preferences.dart';

/// The result of evaluating a notification dispatch against GuardCall safety policies.
class PolicyDecision {
  final bool isAllowed;
  final String reason;
  final bool requiresUserIntervention;

  const PolicyDecision({
    required this.isAllowed,
    required this.reason,
    required this.requiresUserIntervention,
  });

  @override
  String toString() => 'PolicyDecision(allowed: $isAllowed, reason: $reason)';
}

/// Risk-based policy governing when family alerts should be permitted or requested.
///
/// Core Safety Tenets:
/// 1. The senior user always retains final authority (no silent auto-alerts).
/// 2. Low-level threats (Safe, Suspicious) do not trigger family alerts.
/// 3. High and Critical threats allow the senior to initiate an alert.
/// 4. Disabled preferences in Settings completely halt alert dispatch.
class NotificationPolicy {
  /// Evaluates whether a given [RiskLevel] tier is eligible for family alert escalation.
  ///
  /// - [RiskLevel.safe]: No family notification.
  /// - [RiskLevel.suspicious]: No automatic family notification.
  /// - [RiskLevel.high]: Eligible for family notification upon user intervention.
  /// - [RiskLevel.critical]: Eligible for family notification upon user intervention.
  static bool isRiskLevelEligible(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
      case RiskLevel.suspicious:
        return false;
      case RiskLevel.high:
      case RiskLevel.critical:
        return true;
    }
  }

  /// Evaluates a proposed family notification dispatch against system policies.
  static PolicyDecision evaluate({
    required RiskLevel riskLevel,
    required bool isUserInitiated,
    bool? preferencesEnabled,
  }) {
    final alertsEnabled =
        preferencesEnabled ?? NotificationPreferences.instance.familyAlertsEnabled;

    if (!alertsEnabled) {
      return const PolicyDecision(
        isAllowed: false,
        reason: 'Family alerts are disabled in Settings.',
        requiresUserIntervention: true,
      );
    }

    if (!isUserInitiated) {
      return const PolicyDecision(
        isAllowed: false,
        reason:
            'User intervention is strictly required before a family alert can be requested.',
        requiresUserIntervention: true,
      );
    }

    if (riskLevel == RiskLevel.safe) {
      return const PolicyDecision(
        isAllowed: false,
        reason: 'Safe conversations do not warrant family alert escalation.',
        requiresUserIntervention: false,
      );
    }

    if (riskLevel == RiskLevel.suspicious) {
      return const PolicyDecision(
        isAllowed: false,
        reason:
            'Suspicious conversations do not warrant automatic family alerts unless threat escalates.',
        requiresUserIntervention: false,
      );
    }

    return const PolicyDecision(
      isAllowed: true,
      reason:
          'High or critical risk conversation with explicit senior intervention.',
      requiresUserIntervention: true,
    );
  }
}
