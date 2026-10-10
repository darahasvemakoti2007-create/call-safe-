import '../demo/demo_scenario.dart';
import 'risk_analysis.dart';

/// Contract for GuardCall conversation threat detection engines.
///
/// Any implementation (heuristic, rule-based, local on-device ML, or cloud LLM)
/// adheres to this interface, decoupling detection logic from the UI.
abstract class ScamDetectionEngine {
  /// Analyzes a stream or list of conversational turns and produces an
  /// explainable [RiskAnalysis] assessment.
  Future<RiskAnalysis> analyzeConversation(List<ConversationLine> conversation);
}
