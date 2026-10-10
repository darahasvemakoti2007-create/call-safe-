/// Represents the current intervention/warning state of a call session.
enum ScamInterventionState {
  /// No intervention has taken place; normal playback or monitoring.
  none,

  /// Warning dialog is currently being presented to the user.
  warningShown,

  /// User selected "End Call" in response to the warning.
  userEnded,

  /// User selected "I'm Safe" to dismiss the warning and continue.
  userDismissed,

  /// User requested a simulated family alert.
  familyAlertRequested,
}

extension ScamInterventionStateX on ScamInterventionState {
  /// Human-readable label for reporting and telemetry.
  String get displayName {
    switch (this) {
      case ScamInterventionState.none:
        return 'No Intervention';
      case ScamInterventionState.warningShown:
        return 'Warning Shown';
      case ScamInterventionState.userEnded:
        return 'User Ended Call';
      case ScamInterventionState.userDismissed:
        return 'Warning Dismissed';
      case ScamInterventionState.familyAlertRequested:
        return 'Family Alert Requested';
    }
  }

  /// History-friendly status description.
  String? get historyStatus {
    switch (this) {
      case ScamInterventionState.none:
        return null;
      case ScamInterventionState.warningShown:
        return 'GuardCall warning shown';
      case ScamInterventionState.userEnded:
        return 'User selected End Call';
      case ScamInterventionState.userDismissed:
        return 'GuardCall warning shown (Dismissed)';
      case ScamInterventionState.familyAlertRequested:
        return 'Family alert requested';
    }
  }
}
