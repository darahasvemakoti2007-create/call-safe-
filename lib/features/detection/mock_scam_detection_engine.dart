import '../demo/demo_scenario.dart';
import '../../core/widgets/risk_badge.dart';
import 'risk_analysis.dart';
import 'scam_detection_engine.dart';
import 'scam_signal.dart';

/// Prototype rule-based scam detection engine.
///
/// NOTE: This implementation uses heuristic pattern matching, contextual
/// signal combinations, and sequence escalation modeling for demonstration
/// and offline testing. In a production environment, this engine can be
/// substituted with an on-device ML model or cloud LLM implementation
/// adhering to [ScamDetectionEngine].
class MockScamDetectionEngine implements ScamDetectionEngine {
  const MockScamDetectionEngine();

  @override
  Future<RiskAnalysis> analyzeConversation(
    List<ConversationLine> conversation,
  ) async {
    // 1. Handle empty conversation safely
    if (conversation.isEmpty) {
      return RiskAnalysis(
        riskScore: 0,
        riskLevel: RiskLevel.safe,
        detectedSignals: const [],
        explanations: const ['No conversation content available to evaluate.'],
        confidence: 0.0,
      );
    }

    final callerLines = conversation
        .where((line) => line.speaker == Speaker.caller)
        .map((line) => line.text)
        .toList();

    final allLines = conversation.map((line) => line.text).toList();
    final fullCallerText = callerLines.join(' ').toLowerCase();
    final fullDialogueText = allLines.join(' ').toLowerCase();

    // 2. Protective / Safe Context Detection
    final bool hasProtectiveContext = _detectProtectiveContext(fullDialogueText);

    // 3. Detect Individual Behavioral Signals
    final detectedSignals = <ScamSignal>[];

    // A. Authority Impersonation
    // Note: Authority keywords alone (e.g. "bank", "hospital") without pressure or in safe context
    // do not constitute an impersonation signal.
    if (_detectAuthorityImpersonation(fullCallerText, hasProtectiveContext)) {
      detectedSignals.add(ScamSignal(
        type: ScamSignalType.authorityImpersonation,
        explanation:
            'Caller appears to use official authority language claiming to be a bank, police, or government entity.',
      ));
    }

    // B. Urgency / Time Pressure
    if (_detectUrgency(fullCallerText)) {
      detectedSignals.add(ScamSignal(
        type: ScamSignalType.urgency,
        explanation:
            'Caller creates time pressure by imposing artificial deadlines or demanding immediate action.',
      ));
    }

    // C. Fear / Threat
    if (_detectThreat(fullCallerText)) {
      detectedSignals.add(ScamSignal(
        type: ScamSignalType.fearThreat,
        explanation:
            'Caller uses intimidation, threats of arrest, legal prosecution, or immediate account blockage.',
      ));
    }

    // D. Sensitive Information Request
    if (_detectSensitiveInfoRequest(callerLines, hasProtectiveContext)) {
      detectedSignals.add(ScamSignal(
        type: ScamSignalType.sensitiveInformationRequest,
        explanation:
            'Caller solicits confidential authentication credentials such as an OTP, PIN, CVV, or password.',
      ));
    }

    // E. Financial Pressure / Payment Demands
    if (_detectFinancialPressure(fullCallerText, hasProtectiveContext)) {
      detectedSignals.add(ScamSignal(
        type: ScamSignalType.financialPressure,
        explanation:
            'Caller pressures the user to transfer money, make an urgent UPI payment, or move funds.',
      ));
    }

    // F. Isolation
    if (_detectIsolation(fullCallerText)) {
      detectedSignals.add(ScamSignal(
        type: ScamSignalType.isolation,
        explanation:
            'Caller attempts to isolate the user by instructing them not to tell family members or disconnect the call.',
      ));
    }

    // G. Emotional Manipulation
    if (_detectEmotionalManipulation(fullCallerText, hasProtectiveContext)) {
      detectedSignals.add(ScamSignal(
        type: ScamSignalType.emotionalManipulation,
        explanation:
            'Caller exploits family relationships or claims a fabricated emergency crisis to manipulate the user.',
      ));
    }

    // H. Remote Access Request
    if (_detectRemoteAccess(fullCallerText)) {
      detectedSignals.add(ScamSignal(
        type: ScamSignalType.remoteAccessRequest,
        explanation:
            'Caller requests screen sharing or remote device access tools such as AnyDesk or TeamViewer.',
      ));
    }

    // I. Suspicious Link
    if (_detectSuspiciousLink(fullCallerText)) {
      detectedSignals.add(ScamSignal(
        type: ScamSignalType.suspiciousLink,
        explanation:
            'Caller directs the user to open unverified payment links or external URLs.',
      ));
    }

    // 4. Calculate Risk Score from Base Weights
    int score = 0;
    for (final signal in detectedSignals) {
      score += signal.type.defaultWeight;
    }

    // 5. Contextual Bonuses for Dangerous Compounding Combinations
    final types = detectedSignals.map((s) => s.type).toSet();
    int combinationBonuses = 0;

    final hasAuthority = types.contains(ScamSignalType.authorityImpersonation);
    final hasUrgency = types.contains(ScamSignalType.urgency);
    final hasThreat = types.contains(ScamSignalType.fearThreat);
    final hasSensitiveInfo = types.contains(ScamSignalType.sensitiveInformationRequest);
    final hasFinancial = types.contains(ScamSignalType.financialPressure);
    final hasIsolation = types.contains(ScamSignalType.isolation);
    final hasEmotional = types.contains(ScamSignalType.emotionalManipulation);

    if (hasAuthority && hasUrgency) combinationBonuses += 10;
    if (hasAuthority && hasThreat) combinationBonuses += 10;
    if (hasUrgency && hasSensitiveInfo) combinationBonuses += 10;
    if (hasFinancial && hasUrgency) combinationBonuses += 10;
    if (hasIsolation && hasThreat) combinationBonuses += 10;
    if (hasEmotional && hasFinancial) combinationBonuses += 10;
    if (hasAuthority && hasSensitiveInfo) combinationBonuses += 15;

    score += combinationBonuses;

    // 6. Sequence / Escalation Modeling
    // Multi-turn progression: e.g. authority/relationship -> urgency/threat -> sensitive/financial request
    if (_detectEscalationSequence(conversation, types)) {
      score += 10;
    }

    // 7. Critical Tier Qualification
    // Critical (85–100) is strictly reserved for coercive threats (arrest/account seizure),
    // direct credential solicitation (OTP/PIN/password), or remote device control.
    // Emotional distress or financial appeals without threats or credential theft cap at High (80).
    if (!hasThreat && !hasSensitiveInfo && !types.contains(ScamSignalType.remoteAccessRequest)) {
      if (score >= 85) {
        score = 80;
      }
    }

    // 8. Controlled False-Positive Protective Adjustment
    if (hasProtectiveContext) {
      // If protective phrases explicitly counteracted potential risk, cap or reduce score
      if (score > 0) {
        score = (score - 25).clamp(0, 30);
      }
    }

    // Clamp score within 0–100 boundaries
    final finalScore = score.clamp(0, 100);
    final calculatedLevel = RiskLevelScore.fromScore(finalScore);

    // 8. Generate Human-Readable Explanations
    final explanations = <String>[];
    if (detectedSignals.isEmpty) {
      if (hasProtectiveContext) {
        explanations.add(
          'Protective context identified: Caller explicitly advised never sharing passwords/OTPs and referenced official authorized channels.',
        );
      } else {
        explanations.add(
          'Conversational flow appears routine and normal. No deceptive or coercive patterns detected.',
        );
      }
    } else {
      for (final signal in detectedSignals) {
        explanations.add(signal.explanation);
      }
      if (combinationBonuses > 0) {
        explanations.add(
          'Compounding risk factor: Multiple high-threat signals were detected in tandem, indicating coordinated psychological manipulation.',
        );
      }
    }

    // 9. Deterministic Confidence Calculation
    // Prototype confidence scales with quantity of distinct signals and combination presence
    double confidence;
    if (detectedSignals.isEmpty) {
      confidence = hasProtectiveContext ? 0.90 : 0.65;
    } else {
      confidence = 0.55 + (detectedSignals.length * 0.08) + (combinationBonuses > 0 ? 0.12 : 0.0);
    }
    final finalConfidence = confidence.clamp(0.0, 1.0);

    return RiskAnalysis(
      riskScore: finalScore,
      riskLevel: calculatedLevel,
      detectedSignals: detectedSignals,
      explanations: explanations,
      confidence: finalConfidence,
    );
  }

  // --- Signal Heuristic Detectors ---

  bool _detectProtectiveContext(String text) {
    const protectivePatterns = [
      'will never ask for your otp',
      'never ask for your pin',
      'never ask for your password',
      'never ask for your cvv',
      'official bank number',
      'official banking app',
      'no payment or sensitive information is required',
      'no payment',
      'no sensitive information',
      'reschedule your appointment',
    ];

    for (final pattern in protectivePatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _detectAuthorityImpersonation(String text, bool hasProtectiveContext) {
    if (hasProtectiveContext && !text.contains('police') && !text.contains('arrest')) {
      return false;
    }

    const authorityPatterns = [
      "i'm calling from your bank",
      'calling from the bank',
      'police investigation',
      'police inspector',
      'law enforcement',
      'central bank',
      'court officer',
      'tax official',
      'cbi officer',
    ];

    for (final pattern in authorityPatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _detectUrgency(String text) {
    const urgencyPatterns = [
      'expires today',
      'within 10 minutes',
      'within minutes',
      'right now',
      'immediately',
      'urgent',
      'act fast',
      'today only',
    ];

    for (final pattern in urgencyPatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _detectThreat(String text) {
    const threatPatterns = [
      'account will be blocked',
      'will be blocked',
      'police investigation',
      'arrest',
      'serious case',
      'legal action',
      'prove your identity',
      'held liable',
      'penalty',
    ];

    for (final pattern in threatPatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _detectSensitiveInfoRequest(
    List<String> callerLines,
    bool hasProtectiveContext,
  ) {
    for (final line in callerLines) {
      final lower = line.toLowerCase();

      // Guard against protective statements mentioning OTP/PIN
      if (lower.contains('never ask') || lower.contains('no sensitive information')) {
        continue;
      }

      if ((lower.contains('tell me the otp') ||
              lower.contains('share the otp') ||
              lower.contains('provide the otp') ||
              lower.contains('otp you just received') ||
              lower.contains('verification code') ||
              lower.contains('tell me your pin') ||
              lower.contains('cvv') ||
              lower.contains('password')) &&
          !hasProtectiveContext) {
        return true;
      }
    }
    return false;
  }

  bool _detectFinancialPressure(String text, bool hasProtectiveContext) {
    if (hasProtectiveContext &&
        (text.contains('no payment') || text.contains('never ask'))) {
      return false;
    }

    const financialPatterns = [
      'transfer the requested money',
      'transfer the money',
      'transfer money',
      'send the money',
      'send money',
      'upi id',
      'upi payment',
      'wire transfer',
      'pay immediately',
      'need money immediately',
    ];

    for (final pattern in financialPatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _detectIsolation(String text) {
    const isolationPatterns = [
      'do not tell your family',
      "don't tell your family",
      'do not call your family',
      "don't call your family",
      'do not tell my parents',
      "don't tell my parents",
      'do not call my parents',
      "don't call my parents",
      'stay on this call',
      'do not disconnect',
      "don't hang up",
      'keep this confidential',
      'tell no one',
    ];

    for (final pattern in isolationPatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _detectEmotionalManipulation(String text, bool hasProtectiveContext) {
    if (hasProtectiveContext) return false;

    const emotionalPatterns = [
      'grandma, i need your help',
      'grandpa, i need your help',
      'i had an accident',
      'hospital and i need money',
      'accident and i need',
      'in trouble and need help',
    ];

    for (final pattern in emotionalPatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _detectRemoteAccess(String text) {
    const remotePatterns = [
      'screen sharing',
      'remote access',
      'install this app',
      'anydesk',
      'teamviewer',
      'share your screen',
    ];

    for (final pattern in remotePatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _detectSuspiciousLink(String text) {
    const linkPatterns = [
      'click this link',
      'open this link',
      'payment link',
      'upi link',
      'tracking link',
      'http://',
      'https://',
    ];

    for (final pattern in linkPatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _detectEscalationSequence(
    List<ConversationLine> conversation,
    Set<ScamSignalType> types,
  ) {
    // Requires at least 3 conversation turns and multiple compound signals
    if (conversation.length < 3 || types.length < 3) return false;

    // Check if initial turns set up authority/relationship and later turns demand action
    final firstHalf = conversation
        .take((conversation.length / 2).ceil())
        .where((l) => l.speaker == Speaker.caller)
        .map((l) => l.text.toLowerCase())
        .join(' ');

    final secondHalf = conversation
        .skip((conversation.length / 2).floor())
        .where((l) => l.speaker == Speaker.caller)
        .map((l) => l.text.toLowerCase())
        .join(' ');

    final hasInitialSetup = firstHalf.contains('bank') ||
        firstHalf.contains('police') ||
        firstHalf.contains('investigation') ||
        firstHalf.contains('grandma') ||
        firstHalf.contains('accident') ||
        firstHalf.contains('kyc');

    final hasLaterAction = secondHalf.contains('otp') ||
        secondHalf.contains('money') ||
        secondHalf.contains('transfer') ||
        secondHalf.contains('upi') ||
        secondHalf.contains('blocked');

    return hasInitialSetup && hasLaterAction;
  }
}
