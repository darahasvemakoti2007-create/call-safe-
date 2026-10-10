import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/core/config/app_config.dart';
import 'package:guard_call/core/services/ai_http_client.dart';
import 'package:guard_call/core/services/guardcall_edge_function_client.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/demo/demo_scenario.dart';
import 'package:guard_call/features/demo/demo_scenarios.dart';
import 'package:guard_call/features/demo/demo_session_controller.dart';
import 'package:guard_call/features/detection/audio_input.dart';
import 'package:guard_call/features/detection/conversation_pipeline.dart';
import 'package:guard_call/features/detection/detection_exception.dart';
import 'package:guard_call/features/detection/detection_provider_factory.dart';
import 'package:guard_call/features/detection/edge_function_scam_detection_engine.dart';
import 'package:guard_call/features/detection/edge_function_speech_to_text_service.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/mock_speech_to_text_service.dart';
import 'package:guard_call/features/detection/remote_ai_scam_detection_engine.dart';
import 'package:guard_call/features/detection/remote_speech_to_text_service.dart';
import 'package:guard_call/features/detection/scam_signal.dart';
import 'package:guard_call/features/detection/speech_to_text_service.dart';

class MockAIHttpClient implements AIHttpClient {
  final Future<String> Function(Uri url, Map<String, String>? headers, String? body) onPost;

  MockAIHttpClient(this.onPost);

  @override
  Future<String> post({
    required Uri url,
    Map<String, String>? headers,
    String? body,
    Duration timeout = const Duration(seconds: 15),
  }) =>
      onPost(url, headers, body);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppConfig.current = AppConfig.offlineDefault();
  });

  group('Step 15 — End-to-End AI & Speech-to-Text Pipeline Integration Tests', () {
    // -------------------------------------------------------------------------
    // 1. Full Mock Pipeline (AudioInput -> Mock STT -> Mock Detection -> RiskAnalysis)
    // -------------------------------------------------------------------------
    test('1. Full mock pipeline processes AudioInput through to RiskAnalysis offline', () async {
      final pipeline = ConversationPipeline.mock();
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final input = AudioInput.fromScenario(scenario);

      final analysis = await pipeline.processAudio(input);

      expect(analysis.riskScore, greaterThanOrEqualTo(85));
      expect(analysis.riskLevel, RiskLevel.critical);
      expect(analysis.detectedSignals, isNotEmpty);
      expect(analysis.confidence, greaterThan(0.0));
      expect(analysis.explanations, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // 2. Empty Transcript and Audio Validation
    // -------------------------------------------------------------------------
    test('2a. Empty AudioInput throws typed SpeechToTextException', () async {
      final pipeline = ConversationPipeline.mock();
      final emptyInput = AudioInput.empty();

      expect(
        () => pipeline.processAudio(emptyInput),
        throwsA(
          isA<SpeechToTextException>().having(
            (e) => e.errorType,
            'errorType',
            SpeechToTextErrorType.emptyAudio,
          ),
        ),
      );
    });

    test('2b. Empty conversation lines throw typed error in processConversation', () async {
      final pipeline = ConversationPipeline.mock();

      expect(
        () => pipeline.processConversation([]),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.invalidOutput,
          ),
        ),
      );
    });

    test('2c. Empty transcript from STT service throws typed SpeechToTextException', () async {
      final mockEmptyStt = _EmptyMockSpeechToTextService();
      final pipeline = ConversationPipeline(
        speechService: mockEmptyStt,
        detectionEngine: const MockScamDetectionEngine(),
      );

      final input = AudioInput.bytes([1, 2, 3], label: 'Test Audio');

      expect(
        () => pipeline.processAudio(input),
        throwsA(
          isA<SpeechToTextException>().having(
            (e) => e.errorType,
            'errorType',
            SpeechToTextErrorType.emptyAudio,
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 3. Provider Selection Mapping
    // -------------------------------------------------------------------------
    test('3a. Provider factory resolves Mock implementations when configured', () {
      final config = AppConfig.fromMap({
        'AI_BACKEND': 'mock',
        'STT_BACKEND': 'mock',
      });

      final engine = DetectionProviderFactory.getDetectionEngine(config: config);
      expect(engine, isA<MockScamDetectionEngine>());

      final stt = STTProviderFactory.getSpeechToTextService(config: config);
      expect(stt, isA<MockSpeechToTextService>());
    });

    test('3b. Provider factory resolves Direct Development implementations', () {
      final config = AppConfig.fromMap({
        'AI_BACKEND': 'direct_dev',
        'OPENAI_API_KEY': 'sk-test-key-mock',
        'STT_BACKEND': 'direct_dev',
        'SPEECH_TO_TEXT_API_KEY': 'stt-test-key-mock',
      });

      final engine = DetectionProviderFactory.getDetectionEngine(config: config);
      expect(engine, isA<RemoteAIScamDetectionEngine>());

      final stt = STTProviderFactory.getSpeechToTextService(config: config);
      expect(stt, isA<RemoteSpeechToTextService>());
    });

    test('3c. Provider factory resolves Edge Function implementations without silent dev fallback', () {
      final config = AppConfig.fromMap({
        'USE_SUPABASE': 'true',
        'SUPABASE_URL': 'https://edge-test.supabase.co',
        'SUPABASE_ANON_KEY': 'anon-test-key',
        'AI_BACKEND': 'edge_function',
        'STT_BACKEND': 'edge_function',
        'OPENAI_API_KEY': 'sk-should-not-be-used',
      });

      final engine = DetectionProviderFactory.getDetectionEngine(config: config);
      expect(engine, isA<EdgeFunctionScamDetectionEngine>());
      expect(engine, isNot(isA<RemoteAIScamDetectionEngine>()));

      final stt = STTProviderFactory.getSpeechToTextService(config: config);
      expect(stt, isA<EdgeFunctionSpeechToTextService>());
      expect(stt, isNot(isA<RemoteSpeechToTextService>()));
    });

    // -------------------------------------------------------------------------
    // 4. Mock Configuration Mode Labels
    // -------------------------------------------------------------------------
    test('4. Offline default configuration produces OFFLINE labels', () {
      final config = AppConfig.offlineDefault();

      expect(config.detectionModeLabel, 'OFFLINE');
      expect(config.sttModeLabel, 'OFFLINE');
      expect(config.isOfflineDemoMode, isTrue);
    });

    // -------------------------------------------------------------------------
    // 5. Direct Development Configuration Labels
    // -------------------------------------------------------------------------
    test('5. Direct dev configuration produces DIRECT DEV labels', () {
      final config = AppConfig.fromMap({
        'AI_BACKEND': 'direct_dev',
        'OPENAI_API_KEY': 'sk-test-key',
        'STT_BACKEND': 'direct_dev',
        'SPEECH_TO_TEXT_API_KEY': 'stt-key',
      });

      expect(config.detectionModeLabel, 'DIRECT DEV');
      expect(config.sttModeLabel, 'DIRECT DEV');
    });

    // -------------------------------------------------------------------------
    // 6. Edge Function Configuration Labels
    // -------------------------------------------------------------------------
    test('6. Edge function configuration produces EDGE PROXY labels', () {
      final config = AppConfig.fromMap({
        'USE_SUPABASE': 'true',
        'SUPABASE_URL': 'https://my-app.supabase.co',
        'SUPABASE_ANON_KEY': 'anon-key-valid',
        'AI_BACKEND': 'edge_function',
        'STT_BACKEND': 'edge_function',
      });

      expect(config.detectionModeLabel, 'EDGE PROXY');
      expect(config.sttModeLabel, 'EDGE PROXY');
    });

    // -------------------------------------------------------------------------
    // 7. AI Response Normalization (Score, Confidence, 9 Signals, Deterministic Level)
    // -------------------------------------------------------------------------
    test('7. AI response correctly normalizes into RiskAnalysis with deterministic thresholds', () {
      const rawAiJson = '''
{
  "risk_score": 75,
  "confidence": 0.88,
  "signals": [
    {
      "type": "urgency",
      "severity": "high",
      "explanation": "Artificial urgency imposed on the senior."
    },
    {
      "type": "financial_pressure",
      "severity": "high",
      "explanation": "Demanding immediate transfer of funds."
    }
  ],
  "summary": "Urgent financial pressure detected."
}''';

      final analysis = RemoteAIScamDetectionEngine.parseStructuredOutput(rawAiJson);

      expect(analysis.riskScore, 75);
      expect(analysis.riskLevel, RiskLevel.high); // 75 falls in High (71-84)
      expect(analysis.confidence, 0.88);
      expect(analysis.detectedSignals.length, 2);
      expect(analysis.detectedSignals[0].type, ScamSignalType.urgency);
      expect(analysis.detectedSignals[1].type, ScamSignalType.financialPressure);
      expect(analysis.explanations, contains('Urgent financial pressure detected.'));
      expect(analysis.timestamp, isNotNull);
    });

    // -------------------------------------------------------------------------
    // 8. Invalid AI Responses Rejected with Typed Errors
    // -------------------------------------------------------------------------
    test('8a. Invalid JSON throws DetectionException(invalidJson)', () {
      expect(
        () => RemoteAIScamDetectionEngine.parseStructuredOutput('not-valid-json{'),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.invalidJson,
          ),
        ),
      );
    });

    test('8b. Risk score out of bounds (<0 or >100) throws DetectionException(invalidOutput)', () {
      const invalidScoreJson = '{"risk_score": 150, "confidence": 0.8}';
      expect(
        () => RemoteAIScamDetectionEngine.parseStructuredOutput(invalidScoreJson),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.invalidOutput,
          ),
        ),
      );
    });

    test('8c. Confidence out of bounds (<0.0 or >1.0) throws DetectionException(invalidOutput)', () {
      const invalidConfJson = '{"risk_score": 50, "confidence": 1.5}';
      expect(
        () => RemoteAIScamDetectionEngine.parseStructuredOutput(invalidConfJson),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.invalidOutput,
          ),
        ),
      );
    });

    test('8d. Unknown scam signal type throws DetectionException(unknownSignalType)', () {
      const unknownSignalJson = '''
{
  "risk_score": 60,
  "confidence": 0.7,
  "signals": [
    {
      "type": "unrecognized_alien_signal",
      "explanation": "Something foreign."
    }
  ]
}''';
      expect(
        () => RemoteAIScamDetectionEngine.parseStructuredOutput(unknownSignalJson),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.unknownSignalType,
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 9. STT Response Normalization
    // -------------------------------------------------------------------------
    test('9a. OpenAI Whisper text string normalizes into ConversationLine list', () {
      const whisperJson = '{"text": "Hello, this is your bank calling. We need you to verify your account."}';
      final lines = RemoteSpeechToTextService.parseTranscriptResponse(whisperJson);

      expect(lines.isNotEmpty, isTrue);
      expect(lines.first.speaker, Speaker.caller);
      expect(lines.first.text, contains('bank calling'));
    });

    test('9b. Multi-line structured STT format maps caller and user correctly', () {
      const multiLineJson = '''
{
  "lines": [
    {"speaker": "caller", "text": "Can you hear me?"},
    {"speaker": "user", "text": "Yes, who is this?"},
    {"speaker": "caller", "text": "This is Officer Sharma from Delhi Police."}
  ]
}''';
      final lines = RemoteSpeechToTextService.parseTranscriptResponse(multiLineJson);

      expect(lines.length, 3);
      expect(lines[0].speaker, Speaker.caller);
      expect(lines[1].speaker, Speaker.user);
      expect(lines[2].speaker, Speaker.caller);
      expect(lines[2].text, 'This is Officer Sharma from Delhi Police.');
    });

    // -------------------------------------------------------------------------
    // 10. Provider Failure & Non-Fabrication
    // -------------------------------------------------------------------------
    test('10a. Remote AI timeout throws typed DetectionException without fabricating score', () async {
      final timeoutClient = MockAIHttpClient((url, headers, body) async {
        throw TimeoutException('Request timed out');
      });

      final engine = RemoteAIScamDetectionEngine(
        apiKey: 'sk-valid-format-key',
        httpClient: timeoutClient,
        enableFallback: false,
      );

      final pipeline = ConversationPipeline(
        speechService: const MockSpeechToTextService(),
        detectionEngine: engine,
      );

      final scenario = DemoScenarios.all.first;
      final input = AudioInput.fromScenario(scenario);

      expect(
        () => pipeline.processAudio(input),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.timeout,
          ),
        ),
      );
    });

    test('10b. Edge Function missing authentication throws typed DetectionException', () async {
      final edgeClient = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-ref.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        authTokenProvider: () => null, // No active session
      );

      final engine = EdgeFunctionScamDetectionEngine(
        edgeClient: edgeClient,
        enableFallback: false,
      );

      expect(
        () => engine.analyzeConversation([
          const ConversationLine(speaker: Speaker.caller, text: 'Test line'),
        ]),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.unauthorized,
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 11. Offline Operation (No Internet, No Supabase, 100% In-Memory)
    // -------------------------------------------------------------------------
    test('11. Complete offline pipeline execution functions without network or secrets', () async {
      final pipeline = ConversationPipeline.fromConfig(
        config: AppConfig.offlineDefault(),
      );

      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'grandchild_emergency');
      final input = AudioInput.fromScenario(scenario);

      final analysis = await pipeline.processAudio(input);

      expect(analysis.riskScore, greaterThanOrEqualTo(70));
      expect(analysis.isScamLikely, isTrue);
      expect(analysis.detectedSignals.any((s) => s.type == ScamSignalType.emotionalManipulation), isTrue);
    });

    // -------------------------------------------------------------------------
    // 12. Regression of All 5 Existing Demo Scenarios
    // -------------------------------------------------------------------------
    test('12. All 5 demo scenarios evaluate accurately through the pipeline', () async {
      final pipeline = ConversationPipeline.mock();

      // 1. Fake KYC Update -> Critical
      final kyc = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final kycResult = await pipeline.processAudio(AudioInput.fromScenario(kyc));
      expect(kycResult.riskLevel, RiskLevel.critical);
      expect(kycResult.riskScore, greaterThanOrEqualTo(85));

      // 2. Digital Arrest Threat -> Critical
      final arrest = DemoScenarios.all.firstWhere((s) => s.id == 'digital_arrest');
      final arrestResult = await pipeline.processAudio(AudioInput.fromScenario(arrest));
      expect(arrestResult.riskLevel, RiskLevel.critical);
      expect(arrestResult.riskScore, greaterThanOrEqualTo(85));

      // 3. Grandchild Emergency -> High
      final emergency = DemoScenarios.all.firstWhere((s) => s.id == 'grandchild_emergency');
      final emergencyResult = await pipeline.processAudio(AudioInput.fromScenario(emergency));
      expect(emergencyResult.riskLevel, RiskLevel.high);
      expect(emergencyResult.riskScore, inInclusiveRange(71, 84));

      // 4. Legitimate Bank Alert -> Safe
      final bank = DemoScenarios.all.firstWhere((s) => s.id == 'genuine_bank');
      final bankResult = await pipeline.processAudio(AudioInput.fromScenario(bank));
      expect(bankResult.riskLevel, RiskLevel.safe);
      expect(bankResult.riskScore, lessThan(40));

      // 5. Hospital Appointment Reschedule -> Safe
      final hospital = DemoScenarios.all.firstWhere((s) => s.id == 'genuine_hospital');
      final hospitalResult = await pipeline.processAudio(AudioInput.fromScenario(hospital));
      expect(hospitalResult.riskLevel, RiskLevel.safe);
      expect(hospitalResult.riskScore, lessThan(40));
    });

    // -------------------------------------------------------------------------
    // 13. DemoSessionController works with ConversationPipeline and Progressive Detection
    // -------------------------------------------------------------------------
    test('13. DemoSessionController advances turn by turn with progressive risk detection', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final controller = DemoSessionController(scenario: scenario);

      expect(controller.currentAnalysis.riskScore, 0);
      expect(controller.currentAnalysis.riskLevel, RiskLevel.safe);

      // Turn 1
      await controller.advanceNextLine();
      expect(controller.displayedLines.length, 1);

      // Advance remaining turns until warning threshold is crossed
      while (!controller.isCompleted && !controller.isWarningThresholdCrossed) {
        await controller.advanceNextLine();
      }

      expect(controller.isWarningThresholdCrossed, isTrue);
      expect(controller.warningShown, isTrue);
      expect(controller.currentAnalysis.riskScore, greaterThanOrEqualTo(71));

      controller.dispose();
    });
  });
}

class _EmptyMockSpeechToTextService extends SpeechToTextService {
  @override
  Future<List<ConversationLine>> transcribeAudio(AudioInput input) async {
    return [];
  }
}
