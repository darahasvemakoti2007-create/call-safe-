import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/demo/demo_scenario.dart';
import 'package:guard_call/features/demo/demo_scenarios.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/scam_signal.dart';

void main() {
  const engine = MockScamDetectionEngine();

  group('ScamDetectionEngine - Five Demo Scenarios', () {
    test('1. Fake KYC produces Critical risk level', () async {
      final scenario =
          DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final result =
          await engine.analyzeConversation(scenario.conversationLines);

      expect(result.riskLevel, RiskLevel.critical);
      expect(result.riskScore, greaterThanOrEqualTo(85));
      expect(result.isScamLikely, isTrue);

      final signalTypes = result.detectedSignals.map((s) => s.type).toSet();
      expect(signalTypes, contains(ScamSignalType.authorityImpersonation));
      expect(signalTypes, contains(ScamSignalType.urgency));
      expect(signalTypes, contains(ScamSignalType.fearThreat));
      expect(signalTypes, contains(ScamSignalType.sensitiveInformationRequest));
    });

    test('2. Digital Arrest produces Critical risk level', () async {
      final scenario =
          DemoScenarios.all.firstWhere((s) => s.id == 'digital_arrest');
      final result =
          await engine.analyzeConversation(scenario.conversationLines);

      expect(result.riskLevel, RiskLevel.critical);
      expect(result.riskScore, greaterThanOrEqualTo(85));
      expect(result.isScamLikely, isTrue);

      final signalTypes = result.detectedSignals.map((s) => s.type).toSet();
      expect(signalTypes, contains(ScamSignalType.authorityImpersonation));
      expect(signalTypes, contains(ScamSignalType.fearThreat));
      expect(signalTypes, contains(ScamSignalType.isolation));
      expect(signalTypes, contains(ScamSignalType.financialPressure));
    });

    test('3. Grandchild Emergency produces High risk level', () async {
      final scenario =
          DemoScenarios.all.firstWhere((s) => s.id == 'grandchild_emergency');
      final result =
          await engine.analyzeConversation(scenario.conversationLines);

      expect(result.riskLevel, RiskLevel.high);
      expect(result.riskScore, inInclusiveRange(70, 84));
      expect(result.isScamLikely, isTrue);

      final signalTypes = result.detectedSignals.map((s) => s.type).toSet();
      expect(signalTypes, contains(ScamSignalType.emotionalManipulation));
      expect(signalTypes, contains(ScamSignalType.financialPressure));
      expect(signalTypes, contains(ScamSignalType.isolation));
      expect(signalTypes, contains(ScamSignalType.urgency));
    });

    test('4. Genuine Bank produces Safe risk level without false positives', () async {
      final scenario =
          DemoScenarios.all.firstWhere((s) => s.id == 'genuine_bank');
      final result =
          await engine.analyzeConversation(scenario.conversationLines);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, lessThanOrEqualTo(40));
      expect(result.isScamLikely, isFalse);
      expect(result.detectedSignals, isEmpty);
    });

    test('5. Genuine Hospital produces Safe risk level without false positives', () async {
      final scenario =
          DemoScenarios.all.firstWhere((s) => s.id == 'genuine_hospital');
      final result =
          await engine.analyzeConversation(scenario.conversationLines);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, lessThanOrEqualTo(40));
      expect(result.isScamLikely, isFalse);
      expect(result.detectedSignals, isEmpty);
    });
  });

  group('ScamDetectionEngine - Behavioral Rules & Edge Cases', () {
    test('6. Authority alone does not create Critical risk', () async {
      const singleAuthority = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "I'm calling from your bank to confirm your mailing address.",
        ),
      ];

      final result = await engine.analyzeConversation(singleAuthority);
      expect(result.riskLevel, isNot(RiskLevel.critical));
      expect(result.riskLevel, isNot(RiskLevel.high));
      expect(result.riskScore, lessThan(40));
    });

    test('7. OTP request is detected as sensitive information', () async {
      const otpRequest = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Please tell me the OTP you just received on your device.",
        ),
      ];

      final result = await engine.analyzeConversation(otpRequest);
      final hasSensitive = result.detectedSignals.any(
        (s) => s.type == ScamSignalType.sensitiveInformationRequest,
      );
      expect(hasSensitive, isTrue);
    });

    test('8. Financial pressure is detected', () async {
      const paymentDemand = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Send the money right now to this UPI ID.",
        ),
      ];

      final result = await engine.analyzeConversation(paymentDemand);
      final hasFinancial = result.detectedSignals.any(
        (s) => s.type == ScamSignalType.financialPressure,
      );
      expect(hasFinancial, isTrue);
    });

    test('9. Isolation is detected', () async {
      const isolationCall = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Do not tell your family and stay on this call.",
        ),
      ];

      final result = await engine.analyzeConversation(isolationCall);
      final hasIsolation = result.detectedSignals.any(
        (s) => s.type == ScamSignalType.isolation,
      );
      expect(hasIsolation, isTrue);
    });

    test('10. Multiple signals compound and increase risk score', () async {
      const singleSignal = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Action must be taken right now within minutes.",
        ),
      ];

      const multipleSignals = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "This is a police investigation. Your account will be blocked.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Transfer the requested money immediately or you face arrest.",
        ),
      ];

      final singleResult = await engine.analyzeConversation(singleSignal);
      final multiResult = await engine.analyzeConversation(multipleSignals);

      expect(multiResult.riskScore, greaterThan(singleResult.riskScore));
      expect(multiResult.detectedSignals.length, greaterThan(singleResult.detectedSignals.length));
    });

    test('11. Protective language reduces false positives', () async {
      const protectiveCall = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "We noticed unusual activity on your card.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "For your security, we will never ask for your OTP, PIN, or password.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Please contact the official bank number on the back of your card.",
        ),
      ];

      final result = await engine.analyzeConversation(protectiveCall);
      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, lessThanOrEqualTo(40));
      // Shouldn't falsely flag OTP as sensitive info when explicitly saying 'we will never ask'
      final hasFalseOtp = result.detectedSignals.any(
        (s) => s.type == ScamSignalType.sensitiveInformationRequest,
      );
      expect(hasFalseOtp, isFalse);
    });

    test('12. Risk score is always bounded between 0 and 100', () async {
      const extremeThreat = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "This is a police investigation and central bank arrest warrant.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Your account will be blocked immediately within 10 minutes right now.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Tell me the OTP, PIN, and CVV password right now.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Transfer the requested money to this UPI ID or gift cards.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Stay on this call, do not tell your family, keep this confidential.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Grandma, I had an accident and I need urgent help.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Install AnyDesk and start screen sharing immediately.",
        ),
        ConversationLine(
          speaker: Speaker.caller,
          text: "Click this link now.",
        ),
      ];

      final result = await engine.analyzeConversation(extremeThreat);
      expect(result.riskScore, inInclusiveRange(0, 100));
      expect(result.riskScore, equals(100));
    });

    test('13. Explanations describe why signals were identified', () async {
      const urgencyCall = [
        ConversationLine(
          speaker: Speaker.caller,
          text: "Your account will be blocked within 10 minutes.",
        ),
      ];

      final result = await engine.analyzeConversation(urgencyCall);
      expect(result.explanations, isNotEmpty);
      expect(
        result.explanations.any((e) => e.contains('pressure') || e.contains('deadlines') || e.contains('intimidation')),
        isTrue,
      );
    });

    test('14. Confidence is between 0.0 and 1.0', () async {
      final scenario = DemoScenarios.all.first;
      final result = await engine.analyzeConversation(scenario.conversationLines);

      expect(result.confidence, inInclusiveRange(0.0, 1.0));
      expect(result.confidence, greaterThan(0.5));
    });

    test('15. Empty conversation is handled safely with zero score', () async {
      final result = await engine.analyzeConversation(const []);

      expect(result.riskScore, equals(0));
      expect(result.riskLevel, RiskLevel.safe);
      expect(result.detectedSignals, isEmpty);
      expect(result.explanations, isNotEmpty);
      expect(result.confidence, equals(0.0));
    });
  });
}
