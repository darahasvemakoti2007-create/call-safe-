import 'dart:async';
import '../../core/config/app_config.dart';
import 'audio_input.dart';
import 'detection_provider_factory.dart';
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

  /// Stream of recognized interim and final speech segments.
  Stream<LiveSpeechSegment> get segmentStream;

  /// Starts listening for speech and transcribing in real time.
  Future<void> startListening({
    required void Function(LiveSpeechSegment segment) onSegment,
    required void Function(String error) onError,
  });

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

  DefaultLiveSpeechRecognitionService({
    SpeechToTextService? sttService,
  }) : _sttService = sttService ?? STTProviderFactory.getSpeechToTextService();

  @override
  bool get isListening => _isListening;

  @override
  Stream<LiveSpeechSegment> get segmentStream => _segmentController.stream;

  @override
  Future<void> startListening({
    required void Function(LiveSpeechSegment segment) onSegment,
    required void Function(String error) onError,
  }) async {
    if (_isDisposed) return;
    _isListening = true;

    final config = AppConfig.current;
    final isConfigured = config.isEdgeFunctionSttConfigured || config.isCloudSttConfigured;

    if (!isConfigured && config.sttBackend != 'mock') {
      onError(
        'Real-time Speech-to-Text requires configuring the Supabase Edge Function STT proxy '
        'or specifying a speech recognition provider in .env. Setup instructions are documented '
        'in DEVELOPMENT_GUIDE.md.',
      );
    }
  }

  /// Sends a raw audio buffer to the underlying [SpeechToTextService] for batch transcription.
  Future<void> processAudioBytes(List<int> bytes) async {
    if (!_isListening || _isDisposed) return;
    try {
      final input = AudioInput.bytes(bytes, label: 'Microphone Stream');
      final lines = await _sttService.transcribeAudio(input);
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
      }
    } catch (_) {
      // Ignored for empty audio or offline notice
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

  bool get isDisposed => _isDisposed;

  int startCount = 0;
  int stopCount = 0;
  int disposeCount = 0;

  void Function(LiveSpeechSegment)? _onSegmentCallback;
  void Function(String)? _onErrorCallback;

  String? pendingErrorOnStart;

  @override
  bool get isListening => _isListening;

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
      onError(pendingErrorOnStart!);
      return;
    }

    _isListening = true;
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
    if (!_segmentController.isClosed) {
      _segmentController.add(segment);
    }
    _onSegmentCallback?.call(segment);
  }

  /// Programmatically emits an error.
  void emitError(String error) {
    _onErrorCallback?.call(error);
  }
}
