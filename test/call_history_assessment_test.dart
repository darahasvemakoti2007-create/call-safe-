import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/detection/risk_analysis.dart';
import 'package:guard_call/features/detection/scam_signal.dart';
import 'package:guard_call/features/history/assessment_detail_dialog.dart';
import 'package:guard_call/features/history/call_history_repository.dart';
import 'package:guard_call/features/history/history_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CallHistoryRepository.instance.resetForTesting();
  });

  group('Call History & Assessment Details Tests — Step 4', () {
    // -------------------------------------------------------------------------
    // 1. ACTUAL ASSESSMENT RECORDS APPEAR IN HISTORY
    // -------------------------------------------------------------------------
    testWidgets('1. Actual assessment records appear in History screen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Risk History'), findsOneWidget);
      expect(find.text('Past Assessments'), findsOneWidget);

      // Verify seed repository records are rendered with actual titles & subtitles
      expect(find.text('Emergency Impersonation Call'), findsOneWidget);
      expect(find.text('Bank Verification Department'), findsOneWidget);
      expect(find.text('Delivery Courier Inquiry'), findsOneWidget);
      expect(find.text('Local Pharmacy Reminder'), findsOneWidget);

      // Verify signals and scores from real data
      expect(find.text('Fear / Threat'), findsOneWidget);
      expect(find.text('OTP Request'), findsOneWidget);
      expect(find.text('Suspicious Link'), findsOneWidget);
      expect(find.text('No Scam Indicators'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. EMPTY HISTORY IS HANDLED CORRECTLY
    // -------------------------------------------------------------------------
    testWidgets('2. Empty history displays appropriate supportive empty state', (tester) async {
      await CallHistoryRepository.instance.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No call assessments yet'), findsOneWidget);
      expect(
        find.textContaining('No call risk assessment records have been logged yet'),
        findsOneWidget,
      );
      expect(find.text('Emergency Impersonation Call'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 3. SEARCH FILTERS RECORDS CORRECTLY
    // -------------------------------------------------------------------------
    testWidgets('3. Search filters records correctly by title, signal, and summary', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Search by title "bank"
      await tester.enterText(find.byKey(const Key('history_search_text_field')), 'bank');
      await tester.pumpAndSettle();

      expect(find.text('Bank Verification Department'), findsOneWidget);
      expect(find.text('Emergency Impersonation Call'), findsNothing);
      expect(find.text('Delivery Courier Inquiry'), findsNothing);
      expect(find.text('Local Pharmacy Reminder'), findsNothing);

      // Search by signal "OTP"
      await tester.enterText(find.byKey(const Key('history_search_text_field')), 'OTP');
      await tester.pumpAndSettle();

      expect(find.text('Bank Verification Department'), findsOneWidget);
      expect(find.text('Delivery Courier Inquiry'), findsNothing);

      // Search for non-existent text
      await tester.enterText(find.byKey(const Key('history_search_text_field')), 'nonexistent query 12345');
      await tester.pumpAndSettle();

      expect(find.text('No matching assessments found'), findsOneWidget);
      expect(find.textContaining('No records match "nonexistent query 12345"'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 4. RISK FILTERS WORK CORRECTLY
    // -------------------------------------------------------------------------
    testWidgets('4. Risk-level filter chips filter correctly across risk tiers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Critical" filter
      await tester.tap(find.text('Critical'));
      await tester.pumpAndSettle();

      expect(find.text('Emergency Impersonation Call'), findsOneWidget);
      expect(find.text('Bank Verification Department'), findsNothing);
      expect(find.text('Delivery Courier Inquiry'), findsNothing);
      expect(find.text('Local Pharmacy Reminder'), findsNothing);

      // Tap "Safe" filter
      await tester.tap(find.text('Safe'));
      await tester.pumpAndSettle();

      expect(find.text('Local Pharmacy Reminder'), findsOneWidget);
      expect(find.text('Emergency Impersonation Call'), findsNothing);

      // Tap "High" filter
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      expect(find.text('Bank Verification Department'), findsOneWidget);
      expect(find.text('Local Pharmacy Reminder'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 5. CLEARING FILTERS RESTORES THE FULL LIST
    // -------------------------------------------------------------------------
    testWidgets('5. Clearing active filters restores the complete assessment list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search and set filter
      await tester.enterText(find.byKey(const Key('history_search_text_field')), 'courier');
      await tester.pumpAndSettle();
      expect(find.text('Delivery Courier Inquiry'), findsOneWidget);
      expect(find.text('Emergency Impersonation Call'), findsNothing);

      // Tap "Clear Filters" in SectionHeader trailing
      await tester.tap(find.byKey(const Key('history_clear_filters_text_button')));
      await tester.pumpAndSettle();

      // All 4 records restored
      expect(find.text('Emergency Impersonation Call'), findsOneWidget);
      expect(find.text('Bank Verification Department'), findsOneWidget);
      expect(find.text('Delivery Courier Inquiry'), findsOneWidget);
      expect(find.text('Local Pharmacy Reminder'), findsOneWidget);

      // Also verify "Clear Filters" from empty state
      await tester.enterText(find.byKey(const Key('history_search_text_field')), 'impossible_token_999');
      await tester.pumpAndSettle();
      expect(find.text('No matching assessments found'), findsOneWidget);

      await tester.tap(find.byKey(const Key('history_clear_filters_empty_state_button')));
      await tester.pumpAndSettle();

      expect(find.text('Emergency Impersonation Call'), findsOneWidget);
      expect(find.text('Bank Verification Department'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 6. SELECTING A RECORD OPENS ITS DETAIL VIEW
    // -------------------------------------------------------------------------
    testWidgets('6. Selecting a record opens assessment detail dialog and dismisses cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the Critical Impersonation card
      await tester.tap(find.text('Emergency Impersonation Call'));
      await tester.pumpAndSettle();

      // Verify detail dialog is presented
      expect(find.byType(AssessmentDetailDialog), findsOneWidget);
      expect(find.text('Threat Score: 92/100'), findsOneWidget);
      expect(find.text('Assessment Explanation'), findsOneWidget);
      expect(find.textContaining('detained abroad and urgently demanded \$4,500'), findsOneWidget);
      expect(find.text('Recommended Protective Action'), findsOneWidget);
      expect(find.textContaining('Hang up immediately'), findsOneWidget);
      expect(find.text('Transcript Excerpt & Privacy'), findsOneWidget);

      // Tap close icon button to close
      await tester.tap(find.byKey(const Key('assessment_detail_close_icon_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AssessmentDetailDialog), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 7. ASSESSMENT DETAILS SHOW ONLY AVAILABLE STORED DATA (NO FABRICATIONS)
    // -------------------------------------------------------------------------
    testWidgets('7. Assessment details display honest fallback states for missing optional fields', (tester) async {
      const minimalRecord = CallHistoryRecord(
        id: 'minimal_record_1',
        title: 'Minimal Incomplete Assessment',
        subtitle: '',
        timestamp: '',
        duration: '15s',
        riskScore: 20,
        riskLevel: RiskLevel.safe,
        signals: [],
        explanation: null,
        transcriptExcerpt: null,
        recommendedAction: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AssessmentDetailDialog(record: minimalRecord),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & missing timestamp fallback
      expect(find.text('Minimal Incomplete Assessment'), findsOneWidget);
      expect(find.textContaining('Timestamp not recorded'), findsOneWidget);

      // Verify explanation fallback
      expect(
        find.text('No detailed assessment explanation was recorded for this session.'),
        findsOneWidget,
      );

      // Verify signals fallback
      expect(find.text('No manipulation signals recorded.'), findsOneWidget);

      // Verify recommended action fallback
      expect(find.text('No specific protective action recorded.'), findsOneWidget);

      // Verify privacy notice for unrecorded transcript
      expect(find.text('Transcript not stored'), findsOneWidget);
      expect(
        find.textContaining('GuardCall enforces a strict zero-retention privacy policy'),
        findsOneWidget,
      );
    });

    // -------------------------------------------------------------------------
    // 8. NEW RECORDS UPDATE THE INTERFACE REACTIVELY
    // -------------------------------------------------------------------------
    testWidgets('8. Adding new assessment record updates the screen reactively without restart', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Newly Completed Demo Call'), findsNothing);

      // Dynamically insert a new simulation record
      await CallHistoryRepository.instance.addRecord(
        const CallHistoryRecord(
          id: 'newly_logged_demo_99',
          title: 'Newly Completed Demo Call',
          subtitle: 'Simulated tax fraud scenario completed with high threat.',
          timestamp: 'Just now',
          duration: '3m 12s',
          riskScore: 88,
          riskLevel: RiskLevel.critical,
          signals: ['Tax Impersonation', 'Arrest Threat'],
          isSimulated: true,
        ),
      );
      await tester.pumpAndSettle();

      // Verify new record immediately renders at the top
      expect(find.text('Newly Completed Demo Call'), findsOneWidget);
      expect(find.text('Tax Impersonation'), findsOneWidget);
      expect(find.text('Threat: 88', skipOffstage: false), findsNothing); // format is badge
      expect(find.text('Critical Threat (88)'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 9. NARROW SCREENS DO NOT CAUSE LAYOUT OVERFLOW
    // -------------------------------------------------------------------------
    testWidgets('9. Narrow screen dimensions do not cause layout overflow in History or Details', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Risk History'), findsOneWidget);

      // Open detail modal on narrow screen
      await tester.ensureVisible(find.text('Emergency Impersonation Call'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emergency Impersonation Call'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AssessmentDetailDialog), findsOneWidget);

      // Close modal
      await tester.tap(find.byKey(const Key('assessment_detail_close_icon_button')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 10. MODEL SERIALIZATION & RISK-ENGINE INTEGRATION INTACT
    // -------------------------------------------------------------------------
    test('10. CallHistoryRecord serialization round-trip preserves all enhanced fields', () {
      const record = CallHistoryRecord(
        id: 'full_record_42',
        title: 'Medicare Impersonation',
        subtitle: 'Requested Medicare ID card number.',
        timestamp: 'Today at 2:00 PM',
        duration: '1m 20s',
        riskScore: 72,
        riskLevel: RiskLevel.high,
        signals: ['Healthcare Fraud', 'Identity Theft'],
        isSimulated: true,
        interventionStatus: 'notified',
        explanation: 'Caller claimed benefits would lapse without immediate identity confirmation.',
        transcriptExcerpt: '"We need your Medicare card number to update your file."',
        recommendedAction: 'Never provide Medicare or Social Security numbers over unverified phone calls.',
      );

      final map = record.toMap();
      final restored = CallHistoryRecord.fromMap(map);

      expect(restored.id, record.id);
      expect(restored.title, record.title);
      expect(restored.subtitle, record.subtitle);
      expect(restored.timestamp, record.timestamp);
      expect(restored.duration, record.duration);
      expect(restored.riskScore, record.riskScore);
      expect(restored.riskLevel, RiskLevel.high);
      expect(restored.signals, ['Healthcare Fraud', 'Identity Theft']);
      expect(restored.isSimulated, true);
      expect(restored.interventionStatus, 'notified');
      expect(restored.explanation, record.explanation);
      expect(restored.transcriptExcerpt, record.transcriptExcerpt);
      expect(restored.recommendedAction, record.recommendedAction);
    });

    test('10b. RiskAnalysis integrates smoothly with CallHistoryRecord model', () {
      final analysis = RiskAnalysis(
        riskScore: 82,
        riskLevel: RiskLevel.high,
        detectedSignals: [
          ScamSignal(
            type: ScamSignalType.urgency,
            title: 'Urgent Wire Transfer',
            explanation: 'Demanded rapid wire transfer',
          ),
        ],
        explanations: ['Urgent transfer requested under false pretenses.'],
        confidence: 0.95,
      );

      final record = CallHistoryRecord(
        id: 'analysis_test_1',
        title: 'Test Call',
        subtitle: analysis.summary,
        timestamp: 'Now',
        duration: '45s',
        riskScore: analysis.riskScore,
        riskLevel: analysis.riskLevel,
        signals: analysis.detectedSignals.map((s) => s.title).toList(),
        explanation: analysis.explanations.join('\n'),
      );

      expect(record.riskScore, 82);
      expect(record.riskLevel, RiskLevel.high);
      expect(record.signals, ['Urgent Wire Transfer']);
      expect(record.explanation, 'Urgent transfer requested under false pretenses.');
    });
  });
}
