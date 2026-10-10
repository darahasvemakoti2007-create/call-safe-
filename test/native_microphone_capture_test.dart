import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/features/calls/live_microphone_controller.dart';
import 'package:guard_call/features/detection/microphone_audio_capture_service.dart';
import 'package:guard_call/features/detection/microphone_permission_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methodChannel = MethodChannel('guardcall/audio_capture');
  const eventChannelName = 'guardcall/audio_stream';
  const codec = StandardMethodCodec();

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockMethodCallHandler(const MethodChannel(eventChannelName), null);
  });

  group('Step 7 — Native Android Microphone Capture Platform Channel Tests', () {
    test('1. DefaultMicrophonePermissionHandler parses native permission results accurately', () async {
      String nativePermissionResult = 'granted';
      messenger.setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        if (call.method == 'checkPermission') {
          return nativePermissionResult;
        } else if (call.method == 'requestPermission') {
          return nativePermissionResult;
        }
        return null;
      });

      final handler = DefaultMicrophonePermissionHandler();

      // Check granted
      var status = await handler.checkPermission();
      expect(status, MicrophonePermissionStatus.granted);
      expect(status.isGranted, isTrue);

      // Check denied
      nativePermissionResult = 'denied';
      status = await handler.checkPermission();
      expect(status, MicrophonePermissionStatus.denied);
      expect(status.isDenied, isTrue);
      expect(status.isPermanentlyDenied, isFalse);

      // Check permanently denied
      nativePermissionResult = 'permanentlyDenied';
      status = await handler.requestPermission();
      expect(status, MicrophonePermissionStatus.permanentlyDenied);
      expect(status.isPermanentlyDenied, isTrue);
    });

    test('2. DefaultMicrophoneAudioCaptureService binds native recorder when platform channel is available', () async {
      final methodCalls = <String>[];
      messenger.setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        methodCalls.add(call.method);
        if (call.method == 'isAvailable') return true;
        if (call.method == 'startCapture') return true;
        if (call.method == 'stopCapture') return true;
        return null;
      });

      messenger.setMockMethodCallHandler(const MethodChannel(eventChannelName), (MethodCall call) async {
        return null;
      });

      final service = DefaultMicrophoneAudioCaptureService();
      expect(service.isHardwareBound, isFalse);

      await service.startCapture();

      expect(methodCalls, contains('isAvailable'));
      expect(methodCalls, contains('startCapture'));
      expect(service.state, AudioCaptureState.capturing);
      expect(service.isHardwareBound, isTrue);

      await service.stopCapture();
      expect(methodCalls, contains('stopCapture'));
      expect(service.state, AudioCaptureState.stopped);
      expect(service.isHardwareBound, isFalse);

      await service.release();
    });

    test('3. Real 16-bit PCM chunks stream through EventChannel and compute real RMS levels', () async {
      messenger.setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        if (call.method == 'isAvailable') return true;
        if (call.method == 'startCapture') return true;
        if (call.method == 'stopCapture') return true;
        return null;
      });

      messenger.setMockMethodCallHandler(const MethodChannel(eventChannelName), (MethodCall call) async {
        return null;
      });

      final service = DefaultMicrophoneAudioCaptureService();
      await service.startCapture();
      expect(service.isHardwareBound, isTrue);

      final receivedChunks = <List<int>>[];
      final audioSub = service.audioDataStream.listen(receivedChunks.add);

      final receivedLevels = <double>[];
      final levelSub = service.audioLevelStream.listen(receivedLevels.add);

      // Synthesize a 16-bit PCM buffer (100 samples of amplitude 10,000)
      final sampleCount = 100;
      final byteData = ByteData(sampleCount * 2);
      for (var i = 0; i < sampleCount; i++) {
        byteData.setInt16(i * 2, 10000, Endian.little);
      }
      final testPcmBytes = byteData.buffer.asUint8List();

      // Emit chunk via event channel
      await messenger.handlePlatformMessage(
        eventChannelName,
        codec.encodeSuccessEnvelope(testPcmBytes),
        (ByteData? _) {},
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(receivedChunks, isNotEmpty);
      expect(receivedChunks.first.length, testPcmBytes.length);
      expect(receivedLevels, isNotEmpty);
      expect(receivedLevels.last, greaterThan(0.0));
      expect(receivedLevels.last, lessThanOrEqualTo(1.0));

      await audioSub.cancel();
      await levelSub.cancel();
      await service.stopCapture();
      await service.release();
    });

    test('4. RMS level calculation accurately differentiates silence vs sound signal', () {
      // Silence: all zeroes
      final silenceBytes = Uint8List(200);
      final silenceLevel = DefaultMicrophoneAudioCaptureService.calculateRmsLevel(silenceBytes);
      expect(silenceLevel, 0.0);

      // Low whisper: small sample amplitude ~500
      final whisperData = ByteData(200);
      for (var i = 0; i < 100; i++) {
        whisperData.setInt16(i * 2, 500, Endian.little);
      }
      final whisperLevel = DefaultMicrophoneAudioCaptureService.calculateRmsLevel(whisperData.buffer.asUint8List());
      expect(whisperLevel, greaterThan(0.0));
      expect(whisperLevel, lessThan(0.1));

      // Normal speech: moderate sample amplitude ~8000
      final speechData = ByteData(200);
      for (var i = 0; i < 100; i++) {
        speechData.setInt16(i * 2, 8000, Endian.little);
      }
      final speechLevel = DefaultMicrophoneAudioCaptureService.calculateRmsLevel(speechData.buffer.asUint8List());
      expect(speechLevel, greaterThan(whisperLevel));
      expect(speechLevel, greaterThan(0.4));

      // Peak amplitude / loud shout: maximum 16-bit range 32767
      final peakData = ByteData(200);
      for (var i = 0; i < 100; i++) {
        peakData.setInt16(i * 2, 32767, Endian.little);
      }
      final peakLevel = DefaultMicrophoneAudioCaptureService.calculateRmsLevel(peakData.buffer.asUint8List());
      expect(peakLevel, 1.0); // Clamped to 1.0
    });

    test('5. Handles native PERMISSION_DENIED exception gracefully', () async {
      messenger.setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        if (call.method == 'isAvailable') return true;
        if (call.method == 'startCapture') {
          throw PlatformException(
            code: 'PERMISSION_DENIED',
            message: 'RECORD_AUDIO permission is not granted.',
          );
        }
        return null;
      });

      final service = DefaultMicrophoneAudioCaptureService();

      await expectLater(
        service.startCapture(),
        throwsA(
          isA<AudioCaptureException>().having(
            (e) => e.type,
            'type',
            AudioCaptureErrorType.permissionDenied,
          ),
        ),
      );

      expect(service.state, AudioCaptureState.error);
      expect(service.isHardwareBound, isFalse);

      await service.release();
    });

    test('6. Handles native INITIALIZATION_FAILED exception gracefully', () async {
      messenger.setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        if (call.method == 'isAvailable') return true;
        if (call.method == 'startCapture') {
          throw PlatformException(
            code: 'INITIALIZATION_FAILED',
            message: 'AudioRecord hardware initialization failed.',
          );
        }
        return null;
      });

      final service = DefaultMicrophoneAudioCaptureService();

      await expectLater(
        service.startCapture(),
        throwsA(
          isA<AudioCaptureException>().having(
            (e) => e.type,
            'type',
            AudioCaptureErrorType.initializationFailed,
          ),
        ),
      );

      expect(service.state, AudioCaptureState.error);
      expect(service.isHardwareBound, isFalse);

      await service.release();
    });

    test('7. Handles native EventChannel stream interruption during capture', () async {
      messenger.setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        if (call.method == 'isAvailable') return true;
        if (call.method == 'startCapture') return true;
        if (call.method == 'stopCapture') return true;
        return null;
      });

      messenger.setMockMethodCallHandler(const MethodChannel(eventChannelName), (MethodCall call) async {
        return null;
      });

      final service = DefaultMicrophoneAudioCaptureService();
      await service.startCapture();
      expect(service.isHardwareBound, isTrue);

      final states = <AudioCaptureState>[];
      final stateSub = service.stateStream.listen(states.add);

      // Simulate native stream failure / audio focus loss
      await messenger.handlePlatformMessage(
        eventChannelName,
        codec.encodeErrorEnvelope(
          code: 'CAPTURE_ERROR',
          message: 'AudioRecord read error',
        ),
        (ByteData? _) {},
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(service.state, AudioCaptureState.interrupted);
      expect(service.isHardwareBound, isFalse);

      await stateSub.cancel();
      await service.release();
    });

    test('8. LiveMicrophoneController displays truthful hardware capture status in diagnostics', () async {
      messenger.setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        if (call.method == 'isAvailable') return true;
        if (call.method == 'checkPermission') return 'granted';
        if (call.method == 'startCapture') return true;
        if (call.method == 'stopCapture') return true;
        return null;
      });

      messenger.setMockMethodCallHandler(const MethodChannel(eventChannelName), (MethodCall call) async {
        return null;
      });

      final service = DefaultMicrophoneAudioCaptureService();
      final controller = LiveMicrophoneController(
        audioCaptureService: service,
        permissionHandler: DefaultMicrophonePermissionHandler(),
      );

      await controller.initialize();
      expect(controller.captureAvailabilityDescription, 'Idle / Standby');

      await controller.startListening();
      expect(controller.isCapturing, isTrue);
      expect(service.isHardwareBound, isTrue);
      expect(
        controller.captureAvailabilityDescription,
        'Capturing Live Audio (16000Hz • Mono • 16-bit)',
      );

      await controller.stopListening();
      expect(controller.isCapturing, isFalse);
      expect(controller.captureAvailabilityDescription, 'Idle / Standby');

      controller.dispose();
      await service.release();
    });
  });
}
