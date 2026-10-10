import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guard_call/core/services/auth_service.dart';
import 'package:guard_call/core/services/auth_state.dart';
import 'package:guard_call/core/services/family_relationship_service.dart';
import 'package:guard_call/features/family/family_screen.dart';
import 'package:guard_call/features/history/call_history_repository.dart';
import 'package:guard_call/features/home/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setTestPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FamilyRelationshipService.instance.resetForTesting();
    CallHistoryRepository.instance.resetForTesting();
    AuthState.instance.setMockUser(
      user: const AuthUser(
        id: 'demo-user-offline',
        email: 'demo@guardcall.local',
        name: 'Demo User',
      ),
      status: AuthStatus.offlineDemo,
    );
  });

  group('GUARDCall — Step 3: Caregiver Invitation Acceptance Tests', () {
    // -------------------------------------------------------------------------
    // 1. Valid pending invitation acceptance
    // -------------------------------------------------------------------------
    test('1. Valid pending invitation acceptance creates and returns relationship', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'sarah.jenkins@example.com',
        relationship: 'Daughter',
        displayName: 'Sarah Jenkins',
      );

      expect(inv.status, 'pending');

      final rel = await FamilyRelationshipService.instance.acceptInvitation(
        inv.id,
        caregiverUserId: 'caregiver-sarah-101',
        caregiverEmail: 'sarah.jenkins@example.com',
        caregiverDisplayName: 'Sarah Jenkins',
      );

      expect(rel.id, isNotEmpty);
      expect(rel.ownerUserId, inv.ownerUserId);
      expect(rel.caregiverUserId, 'caregiver-sarah-101');
      expect(rel.relationship, 'Daughter');
      expect(rel.displayName, 'Sarah Jenkins');
      expect(rel.enabled, isTrue);
    });

    // -------------------------------------------------------------------------
    // 2. Invitation status changes correctly
    // -------------------------------------------------------------------------
    test('2. Invitation status transitions to accepted upon acceptance', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'michael.vance@example.com',
        relationship: 'Son',
        displayName: 'Michael Vance',
      );

      expect(inv.status, 'pending');

      await FamilyRelationshipService.instance.acceptInvitation(
        inv.id,
        caregiverUserId: 'caregiver-michael-202',
        caregiverEmail: 'michael.vance@example.com',
      );

      final myInvs = await FamilyRelationshipService.instance.getMyInvitations();
      final updatedInv = myInvs.firstWhere((i) => i.id == inv.id);
      expect(updatedInv.status, 'accepted');
    });

    // -------------------------------------------------------------------------
    // 3. Active relationship is created or activated correctly
    // -------------------------------------------------------------------------
    test('3. Active relationship is created and accessible by owner and caregiver', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'dr.smith@example.com',
        relationship: 'Guardian',
        displayName: 'Dr. Smith',
      );

      final createdRel = await FamilyRelationshipService.instance.acceptInvitation(
        inv.id,
        caregiverUserId: 'caregiver-drsmith-303',
        caregiverEmail: 'dr.smith@example.com',
      );

      // Verify owner can view it
      final ownerRels = await FamilyRelationshipService.instance.getMyRelationships();
      expect(ownerRels.any((r) => r.id == createdRel.id && r.enabled), isTrue);

      // Verify caregiver can view it
      final caregiverRels = await FamilyRelationshipService.instance.getCaregiverRelationships(
        caregiverUserId: 'caregiver-drsmith-303',
      );
      expect(caregiverRels.any((r) => r.id == createdRel.id && r.enabled), isTrue);
    });

    // -------------------------------------------------------------------------
    // 4. Already accepted invitation is rejected safely
    // -------------------------------------------------------------------------
    test('4. Already accepted invitation cannot be accepted again', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'caregiver.repeat@example.com',
        relationship: 'Sister',
      );

      await FamilyRelationshipService.instance.acceptInvitation(
        inv.id,
        caregiverUserId: 'caregiver-repeat-404',
        caregiverEmail: 'caregiver.repeat@example.com',
      );

      // Second acceptance must fail with StateError
      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          inv.id,
          caregiverUserId: 'caregiver-repeat-404',
          caregiverEmail: 'caregiver.repeat@example.com',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already been accepted'),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 5. Revoked invitation cannot be accepted
    // -------------------------------------------------------------------------
    test('5. Revoked invitation cannot be accepted', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'revoked.caregiver@example.com',
        relationship: 'Neighbor',
      );

      await FamilyRelationshipService.instance.revokeInvitation(inv.id);

      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          inv.id,
          caregiverUserId: 'caregiver-revoked-505',
          caregiverEmail: 'revoked.caregiver@example.com',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('revoked'),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 6. Unknown invitation is rejected
    // -------------------------------------------------------------------------
    test('6. Non-existent invitation ID is rejected with clear error', () async {
      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          'non-existent-invitation-uuid-999',
          caregiverUserId: 'any-user-id',
          caregiverEmail: 'any.email@example.com',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('Invitation not found'),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 7. Unauthorized user cannot accept another user's invitation
    // -------------------------------------------------------------------------
    test('7. Unauthorized user cannot accept an invitation intended for another email', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'legitimate.caregiver@example.com',
        relationship: 'Daughter',
      );

      // Attempted acceptance by unauthorized user with different email
      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          inv.id,
          caregiverUserId: 'unauthorized-intruder-id',
          caregiverEmail: 'intruder@attack.com',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('Unauthorized'),
          ),
        ),
      );

      // Verify status remains pending
      final invs = await FamilyRelationshipService.instance.getMyInvitations();
      expect(invs.firstWhere((i) => i.id == inv.id).status, 'pending');
    });

    // -------------------------------------------------------------------------
    // 8. Self-acceptance is rejected
    // -------------------------------------------------------------------------
    test('8. Self-acceptance is rejected when owner attempts to accept own invitation', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        ownerUserId: 'owner-account-777',
        invitedEmail: 'owner@self.com',
        relationship: 'Self',
      );

      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          inv.id,
          caregiverUserId: 'owner-account-777',
          caregiverEmail: 'owner@self.com',
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

    // -------------------------------------------------------------------------
    // 9. Duplicate active relationship is prevented
    // -------------------------------------------------------------------------
    test('9. Duplicate active relationship between same owner and caregiver is prevented', () async {
      final inv1 = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'duplicate.test@example.com',
        relationship: 'Son',
      );

      await FamilyRelationshipService.instance.acceptInvitation(
        inv1.id,
        caregiverUserId: 'caregiver-duplicate-888',
        caregiverEmail: 'duplicate.test@example.com',
      );

      // Create a second invitation for the same user
      final inv2 = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'duplicate.test@example.com',
        relationship: 'Son (Second Invite)',
      );

      // Attempting to accept a second active relationship between same parties must fail
      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          inv2.id,
          caregiverUserId: 'caregiver-duplicate-888',
          caregiverEmail: 'duplicate.test@example.com',
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

    // -------------------------------------------------------------------------
    // 10. Persistence survives service or application reinitialization
    // -------------------------------------------------------------------------
    test('10. Accepted invitation and established relationship survive reload', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'persisted.caregiver@example.com',
        relationship: 'Primary Caregiver',
        displayName: 'Persisted Nurse',
      );

      final acceptedRel = await FamilyRelationshipService.instance.acceptInvitation(
        inv.id,
        caregiverUserId: 'caregiver-persisted-999',
        caregiverEmail: 'persisted.caregiver@example.com',
      );

      expect(acceptedRel.enabled, isTrue);

      // Simulate application restart
      FamilyRelationshipService.instance.resetForTesting();
      // Before loading, only seed demo relationship is present
      final beforeLoad = await FamilyRelationshipService.instance.getMyRelationships();
      expect(beforeLoad.any((r) => r.id == acceptedRel.id), isFalse);

      // Load from local storage
      await FamilyRelationshipService.instance.loadFromStorage();
      final afterLoadRels = await FamilyRelationshipService.instance.getMyRelationships();
      final afterLoadInvs = await FamilyRelationshipService.instance.getMyInvitations();

      expect(afterLoadRels.any((r) => r.caregiverUserId == 'caregiver-persisted-999'), isTrue);
      expect(
        afterLoadInvs.any(
          (i) => i.id == inv.id && i.status == 'accepted',
        ),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // Extra: Expired invitation rejection
    // -------------------------------------------------------------------------
    test('Extra: Expired invitation transitions to expired and is rejected', () async {
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'expired.caregiver@example.com',
        relationship: 'Nurse',
        expiresAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(
        () => FamilyRelationshipService.instance.acceptInvitation(
          inv.id,
          caregiverUserId: 'caregiver-expired-000',
          caregiverEmail: 'expired.caregiver@example.com',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('expired'),
          ),
        ),
      );

      final updatedInvs = await FamilyRelationshipService.instance.getMyInvitations();
      expect(updatedInvs.firstWhere((i) => i.id == inv.id).status, 'expired');
    });

    // -------------------------------------------------------------------------
    // 11. FamilyScreen displays and handles the Accept action
    // -------------------------------------------------------------------------
    testWidgets('11. FamilyScreen Caregiver View displays and accepts pending invitation', (tester) async {
      setTestPhoneSize(tester);

      // Create an invitation from senior owner for this caregiver
      final inv = await FamilyRelationshipService.instance.createInvitation(
        ownerUserId: 'senior-owner-456',
        invitedEmail: 'sarah.caregiver@example.com',
        relationship: 'Daughter',
        displayName: 'Eleanor Vance (Mother)',
      );

      // Authenticate as caregiver
      AuthState.instance.setMockUser(
        user: const AuthUser(
          id: 'caregiver-ui-test-id',
          email: 'sarah.caregiver@example.com',
          name: 'Sarah Caregiver',
        ),
        status: AuthStatus.offlineDemo,
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

      // Verify incoming invitation section and pending invitation card
      expect(find.text('Incoming Invitations'), findsOneWidget);
      expect(find.text('Eleanor Vance (Mother)'), findsOneWidget);
      expect(find.text('PENDING'), findsWidgets);
      expect(find.byKey(Key('accept_invitation_${inv.id}')), findsOneWidget);

      // Tap Accept Invitation
      await tester.tap(find.byKey(Key('accept_invitation_${inv.id}')));
      await tester.pumpAndSettle();

      // Verify success feedback
      expect(find.textContaining('Invitation accepted!'), findsOneWidget);

      // Verify invitation is no longer pending
      expect(find.text('No pending caregiver invitations for your account.'), findsOneWidget);

      // Verify active protected member card is visible with LINKED badge
      expect(find.text('LINKED'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // 12. Home dashboard reflects the accepted relationship
    // -------------------------------------------------------------------------
    testWidgets('12. Home dashboard dynamically reacts to accepted caregiver invitation', (tester) async {
      setTestPhoneSize(tester);

      // Start with empty relationships to isolate test
      FamilyRelationshipService.instance.clearForTesting();

      // Create a pending invitation
      final inv = await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'sarah.home@example.com',
        relationship: 'Daughter',
        displayName: 'Sarah Home',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Home card should display pending invitation status
      expect(find.text('Invitation Pending • Awaiting Acceptance'), findsOneWidget);
      expect(find.text('Sarah Home (Daughter)'), findsOneWidget);

      // Now accept the invitation as the caregiver
      await FamilyRelationshipService.instance.acceptInvitation(
        inv.id,
        caregiverUserId: 'caregiver-home-id',
        caregiverEmail: 'sarah.home@example.com',
      );

      // Allow reactive stream event to trigger UI reload
      await tester.pumpAndSettle();

      // Home card now reflects active relationship
      expect(find.text('Connected • Receives Critical Alerts'), findsOneWidget);
      expect(find.text('Sarah Home (Daughter)'), findsOneWidget);
    });
  });
}
