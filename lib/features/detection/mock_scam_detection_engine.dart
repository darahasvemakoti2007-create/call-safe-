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
    final hasRemote = types.contains(ScamSignalType.remoteAccessRequest);
    final hasLink = types.contains(ScamSignalType.suspiciousLink);

    if (hasAuthority && hasUrgency) combinationBonuses += 10;
    if (hasAuthority && hasThreat) combinationBonuses += 10;
    if (hasUrgency && hasSensitiveInfo) combinationBonuses += 10;
    if (hasFinancial && hasUrgency) combinationBonuses += 10;
    if (hasIsolation && hasThreat) combinationBonuses += 10;
    if (hasEmotional && hasFinancial) combinationBonuses += 10;
    if (hasAuthority && hasSensitiveInfo) combinationBonuses += 15;
    if (hasThreat && hasSensitiveInfo) combinationBonuses += 15;
    if (hasThreat && hasFinancial) combinationBonuses += 10;
    if (hasRemote && hasUrgency) combinationBonuses += 10;
    if (hasRemote && (hasAuthority || hasThreat)) combinationBonuses += 15;
    if (hasLink && hasFinancial) combinationBonuses += 10;

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
    if (!hasThreat && !hasSensitiveInfo && !hasRemote) {
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
          'Protective context identified: Message explicitly advised never sharing credentials/OTPs or referenced legitimate verification channels.',
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
      'never ask for your code',
      'never ask for your credentials',
      'never share your otp',
      'never share your pin',
      'never share your password',
      'never share your cvv',
      'never share your',
      'do not share your otp',
      'do not share this otp',
      'do not share this code',
      'do not share your pin',
      'do not share your password',
      'do not share your credentials',
      'never disclose',
      'do not disclose',
      'never give your otp',
      'do not give your otp',
      'never give your password',
      'security tip',
      'fraud awareness',
      'stay vigilant',
      'beware of fraudulent',
      'beware of phishing',
      'we will never ask',
      'bank will never ask',
      'officials will never ask',
      'staff will never ask',
      'team will never ask',
      'official bank number',
      'official banking app',
      'no payment or sensitive information is required',
      'no payment required',
      'no payment is required',
      'no payment',
      'no sensitive information',
      'reschedule your appointment',
      'payment was successful',
      'successful on',
      'confirmation ref',
      'thank you for your payment',
      'available balance is',
      'if you did not make this purchase',
      'was charged',
      // Multilingual / Hinglish protective phrases
      'kabhi kisi ko otp mat dena',
      'bank kabhi otp nahi maangta',
      'kisi ko otp mat share karo',
      'kisi ko pin mat dena',
      'otp share mat kijiye',
      'savdhaan rahein',
      'satark rahein',
    ];

    for (final pattern in protectivePatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _detectAuthorityImpersonation(String text, bool hasProtectiveContext) {
    if (hasProtectiveContext &&
        !text.contains('police') &&
        !text.contains('arrest') &&
        !text.contains('cyber crime')) {
      return false;
    }

    const authorityPatterns = [
      "i'm calling from your bank",
      'calling from the bank',
      'calling from your bank',
      'bank security division',
      'bank fraud department',
      'fraud prevention',
      'fraudulent charges',
      'police investigation',
      'police inspector',
      'law enforcement',
      'central bank',
      'court officer',
      'tax official',
      'income tax department',
      'tax department',
      'cbi officer',
      'cyber crime',
      'cyber cell',
      'customs department',
      'telecom department',
      'microsoft technical support',
      'technical support',
      'it support',
      // Multilingual / Hinglish authority impersonation
      'police aayegi',
      'police aa rahi hai',
      'cbi officer bol raha hoon',
      'crime branch se hoon',
      'crime branch se bol raha',
      'mumbai police',
      'delhi police',
      'crime branch',
      'thaana',
      'court se warrant',
      'bank manager bol raha',
      'bank portal',
      'bank official',
      'society bank',
      'cyber cell se',
      'trai department',
      'dot department',
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
      'within 30 minutes',
      'in 30 minutes',
      'immediately',
      'urgent',
      'urgently',
      'act fast',
      'today only',
      'time is running out',
      'overdue',
      'pay right now',
      'send right now',
      'transfer right now',
      'share right now',
      'tell me right now',
      'install right now',
      'call right now',
      'reply right now',
      'right now to prevent',
      'right now or',
      'right now before',
      'right now so',
      // Multilingual / Hinglish urgency
      'jaldi karo',
      'turant',
      'abhi ke abhi',
      'samay nahi hai',
      'fatafat',
      '10 minute mein',
      '30 minute mein',
      'turant karo',
      'abhi karo',
      'time khatam',
    ];

    for (final pattern in urgencyPatterns) {
      if (text.contains(pattern)) return true;
    }

    // Bare "right now" triggers only if imperative action or coercive words are present
    if (text.contains('right now')) {
      const actionTriggers = [
        'pay',
        'send',
        'transfer',
        'tell',
        'share',
        'give',
        'install',
        'action',
        'must',
        'prevent',
        'police',
        'penalty',
        'blocked',
        'arrest',
        'wire',
        'disconnect',
      ];
      final isDescriptive = text.contains('i am') || text.contains("i'm");
      final hasAction = actionTriggers.any((w) => text.contains(w));
      if (hasAction || !isDescriptive) {
        return true;
      }
    }

    return false;
  }

  bool _detectThreat(String text) {
    const threatPatterns = [
      'account will be blocked',
      'will be blocked',
      'account will be suspended',
      'will be suspended',
      'power will be disconnected',
      'disconnected in',
      'service will be terminated',
      'police investigation',
      'arrest',
      'arrest warrant',
      'warrant has been issued',
      'non-bailable',
      'serious case',
      'legal action',
      'legal prosecution',
      'prove your identity',
      'held liable',
      'penalty',
      'tax evasion',
      'trojan virus',
      'viruses on your computer',
      'computer has been infected',
      // Multilingual / Hinglish threats
      'arrest ho jaoge',
      'arrest warrant issue',
      'jail bhej denge',
      'account band ho jayega',
      'police bhej rahe hain',
      'fir darj',
      'digital arrest',
      'digital custody',
      'power cut ho jayegi',
      'bijli kat jayegi',
      'sim block ho jayega',
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
    if (hasProtectiveContext) {
      // In protective context, credential mentions are defensive guidance
      return false;
    }

    for (final line in callerLines) {
      final lower = line.toLowerCase();

      // Guard against protective statements or negative advice
      if (lower.contains('never ask') ||
          lower.contains('never share') ||
          lower.contains('do not share') ||
          lower.contains('never disclose') ||
          lower.contains('do not disclose') ||
          lower.contains('never give') ||
          lower.contains('do not give') ||
          lower.contains('no sensitive information') ||
          lower.contains('security tip') ||
          lower.contains('stay vigilant') ||
          lower.contains('beware of') ||
          lower.contains('mat dena') ||
          lower.contains('mat share')) {
        continue;
      }

      // Action verbs requesting confidential credentials
      final hasSolicitVerb = lower.contains('tell me') ||
          lower.contains('share ') ||
          lower.contains('provide ') ||
          lower.contains('send ') ||
          lower.contains('enter ') ||
          lower.contains('read back') ||
          lower.contains('read me') ||
          lower.contains('give me') ||
          lower.contains('disclose ') ||
          // Multilingual / Hinglish solicitation verbs
          lower.contains('batao') ||
          lower.contains('bataiye') ||
          lower.contains('bolo') ||
          lower.contains('karo');

      final hasCredentialTerm = lower.contains('otp') ||
          lower.contains('pin') ||
          lower.contains('cvv') ||
          lower.contains('password') ||
          lower.contains('verification code') ||
          lower.contains('recovery code') ||
          lower.contains('security code') ||
          lower.contains('auth code') ||
          lower.contains('passcode');

      if (hasSolicitVerb && hasCredentialTerm) {
        return true;
      }

      // Explicit harvesting phrases
      if (lower.contains('otp you just received') ||
          lower.contains('tell me the otp') ||
          lower.contains('tell me your pin') ||
          lower.contains('secret pin') ||
          lower.contains('tell me the code') ||
          // Multilingual / Hinglish harvesting phrases
          lower.contains('otp batao') ||
          lower.contains('otp bataiye') ||
          lower.contains('otp bolo') ||
          lower.contains('pin batao') ||
          lower.contains('pin bataiye') ||
          lower.contains('code batao') ||
          lower.contains('jo otp aaya')) {
        return true;
      }
    }
    return false;
  }

  bool _detectFinancialPressure(String text, bool hasProtectiveContext) {
    if (hasProtectiveContext &&
        (text.contains('no payment') ||
            text.contains('never ask') ||
            text.contains('was charged') ||
            text.contains('payment was successful') ||
            text.contains('debited by'))) {
      return false;
    }

    const financialPatterns = [
      'transfer the requested money',
      'transfer the money',
      'transfer money',
      'transfer funds',
      'transfer the penalty',
      'send the money',
      'send money',
      'send payment',
      'upi id',
      'upi payment',
      'wire transfer',
      'wire funds',
      'pay immediately',
      'need money immediately',
      'customs fee',
      'unpaid fee',
      'penalty fee',
      'redelivery fee',
      'safe custody account',
      'safe account',
      'deposit the funds',
      'deposit money',
      // Multilingual / Hinglish financial demands
      'paise bhejo',
      'paise transfer',
      'paise jama karo',
      'paise daalo',
      'paise chahiye',
      'via upi',
      'upi se',
      'upi kar do',
      'turant pay karo',
      'turant transfer karo',
      'safe account mein transfer',
      'fine bharna hoga',
      'penalty bharni hogi',
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
      'do not tell anyone',
      "don't tell anyone",
      'tell no one',
      'stay on this call',
      'stay on the line',
      'do not disconnect',
      'do not hang up',
      "don't hang up",
      'keep this confidential',
      'keep this secret',
      // Multilingual / Hinglish isolation
      'kisi ko mat batana',
      'kisi se baat mat karo',
      'ghar walon ko mat batao',
      'mummy papa ko mat batana',
      'parents ko mat batana',
      'family ko mat batana',
      'phone mat kaatna',
      'call disconnect mat karo',
      'call cut mat karna',
      'line par raho',
      'video call par raho',
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
      // Multilingual / Hinglish emotional manipulation
      'dadi main musibat mein hoon',
      'nani main musibat mein hoon',
      'mera accident ho gaya',
      'police ne pakad liya',
      'hospital mein hoon paise chahiye',
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
      'quicksupport',
      'rustdesk',
      'ultraviewer',
      'share your screen',
      'screen share',
      'remote desktop',
      'remote control',
      // Multilingual / Hinglish remote access
      'app download karo',
      'app install karo',
      'screen share karo',
      'anydesk download',
      'teamviewer download',
    ];

    for (final pattern in remotePatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _detectSuspiciousLink(String text) {
    // Explicit suspicious or phishing link patterns
    const explicitLinkPatterns = [
      'click this link',
      'open this link',
      'payment link',
      'upi link',
      'tracking link',
      'bit.ly/',
      'tinyurl.com/',
      'is.gd/',
      't.co/',
      'goo.gl/',
      'tap the link',
      'click here to pay',
      'tap here to pay',
      'pay at http',
      'pay at https',
      'http://',
      // Multilingual / Hinglish link directives
      'link pe click karo',
      'link kholo',
      'link par tap karo',
    ];

    for (final pattern in explicitLinkPatterns) {
      if (text.contains(pattern)) return true;
    }

    // Generic link combined with financial demand or coercive urgency
    if (text.contains('https://') ||
        text.contains('click here') ||
        text.contains('tap here')) {
      final hasSuspiciousContext = text.contains('fee') ||
          text.contains('pay') ||
          text.contains('urgent') ||
          text.contains('blocked') ||
          text.contains('suspend') ||
          text.contains('redelivery');
      if (hasSuspiciousContext) {
        return true;
      }
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
        firstHalf.contains('kyc') ||
        firstHalf.contains('tax') ||
        firstHalf.contains('support') ||
        firstHalf.contains('aadhar') ||
        firstHalf.contains('parcel') ||
        firstHalf.contains('namaste') ||
        firstHalf.contains('society') ||
        firstHalf.contains('crime');

    final hasLaterAction = secondHalf.contains('otp') ||
        secondHalf.contains('money') ||
        secondHalf.contains('transfer') ||
        secondHalf.contains('upi') ||
        secondHalf.contains('blocked') ||
        secondHalf.contains('anydesk') ||
        secondHalf.contains('code') ||
        secondHalf.contains('paise') ||
        secondHalf.contains('batao') ||
        secondHalf.contains('band');

    return hasInitialSetup && hasLaterAction;
  }
}
