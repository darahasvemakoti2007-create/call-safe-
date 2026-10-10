import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guard_call/core/services/auth_service.dart';
import 'package:guard_call/core/services/auth_state.dart';
import 'package:guard_call/core/services/profile_service.dart';
import 'package:guard_call/core/services/family_contact_service.dart';
import 'package:guard_call/core/services/family_relationship_service.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/history/call_history_repository.dart';
import 'package:guard_call/features/home/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FamilyRelationshipService.instance.resetForTesting();
    FamilyContactService.instance.resetForTesting();
    CallHistoryRepository.instance.clear();
    AuthState.instance.continueInDemoMode();
  });

  group('Home Dashboard Data Binding Tests — Step 2', () {
    // -------------------------------------------------------------------------
    // 1. GREETING BINDING TESTS
    // -------------------------------------------------------------------------
    testWidgets('1a. Displays personalized greeting with user display name', (tester) async {
      AuthState.instance.setMockUser(
        user: const AuthUser(id: 'test-1', email: 'robert@test.com', name: 'Robert Jenkins'),
        profile: const UserProfile(id: 'test-1', name: 'Robert Jenkins'),
        status: AuthStatus.authenticated,
      );

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back, Robert Jenkins'), findsOneWidget);
    });

    testWidgets('1b. Displays default demo greeting in demo mode', (tester) async {
      AuthState.instance.continueInDemoMode();

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back, Demo User'), findsOneWidget);
    });

    testWidgets('1c. Displays friendly generic greeting when display name is empty or whitespace', (tester) async {
      AuthState.instance.setMockUser(
        user: const AuthUser(id: 'test-empty', email: 'anon@test.com', name: '   '),
        profile: const UserProfile(id: 'test-empty', name: '   '),
        status: AuthStatus.authenticated,
      );

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('1d. Displays friendly generic greeting when user is guest', (tester) async {
      AuthState.instance.setMockUser(
        user: null,
        profile: null,
        status: AuthStatus.unauthenticated,
      );

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. FAMILY CIRCLE CARD TESTS
    // -------------------------------------------------------------------------
    testWidgets('2a. Displays real active relationship when configured', (tester) async {
      FamilyRelationshipService.instance.resetForTesting();

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Sarah Jenkins (Daughter (Primary Caregiver))'), findsOneWidget);
      expect(find.text('Connected • Receives Critical Alerts'), findsOneWidget);
    });

    testWidgets('2b. Displays pending invitation when no active relationships exist', (tester) async {
      FamilyRelationshipService.instance.clearForTesting();
      FamilyContactService.instance.clearForTesting();

      await FamilyRelationshipService.instance.createInvitation(
        invitedEmail: 'michael@jenkins.org',
        relationship: 'Son',
        displayName: 'Michael Jenkins',
      );

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Michael Jenkins (Son)'), findsOneWidget);
      expect(find.text('Invitation Pending • Awaiting Acceptance'), findsOneWidget);
    });

    testWidgets('2c. Displays fallback family contact when no relationship exists', (tester) async {
      FamilyRelationshipService.instance.clearForTesting();
      FamilyContactService.instance.clearForTesting();

      await FamilyContactService.instance.addFamilyContact(
        name: 'Emily Davis',
        relationship: 'Granddaughter',
        contactIdentifier: '+1 555-987-6543',
      );

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Emily Davis (Granddaughter)'), findsOneWidget);
      expect(find.text('Connected • Receives Critical Alerts'), findsOneWidget);
    });

    testWidgets('2d. Displays clean empty state when no contacts, relationships, or invitations exist', (tester) async {
      FamilyRelationshipService.instance.clearForTesting();
      FamilyContactService.instance.clearForTesting();

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No Caregiver Connected'), findsOneWidget);
      expect(find.text('Tap to add a trusted emergency contact'), findsOneWidget);
    });

    testWidgets('2e. Tapping Family Circle card triggers navigation callback', (tester) async {
      bool familyNavigated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            onNavigateToFamily: () => familyNavigated = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sarah Jenkins (Daughter (Primary Caregiver))'));
      await tester.pumpAndSettle();

      expect(familyNavigated, isTrue);
    });

    // -------------------------------------------------------------------------
    // 3. RECENT ACTIVITY CARD TESTS
    // -------------------------------------------------------------------------
    testWidgets('3a. Displays clean empty recent activity card when history is empty', (tester) async {
      CallHistoryRepository.instance.clear();

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No Call Activity Logged'), findsOneWidget);
      expect(find.text('Completed call assessments will appear here.'), findsOneWidget);
    });

    testWidgets('3b. Displays latest actual call assessment when records exist', (tester) async {
      CallHistoryRepository.instance.clear();
      CallHistoryRepository.instance.addRecord(
        const CallHistoryRecord(
          id: 'test_call_1',
          title: 'Suspicious Bank Verification',
          subtitle: 'Caller pressured for confidential account PIN.',
          timestamp: '10 mins ago',
          duration: '1m 20s',
          riskScore: 84,
          riskLevel: RiskLevel.critical,
          signals: ['Urgency', 'Sensitive Information Request'],
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Suspicious Bank Verification'), findsOneWidget);
      expect(find.text('Caller pressured for confidential account PIN.'), findsOneWidget);
      expect(find.text('10 mins ago'), findsOneWidget);
      expect(find.text('Critical Threat (84)'), findsOneWidget);
    });

    testWidgets('3c. Reactively updates recent activity when a new assessment is recorded', (tester) async {
      CallHistoryRepository.instance.clear();

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No Call Activity Logged'), findsOneWidget);

      // Simulate a completed call evaluation adding a record dynamically
      CallHistoryRepository.instance.addRecord(
        const CallHistoryRecord(
          id: 'new_dyn_call',
          title: 'Fake Customs Clearance Scam',
          subtitle: 'Demanded instant payment to release international parcel.',
          timestamp: 'Just now',
          duration: '0m 45s',
          riskScore: 76,
          riskLevel: RiskLevel.high,
          signals: ['Financial Demand', 'Urgency'],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fake Customs Clearance Scam'), findsOneWidget);
      expect(find.text('Demanded instant payment to release international parcel.'), findsOneWidget);
      expect(find.text('High Risk (76)'), findsOneWidget);
    });

    testWidgets('3d. Tapping Recent Activity card triggers navigation callback', (tester) async {
      bool historyNavigated = false;

      CallHistoryRepository.instance.clear();
      CallHistoryRepository.instance.addRecord(
        const CallHistoryRecord(
          id: 'test_call_2',
          title: 'Legitimate Hospital Call',
          subtitle: 'Routine appointment reminder.',
          timestamp: 'Yesterday',
          duration: '0m 30s',
          riskScore: 10,
          riskLevel: RiskLevel.safe,
          signals: [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            onNavigateToHistory: () => historyNavigated = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final target = find.text('Legitimate Hospital Call');
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(historyNavigated, isTrue);
    });
  });
}
