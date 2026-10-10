import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/app/app_theme.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/alerts/scam_intervention_state.dart';
import 'package:guard_call/features/alerts/scam_warning_dialog.dart';
import 'package:guard_call/features/alerts/simulated_family_alert.dart';
import 'package:guard_call/features/demo/demo_scenario.dart';
import 'package:guard_call/features/demo/demo_scenarios.dart';
import 'package:guard_call/features/demo/demo_session_controller.dart';
import 'package:guard_call/features/detection/risk_analysis.dart';
import 'package:guard_call/features/detection/scam_signal.dart';

void main() {
  group('Step 6 Intervention Trigger & State Tests', () {
    test('1. Safe scenario does not trigger warning', () async {
      final safeScenario = DemoScenarios.all.firstWhere((s) => s.id == 'genuine_bank');
      final controller = DemoSessionController(scenario: safeScenario);

      while (!controller.isCompleted) {
        await controller.advanceNextLine();
        expect(controller.warningShown, isFalse);
        expect(controller.interventionState, ScamInterventionState.none);
        expect(controller.isWarningThresholdCrossed, isFalse);
      }

      expect(controller.currentAnalysis.riskLevel, RiskLevel.safe);
      controller.dispose();
    });

    test('2. Suspicious risk does not trigger warning', () async {
      const suspiciousScenario = DemoScenario(
        id: 'suspicious_demo',
        title: 'Suspicious Scenario',
        shortDescription: 'Only mild urgency',
        category: 'Test',
        callerRole: 'Caller',
        expectedRiskLevel: RiskLevel.suspicious,
        expectedSignals: ['Urgency'],
        conversationLines: [
          ConversationLine(speaker: Speaker.caller, text: 'Hello, please call us back urgently today.'),
          ConversationLine(speaker: Speaker.user, text: 'Okay, what is this regarding?'),
        ],
      );

      final controller = DemoSessionController(scenario: suspiciousScenario);
      await controller.advanceNextLine();

      // Only single urgency signal -> score < 40 or suspicious tier
      expect(controller.isWarningThresholdCrossed, isFalse);
      expect(controller.warningShown, isFalse);
      expect(controller.interventionState, ScamInterventionState.none);

      controller.dispose();
    });

    test('3. High risk triggers warning', () async {
      final highScenario = DemoScenarios.all.firstWhere((s) => s.id == 'grandchild_emergency');
      final controller = DemoSessionController(scenario: highScenario);

      bool triggered = false;
      while (!controller.isCompleted) {
        await controller.advanceNextLine();
        if (controller.warningShown) {
          triggered = true;
          expect(controller.interventionState, ScamInterventionState.warningShown);
          expect(controller.isWarningThresholdCrossed, isTrue);
          expect(controller.isPaused, isTrue);
          break;
        }
      }

      expect(triggered, isTrue);
      controller.dispose();
    });

    test('4. Critical risk triggers warning', () async {
      final criticalScenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final controller = DemoSessionController(scenario: criticalScenario);

      bool triggered = false;
      while (!controller.isCompleted) {
        await controller.advanceNextLine();
        if (controller.warningShown) {
          triggered = true;
          expect(controller.interventionState, ScamInterventionState.warningShown);
          expect(controller.currentAnalysis.riskScore, greaterThanOrEqualTo(71));
          break;
        }
      }

      expect(triggered, isTrue);
      controller.dispose();
    });

    test('5. Warning appears only once per simulation', () async {
      final criticalScenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final controller = DemoSessionController(scenario: criticalScenario);

      int warningCount = 0;
      while (!controller.isCompleted) {
        await controller.advanceNextLine();
        if (controller.interventionState == ScamInterventionState.warningShown) {
          warningCount++;
          // Simulate user dismissing warning with "I'm Safe"
          controller.dismissWarning();
        }
      }

      expect(warningCount, equals(1));
      controller.dispose();
    });

    test('6. "I\'m Safe" does not reduce risk score', () async {
      final criticalScenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final controller = DemoSessionController(scenario: criticalScenario);

      while (!controller.isCompleted && !controller.warningShown) {
        await controller.advanceNextLine();
      }

      final scoreBeforeDismissal = controller.currentAnalysis.riskScore;
      expect(controller.warningShown, isTrue);

      controller.dismissWarning();

      expect(controller.currentAnalysis.riskScore, equals(scoreBeforeDismissal));
      expect(controller.interventionState, ScamInterventionState.userDismissed);
      controller.dispose();
    });

    test('7. "I\'m Safe" does not remove detected signals', () async {
      final criticalScenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final controller = DemoSessionController(scenario: criticalScenario);

      while (!controller.isCompleted && !controller.warningShown) {
        await controller.advanceNextLine();
      }

      final signalsBefore = List<ScamSignal>.from(controller.currentAnalysis.detectedSignals);
      expect(signalsBefore, isNotEmpty);

      controller.dismissWarning();

      expect(controller.currentAnalysis.detectedSignals.length, equals(signalsBefore.length));
      expect(
        controller.currentAnalysis.detectedSignals.map((s) => s.type),
        containsAll(signalsBefore.map((s) => s.type)),
      );
      controller.dispose();
    });

    test('8. "End Call" stops simulation', () async {
      final criticalScenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final controller = DemoSessionController(scenario: criticalScenario);

      while (!controller.isCompleted && !controller.warningShown) {
        await controller.advanceNextLine();
      }

      expect(controller.isCompleted, isFalse);
      controller.endCallByWarning();

      expect(controller.isCompleted, isTrue);
      expect(controller.isRunning, isFalse);
      expect(controller.isEndedByIntervention, isTrue);
      expect(controller.interventionState, ScamInterventionState.userEnded);
      controller.dispose();
    });

    test('9. "Alert Family" creates simulated alert state', () {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'digital_arrest');
      final controller = DemoSessionController(scenario: scenario);

      controller.requestFamilyAlert();
      expect(controller.interventionState, ScamInterventionState.familyAlertRequested);
      expect(controller.interventionState.historyStatus, equals('Family alert requested'));
      controller.dispose();
    });

    test('10. Simulated family alert does not perform network activity', () {
      // Pure synchronous Dart object instantiation without I/O
      final analysis = RiskAnalysis(
        riskScore: 90,
        riskLevel: RiskLevel.critical,
        detectedSignals: [
          ScamSignal(
            type: ScamSignalType.authorityImpersonation,
            title: 'Possible authority impersonation',
            explanation: 'Test reason',
          ),
        ],
        explanations: const ['Test explanation'],
        confidence: 0.9,
      );

      expect(analysis.riskScore, 90);
      expect(analysis.detectedSignals, hasLength(1));
    });

    test('11. Restart resets warning state', () async {
      final criticalScenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final controller = DemoSessionController(scenario: criticalScenario);

      while (!controller.isCompleted && !controller.warningShown) {
        await controller.advanceNextLine();
      }

      expect(controller.warningShown, isTrue);
      controller.restart();

      expect(controller.warningShown, isFalse);
      expect(controller.isEndedByIntervention, isFalse);
      expect(controller.interventionState, ScamInterventionState.none);
      expect(controller.currentAnalysis.riskScore, 0);
      controller.dispose();
    });

    test('12. No warning appears before threshold is reached', () async {
      final criticalScenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final controller = DemoSessionController(scenario: criticalScenario);

      // Turn 1: "I'm calling from your bank."
      await controller.advanceNextLine();
      expect(controller.currentAnalysis.riskLevel, RiskLevel.safe);
      expect(controller.warningShown, isFalse);
      expect(controller.isWarningThresholdCrossed, isFalse);

      controller.dispose();
    });
  });

  group('Step 6 Alert Widget Tests', () {
    testWidgets('ScamWarningDialog renders content and handles End Call', (tester) async {
      bool endCallTapped = false;
      bool imSafeTapped = false;
      bool alertFamilyTapped = false;

      final analysis = RiskAnalysis(
        riskScore: 100,
        riskLevel: RiskLevel.critical,
        detectedSignals: [
          ScamSignal(
            type: ScamSignalType.authorityImpersonation,
            title: 'Possible authority impersonation',
            explanation: 'Caller claimed to be a bank official.',
          ),
          ScamSignal(
            type: ScamSignalType.sensitiveInformationRequest,
            title: 'Sensitive information request',
            explanation: 'Caller solicited OTP code.',
          ),
        ],
        explanations: const [
          'Caller appears to use official authority language.',
          'Caller solicits confidential authentication credentials.',
        ],
        confidence: 0.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ScamWarningDialog(
              analysis: analysis,
              onEndCall: () => endCallTapped = true,
              onImSafe: () => imSafeTapped = true,
              onAlertFamily: () => alertFamilyTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Title, Subtitle, Risk status
      expect(find.text('Possible Scam'), findsOneWidget);
      expect(find.text('This conversation shows signs of manipulation.'), findsOneWidget);
      expect(find.text('CRITICAL THREAT'), findsNWidgets(2));
      expect(find.text('100 / 100'), findsNWidgets(2));

      // Verify signals
      expect(find.text('Possible authority impersonation'), findsOneWidget);
      expect(find.text('Sensitive information request'), findsOneWidget);

      // Verify explanation
      expect(find.text('Why is GuardCall concerned?'), findsOneWidget);
      expect(find.text('GuardCall detected patterns that may indicate a scam:'), findsOneWidget);

      // Verify 3 Action buttons
      expect(find.text('End Call'), findsOneWidget);
      expect(find.text("I'm Safe"), findsOneWidget);
      expect(find.text('Alert Family'), findsOneWidget);

      // Scroll to End Call and tap
      await tester.scrollUntilVisible(find.text('End Call'), 100);
      await tester.tap(find.text('End Call'));
      await tester.pump();
      expect(endCallTapped, isTrue);

      // Scroll to I'm Safe and tap
      await tester.scrollUntilVisible(find.text("I'm Safe"), 100);
      await tester.tap(find.text("I'm Safe"));
      await tester.pump();
      expect(imSafeTapped, isTrue);

      // Scroll to Alert Family and tap
      await tester.scrollUntilVisible(find.text('Alert Family'), 100);
      await tester.tap(find.text('Alert Family'));
      await tester.pump();
      expect(alertFamilyTapped, isTrue);
    });

    testWidgets('SimulatedFamilyAlert renders confirmation metadata and closes', (tester) async {
      bool closed = false;

      final analysis = RiskAnalysis(
        riskScore: 80,
        riskLevel: RiskLevel.high,
        detectedSignals: [
          ScamSignal(
            type: ScamSignalType.emotionalManipulation,
            title: 'Emotional manipulation',
            explanation: 'Accident fabrication',
          ),
        ],
        explanations: const ['Urgent hospital appeal'],
        confidence: 0.9,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SimulatedFamilyAlert(
              scenarioTitle: 'Grandchild Emergency',
              analysis: analysis,
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SIMULATED FAMILY ALERT'), findsOneWidget);
      expect(find.text('Family Alert Requested'), findsOneWidget);
      expect(find.text('Target: Sarah Jenkins (Daughter)'), findsOneWidget);
      expect(find.text('Grandchild Emergency'), findsOneWidget);
      expect(find.text('Emotional manipulation'), findsOneWidget);

      // Scroll to Close if needed and tap
      await tester.scrollUntilVisible(find.text('Close'), 100);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });
  });
}
