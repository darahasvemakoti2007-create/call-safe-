import '../../core/widgets/risk_badge.dart';

/// Speaker role in a simulated conversation.
enum Speaker {
  caller,
  user;

  String get displayName => this == Speaker.caller ? 'Caller' : 'User';
}

/// A single spoken line in a dialogue.
class ConversationLine {
  final Speaker speaker;
  final String text;

  const ConversationLine({
    required this.speaker,
    required this.text,
  });
}

/// Model representing a predefined simulated call scenario for demonstration.
class DemoScenario {
  final String id;
  final String title;
  final String shortDescription;
  final String category;
  final String callerRole;
  final List<ConversationLine> conversationLines;
  final RiskLevel expectedRiskLevel;
  final List<String> expectedSignals;

  const DemoScenario({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.category,
    required this.callerRole,
    required this.conversationLines,
    required this.expectedRiskLevel,
    required this.expectedSignals,
  });
}
