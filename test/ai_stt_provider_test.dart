import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/core/config/app_config.dart';
import 'package:guard_call/core/services/ai_http_client.dart';
import 'package:guard_call/core/services/auth_service.dart';
import 'package:guard_call/core/services/family_alert_service.dart';
import 'package:guard_call/core/services/family_relationship_service.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/demo/demo_scenario.dart';
import 'package:guard_call/features/demo/demo_scenarios.dart';
import 'package:guard_call/features/detection/audio_input.dart';
import 'package:guard_call/features/detection/conversation_pipeline.dart';
import 'package:guard_call/features/detection/detection_exception.dart';
import 'package:guard_call/features/detection/detection_provider_factory.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/mock_speech_to_text_service.dart';
import 'package:guard_call/features/detection/remote_ai_scam_detection_engine.dart';
import 'package:guard_call/features/detection/remote_speech_to_text_service.dart';
import 'package:guard_call/features/detection/scam_signal.dart';
import 'package:guard_call/features/history/call_history_repository.dart';

typedef HttpPostHandler = Future<String> Function({
  required Uri url,
  required Map<String, String> headers,
  required String body,
  Duration timeout,
});

class FakeAIHttpClient implements AIHttpClient {
  final HttpPostHandler handler;

  FakeAIHttpClient(this.handler);

  @override
  Future<String> post({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 10),
  }) =>
      handler(url: url, headers: headers, body: body, timeout: timeout);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppConfig.current = AppConfig.offlineDefault();
  });

  group('Phase L — Step 12 AI & Speech-to-Text Provider Tests', () {
    test('1. Provider factory defaults to mock engines when unconfigured', () {
      final engine = DetectionProviderFactory.getDetectionEngine();
      expect(engine, isA<MockScamDetectionEngine>());

      final stt = STTProviderFactory.getSpeechToTextService();
      expect(stt, isA<MockSpeechToTextService>());
    });

    test('2. Mock STT still transcribes scenario accurately', () async {
      const mockStt = MockSpeechToTextService();
      final scenario = DemoScenarios.all.first;
      final input = AudioInput.fromScenario(scenario);

      final lines = await mockStt.transcribeAudio(input);
      expect(lines.isNotEmpty, isTrue);
      expect(lines.first.text, scenario.conversationLines.first.text);
    });

    test('3. Mock detection still analyzes conversation correctly', () async {
      const mockEngine = MockScamDetectionEngine();
      final fakeKyc = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');

      final analysis = await mockEngine.analyzeConversation(fakeKyc.conversationLines);
      expect(analysis.riskLevel, RiskLevel.critical);
      expect(analysis.riskScore, greaterThanOrEqualTo(85));
      expect(analysis.detectedSignals, isNotEmpty);
    });

    test('4. Pipeline dependency injection works with custom engines', () async {
      const stt = MockSpeechToTextService();
      const engine = MockScamDetectionEngine();
      final pipeline = ConversationPipeline(speechService: stt, detectionEngine: engine);

      final scenario = DemoScenarios.all.first;
      final input = AudioInput.fromScenario(scenario);
      final analysis = await pipeline.processAudio(input);

      expect(analysis.riskScore, greaterThan(0));
    });

    test('5. Invalid AI JSON response is rejected with typed error', () {
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

    test('6. Risk score outside 0–100 is rejected', () {
      final badScoreJson = '''
      {
        "risk_score": 150,
        "confidence": 0.9,
        "signals": []
      }
      ''';
      expect(
        () => RemoteAIScamDetectionEngine.parseStructuredOutput(badScoreJson),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.invalidOutput,
          ),
        ),
      );

      final negativeScoreJson = '''
      {
        "risk_score": -10,
        "confidence": 0.9,
        "signals": []
      }
      ''';
      expect(
        () => RemoteAIScamDetectionEngine.parseStructuredOutput(negativeScoreJson),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.invalidOutput,
          ),
        ),
      );
    });

    test('7. Confidence outside 0–1 is rejected', () {
      final badConfidenceJson = '''
      {
        "risk_score": 50,
        "confidence": 1.5,
        "signals": []
      }
      ''';
      expect(
        () => RemoteAIScamDetectionEngine.parseStructuredOutput(badConfidenceJson),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.invalidOutput,
          ),
        ),
      );
    });

    test('8. Unknown signal type is rejected', () {
      final unknownSignalJson = '''
      {
        "risk_score": 75,
        "confidence": 0.8,
        "signals": [
          {
            "type": "unrecognized_alien_signal",
            "severity": "high",
            "explanation": "Something suspicious"
          }
        ]
      }
      ''';
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

    test('9. Empty explanation is rejected', () {
      final emptyExplanationJson = '''
      {
        "risk_score": 75,
        "confidence": 0.8,
        "signals": [
          {
            "type": "urgency",
            "severity": "high",
            "explanation": ""
          }
        ]
      }
      ''';
      expect(
        () => RemoteAIScamDetectionEngine.parseStructuredOutput(emptyExplanationJson),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.invalidOutput,
          ),
        ),
      );
    });

    test('10. Remote AI timeout produces typed failure', () async {
      final timeoutClient = FakeAIHttpClient(
        ({required url, required headers, required body, timeout = const Duration(seconds: 10)}) async {
          throw TimeoutException('Request timed out');
        },
      );

      final engine = RemoteAIScamDetectionEngine(
        apiKey: 'test-valid-key',
        httpClient: timeoutClient,
        enableFallback: false,
      );

      expect(
        () => engine.analyzeConversation([
          const ConversationLine(speaker: Speaker.caller, text: 'Hello'),
        ]),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.timeout,
          ),
        ),
      );
    });

    test('11. Remote STT timeout produces typed failure', () async {
      final timeoutClient = FakeAIHttpClient(
        ({required url, required headers, required body, timeout = const Duration(seconds: 10)}) async {
          throw TimeoutException('STT timed out');
        },
      );

      final stt = RemoteSpeechToTextService(
        apiKey: 'test-stt-key',
        httpClient: timeoutClient,
      );

      const input = AudioInput(
        sourceType: AudioSourceType.prerecordedFile,
        label: 'test.wav',
        duration: Duration(seconds: 10),
      );

      expect(
        () => stt.transcribeAudio(input),
        throwsA(
          isA<SpeechToTextException>().having(
            (e) => e.errorType,
            'errorType',
            SpeechToTextErrorType.transcriptionTimeout,
          ),
        ),
      );
    });

    test('12. Network failure does not crash the app / handles safely', () async {
      final socketErrorClient = FakeAIHttpClient(
        ({required url, required headers, required body, timeout = const Duration(seconds: 10)}) async {
          throw const SocketException('No route to host');
        },
      );

      final engine = RemoteAIScamDetectionEngine(
        apiKey: 'test-key',
        httpClient: socketErrorClient,
        enableFallback: false,
      );

      expect(
        () => engine.analyzeConversation([
          const ConversationLine(speaker: Speaker.caller, text: 'Test'),
        ]),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.errorType,
            'errorType',
            DetectionErrorType.networkFailure,
          ),
        ),
      );

      // Safe pipeline returns safe fallback with explanation
      final pipeline = ConversationPipeline(
        speechService: const MockSpeechToTextService(),
        detectionEngine: engine,
      );

      final scenario = DemoScenarios.all.first;
      final analysis = await pipeline.processAudioSafe(AudioInput.fromScenario(scenario));
      expect(analysis.riskLevel, RiskLevel.safe);
      expect(analysis.explanations.first, contains('AI analysis unavailable'));
    });

    test('13. Missing API key does not crash the app', () async {
      final engine = RemoteAIScamDetectionEngine(
        apiKey: '',
        enableFallback: true,
        fallbackEngine: const MockScamDetectionEngine(),
      );

      final fakeKyc = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      // With fallback enabled, seamlessly falls back to mock detection without throwing
      final analysis = await engine.analyzeConversation(fakeKyc.conversationLines);
      expect(analysis.riskLevel, RiskLevel.critical);
    });

    test('14. Offline mode makes zero remote requests', () async {
      var requestMade = false;
      final trackingClient = FakeAIHttpClient(
        ({required url, required headers, required body, timeout = const Duration(seconds: 10)}) async {
          requestMade = true;
          return '{}';
        },
      );

      final pipeline = ConversationPipeline.fromConfig(
        config: AppConfig.offlineDefault(),
        httpClient: trackingClient,
      );

      final scenario = DemoScenarios.all.first;
      await pipeline.processAudio(AudioInput.fromScenario(scenario));
      expect(requestMade, isFalse);
    });

    test('15. Existing five demo scenarios still produce their expected risk levels', () async {
      const engine = MockScamDetectionEngine();

      for (final scenario in DemoScenarios.all) {
        final analysis = await engine.analyzeConversation(scenario.conversationLines);
        expect(
          analysis.riskLevel,
          scenario.expectedRiskLevel,
          reason: 'Scenario ${scenario.id} did not match expected level',
        );
      }
    });

    test('16. Valid structured remote AI response produces correct RiskAnalysis', () {
      final validResponse = '''
      {
        "risk_score": 88,
        "confidence": 0.95,
        "signals": [
          {
            "type": "authority_impersonation",
            "severity": "critical",
            "explanation": "Caller impersonated bank fraud department."
          },
          {
            "type": "urgency",
            "severity": "high",
            "explanation": "Demanded OTP within 5 minutes."
          }
        ],
        "summary": "High risk banking impersonation fraud detected."
      }
      ''';

      final analysis = RemoteAIScamDetectionEngine.parseStructuredOutput(validResponse);
      expect(analysis.riskScore, 88);
      expect(analysis.riskLevel, RiskLevel.critical);
      expect(analysis.confidence, 0.95);
      expect(analysis.detectedSignals.length, 2);
      expect(analysis.detectedSignals[0].type, ScamSignalType.authorityImpersonation);
      expect(analysis.detectedSignals[1].type, ScamSignalType.urgency);
      expect(analysis.explanations.first, contains('High risk banking impersonation'));
    });

    test('17. Existing Family Circle still works in local memory', () async {
      final rels = await FamilyRelationshipService.instance.getMyRelationships();
      expect(rels.isNotEmpty, isTrue);
      expect(rels.first.relationship, contains('Daughter'));
    });

    test('18. Existing Supabase alert creation works in local fallback', () async {
      final alert = await FamilyAlertService.instance.createAlert(
        callSessionId: 'test-session-12',
        familyContactId: 'test-contact-12',
        riskScore: 78,
      );
      expect(alert.status, 'pending');
      expect(alert.riskScore, 78);
    });

    test('19. Existing authentication tests still work in offline demo', () {
      expect(AuthService.instance.isConfigured, isFalse);
      expect(AuthService.instance.isOffline, isTrue);
    });

    test('20. Existing history tests still work', () {
      CallHistoryRepository.instance.clear();
      expect(CallHistoryRepository.instance.records, isEmpty);

      const record = CallHistoryRecord(
        id: 'hist-12',
        title: 'Step 12 Test Call',
        subtitle: 'Validation',
        timestamp: 'Now',
        duration: '1m',
        riskScore: 60,
        riskLevel: RiskLevel.suspicious,
        signals: ['Urgency'],
      );

      CallHistoryRepository.instance.addRecord(record);
      expect(CallHistoryRepository.instance.records.length, 1);
    });
  });
}
