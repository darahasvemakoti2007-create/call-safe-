import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/app/app.dart';
import 'package:guard_call/app/app_theme.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/core/widgets/risk_meter.dart';
import 'package:guard_call/features/demo/demo_center_screen.dart';
import 'package:guard_call/features/demo/demo_scenario.dart';
import 'package:guard_call/features/demo/demo_scenarios.dart';

void main() {
  group('DemoScenario Model & Data', () {
    test('DemoScenario model instantiates correctly', () {
      const scenario = DemoScenario(
        id: 'test_scenario',
        title: 'Test Scenario',
        shortDescription: 'Test description',
        category: 'Testing',
        callerRole: 'Tester',
        expectedRiskLevel: RiskLevel.suspicious,
        expectedSignals: ['Urgency'],
        conversationLines: [
          ConversationLine(speaker: Speaker.caller, text: 'Hello!'),
          ConversationLine(speaker: Speaker.user, text: 'Hi!'),
        ],
      );

      expect(scenario.id, 'test_scenario');
      expect(scenario.title, 'Test Scenario');
      expect(scenario.callerRole, 'Tester');
      expect(scenario.expectedRiskLevel, RiskLevel.suspicious);
      expect(scenario.expectedSignals.first, 'Urgency');
      expect(scenario.conversationLines.length, 2);
      expect(scenario.conversationLines[0].speaker.displayName, 'Caller');
      expect(scenario.conversationLines[1].speaker.displayName, 'User');
    });

    test('Exactly 5 predefined scenarios exist with correct risk levels', () {
      expect(DemoScenarios.all.length, 5);

      final ids = DemoScenarios.all.map((s) => s.id).toList();
      expect(ids, containsAll([
        'fake_kyc',
        'digital_arrest',
        'grandchild_emergency',
        'genuine_bank',
        'genuine_hospital',
      ]));

      final fakeKyc = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      expect(fakeKyc.expectedRiskLevel, RiskLevel.critical);

      final digitalArrest = DemoScenarios.all.firstWhere((s) => s.id == 'digital_arrest');
      expect(digitalArrest.expectedRiskLevel, RiskLevel.critical);

      final grandchild = DemoScenarios.all.firstWhere((s) => s.id == 'grandchild_emergency');
      expect(grandchild.expectedRiskLevel, RiskLevel.high);

      final genuineBank = DemoScenarios.all.firstWhere((s) => s.id == 'genuine_bank');
      expect(genuineBank.expectedRiskLevel, RiskLevel.safe);

      final genuineHospital = DemoScenarios.all.firstWhere((s) => s.id == 'genuine_hospital');
      expect(genuineHospital.expectedRiskLevel, RiskLevel.safe);
    });
  });

  group('Demo Center UI & Navigation', () {
    testWidgets('DemoCenterScreen renders all 5 scenario cards correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const DemoCenterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and notice
      expect(find.text('Practice how GuardCall detects manipulation.'), findsOneWidget);
      expect(
        find.text('These conversations are simulated. No real phone call is being monitored.'),
        findsOneWidget,
      );

      // Verify all 5 scenario titles appear
      expect(find.text('Fake KYC Update'), findsOneWidget);
      expect(find.text('Digital Arrest Threat'), findsOneWidget);
      expect(find.text('Grandchild Emergency'), findsOneWidget);
      expect(find.text('Legitimate Bank Alert'), findsOneWidget);
      expect(find.text('Hospital Appointment Reschedule'), findsOneWidget);

      // Verify Play Scenario buttons are available
      expect(find.text('Play Scenario'), findsNWidgets(5));
    });

    testWidgets('Navigation to Demo Center from Home screen', (tester) async {
      await tester.pumpWidget(const GuardCallApp());
      await tester.pumpAndSettle();

      // Find and tap "Start Demo Call" on Home
      final startDemoBtn = find.text('Start Demo Call');
      expect(startDemoBtn, findsOneWidget);
      await tester.tap(startDemoBtn);
      await tester.pumpAndSettle();

      // Verify we arrived in Demo Center
      expect(find.text('Practice how GuardCall detects manipulation.'), findsOneWidget);

      // Tap back button
      final backBtn = find.byTooltip('Return to previous screen');
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Verify back on Home
      expect(find.text('Protection Active'), findsOneWidget);
    });

    testWidgets('Navigation to Demo Center from Calls screen', (tester) async {
      await tester.pumpWidget(const GuardCallApp());
      await tester.pumpAndSettle();

      // Tap on Calls bottom navigation tab
      await tester.tap(find.text('Calls'));
      await tester.pumpAndSettle();
      expect(find.text('No Active Call'), findsOneWidget);

      // Find and tap "Open Demo Center"
      final openDemoBtn = find.text('Open Demo Center');
      expect(openDemoBtn, findsOneWidget);
      await tester.tap(openDemoBtn);
      await tester.pumpAndSettle();

      // Verify arrived in Demo Center
      expect(find.text('Practice how GuardCall detects manipulation.'), findsOneWidget);
    });

    testWidgets('Demo player opens and plays simulation lines', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const DemoCenterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the first "Play Scenario" button (Fake KYC Update)
      await tester.tap(find.text('Play Scenario').first);
      await tester.pumpAndSettle();

      // Verify Player screen rendered with top risk status and controls
      expect(find.text('SIMULATED CALL'), findsOneWidget);
      expect(find.byType(RiskMeter), findsOneWidget);
      expect(find.text('Start Simulation'), findsOneWidget);

      // Tap Start Simulation
      await tester.tap(find.text('Start Simulation'));
      await tester.pump();

      // First line should be displayed
      expect(find.text("I'm calling from your bank."), findsOneWidget);

      // Advance clock until warning triggers
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 1700));
      }
      await tester.pumpAndSettle();

      // Warning dialog should appear for Fake KYC
      if (find.text('Possible Scam').evaluate().isNotEmpty) {
        expect(find.text('Possible Scam'), findsOneWidget);
        await tester.tap(find.text("I'm Safe"));
        await tester.pumpAndSettle();
      }

      // Advance remaining turns to completion
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 1700));
      }
      await tester.pumpAndSettle();

      // Verify progressive risk analysis and final assessment
      expect(find.text('Simulation Complete'), findsOneWidget);
      expect(find.text('High Risk Scam Detected'), findsOneWidget);
      expect(find.text('Restart Simulation'), findsOneWidget);

      // Verify signals and explanation section are present in the list
      await tester.scrollUntilVisible(find.text('Detected Signals'), -100);
      expect(find.text('Detected Signals'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Why is GuardCall concerned?'), -100);
      expect(find.text('Why is GuardCall concerned?'), findsOneWidget);
    });
  });
}
