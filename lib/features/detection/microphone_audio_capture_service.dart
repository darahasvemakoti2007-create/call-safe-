import 'dart:async';

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
/// microphone lifecycle and streaming.
class DefaultMicrophoneAudioCaptureService implements MicrophoneAudioCaptureService {
  AudioCaptureState _state = AudioCaptureState.idle;
  final StreamController<AudioCaptureState> _stateController =
      StreamController<AudioCaptureState>.broadcast();
  final StreamController<List<int>> _audioDataController =
      StreamController<List<int>>.broadcast();
  final StreamController<double> _audioLevelController =
      StreamController<double>.broadcast();

  Timer? _levelTimer;
  bool _isReleased = false;

  @override
  int get sampleRate => 16000;

  @override
  int get channelCount => 1;

  @override
  int get bitDepth => 16;

  @override
  String get encoding => 'audio/pcm;rate=16000;channels=1';

  @override
  bool get isHardwareBound => false;

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
    // Simulate brief hardware buffer initialization
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_isReleased) return;

    _setState(AudioCaptureState.capturing);

    // Emit gentle pulse amplitude updates to drive UI visualizer
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
    if (!_audioLevelController.isClosed) {
      _audioLevelController.add(0.0);
    }
    _setState(AudioCaptureState.stopped);
  }

  @override
  Future<void> interrupt() async {
    _levelTimer?.cancel();
    _levelTimer = null;
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
