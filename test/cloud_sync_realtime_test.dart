import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/core/services/call_session_service.dart';
import 'package:guard_call/core/services/family_alert_service.dart';
import 'package:guard_call/core/services/family_contact_service.dart';
import 'package:guard_call/core/services/realtime_service.dart';
import 'package:guard_call/core/services/risk_signal_service.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/alerts/simulated_family_alert.dart';
import 'package:guard_call/features/detection/risk_analysis.dart';
import 'package:guard_call/features/detection/scam_signal.dart';
import 'package:guard_call/features/history/call_history_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CallSessionService.instance.resetForTesting();
    RiskSignalService.instance.resetForTesting();
    FamilyContactService.instance.resetForTesting();
    FamilyAlertService.instance.resetForTesting();
    RealtimeService.instance.resetForTesting();
    CallHistoryRepository.instance.clear();
  });

  group('Phase B & C — Call Session & Risk Signal Mapping', () {
    test('1. CallSession model serializes and deserializes accurately', () {
      final now = DateTime.now();
      final session = CallSession(
        id: '11111111-1111-1111-1111-111111111111',
        userId: '22222222-2222-2222-2222-222222222222',
        startedAt: now,
        durationSeconds: 42,
        riskScore: 88,
        riskLevel: 'critical',
        scenarioType: 'fake_kyc',
        interventionStatus: 'userEnded',
      );

      final map = session.toMap();
      expect(map['id'], '11111111-1111-1111-1111-111111111111');
      expect(map['user_id'], '22222222-2222-2222-2222-222222222222');
      expect(map['duration_seconds'], 42);
      expect(map['risk_score'], 88);
      expect(map['risk_level'], 'critical');
      expect(map['scenario_type'], 'fake_kyc');
      expect(map['intervention_status'], 'userEnded');

      final fromMap = CallSession.fromMap(map);
      expect(fromMap.id, session.id);
      expect(fromMap.userId, session.userId);
      expect(fromMap.durationSeconds, 42);
      expect(fromMap.riskScore, 88);
      expect(fromMap.riskLevel, 'critical');
      expect(fromMap.scenarioType, 'fake_kyc');
      expect(fromMap.interventionStatus, 'userEnded');
    });

    test('2. RiskSignalRecord model maps structured signals without dialogue text', () {
      final now = DateTime.now();
      final signal = RiskSignalRecord(
        id: 'sig-001',
        callSessionId: 'call-001',
        signalType: 'authority_impersonation',
        severity: 'critical',
        explanation: 'Caller demanded urgent verification under legal threat',
        detectedAt: now,
      );

      final map = signal.toMap();
      expect(map['call_session_id'], 'call-001');
      expect(map['signal_type'], 'authority_impersonation');
      expect(map['severity'], 'critical');
      expect(map['explanation'], contains('urgent verification'));
      // Verifies zero raw transcript fields exist in payload
      expect(map.containsKey('raw_transcript'), isFalse);
      expect(map.containsKey('audio_url'), isFalse);

      final restored = RiskSignalRecord.fromMap(map);
      expect(restored.signalType, 'authority_impersonation');
      expect(restored.severity, 'critical');
      expect(restored.callSessionId, 'call-001');
    });
  });

  group('Phase D — Family Contact CRUD Behavior', () {
    test('3. FamilyContactService supports complete local/demo CRUD cycle', () async {
      final service = FamilyContactService.instance;

      // 1. Initial demo contact exists
      final initial = await service.getFamilyContacts();
      expect(initial.length, 1);
      expect(initial.first.name, 'Sarah Jenkins');
      expect(initial.first.relationship, 'Daughter');

      // 2. Add new contact
      final added = await service.addFamilyContact(
        name: 'Robert Jenkins',
        relationship: 'Son',
        contactIdentifier: '+1 (555) 987-6543',
        enabled: true,
      );
      expect(added.name, 'Robert Jenkins');

      final updatedList = await service.getFamilyContacts();
      expect(updatedList.length, 2);

      // 3. Toggle enabled
      await service.toggleContactEnabled(added.id, false);
      final disabledCheck = await service.getFamilyContacts();
      final disabledItem = disabledCheck.firstWhere((c) => c.id == added.id);
      expect(disabledItem.enabled, isFalse);

      // 4. Update contact
      final modified = disabledItem.copyWith(name: 'Robert Jenkins Jr.');
      await service.updateFamilyContact(modified);
      final afterUpdate = await service.getFamilyContacts();
      expect(afterUpdate.any((c) => c.name == 'Robert Jenkins Jr.'), isTrue);

      // 5. Remove contact
      await service.removeFamilyContact(added.id);
      final finalList = await service.getFamilyContacts();
      expect(finalList.length, 1);
      expect(finalList.any((c) => c.name == 'Robert Jenkins Jr.'), isFalse);
    });
  });

  group('Phase E & H — Family Alert Service & Mapping', () {
    test('4. FamilyAlertRecord maps accurately with initial status pending', () async {
      final service = FamilyAlertService.instance;

      final alert = await service.createAlert(
        callSessionId: 'session-xyz',
        familyContactId: 'contact-abc',
        riskScore: 95,
      );

      expect(alert.callSessionId, 'session-xyz');
      expect(alert.familyContactId, 'contact-abc');
      expect(alert.riskScore, 95);
      expect(alert.status, 'pending');

      final map = alert.toMap();
      expect(map['status'], 'pending');

      final fromMap = FamilyAlertRecord.fromMap(map);
      expect(fromMap.status, 'pending');
      expect(fromMap.riskScore, 95);
    });

    test('5. Offline mode operates completely in-memory with zero remote calls', () async {
      expect(CallSessionService.instance.isConfigured, isFalse);
      expect(RiskSignalService.instance.isConfigured, isFalse);
      expect(FamilyContactService.instance.isConfigured, isFalse);
      expect(FamilyAlertService.instance.isConfigured, isFalse);
      expect(RealtimeService.instance.isConfigured, isFalse);

      final session = await CallSessionService.instance.createCallSession(
        userId: 'demo-user',
        startedAt: DateTime.now(),
        durationSeconds: 30,
        riskScore: 75,
        riskLevel: 'high',
      );
      expect(session.id, isNotEmpty);

      final signals = await RiskSignalService.instance.createRiskSignals([
        RiskSignalRecord(
          callSessionId: session.id,
          signalType: 'urgency',
          severity: 'high',
          explanation: 'Fast response demanded',
          detectedAt: DateTime.now(),
        ),
      ]);
      expect(signals.length, 1);

      final fetchedSignals = await RiskSignalService.instance.getSignalsForCall(session.id);
      expect(fetchedSignals.length, 1);
      expect(fetchedSignals.first.signalType, 'urgency');
    });

    test('6. Cloud sync failure does not crash the demo', () async {
      // In offline mode, services safely catch and retain in-memory copies
      final session = await CallSessionService.instance.createCallSession(
        id: 'unusual-id',
        userId: 'user-fail-test',
        startedAt: DateTime.now(),
        durationSeconds: 15,
        riskScore: 90,
        riskLevel: 'critical',
      );
      expect(session.id, 'unusual-id');

      // Update non-existent record gracefully returns null
      final updated = await CallSessionService.instance.updateCallSession(
        id: 'non-existent',
        userId: 'user-fail-test',
        interventionStatus: 'none',
      );
      expect(updated, isNull);
    });
  });

  group('Phase F & G — Realtime Service Lifecycle & Security', () {
    test('7. RealtimeService emits simulated alert and unsubscribes cleanly', () async {
      final realtime = RealtimeService.instance;
      expect(realtime.state, RealtimeAlertState.disconnected);

      FamilyAlertRecord? received;
      final sub = realtime.alertStream.listen((alert) {
        received = alert;
      });

      const testAlert = FamilyAlertRecord(
        id: 'sim-alert-1',
        callSessionId: 'call-1',
        familyContactId: 'contact-1',
        riskScore: 92,
        status: 'pending',
      );

      realtime.emitSimulatedAlert(testAlert);
      await pumpEventQueue();

      expect(received, isNotNull);
      expect(received?.id, 'sim-alert-1');
      expect(received?.riskScore, 92);

      await realtime.unsubscribe();
      expect(realtime.state, RealtimeAlertState.disconnected);
      await sub.cancel();
    });

    test('8. Offline Realtime subscription safely transitions to disconnected', () async {
      final realtime = RealtimeService.instance;
      await realtime.subscribeToUserAlerts(userId: 'offline-user');
      expect(realtime.state, RealtimeAlertState.disconnected);
      expect(realtime.lastError, isNull);
    });
  });

  group('Phase H — Intervention Dialog Cloud vs Demo UI', () {
    testWidgets('9. Alert Family in Demo Mode displays simulation notice', (tester) async {
      final mockAnalysis = RiskAnalysis(
        riskScore: 90,
        riskLevel: RiskLevel.critical,
        detectedSignals: [
          ScamSignal(
            type: ScamSignalType.urgency,
            title: 'Immediate Urgency',
            explanation: 'Caller demands immediate action.',
          ),
        ],
        explanations: const ['Urgent demands detected.'],
        confidence: 0.9,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  SimulatedFamilyAlert.show(
                    context: ctx,
                    scenarioTitle: 'Fake KYC Scenario',
                    analysis: mockAnalysis,
                    isCloudRecorded: false,
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

      expect(find.text('SIMULATED FAMILY ALERT'), findsOneWidget);
      expect(find.text('Family Alert Requested'), findsOneWidget);
      expect(find.textContaining('Simulation only'), findsOneWidget);
    });

    testWidgets('10. Alert Family in Supabase mode displays Cloud Sync recorded status', (tester) async {
      final mockAnalysis = RiskAnalysis(
        riskScore: 95,
        riskLevel: RiskLevel.critical,
        detectedSignals: [
          ScamSignal(
            type: ScamSignalType.authorityImpersonation,
            title: 'Authority Impersonation',
            explanation: 'Impersonating police official.',
          ),
        ],
        explanations: const ['Impersonating law enforcement.'],
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
                    scenarioTitle: 'Digital Arrest Scenario',
                    analysis: mockAnalysis,
                    isCloudRecorded: true,
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

      expect(find.text('ALERT REQUEST RECORDED'), findsOneWidget);
      expect(find.text('Alert Request Recorded'), findsOneWidget);
      expect(find.textContaining('Cloud Sync: Alert record created in Supabase'), findsOneWidget);
      expect(find.textContaining('status: pending'), findsOneWidget);
    });
  });
}
