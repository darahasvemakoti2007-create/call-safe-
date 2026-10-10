import 'dart:async';
import '../../core/config/app_config.dart';
import 'audio_input.dart';
import 'detection_provider_factory.dart';
import 'edge_function_speech_to_text_service.dart';
import 'mock_speech_to_text_service.dart';
import 'remote_speech_to_text_service.dart';
import 'speech_to_text_service.dart';

/// Represents a recognized spoken segment in real time.
class LiveSpeechSegment {
  /// The transcribed text string.
  final String text;

  /// Whether this segment is a final recognized utterance or an interim hypothesis.
  final bool isFinal;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Timestamp when the segment was recognized.
  final DateTime timestamp;

  /// Optional speaker label.
  final String speaker;

  const LiveSpeechSegment({
    required this.text,
    required this.isFinal,
    this.confidence = 1.0,
    required this.timestamp,
    this.speaker = 'Caller',
  });

  LiveSpeechSegment copyWith({
    String? text,
    bool? isFinal,
    double? confidence,
    DateTime? timestamp,
    String? speaker,
  }) {
    return LiveSpeechSegment(
      text: text ?? this.text,
      isFinal: isFinal ?? this.isFinal,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      speaker: speaker ?? this.speaker,
    );
  }

  @override
  String toString() =>
      'LiveSpeechSegment(text: "$text", isFinal: $isFinal, confidence: ${confidence.toStringAsFixed(2)})';
}

/// Abstract contract for live, streaming speech recognition.
abstract class LiveSpeechRecognitionService {
  /// Whether the service is currently actively listening.
  bool get isListening;

  /// Whether a live ASR backend is configured and ready.
  bool get isConfigured;

  /// The name/tier of the active ASR provider.
  String get providerName;

  /// Timestamp of the last successful speech transcription.
  DateTime? get lastTranscriptionTime;

  /// Last error message encountered during recognition, if any.
  String? get lastError;

  /// Stream of recognized interim and final speech segments.
  Stream<LiveSpeechSegment> get segmentStream;

  /// Starts listening for speech and transcribing in real time.
  Future<void> startListening({
    required void Function(LiveSpeechSegment segment) onSegment,
    required void Function(String error) onError,
  });

  /// Feeds a chunk of PCM audio bytes into the recognition engine.
  Future<void> processAudioBytes(List<int> bytes);

  /// Stops speech recognition.
  Future<void> stopListening();

  /// Releases resources.
  Future<void> dispose();
}

/// Default implementation routing live recognition through GuardCall STT services.
///
/// When an external STT service (Supabase Edge Function or cloud STT) is configured,
/// audio is transcribed through the respective provider.
///
/// When unconfigured, rather than fabricating fake transcription, it reports a clear
/// configuration notice explaining how to configure live cloud STT.
class DefaultLiveSpeechRecognitionService implements LiveSpeechRecognitionService {
  final SpeechToTextService _sttService;
  final StreamController<LiveSpeechSegment> _segmentController =
      StreamController<LiveSpeechSegment>.broadcast();

  bool _isListening = false;
  bool _isDisposed = false;
  DateTime? _lastTranscriptionTime;
  String? _lastError;
  void Function(String error)? _onError;
  void Function(LiveSpeechSegment segment)? _onSegment;

  DefaultLiveSpeechRecognitionService({
    SpeechToTextService? sttService,
  }) : _sttService = sttService ?? STTProviderFactory.getSpeechToTextService();

  @override
  bool get isListening => _isListening;

  @override
  bool get isConfigured {
    final config = AppConfig.current;
    if (_sttService is! MockSpeechToTextService) {
      return true;
    }
    return config.isEdgeFunctionSttConfigured || config.isCloudSttConfigured;
  }

  @override
  String get providerName {
    if (_sttService is EdgeFunctionSpeechToTextService) {
      return 'Supabase Edge Function (guardcall-stt)';
    } else if (_sttService is RemoteSpeechToTextService) {
      return 'Direct Cloud STT (OpenAI/Whisper)';
    } else if (_sttService is MockSpeechToTextService) {
      final config = AppConfig.current;
      if (config.isEdgeFunctionSttConfigured) {
        return 'Supabase Edge Function (Configured)';
      } else if (config.isCloudSttConfigured) {
        return 'Direct Cloud STT (Configured)';
      }
      return 'Offline / Unconfigured';
    }
    return 'Custom Provider (${_sttService.runtimeType})';
  }

  @override
  DateTime? get lastTranscriptionTime => _lastTranscriptionTime;

  @override
  String? get lastError => _lastError;

  @override
  Stream<LiveSpeechSegment> get segmentStream => _segmentController.stream;

  @override
  Future<void> startListening({
    required void Function(LiveSpeechSegment segment) onSegment,
    required void Function(String error) onError,
  }) async {
    if (_isDisposed) return;
    _isListening = true;
    _onSegment = onSegment;
    _onError = onError;
    _lastError = null;

    final config = AppConfig.current;
    final configured = isConfigured;

    if (!configured && config.sttBackend != 'mock') {
      const msg = 'Real-time Speech-to-Text requires configuring the Supabase Edge Function STT proxy '
          'or specifying a speech recognition provider in .env. Setup instructions are documented '
          'in DEVELOPMENT_GUIDE.md.';
      _lastError = msg;
      onError(msg);
    }
  }

  /// Sends a raw audio buffer to the underlying [SpeechToTextService] for batch transcription.
  @override
  Future<void> processAudioBytes(List<int> bytes) async {
    if (!_isListening || _isDisposed) return;
    if (bytes.isEmpty) {
      _lastError = 'Audio chunk is empty.';
      throw const SpeechToTextException(
        SpeechToTextErrorType.emptyAudio,
        'Cannot transcribe empty audio buffer.',
      );
    }
    try {
      final input = AudioInput.bytes(bytes, label: 'Microphone Stream');
      final lines = await _sttService.transcribeAudio(input);
      _lastTranscriptionTime = DateTime.now();
      _lastError = null;
      for (final line in lines) {
        final segment = LiveSpeechSegment(
          text: line.text,
          isFinal: true,
          timestamp: DateTime.now(),
          speaker: line.speaker.displayName,
        );
        if (!_segmentController.isClosed) {
          _segmentController.add(segment);
        }
        _onSegment?.call(segment);
      }
    } catch (e) {
      _lastError = e.toString();
      _onError?.call(_lastError!);
      rethrow;
    }
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _isListening = false;
    await _segmentController.close();
  }
}

/// Mock live speech recognition service for unit and widget testing.
///
/// Enables programmatic feeding of interim and final speech segments
/// without physical microphone hardware.
class MockLiveSpeechRecognitionService implements LiveSpeechRecognitionService {
  final StreamController<LiveSpeechSegment> _segmentController =
      StreamController<LiveSpeechSegment>.broadcast();

  bool _isListening = false;
  bool _isDisposed = false;
  bool configured = false;
  String customProviderName = 'Mock ASR';
  DateTime? _lastTranscriptionTime;
  String? _lastError;

  bool get isDisposed => _isDisposed;

  int startCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  int processAudioCount = 0;

  void Function(LiveSpeechSegment)? _onSegmentCallback;
  void Function(String)? _onErrorCallback;

  String? pendingErrorOnStart;

  MockLiveSpeechRecognitionService({
    bool isConfigured = false,
    String providerName = 'Mock ASR',
  })  : configured = isConfigured,
        customProviderName = providerName;

  @override
  bool get isListening => _isListening;

  @override
  bool get isConfigured => configured;

  @override
  String get providerName => customProviderName;

  @override
  DateTime? get lastTranscriptionTime => _lastTranscriptionTime;

  @override
  String? get lastError => _lastError;

  @override
  Stream<LiveSpeechSegment> get segmentStream => _segmentController.stream;

  @override
  Future<void> startListening({
    required void Function(LiveSpeechSegment segment) onSegment,
    required void Function(String error) onError,
  }) async {
    startCount++;
    _onSegmentCallback = onSegment;
    _onErrorCallback = onError;

    if (pendingErrorOnStart != null) {
      _lastError = pendingErrorOnStart;
      onError(pendingErrorOnStart!);
      return;
    }

    _isListening = true;
  }

  @override
  Future<void> processAudioBytes(List<int> bytes) async {
    processAudioCount++;
    if (bytes.isEmpty) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.emptyAudio,
        'Cannot transcribe empty audio buffer.',
      );
    }
    _lastTranscriptionTime = DateTime.now();
  }

  @override
  Future<void> stopListening() async {
    stopCount++;
    _isListening = false;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _isDisposed = true;
    _isListening = false;
    await _segmentController.close();
  }

  /// Programmatically emits a speech segment to simulate recognized speech.
  void emitSegment(LiveSpeechSegment segment) {
    _lastTranscriptionTime = DateTime.now();
    if (!_segmentController.isClosed) {
      _segmentController.add(segment);
    }
    _onSegmentCallback?.call(segment);
  }

  /// Programmatically emits an error.
  void emitError(String error) {
    _lastError = error;
    _onErrorCallback?.call(error);
  }
}
