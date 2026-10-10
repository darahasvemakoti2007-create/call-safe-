import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../core/services/ai_http_client.dart';
import '../demo/demo_scenario.dart';
import 'audio_input.dart';
import 'speech_to_text_service.dart';

/// LOCAL DEVELOPMENT ONLY — Direct external Speech-to-Text client.
///
/// In production architecture, mobile applications must NOT embed provider API
/// keys. All production speech-to-text requests route through the authenticated
/// [GuardCallEdgeFunctionClient] and Supabase Edge Functions.
///
/// This direct client is maintained strictly for local developer experimentation,
/// unit test fixtures, and mock verification.
///
/// CRITICAL PRIVACY & PLATFORM LIMITATIONS:
/// 1. Remote Processing Boundary: Passing audio to this service sends audio data
///    outside the local device to the configured remote endpoint.
/// 2. Zero Raw Audio Storage: Audio buffers are never saved to disk or Supabase.
/// 3. No Cellular Call Wiretapping: This service does NOT intercept real cellular
///    call audio. Standard Android does not expose cellular voice call audio streams
///    to third-party user apps. Remote STT operates only on explicitly supplied audio
///    sources (prerecorded files, controlled mic input, test fixtures).
class RemoteSpeechToTextService extends SpeechToTextService {
  final String apiKey;
  final Uri endpoint;
  final Duration timeout;
  final AIHttpClient httpClient;

  RemoteSpeechToTextService({
    required this.apiKey,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 15),
    AIHttpClient? httpClient,
  })  : endpoint = endpoint ?? Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
        httpClient = httpClient ?? const DefaultAIHttpClient();

  @override
  Future<List<ConversationLine>> transcribeAudio(AudioInput input) async {
    // 1. Validate audio data presence
    if (!input.hasAudioData || (input.duration != null && input.duration == Duration.zero)) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.emptyAudio,
        'Audio input contains no audio frames or empty waveform data.',
      );
    }

    // 2. Validate API credentials
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty || cleanKey.contains('your-') || cleanKey.contains('placeholder')) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.unavailableAudio,
        'Remote speech recognition credentials are not configured.',
      );
    }

    // 3. Validate supported audio source types
    if (input.sourceType == AudioSourceType.stream) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.unsupportedAudioSource,
        'Live streaming audio buffers are not supported by this remote provider.',
      );
    }

    // 4. If simulatedLines are present (test/mock scenario), handle deterministically
    if (input.sourceType == AudioSourceType.mockScenario && input.simulatedLines != null) {
      return input.simulatedLines!;
    }

    // 5. Remote API call execution
    try {
      final headers = {
        'Authorization': 'Bearer $cleanKey',
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'model': 'whisper-1',
        'label': input.label,
        'duration_seconds': input.duration?.inSeconds ?? 0,
      });

      final responseBody = await httpClient
          .post(url: endpoint, headers: headers, body: body, timeout: timeout)
          .timeout(timeout);

      return parseTranscriptResponse(responseBody);
    } on TimeoutException {
      throw SpeechToTextException(
        SpeechToTextErrorType.transcriptionTimeout,
        'Remote speech-to-text service timed out after ${timeout.inSeconds} seconds.',
      );
    } on SocketException catch (e) {
      throw SpeechToTextException(
        SpeechToTextErrorType.transcriptionFailure,
        'Network failure connecting to remote speech recognition provider: ${e.message}',
      );
    } on HttpException catch (e) {
      throw SpeechToTextException(
        SpeechToTextErrorType.transcriptionFailure,
        'Speech recognition provider HTTP error: ${e.message}',
      );
    } on SpeechToTextException {
      rethrow;
    } catch (e) {
      throw SpeechToTextException(
        SpeechToTextErrorType.transcriptionFailure,
        'Failed to transcribe audio via remote provider: $e',
      );
    }
  }

  /// Parses and validates the structured transcription response.
  static List<ConversationLine> parseTranscriptResponse(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        // OpenAI Whisper JSON format: {"text": "..."}
        if (decoded.containsKey('text') && decoded['text'] is String) {
          final text = decoded['text'] as String;
          if (text.trim().isEmpty) {
            return [];
          }
          // Segment transcript by sentences or punctuation
          final segments = text
              .split(RegExp(r'(?<=[.?!])\s+'))
              .where((s) => s.trim().isNotEmpty)
              .toList();

          return segments.map((seg) {
            return ConversationLine(
              speaker: Speaker.caller,
              text: seg.trim(),
            );
          }).toList();
        }

        // Structured multi-line format: {"lines": [{"speaker": "caller", "text": "..."}]}
        if (decoded.containsKey('lines') && decoded['lines'] is List) {
          final rawLines = decoded['lines'] as List;
          return rawLines.map((item) {
            if (item is Map<String, dynamic>) {
              final speakerStr = (item['speaker'] as String? ?? 'caller').toLowerCase();
              final speaker = speakerStr == 'user' ? Speaker.user : Speaker.caller;
              final text = item['text'] as String? ?? '';
              return ConversationLine(speaker: speaker, text: text);
            }
            return ConversationLine(speaker: Speaker.caller, text: item.toString());
          }).toList();
        }
      }
      throw const FormatException('Missing valid "text" or "lines" array in response.');
    } catch (e) {
      throw SpeechToTextException(
        SpeechToTextErrorType.transcriptionFailure,
        'Invalid or unparseable response from speech recognition provider: $e',
      );
    }
  }
}
