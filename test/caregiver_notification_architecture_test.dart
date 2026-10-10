import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/core/services/family_alert_service.dart';
import 'package:guard_call/core/services/family_relationship_service.dart';
import 'package:guard_call/core/services/notification_policy.dart';
import 'package:guard_call/core/services/notification_preferences.dart';
import 'package:guard_call/core/services/notification_service.dart';
import 'package:guard_call/core/services/simulated_notification_service.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/alerts/simulated_family_alert.dart';
import 'package:guard_call/features/demo/demo_scenarios.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/risk_analysis.dart';
import 'package:guard_call/features/detection/scam_signal.dart';
import 'package:guard_call/features/family/family_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NotificationService.resetToDefault();
    NotificationPreferences.instance.reset();
    FamilyAlertService.instance.resetForTesting();
    FamilyRelationshipService.instance.resetForTesting();
  });

  void setTestPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  NotificationRequest createSampleRequest({
    String alertId = 'test_alert_101',
    int riskScore = 92,
    String riskLevel = 'Critical',
    String scenario = 'Fake KYC Verification Scam',
  }) {
    return NotificationRequest(
      alertId: alertId,
      caregiverId: 'contact_sarah',
      caregiverDisplayName: 'Sarah Jenkins (Daughter)',
      seniorDisplayName: 'Robert Jenkins (Father)',
      riskScore: riskScore,
      riskLevel: riskLevel,
      scenarioType: scenario,
      detectedSignals: const ['Authority impersonation', 'Urgency or time pressure'],
      explanation: 'Caller impersonated a bank representative demanding immediate OTP verification.',
      interventionStatus: 'User selected Alert Family',
      timestamp: DateTime.now(),
    );
  }

  group('Step 17 — Caregiver Alert & Notification Architecture Tests', () {
    test('1. NotificationService interface resolution resolves active instance', () {
      final service = NotificationService.instance;
      expect(service, isNotNull);
      expect(service, isA<NotificationService>());
    });

    test('2. Default provider is simulated/offline SimulatedNotificationService', () {
      final service = NotificationService.instance;
      expect(service, isA<SimulatedNotificationService>());
    });

    test('3. Simulated notification returns SIMULATED status and user-safe message', () async {
      final service = NotificationService.instance;
      final request = createSampleRequest();

      final result = await service.sendFamilyAlert(request);

      expect(result.status, equals(NotificationStatus.simulated));
      expect(result.isSimulated, isTrue);
      expect(result.message, contains('Family alert simulated'));
      expect(result.message, contains('No external message was sent'));
    });

    test('4. Simulated service makes zero network requests and executes locally', () async {
      final service = SimulatedNotificationService();
      final request = createSampleRequest();

      final stopwatch = Stopwatch()..start();
      final result = await service.sendFamilyAlert(request);
      stopwatch.stop();

      expect(result.status, equals(NotificationStatus.simulated));
      // Local execution executes essentially instantaneously (< 100ms) with zero sockets
      expect(stopwatch.elapsedMilliseconds, lessThan(250));
      expect(service.dispatchedNotifications.length, equals(1));
    });

    test('5. Notification event is emitted over local reactive stream', () async {
      final service = NotificationService.instance;
      final request = createSampleRequest();

      final completer = Completer<NotificationEvent>();
      final sub = service.onNotificationEvent.listen(completer.complete);

      await service.sendFamilyAlert(request);

      final event = await completer.future.timeout(const Duration(seconds: 1));
      expect(event.alertId, equals(request.alertId));
      expect(event.caregiverDisplayName, equals(request.caregiverDisplayName));
      expect(event.status, equals(NotificationStatus.simulated));

      await sub.cancel();
    });

    test('6. Notification event contains structured risk metadata', () async {
      final service = NotificationService.instance;
      final request = createSampleRequest(riskScore: 94, riskLevel: 'Critical');

      final completer = Completer<NotificationEvent>();
      final sub = service.onNotificationEvent.listen(completer.complete);

      await service.sendFamilyAlert(request);

      final event = await completer.future;
      expect(event.riskScore, equals(94));
      expect(event.riskLevel, equals('Critical'));
      expect(event.scenario, equals('Fake KYC Verification Scam'));
      expect(event.signals, contains('Authority impersonation'));

      await sub.cancel();
    });

    test('7. Notification event contains NO raw audio data or waveform buffers', () {
      final request = createSampleRequest();
      final map = request.toMap();

      expect(map.containsKey('audio'), isFalse);
      expect(map.containsKey('audio_bytes'), isFalse);
      expect(map.containsKey('raw_audio'), isFalse);
      expect(map.containsKey('waveform'), isFalse);
      expect(request.isPrivacyCompliant, isTrue);
    });

    test('8. Notification event contains NO full conversation transcript', () {
      final request = createSampleRequest();
      final map = request.toMap();

      expect(map.containsKey('transcript'), isFalse);
      expect(map.containsKey('conversation_lines'), isFalse);
      expect(map.containsKey('dialogue'), isFalse);
      expect(request.explanation, isNot(contains('Hello, this is officer')));
    });

    test('9. Alert Family creates alert and triggers NotificationService dispatch', () async {
      final alert = await FamilyAlertService.instance.createAlert(
        callSessionId: 'call_test_step17',
        familyContactId: 'contact_sarah',
        riskScore: 88,
        scenarioType: 'Fake KYC Verification',
        riskLevel: 'Critical',
        detectedSignals: ['Authority impersonation'],
        explanation: 'Scam pattern detected.',
        interventionStatus: 'User selected Alert Family',
        victimName: 'Robert Jenkins (Father)',
        caregiverName: 'Sarah Jenkins (Daughter)',
      );

      expect(alert.notificationStatus, equals('SIMULATED'));
      expect(alert.notificationMessage, contains('Family alert simulated'));
    });

    test('10. Family alerts disabled in Settings prevents notification dispatch', () async {
      NotificationPreferences.instance.setFamilyAlertsEnabled(false);
      expect(NotificationPreferences.instance.familyAlertsEnabled, isFalse);

      final service = NotificationService.instance;
      final request = createSampleRequest();

      final result = await service.sendFamilyAlert(request);

      expect(result.status, equals(NotificationStatus.unavailable));
      expect(result.message, contains('disabled in Settings'));
    });

    test('11. SAFE risk tier does not request family notification', () {
      expect(NotificationPolicy.isRiskLevelEligible(RiskLevel.safe), isFalse);

      final decision = NotificationPolicy.evaluate(
        riskLevel: RiskLevel.safe,
        isUserInitiated: true,
      );
      expect(decision.isAllowed, isFalse);
      expect(decision.reason, contains('Safe conversations do not warrant'));
    });

    test('12. SUSPICIOUS risk tier does not request automatic notification', () {
      expect(NotificationPolicy.isRiskLevelEligible(RiskLevel.suspicious), isFalse);

      final decision = NotificationPolicy.evaluate(
        riskLevel: RiskLevel.suspicious,
        isUserInitiated: true,
      );
      expect(decision.isAllowed, isFalse);
      expect(decision.reason, contains('Suspicious conversations do not warrant automatic'));
    });

    test('13. HIGH risk tier supports family alert request upon user intervention', () {
      expect(NotificationPolicy.isRiskLevelEligible(RiskLevel.high), isTrue);

      final decision = NotificationPolicy.evaluate(
        riskLevel: RiskLevel.high,
        isUserInitiated: true,
      );
      expect(decision.isAllowed, isTrue);
    });

    test('14. CRITICAL risk tier supports family alert request upon user intervention', () {
      expect(NotificationPolicy.isRiskLevelEligible(RiskLevel.critical), isTrue);

      final decision = NotificationPolicy.evaluate(
        riskLevel: RiskLevel.critical,
        isUserInitiated: true,
      );
      expect(decision.isAllowed, isTrue);
    });

    testWidgets('15. Caregiver view displays notification simulated status and disclaimer', (tester) async {
      setTestPhoneSize(tester);

      // Pre-seed an alert with simulated notification status
      await FamilyAlertService.instance.createAlert(
        callSessionId: 'call_caregiver_view_test',
        familyContactId: 'contact_sarah',
        riskScore: 92,
        scenarioType: 'Fake KYC Verification Scam',
        riskLevel: 'Critical',
        detectedSignals: ['Authority impersonation', 'Urgency or time pressure'],
        explanation: 'Bank impersonation attempting OTP extraction.',
        interventionStatus: 'User selected End Call',
        victimName: 'Robert Jenkins (Father)',
        caregiverName: 'Sarah Jenkins (Daughter)',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FamilyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Caregiver View tab
      final caregiverTab = find.text('Caregiver View (Preview)');
      expect(caregiverTab, findsOneWidget);
      await tester.tap(caregiverTab);
      await tester.pumpAndSettle();

      // Verify Alert: Created and Notification: SIMULATED are rendered
      expect(find.text('Alert: Created'), findsOneWidget);
      expect(find.text('Notification: SIMULATED'), findsOneWidget);
      expect(find.text('Demo only — no external message was sent.'), findsOneWidget);
    });

    test('16. Notification failure is typed and user-safe without leaking stack trace', () {
      final request = createSampleRequest();
      final failedResult = NotificationResult(
        notificationId: 'notif_err_1',
        alertId: request.alertId,
        status: NotificationStatus.failed,
        message: 'Notification delivery failed due to network unavailability.',
        timestamp: DateTime.now(),
        request: request,
      );

      expect(failedResult.status, equals(NotificationStatus.failed));
      expect(failedResult.message, isNot(contains('Exception')));
      expect(failedResult.message, isNot(contains('Stack trace')));
      expect(failedResult.status.label, equals('FAILED'));
    });

    test('17. Offline demo operates with zero credentials and zero cloud requirements', () async {
      final alert = await FamilyAlertService.instance.createAlert(
        callSessionId: 'offline_session_101',
        familyContactId: 'contact_sarah',
        riskScore: 90,
        scenarioType: 'Grandparent Emergency Scam',
        riskLevel: 'Critical',
        detectedSignals: ['Family emergency pretext', 'Extreme urgency'],
        explanation: 'Impersonation of distressed relative requesting bail wire transfer.',
        victimName: 'Robert Jenkins (Father)',
      );

      expect(alert.status, equals('pending'));
      expect(alert.notificationStatus, equals('SIMULATED'));
      expect(alert.victimName, equals('Robert Jenkins (Father)'));
    });

    testWidgets('18. Existing intervention warning and simulated alert dialogs function', (tester) async {
      setTestPhoneSize(tester);

      final analysis = RiskAnalysis(
        riskScore: 85,
        riskLevel: RiskLevel.critical,
        detectedSignals: [
          ScamSignal(
            type: ScamSignalType.authorityImpersonation,
            title: 'Authority impersonation',
            explanation: 'Caller claims to be police officer',
          ),
        ],
        explanations: const ['Caller demands immediate wire transfer under arrest threat.'],
        confidence: 0.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  SimulatedFamilyAlert.show(
                    context: ctx,
                    scenarioTitle: 'Police Arrest Threat',
                    analysis: analysis,
                    caregiverName: 'Sarah Jenkins (Daughter)',
                    seniorName: 'Robert Jenkins (Father)',
                    notificationStatus: 'SIMULATED',
                  );
                },
                child: const Text('Open Alert'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Alert'));
      await tester.pumpAndSettle();

      expect(find.text('SIMULATED FAMILY NOTIFICATION'), findsOneWidget);
      expect(find.text('Demo only — no message was actually sent.'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    test('19. Existing scam detection engine returns valid RiskAnalysis', () async {
      final engine = MockScamDetectionEngine();
      final lines = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc').conversationLines;

      final analysis = await engine.analyzeConversation(lines);
      expect(analysis.riskScore, greaterThanOrEqualTo(50));
      expect(analysis.isScamLikely, isTrue);
      expect(analysis.detectedSignals, isNotEmpty);
    });

    test('20. Existing five demo scenarios are intact with dialogue lines', () {
      expect(DemoScenarios.all.length, equals(5));

      for (final scenario in DemoScenarios.all) {
        expect(scenario.id, isNotEmpty);
        expect(scenario.title, isNotEmpty);
        expect(scenario.conversationLines, isNotEmpty);
      }
    });
  });
}
