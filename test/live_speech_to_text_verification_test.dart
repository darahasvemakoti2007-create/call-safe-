import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/core/config/app_config.dart';
import 'package:guard_call/core/services/ai_http_client.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/calls/live_microphone_controller.dart';
import 'package:guard_call/features/demo/demo_scenario.dart';
import 'package:guard_call/features/detection/audio_input.dart';
import 'package:guard_call/features/detection/live_speech_recognition_service.dart';
import 'package:guard_call/features/detection/microphone_audio_capture_service.dart';
import 'package:guard_call/features/detection/microphone_permission_handler.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/remote_speech_to_text_service.dart';
import 'package:guard_call/features/detection/speech_to_text_service.dart';
import 'package:guard_call/features/detection/wav_encoder.dart';
import 'package:guard_call/features/history/call_history_repository.dart';

class StubAIHttpClient implements AIHttpClient {
  final Future<String> Function({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout,
  }) handler;

  StubAIHttpClient(this.handler);

  @override
  Future<String> post({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 10),
  }) =>
      handler(url: url, headers: headers, body: body, timeout: timeout);
}

class RecordingSpeechToTextService extends SpeechToTextService {
  final List<AudioInput> recordedInputs = [];
  final List<ConversationLine> returnLines;
  Exception? pendingError;

  RecordingSpeechToTextService({
    this.returnLines = const [],
    this.pendingError,
  });

  @override
  Future<List<ConversationLine>> transcribeAudio(AudioInput input) async {
    recordedInputs.add(input);
    if (pendingError != null) throw pendingError!;
    return returnLines;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppConfig.current = AppConfig.offlineDefault();
  });

  group('Step 8 — Audio Container (WAV Encoder) Tests', () {
    test('1. Encodes 16kHz linear PCM bytes into valid 44-byte RIFF/WAVE container', () {
      // 100 samples of 16-bit PCM = 200 bytes
      final pcmBytes = Uint8List(200);
      for (var i = 0; i < 100; i++) {
        pcmBytes[i * 2] = 0x34;
        pcmBytes[i * 2 + 1] = 0x12; // 0x1234
      }

      final wavBytes = WavEncoder.encodePcmToWav(pcmBytes);

      expect(wavBytes.length, 244); // 44 header + 200 data
      expect(WavEncoder.isValidWavHeader(wavBytes), isTrue);

      final byteData = ByteData.sublistView(wavBytes);
      // "RIFF"
      expect(String.fromCharCode(wavBytes[0]), 'R');
      expect(String.fromCharCode(wavBytes[1]), 'I');
      expect(String.fromCharCode(wavBytes[2]), 'F');
      expect(String.fromCharCode(wavBytes[3]), 'F');
      // ChunkSize: 36 + 200 = 236
      expect(byteData.getUint32(4, Endian.little), 236);
      // "WAVE"
      expect(String.fromCharCode(wavBytes[8]), 'W');
      expect(String.fromCharCode(wavBytes[9]), 'A');
      expect(String.fromCharCode(wavBytes[10]), 'V');
      expect(String.fromCharCode(wavBytes[11]), 'E');
      // Format (1 for linear PCM)
      expect(byteData.getUint16(20, Endian.little), 1);
      // Channels (1 for Mono)
      expect(byteData.getUint16(22, Endian.little), 1);
      // SampleRate (16000)
      expect(byteData.getUint32(24, Endian.little), 16000);
      // ByteRate (32000 = 16000 * 1 * 2)
      expect(byteData.getUint32(28, Endian.little), 32000);
      // BitsPerSample (16)
      expect(byteData.getUint16(34, Endian.little), 16);
      // SubChunk2Size (200)
      expect(byteData.getUint32(40, Endian.little), 200);
      // First PCM sample preserved
      expect(wavBytes[44], 0x34);
      expect(wavBytes[45], 0x12);
    });

    test('2. Header validator rejects corrupt or non-WAV buffers', () {
      expect(WavEncoder.isValidWavHeader([]), isFalse);
      expect(WavEncoder.isValidWavHeader(Uint8List(40)), isFalse); // under 44 bytes
      expect(WavEncoder.isValidWavHeader(Uint8List(50)), isFalse); // all zeroes
    });
  });

  group('Step 8 — Bounded Audio Buffering & Chunk Aggregation Tests', () {
    test('3. Bounded buffer accumulates micro-chunks and flushes when reaching threshold', () async {
      final stt = RecordingSpeechToTextService(
        returnLines: [
          const ConversationLine(
            speaker: Speaker.caller,
            text: 'Your bank account is compromised',
          ),
        ],
      );

      // Buffer threshold: 100 bytes
      final service = DefaultLiveSpeechRecognitionService(
        sttService: stt,
        bufferThresholdBytes: 100,
      );

      final segments = <LiveSpeechSegment>[];
      final sub = service.segmentStream.listen(segments.add);

      await service.startListening(
        onSegment: (_) {},
        onError: (_) {},
      );

      // Feed 40 bytes (under threshold) -> should buffer, not transcribe
      await service.processAudioBytes(Uint8List(40));
      expect(stt.recordedInputs, isEmpty);
      expect(segments, isEmpty);

      // Feed 40 bytes (total 80, still under threshold)
      await service.processAudioBytes(Uint8List(40));
      expect(stt.recordedInputs, isEmpty);

      // Feed 30 bytes (total 110 >= 100) -> should trigger flush and transcribe!
      await service.processAudioBytes(Uint8List(30));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(stt.recordedInputs.length, 1);
      expect(segments.length, 1);
      expect(segments.first.text, 'Your bank account is compromised');

      // Verify input submitted to STT was packaged as a valid WAV
      final submitted = stt.recordedInputs.first;
      expect(submitted.audioBytes, isNotNull);
      expect(WavEncoder.isValidWavHeader(submitted.audioBytes!), isTrue);

      await sub.cancel();
      await service.dispose();
    });

    test('4. Flushes remaining buffered audio when stopListening() is called', () async {
      final stt = RecordingSpeechToTextService(
        returnLines: [
          const ConversationLine(
            speaker: Speaker.caller,
            text: 'Immediate payment required',
          ),
        ],
      );

      final service = DefaultLiveSpeechRecognitionService(
        sttService: stt,
        bufferThresholdBytes: 500, // High threshold
      );

      final segments = <LiveSpeechSegment>[];
      final sub = service.segmentStream.listen(segments.add);

      await service.startListening(
        onSegment: (_) {},
        onError: (_) {},
      );

      // Feed 50 bytes (under 500 threshold)
      await service.processAudioBytes(Uint8List(50));
      expect(stt.recordedInputs, isEmpty);

      // Stopping should flush the pending 50 bytes
      await service.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(stt.recordedInputs.length, 1);
      expect(segments.length, 1);
      expect(segments.first.text, 'Immediate payment required');

      await sub.cancel();
      await service.dispose();
    });

    test('5. Enforces bounded memory buffer limit (maxBufferSize = 160KB)', () async {
      final stt = RecordingSpeechToTextService();
      final service = DefaultLiveSpeechRecognitionService(
        sttService: stt,
        bufferThresholdBytes: 200000, // Above maxBufferSize
      );

      await service.startListening(
        onSegment: (_) {},
        onError: (_) {},
      );

      // Feed 100KB twice (total 200KB > 160KB max)
      await service.processAudioBytes(Uint8List(100000));
      await service.processAudioBytes(Uint8List(100000));

      // Stop to flush remaining buffer
      await service.stopListening();

      expect(stt.recordedInputs.length, 1);
      final rawPcmLength = stt.recordedInputs.first.audioBytes!.length - 44;
      // Buffer must be clamped to 160,000 bytes maximum
      expect(rawPcmLength, lessThanOrEqualTo(DefaultLiveSpeechRecognitionService.maxBufferSize));

      await service.dispose();
    });
  });

  group('Step 8 — Remote STT Provider Integration Tests', () {
    test('6. RemoteSpeechToTextService parses OpenAI Whisper text output and attaches WAV audio', () async {
      String? sentBody;
      final stubClient = StubAIHttpClient(
        ({required url, required headers, required body, timeout = const Duration(seconds: 10)}) async {
          sentBody = body;
          return jsonEncode({
            'text': 'We have detected unusual activity. Send your verification code now.',
          });
        },
      );

      final service = RemoteSpeechToTextService(
        apiKey: 'test-valid-key',
        httpClient: stubClient,
      );

      final pcmBytes = Uint8List(1600); // 50ms of audio
      final wavBytes = WavEncoder.encodePcmToWav(pcmBytes);
      final input = AudioInput.bytes(wavBytes, label: 'test_mic.wav');

      final lines = await service.transcribeAudio(input);

      expect(lines.length, 2); // Split into 2 sentences
      expect(lines.first.text, 'We have detected unusual activity.');
      expect(lines.last.text, 'Send your verification code now.');

      // Check request payload contains base64 audio and wav content type
      expect(sentBody, isNotNull);
      final decodedBody = jsonDecode(sentBody!) as Map<String, dynamic>;
      expect(decodedBody['audio_base64'], isNotNull);
      expect(decodedBody['content_type'], 'audio/wav');
      expect(decodedBody['model'], 'whisper-1');
    });

    test('7. Handles provider error envelope (rate limit / quota exceeded) cleanly', () async {
      final errorClient = StubAIHttpClient(
        ({required url, required headers, required body, timeout = const Duration(seconds: 10)}) async {
          return jsonEncode({
            'error': {
              'message': 'You exceeded your current quota, please check your plan and billing details.',
              'type': 'insufficient_quota',
            },
          });
        },
      );

      final service = RemoteSpeechToTextService(
        apiKey: 'test-key',
        httpClient: errorClient,
      );

      final input = AudioInput.bytes(WavEncoder.encodePcmToWav(Uint8List(200)));

      expect(
        () => service.transcribeAudio(input),
        throwsA(
          isA<SpeechToTextException>().having(
            (e) => e.message,
            'message',
            contains('exceeded your current quota'),
          ),
        ),
      );
    });

    test('8. Handles network socket drop and timeout gracefully', () async {
      final networkFailClient = StubAIHttpClient(
        ({required url, required headers, required body, timeout = const Duration(seconds: 10)}) async {
          throw const SocketException('Connection refused');
        },
      );

      final service = RemoteSpeechToTextService(
        apiKey: 'test-key',
        httpClient: networkFailClient,
      );

      final input = AudioInput.bytes(WavEncoder.encodePcmToWav(Uint8List(200)));

      expect(
        () => service.transcribeAudio(input),
        throwsA(
          isA<SpeechToTextException>().having(
            (e) => e.errorType,
            'errorType',
            SpeechToTextErrorType.transcriptionFailure,
          ),
        ),
      );
    });
  });

  group('Step 8 — LiveMicrophoneController End-to-End Pipeline & Assessment Tests', () {
    test('9. Real recognized scam phrase escalates risk score and triggers warning modal without duplicates', () async {
      final fakeStt = RecordingSpeechToTextService(
        returnLines: [
          const ConversationLine(
            speaker: Speaker.caller,
            text: 'This is police investigation regarding arrest warrant, transfer money immediately.',
          ),
        ],
      );

      final liveSttService = DefaultLiveSpeechRecognitionService(
        sttService: fakeStt,
        bufferThresholdBytes: 0, // immediate for test
      );

      final mockEngine = const MockScamDetectionEngine();
      final controller = LiveMicrophoneController(
        speechRecognitionService: liveSttService,
        detectionEngine: mockEngine,
        permissionHandler: MockMicrophonePermissionHandler(status: MicrophonePermissionStatus.granted),
      );

      var warningTriggerCount = 0;
      controller.onWarningTriggered = (_) {
        warningTriggerCount++;
      };

      await controller.initialize();
      await controller.startListening();

      // Feed PCM audio bytes into pipeline
      await liveSttService.processAudioBytes(Uint8List(100));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.transcriptSegments.length, 1);
      expect(controller.currentAnalysis.riskLevel, RiskLevel.critical);
      expect(controller.currentAnalysis.riskScore, greaterThanOrEqualTo(85));
      expect(controller.isWarningActive, isTrue);
      expect(warningTriggerCount, 1);

      // Dismiss warning
      controller.dismissWarningModal();
      expect(controller.isWarningActive, isFalse);

      // Subsequent identical evaluation should not re-trigger warning popup
      await controller.processSpeechSegment(controller.transcriptSegments.first);
      expect(warningTriggerCount, 1); // Deduplicated!

      await controller.stopListening();
      controller.dispose();
    });

    test('10. Persists assessment to CallHistoryRepository only when real recognized speech is evaluated', () async {
      CallHistoryRepository.instance.resetForTesting();
      final countBefore = CallHistoryRepository.instance.records.length;

      final fakeStt = RecordingSpeechToTextService(
        returnLines: [
          const ConversationLine(
            speaker: Speaker.caller,
            text: 'This is fraud department, transfer funds immediately.',
          ),
        ],
      );

      final liveSttService = DefaultLiveSpeechRecognitionService(
        sttService: fakeStt,
        bufferThresholdBytes: 0,
      );

      final controller = LiveMicrophoneController(
        speechRecognitionService: liveSttService,
        detectionEngine: const MockScamDetectionEngine(),
        permissionHandler: MockMicrophonePermissionHandler(status: MicrophonePermissionStatus.granted),
      );

      await controller.initialize();
      await controller.startListening();

      // Feed audio to produce genuine recognized speech
      await liveSttService.processAudioBytes(Uint8List(100));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.transcriptSegments, isNotEmpty);

      // Stop listening -> triggers logAssessmentToHistory()
      await controller.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final historyAfter = CallHistoryRepository.instance.records;
      expect(historyAfter.length, countBefore + 1);

      final savedRecord = historyAfter.first;
      expect(savedRecord.isSimulated, isFalse); // Genuine microphone capture!
      expect(savedRecord.title, 'Microphone Audio Analysis');
      expect(savedRecord.riskScore, greaterThan(0));

      controller.dispose();
    });

    test('11. Honest UI diagnostics: recognizer error suppresses LIVE RECOGNIZER ACTIVE badge', () async {
      final failingStt = RecordingSpeechToTextService(
        pendingError: const SpeechToTextException(
          SpeechToTextErrorType.transcriptionTimeout,
          'Recognition connection failed',
        ),
      );

      final liveSttService = DefaultLiveSpeechRecognitionService(
        sttService: failingStt,
        bufferThresholdBytes: 0,
      );

      final mockCapture = MockMicrophoneAudioCaptureService();
      final controller = LiveMicrophoneController(
        speechRecognitionService: liveSttService,
        audioCaptureService: mockCapture,
        permissionHandler: MockMicrophonePermissionHandler(status: MicrophonePermissionStatus.granted),
      );

      await controller.initialize();
      await controller.startListening();

      // Simulate capturing active
      mockCapture.setState(AudioCaptureState.capturing);

      // Initially configured and capturing
      expect(controller.isCapturing, isTrue);

      // Trigger error in STT
      try {
        await liveSttService.processAudioBytes(Uint8List(50));
      } catch (_) {}

      // Honest indicator: because lastError is set, isLiveTranscriptionActive MUST be false!
      expect(liveSttService.lastError, isNotNull);
      expect(controller.isLiveTranscriptionActive, isFalse);

      await controller.stopListening();
      controller.dispose();
    });

    test('12. Harmless evaluated speech persists to CallHistoryRepository as Safe assessment', () async {
      final harmlessStt = RecordingSpeechToTextService(
        returnLines: [
          const ConversationLine(
            speaker: Speaker.caller,
            text: 'Good morning Eleanor, just checking in to see how your garden is doing today.',
          ),
        ],
      );

      final liveSttService = DefaultLiveSpeechRecognitionService(
        sttService: harmlessStt,
        bufferThresholdBytes: 0,
      );

      final controller = LiveMicrophoneController(
        speechRecognitionService: liveSttService,
        detectionEngine: const MockScamDetectionEngine(),
        permissionHandler: MockMicrophonePermissionHandler(status: MicrophonePermissionStatus.granted),
      );

      await controller.initialize();
      await controller.startListening();

      final countBefore = CallHistoryRepository.instance.records.length;

      // Ingest harmless speech
      await liveSttService.processAudioBytes(Uint8List(80));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.transcriptSegments, isNotEmpty);
      expect(controller.currentAnalysis.riskScore, 0);
      expect(controller.currentAnalysis.riskLevel, RiskLevel.safe);

      // Stop listening -> triggers logAssessmentToHistory()
      await controller.stopListening();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final historyAfter = CallHistoryRepository.instance.records;
      expect(historyAfter.length, countBefore + 1);

      final saved = historyAfter.first;
      expect(saved.isSimulated, isFalse);
      expect(saved.riskScore, 0);
      expect(saved.riskLevel, RiskLevel.safe);
      expect(saved.recommendedAction, contains('No protective action needed'));

      controller.dispose();
    });
  });
}
