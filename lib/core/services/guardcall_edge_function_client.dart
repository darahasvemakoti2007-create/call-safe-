import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../features/demo/demo_scenario.dart';
import '../../features/detection/audio_input.dart';
import '../../features/detection/detection_exception.dart';
import '../../features/detection/remote_ai_scam_detection_engine.dart';
import '../../features/detection/remote_speech_to_text_service.dart';
import '../../features/detection/risk_analysis.dart';
import '../config/app_config.dart';
import 'ai_http_client.dart';
import 'supabase_service.dart';

/// Secure client for invoking GuardCall Supabase Edge Functions.
///
/// In production architecture, mobile clients communicate exclusively with
/// authenticated Edge Function proxies rather than calling third-party AI APIs
/// directly. This keeps provider API secrets (OpenAI, Gemini) strictly server-side.
class GuardCallEdgeFunctionClient {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final AIHttpClient httpClient;
  final Duration timeout;
  final String? Function()? authTokenProvider;

  GuardCallEdgeFunctionClient({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    AIHttpClient? httpClient,
    this.timeout = const Duration(seconds: 15),
    this.authTokenProvider,
  }) : httpClient = httpClient ?? const DefaultAIHttpClient();

  /// Creates a client derived from [AppConfig] and the active [SupabaseService] session.
  factory GuardCallEdgeFunctionClient.fromConfig({
    AppConfig? config,
    AIHttpClient? httpClient,
    Duration timeout = const Duration(seconds: 15),
    String? Function()? authTokenProvider,
  }) {
    final cfg = config ?? AppConfig.current;
    return GuardCallEdgeFunctionClient(
      supabaseUrl: cfg.supabaseUrl,
      supabaseAnonKey: cfg.supabaseAnonKey,
      httpClient: httpClient,
      timeout: timeout,
      authTokenProvider: authTokenProvider ??
          () => SupabaseService.instance.client?.auth.currentSession?.accessToken,
    );
  }

  /// URL for the conversation analysis Edge Function.
  Uri get aiEndpoint => Uri.parse('$supabaseUrl/functions/v1/guardcall-ai-analyze');

  /// URL for the speech-to-text Edge Function.
  Uri get sttEndpoint => Uri.parse('$supabaseUrl/functions/v1/guardcall-stt');

  /// Invokes the `guardcall-ai-analyze` Edge Function to inspect conversation dialogue.
  Future<RiskAnalysis> analyzeConversation(List<ConversationLine> conversation) async {
    if (conversation.isEmpty) {
      return RiskAnalysis.safe(explanations: ['No conversation lines to analyze.']);
    }

    // 1. Authenticate user session
    final token = authTokenProvider?.call();
    if (token == null || token.trim().isEmpty) {
      throw const DetectionException(
        DetectionErrorType.unauthorized,
        'Authentication required. You must be signed in to analyze conversations via Edge Function.',
      );
    }

    // 2. Validate URL configuration
    if (supabaseUrl.isEmpty || !supabaseUrl.startsWith('http')) {
      throw const DetectionException(
        DetectionErrorType.invalidConfiguration,
        'Supabase URL is not configured.',
      );
    }

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'apikey': supabaseAnonKey,
      };

      final body = jsonEncode({
        'conversation': conversation.map((line) {
          final speakerStr = line.speaker == Speaker.caller ? 'caller' : 'user';
          return {
            'speaker': speakerStr,
            'text': line.text,
          };
        }).toList(),
      });

      final responseText = await httpClient
          .post(url: aiEndpoint, headers: headers, body: body, timeout: timeout)
          .timeout(timeout);

      return RemoteAIScamDetectionEngine.parseStructuredOutput(responseText);
    } on TimeoutException {
      throw DetectionException(
        DetectionErrorType.timeout,
        'Edge Function AI analysis timed out after ${timeout.inSeconds} seconds.',
      );
    } on SocketException catch (e) {
      throw DetectionException(
        DetectionErrorType.networkFailure,
        'Network error connecting to Edge Function: ${e.message}',
      );
    } on HttpException catch (e) {
      if (e.message.contains('401')) {
        throw const DetectionException(
          DetectionErrorType.unauthorized,
          'Unauthorized: Edge Function rejected authentication token.',
        );
      }
      if (e.message.contains('503') || e.message.toLowerCase().contains('credential')) {
        throw DetectionException(
          DetectionErrorType.missingApiKey,
          'Edge Function AI credentials unconfigured: ${e.message}',
        );
      }
      throw DetectionException(
        DetectionErrorType.networkFailure,
        'Edge Function HTTP error: ${e.message}',
      );
    } on DetectionException {
      rethrow;
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('401')) {
        throw const DetectionException(
          DetectionErrorType.unauthorized,
          'Unauthorized: Edge Function rejected authentication token.',
        );
      }
      if (str.contains('503') || str.contains('credential')) {
        throw DetectionException(
          DetectionErrorType.missingApiKey,
          'Edge Function AI credentials unconfigured: $e',
        );
      }
      throw DetectionException(
        DetectionErrorType.providerUnavailable,
        'Failed to execute Edge Function AI analysis: $e',
      );
    }
  }

  /// Invokes the `guardcall-stt` Edge Function to transcribe explicitly provided audio.
  Future<List<ConversationLine>> transcribeAudio(AudioInput input) async {
    if (!input.hasAudioData) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.emptyAudio,
        'Audio input contains no audio frames or empty waveform data.',
      );
    }

    if (input.sourceType == AudioSourceType.stream) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.unsupportedAudioSource,
        'Live streaming audio buffers are not supported by the Edge Function STT proxy.',
      );
    }

    // Deterministic mock scenario pass-through
    if (input.sourceType == AudioSourceType.mockScenario && input.simulatedLines != null) {
      return input.simulatedLines!;
    }

    final token = authTokenProvider?.call();
    if (token == null || token.trim().isEmpty) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.unavailableAudio,
        'Authentication required. You must be signed in to transcribe audio via Edge Function.',
      );
    }

    if (supabaseUrl.isEmpty || !supabaseUrl.startsWith('http')) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.unavailableAudio,
        'Supabase URL is not configured.',
      );
    }

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'apikey': supabaseAnonKey,
      };

      // Encode audio bytes to base64 if present, or simulate payload
      final base64Audio = input.audioBytes != null
          ? base64Encode(input.audioBytes!)
          : base64Encode(utf8.encode('DUMMY_AUDIO_BYTES_TEST'));

      final body = jsonEncode({
        'audio_base64': base64Audio,
        'content_type': 'audio/wav',
        'label': input.label,
        'duration_seconds': input.duration?.inSeconds ?? 0,
      });

      final responseText = await httpClient
          .post(url: sttEndpoint, headers: headers, body: body, timeout: timeout)
          .timeout(timeout);

      return RemoteSpeechToTextService.parseTranscriptResponse(responseText);
    } on TimeoutException {
      throw SpeechToTextException(
        SpeechToTextErrorType.transcriptionTimeout,
        'Edge Function speech-to-text timed out after ${timeout.inSeconds} seconds.',
      );
    } on SocketException catch (e) {
      throw SpeechToTextException(
        SpeechToTextErrorType.transcriptionFailure,
        'Network error connecting to Edge Function STT: ${e.message}',
      );
    } on HttpException catch (e) {
      throw SpeechToTextException(
        SpeechToTextErrorType.transcriptionFailure,
        'Edge Function STT HTTP error: ${e.message}',
      );
    } on SpeechToTextException {
      rethrow;
    } catch (e) {
      throw SpeechToTextException(
        SpeechToTextErrorType.transcriptionFailure,
        'Failed to execute Edge Function speech-to-text: $e',
      );
    }
  }
}
