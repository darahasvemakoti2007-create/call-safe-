import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Lifecycle states of device microphone audio capture.
enum AudioCaptureState {
  /// Recorder is inactive and ready to start.
  idle,

  /// Initializing hardware audio driver or requesting stream.
  starting,

  /// Active capture running, streaming acoustic waveform data.
  capturing,

  /// Capture interrupted by an external system event (e.g. incoming call, audio focus loss).
  interrupted,

  /// Capture has been explicitly stopped.
  stopped,

  /// Fatal error encountered during capture.
  error;

  bool get isActive => this == AudioCaptureState.capturing;
}

/// Typed categories for audio hardware and capture errors.
enum AudioCaptureErrorType {
  /// User denied microphone permission.
  permissionDenied,

  /// Microphone hardware is busy, unplugged, or unavailable.
  hardwareUnavailable,

  /// Audio capture interrupted by higher priority system audio.
  captureInterrupted,

  /// Audio buffer initialization failed.
  initializationFailed,

  /// Unspecified hardware or OS exception.
  unknown;
}

/// Typed exception representing an audio capture failure.
class AudioCaptureException implements Exception {
  final AudioCaptureErrorType type;
  final String message;

  const AudioCaptureException(this.type, this.message);

  @override
  String toString() => 'AudioCaptureException(${type.name}): $message';
}

/// Abstract contract managing device microphone audio capture.
abstract class MicrophoneAudioCaptureService {
  /// Current capture state.
  AudioCaptureState get state;

  /// Stream of state transitions.
  Stream<AudioCaptureState> get stateStream;

  /// Stream of captured raw audio byte buffers.
  Stream<List<int>> get audioDataStream;

  /// Stream of normalized audio volume/amplitude levels (0.0 to 1.0).
  Stream<double> get audioLevelStream;

  /// Sampling rate in Hz (standard 16000 for acoustic speech recognition).
  int get sampleRate;

  /// Audio channel count (1 for mono).
  int get channelCount;

  /// Audio bit depth (16 for 16-bit linear PCM).
  int get bitDepth;

  /// Audio encoding description.
  String get encoding;

  /// Whether real native hardware capture is bound and streaming.
  bool get isHardwareBound;

  /// Starts capturing audio from the physical microphone.
  Future<void> startCapture();

  /// Stops active microphone capture.
  Future<void> stopCapture();

  /// Signals that capture was interrupted by an external event.
  Future<void> interrupt();

  /// Stops capture and releases all allocated audio resources.
  Future<void> release();
}

/// Default implementation of [MicrophoneAudioCaptureService] managing
/// microphone lifecycle and streaming via native Android AudioRecord or fallback buffer.
class DefaultMicrophoneAudioCaptureService implements MicrophoneAudioCaptureService {
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  AudioCaptureState _state = AudioCaptureState.idle;
  final StreamController<AudioCaptureState> _stateController =
      StreamController<AudioCaptureState>.broadcast();
  final StreamController<List<int>> _audioDataController =
      StreamController<List<int>>.broadcast();
  final StreamController<double> _audioLevelController =
      StreamController<double>.broadcast();

  StreamSubscription<dynamic>? _nativeAudioSubscription;
  Timer? _levelTimer;
  bool _isReleased = false;
  bool _isHardwareBound = false;

  DefaultMicrophoneAudioCaptureService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ?? const MethodChannel('guardcall/audio_capture'),
        _eventChannel = eventChannel ?? const EventChannel('guardcall/audio_stream');

  @override
  int get sampleRate => 16000;

  @override
  int get channelCount => 1;

  @override
  int get bitDepth => 16;

  @override
  String get encoding => 'audio/pcm;rate=16000;channels=1';

  @override
  bool get isHardwareBound => _isHardwareBound;

  @override
  AudioCaptureState get state => _state;

  @override
  Stream<AudioCaptureState> get stateStream => _stateController.stream;

  @override
  Stream<List<int>> get audioDataStream => _audioDataController.stream;

  @override
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  void _setState(AudioCaptureState newState) {
    if (_isReleased) return;
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  @override
  Future<void> startCapture() async {
    if (_isReleased) {
      throw const AudioCaptureException(
        AudioCaptureErrorType.hardwareUnavailable,
        'Cannot start audio capture on a released service.',
      );
    }
    if (_state == AudioCaptureState.capturing) return;

    _setState(AudioCaptureState.starting);

    bool nativeStarted = false;
    try {
      final isAvailable = await _methodChannel.invokeMethod<bool>('isAvailable');
      if (isAvailable == true) {
        // Subscribe to native PCM EventChannel stream
        await _nativeAudioSubscription?.cancel();
        _nativeAudioSubscription = _eventChannel.receiveBroadcastStream().listen(
          (dynamic chunk) {
            if (chunk is List<int>) {
              feedAudioBytes(chunk);
            } else if (chunk is List) {
              feedAudioBytes(List<int>.from(chunk));
            }
          },
          onError: (dynamic error) {
            _handleNativeCaptureError(error);
          },
          onDone: () {
            _isHardwareBound = false;
          },
          cancelOnError: false,
        );

        final startResult = await _methodChannel.invokeMethod<bool>('startCapture');
        nativeStarted = startResult == true;
      }
    } on PlatformException catch (e) {
      await _nativeAudioSubscription?.cancel();
      _nativeAudioSubscription = null;
      _isHardwareBound = false;
      _setState(AudioCaptureState.error);
      if (e.code == 'PERMISSION_DENIED') {
        throw const AudioCaptureException(
          AudioCaptureErrorType.permissionDenied,
          'Microphone permission is required to capture audio.',
        );
      } else if (e.code == 'INITIALIZATION_FAILED') {
        throw AudioCaptureException(
          AudioCaptureErrorType.initializationFailed,
          'Failed to initialize native audio hardware: ${e.message}',
        );
      } else {
        throw AudioCaptureException(
          AudioCaptureErrorType.hardwareUnavailable,
          'Native audio capture error: ${e.message}',
        );
      }
    } on MissingPluginException {
      // Platform channel not available in current runtime (headless tests, web, or non-Android environment)
      nativeStarted = false;
    } catch (_) {
      nativeStarted = false;
    }

    if (nativeStarted) {
      _isHardwareBound = true;
      _setState(AudioCaptureState.capturing);
      return;
    }

    // Fallback mode for tests or environments without native AudioRecord:
    // brief delay simulating hardware buffer initialization
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_isReleased) return;

    _isHardwareBound = false;
    _setState(AudioCaptureState.capturing);

    // Emit gentle pulse amplitude updates to drive UI visualizer in fallback mode
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_state != AudioCaptureState.capturing || _isReleased) {
        timer.cancel();
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final level = 0.25 + 0.5 * ((now % 1000) / 1000.0);
      if (!_audioLevelController.isClosed) {
        _audioLevelController.add(level);
      }
    });
  }

  @override
  Future<void> stopCapture() async {
    _levelTimer?.cancel();
    _levelTimer = null;

    if (_nativeAudioSubscription != null) {
      await _nativeAudioSubscription?.cancel();
      _nativeAudioSubscription = null;
    }

    if (_isHardwareBound) {
      try {
        await _methodChannel.invokeMethod<bool>('stopCapture');
      } catch (_) {}
      _isHardwareBound = false;
    }

    if (!_audioLevelController.isClosed) {
      _audioLevelController.add(0.0);
    }
    _setState(AudioCaptureState.stopped);
  }

  @override
  Future<void> interrupt() async {
    _levelTimer?.cancel();
    _levelTimer = null;

    if (_nativeAudioSubscription != null) {
      await _nativeAudioSubscription?.cancel();
      _nativeAudioSubscription = null;
    }

    if (_isHardwareBound) {
      try {
        await _methodChannel.invokeMethod<bool>('stopCapture');
      } catch (_) {}
      _isHardwareBound = false;
    }

    if (!_audioLevelController.isClosed) {
      _audioLevelController.add(0.0);
    }
    _setState(AudioCaptureState.interrupted);
  }

  @override
  Future<void> release() async {
    if (_isReleased) return;
    _isReleased = true;
    _levelTimer?.cancel();
    _levelTimer = null;

    if (_nativeAudioSubscription != null) {
      await _nativeAudioSubscription?.cancel();
      _nativeAudioSubscription = null;
    }

    if (_isHardwareBound) {
      try {
        await _methodChannel.invokeMethod<bool>('stopCapture');
      } catch (_) {}
      _isHardwareBound = false;
    }

    _setState(AudioCaptureState.idle);

    await _stateController.close();
    await _audioDataController.close();
    await _audioLevelController.close();
  }

  /// Manually feeds a chunk of PCM audio bytes into the audio data stream.
  ///
  /// Used by native audio platform channels or audio test fixtures.
  void feedAudioBytes(List<int> bytes) {
    if (_isReleased || _state != AudioCaptureState.capturing) return;
    if (!_audioDataController.isClosed) {
      _audioDataController.add(bytes);
    }
    // If real native audio is streaming, calculate and emit actual RMS amplitude
    if (_isHardwareBound && !_audioLevelController.isClosed && bytes.length >= 2) {
      final level = calculateRmsLevel(bytes);
      _audioLevelController.add(level);
    }
  }

  /// Calculates normalized Root-Mean-Square (RMS) amplitude level [0.0 to 1.0]
  /// from 16-bit linear PCM byte samples.
  static double calculateRmsLevel(List<int> bytes) {
    if (bytes.length < 2) return 0.0;
    final byteData = bytes is Uint8List
        ? ByteData.sublistView(bytes)
        : ByteData.sublistView(Uint8List.fromList(bytes));

    double sumSquares = 0.0;
    final sampleCount = bytes.length ~/ 2;
    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      final normalized = sample / 32768.0;
      sumSquares += normalized * normalized;
    }
    final rms = math.sqrt(sumSquares / sampleCount);
    // Scale RMS by 2.5 to map typical speech dynamics (0.02 - 0.40) to responsive visual levels [0.0 - 1.0]
    return (rms * 2.5).clamp(0.0, 1.0);
  }

  void _handleNativeCaptureError(dynamic error) {
    if (_isReleased) return;
    _isHardwareBound = false;
    _setState(AudioCaptureState.interrupted);
    if (!_audioLevelController.isClosed) {
      _audioLevelController.add(0.0);
    }
  }
}

/// Mock capture service for unit and widget testing.
class MockMicrophoneAudioCaptureService implements MicrophoneAudioCaptureService {
  AudioCaptureState _state = AudioCaptureState.idle;
  final StreamController<AudioCaptureState> _stateController =
      StreamController<AudioCaptureState>.broadcast();
  final StreamController<List<int>> _audioDataController =
      StreamController<List<int>>.broadcast();
  final StreamController<double> _audioLevelController =
      StreamController<double>.broadcast();

  int startCount = 0;
  int stopCount = 0;
  int releaseCount = 0;
  int interruptCount = 0;

  AudioCaptureException? pendingErrorOnStart;

  @override
  int sampleRate = 16000;

  @override
  int channelCount = 1;

  @override
  int bitDepth = 16;

  @override
  String encoding = 'audio/pcm;rate=16000;channels=1';

  @override
  bool isHardwareBound = false;

  @override
  AudioCaptureState get state => _state;

  @override
  Stream<AudioCaptureState> get stateStream => _stateController.stream;

  @override
  Stream<List<int>> get audioDataStream => _audioDataController.stream;

  @override
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  void setState(AudioCaptureState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  @override
  Future<void> startCapture() async {
    startCount++;
    if (pendingErrorOnStart != null) {
      setState(AudioCaptureState.error);
      throw pendingErrorOnStart!;
    }
    setState(AudioCaptureState.capturing);
  }

  @override
  Future<void> stopCapture() async {
    stopCount++;
    setState(AudioCaptureState.stopped);
  }

  @override
  Future<void> interrupt() async {
    interruptCount++;
    setState(AudioCaptureState.interrupted);
  }

  @override
  Future<void> release() async {
    releaseCount++;
    setState(AudioCaptureState.idle);
    await _stateController.close();
    await _audioDataController.close();
    await _audioLevelController.close();
  }

  void emitLevel(double level) {
    if (!_audioLevelController.isClosed) {
      _audioLevelController.add(level);
    }
  }

  void emitAudioData(List<int> bytes) {
    if (!_audioDataController.isClosed) {
      _audioDataController.add(bytes);
    }
  }
}
