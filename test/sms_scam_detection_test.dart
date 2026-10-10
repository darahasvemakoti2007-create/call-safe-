import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guard_call/app/app_theme.dart';
import 'package:guard_call/core/services/family_alert_service.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/calls/calls_screen.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/scam_signal.dart';
import 'package:guard_call/features/history/call_history_repository.dart';
import 'package:guard_call/features/home/home_screen.dart';
import 'package:guard_call/features/sms/sms_protection_controller.dart';
import 'package:guard_call/features/sms/sms_protection_screen.dart';
import 'package:guard_call/features/sms/sms_scam_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CallHistoryRepository.instance.resetForTesting();
    FamilyAlertService.instance.resetForTesting();
  });

  group('Step 10: SmsScamAnalysisService Unit Tests', () {
    final service = SmsScamAnalysisService(
      engine: const MockScamDetectionEngine(),
      historyRepository: CallHistoryRepository.instance,
    );

    test('1. Routine medical appointment message is evaluated as Safe without scam signals', () async {
      const routineMessage =
          'Reminder: Your appointment with Dr. Henderson is confirmed for tomorrow at 2:00 PM. '
          'Reschedule your appointment by calling the clinic. No payment or sensitive information is required.';

      final result = await service.analyzeMessage(routineMessage);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, lessThanOrEqualTo(40));
      expect(result.isScamLikely, isFalse);
      expect(result.detectedSignals, isEmpty);
      expect(result.detectedTactics, isEmpty);
      expect(result.actionChecklist, isNotEmpty);
      expect(result.recommendedAction, contains('Routine notification'));
      expect(result.disclaimer, contains('does not constitute certified proof'));
    });

    test('2. Routine family message is evaluated as Safe with 0 risk score', () async {
      const familyMessage =
          'Hi Grandma! Just checking in to see how you are doing today. Looking forward to our Sunday lunch at 12:30 PM.';

      final result = await service.analyzeMessage(familyMessage);

      expect(result.riskLevel, RiskLevel.safe);
      expect(result.riskScore, 0);
      expect(result.isScamLikely, isFalse);
      expect(result.detectedSignals, isEmpty);
    });

    test('3. Urgent bank OTP credential harvesting message produces Critical risk', () async {
      const otpScamMessage =
          'URGENT: Calling from the bank fraud department. Your account will be blocked within 10 minutes. '
          'Tell me the OTP immediately to prevent arrest.';

      final result = await service.analyzeMessage(otpScamMessage);

      expect(result.riskLevel, RiskLevel.critical);
      expect(result.riskScore, greaterThanOrEqualTo(85));
      expect(result.isScamLikely, isTrue);

      final signalTypes = result.detectedSignals.map((s) => s.type).toSet();
      expect(signalTypes, contains(ScamSignalType.authorityImpersonation));
      expect(signalTypes, contains(ScamSignalType.urgency));
      expect(signalTypes, contains(ScamSignalType.fearThreat));
      expect(signalTypes, contains(ScamSignalType.sensitiveInformationRequest));

      expect(result.detectedTactics, contains('Fake Authority / Impersonation'));
      expect(result.detectedTactics, contains('OTP / Credential Request'));
      expect(result.detectedTactics, contains('Urgent Deadline Pressure'));
      expect(result.detectedTactics, contains('Legal / Account Threat'));

      // Safe action checklist must include OTP credential warning
      final checklistTitles = result.actionChecklist.map((c) => c.title).toList();
      expect(checklistTitles, contains('Never share OTPs or PIN codes'));
    });

    test('4. Phishing delivery tracking message flags Suspicious Link & Urgency', () async {
      const deliveryScamMessage =
          'USPS Notice: Your package delivery failed. Urgent: click this link https://usps-redelivery.com/pay to update address.';

      final result = await service.analyzeMessage(deliveryScamMessage);

      expect(result.riskScore, greaterThan(30));
      final signalTypes = result.detectedSignals.map((s) => s.type).toSet();
      expect(signalTypes, contains(ScamSignalType.suspiciousLink));
      expect(signalTypes, contains(ScamSignalType.urgency));

      final checklistTitles = result.actionChecklist.map((c) => c.title).toList();
      expect(checklistTitles, contains('Do not tap links or download files'));
    });

    test('5. Coercive digital arrest message flags Fear/Threat, Authority, and Financial Pressure', () async {
      const arrestMessage =
          'Police investigation notice: Legal action is registered against you. Your account will be blocked. '
          'Transfer money immediately via UPI payment to avoid arrest.';

      final result = await service.analyzeMessage(arrestMessage);

      expect(result.riskLevel, RiskLevel.critical);
      expect(result.riskScore, greaterThanOrEqualTo(85));

      final signalTypes = result.detectedSignals.map((s) => s.type).toSet();
      expect(signalTypes, contains(ScamSignalType.fearThreat));
      expect(signalTypes, contains(ScamSignalType.financialPressure));
      expect(signalTypes, contains(ScamSignalType.authorityImpersonation));

      final checklistTitles = result.actionChecklist.map((c) => c.title).toList();
      expect(checklistTitles, contains('Refuse immediate payment or wire transfers'));
      expect(checklistTitles, contains('Verify through official published contacts'));
    });

    test('6. Empty or whitespace-only message throws SmsEmptyMessageException', () async {
      expect(
        () => service.analyzeMessage(''),
        throwsA(isA<SmsEmptyMessageException>()),
      );
      expect(
        () => service.analyzeMessage('   \n\t  '),
        throwsA(isA<SmsEmptyMessageException>()),
      );
    });

    test('7. Excessively long message is safely truncated to maxInputLength without crashing', () async {
      final longText = 'Urgent: Your account will be blocked. ${'A' * 6000}';
      expect(longText.length, greaterThan(SmsScamAnalysisService.maxInputLength));

      final result = await service.analyzeMessage(longText);

      expect(result.isTruncated, isTrue);
      expect(result.rawMessage.length, SmsScamAnalysisService.maxInputLength);
      expect(result.detectedSignals, isNotEmpty);
    });

    test('8. Persisting SMS assessment to history writes non-simulated Manual SMS record', () async {
      const sampleMessage =
          'URGENT: Calling from the bank fraud department. Your account will be blocked. Tell me the OTP immediately.';

      final result = await service.analyzeMessage(sampleMessage);
      final initialCount = CallHistoryRepository.instance.records.length;

      final saved = await service.saveToHistory(result);

      expect(saved.isSimulated, isFalse);
      expect(saved.source, AssessmentSource.manualSms);
      expect(saved.title, 'Manual SMS Analysis');
      expect(saved.duration, '1 message');
      expect(saved.riskScore, result.riskScore);
      expect(saved.riskLevel, result.riskLevel);
      expect(saved.transcriptExcerpt, isNotEmpty);
      expect(saved.recommendedAction, contains('Critical threat detected'));

      final currentRecords = CallHistoryRepository.instance.records;
      expect(currentRecords.length, initialCount + 1);
      expect(currentRecords.first.id, saved.id);
      expect(currentRecords.first.source, AssessmentSource.manualSms);
    });
  });

  group('Step 10: CallHistoryRecord Serialization & AssessmentSource Compatibility', () {
    test('9. Serializes and deserializes source field with 100% fidelity', () {
      const record = CallHistoryRecord(
        id: 'test_sms_1',
        title: 'Manual SMS Analysis',
        subtitle: 'Critical threat evaluated',
        timestamp: 'Today • 14:00',
        duration: '1 message',
        riskScore: 95,
        riskLevel: RiskLevel.critical,
        signals: ['Authority Impersonation', 'OTP Request'],
        isSimulated: false,
        source: AssessmentSource.manualSms,
        explanation: 'Detailed explanation text',
        transcriptExcerpt: 'URGENT bank verification code',
        recommendedAction: 'Do not share credentials.',
      );

      final map = record.toMap();
      expect(map['source'], 'manualSms');
      expect(map['isSimulated'], isFalse);

      final restored = CallHistoryRecord.fromMap(map);
      expect(restored.id, record.id);
      expect(restored.source, AssessmentSource.manualSms);
      expect(restored.isSimulated, isFalse);
      expect(restored.riskScore, 95);
      expect(restored.signals, ['Authority Impersonation', 'OTP Request']);
    });

    test('10. Legacy records missing source key are inferred gracefully without breaking', () {
      final legacySmsMap = {
        'id': 'legacy_1',
        'title': 'Suspicious SMS Text',
        'subtitle': 'Old record',
        'timestamp': 'Yesterday',
        'duration': '1 message',
        'riskScore': 75,
        'riskLevel': 'high',
        'signals': ['Urgency'],
        'isSimulated': false,
      };

      final restoredSms = CallHistoryRecord.fromMap(legacySmsMap);
      expect(restoredSms.source, AssessmentSource.manualSms);

      final legacyMicMap = {
        'id': 'legacy_2',
        'title': 'Microphone Audio Analysis',
        'subtitle': 'Old mic record',
        'timestamp': 'Yesterday',
        'duration': '45s',
        'riskScore': 20,
        'riskLevel': 'safe',
        'signals': [],
        'isSimulated': false,
      };

      final restoredMic = CallHistoryRecord.fromMap(legacyMicMap);
      expect(restoredMic.source, AssessmentSource.microphoneAudio);

      final legacyDemoMap = {
        'id': 'legacy_3',
        'title': 'Emergency Impersonation Call',
        'subtitle': 'Demo simulation',
        'timestamp': 'Yesterday',
        'duration': '1m 20s',
        'riskScore': 90,
        'riskLevel': 'critical',
        'signals': ['Fear'],
        'isSimulated': true,
      };

      final restoredDemo = CallHistoryRecord.fromMap(legacyDemoMap);
      expect(restoredDemo.source, AssessmentSource.demoCall);
    });

    test('11. copyWith properly copies or overrides source field', () {
      const record = CallHistoryRecord(
        id: 'test_copy',
        title: 'Title',
        subtitle: 'Sub',
        timestamp: 'Time',
        duration: '0s',
        riskScore: 10,
        riskLevel: RiskLevel.safe,
        signals: [],
        source: AssessmentSource.microphoneAudio,
      );

      final cloned = record.copyWith(source: AssessmentSource.manualSms);
      expect(cloned.source, AssessmentSource.manualSms);

      final retained = record.copyWith(riskScore: 25);
      expect(retained.source, AssessmentSource.microphoneAudio);
      expect(retained.riskScore, 25);
    });
  });

  group('Step 10: SmsProtectionController Unit Tests', () {
    test('12. Initial state is empty and idle', () {
      final controller = SmsProtectionController();
      expect(controller.isAnalyzing, isFalse);
      expect(controller.hasResult, isFalse);
      expect(controller.currentResult, isNull);
      expect(controller.errorMessage, isNull);
      expect(controller.savedRecord, isNull);
      controller.dispose();
    });

    test('13. loadPreset populates textController and resets prior results/errors', () {
      final controller = SmsProtectionController();
      controller.loadPreset('Test preset message content');

      expect(controller.textController.text, 'Test preset message content');
      expect(controller.errorMessage, isNull);
      expect(controller.currentResult, isNull);
      controller.dispose();
    });

    test('14. analyze on empty text sets errorMessage and does not throw', () async {
      final controller = SmsProtectionController();
      controller.textController.text = '   ';

      await controller.analyze();

      expect(controller.errorMessage, contains('Please enter or paste message text'));
      expect(controller.hasResult, isFalse);
      controller.dispose();
    });

    test('15. analyze on valid text populates currentResult and savedRecord', () async {
      final controller = SmsProtectionController();
      controller.loadPreset(SmsProtectionController.presets.first.text);

      await controller.analyze();

      expect(controller.hasResult, isTrue);
      expect(controller.errorMessage, isNull);
      expect(controller.currentResult!.riskLevel, RiskLevel.critical);
      expect(controller.savedRecord, isNotNull);
      expect(controller.savedRecord!.source, AssessmentSource.manualSms);
      controller.dispose();
    });

    test('16. clear resets text, result, and errors', () async {
      final controller = SmsProtectionController();
      controller.loadPreset(SmsProtectionController.presets.first.text);
      await controller.analyze();
      expect(controller.hasResult, isTrue);

      controller.clear();

      expect(controller.textController.text, isEmpty);
      expect(controller.hasResult, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.savedRecord, isNull);
      controller.dispose();
    });
  });

  group('Step 10: SmsProtectionScreen Widget UI Tests', () {
    Widget buildTestScreen([SmsProtectionController? controller]) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: SmsProtectionScreen(controller: controller),
      );
    }

    testWidgets('17. Renders AppBar, privacy banner, presets, input field, and action button', (tester) async {
      await tester.pumpWidget(buildTestScreen());

      expect(find.text('SMS Scam Shield'), findsOneWidget);
      expect(find.text('Safe Message Analysis'), findsOneWidget);
      expect(find.text('Zero Inbox Snooping'), findsOneWidget);
      expect(find.byKey(const Key('sms_input_text_field')), findsOneWidget);
      expect(find.byKey(const Key('sms_analyze_button')), findsOneWidget);
      expect(find.byKey(const Key('sms_paste_clipboard_button')), findsOneWidget);

      // Verify sample presets are displayed
      expect(find.text('Bank OTP Scam'), findsOneWidget);
      expect(find.text('Package Delivery Link'), findsOneWidget);
    });

    testWidgets('18. Tapping Analyze on empty input displays validation error banner', (tester) async {
      await tester.pumpWidget(buildTestScreen());

      final analyzeBtn = find.byKey(const Key('sms_analyze_button'));
      await tester.ensureVisible(analyzeBtn);
      await tester.tap(analyzeBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sms_validation_error')), findsOneWidget);
      expect(find.text('Please enter or paste message text to analyze.'), findsOneWidget);
      expect(find.byKey(const Key('sms_analysis_results_card')), findsNothing);
    });

    testWidgets('19. Loading preset and analyzing renders complete threat breakdown & checklist', (tester) async {
      final controller = SmsProtectionController();
      await tester.pumpWidget(buildTestScreen(controller));

      // Tap preset chip
      final presetChip = find.byKey(const Key('sms_preset_bank_otp_scam'));
      expect(presetChip, findsOneWidget);
      await tester.tap(presetChip);
      await tester.pumpAndSettle();

      expect(controller.textController.text, contains('URGENT: Calling from the bank'));

      // Tap Analyze button
      final analyzeBtn = find.byKey(const Key('sms_analyze_button'));
      await tester.ensureVisible(analyzeBtn);
      await tester.tap(analyzeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Results card should be rendered
      expect(find.byKey(const Key('sms_analysis_results_card')), findsOneWidget);
      expect(find.text('Threat Score: 100 / 100'), findsOneWidget);
      expect(find.text('Identified Scam Tactics'), findsOneWidget);
      expect(find.text('Fake Authority / Impersonation'), findsOneWidget);
      expect(find.text('OTP / Credential Request'), findsOneWidget);

      // Safe Action Checklist
      expect(find.text('Safe Action Checklist'), findsOneWidget);
      expect(find.text('Never share OTPs or PIN codes'), findsOneWidget);

      // Saved in history indicator
      expect(find.text('Saved to Risk History (Manual SMS Analysis)'), findsOneWidget);

      // Alert Family Button
      final alertFamilyBtn = find.byKey(const Key('sms_alert_family_button'));
      await tester.ensureVisible(alertFamilyBtn);
      expect(alertFamilyBtn, findsOneWidget);

      // Reset button
      final resetBtn = find.byKey(const Key('sms_reset_button'));
      await tester.ensureVisible(resetBtn);
      expect(resetBtn, findsOneWidget);

      controller.dispose();
    });

    testWidgets('20. Tapping Alert Family Circle notifies family service and shows confirmation', (tester) async {
      final controller = SmsProtectionController();
      controller.loadPreset(SmsProtectionController.presets.first.text);
      await tester.pumpWidget(buildTestScreen(controller));

      final analyzeBtn = find.byKey(const Key('sms_analyze_button'));
      await tester.ensureVisible(analyzeBtn);
      await tester.tap(analyzeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final alertFamilyBtn = find.byKey(const Key('sms_alert_family_button'));
      await tester.ensureVisible(alertFamilyBtn);
      expect(alertFamilyBtn, findsOneWidget);
      await tester.tap(alertFamilyBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // SnackBar verification
      expect(find.text('Family circle notified regarding this suspicious message.'), findsOneWidget);

      // Verify alert was logged in FamilyAlertService
      final alerts = FamilyAlertService.instance.inMemoryAlerts;
      expect(alerts, isNotEmpty);
      expect(alerts.first.scenarioType, 'Suspicious SMS Message');
      expect(alerts.first.riskScore, 100);

      controller.dispose();
    });

    testWidgets('21. Tapping Analyze Another clears input and returns to initial state', (tester) async {
      final controller = SmsProtectionController();
      controller.loadPreset(SmsProtectionController.presets.first.text);
      await tester.pumpWidget(buildTestScreen(controller));

      final analyzeBtn = find.byKey(const Key('sms_analyze_button'));
      await tester.ensureVisible(analyzeBtn);
      await tester.tap(analyzeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sms_analysis_results_card')), findsOneWidget);

      final resetBtn = find.byKey(const Key('sms_reset_button'));
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('sms_analysis_results_card')), findsNothing);
      expect(controller.textController.text, isEmpty);

      controller.dispose();
    });

    testWidgets('22. Navigation from CallsScreen opens SmsProtectionScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CallsScreen(),
        ),
      );

      final openSmsButton = find.byKey(const Key('open_sms_protection_button'));
      expect(openSmsButton, findsOneWidget);
      await tester.ensureVisible(openSmsButton);
      await tester.tap(openSmsButton);
      await tester.pumpAndSettle();

      expect(find.text('SMS Scam Shield'), findsOneWidget);
      expect(find.text('Safe Message Analysis'), findsOneWidget);
    });

    testWidgets('23. Navigation from HomeScreen opens SmsProtectionScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      final homeSmsButton = find.byKey(const Key('home_open_sms_protection_button'));
      expect(homeSmsButton, findsOneWidget);

      await tester.tap(homeSmsButton);
      await tester.pumpAndSettle();

      expect(find.text('SMS Scam Shield'), findsOneWidget);
      expect(find.text('Safe Message Analysis'), findsOneWidget);
    });
  });
}
