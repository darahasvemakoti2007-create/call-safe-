import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guard_call/app/app_theme.dart';
import 'package:guard_call/core/services/auth_service.dart';
import 'package:guard_call/core/services/auth_state.dart';
import 'package:guard_call/core/services/family_alert_service.dart';
import 'package:guard_call/core/services/family_relationship_service.dart';
import 'package:guard_call/core/services/notification_service.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/calls/live_microphone_controller.dart';
import 'package:guard_call/features/calls/live_microphone_screen.dart';
import 'package:guard_call/features/detection/microphone_audio_capture_service.dart';
import 'package:guard_call/features/detection/microphone_permission_handler.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/risk_analysis.dart';
import 'package:guard_call/features/detection/scam_signal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FamilyRelationshipService.instance.resetForTesting();
    FamilyAlertService.instance.resetForTesting();
    AuthState.instance.setMockUser(
      user: const AuthUser(
        id: 'owner-account-id',
        email: 'senior.owner@guardcall.local',
        name: 'Senior Owner',
      ),
      status: AuthStatus.authenticated,
    );
  });

  group('Step 13 — Family Invitation Workflow Verification', () {
    test('1. Creates valid invitation with pending status and 7-day expiration', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'caregiver.daughter@example.com',
        relationship: 'Daughter',
        displayName: 'Sarah',
      );

      expect(inv.id, isNotEmpty);
      expect(inv.status, 'pending');
      expect(inv.invitedEmail, 'caregiver.daughter@example.com');
      expect(inv.relationship, 'Daughter');
      expect(inv.displayName, 'Sarah');
      expect(inv.expiresAt, isNotNull);
      expect(inv.expiresAt!.isAfter(DateTime.now().add(const Duration(days: 6))), isTrue);
    });

    test('2. Successful acceptance by intended caregiver creates active authenticated relationship', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'caregiver.daughter@example.com',
        relationship: 'Daughter',
        displayName: 'Sarah',
      );

      final rel = await FamilyRelationshipService.instance.acceptInvitation(
        inv.id,
        caregiverUserId: 'caregiver-acct-101',
        caregiverEmail: 'caregiver.daughter@example.com',
        caregiverDisplayName: 'Sarah Jenkins',
      );

      expect(rel.id, isNotEmpty);
      expect(rel.ownerUserId, inv.ownerUserId);
      expect(rel.caregiverUserId, 'caregiver-acct-101');
      expect(rel.relationship, 'Daughter');
      expect(rel.displayName, 'Sarah');
      expect(rel.enabled, isTrue);

      // Verify invitation status is transitioned to accepted
      final invs = await FamilyRelationshipService.instance.getMyInvitations();
      final updatedInv = invs.firstWhere((i) => i.id == inv.id);
      expect(updatedInv.status, 'accepted');
    });

    test('3. Rejects acceptance when recipient email does not match invited email (wrong account)', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'intended.caregiver@example.com',
      );

      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          inv.id,
          caregiverUserId: 'wrong-acct-202',
          caregiverEmail: 'intruder@example.com',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('Unauthorized: Invitation was sent to'),
          ),
        ),
      );
    });

    test('4. Rejects self-acceptance (owner cannot accept their own invitation)', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'senior.owner@guardcall.local',
        ownerUserId: 'owner-account-id',
      );

      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          inv.id,
          caregiverUserId: 'owner-account-id',
          caregiverEmail: 'senior.owner@guardcall.local',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Self-acceptance is rejected'),
          ),
        ),
      );
    });

    test('5. Rejects expired invitation and transitions status to expired', () async {
      final expiredDate = DateTime.now().subtract(const Duration(hours: 1));
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'late.caregiver@example.com',
        expiresAt: expiredDate,
      );

      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          inv.id,
          caregiverUserId: 'caregiver-late-303',
          caregiverEmail: 'late.caregiver@example.com',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot accept an expired invitation'),
          ),
        ),
      );

      final invs = await FamilyRelationshipService.instance.getMyInvitations();
      final updated = invs.firstWhere((i) => i.id == inv.id);
      expect(updated.status, 'expired');
    });

    test('6. Rejects already-accepted or revoked invitations', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'caregiver@example.com',
      );

      await FamilyRelationshipService.instance.acceptInvitation(
        inv.id,
        caregiverUserId: 'caregiver-404',
        caregiverEmail: 'caregiver@example.com',
      );

      // Attempting to accept a second time throws
      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          inv.id,
          caregiverUserId: 'caregiver-404',
          caregiverEmail: 'caregiver@example.com',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Invitation has already been accepted'),
          ),
        ),
      );

      // Revoked invitation cannot be accepted
      final inv2 = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'revoked@example.com',
      );
      await FamilyRelationshipService.instance.revokeInvitation(inv2.id);

      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          inv2.id,
          caregiverUserId: 'caregiver-505',
          caregiverEmail: 'revoked@example.com',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot accept a revoked invitation'),
          ),
        ),
      );
    });

    test('7. Prevents duplicate active relationships between same owner and caregiver', () async {
      final inv1 = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'caregiver@example.com',
      );
      await FamilyRelationshipService.instance.acceptInvitation(
        inv1.id,
        caregiverUserId: 'caregiver-606',
        caregiverEmail: 'caregiver@example.com',
      );

      final inv2 = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'caregiver@example.com',
      );

      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          inv2.id,
          caregiverUserId: 'caregiver-606',
          caregiverEmail: 'caregiver@example.com',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Duplicate active relationship'),
          ),
        ),
      );
    });

    test('8. Re-activates previously disabled relationship upon accepting a new invitation', () async {
      final inv1 = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'caregiver@example.com',
      );
      final rel1 = await FamilyRelationshipService.instance.acceptInvitation(
        inv1.id,
        caregiverUserId: 'caregiver-707',
        caregiverEmail: 'caregiver@example.com',
      );

      // Caregiver relationship is disabled by owner
      await FamilyRelationshipService.instance.enableRelationship(rel1.id, false);
      final disabledRel = (await FamilyRelationshipService.instance.getMyRelationships())
          .firstWhere((r) => r.id == rel1.id);
      expect(disabledRel.enabled, isFalse);

      // Owner issues new invitation and caregiver accepts
      final inv2 = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'caregiver@example.com',
        relationship: 'Primary Caregiver',
      );
      final reactivatedRel = await FamilyRelationshipService.instance.acceptInvitation(
        inv2.id,
        caregiverUserId: 'caregiver-707',
        caregiverEmail: 'caregiver@example.com',
      );

      expect(reactivatedRel.enabled, isTrue);
      expect(reactivatedRel.relationship, 'Primary Caregiver');
    });

    test('9. Offline data persists across simulated app restarts via loadFromStorage', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'persistent@example.com',
        relationship: 'Son',
        displayName: 'Alex',
      );

      await FamilyRelationshipService.instance.acceptInvitation(
        inv.id,
        caregiverUserId: 'caregiver-alex-808',
        caregiverEmail: 'persistent@example.com',
      );

      // Simulate app restart by clearing memory and reloading from SharedPreferences
      FamilyRelationshipService.instance.resetForTesting();
      await FamilyRelationshipService.instance.loadFromStorage();

      final restoredRels = await FamilyRelationshipService.instance.getMyRelationships();
      expect(restoredRels.any((r) => r.caregiverUserId == 'caregiver-alex-808'), isTrue);

      final restoredInvs = await FamilyRelationshipService.instance.getMyInvitations();
      expect(restoredInvs.any((i) => i.id == inv.id && i.status == 'accepted'), isTrue);
    });
  });

  group('Step 13 — Caregiver Alerts Verification & Deduplication', () {
    test('10. High-risk assessment creates structured alert with correct category and score', () async {
      final alert = await FamilyAlertService.instance.createAlert(
        callSessionId: 'session_risk_92',
        familyContactId: 'caregiver-sarah-101',
        caregiverName: 'Sarah Jenkins',
        riskScore: 92,
        scenarioType: 'Fake KYC Verification',
        riskLevel: 'Critical',
        detectedSignals: const ['Authority impersonation', 'Urgency', 'Sensitive info'],
        explanation: 'Caller demanded immediate OTP verification.',
      );

      expect(alert.id, isNotNull);
      expect(alert.callSessionId, 'session_risk_92');
      expect(alert.familyContactId, 'caregiver-sarah-101');
      expect(alert.riskScore, 92);
      expect(alert.scenarioType, 'Fake KYC Verification');
      expect(alert.riskLevel, 'Critical');
      expect(alert.detectedSignals?.length, 3);
      expect(alert.notificationStatus, equals('SIMULATED'));

      final memoryAlerts = FamilyAlertService.instance.inMemoryAlerts;
      expect(memoryAlerts.first.id, alert.id);
    });

    test('11. Repeated alert creation with same callSessionId and contact is deduplicated', () async {
      final alert1 = await FamilyAlertService.instance.createAlert(
        callSessionId: 'duplicate_session_test',
        familyContactId: 'caregiver-sarah-101',
        riskScore: 88,
        scenarioType: 'Digital Arrest',
      );

      final countBefore = FamilyAlertService.instance.inMemoryAlerts.length;

      // Repeated dispatch with identical session and contact
      final alert2 = await FamilyAlertService.instance.createAlert(
        callSessionId: 'duplicate_session_test',
        familyContactId: 'caregiver-sarah-101',
        riskScore: 88,
        scenarioType: 'Digital Arrest',
      );

      final countAfter = FamilyAlertService.instance.inMemoryAlerts.length;

      expect(countAfter, equals(countBefore)); // No duplicate added!
      expect(alert2.id, equals(alert1.id));
    });

    test('12. Privacy check: Alert telemetry contains high-level signals and no raw transcripts or credentials', () async {
      final sensitiveAnalysis = RiskAnalysis(
        riskScore: 95,
        riskLevel: RiskLevel.critical,
        detectedSignals: [
          ScamSignal(
            type: ScamSignalType.sensitiveInformationRequest,
            title: 'Sensitive information request',
            explanation: 'Caller asked for OTP 492019 and password SecretPass123.',
          ),
        ],
        explanations: ['High risk due to credential solicitation.'],
        confidence: 0.95,
      );

      // Verify NotificationRequest privacy validation
      final req = NotificationRequest(
        alertId: 'privacy_test_alert',
        caregiverId: 'caregiver_1',
        caregiverDisplayName: 'Sarah',
        seniorDisplayName: 'Robert',
        riskScore: sensitiveAnalysis.riskScore,
        riskLevel: sensitiveAnalysis.riskLevel.label,
        scenarioType: 'Credential Phishing',
        detectedSignals: sensitiveAnalysis.detectedSignals.map((s) => s.title).toList(),
        explanation: sensitiveAnalysis.summary, // High-level summary only
        interventionStatus: 'User selected Alert Family',
        timestamp: DateTime.now(),
      );

      expect(req.isPrivacyCompliant, isTrue);
      // Ensure summary does not contain the raw OTP or password
      expect(req.explanation.contains('492019'), isFalse);
      expect(req.explanation.contains('SecretPass123'), isFalse);
    });

    test('13. NotificationService reports SIMULATED status without claiming external delivery', () async {
      final notifResult = await NotificationService.instance.sendFamilyAlert(
        NotificationRequest(
          alertId: 'audit_notif_1',
          caregiverId: 'caregiver_sarah',
          caregiverDisplayName: 'Sarah Jenkins',
          seniorDisplayName: 'Robert Jenkins',
          riskScore: 90,
          riskLevel: 'Critical',
          scenarioType: 'Digital Arrest',
          detectedSignals: const ['Threat', 'Financial pressure'],
          explanation: 'Assessed as Critical due to legal threats.',
          interventionStatus: 'Alert Family',
          timestamp: DateTime.now(),
        ),
      );

      expect(notifResult.status, equals(NotificationStatus.simulated));
      expect(notifResult.isSimulated, isTrue);
      expect(notifResult.message, contains('Family alert simulated in hackathon demo mode'));
      expect(notifResult.message, contains('No external message was sent'));
    });
  });

  group('Step 13 — Live Microphone Screen Alert Family Integration Widget Tests', () {
    testWidgets('14. Tapping Alert Family from ScamWarningDialog records alert and shows SnackBar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockCapture = MockMicrophoneAudioCaptureService();
      final controller = LiveMicrophoneController(
        permissionHandler: MockMicrophonePermissionHandler(status: MicrophonePermissionStatus.granted),
        detectionEngine: const MockScamDetectionEngine(),
        audioCaptureService: mockCapture,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: LiveMicrophoneScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger high-risk scam phrase to open ScamWarningDialog
      await controller.startListening();
      await controller.addSpokenLine("This is a police investigation. Your account will be blocked within 10 minutes.");
      await controller.addSpokenLine("Tell me the OTP you just received immediately or you will be arrested.");
      await tester.pumpAndSettle();

      // Dialog must be visible
      expect(find.text('Possible Scam'), findsOneWidget);
      expect(find.text('Alert Family'), findsOneWidget);

      final alertCountBefore = FamilyAlertService.instance.inMemoryAlerts.length;

      // Tap Alert Family
      await tester.tap(find.text('Alert Family'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.text('Possible Scam'), findsNothing);

      // Honest SnackBar confirmation is shown
      expect(find.text('Family alert recorded locally for this call session.'), findsOneWidget);

      // FamilyAlertService received the alert
      final alertCountAfter = FamilyAlertService.instance.inMemoryAlerts.length;
      expect(alertCountAfter, alertCountBefore + 1);

      final saved = FamilyAlertService.instance.inMemoryAlerts.first;
      expect(saved.scenarioType, 'Live Microphone Shield');
      expect(saved.riskScore, greaterThanOrEqualTo(85));
      expect(saved.familyContactId, isNotEmpty);

      await controller.stopListening();
    });
  });
}
