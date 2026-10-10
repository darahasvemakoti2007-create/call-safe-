import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/calls/calls_screen.dart';
import 'package:guard_call/features/calls/live_microphone_controller.dart';
import 'package:guard_call/features/calls/live_microphone_screen.dart';
import 'package:guard_call/features/detection/live_speech_recognition_service.dart';
import 'package:guard_call/features/detection/microphone_audio_capture_service.dart';
import 'package:guard_call/features/detection/microphone_permission_handler.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/history/call_history_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CallHistoryRepository.instance.resetForTesting();
  });

  group('Step 5 — Real Microphone Audio Detection Foundation Tests', () {
    // -------------------------------------------------------------------------
    // 1. PERMISSION HANDLING TESTS
    // -------------------------------------------------------------------------
    testWidgets('1a. Shows permission prompt when microphone access is not determined', (tester) async {
      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.notDetermined,
      );
      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: MockMicrophoneAudioCaptureService(),
        speechRecognitionService: MockLiveSpeechRecognitionService(),
        detectionEngine: const MockScamDetectionEngine(),
      );

      await tester.pumpWidget(
        MaterialApp(home: LiveMicrophoneScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Microphone Permission Needed'), findsOneWidget);
      expect(find.byKey(const Key('grant_microphone_permission_button')), findsOneWidget);
    });

    testWidgets('1b. Granting permission updates status and allows start capture', (tester) async {
      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.notDetermined,
      );
      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: MockMicrophoneAudioCaptureService(),
        speechRecognitionService: MockLiveSpeechRecognitionService(),
        detectionEngine: const MockScamDetectionEngine(),
      );

      await tester.pumpWidget(
        MaterialApp(home: LiveMicrophoneScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Change status to granted upon user tap
      permHandler.status = MicrophonePermissionStatus.granted;
      await tester.tap(find.byKey(const Key('grant_microphone_permission_button')));
      await tester.pumpAndSettle();

      expect(find.text('Microphone Permission Needed'), findsNothing);
      expect(find.byKey(const Key('start_microphone_shield_button')), findsOneWidget);
    });

    testWidgets('1c. Denied permission shows clear explanatory feedback', (tester) async {
      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.denied,
      );
      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: MockMicrophoneAudioCaptureService(),
        speechRecognitionService: MockLiveSpeechRecognitionService(),
        detectionEngine: const MockScamDetectionEngine(),
      );

      await controller.initialize();
      await controller.requestPermission();

      expect(controller.permissionStatus, MicrophonePermissionStatus.denied);
      expect(controller.errorMessage, contains('Microphone permission denied'));
    });

    testWidgets('1d. Permanently denied permission indicates app settings requirement', (tester) async {
      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.permanentlyDenied,
      );
      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: MockMicrophoneAudioCaptureService(),
        speechRecognitionService: MockLiveSpeechRecognitionService(),
        detectionEngine: const MockScamDetectionEngine(),
      );

      await tester.pumpWidget(
        MaterialApp(home: LiveMicrophoneScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Microphone Permission Blocked'), findsOneWidget);
      expect(find.textContaining('device settings'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. CAPTURE LIFECYCLE & HARDWARE TESTS
    // -------------------------------------------------------------------------
    test('2a. Capture start and stop transitions state correctly', () async {
      final captureService = MockMicrophoneAudioCaptureService();
      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.granted,
      );
      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: captureService,
        speechRecognitionService: MockLiveSpeechRecognitionService(),
        detectionEngine: const MockScamDetectionEngine(),
      );

      await controller.initialize();
      expect(controller.isCapturing, isFalse);

      await controller.startListening();
      expect(controller.isCapturing, isTrue);
      expect(captureService.startCount, 1);

      await controller.stopListening();
      expect(controller.isCapturing, isFalse);
      expect(captureService.stopCount, 1);
    });

    test('2b. Interruption transitions state and updates status message', () async {
      final captureService = MockMicrophoneAudioCaptureService();
      final controller = LiveMicrophoneController(
        permissionHandler: MockMicrophonePermissionHandler(
          status: MicrophonePermissionStatus.granted,
        ),
        audioCaptureService: captureService,
        speechRecognitionService: MockLiveSpeechRecognitionService(),
        detectionEngine: const MockScamDetectionEngine(),
      );

      await controller.initialize();
      await controller.startListening();
      expect(controller.isCapturing, isTrue);

      await controller.handleInterruption();
      expect(captureService.interruptCount, 1);
      expect(controller.statusMessage, contains('interrupted'));
    });

    test('2c. Audio capture start error is caught and handled safely', () async {
      final captureService = MockMicrophoneAudioCaptureService();
      captureService.pendingErrorOnStart = const AudioCaptureException(
        AudioCaptureErrorType.hardwareUnavailable,
        'Device microphone is occupied by another process.',
      );

      final controller = LiveMicrophoneController(
        permissionHandler: MockMicrophonePermissionHandler(
          status: MicrophonePermissionStatus.granted,
        ),
        audioCaptureService: captureService,
        speechRecognitionService: MockLiveSpeechRecognitionService(),
        detectionEngine: const MockScamDetectionEngine(),
      );

      await controller.initialize();
      await controller.startListening();

      expect(controller.isCapturing, isFalse);
      expect(controller.errorMessage, contains('Device microphone is occupied'));
    });

    // -------------------------------------------------------------------------
    // 3. LIVE TRANSCRIPTION STREAMING (INTERIM VS FINAL)
    // -------------------------------------------------------------------------
    testWidgets('3a. Renders interim and final transcript segments with visual distinction', (tester) async {
      final speechService = MockLiveSpeechRecognitionService();
      final controller = LiveMicrophoneController(
        permissionHandler: MockMicrophonePermissionHandler(
          status: MicrophonePermissionStatus.granted,
        ),
        audioCaptureService: MockMicrophoneAudioCaptureService(),
        speechRecognitionService: speechService,
        detectionEngine: const MockScamDetectionEngine(),
      );

      await tester.pumpWidget(
        MaterialApp(home: LiveMicrophoneScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Emit interim hypothesis
      speechService.emitSegment(LiveSpeechSegment(
        text: 'This is the fraud department',
        isFinal: false,
        timestamp: DateTime.now(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('INTERIM'), findsOneWidget);
      expect(find.text('This is the fraud department'), findsOneWidget);

      // Emit final confirmed segment
      speechService.emitSegment(LiveSpeechSegment(
        text: 'This is the fraud department from your bank.',
        isFinal: true,
        timestamp: DateTime.now(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('FINAL'), findsOneWidget);
      expect(find.text('This is the fraud department from your bank.'), findsOneWidget);
      expect(find.text('INTERIM'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // 4. SCAM DETECTION ENGINE INTEGRATION
    // -------------------------------------------------------------------------
    test('4a. Supplied scam transcript triggers Threat detection in risk engine', () async {
      final speechService = MockLiveSpeechRecognitionService();
      final controller = LiveMicrophoneController(
        permissionHandler: MockMicrophonePermissionHandler(
          status: MicrophonePermissionStatus.granted,
        ),
        audioCaptureService: MockMicrophoneAudioCaptureService(),
        speechRecognitionService: speechService,
        detectionEngine: const MockScamDetectionEngine(),
      );

      await controller.initialize();
      expect(controller.currentAnalysis.riskLevel, RiskLevel.safe);

      // Inject predatory threat phrases
      await controller.addSpokenLine(
        'This is a police investigation. You face arrest right now.',
        isFinal: true,
      );
      await controller.addSpokenLine(
        'You must wire transfer money immediately to avoid legal action.',
        isFinal: true,
      );

      expect(controller.currentAnalysis.riskScore, greaterThanOrEqualTo(85));
      expect(controller.currentAnalysis.riskLevel, RiskLevel.critical);
      expect(controller.currentAnalysis.detectedSignals, isNotEmpty);
      expect(
        controller.currentAnalysis.detectedSignals.any((s) => s.title.toLowerCase().contains('threat') || s.title.toLowerCase().contains('urgency')),
        isTrue,
      );
    });

    test('4b. Safe spoken dialogue remains in Safe risk tier', () async {
      final controller = LiveMicrophoneController(
        permissionHandler: MockMicrophonePermissionHandler(
          status: MicrophonePermissionStatus.granted,
        ),
        audioCaptureService: MockMicrophoneAudioCaptureService(),
        speechRecognitionService: MockLiveSpeechRecognitionService(),
        detectionEngine: const MockScamDetectionEngine(),
      );

      await controller.initialize();

      await controller.addSpokenLine(
        'Hi grandma, just calling to see if you want to meet for lunch tomorrow at noon.',
        isFinal: true,
      );

      expect(controller.currentAnalysis.riskLevel, RiskLevel.safe);
      expect(controller.currentAnalysis.riskScore, 0);
    });

    // -------------------------------------------------------------------------
    // 5. WARNING DEDUPLICATION TESTS
    // -------------------------------------------------------------------------
    test('5. Warning callback triggers only once per tier, avoiding repeated dialog spams', () async {
      int warningCount = 0;
      final controller = LiveMicrophoneController(
        permissionHandler: MockMicrophonePermissionHandler(
          status: MicrophonePermissionStatus.granted,
        ),
        audioCaptureService: MockMicrophoneAudioCaptureService(),
        speechRecognitionService: MockLiveSpeechRecognitionService(),
        detectionEngine: const MockScamDetectionEngine(),
      );

      controller.onWarningTriggered = (_) => warningCount++;
      await controller.initialize();

      // First scam utterance reaches Critical
      await controller.addSpokenLine(
        'This is a police investigation. Transfer money immediately or you face arrest.',
        isFinal: true,
      );
      expect(warningCount, 1);

      // Subsequent line in the same tier does NOT re-trigger warning
      await controller.addSpokenLine(
        'Do not hang up the phone.',
        isFinal: true,
      );
      expect(warningCount, 1);

      // Third line in the same tier does NOT re-trigger warning
      await controller.addSpokenLine(
        'Go to the bank right now.',
        isFinal: true,
      );
      expect(warningCount, 1);
    });

    // -------------------------------------------------------------------------
    // 6. AUDIO RESOURCE CLEANUP
    // -------------------------------------------------------------------------
    testWidgets('6. Leaving screen properly stops capture and releases audio resources', (tester) async {
      final captureService = MockMicrophoneAudioCaptureService();
      final speechService = MockLiveSpeechRecognitionService();
      final controller = LiveMicrophoneController(
        permissionHandler: MockMicrophonePermissionHandler(
          status: MicrophonePermissionStatus.granted,
        ),
        audioCaptureService: captureService,
        speechRecognitionService: speechService,
        detectionEngine: const MockScamDetectionEngine(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveMicrophoneScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await controller.startListening();
      expect(controller.isCapturing, isTrue);

      // Pop screen
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Next Screen'))),
      );
      await tester.pumpAndSettle();

      expect(captureService.releaseCount, 1);
      expect(speechService.disposeCount, 1);
    });

    // -------------------------------------------------------------------------
    // 7. CALL HISTORY INTEGRATION
    // -------------------------------------------------------------------------
    test('7. Stopping session with genuine threat speech logs Microphone record to history', () async {
      final repo = CallHistoryRepository.instance;
      await repo.clear();
      expect(repo.records, isEmpty);

      final controller = LiveMicrophoneController(
        permissionHandler: MockMicrophonePermissionHandler(
          status: MicrophonePermissionStatus.granted,
        ),
        audioCaptureService: MockMicrophoneAudioCaptureService(),
        speechRecognitionService: MockLiveSpeechRecognitionService(),
        detectionEngine: const MockScamDetectionEngine(),
      );

      await controller.initialize();
      await controller.startListening();

      await controller.addSpokenLine(
        'This is a police investigation. Transfer money immediately or you face arrest.',
        isFinal: true,
      );

      await controller.stopListening();

      expect(repo.records, isNotEmpty);
      final savedRecord = repo.records.first;
      expect(savedRecord.title, 'Microphone Audio Analysis');
      expect(savedRecord.isSimulated, isFalse);
      expect(savedRecord.riskScore, greaterThanOrEqualTo(85));
      expect(savedRecord.signals, isNotEmpty);
      expect(savedRecord.transcriptExcerpt, contains('police investigation'));
    });

    // -------------------------------------------------------------------------
    // 8. CALLS SCREEN NAVIGATION ENTRY POINT
    // -------------------------------------------------------------------------
    testWidgets('8. CallsScreen provides clear Start Microphone Shield entry button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CallsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('open_live_mic_shield_button')), findsOneWidget);
      expect(find.text('Start Microphone Shield'), findsOneWidget);

      // Tap button and verify navigation to LiveMicrophoneScreen
      await tester.tap(find.byKey(const Key('open_live_mic_shield_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LiveMicrophoneScreen), findsOneWidget);
      expect(find.text('Live Microphone Audio Analysis'), findsOneWidget);
    });
  });
}
