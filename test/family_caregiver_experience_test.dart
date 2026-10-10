import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guard_call/core/services/family_alert_service.dart';
import 'package:guard_call/core/services/family_relationship_service.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/alerts/scam_warning_dialog.dart';
import 'package:guard_call/features/demo/demo_scenarios.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/risk_analysis.dart';
import 'package:guard_call/features/detection/scam_signal.dart';
import 'package:guard_call/features/family/caregiver_alert_detail_dialog.dart';
import 'package:guard_call/features/family/family_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FamilyRelationshipService.instance.resetForTesting();
    FamilyAlertService.instance.resetForTesting();
  });

  void setTestPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Step 16 — Family Circle + Caregiver Experience Tests', () {
    testWidgets('1. Family Circle screen renders with senior view by default', (tester) async {
      setTestPhoneSize(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: FamilyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Family Circle'), findsOneWidget);
      expect(find.text('My Family Circle'), findsOneWidget);
      expect(find.text('Caregiver View (Preview)'), findsOneWidget);
      expect(find.text('Add Family Member'), findsOneWidget);
      expect(find.text('Your Privacy'), findsOneWidget);
    });

    testWidgets('2. Demo caregiver renders with DEMO badge and active authorization', (tester) async {
      setTestPhoneSize(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: FamilyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('DEMO'), findsOneWidget);
      expect(find.text('Active • RLS Authorized'), findsOneWidget);
      expect(find.text('Receive scam escalation alerts'), findsOneWidget);
    });

    testWidgets('3. Add Family Member sheet opens and displays required fields', (tester) async {
      setTestPhoneSize(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: FamilyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Family Member'));
      await tester.pumpAndSettle();

      expect(find.text('Caregiver Email *'), findsOneWidget);
      expect(find.text('Relationship *'), findsOneWidget);
      expect(find.text('Caregiver Name (Optional)'), findsOneWidget);
      expect(find.text('Demo Invitation Created'), findsOneWidget);
      expect(find.text('Create Pending Invitation'), findsOneWidget);
    });

    testWidgets('4. Invalid email is rejected with inline validation error', (tester) async {
      setTestPhoneSize(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: FamilyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Family Member'));
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(find.widgetWithText(TextField, 'Caregiver Email *'), 'not-an-email');
      await tester.tap(find.text('Create Pending Invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      // Verify invitation was not added to service
      final invs = await FamilyRelationshipService.instance.getMyInvitations();
      expect(invs, isEmpty);
    });

    testWidgets('5. Missing relationship is rejected with inline validation error', (tester) async {
      setTestPhoneSize(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: FamilyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Family Member'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Caregiver Email *'), 'valid@example.com');
      // Clear relationship
      await tester.enterText(find.widgetWithText(TextField, 'Relationship *'), '');
      await tester.tap(find.text('Create Pending Invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Relationship is required.'), findsOneWidget);
      final invs = await FamilyRelationshipService.instance.getMyInvitations();
      expect(invs, isEmpty);
    });

    testWidgets('6. Demo invitation creation succeeds and stores pending record', (tester) async {
      setTestPhoneSize(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: FamilyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Family Member'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Caregiver Email *'), 'son.caregiver@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Relationship *'), 'Son');
      await tester.enterText(find.widgetWithText(TextField, 'Caregiver Name (Optional)'), 'Michael Jenkins');
      await tester.tap(find.text('Create Pending Invitation'));
      await tester.pumpAndSettle();

      final invs = await FamilyRelationshipService.instance.getMyInvitations();
      expect(invs.length, 1);
      expect(invs.first.invitedEmail, 'son.caregiver@example.com');
      expect(invs.first.relationship, 'Son');
      expect(invs.first.displayName, 'Michael Jenkins');
      expect(invs.first.status, 'pending');
    });

    testWidgets('7. Pending invitation renders in Pending Invitations section', (tester) async {
      setTestPhoneSize(tester);
      await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'michael@example.com',
        relationship: 'Son',
        displayName: 'Michael Jenkins',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FamilyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Michael Jenkins (michael@example.com)'), findsOneWidget);
      expect(find.textContaining('Pending: Invitation waiting for caregiver acceptance'), findsOneWidget);
      expect(find.text('Revoke'), findsOneWidget);
    });

    testWidgets('8. Invitation revoke action transitions status to revoked', (tester) async {
      setTestPhoneSize(tester);
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'revoke.test@example.com',
        relationship: 'Guardian',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FamilyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Revoke'), findsOneWidget);
      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();

      // Confirm in dialog if confirmation dialog appears
      if (find.byType(AlertDialog).evaluate().isNotEmpty) {
        await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Revoke')));
        await tester.pumpAndSettle();
      }

      final updated = await FamilyRelationshipService.instance.getMyInvitations();
      expect(updated.firstWhere((i) => i.id == inv.id).status, 'revoked');
    });

    test('9. Alert Family creates simulated alert with full telemetry in memory', () async {
      final alert = await FamilyAlertService.instance.createAlert(
        callSessionId: 'test-session-step16',
        familyContactId: 'demo-contact-sarah',
        riskScore: 88,
        scenarioType: 'Digital Arrest Threat',
        riskLevel: 'Critical',
        detectedSignals: ['Authority impersonation', 'Fear or threat manipulation'],
        explanation: 'Caller claimed to be police officer demanding immediate payment.',
        interventionStatus: 'Family alert requested',
        victimName: 'Robert Jenkins (Father)',
      );

      expect(alert.status, 'pending');
      expect(alert.riskScore, 88);
      expect(alert.scenarioType, 'Digital Arrest Threat');
      expect(alert.victimName, 'Robert Jenkins (Father)');
      expect(alert.interventionStatus, 'Family alert requested');
    });

    test('10. Alert contains required risk metadata fields', () {
      final alert = FamilyAlertRecord(
        id: 'meta-alert-1',
        callSessionId: 'call-1',
        familyContactId: 'contact-1',
        riskScore: 78,
        status: 'pending',
        scenarioType: 'Fake KYC Verification',
        riskLevel: 'High',
        detectedSignals: const ['Urgency', 'Sensitive info'],
        explanation: 'Demanded OTP verification immediately.',
        interventionStatus: 'User selected End Call',
        victimName: 'Robert Jenkins (Father)',
      );

      expect(alert.riskScore, 78);
      expect(alert.scenarioType, isNotEmpty);
      expect(alert.riskLevel, 'High');
      expect(alert.detectedSignals, hasLength(2));
      expect(alert.explanation, isNotNull);
      expect(alert.interventionStatus, 'User selected End Call');
      expect(alert.victimName, contains('Robert'));
    });

    test('11. Alert does NOT contain raw audio bytes or audio file references', () {
      final alert = FamilyAlertRecord(
        id: 'no-audio-alert',
        callSessionId: 'call-1',
        familyContactId: 'contact-1',
        riskScore: 90,
      );

      final map = alert.toMap();
      expect(map.containsKey('audio'), isFalse);
      expect(map.containsKey('raw_audio'), isFalse);
      expect(map.containsKey('audio_bytes'), isFalse);
      expect(map.containsKey('audio_path'), isFalse);
    });

    test('12. Alert does NOT contain full conversation transcript', () {
      final alert = FamilyAlertRecord(
        id: 'no-transcript-alert',
        callSessionId: 'call-1',
        familyContactId: 'contact-1',
        riskScore: 90,
      );

      final map = alert.toMap();
      expect(map.containsKey('transcript'), isFalse);
      expect(map.containsKey('full_transcript'), isFalse);
      expect(map.containsKey('conversation_lines'), isFalse);
    });

    testWidgets('13. Caregiver view displays recent alert cards with score and threat', (tester) async {
      setTestPhoneSize(tester);
      await FamilyAlertService.instance.createAlert(
        callSessionId: 'demo-alert-display',
        familyContactId: 'demo-contact-sarah',
        riskScore: 92,
        scenarioType: 'Fake KYC Verification Scam',
        riskLevel: 'Critical',
        detectedSignals: ['Authority impersonation', 'Urgency or time pressure'],
        explanation: 'Caller impersonated a bank official threatening account closure.',
        interventionStatus: 'User selected End Call',
        victimName: 'Robert Jenkins (Father)',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FamilyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Caregiver View
      await tester.tap(find.text('Caregiver View (Preview)'));
      await tester.pumpAndSettle();

      expect(find.text('Caregiver Perspective Foundation'), findsOneWidget);
      expect(find.text('Robert Jenkins (Father)'), findsOneWidget);
      expect(find.text('LINKED'), findsOneWidget);
      expect(find.text('Threat: Fake KYC Verification Scam'), findsOneWidget);
      expect(find.text('Score: 92/100'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
    });

    testWidgets('14. Caregiver detail dialog displays what happened, why flagged, what user did', (tester) async {
      setTestPhoneSize(tester);
      final alert = FamilyAlertRecord(
        id: 'detail-alert-1',
        callSessionId: 'session-123',
        familyContactId: 'contact-sarah',
        riskScore: 85,
        status: 'pending',
        scenarioType: 'Digital Arrest Threat',
        riskLevel: 'Critical',
        detectedSignals: const ['Authority impersonation', 'Fear or threat manipulation'],
        explanation: 'Caller claimed to be a police investigator demanding urgent bail funds.',
        interventionStatus: 'User requested Family Alert',
        victimName: 'Robert Jenkins (Father)',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  CaregiverAlertDetailDialog.show(
                    context: ctx,
                    alert: alert,
                    onReviewed: () {},
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Scam Escalation Alert'), findsOneWidget);
      expect(find.text('Protected Senior: Robert Jenkins (Father)'), findsOneWidget);
      expect(find.text('WHAT HAPPENED'), findsOneWidget);
      expect(find.text('WHY IT WAS FLAGGED (DETECTED SIGNALS)'), findsOneWidget);
      expect(find.text('WHAT THE USER DID'), findsOneWidget);
      expect(find.text('WHAT YOU CAN DO (CAREGIVER ACTIONS)'), findsOneWidget);
      expect(find.text('Authority impersonation'), findsOneWidget);
      expect(find.text('Fear or threat manipulation'), findsOneWidget);
      expect(find.text('User requested Family Alert'), findsOneWidget);
      expect(find.text('Contact Robert Jenkins (Father)'), findsOneWidget);
      expect(find.text('Mark as Reviewed'), findsOneWidget);
    });

    test('15. Caregiver cannot be authorized merely by email without linked relationship', () async {
      // In GuardCall security architecture, email is an invitation target.
      // An active relationship requires owner_user_id + caregiver_user_id authenticated pairing.
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'unlinked@example.com',
        relationship: 'Friend',
      );

      expect(inv.status, 'pending');

      // The unlinked email does NOT create an authorized relationship row
      final rels = await FamilyRelationshipService.instance.getMyRelationships();
      expect(rels.any((r) => r.caregiverUserId == 'unlinked@example.com'), isFalse);
    });

    test('16. Disabled relationship disables alert access', () async {
      final rels = await FamilyRelationshipService.instance.getMyRelationships();
      final defaultRel = rels.first;

      expect(defaultRel.enabled, isTrue);

      await FamilyRelationshipService.instance.enableRelationship(defaultRel.id, false);
      final updated = await FamilyRelationshipService.instance.getMyRelationships();
      expect(updated.first.enabled, isFalse);
    });

    test('17. Demo mode operates completely offline with zero network connectivity', () async {
      expect(FamilyRelationshipService.instance.isConfigured, isFalse);
      expect(FamilyAlertService.instance.isConfigured, isFalse);

      final rels = await FamilyRelationshipService.instance.getMyRelationships();
      expect(rels, isNotEmpty);

      final alerts = await FamilyAlertService.instance.getCaregiverAlerts();
      expect(alerts, isNotEmpty);

      final newAlert = await FamilyAlertService.instance.createAlert(
        callSessionId: 'offline-test',
        familyContactId: 'demo-contact',
        riskScore: 65,
      );
      expect(newAlert.riskScore, 65);
    });

    testWidgets('18. Existing intervention warning and simulated alert dialogs function', (tester) async {
      setTestPhoneSize(tester);
      final analysis = RiskAnalysis(
        riskScore: 82,
        riskLevel: RiskLevel.high,
        confidence: 0.9,
        timestamp: DateTime.now(),
        detectedSignals: [
          ScamSignal(
            type: ScamSignalType.authorityImpersonation,
            title: 'Authority Impersonation',
            explanation: 'Caller claimed to be bank manager.',
          ),
        ],
        explanations: const ['Urgent action required on account.'],
      );

      bool familyAlertTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  ScamWarningDialog.show(
                    context: ctx,
                    analysis: analysis,
                    onEndCall: () {},
                    onImSafe: () {},
                    onAlertFamily: () {
                      familyAlertTapped = true;
                    },
                  );
                },
                child: const Text('Show Warning'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show Warning'));
      await tester.pumpAndSettle();

      expect(find.text('Possible Scam'), findsOneWidget);
      expect(find.text('Alert Family'), findsOneWidget);
      await tester.tap(find.text('Alert Family'));
      await tester.pumpAndSettle();

      expect(familyAlertTapped, isTrue);
    });

    test('19. Existing scam detection engine returns valid RiskAnalysis', () async {
      final engine = MockScamDetectionEngine();
      final lines = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc').conversationLines;

      final analysis = await engine.analyzeConversation(lines);
      expect(analysis.riskScore, greaterThanOrEqualTo(50));
      expect(analysis.isScamLikely, isTrue);
      expect(analysis.detectedSignals, isNotEmpty);
    });

    test('20. Existing five demo scenarios are intact', () {
      final scenarios = DemoScenarios.all;
      expect(scenarios.length, 5);

      final kyc = scenarios.firstWhere((s) => s.id == 'fake_kyc');
      expect(kyc.title, 'Fake KYC Update');

      final arrest = scenarios.firstWhere((s) => s.id == 'digital_arrest');
      expect(arrest.title, 'Digital Arrest Threat');

      final grand = scenarios.firstWhere((s) => s.id == 'grandchild_emergency');
      expect(grand.title, 'Grandchild Emergency');

      final bank = scenarios.firstWhere((s) => s.id == 'genuine_bank');
      expect(bank.title, 'Legitimate Bank Alert');

      final hospital = scenarios.firstWhere((s) => s.id == 'genuine_hospital');
      expect(hospital.title, 'Hospital Appointment Reschedule');
    });
  });
}
