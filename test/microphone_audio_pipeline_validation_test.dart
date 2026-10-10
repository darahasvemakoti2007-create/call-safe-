import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:guard_call/core/services/ai_http_client.dart';
import 'package:guard_call/features/calls/live_microphone_controller.dart';
import 'package:guard_call/features/calls/live_microphone_screen.dart';
import 'package:guard_call/features/demo/demo_scenario.dart';
import 'package:guard_call/features/detection/audio_input.dart';
import 'package:guard_call/features/detection/live_speech_recognition_service.dart';
import 'package:guard_call/features/detection/microphone_audio_capture_service.dart';
import 'package:guard_call/features/detection/microphone_permission_handler.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/mock_speech_to_text_service.dart';
import 'package:guard_call/features/detection/remote_speech_to_text_service.dart';
import 'package:guard_call/features/detection/speech_to_text_service.dart';
import 'package:guard_call/features/history/call_history_repository.dart';

/// Test STT service that simulates controlled network or parse failures.
class FailingSpeechToTextService extends SpeechToTextService {
  final SpeechToTextException failureException;

  FailingSpeechToTextService(this.failureException);

  @override
  Future<List<ConversationLine>> transcribeAudio(AudioInput input) async {
    throw failureException;
  }
}

/// Test STT service that returns a predefined list of conversation lines.
class PredictableSpeechToTextService extends SpeechToTextService {
  final List<ConversationLine> linesToReturn;

  PredictableSpeechToTextService(this.linesToReturn);

  @override
  Future<List<ConversationLine>> transcribeAudio(AudioInput input) async {
    return linesToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CallHistoryRepository.instance.resetForTesting();
  });

  group('Step 6 — Audio Capture & Hardware Specification Tests', () {
    test('1. DefaultMicrophoneAudioCaptureService reports standard 16kHz Mono PCM format', () {
      final service = DefaultMicrophoneAudioCaptureService();

      expect(service.sampleRate, 16000);
      expect(service.channelCount, 1);
      expect(service.bitDepth, 16);
      expect(service.encoding, 'audio/pcm;rate=16000;channels=1');
      expect(service.isHardwareBound, isFalse); // Honest adapter indicator
      expect(service.state, AudioCaptureState.idle);
    });

    test('2. Capture lifecycle: idle -> starting -> capturing -> stopped', () async {
      final service = DefaultMicrophoneAudioCaptureService();
      final states = <AudioCaptureState>[];
      final sub = service.stateStream.listen(states.add);

      expect(service.state, AudioCaptureState.idle);
      await service.startCapture();
      expect(service.state, AudioCaptureState.capturing);

      await service.stopCapture();
      expect(service.state, AudioCaptureState.stopped);

      await sub.cancel();
      await service.release();
    });

    test('3. feedAudioBytes forwards PCM bytes to audioDataStream when capturing', () async {
      final service = DefaultMicrophoneAudioCaptureService();
      final receivedChunks = <List<int>>[];
      final sub = service.audioDataStream.listen(receivedChunks.add);

      await service.startCapture();

      final fakePcmChunk = [0, 1, 2, 3, 4, 5];
      service.feedAudioBytes(fakePcmChunk);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(receivedChunks.length, 1);
      expect(receivedChunks.first, fakePcmChunk);

      await service.stopCapture();
      // Should not forward bytes when stopped
      service.feedAudioBytes([9, 9, 9]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(receivedChunks.length, 1);

      await sub.cancel();
      await service.release();
    });

    test('4. Released audio capture service rejects startCapture', () async {
      final service = DefaultMicrophoneAudioCaptureService();
      await service.release();

      expect(
        () => service.startCapture(),
        throwsA(isA<AudioCaptureException>()),
      );
    });
  });

  group('Step 6 — Speech-to-Text Adapter & Chunk Processing Tests', () {
    test('5. DefaultLiveSpeechRecognitionService reports unconfigured when using offline mock', () {
      final service = DefaultLiveSpeechRecognitionService(
        sttService: const MockSpeechToTextService(),
      );

      expect(service.isConfigured, isFalse);
      expect(service.providerName, 'Offline / Unconfigured');
      expect(service.lastTranscriptionTime, isNull);
    });

    test('6. Reports configured status when backed by remote STT service', () {
      final remoteStt = RemoteSpeechToTextService(
        apiKey: 'test-valid-key-not-placeholder',
        httpClient: const DefaultAIHttpClient(),
      );
      final service = DefaultLiveSpeechRecognitionService(sttService: remoteStt);

      expect(service.isConfigured, isTrue);
      expect(service.providerName, contains('Direct Cloud STT'));
    });

    test('7. Malformed audio chunk (empty byte list) throws emptyAudio exception', () async {
      final service = DefaultLiveSpeechRecognitionService(
        sttService: const MockSpeechToTextService(),
      );

      await service.startListening(
        onSegment: (_) {},
        onError: (_) {},
      );

      expect(
        () => service.processAudioBytes([]),
        throwsA(isA<SpeechToTextException>().having(
          (e) => e.type,
          'errorType',
          SpeechToTextErrorType.emptyAudio,
        )),
      );

      expect(service.lastError, contains('empty'));
      await service.dispose();
    });

    test('8. Recognizer timeout or network failure updates lastError and triggers onError', () async {
      final failingStt = FailingSpeechToTextService(
        const SpeechToTextException(
          SpeechToTextErrorType.transcriptionTimeout,
          'Speech recognizer connection timed out after 15s',
        ),
      );
      final service = DefaultLiveSpeechRecognitionService(sttService: failingStt);

      String? reportedError;
      await service.startListening(
        onSegment: (_) {},
        onError: (err) => reportedError = err,
      );

      await expectLater(
        service.processAudioBytes([10, 20, 30, 40]),
        throwsA(isA<SpeechToTextException>()),
      );

      expect(service.lastError, contains('timed out'));
      expect(reportedError, contains('timed out'));
      await service.dispose();
    });

    test('9. Empty transcript results from recognizer are handled gracefully', () async {
      final emptyStt = PredictableSpeechToTextService([]);
      final service = DefaultLiveSpeechRecognitionService(sttService: emptyStt);

      final emitted = <LiveSpeechSegment>[];
      final sub = service.segmentStream.listen(emitted.add);

      await service.startListening(
        onSegment: (_) {},
        onError: (_) {},
      );

      // Process non-empty audio bytes that produce zero speech segments (e.g. ambient silence)
      await service.processAudioBytes([1, 2, 3, 4]);

      expect(emitted, isEmpty);
      expect(service.lastTranscriptionTime, isNotNull);
      expect(service.lastError, isNull);

      await sub.cancel();
      await service.dispose();
    });

    test('10. Valid audio chunk produces LiveSpeechSegment and updates lastTranscriptionTime', () async {
      final successfulStt = PredictableSpeechToTextService([
        const ConversationLine(
          speaker: Speaker.caller,
          text: 'Transfer your money to safe account immediately',
        ),
      ]);
      final service = DefaultLiveSpeechRecognitionService(sttService: successfulStt);

      final emitted = <LiveSpeechSegment>[];
      final sub = service.segmentStream.listen(emitted.add);

      await service.startListening(
        onSegment: (_) {},
        onError: (_) {},
      );

      await service.processAudioBytes([10, 20, 30, 40]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(emitted.length, 1);
      expect(emitted.first.text, 'Transfer your money to safe account immediately');
      expect(emitted.first.isFinal, isTrue);
      expect(service.lastTranscriptionTime, isNotNull);

      await sub.cancel();
      await service.dispose();
    });
  });

  group('Step 6 — Pipeline Diagnostics & Controller Integration Tests', () {
    test('11. LiveMicrophoneController exposes complete pipeline diagnostic health', () async {
      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.granted,
      );
      final audioCapture = MockMicrophoneAudioCaptureService();
      final speechService = MockLiveSpeechRecognitionService(
        isConfigured: false,
        providerName: 'Offline / Unconfigured',
      );

      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: audioCapture,
        speechRecognitionService: speechService,
        detectionEngine: const MockScamDetectionEngine(),
      );

      await controller.initialize();

      expect(controller.permissionStatus, MicrophonePermissionStatus.granted);
      expect(controller.captureAvailabilityDescription, contains('Idle / Standby'));
      expect(controller.isSttConfigured, isFalse);
      expect(controller.sttStatusDescription, contains('Unconfigured'));
      expect(controller.lastTranscriptionStatus, contains('No speech transcribed yet'));
      expect(controller.riskEngineStatusDescription, contains('Heuristic Engine'));
      expect(controller.isLiveTranscriptionActive, isFalse);

      controller.dispose();
    });

    test('12. isLiveTranscriptionActive is false when capturing with unconfigured ASR', () async {
      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.granted,
      );
      final audioCapture = MockMicrophoneAudioCaptureService();
      final speechService = MockLiveSpeechRecognitionService(isConfigured: false);

      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: audioCapture,
        speechRecognitionService: speechService,
        detectionEngine: const MockScamDetectionEngine(),
      );

      await controller.initialize();
      await controller.startListening();

      expect(controller.isCapturing, isTrue);
      expect(controller.isSttConfigured, isFalse);
      // Crucial honest invariant: NOT live transcription active
      expect(controller.isLiveTranscriptionActive, isFalse);
      expect(controller.statusMessage, contains('ASR unconfigured'));

      await controller.stopListening();
      controller.dispose();
    });

    test('13. isLiveTranscriptionActive is true when capturing with configured ASR', () async {
      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.granted,
      );
      final audioCapture = MockMicrophoneAudioCaptureService();
      final speechService = MockLiveSpeechRecognitionService(
        isConfigured: true,
        providerName: 'Supabase Edge Proxy (Active)',
      );

      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: audioCapture,
        speechRecognitionService: speechService,
        detectionEngine: const MockScamDetectionEngine(),
      );

      await controller.initialize();
      await controller.startListening();

      expect(controller.isCapturing, isTrue);
      expect(controller.isSttConfigured, isTrue);
      expect(controller.isLiveTranscriptionActive, isTrue);
      expect(controller.statusMessage, contains('listening and evaluating speech'));

      await controller.stopListening();
      controller.dispose();
    });

    test('14. Audio bytes from audioCaptureService are piped directly into speechRecognitionService', () async {
      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.granted,
      );
      final audioCapture = MockMicrophoneAudioCaptureService();
      final speechService = MockLiveSpeechRecognitionService(isConfigured: true);

      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: audioCapture,
        speechRecognitionService: speechService,
        detectionEngine: const MockScamDetectionEngine(),
      );

      await controller.initialize();
      await controller.startListening();

      expect(speechService.processAudioCount, 0);

      // Audio capture service receives a PCM buffer
      audioCapture.emitAudioData([1, 2, 3, 4, 5, 6]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(speechService.processAudioCount, 1);

      await controller.stopListening();
      controller.dispose();
    });
  });

  group('Step 6 — Widget UI Diagnostics & Honest Status Display Tests', () {
    testWidgets('15. LiveMicrophoneScreen renders Pipeline Diagnostics Card with all 5 items', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.granted,
      );
      final audioCapture = MockMicrophoneAudioCaptureService();
      final speechService = MockLiveSpeechRecognitionService(
        isConfigured: false,
        providerName: 'Offline / Unconfigured',
      );

      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: audioCapture,
        speechRecognitionService: speechService,
        detectionEngine: const MockScamDetectionEngine(),
      );

      await tester.pumpWidget(
        MaterialApp(home: LiveMicrophoneScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Check Diagnostics Card
      expect(find.byKey(const Key('pipeline_diagnostics_card')), findsOneWidget);
      expect(find.text('Pipeline Diagnostics'), findsOneWidget);
      expect(find.text('Microphone Permission'), findsOneWidget);
      expect(find.text('Audio Capture'), findsOneWidget);
      expect(find.text('Speech Recognizer (ASR)'), findsOneWidget);
      expect(find.text('Last Transcription'), findsOneWidget);
      expect(find.text('Scam Detection Engine'), findsOneWidget);

      // Verify unconfigured badge status
      expect(find.text('STANDBY'), findsOneWidget);
      expect(find.text('LIVE RECOGNIZER ACTIVE'), findsNothing);
    });

    testWidgets('16. When capturing with unconfigured ASR, UI displays ACOUSTIC ONLY badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.granted,
      );
      final audioCapture = MockMicrophoneAudioCaptureService();
      final speechService = MockLiveSpeechRecognitionService(isConfigured: false);

      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: audioCapture,
        speechRecognitionService: speechService,
        detectionEngine: const MockScamDetectionEngine(),
      );

      await tester.pumpWidget(
        MaterialApp(home: LiveMicrophoneScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start_microphone_shield_button')));
      await tester.pumpAndSettle();

      // Verified: Displays ACOUSTIC ONLY, NOT LIVE RECOGNIZER ACTIVE
      expect(find.text('ACOUSTIC ONLY'), findsOneWidget);
      expect(find.text('LIVE RECOGNIZER ACTIVE'), findsNothing);
      expect(find.textContaining('Acoustic Monitoring'), findsOneWidget);
    });

    testWidgets('17. When capturing with configured ASR, UI displays LIVE RECOGNIZER ACTIVE badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.granted,
      );
      final audioCapture = MockMicrophoneAudioCaptureService();
      final speechService = MockLiveSpeechRecognitionService(
        isConfigured: true,
        providerName: 'Supabase Edge Proxy',
      );

      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: audioCapture,
        speechRecognitionService: speechService,
        detectionEngine: const MockScamDetectionEngine(),
      );

      await tester.pumpWidget(
        MaterialApp(home: LiveMicrophoneScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start_microphone_shield_button')));
      await tester.pumpAndSettle();

      // Verified: Displays LIVE RECOGNIZER ACTIVE
      expect(find.text('LIVE RECOGNIZER ACTIVE'), findsOneWidget);
      expect(find.textContaining('Microphone Active'), findsOneWidget);
    });

    testWidgets('18. Unconfigured ASR shows honest manual verification callout and hint', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final permHandler = MockMicrophonePermissionHandler(
        status: MicrophonePermissionStatus.granted,
      );
      final speechService = MockLiveSpeechRecognitionService(isConfigured: false);

      final controller = LiveMicrophoneController(
        permissionHandler: permHandler,
        audioCaptureService: MockMicrophoneAudioCaptureService(),
        speechRecognitionService: speechService,
        detectionEngine: const MockScamDetectionEngine(),
      );

      await tester.pumpWidget(
        MaterialApp(home: LiveMicrophoneScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Open manual test input
      await tester.tap(find.text('Manual Test Input'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Manual Speech Test:'), findsOneWidget);
      expect(find.byKey(const Key('manual_speech_input_field')), findsOneWidget);
    });
  });
}
