import '../../core/config/app_config.dart';
import '../../core/services/ai_http_client.dart';
import '../../core/services/guardcall_edge_function_client.dart';
import 'edge_function_scam_detection_engine.dart';
import 'edge_function_speech_to_text_service.dart';
import 'mock_scam_detection_engine.dart';
import 'mock_speech_to_text_service.dart';
import 'remote_ai_scam_detection_engine.dart';
import 'remote_speech_to_text_service.dart';
import 'scam_detection_engine.dart';
import 'speech_to_text_service.dart';

/// Factory resolving the active [ScamDetectionEngine] based on environment configuration.
///
/// Hierarchy:
/// 1. Edge Function AI proxy (Production target: secrets stay server-side).
/// 2. Direct AI Provider (Local Development Only: requires local API key).
/// 3. Mock Scam Detection Engine (Default: safe offline demonstration mode).
class DetectionProviderFactory {
  /// Resolves the appropriate detection engine instance based on [AppConfig].
  ///
  /// Supported configurations:
  /// - `AI_BACKEND=mock` -> [MockScamDetectionEngine] (Default, offline-safe)
  /// - `AI_BACKEND=direct_dev` -> [RemoteAIScamDetectionEngine] (Local dev only)
  /// - `AI_BACKEND=edge_function` -> [EdgeFunctionScamDetectionEngine] (Production target)
  static ScamDetectionEngine getDetectionEngine({
    AppConfig? config,
    AIHttpClient? httpClient,
    bool enableFallback = true,
  }) {
    final cfg = config ?? AppConfig.current;

    // 1. Explicit mock backend (Default: safe offline demonstration mode)
    if (cfg.aiBackend == 'mock') {
      return const MockScamDetectionEngine();
    }

    // 2. Production Mode: Authenticated Supabase Edge Function AI Proxy
    if (cfg.aiBackend == 'edge_function' || cfg.isEdgeFunctionAiConfigured) {
      final edgeClient = GuardCallEdgeFunctionClient.fromConfig(
        config: cfg,
        httpClient: httpClient,
      );
      return EdgeFunctionScamDetectionEngine(
        edgeClient: edgeClient,
        enableFallback: enableFallback,
      );
    }

    // 3. Local Development Only: Direct OpenAI/Gemini REST client
    if (cfg.aiBackend == 'direct_dev' || cfg.isRemoteAiConfigured) {
      final key = cfg.aiProvider == 'openai' ? cfg.openaiApiKey : cfg.geminiApiKey;
      return RemoteAIScamDetectionEngine(
        provider: cfg.aiProvider,
        apiKey: key,
        httpClient: httpClient,
        enableFallback: enableFallback,
      );
    }

    // 4. Safe Offline Default
    return const MockScamDetectionEngine();
  }
}

/// Factory resolving the active [SpeechToTextService] based on environment configuration.
///
/// Hierarchy:
/// 1. `STT_BACKEND=mock` -> [MockSpeechToTextService] (Default, offline-safe)
/// 2. `STT_BACKEND=edge_function` -> [EdgeFunctionSpeechToTextService] (Production target)
/// 3. `STT_BACKEND=direct_dev` -> [RemoteSpeechToTextService] (Local dev only)
class STTProviderFactory {
  /// Resolves the appropriate speech-to-text service instance based on [AppConfig].
  static SpeechToTextService getSpeechToTextService({
    AppConfig? config,
    AIHttpClient? httpClient,
  }) {
    final cfg = config ?? AppConfig.current;

    // 1. Explicit mock backend (Default: safe offline demonstration mode)
    if (cfg.sttBackend == 'mock') {
      return const MockSpeechToTextService();
    }

    // 2. Production Mode: Authenticated Supabase Edge Function STT Proxy
    if (cfg.sttBackend == 'edge_function' || cfg.isEdgeFunctionSttConfigured) {
      final edgeClient = GuardCallEdgeFunctionClient.fromConfig(
        config: cfg,
        httpClient: httpClient,
      );
      return EdgeFunctionSpeechToTextService(edgeClient: edgeClient);
    }

    // 3. Local Development Only: Direct Remote STT client
    if (cfg.sttBackend == 'direct_dev' || cfg.isCloudSttConfigured) {
      return RemoteSpeechToTextService(
        apiKey: cfg.speechToTextApiKey,
        httpClient: httpClient,
      );
    }

    // 4. Safe Offline Default
    return const MockSpeechToTextService();
  }
}
