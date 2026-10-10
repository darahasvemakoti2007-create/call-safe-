import 'package:guard_call/features/demo/demo_scenario.dart';

/// Represents the origin or mechanism of an audio input stream or recording.
enum AudioSourceType {
  /// Predefined scenario used for testing and deterministic offline demos.
  mockScenario,

  /// Prerecorded local audio file (future extension).
  prerecordedFile,

  /// Real-time device microphone stream (future extension, requires permissions).
  microphone,

  /// Live streaming audio buffer (future extension).
  stream,
}

/// Typed categories for audio pipeline and speech recognition errors.
enum SpeechToTextErrorType {
  /// Audio source or hardware buffer is unavailable or cannot be accessed.
  unavailableAudio,

  /// Provided audio input contains no audio frames or empty waveform data.
  emptyAudio,

  /// Speech recognition failed to decipher phonetic words or transcript.
  transcriptionFailure,

  /// Transcription service or local model exceeded processing timeout.
  transcriptionTimeout,

  /// Specified audio format or source type is not supported by the provider.
  unsupportedAudioSource,
}

/// Typed exception representing an error during audio transcription.
class SpeechToTextException implements Exception {
  final SpeechToTextErrorType errorType;
  final String message;

  const SpeechToTextException(this.errorType, this.message);

  /// Convenient alias for [errorType].
  SpeechToTextErrorType get type => errorType;

  @override
  String toString() => 'SpeechToTextException(${errorType.name}): $message';
}

/// Lightweight architectural abstraction representing an audio input for GuardCall.
///
/// In this prototype step, this model carries metadata, optional byte buffers,
/// and simulated payload for testing and edge function execution.
class AudioInput {
  /// The origin type of this audio input.
  final AudioSourceType sourceType;

  /// Identifier or human-readable label for this audio stream or track.
  final String label;

  /// Duration of audio if known ahead of time.
  final Duration? duration;

  /// Whether valid audio payload data is present and available.
  final bool hasAudioData;

  /// Associated conversation scenario or turns for deterministic mock transcription.
  final List<ConversationLine>? simulatedLines;

  /// Raw audio byte buffer, if available.
  final List<int>? audioBytes;

  const AudioInput({
    required this.sourceType,
    required this.label,
    this.duration,
    this.hasAudioData = true,
    this.simulatedLines,
    this.audioBytes,
  });

  /// Factory for creating a mock audio input from a [DemoScenario].
  factory AudioInput.fromScenario(DemoScenario scenario) {
    return AudioInput(
      sourceType: AudioSourceType.mockScenario,
      label: scenario.title,
      duration: Duration(seconds: scenario.conversationLines.length * 3),
      hasAudioData: scenario.conversationLines.isNotEmpty,
      simulatedLines: scenario.conversationLines,
    );
  }

  /// Factory for creating an audio input from raw audio bytes.
  factory AudioInput.bytes(
    List<int> bytes, {
    String label = 'Audio Bytes Input',
    Duration? duration,
  }) {
    return AudioInput(
      sourceType: AudioSourceType.prerecordedFile,
      label: label,
      duration: duration ?? const Duration(seconds: 5),
      hasAudioData: bytes.isNotEmpty,
      audioBytes: bytes,
    );
  }

  /// Factory for creating a stream audio input.
  factory AudioInput.stream(
    Stream<List<int>>? stream, {
    String label = 'Live Stream Input',
    Duration? duration,
  }) {
    return AudioInput(
      sourceType: AudioSourceType.stream,
      label: label,
      duration: duration,
      hasAudioData: stream != null,
    );
  }

  /// Factory for creating an empty or unrecorded audio input to test error paths.
  factory AudioInput.empty({String label = 'Empty Audio Input'}) {
    return AudioInput(
      sourceType: AudioSourceType.mockScenario,
      label: label,
      duration: Duration.zero,
      hasAudioData: false,
      simulatedLines: const [],
    );
  }
}
