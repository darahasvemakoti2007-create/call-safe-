import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/demo/demo_scenarios.dart';
import 'package:guard_call/features/demo/demo_session_controller.dart';
import 'package:guard_call/features/detection/scam_signal.dart';

void main() {
  group('DemoSessionController Lifecycle & Progressive Detection', () {
    test('1. Controller starts with no displayed lines and safe risk', () {
      final scenario = DemoScenarios.all.first;
      final controller = DemoSessionController(scenario: scenario);

      expect(controller.displayedLines, isEmpty);
      expect(controller.currentLineIndex, equals(0));
      expect(controller.isRunning, isFalse);
      expect(controller.isCompleted, isFalse);
      expect(controller.currentAnalysis.riskScore, equals(0));
      expect(controller.currentAnalysis.riskLevel, RiskLevel.safe);

      controller.dispose();
    });

    test('2. Starting simulation displays the first line immediately', () async {
      final scenario = DemoScenarios.all.first;
      final controller = DemoSessionController(
        scenario: scenario,
        stepInterval: const Duration(milliseconds: 100),
      );

      await controller.start();

      expect(controller.displayedLines.length, equals(1));
      expect(controller.displayedLines.first.text, equals(scenario.conversationLines.first.text));
      expect(controller.isRunning, isTrue);

      controller.dispose();
    });

    test('3. Risk analysis updates as conversation progresses', () async {
      final fakeKyc = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final controller = DemoSessionController(
        scenario: fakeKyc,
        stepInterval: const Duration(milliseconds: 50),
      );

      // Turn 1
      await controller.advanceNextLine();
      final scoreAfter1 = controller.currentAnalysis.riskScore;

      // Turn 2
      await controller.advanceNextLine();
      final scoreAfter2 = controller.currentAnalysis.riskScore;

      // Turn 3
      await controller.advanceNextLine();
      final scoreAfter3 = controller.currentAnalysis.riskScore;

      // Turn 4
      await controller.advanceNextLine();
      final scoreAfter4 = controller.currentAnalysis.riskScore;

      // As urgency and threats compound, the score increases
      expect(scoreAfter2, greaterThanOrEqualTo(scoreAfter1));
      expect(scoreAfter3, greaterThanOrEqualTo(scoreAfter2));
      expect(scoreAfter4, greaterThanOrEqualTo(scoreAfter3));
      expect(controller.displayedLines.length, equals(4));

      controller.dispose();
    });

    test('4. Final analysis matches the expected scenario risk level', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final controller = DemoSessionController(
        scenario: scenario,
        stepInterval: const Duration(milliseconds: 10),
      );

      while (!controller.isCompleted) {
        await controller.advanceNextLine();
      }

      expect(controller.isCompleted, isTrue);
      expect(controller.currentAnalysis.riskLevel, scenario.expectedRiskLevel);

      controller.dispose();
    });

    test('5. Fake KYC reaches Critical', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final controller = DemoSessionController(scenario: scenario);

      while (!controller.isCompleted) {
        await controller.advanceNextLine();
      }

      expect(controller.currentAnalysis.riskLevel, RiskLevel.critical);
      expect(controller.currentAnalysis.riskScore, greaterThanOrEqualTo(85));
      expect(
        controller.currentAnalysis.detectedSignals.any((s) => s.type == ScamSignalType.sensitiveInformationRequest),
        isTrue,
      );

      controller.dispose();
    });

    test('6. Digital Arrest reaches Critical', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'digital_arrest');
      final controller = DemoSessionController(scenario: scenario);

      while (!controller.isCompleted) {
        await controller.advanceNextLine();
      }

      expect(controller.currentAnalysis.riskLevel, RiskLevel.critical);
      expect(controller.currentAnalysis.riskScore, greaterThanOrEqualTo(85));
      expect(
        controller.currentAnalysis.detectedSignals.any((s) => s.type == ScamSignalType.isolation),
        isTrue,
      );

      controller.dispose();
    });

    test('7. Grandchild Emergency reaches High', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'grandchild_emergency');
      final controller = DemoSessionController(scenario: scenario);

      while (!controller.isCompleted) {
        await controller.advanceNextLine();
      }

      expect(controller.currentAnalysis.riskLevel, RiskLevel.high);
      expect(controller.currentAnalysis.riskScore, inInclusiveRange(70, 84));

      controller.dispose();
    });

    test('8. Genuine Bank remains Safe', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'genuine_bank');
      final controller = DemoSessionController(scenario: scenario);

      while (!controller.isCompleted) {
        await controller.advanceNextLine();
      }

      expect(controller.currentAnalysis.riskLevel, RiskLevel.safe);
      expect(controller.currentAnalysis.riskScore, lessThanOrEqualTo(40));
      expect(controller.currentAnalysis.detectedSignals, isEmpty);

      controller.dispose();
    });

    test('9. Genuine Hospital remains Safe', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'genuine_hospital');
      final controller = DemoSessionController(scenario: scenario);

      while (!controller.isCompleted) {
        await controller.advanceNextLine();
      }

      expect(controller.currentAnalysis.riskLevel, RiskLevel.safe);
      expect(controller.currentAnalysis.riskScore, lessThanOrEqualTo(40));
      expect(controller.currentAnalysis.detectedSignals, isEmpty);

      controller.dispose();
    });

    test('10. Restart resets the simulation cleanly', () async {
      final scenario = DemoScenarios.all.first;
      final controller = DemoSessionController(scenario: scenario);

      await controller.advanceNextLine();
      await controller.advanceNextLine();
      expect(controller.displayedLines.length, equals(2));

      controller.restart();

      expect(controller.displayedLines, isEmpty);
      expect(controller.currentLineIndex, equals(0));
      expect(controller.isRunning, isFalse);
      expect(controller.isCompleted, isFalse);
      expect(controller.currentAnalysis.riskScore, equals(0));

      controller.dispose();
    });

    test('11. Completion state is correct and stops playback', () async {
      final scenario = DemoScenarios.all.first;
      final controller = DemoSessionController(scenario: scenario);

      while (!controller.isCompleted) {
        await controller.advanceNextLine();
      }

      expect(controller.isCompleted, isTrue);
      expect(controller.isRunning, isFalse);
      expect(controller.displayedLines.length, equals(scenario.conversationLines.length));

      controller.dispose();
    });

    test('12. Timer and controller disposal is safe', () async {
      final scenario = DemoScenarios.all.first;
      final controller = DemoSessionController(
        scenario: scenario,
        stepInterval: const Duration(milliseconds: 50),
      );

      await controller.start();
      controller.pause();
      controller.resume();

      // Disposal should cancel timer with no exceptions
      expect(() => controller.dispose(), returnsNormally);
    });
  });
}
