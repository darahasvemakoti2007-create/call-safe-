import 'package:guard_call/features/demo/demo_scenario.dart';
import 'package:guard_call/features/detection/audio_input.dart';
import 'package:guard_call/features/detection/speech_to_text_service.dart';

/// Deterministic mock implementation of [SpeechToTextService].
///
/// **Important Notice:**
/// This is a deterministic mock implementation used for offline demonstrations and testing.
/// It works entirely in-memory, does not perform network activity, does not access device
/// microphone hardware, and does not store raw audio data.
class MockSpeechToTextService implements SpeechToTextService {
  const MockSpeechToTextService();

  @override
  Future<List<ConversationLine>> transcribeAudio(AudioInput input) async {
    // 1. Validate audio data availability
    if (!input.hasAudioData) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.emptyAudio,
        'AudioInput contains no audio data or has zero duration.',
      );
    }

    // 2. Validate supported source types for this mock
    if (input.sourceType == AudioSourceType.microphone) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.unsupportedAudioSource,
        'Real-time microphone input is not supported in MockSpeechToTextService. '
        'Use mockScenario for offline simulation.',
      );
    }

    // 3. Validate simulated dialogue lines
    final lines = input.simulatedLines;
    if (lines == null || lines.isEmpty) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.emptyAudio,
        'Transcription produced no conversation lines from input.',
      );
    }

    // Return unmodifiable copy of the transcribed dialogue turns
    return List<ConversationLine>.unmodifiable(lines);
  }

  @override
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
          'Mock transcription error: $e',
        ),
      );
    }
  }
}
