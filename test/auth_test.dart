import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/app/app.dart';
import 'package:guard_call/core/services/auth_service.dart';
import 'package:guard_call/core/services/auth_state.dart';
import 'package:guard_call/core/services/profile_service.dart';
import 'package:guard_call/features/auth/login_screen.dart';
import 'package:guard_call/features/auth/signup_screen.dart';
import 'package:guard_call/features/demo/demo_center_screen.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance.resetForTesting();
    ProfileService.instance.resetForTesting();
  });

  group('AuthService Offline/Demo Tests', () {
    test('Offline mode operates without network calls', () {
      expect(AuthService.instance.isConfigured, isFalse);
      expect(AuthService.instance.isOffline, isTrue);
    });

    test('Offline signUp creates simulated demo user', () async {
      final user = await AuthService.instance.signUp(
        email: 'tester@guardcall.local',
        password: 'password123',
        name: 'Tester Name',
      );

      expect(user.email, 'tester@guardcall.local');
      expect(user.name, 'Tester Name');
      expect(user.id.startsWith('demo-user-'), isTrue);
    });

    test('Offline signIn succeeds with valid input', () async {
      final session = await AuthService.instance.signIn(
        email: 'tester@guardcall.local',
        password: 'password123',
      );

      expect(session.accessToken, 'offline-demo-token');
      expect(session.user.email, 'tester@guardcall.local');
      expect(AuthService.instance.getCurrentUser(), isNotNull);
    });

    test('Offline signOut clears user and session', () async {
      await AuthService.instance.signIn(
        email: 'tester@guardcall.local',
        password: 'password123',
      );
      expect(AuthService.instance.getCurrentUser(), isNotNull);

      await AuthService.instance.signOut();
      expect(AuthService.instance.getCurrentUser(), isNull);
      expect(AuthService.instance.getCurrentSession(), isNull);
    });

    test('Invalid email triggers AuthException', () async {
      expect(
        () => AuthService.instance.signIn(
          email: 'not-an-email',
          password: 'password123',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.invalidEmail,
        )),
      );
    });

    test('Short password triggers AuthException on signUp', () async {
      expect(
        () => AuthService.instance.signUp(
          email: 'test@example.com',
          password: '123',
          name: 'Short Pass',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          AuthErrorCode.invalidPassword,
        )),
      );
    });
  });

  group('AuthState Transitions', () {
    test('Continue in demo mode sets offlineDemo status', () {
      final auth = AuthState.instance;
      auth.continueInDemoMode();

      expect(auth.status, AuthStatus.offlineDemo);
      expect(auth.isOfflineDemo, isTrue);
      expect(auth.displayName, 'Demo User');
    });

    test('Sign in offline updates auth state', () async {
      final auth = AuthState.instance;
      final success = await auth.signIn(
        email: 'offline@demo.com',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(auth.isOfflineDemo, isTrue);
      expect(auth.currentUser?.email, 'offline@demo.com');
    });

    test('Sign out resets state', () async {
      final auth = AuthState.instance;
      await auth.signIn(
        email: 'offline@demo.com',
        password: 'password123',
      );
      await auth.signOut();

      expect(auth.currentUser, isNull);
      expect(auth.isOfflineDemo, isTrue); // in offline config, stays demo ready
    });
  });

  group('ProfileService Mapping Tests', () {
    test('Creates and retrieves offline profile', () async {
      final profile = await ProfileService.instance.createProfile(
        id: 'user-123',
        name: 'Jane Doe',
      );

      expect(profile.id, 'user-123');
      expect(profile.name, 'Jane Doe');

      final fetched = await ProfileService.instance.getProfile('user-123');
      expect(fetched?.name, 'Jane Doe');
    });

    test('Updates offline profile name', () async {
      await ProfileService.instance.createProfile(
        id: 'user-123',
        name: 'Jane Doe',
      );

      final updated = await ProfileService.instance.updateProfile(
        id: 'user-123',
        name: 'Jane Smith',
      );

      expect(updated.name, 'Jane Smith');
    });
  });

  group('LoginScreen Widget Tests', () {
    testWidgets('Displays branding, inputs, and demo button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('GuardCall'), findsOneWidget);
      expect(
        find.textContaining('protect you from phone scams'),
        findsOneWidget,
      );
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Continue in Demo Mode'), findsOneWidget);
    });

    testWidgets('Validates empty email and password', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Tap Sign In without filling fields
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email address is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('Validates invalid email pattern', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'invalid-email',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });
  });

  group('SignUpScreen Widget Tests', () {
    testWidgets('Validates all required fields on submit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Full name is required.'), findsOneWidget);
      expect(find.text('Email address is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('Validates password confirmation mismatch', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name'),
        'Alex Caregiver',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'alex@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password (min. 6 characters)'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'different_password',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });
  });

  group('Demo Center Accessibility Without Authentication', () {
    testWidgets('GuardCallApp launches directly into Demo Center in offline mode', (tester) async {
      AuthState.instance.continueInDemoMode();

      await tester.pumpWidget(const GuardCallApp());
      await tester.pumpAndSettle();

      // Home Screen is active with Start Demo Call button
      expect(find.text('Start Demo Call'), findsOneWidget);

      // Tap Start Demo Call button
      await tester.tap(find.text('Start Demo Call'));
      await tester.pumpAndSettle();

      // Verify Demo Center Screen is reached without login gate
      expect(find.byType(DemoCenterScreen), findsOneWidget);
      expect(find.text('Fake KYC Update'), findsOneWidget);
      expect(find.text('Digital Arrest Threat'), findsOneWidget);
    });
  });
}
