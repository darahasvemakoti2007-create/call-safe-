/// Distinct categories of conversational manipulation signals identified by GuardCall.
enum ScamSignalType {
  urgency,
  fearThreat,
  authorityImpersonation,
  sensitiveInformationRequest,
  financialPressure,
  isolation,
  emotionalManipulation,
  remoteAccessRequest,
  suspiciousLink;

  /// User-friendly label for display.
  String get title {
    switch (this) {
      case ScamSignalType.urgency:
        return 'Urgency or time pressure';
      case ScamSignalType.fearThreat:
        return 'Threat or fear-based pressure';
      case ScamSignalType.authorityImpersonation:
        return 'Possible authority impersonation';
      case ScamSignalType.sensitiveInformationRequest:
        return 'Sensitive information request';
      case ScamSignalType.financialPressure:
        return 'Financial pressure or payment request';
      case ScamSignalType.isolation:
        return 'Isolation from family or trusted people';
      case ScamSignalType.emotionalManipulation:
        return 'Emotional manipulation';
      case ScamSignalType.remoteAccessRequest:
        return 'Remote access or screen-sharing request';
      case ScamSignalType.suspiciousLink:
        return 'Suspicious link or payment link';
    }
  }

  /// Default human-readable explanation of why this signal is concerning.
  String get defaultExplanation {
    switch (this) {
      case ScamSignalType.urgency:
        return 'Caller creates artificial urgency or strict time deadlines to prevent careful reflection.';
      case ScamSignalType.fearThreat:
        return 'Caller uses intimidation, threats of arrest, legal penalties, or immediate account blockage.';
      case ScamSignalType.authorityImpersonation:
        return 'Caller appears to use official authority language claiming to be a bank, police, or government entity.';
      case ScamSignalType.sensitiveInformationRequest:
        return 'Caller requests confidential verification credentials such as an OTP, PIN, password, or card details.';
      case ScamSignalType.financialPressure:
        return 'Caller pressures the user to transfer funds, send money, or execute an immediate payment.';
      case ScamSignalType.isolation:
        return 'Caller attempts to isolate the user by insisting they stay on the call and not consult family or advisors.';
      case ScamSignalType.emotionalManipulation:
        return 'Caller fabricates an emergency crisis involving a loved one to exploit protective empathy.';
      case ScamSignalType.remoteAccessRequest:
        return 'Caller requests screen sharing or remote device access tools such as AnyDesk or TeamViewer.';
      case ScamSignalType.suspiciousLink:
        return 'Caller provides or instructs the user to open unverified payment or verification links.';
    }
  }

  /// Suggested baseline weight contributing to prototype risk score.
  int get defaultWeight {
    switch (this) {
      case ScamSignalType.authorityImpersonation:
        return 10;
      case ScamSignalType.urgency:
        return 15;
      case ScamSignalType.fearThreat:
        return 20;
      case ScamSignalType.sensitiveInformationRequest:
        return 25;
      case ScamSignalType.financialPressure:
        return 20;
      case ScamSignalType.isolation:
        return 15;
      case ScamSignalType.emotionalManipulation:
        return 15;
      case ScamSignalType.remoteAccessRequest:
        return 25;
      case ScamSignalType.suspiciousLink:
        return 20;
    }
  }
}

/// Represents an individual scam signal detected during conversation analysis.
class ScamSignal {
  final ScamSignalType type;
  final String title;
  final String explanation;
  final List<String> matchedPhrases;

  ScamSignal({
    required this.type,
    String? title,
    String? explanation,
    this.matchedPhrases = const [],
  })  : title = title ?? type.title,
        explanation = explanation ?? type.defaultExplanation;

  @override
  String toString() => 'ScamSignal(type: ${type.name}, title: $title)';
}
