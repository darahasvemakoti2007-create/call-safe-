import 'package:guard_call/core/config/app_config.dart';
import 'package:guard_call/core/services/ai_http_client.dart';
import 'package:guard_call/features/demo/demo_scenario.dart';
import 'package:guard_call/features/detection/audio_input.dart';
import 'package:guard_call/features/detection/detection_provider_factory.dart';
import 'package:guard_call/features/detection/risk_analysis.dart';
import 'package:guard_call/features/detection/scam_detection_engine.dart';
import 'package:guard_call/features/detection/speech_to_text_service.dart';

import 'package:guard_call/features/detection/detection_exception.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/mock_speech_to_text_service.dart';

/// Coordinates the end-to-end processing pipeline:
///
/// ```
/// AudioInput
///     ↓
/// SpeechToTextService
///     ↓
/// List<ConversationLine>
///     ↓
/// ScamDetectionEngine
///     ↓
/// RiskAnalysis
/// ```
///
/// This coordinator is completely decoupled from UI widgets and Flutter lifecycle,
/// enabling unit testing, CLI execution, and seamless integration with future
/// on-device speech engines.
class ConversationPipeline {
  final SpeechToTextService speechService;
  final ScamDetectionEngine detectionEngine;

  const ConversationPipeline({
    required this.speechService,
    required this.detectionEngine,
  });

  /// Factory creating an offline deterministic mock pipeline without network dependencies.
  factory ConversationPipeline.mock() {
    return const ConversationPipeline(
      speechService: MockSpeechToTextService(),
      detectionEngine: MockScamDetectionEngine(),
    );
  }

  /// Factory creating a pipeline configured automatically via [DetectionProviderFactory]
  /// and [STTProviderFactory].
  factory ConversationPipeline.fromConfig({
    AppConfig? config,
    AIHttpClient? httpClient,
    bool enableFallback = true,
  }) {
    return ConversationPipeline(
      speechService: STTProviderFactory.getSpeechToTextService(
        config: config,
        httpClient: httpClient,
      ),
      detectionEngine: DetectionProviderFactory.getDetectionEngine(
        config: config,
        httpClient: httpClient,
        enableFallback: enableFallback,
      ),
    );
  }

  /// Processes an [AudioInput] source through speech-to-text transcription
  /// and subsequent heuristic or AI scam analysis, returning the final [RiskAnalysis].
  ///
  /// The pipeline enforces:
  /// 1. Audio input validation (has valid audio data).
  /// 2. Speech-to-text transcription via configured [SpeechToTextService].
  /// 3. Validation that the resulting transcript is not empty.
  /// 4. Threat analysis via configured [ScamDetectionEngine].
  /// 5. Preservation of typed errors ([SpeechToTextException], [DetectionException]).
  /// 6. Never fabricates AI results when the provider fails.
  ///
  /// Throws [SpeechToTextException] if audio is missing, empty, or transcription fails.
  /// Throws [DetectionException] if scam detection analysis fails.
  Future<RiskAnalysis> processAudio(AudioInput input) async {
    // 1. Audio input data validation
    if (!input.hasAudioData) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.emptyAudio,
        'AudioInput contains no audio frames or empty waveform data.',
      );
    }

    // 2. Audio input -> Speech-to-text conversion
    final lines = await speechService.transcribeAudio(input);

    // 3. Validate that the conversation transcript is not empty
    if (lines.isEmpty) {
      throw const SpeechToTextException(
        SpeechToTextErrorType.emptyAudio,
        'Transcription produced no conversation lines to analyze.',
      );
    }

    // 4. Transcribed dialogue lines -> Scam detection engine
    return detectionEngine.analyzeConversation(lines);
  }

  /// Safe pipeline execution that catches transcription or detection errors and
  /// returns a safe baseline [RiskAnalysis] with typed diagnostic explanations.
  Future<RiskAnalysis> processAudioSafe(AudioInput input) async {
    try {
      return await processAudio(input);
    } on SpeechToTextException catch (e) {
      return RiskAnalysis.safe(
        explanations: [
          'Audio processing bypassed: ${e.message}',
        ],
      );
    } on DetectionException catch (e) {
      return RiskAnalysis.safe(
        explanations: [
          'AI analysis unavailable: ${e.message}',
        ],
      );
    } catch (e) {
      return RiskAnalysis.safe(
        explanations: [
          'Audio/AI analysis error: $e',
        ],
      );
    }
  }

  /// Analyzes an existing sequence of [ConversationLine] dialogue turns directly,
  /// bypassing the speech-to-text layer (used by progressive demo playback).
  Future<RiskAnalysis> processConversation(List<ConversationLine> lines) async {
    if (lines.isEmpty) {
      throw const DetectionException(
        DetectionErrorType.invalidOutput,
        'Conversation lines cannot be empty for analysis.',
      );
    }
    return detectionEngine.analyzeConversation(lines);
  }
}

