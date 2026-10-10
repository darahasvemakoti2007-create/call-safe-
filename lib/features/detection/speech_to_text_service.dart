import 'package:guard_call/features/demo/demo_scenario.dart';
import 'package:guard_call/features/detection/audio_input.dart';

/// Result envelope returned by safe speech-to-text operations.
class SpeechTranscriptionResult {
  /// Whether the transcription completed successfully without errors.
  final bool isSuccess;

  /// Transcribed conversation lines when [isSuccess] is true.
  final List<ConversationLine> lines;

  /// Error details when [isSuccess] is false.
  final SpeechToTextException? error;

  const SpeechTranscriptionResult.success(this.lines)
      : isSuccess = true,
        error = null;

  const SpeechTranscriptionResult.failure(SpeechToTextException this.error)
      : isSuccess = false,
        lines = const [];
}

/// Abstract contract for converting incoming audio streams or recordings
/// into structured [ConversationLine] dialogue turns.
///
/// UI and detection layers depend exclusively on this interface, remaining
/// fully decoupled from specific on-device Whisper engines, platform audio
/// drivers, or cloud services.
abstract class SpeechToTextService {
  /// Transcribes the given [AudioInput] into a chronological list of [ConversationLine] objects.
  ///
  /// Throws a [SpeechToTextException] if audio is missing, empty, or fails processing.
  Future<List<ConversationLine>> transcribeAudio(AudioInput input);

  /// Safe convenience wrapper that catches [SpeechToTextException] and returns
  /// a [SpeechTranscriptionResult].
  Future<SpeechTranscriptionResult> transcribeSafe(AudioInput input) async {
    try {
      final lines = await transcribeAudio(input);
      return SpeechTranscriptionResult.success(lines);
    } on SpeechToTextException catch (e) {
      return SpeechTranscriptionResult.failure(e);
    } catch (e) {
      return SpeechTranscriptionResult.failure(
        SpeechToTextException(
          SpeechToTextErrorType.transcriptionFailure,
          'Unexpected transcription error: $e',
        ),
      );
    }
  }
}
