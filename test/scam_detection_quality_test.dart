import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/demo/demo_scenario.dart';
import 'package:guard_call/features/demo/demo_scenarios.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/scam_signal.dart';
import 'package:guard_call/features/sms/sms_scam_analysis_service.dart';

void main() {
  const engine = MockScamDetectionEngine();
  final smsService = SmsScamAnalysisService(engine: engine);

  group('Step 12: Scam-like Scenarios Evaluation', () {
    test('S1: Direct OTP and recovery code harvesting produces Critical risk', () async {
      const dialogue = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "I'm calling from your bank security division.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "We see suspicious activity. Please share the 6-digit recovery code sent to your phone immediately.",
        ),
      ];

      final result = await engine.analyzeConversation(dialogue);

      expect(result.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(result.riskScore, greaterThanOrEqualTo(70));
      expect(result.isScamLikely, isTrue);

      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, contains(ScamSignalType.sensitiveInformationRequest));
      expect(
        result.explanations.any((e) => e.contains('confidential') || e.contains('credentials') || e.contains('OTP')),
        isTrue,
      );
    });

    test('S2: Impersonated tax official threatening immediate arrest produces Critical risk', () async {
      const dialogue = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "This is officer Sharma from the income tax department and cyber crime cell.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "A non-bailable arrest warrant has been issued against you for tax evasion.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Transfer the penalty fee right now to this government reserve UPI ID or police will arrive.",
        ),
      ];

      final result = await engine.analyzeConversation(dialogue);

      expect(result.riskLevel, RiskLevel.critical);
      expect(result.riskScore, greaterThanOrEqualTo(85));
      expect(result.isScamLikely, isTrue);

      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, contains(ScamSignalType.authorityImpersonation));
      expect(types, contains(ScamSignalType.fearThreat));
      expect(types, contains(ScamSignalType.financialPressure));
    });

    test('S3: Threat of bank account closure unless money is moved to a safe account', () async {
      const dialogue = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Your bank account has been compromised and will be blocked within minutes.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "To safeguard your savings, transfer money immediately to our temporary safe custody account.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Do not hang up or tell anyone until the transfer is verified.",
        ),
      ];

      final result = await engine.analyzeConversation(dialogue);

      expect(result.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(result.riskScore, greaterThanOrEqualTo(75));

      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, contains(ScamSignalType.fearThreat));
      expect(types, contains(ScamSignalType.financialPressure));
      expect(types, contains(ScamSignalType.isolation));
    });

    test('S4: Unexpected parcel delivery fee with suspicious shortened link produces Suspicious or High risk', () async {
      const sms =
          "Postal Delivery Alert: Your parcel could not be delivered due to an unpaid customs fee of \$2.40. "
          "Pay immediately at http://bit.ly/postal-redelivery-fee to prevent item return.";

      final result = await smsService.analyzeMessage(sms);

      expect(result.riskLevel, isIn([RiskLevel.suspicious, RiskLevel.high]));
      expect(result.riskScore, greaterThanOrEqualTo(40));

      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, contains(ScamSignalType.suspiciousLink));
      expect(result.actionChecklist.any((c) => c.title.contains('link')), isTrue);
    });

    test('S5: Urgent UPI transfer request to unknown account produces Suspicious or High risk', () async {
      const sms =
          "URGENT: Your pending electricity bill is overdue. Power will be disconnected in 30 minutes. "
          "Send payment immediately to UPI ID: quickbill.pay@okaxis.";

      final result = await smsService.analyzeMessage(sms);

      expect(result.riskLevel, isIn([RiskLevel.suspicious, RiskLevel.high, RiskLevel.critical]));
      expect(result.riskScore, greaterThanOrEqualTo(40));

      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, contains(ScamSignalType.financialPressure));
      expect(types, contains(ScamSignalType.urgency));
    });

    test('S6: Technical support scam demanding remote access software installation produces High or Critical risk', () async {
      const dialogue = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "This is Microsoft technical support. We detected dangerous trojan viruses on your computer.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Please install AnyDesk right now so our technician can start screen sharing and clean your device.",
        ),
      ];

      final result = await engine.analyzeConversation(dialogue);

      expect(result.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(result.riskScore, greaterThanOrEqualTo(70));

      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, contains(ScamSignalType.remoteAccessRequest));
      expect(
        result.explanations.any((e) => e.contains('remote') || e.contains('screen sharing')),
        isTrue,
      );
    });

    test('S7: Paraphrased coercive scam asking for PIN or passcode under pressure', () async {
      const dialogue = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "We are validating your credit card against fraudulent charges.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Read back your secret PIN and the security code you received so we can cancel the charge.",
        ),
      ];

      final result = await engine.analyzeConversation(dialogue);

      expect(result.riskScore, greaterThanOrEqualTo(40));
      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, contains(ScamSignalType.sensitiveInformationRequest));
    });
  });

  group('Step 12: Legitimate Scenarios Evaluation (False Positive Prevention)', () {
    test('L1: Ordinary family conversation and social check-in is evaluated as Safe (Score: 0)', () async {
      const dialogue = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Hi Grandma! How was your morning walk today?",
        ),
        ConversationLine(
          speaker: Speaker.user,
          text: "It was lovely, dear. The flowers in the garden are blooming.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "That's wonderful! Dad and I are coming over for dinner around 6 PM. Do you need anything from the store?",
        ),
      ];

      final result = await engine.analyzeConversation(dialogue);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, 0);
      expect(result.detectedSignals, isEmpty);
      expect(result.isScamLikely, isFalse);
    });

    test('L2: Routine clinic appointment reminder and rescheduling notice is evaluated as Safe', () async {
      const sms =
          "Clinic Reminder: Your appointment with Dr. Henderson is confirmed for Thursday at 10:30 AM. "
          "Please arrive 10 minutes early. To reschedule, call our reception desk directly. No payment required.";

      final result = await smsService.analyzeMessage(sms);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, lessThanOrEqualTo(30));
      expect(result.detectedSignals, isEmpty);
      expect(result.isScamLikely, isFalse);
      expect(result.recommendedAction, contains('Routine'));
    });

    test('L3: Genuine parcel delivery update without payment links is evaluated as Safe', () async {
      const sms =
          "FedEx Tracking: Your package #482910 has been delivered to your front porch at 2:15 PM. "
          "Signed by: Front Door. Thank you for using FedEx.";

      final result = await smsService.analyzeMessage(sms);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, lessThanOrEqualTo(30));
      expect(result.detectedSignals, isEmpty);
      expect(result.isScamLikely, isFalse);
    });

    test('L4: Normal debit card transaction confirmation alert is evaluated as Safe', () async {
      const sms =
          "Bank Alert: Your debit card ending in 4102 was charged \$34.50 at Metro Grocery on 11-Oct at 14:22. "
          "Available balance is \$1,420.00. If you did not make this purchase, call the number on your card.";

      final result = await smsService.analyzeMessage(sms);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, lessThanOrEqualTo(30));
      expect(result.isScamLikely, isFalse);
      // Legitimate debit alert should not be flagged as predatory financial pressure
      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, isNot(contains(ScamSignalType.financialPressure)));
    });

    test('L5: Bank security advisory explicitly advising NEVER to share OTP is evaluated as Safe', () async {
      const sms =
          "Security Tip from Your Bank: Never share your OTP, PIN, password, or CVV with anyone. "
          "Bank officials will never call or message asking for your secret codes. Stay vigilant.";

      final result = await smsService.analyzeMessage(sms);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, lessThanOrEqualTo(30));
      expect(result.isScamLikely, isFalse);
      // Critical check: Mentioning OTP in a protective warning must NOT be flagged as credential harvesting!
      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, isNot(contains(ScamSignalType.sensitiveInformationRequest)));
    });

    test('L6: Two-factor authentication delivery with "Do not share" warning is evaluated as Safe', () async {
      const sms =
          "Your login verification code is 582914. Valid for 10 minutes. "
          "Do not share this OTP or code with anyone. Our support team will never ask for it.";

      final result = await smsService.analyzeMessage(sms);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, lessThanOrEqualTo(30));
      expect(result.isScamLikely, isFalse);
      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, isNot(contains(ScamSignalType.sensitiveInformationRequest)));
    });

    test('L7: Normal payment confirmation receipt is evaluated as Safe', () async {
      const sms =
          "Payment of \$120.00 to City Water Utility was successful on 10/11. "
          "Confirmation Ref: WTR-98234. Thank you for your payment.";

      final result = await smsService.analyzeMessage(sms);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, 0);
      expect(result.detectedSignals, isEmpty);
      expect(result.isScamLikely, isFalse);
    });
  });

  group('Step 12: Borderline and Contextual Scenarios Evaluation', () {
    test('B1: Harmless word "bank" in routine context does not trigger Authority Impersonation', () async {
      const dialogue = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Hi Mom, I am walking past the bank right now on my way to pick up the dry cleaning.",
        ),
      ];

      final result = await engine.analyzeConversation(dialogue);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, 0);
      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, isNot(contains(ScamSignalType.authorityImpersonation)));
    });

    test('B2: Harmless word "urgent" in a family errand context does not escalate to High risk', () async {
      const dialogue = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Hi Honey, please check the oven when you get a chance, it's urgent before the pie burns!",
        ),
      ];

      final result = await engine.analyzeConversation(dialogue);

      // Urgency signal might trigger from the word 'urgent' (weight 15), but score must stay Safe (< 40)
      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, lessThan(40));
      expect(result.isScamLikely, isFalse);
    });

    test('B3: Multiple coercive signals raise risk substantially compared to isolated signals', () async {
      const singleUrgency = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Please reply right now today.",
        ),
      ];

      const compoundCoercion = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "This is officer Davis from the central police investigation department.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Your identity is involved in criminal fraud. If you disconnect, you face immediate arrest.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Transfer the bond money right now to this UPI ID or police will arrive within minutes.",
        ),
      ];

      final singleResult = await engine.analyzeConversation(singleUrgency);
      final compoundResult = await engine.analyzeConversation(compoundCoercion);

      expect(singleResult.riskLevel, RiskLevel.safe);
      expect(compoundResult.riskLevel, RiskLevel.critical);
      expect(compoundResult.riskScore, greaterThan(singleResult.riskScore + 50));
    });
  });

  group('Organizer Evaluation Scenarios (Hinglish, Mid-Call Pivot, Protective Hindi)', () {
    test('O1: Hinglish Digital Arrest extortion produces Critical risk (85-100)', () async {
      final scenario = DemoScenarios.hinglishDigitalArrest;
      final result = await engine.analyzeConversation(scenario.conversationLines);

      expect(result.riskLevel, RiskLevel.critical);
      expect(result.riskScore, greaterThanOrEqualTo(85));
      expect(result.isScamLikely, isTrue);

      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, contains(ScamSignalType.authorityImpersonation));
      expect(types, contains(ScamSignalType.fearThreat));
      expect(types, contains(ScamSignalType.financialPressure));
      expect(types, contains(ScamSignalType.isolation));
    });

    test('O2: Mid-Call Pivot from friendly small talk into urgent OTP demand triggers Critical threat', () async {
      final scenario = DemoScenarios.midcallPivot;
      final result = await engine.analyzeConversation(scenario.conversationLines);

      expect(result.riskLevel, RiskLevel.critical);
      expect(result.riskScore, greaterThanOrEqualTo(85));
      expect(result.isScamLikely, isTrue);

      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, contains(ScamSignalType.authorityImpersonation));
      expect(types, contains(ScamSignalType.urgency));
      expect(types, contains(ScamSignalType.sensitiveInformationRequest));
    });

    test('O3: Protective Hindi advisory mentioning OTP/PIN defensively is evaluated as Safe', () async {
      const sms =
          "Satark rahein: Bank kabhi kisi ko OTP mat dena bolti hai. "
          "Apna secret PIN ya code kisi ko mat share karo. Savdhaan rahein.";

      final result = await smsService.analyzeMessage(sms);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, lessThanOrEqualTo(30));
      expect(result.isScamLikely, isFalse);
      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, isNot(contains(ScamSignalType.sensitiveInformationRequest)));
    });

    test('O4: Hinglish Grandchild emergency distress phishing flags Emotional Manipulation and Financial Pressure', () async {
      const dialogue = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Dadi main musibat mein hoon, mera accident ho gaya hospital mein hoon paise chahiye.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Mummy papa ko mat batana, safe account mein transfer karo turant paise via UPI.",
        ),
      ];

      final result = await engine.analyzeConversation(dialogue);

      expect(result.riskLevel, isIn([RiskLevel.high, RiskLevel.critical]));
      expect(result.riskScore, greaterThanOrEqualTo(70));
      final types = result.detectedSignals.map((s) => s.type).toSet();
      expect(types, contains(ScamSignalType.emotionalManipulation));
      expect(types, contains(ScamSignalType.financialPressure));
    });
  });
}
