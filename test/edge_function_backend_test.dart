import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/core/config/app_config.dart';
import 'package:guard_call/core/services/ai_http_client.dart';
import 'package:guard_call/core/services/guardcall_edge_function_client.dart';
import 'package:guard_call/features/demo/demo_scenario.dart';
import 'package:guard_call/features/demo/demo_scenarios.dart';
import 'package:guard_call/features/detection/audio_input.dart';
import 'package:guard_call/features/detection/detection_exception.dart';
import 'package:guard_call/features/detection/detection_provider_factory.dart';
import 'package:guard_call/features/detection/edge_function_scam_detection_engine.dart';
import 'package:guard_call/features/detection/edge_function_speech_to_text_service.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/mock_speech_to_text_service.dart';
import 'package:guard_call/features/detection/scam_signal.dart';

class MockAIHttpClient implements AIHttpClient {
  final Future<String> Function(Uri url, Map<String, String>? headers, String? body)? onPost;

  MockAIHttpClient({this.onPost});

  @override
  Future<String> post({
    required Uri url,
    Map<String, String>? headers,
    String? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (onPost != null) {
      return onPost!(url, headers, body);
    }
    throw const SocketException('No mock implementation provided');
  }
}

void main() {
  group('Step 13 — Secure Supabase Edge Function AI Backend Proxy Tests', () {
    const validAiResponse = '''
{
  "risk_score": 88,
  "confidence": 0.95,
  "signals": [
    {
      "type": "authority_impersonation",
      "severity": "critical",
      "explanation": "Caller falsely claims to be a police officer."
    },
    {
      "type": "urgency",
      "severity": "high",
      "explanation": "Demands immediate action before arrest."
    }
  ],
  "summary": "Impersonator attempting extortion under threat of digital arrest."
}''';

    const validSttResponse = '''
{
  "lines": [
    {
      "speaker": "caller",
      "text": "This is Officer Sharma from Delhi Police."
    },
    {
      "speaker": "caller",
      "text": "Your Aadhaar is linked to illegal contraband."
    }
  ]
}''';

    // -------------------------------------------------------------------------
    // 1. Authenticated Edge Function request
    // -------------------------------------------------------------------------
    test('1. Authenticated Edge Function request includes Bearer token and apikey', () async {
      Uri? calledUrl;
      Map<String, String>? calledHeaders;
      String? calledBody;

      final mockClient = MockAIHttpClient(
        onPost: (url, headers, body) async {
          calledUrl = url;
          calledHeaders = headers;
          calledBody = body;
          return validAiResponse;
        },
      );

      final client = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        httpClient: mockClient,
        authTokenProvider: () => 'valid-jwt-token-xyz',
      );

      final result = await client.analyzeConversation([
        const ConversationLine(speaker: Speaker.caller, text: 'Give me your OTP immediately.'),
      ]);

      expect(calledUrl.toString(), equals('https://test-project.supabase.co/functions/v1/guardcall-ai-analyze'));
      expect(calledHeaders?['Authorization'], equals('Bearer valid-jwt-token-xyz'));
      expect(calledHeaders?['apikey'], equals('test-anon-key'));
      expect(calledBody, contains('Give me your OTP immediately.'));

      expect(result.riskScore, equals(88));
      expect(result.confidence, equals(0.95));
      expect(result.detectedSignals.length, equals(2));
      expect(result.detectedSignals.first.type, equals(ScamSignalType.authorityImpersonation));
    });

    // -------------------------------------------------------------------------
    // 2. Unauthenticated request rejected
    // -------------------------------------------------------------------------
    test('2. Unauthenticated request rejected with DetectionException unauthorized', () async {
      final client = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        authTokenProvider: () => null, // No session token
      );

      expect(
        () => client.analyzeConversation([
          const ConversationLine(speaker: Speaker.caller, text: 'Hello'),
        ]),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.type,
            'error type',
            equals(DetectionErrorType.unauthorized),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 3. Unauthenticated STT request rejected
    // -------------------------------------------------------------------------
    test('3. Unauthenticated STT request rejected with SpeechToTextException', () async {
      final client = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        authTokenProvider: () => '', // Empty session
      );

      // Audio bytes input requires authentication
      final audioInput = AudioInput.bytes(
        [1, 2, 3, 4],
        duration: const Duration(seconds: 2),
      );

      expect(
        () => client.transcribeAudio(audioInput),
        throwsA(
          isA<SpeechToTextException>().having(
            (e) => e.type,
            'error type',
            equals(SpeechToTextErrorType.unavailableAudio),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 4. Empty conversation handled safely
    // -------------------------------------------------------------------------
    test('4. Empty conversation returns safe RiskAnalysis without network request', () async {
      var netCalls = 0;
      final mockClient = MockAIHttpClient(
        onPost: (url, headers, body) async {
          netCalls++;
          return validAiResponse;
        },
      );

      final client = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        httpClient: mockClient,
        authTokenProvider: () => 'token',
      );

      final result = await client.analyzeConversation([]);
      expect(netCalls, equals(0));
      expect(result.riskScore, equals(0));
    });

    // -------------------------------------------------------------------------
    // 5. Invalid STT input rejected
    // -------------------------------------------------------------------------
    test('5. Empty audio input rejected before making network request', () async {
      final client = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        authTokenProvider: () => 'token',
      );

      final emptyInput = AudioInput.stream(null, duration: Duration.zero);

      expect(
        () => client.transcribeAudio(emptyInput),
        throwsA(
          isA<SpeechToTextException>().having(
            (e) => e.type,
            'type',
            equals(SpeechToTextErrorType.emptyAudio),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 6. Missing provider secret handled safely
    // -------------------------------------------------------------------------
    test('6. Missing provider secret in Edge Function surfaces typed missingApiKey failure', () async {
      final mockClient = MockAIHttpClient(
        onPost: (url, headers, body) async {
          throw const HttpException('HTTP 503: AI provider credentials are not configured on this server.');
        },
      );

      final client = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        httpClient: mockClient,
        authTokenProvider: () => 'token',
      );

      expect(
        () => client.analyzeConversation([
          const ConversationLine(speaker: Speaker.caller, text: 'Pay the fine now.'),
        ]),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.type,
            'type',
            equals(DetectionErrorType.missingApiKey),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 7. Provider timeout handled
    // -------------------------------------------------------------------------
    test('7. Provider timeout handled safely with typed timeout exception', () async {
      final mockClient = MockAIHttpClient(
        onPost: (url, headers, body) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return validAiResponse;
        },
      );

      final client = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        httpClient: mockClient,
        timeout: const Duration(milliseconds: 10),
        authTokenProvider: () => 'token',
      );

      expect(
        () => client.analyzeConversation([
          const ConversationLine(speaker: Speaker.caller, text: 'Hello'),
        ]),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.type,
            'type',
            equals(DetectionErrorType.timeout),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 8. Provider malformed response rejected
    // -------------------------------------------------------------------------
    test('8. Provider malformed response is rejected', () async {
      final mockClient = MockAIHttpClient(
        onPost: (url, headers, body) async => 'NOT_JSON_AT_ALL',
      );

      final client = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        httpClient: mockClient,
        authTokenProvider: () => 'token',
      );

      expect(
        () => client.analyzeConversation([
          const ConversationLine(speaker: Speaker.caller, text: 'Hello'),
        ]),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.type,
            'type',
            equals(DetectionErrorType.invalidJson),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 9. AI schema validation
    // -------------------------------------------------------------------------
    test('9. AI schema validation rejects invalid score or confidence', () async {
      final mockClient = MockAIHttpClient(
        onPost: (url, headers, body) async => jsonEncode({
          'risk_score': 150, // Invalid!
          'confidence': 0.8,
          'signals': [],
        }),
      );

      final client = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        httpClient: mockClient,
        authTokenProvider: () => 'token',
      );

      expect(
        () => client.analyzeConversation([
          const ConversationLine(speaker: Speaker.caller, text: 'Hello'),
        ]),
        throwsA(
          isA<DetectionException>().having(
            (e) => e.type,
            'type',
            equals(DetectionErrorType.invalidOutput),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 10. STT response validation
    // -------------------------------------------------------------------------
    test('10. STT response validation parses structured lines', () async {
      final mockClient = MockAIHttpClient(
        onPost: (url, headers, body) async => validSttResponse,
      );

      final client = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        httpClient: mockClient,
        authTokenProvider: () => 'token',
      );

      final audioInput = AudioInput.bytes(
        [10, 20, 30],
        duration: const Duration(seconds: 3),
      );

      final lines = await client.transcribeAudio(audioInput);
      expect(lines.length, equals(2));
      expect(lines.first.speaker, equals(Speaker.caller));
      expect(lines.first.text, equals('This is Officer Sharma from Delhi Police.'));
      expect(lines.last.text, equals('Your Aadhaar is linked to illegal contraband.'));
    });

    // -------------------------------------------------------------------------
    // 11. EdgeFunctionScamDetectionEngine fallback behavior
    // -------------------------------------------------------------------------
    test('11. EdgeFunctionScamDetectionEngine falls back to local heuristic on error when enabled', () async {
      final mockClient = MockAIHttpClient(
        onPost: (url, headers, body) async {
          throw const SocketException('Server unreachable');
        },
      );

      final edgeClient = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        httpClient: mockClient,
        authTokenProvider: () => 'token',
      );

      final engine = EdgeFunctionScamDetectionEngine(
        edgeClient: edgeClient,
        enableFallback: true,
      );

      // The fallback engine analyzes the KYC scam scenario and detects Critical risk
      final fakeKyc = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final result = await engine.analyzeConversation(fakeKyc.conversationLines);

      expect(result.riskScore, greaterThanOrEqualTo(85));
      expect(result.detectedSignals.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // 12. EdgeFunctionSpeechToTextService delegation
    // -------------------------------------------------------------------------
    test('12. EdgeFunctionSpeechToTextService delegates audio transcription to client', () async {
      final mockClient = MockAIHttpClient(
        onPost: (url, headers, body) async => validSttResponse,
      );

      final edgeClient = GuardCallEdgeFunctionClient(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        httpClient: mockClient,
        authTokenProvider: () => 'token',
      );

      final sttService = EdgeFunctionSpeechToTextService(edgeClient: edgeClient);
      final lines = await sttService.transcribeAudio(
        AudioInput.bytes([1, 2, 3], duration: const Duration(seconds: 1)),
      );

      expect(lines.length, equals(2));
    });

    // -------------------------------------------------------------------------
    // 13. AppConfig backend parsing
    // -------------------------------------------------------------------------
    test('13. AppConfig parses AI_BACKEND and STT_BACKEND configuration', () {
      final config = AppConfig.fromMap({
        'SUPABASE_URL': 'https://custom-project.supabase.co',
        'SUPABASE_ANON_KEY': 'actual-anon-key-12345',
        'USE_SUPABASE': 'true',
        'AI_BACKEND': 'edge_function',
        'STT_BACKEND': 'edge_function',
      });

      expect(config.aiBackend, equals('edge_function'));
      expect(config.sttBackend, equals('edge_function'));
      expect(config.isEdgeFunctionAiConfigured, isTrue);
      expect(config.isEdgeFunctionSttConfigured, isTrue);
      expect(config.isOfflineDemoMode, isFalse);
    });

    // -------------------------------------------------------------------------
    // 14. Provider factory resolves EdgeFunctionScamDetectionEngine
    // -------------------------------------------------------------------------
    test('14. DetectionProviderFactory returns EdgeFunctionScamDetectionEngine when configured', () {
      final config = AppConfig.fromMap({
        'SUPABASE_URL': 'https://custom-project.supabase.co',
        'SUPABASE_ANON_KEY': 'actual-anon-key-12345',
        'USE_SUPABASE': 'true',
        'AI_BACKEND': 'edge_function',
      });

      final engine = DetectionProviderFactory.getDetectionEngine(config: config);
      expect(engine, isA<EdgeFunctionScamDetectionEngine>());
    });

    // -------------------------------------------------------------------------
    // 15. Provider factory resolves EdgeFunctionSpeechToTextService
    // -------------------------------------------------------------------------
    test('15. STTProviderFactory returns EdgeFunctionSpeechToTextService when configured', () {
      final config = AppConfig.fromMap({
        'SUPABASE_URL': 'https://custom-project.supabase.co',
        'SUPABASE_ANON_KEY': 'actual-anon-key-12345',
        'USE_SUPABASE': 'true',
        'STT_BACKEND': 'edge_function',
      });

      final service = STTProviderFactory.getSpeechToTextService(config: config);
      expect(service, isA<EdgeFunctionSpeechToTextService>());
    });

    // -------------------------------------------------------------------------
    // 16. Offline mock mode still defaults cleanly
    // -------------------------------------------------------------------------
    test('16. Provider factory defaults to mock engines when offline or unconfigured', () {
      final offlineConfig = AppConfig.offlineDefault();

      final engine = DetectionProviderFactory.getDetectionEngine(config: offlineConfig);
      final stt = STTProviderFactory.getSpeechToTextService(config: offlineConfig);

      expect(engine, isA<MockScamDetectionEngine>());
      expect(stt, isA<MockSpeechToTextService>());
    });
  });
}
