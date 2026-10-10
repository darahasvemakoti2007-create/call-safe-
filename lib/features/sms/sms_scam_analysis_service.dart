import 'package:flutter/material.dart';
import '../../core/widgets/risk_badge.dart';
import '../demo/demo_scenario.dart';
import '../detection/detection_provider_factory.dart';
import '../detection/risk_analysis.dart';
import '../detection/scam_detection_engine.dart';
import '../detection/scam_signal.dart';
import '../history/call_history_repository.dart';

/// Exception thrown when attempting to analyze an empty or whitespace-only message.
class SmsEmptyMessageException implements Exception {
  final String message;
  const SmsEmptyMessageException([this.message = 'Message text cannot be empty.']);

  @override
  String toString() => message;
}

/// An actionable protective guidance recommendation for the user.
class SafeActionItem {
  final String title;
  final String description;
  final IconData icon;
  final bool isCrucial;

  const SafeActionItem({
    required this.title,
    required this.description,
    required this.icon,
    this.isCrucial = false,
  });
}

/// Comprehensive structured result of an evaluated SMS or instant message.
class SmsAnalysisResult {
  final String rawMessage;
  final RiskAnalysis analysis;
  final bool isTruncated;
  final List<String> detectedTactics;
  final List<SafeActionItem> actionChecklist;
  final String recommendedAction;

  const SmsAnalysisResult({
    required this.rawMessage,
    required this.analysis,
    this.isTruncated = false,
    required this.detectedTactics,
    required this.actionChecklist,
    required this.recommendedAction,
  });

  int get riskScore => analysis.riskScore;
  RiskLevel get riskLevel => analysis.riskLevel;
  List<ScamSignal> get detectedSignals => analysis.detectedSignals;
  bool get isScamLikely => analysis.isScamLikely;

  /// Transparency disclaimer distinguishing risk pattern indicators from certified proof of fraud.
  String get disclaimer =>
      'Notice: GuardCall evaluates language patterns, pressure dynamics, and known social engineering tactics. '
      'A high score highlights significant manipulation signals, but does not constitute certified proof that a message is fraudulent. '
      'Similarly, a low score does not guarantee legitimacy. Always independently verify senders before acting.';
}

/// Service evaluating suspicious SMS message text for deceptive manipulation tactics,
/// credential harvesting, and fraudulent patterns using GuardCall's core detection engine.
class SmsScamAnalysisService {
  final ScamDetectionEngine _engine;
  final CallHistoryRepository _historyRepository;

  static final SmsScamAnalysisService instance = SmsScamAnalysisService();

  SmsScamAnalysisService({
    ScamDetectionEngine? engine,
    CallHistoryRepository? historyRepository,
  })  : _engine = engine ?? DetectionProviderFactory.getDetectionEngine(),
        _historyRepository = historyRepository ?? CallHistoryRepository.instance;

  /// Maximum characters evaluated in a single SMS pass to prevent memory exhaustion.
  static const int maxInputLength = 5000;

  /// Evaluates the supplied message text and returns an explainable [SmsAnalysisResult].
  Future<SmsAnalysisResult> analyzeMessage(String rawText) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      throw const SmsEmptyMessageException(
        'Please enter or paste the message text you wish to analyze.',
      );
    }

    bool isTruncated = false;
    String textToAnalyze = trimmed;
    if (trimmed.length > maxInputLength) {
      textToAnalyze = trimmed.substring(0, maxInputLength);
      isTruncated = true;
    }

    // Treat the incoming SMS text as a communication turn from an external sender
    final lines = [
      ConversationLine(
        speaker: Speaker.caller,
        text: textToAnalyze,
      ),
    ];

    final analysis = await _engine.analyzeConversation(lines);
    final tactics = _extractTactics(analysis.detectedSignals);
    final checklist = _buildSafeActionChecklist(analysis);
    final recommendedAction = _buildRecommendedAction(analysis);

    return SmsAnalysisResult(
      rawMessage: textToAnalyze,
      analysis: analysis,
      isTruncated: isTruncated,
      detectedTactics: tactics,
      actionChecklist: checklist,
      recommendedAction: recommendedAction,
    );
  }

  /// Persists the completed SMS analysis assessment to [CallHistoryRepository].
  Future<CallHistoryRecord> saveToHistory(SmsAnalysisResult result) async {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final sessionId = 'sms_${now.millisecondsSinceEpoch}';

    final excerpt = result.rawMessage.length > 140
        ? '${result.rawMessage.substring(0, 137)}...'
        : result.rawMessage;

    final subtitle = result.detectedTactics.isNotEmpty
        ? '${result.riskLevel.label} • ${result.detectedTactics.take(2).join(", ")}'
        : '${result.riskLevel.label} • Message Evaluation';

    final explanationText = result.analysis.explanations.isNotEmpty
        ? result.analysis.explanations.join('\n• ')
        : result.analysis.summary;

    final record = CallHistoryRecord(
      id: sessionId,
      title: 'Manual SMS Analysis',
      subtitle: subtitle,
      timestamp: 'Today • $timeStr',
      duration: '1 message',
      riskScore: result.riskScore,
      riskLevel: result.riskLevel,
      signals: result.detectedSignals.map((s) => s.title).toList(),
      isSimulated: false,
      source: AssessmentSource.manualSms,
      explanation: explanationText,
      transcriptExcerpt: excerpt,
      recommendedAction: result.recommendedAction,
    );

    await _historyRepository.addRecord(record);
    return record;
  }

  List<String> _extractTactics(List<ScamSignal> signals) {
    final tactics = <String>[];
    for (final s in signals) {
      switch (s.type) {
        case ScamSignalType.authorityImpersonation:
          tactics.add('Fake Authority / Impersonation');
          break;
        case ScamSignalType.urgency:
          tactics.add('Urgent Deadline Pressure');
          break;
        case ScamSignalType.fearThreat:
          tactics.add('Legal / Account Threat');
          break;
        case ScamSignalType.sensitiveInformationRequest:
          tactics.add('OTP / Credential Request');
          break;
        case ScamSignalType.financialPressure:
          tactics.add('Urgent Money / UPI Request');
          break;
        case ScamSignalType.isolation:
          tactics.add('Isolation / Secrecy Demand');
          break;
        case ScamSignalType.emotionalManipulation:
          tactics.add('Emotional / Family Crisis');
          break;
        case ScamSignalType.remoteAccessRequest:
          tactics.add('Remote App Installation');
          break;
        case ScamSignalType.suspiciousLink:
          tactics.add('Suspicious Link / URL');
          break;
      }
    }
    return tactics;
  }

  List<SafeActionItem> _buildSafeActionChecklist(RiskAnalysis analysis) {
    final checklist = <SafeActionItem>[];
    final types = analysis.detectedSignals.map((s) => s.type).toSet();

    if (types.contains(ScamSignalType.suspiciousLink)) {
      checklist.add(const SafeActionItem(
        title: 'Do not tap links or download files',
        description:
            'Never click web links or download attachments sent in unverified messages.',
        icon: Icons.link_off_rounded,
        isCrucial: true,
      ));
    }

    if (types.contains(ScamSignalType.sensitiveInformationRequest)) {
      checklist.add(const SafeActionItem(
        title: 'Never share OTPs or PIN codes',
        description:
            'Legitimate institutions and banks will never request one-time passwords via text or call.',
        icon: Icons.lock_outline_rounded,
        isCrucial: true,
      ));
    }

    if (types.contains(ScamSignalType.authorityImpersonation) ||
        types.contains(ScamSignalType.fearThreat)) {
      checklist.add(const SafeActionItem(
        title: 'Verify through official published contacts',
        description:
            'Do not reply or call phone numbers inside the message. Look up the organization independently.',
        icon: Icons.verified_user_outlined,
        isCrucial: true,
      ));
    }

    if (types.contains(ScamSignalType.financialPressure)) {
      checklist.add(const SafeActionItem(
        title: 'Refuse immediate payment or wire transfers',
        description:
            'Scammers create false panic to force hasty transfers. Pause and verify with family.',
        icon: Icons.money_off_rounded,
        isCrucial: true,
      ));
    }

    // Baseline safety checklist items
    if (checklist.isEmpty) {
      checklist.addAll([
        const SafeActionItem(
          title: 'Verify unexpected notifications',
          description:
              'If this message was unexpected, confirm through the sender’s official app or portal.',
          icon: Icons.check_circle_outline_rounded,
        ),
        const SafeActionItem(
          title: 'Maintain credential secrecy',
          description:
              'Always keep passwords and OTPs private even if a message seems routine.',
          icon: Icons.shield_outlined,
        ),
      ]);
    } else {
      checklist.add(const SafeActionItem(
        title: 'Consult trusted family circle',
        description:
            'When feeling pressured or unsure, share this message with your trusted caregiver before acting.',
        icon: Icons.family_restroom_rounded,
      ));
    }

    return checklist;
  }

  String _buildRecommendedAction(RiskAnalysis analysis) {
    switch (analysis.riskLevel) {
      case RiskLevel.critical:
        return 'Critical threat detected. Do not reply, do not click links, and never share OTPs. '
            'Block the sender immediately and alert your family circle.';
      case RiskLevel.high:
        return 'High risk manipulation detected. Do not send money, OTPs, or personal details. '
            'Independently verify with the organization using official published contacts.';
      case RiskLevel.suspicious:
        return 'Suspicious patterns detected. Exercise caution and verify the sender before taking any action.';
      case RiskLevel.safe:
        return 'Routine notification. No coercive or deceptive manipulation patterns detected.';
    }
  }
}
