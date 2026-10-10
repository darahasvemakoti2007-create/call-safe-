import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/core/config/app_config.dart';
import 'package:guard_call/core/logging/app_logger.dart';
import 'package:guard_call/core/services/accessibility_preferences.dart';
import 'package:guard_call/core/services/notification_preferences.dart';
import 'package:guard_call/core/services/notification_service.dart';
import 'package:guard_call/core/services/simulated_notification_service.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/alerts/scam_warning_dialog.dart';
import 'package:guard_call/features/alerts/simulated_family_alert.dart';
import 'package:guard_call/features/demo/demo_center_screen.dart';
import 'package:guard_call/features/detection/risk_analysis.dart';
import 'package:guard_call/features/detection/scam_signal.dart';
import 'package:guard_call/features/family/family_screen.dart';
import 'package:guard_call/features/home/home_screen.dart';
import 'package:guard_call/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 18 — Accessibility & UX Safety Hardening Tests', () {
    setUp(() {
      AccessibilityPreferences.instance.setReduceMotion(false);
      NotificationPreferences.instance.setFamilyAlertsEnabled(true);
    });

    test('1. Reduce Motion preference can be enabled and disabled reactively', () {
      final prefs = AccessibilityPreferences.instance;
      expect(prefs.reduceMotion, isFalse);

      bool notified = false;
      prefs.addListener(() => notified = true);

      prefs.setReduceMotion(true);
      expect(prefs.reduceMotion, isTrue);
      expect(notified, isTrue);

      prefs.setReduceMotion(false);
      expect(prefs.reduceMotion, isFalse);
    });

    test('2. Family Alerts setting can be disabled and re-enabled', () {
      final notifPrefs = NotificationPreferences.instance;
      expect(notifPrefs.familyAlertsEnabled, isTrue);

      notifPrefs.setFamilyAlertsEnabled(false);
      expect(notifPrefs.familyAlertsEnabled, isFalse);

      notifPrefs.setFamilyAlertsEnabled(true);
      expect(notifPrefs.familyAlertsEnabled, isTrue);
    });

    testWidgets('3. ScamWarningDialog exposes explicit elderly-safe actions without auto-alerting',
        (tester) async {
      bool endCallTapped = false;
      bool imSafeTapped = false;
      bool alertFamilyTapped = false;

      final analysis = RiskAnalysis(
        riskScore: 75,
        riskLevel: RiskLevel.high,
        detectedSignals: [
          ScamSignal(
            type: ScamSignalType.authorityImpersonation,
            title: 'Authority Impersonation',
            explanation: 'Caller falsely claimed to be bank fraud department.',
          ),
        ],
        explanations: const ['Pressure to share KYC details'],
        confidence: 0.95,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScamWarningDialog(
              analysis: analysis,
              onEndCall: () => endCallTapped = true,
              onImSafe: () => imSafeTapped = true,
              onAlertFamily: () => alertFamilyTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify clear actions exist
      expect(find.text('End Call'), findsOneWidget);
      expect(find.text("I'm Safe"), findsOneWidget);
      expect(find.text('Alert Family'), findsOneWidget);

      // Verify actions respond to user tap
      await tester.tap(find.text('End Call'));
      expect(endCallTapped, isTrue);

      await tester.tap(find.text("I'm Safe"));
      expect(imSafeTapped, isTrue);

      await tester.tap(find.text('Alert Family'));
      expect(alertFamilyTapped, isTrue);
    });

    testWidgets('4. Risk level communicates state through text and semantics, not color alone',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RiskBadge(level: RiskLevel.safe, score: 15),
                RiskBadge(level: RiskLevel.suspicious, score: 55),
                RiskBadge(level: RiskLevel.high, score: 75),
                RiskBadge(level: RiskLevel.critical, score: 92),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Text labels and scores must be clearly present
      expect(find.text('Safe (15)'), findsOneWidget);
      expect(find.text('Suspicious (55)'), findsOneWidget);
      expect(find.text('High Risk (75)'), findsOneWidget);
      expect(find.text('Critical Threat (92)'), findsOneWidget);
    });

    testWidgets('5. Simulated notification dialog clearly identifies prototype simulation',
        (tester) async {
      final analysis = RiskAnalysis(
        riskScore: 75,
        riskLevel: RiskLevel.high,
        detectedSignals: const [],
        explanations: const [],
        confidence: 0.9,
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimulatedFamilyAlert(
              scenarioTitle: 'Fake KYC Verification Scam',
              analysis: analysis,
              onClose: () {},
              caregiverName: 'Sarah Jenkins (Daughter)',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SIMULATED FAMILY ALERT'), findsOneWidget);
      expect(find.text('SIMULATED FAMILY NOTIFICATION'), findsOneWidget);
      expect(find.text('Demo only — no message was actually sent.'), findsOneWidget);
      // Harmonized dynamic risk level label
      expect(
        find.text('Sarah Jenkins (Daughter) would receive a high risk GuardCall alert.'),
        findsOneWidget,
      );
    });

    testWidgets('6a. HomeScreen renders cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();
      expect(find.text('GuardCall'), findsOneWidget);
    });

    testWidgets('6b. DemoCenterScreen renders cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: DemoCenterScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Demo Center'), findsWidgets);
    });

    testWidgets('6c. FamilyScreen renders cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: FamilyScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Family Circle'), findsOneWidget);
    });

    testWidgets('6d. SettingsScreen renders cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group('Step 18 — Privacy & Security Hardening Tests', () {
    test('7. AppLogger sanitizes sensitive credentials and secrets automatically', () {
      expect(
        AppLogger.sanitize('Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc'),
        contains('[REDACTED]'),
      );
      expect(
        AppLogger.sanitize('apiKey=sk-1234567890abcdef'),
        contains('[REDACTED_SECRET]'),
      );
      expect(
        AppLogger.sanitize('password=superSecret123'),
        contains('[REDACTED_SECRET]'),
      );
      expect(
        AppLogger.sanitize('otp: 482913'),
        contains('[REDACTED_CREDENTIAL]'),
      );
      expect(
        AppLogger.sanitize('cvv=123'),
        contains('[REDACTED_CREDENTIAL]'),
      );
    });

    test('8. NotificationRequest strictly enforces zero audio and zero transcript payload boundary', () {
      final validRequest = NotificationRequest(
        alertId: 'alert-001',
        caregiverId: 'caregiver-001',
        caregiverDisplayName: 'Sarah Jenkins',
        seniorDisplayName: 'Robert Jenkins',
        riskScore: 75,
        riskLevel: 'high',
        scenarioType: 'Fake KYC Scam',
        detectedSignals: const ['Authority Impersonation', 'Urgency'],
        explanation: 'Caller demanded bank OTP verification urgently.',
        interventionStatus: 'User requested Family Alert',
        timestamp: DateTime.now(),
      );

      final map = validRequest.toMap();
      expect(map.containsKey('audio'), isFalse);
      expect(map.containsKey('raw_audio'), isFalse);
      expect(map.containsKey('audio_bytes'), isFalse);
      expect(map.containsKey('transcript'), isFalse);
      expect(map.containsKey('full_transcript'), isFalse);
      expect(map.containsKey('otp'), isFalse);
      expect(map.containsKey('pin'), isFalse);
      expect(map.containsKey('cvv'), isFalse);
      expect(map.containsKey('password'), isFalse);
      expect(map.containsKey('service_role'), isFalse);
      expect(validRequest.isPrivacyCompliant, isTrue);
    });

    test('9. AppConfig never exposes service_role key and defaults safely to offline demo mode', () {
      final config = AppConfig.offlineDefault();
      expect(config.isOfflineDemoMode, isTrue);
      expect(config.useSupabase, isFalse);
      expect(config.useRemoteAi, isFalse);
      expect(config.useCloudStt, isFalse);
      expect(config.aiBackend, 'mock');
      expect(config.sttBackend, 'mock');
      expect(config.isSupabaseConfigured, isFalse);
      expect(config.supabaseAnonKey, isNot(contains('service_role')));
    });

    test('10. Disabled family alerts block notification requests and return UNAVAILABLE status', () async {
      NotificationPreferences.instance.setFamilyAlertsEnabled(false);
      final service = SimulatedNotificationService();

      final request = NotificationRequest(
        alertId: 'alert-block-test',
        caregiverId: 'cg-1',
        caregiverDisplayName: 'Sarah',
        seniorDisplayName: 'Robert',
        riskScore: 75,
        riskLevel: 'high',
        scenarioType: 'Test Scam',
        detectedSignals: const ['Urgency'],
        explanation: 'Test explanation',
        interventionStatus: 'User requested Family Alert',
        timestamp: DateTime.now(),
      );

      final result = await service.sendFamilyAlert(request);
      expect(result.status, NotificationStatus.unavailable);
      expect(result.status.isSimulated, isFalse);
      expect(result.status.label, 'UNAVAILABLE');
      expect(result.message, contains('disabled in Settings'));

      NotificationPreferences.instance.setFamilyAlertsEnabled(true);
    });

    test('11. Simulated notifications strictly report SIMULATED, never SENT or DELIVERED', () async {
      NotificationPreferences.instance.setFamilyAlertsEnabled(true);
      final service = SimulatedNotificationService();

      final request = NotificationRequest(
        alertId: 'alert-sim-test',
        caregiverId: 'cg-2',
        caregiverDisplayName: 'Sarah Jenkins',
        seniorDisplayName: 'Robert Jenkins',
        riskScore: 75,
        riskLevel: 'high',
        scenarioType: 'Fake KYC Scam',
        detectedSignals: const ['Authority Impersonation'],
        explanation: 'Test',
        interventionStatus: 'Family alert requested',
        timestamp: DateTime.now(),
      );

      final result = await service.sendFamilyAlert(request);
      expect(result.status, NotificationStatus.simulated);
      expect(result.status.isSimulated, isTrue);
      expect(result.status.label, 'SIMULATED');
      expect(result.status, isNot(NotificationStatus.sent));
      expect(result.status, isNot(NotificationStatus.delivered));
    });

    test('12. Risk thresholds and score labels agree at 75 (High threat tier)', () {
      final level75 = RiskLevelScore.fromScore(75);
      expect(level75, RiskLevel.high);
      expect(level75.label, 'High Risk');

      final level85 = RiskLevelScore.fromScore(85);
      expect(level85, RiskLevel.critical);
      expect(level85.label, 'Critical Threat');

      final level50 = RiskLevelScore.fromScore(50);
      expect(level50, RiskLevel.suspicious);
      expect(level50.label, 'Suspicious');

      final level20 = RiskLevelScore.fromScore(20);
      expect(level20, RiskLevel.safe);
      expect(level20.label, 'Safe');
    });
  });
}
