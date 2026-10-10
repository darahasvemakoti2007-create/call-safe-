import '../../core/widgets/risk_badge.dart';
import 'scam_signal.dart';

/// Helper extension on RiskLevel providing threshold mappings and labels.
extension RiskLevelScore on RiskLevel {
  /// Deterministically maps a 0–100 risk score to its corresponding RiskLevel.
  ///
  /// Thresholds defined by GuardCall architecture:
  /// - 0–40: Safe
  /// - 41–70: Suspicious
  /// - 71–84: High
  /// - 85–100: Critical
  static RiskLevel fromScore(int score) {
    if (score < 40) {
      return RiskLevel.safe;
    } else if (score <= 70) {
      return RiskLevel.suspicious;
    } else if (score < 85) {
      return RiskLevel.high;
    } else {
      return RiskLevel.critical;
    }
  }
}

/// Comprehensive outcome of a conversation threat analysis.
class RiskAnalysis {
  /// The assessed threat score, clamped between 0 and 100.
  final int riskScore;

  /// The categorical risk tier.
  final RiskLevel riskLevel;

  /// List of distinct scam signals identified in the conversation.
  final List<ScamSignal> detectedSignals;

  /// Human-readable explanations detailing why signals were detected.
  final List<String> explanations;

  /// Deterministic confidence factor between 0.0 (low) and 1.0 (high).
  final double confidence;

  /// Timestamp when the analysis was performed.
  final DateTime timestamp;

  RiskAnalysis({
    required int riskScore,
    RiskLevel? riskLevel,
    required this.detectedSignals,
    required this.explanations,
    required double confidence,
    DateTime? timestamp,
  })  : riskScore = riskScore.clamp(0, 100),
        riskLevel = riskLevel ?? RiskLevelScore.fromScore(riskScore.clamp(0, 100)),
        confidence = confidence.clamp(0.0, 1.0),
        timestamp = timestamp ?? DateTime.now();

  /// Baseline safe assessment when no threats or no dialogue have been analyzed.
  factory RiskAnalysis.safe({List<String>? explanations}) {
    return RiskAnalysis(
      riskScore: 0,
      riskLevel: RiskLevel.safe,
      detectedSignals: const [],
      explanations: explanations ??
          const ['No scam or manipulation signals detected so far.'],
      confidence: 1.0,
    );
  }

  /// Human-friendly display label for the assessed tier.
  String get riskLevelLabel => riskLevel.label;

  /// Indicates if the call warrants active warning or caregiver escalation.
  bool get isScamLikely =>
      riskLevel == RiskLevel.high || riskLevel == RiskLevel.critical;

  /// Concise overview summarizing the risk outcome and main grounds.
  String get summary {
    if (riskLevel == RiskLevel.safe) {
      return 'Call is assessed as Safe. No predatory manipulation or deceptive signals were detected.';
    }

    final signalTitles = detectedSignals.map((s) => s.title.toLowerCase()).join(', ');
    return 'Assessed as ${riskLevel.label} (Score: $riskScore/100) due to: $signalTitles.';
  }

  @override
  String toString() =>
      'RiskAnalysis(score: $riskScore, level: ${riskLevel.name}, signals: ${detectedSignals.length}, confidence: ${confidence.toStringAsFixed(2)})';
}
