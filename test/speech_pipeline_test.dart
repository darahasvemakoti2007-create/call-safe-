import 'package:flutter_test/flutter_test.dart';
import 'package:guard_call/core/widgets/risk_badge.dart';
import 'package:guard_call/features/demo/demo_scenarios.dart';
import 'package:guard_call/features/detection/audio_input.dart';
import 'package:guard_call/features/detection/conversation_pipeline.dart';
import 'package:guard_call/features/detection/mock_scam_detection_engine.dart';
import 'package:guard_call/features/detection/mock_speech_to_text_service.dart';
import 'package:guard_call/features/detection/scam_detection_engine.dart';
import 'package:guard_call/features/detection/speech_to_text_service.dart';

void main() {
  late SpeechToTextService speechService;
  late ScamDetectionEngine detectionEngine;
  late ConversationPipeline pipeline;

  setUp(() {
    speechService = const MockSpeechToTextService();
    detectionEngine = const MockScamDetectionEngine();
    pipeline = ConversationPipeline(
      speechService: speechService,
      detectionEngine: detectionEngine,
    );
  });

  group('Step 7 Audio Pipeline & Mock STT Tests', () {
    test('1. Fake KYC scenario via pipeline reaches Critical risk', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');
      final input = AudioInput.fromScenario(scenario);

      final analysis = await pipeline.processAudio(input);

      expect(analysis.riskLevel, equals(RiskLevel.critical));
      expect(analysis.riskScore, greaterThanOrEqualTo(85));
      expect(analysis.detectedSignals, isNotEmpty);
      expect(
        analysis.detectedSignals.any((s) => s.title.toLowerCase().contains('otp') || s.title.toLowerCase().contains('sensitive')),
        isTrue,
      );
    });

    test('2. Digital Arrest scenario via pipeline reaches Critical risk', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'digital_arrest');
      final input = AudioInput.fromScenario(scenario);

      final analysis = await pipeline.processAudio(input);

      expect(analysis.riskLevel, equals(RiskLevel.critical));
      expect(analysis.riskScore, greaterThanOrEqualTo(85));
      expect(
        analysis.detectedSignals.any((s) => s.title.toLowerCase().contains('authority')),
        isTrue,
      );
    });

    test('3. Grandchild Emergency scenario via pipeline reaches High risk', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'grandchild_emergency');
      final input = AudioInput.fromScenario(scenario);

      final analysis = await pipeline.processAudio(input);

      expect(analysis.riskLevel, equals(RiskLevel.high));
      expect(analysis.riskScore, greaterThanOrEqualTo(70));
      expect(
        analysis.detectedSignals.any((s) => s.title.toLowerCase().contains('emotional') || s.title.toLowerCase().contains('distress')),
        isTrue,
      );
    });

    test('4. Genuine Bank scenario via pipeline remains Safe', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'genuine_bank');
      final input = AudioInput.fromScenario(scenario);

      final analysis = await pipeline.processAudio(input);

      expect(analysis.riskLevel, equals(RiskLevel.safe));
      expect(analysis.riskScore, equals(0));
      expect(analysis.detectedSignals, isEmpty);
    });

    test('5. Genuine Hospital scenario via pipeline remains Safe', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'genuine_hospital');
      final input = AudioInput.fromScenario(scenario);

      final analysis = await pipeline.processAudio(input);

      expect(analysis.riskLevel, equals(RiskLevel.safe));
      expect(analysis.riskScore, equals(0));
      expect(analysis.detectedSignals, isEmpty);
    });

    test('6. Empty audio input throws typed SpeechToTextException safely', () async {
      final emptyInput = AudioInput.empty();

      expect(
        () => speechService.transcribeAudio(emptyInput),
        throwsA(
          isA<SpeechToTextException>().having(
            (e) => e.errorType,
            'errorType',
            equals(SpeechToTextErrorType.emptyAudio),
          ),
        ),
      );
    });

    test('7. Mock speech service executes offline with zero network latency', () async {
      final scenario = DemoScenarios.all.first;
      final input = AudioInput.fromScenario(scenario);

      final stopwatch = Stopwatch()..start();
      final lines = await speechService.transcribeAudio(input);
      stopwatch.stop();

      // Offline in-memory execution must resolve almost instantaneously (< 50ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
      expect(lines.length, equals(scenario.conversationLines.length));
    });

    test('8. Detection engine operates completely independently from speech service', () async {
      final scenario = DemoScenarios.all.firstWhere((s) => s.id == 'fake_kyc');

      // Direct detection engine call without using speechService
      final directAnalysis = await detectionEngine.analyzeConversation(scenario.conversationLines);
      expect(directAnalysis.riskLevel, equals(RiskLevel.critical));

      // Pipeline also supports direct conversation processing without STT
      final pipelineDirectAnalysis = await pipeline.processConversation(scenario.conversationLines);
      expect(pipelineDirectAnalysis.riskScore, equals(directAnalysis.riskScore));
    });

    test('9. Unsupported microphone source throws typed error in mock service', () async {
      const micInput = AudioInput(
        sourceType: AudioSourceType.microphone,
        label: 'Live Microphone Track',
      );

      expect(
        () => speechService.transcribeAudio(micInput),
        throwsA(
          isA<SpeechToTextException>().having(
            (e) => e.errorType,
            'errorType',
            equals(SpeechToTextErrorType.unsupportedAudioSource),
          ),
        ),
      );
    });

    test('10. Pipeline processAudioSafe handles errors gracefully and yields Safe baseline', () async {
      final emptyInput = AudioInput.empty();

      final safeAnalysis = await pipeline.processAudioSafe(emptyInput);

      expect(safeAnalysis.riskLevel, equals(RiskLevel.safe));
      expect(safeAnalysis.riskScore, equals(0));
      expect(
        safeAnalysis.explanations.any((e) => e.contains('Audio processing bypassed')),
        isTrue,
      );
    });

    test('11. AudioInput metadata initializes correctly from scenario', () {
      final scenario = DemoScenarios.all.first;
      final input = AudioInput.fromScenario(scenario);

      expect(input.sourceType, equals(AudioSourceType.mockScenario));
      expect(input.label, equals(scenario.title));
      expect(input.hasAudioData, isTrue);
      expect(input.duration, isNotNull);
      expect(input.simulatedLines?.length, equals(scenario.conversationLines.length));
    });

    test('12. transcribeSafe returns SpeechTranscriptionResult wrapper', () async {
      final scenario = DemoScenarios.all.first;
      final successInput = AudioInput.fromScenario(scenario);
      final successResult = await speechService.transcribeSafe(successInput);

      expect(successResult.isSuccess, isTrue);
      expect(successResult.error, isNull);
      expect(successResult.lines, isNotEmpty);

      final failureResult = await speechService.transcribeSafe(AudioInput.empty());
      expect(failureResult.isSuccess, isFalse);
      expect(failureResult.error, isNotNull);
      expect(failureResult.error!.errorType, equals(SpeechToTextErrorType.emptyAudio));
      expect(failureResult.lines, isEmpty);
    });
  });
}
