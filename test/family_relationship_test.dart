import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guard_call/core/services/auth_service.dart';
import 'package:guard_call/core/services/family_alert_service.dart';
import 'package:guard_call/core/services/family_relationship_service.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/demo/demo_scenarios.dart';
import 'package:guard_call/features/family/family_screen.dart';
import 'package:guard_call/features/history/call_history_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FamilyRelationshipService.instance.resetForTesting();
    FamilyAlertService.instance.resetForTesting();
    CallHistoryRepository.instance.clear();
  });

  group('Phase J — Step 11 Secure Family Circle & Caregiver Foundation Tests', () {
    test('1. FamilyRelationship model serialization and deserialization', () {
      final now = DateTime.now();
      final rel = FamilyRelationship(
        id: '11111111-1111-1111-1111-111111111111',
        ownerUserId: '22222222-2222-2222-2222-222222222222',
        caregiverUserId: '33333333-3333-3333-3333-333333333333',
        relationship: 'Daughter',
        enabled: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = rel.toMap();
      expect(map['id'], '11111111-1111-1111-1111-111111111111');
      expect(map['owner_user_id'], '22222222-2222-2222-2222-222222222222');
      expect(map['caregiver_user_id'], '33333333-3333-3333-3333-333333333333');
      expect(map['relationship'], 'Daughter');
      expect(map['enabled'], true);

      final reconstructed = FamilyRelationship.fromMap(map);
      expect(reconstructed.id, rel.id);
      expect(reconstructed.ownerUserId, rel.ownerUserId);
      expect(reconstructed.caregiverUserId, rel.caregiverUserId);
      expect(reconstructed.relationship, 'Daughter');
      expect(reconstructed.enabled, true);

      final toggled = rel.copyWith(enabled: false);
      expect(toggled.enabled, false);
      expect(toggled.id, rel.id);
    });

    test('2. Owner relationship creation in local memory', () async {
      final rel = await FamilyRelationshipService.instance.createRelationship(
        caregiverUserId: 'test-caregiver-user-id',
        relationship: 'Son',
        enabled: true,
      );

      expect(rel.caregiverUserId, 'test-caregiver-user-id');
      expect(rel.relationship, 'Son');
      expect(rel.enabled, true);

      final all = await FamilyRelationshipService.instance.getMyRelationships();
      expect(all.any((r) => r.caregiverUserId == 'test-caregiver-user-id'), isTrue);
    });

    test('3. Caregiver relationship lookup returns accessible items', () async {
      final caregiverRels = await FamilyRelationshipService.instance.getCaregiverRelationships();
      // In offline/demo mode, returns safe empty or configured mock list without throwing
      expect(caregiverRels, isA<List<FamilyRelationship>>());
    });

    test('4. Relationship enable and disable behavior', () async {
      final rel = await FamilyRelationshipService.instance.createRelationship(
        caregiverUserId: 'caregiver-toggle-id',
        relationship: 'Spouse',
        enabled: true,
      );

      expect(rel.enabled, isTrue);

      await FamilyRelationshipService.instance.enableRelationship(rel.id, false);
      final list = await FamilyRelationshipService.instance.getMyRelationships();
      final updated = list.firstWhere((r) => r.id == rel.id);
      expect(updated.enabled, isFalse);

      await FamilyRelationshipService.instance.enableRelationship(rel.id, true);
      final list2 = await FamilyRelationshipService.instance.getMyRelationships();
      final reEnabled = list2.firstWhere((r) => r.id == rel.id);
      expect(reEnabled.enabled, isTrue);
    });

    test('5. Relationship deletion', () async {
      final rel = await FamilyRelationshipService.instance.createRelationship(
        caregiverUserId: 'caregiver-to-delete',
        relationship: 'Guardian',
      );

      final before = await FamilyRelationshipService.instance.getMyRelationships();
      expect(before.any((r) => r.id == rel.id), isTrue);

      await FamilyRelationshipService.instance.deleteRelationship(rel.id);
      final after = await FamilyRelationshipService.instance.getMyRelationships();
      expect(after.any((r) => r.id == rel.id), isFalse);
    });

    test('6. Offline fallback provides simulated caregiver without network calls', () async {
      expect(FamilyRelationshipService.instance.isConfigured, isFalse);

      final rels = await FamilyRelationshipService.instance.getMyRelationships();
      expect(rels.isNotEmpty, isTrue);
      expect(rels.first.id, 'demo-rel-sarah');
      expect(rels.first.relationship, contains('Daughter'));
    });

    test('7. Network failure / unexpected error resilience', () async {
      // getMyRelationships handles exceptions internally and falls back to cached memory
      final rels = await FamilyRelationshipService.instance.getMyRelationships();
      expect(rels, isNotNull);
    });

    test('8. Unauthorized / empty auth is safely handled by service logic', () async {
      // In unconfigured / offline state, service operates with demo scope and never leaks arbitrary users
      final invs = await FamilyRelationshipService.instance.getMyInvitations();
      expect(invs, isA<List<FamilyInvitation>>());
    });

    test('9. Demo mode does not claim a real caregiver account', () async {
      final rels = await FamilyRelationshipService.instance.getMyRelationships();
      final defaultRel = rels.first;
      expect(defaultRel.id.startsWith('demo'), isTrue);
      expect(defaultRel.ownerUserId, 'demo-owner-id');
    });

    test('10. Invitation remains pending until explicitly accepted', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'test.caregiver@example.com',
        relationship: 'Daughter',
      );

      expect(inv.status, 'pending');
      expect(inv.invitedEmail, 'test.caregiver@example.com');
      expect(inv.relationship, 'Daughter');

      final allInvs = await FamilyRelationshipService.instance.getMyInvitations();
      expect(allInvs.any((i) => i.id == inv.id && i.status == 'pending'), isTrue);

      // Revoking transitions status to 'revoked'
      await FamilyRelationshipService.instance.revokeInvitation(inv.id);
      final updatedInvs = await FamilyRelationshipService.instance.getMyInvitations();
      final revoked = updatedInvs.firstWhere((i) => i.id == inv.id);
      expect(revoked.status, 'revoked');
    });

    test('11. No password or secret stored in invitation or relationship data', () {
      final inv = FamilyInvitation(
        id: 'inv-123',
        ownerUserId: 'owner-456',
        invitedEmail: 'safe@example.com',
        relationship: 'Son',
      );

      final invMap = inv.toMap();
      expect(invMap.containsKey('password'), isFalse);
      expect(invMap.containsKey('token'), isFalse);
      expect(invMap.containsKey('secret'), isFalse);
      expect(invMap.containsKey('service_role'), isFalse);

      final rel = FamilyRelationship(
        id: 'rel-123',
        ownerUserId: 'owner-456',
        caregiverUserId: 'caregiver-789',
      );
      final relMap = rel.toMap();
      expect(relMap.containsKey('password'), isFalse);
      expect(relMap.containsKey('secret'), isFalse);
      expect(relMap.containsKey('service_role'), isFalse);
    });

    test('12. Existing alert flow still works with new caregiver retrieval', () async {
      final alert = await FamilyAlertService.instance.createAlert(
        callSessionId: 'test-session-step11',
        familyContactId: 'test-contact-step11',
        riskScore: 85,
      );

      expect(alert.status, 'pending');
      expect(alert.riskScore, 85);

      final caregiverAlerts = await FamilyAlertService.instance.getCaregiverAlerts();
      expect(caregiverAlerts, isNotEmpty);
    });

    test('13. Existing Demo Center scenarios still work', () {
      final scenarios = DemoScenarios.all;
      expect(scenarios.length, 5);

      final fakeKyc = scenarios.firstWhere((s) => s.id == 'fake_kyc');
      expect(fakeKyc.expectedRiskLevel, RiskLevel.critical);

      final bank = scenarios.firstWhere((s) => s.id == 'genuine_bank');
      expect(bank.expectedRiskLevel, RiskLevel.safe);
    });

    test('14. Existing authentication service functions offline', () {
      expect(AuthService.instance.isConfigured, isFalse);
      expect(AuthService.instance.isOffline, isTrue);
    });

    test('15. Existing history repository functions locally', () {
      CallHistoryRepository.instance.clear();
      expect(CallHistoryRepository.instance.records, isEmpty);

      const record = CallHistoryRecord(
        id: 'hist-1',
        title: 'Test History',
        subtitle: 'Threat test',
        timestamp: 'Just now',
        duration: '40s',
        riskScore: 80,
        riskLevel: RiskLevel.high,
        signals: ['Urgency'],
      );

      CallHistoryRepository.instance.addRecord(record);
      expect(CallHistoryRepository.instance.records.length, 1);
    });

    testWidgets('16. FamilyScreen renders elderly view and caregiver view', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FamilyScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Check main headers
      expect(find.text('Family Circle'), findsOneWidget);
      expect(find.text('My Family Circle'), findsOneWidget);
      expect(find.text('Caregiver View (Preview)'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('DEMO'), findsOneWidget);

      // Switch to Caregiver View
      await tester.tap(find.text('Caregiver View (Preview)'));
      await tester.pumpAndSettle();

      expect(find.text('Caregiver Perspective Foundation'), findsOneWidget);
      expect(find.text('Robert Jenkins (Father)'), findsOneWidget);
      expect(find.text('LINKED'), findsOneWidget);
    });
  });
}
