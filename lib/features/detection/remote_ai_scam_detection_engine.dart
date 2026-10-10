import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../../core/services/ai_http_client.dart';
import '../demo/demo_scenario.dart';
import 'detection_exception.dart';
import 'mock_scam_detection_engine.dart';
import 'risk_analysis.dart';
import 'scam_detection_engine.dart';
import 'scam_signal.dart';

/// LOCAL DEVELOPMENT ONLY — Direct external AI client.
///
/// In production architecture, mobile applications must NOT embed provider API
/// keys. All production AI analysis requests route through the authenticated
/// [GuardCallEdgeFunctionClient] and Supabase Edge Functions.
///
/// This direct client is maintained strictly for local developer experimentation,
/// unit test fixtures, and mock verification.
class RemoteAIScamDetectionEngine implements ScamDetectionEngine {
  final String provider; // 'openai' or 'gemini'
  final String apiKey;
  final Uri? endpoint;
  final Duration timeout;
  final AIHttpClient httpClient;
  final ScamDetectionEngine? fallbackEngine;
  final bool enableFallback;

  RemoteAIScamDetectionEngine({
    this.provider = 'openai',
    required this.apiKey,
    this.endpoint,
    this.timeout = const Duration(seconds: 10),
    AIHttpClient? httpClient,
    this.fallbackEngine = const MockScamDetectionEngine(),
    this.enableFallback = false,
  }) : httpClient = httpClient ?? const DefaultAIHttpClient();

  /// Default API endpoint for the selected provider.
  Uri get resolvedEndpoint {
    if (endpoint != null) return endpoint!;
    if (provider.toLowerCase() == 'gemini') {
      return Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
      );
    }
    return Uri.parse('https://api.openai.com/v1/chat/completions');
  }

  @override
  Future<RiskAnalysis> analyzeConversation(List<ConversationLine> conversation) async {
    if (conversation.isEmpty) {
      return RiskAnalysis.safe(explanations: ['No conversation lines to analyze.']);
    }

    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty || cleanKey.contains('your-') || cleanKey.contains('placeholder')) {
      if (enableFallback && fallbackEngine != null) {
        developer.log('Remote AI key unconfigured. Falling back to local heuristic engine.');
        return fallbackEngine!.analyzeConversation(conversation);
      }
      throw const DetectionException(
        DetectionErrorType.missingApiKey,
        'Remote AI API key is missing or not configured.',
      );
    }

    try {
      final formattedPrompt = _buildPrompt(conversation);
      final headers = _buildHeaders(cleanKey);
      final body = _buildRequestBody(formattedPrompt);

      final responseBody = await httpClient
          .post(url: resolvedEndpoint, headers: headers, body: body, timeout: timeout)
          .timeout(timeout);

      return parseStructuredOutput(responseBody);
    } on TimeoutException {
      if (enableFallback && fallbackEngine != null) {
        developer.log('Remote AI timed out. Falling back to local heuristic engine.');
        return fallbackEngine!.analyzeConversation(conversation);
      }
      throw DetectionException(
        DetectionErrorType.timeout,
        'Remote AI provider timed out after ${timeout.inSeconds} seconds.',
      );
    } on SocketException catch (e) {
      if (enableFallback && fallbackEngine != null) {
        developer.log('Remote AI network error ($e). Falling back to local heuristic engine.');
        return fallbackEngine!.analyzeConversation(conversation);
      }
      throw DetectionException(
        DetectionErrorType.networkFailure,
        'Network failure connecting to remote AI provider: ${e.message}',
      );
    } on HttpException catch (e) {
      if (enableFallback && fallbackEngine != null) {
        return fallbackEngine!.analyzeConversation(conversation);
      }
      throw DetectionException(
        DetectionErrorType.networkFailure,
        'Remote AI provider HTTP error: ${e.message}',
      );
    } on DetectionException {
      if (enableFallback && fallbackEngine != null) {
        return fallbackEngine!.analyzeConversation(conversation);
      }
      rethrow;
    } catch (e) {
      if (enableFallback && fallbackEngine != null) {
        return fallbackEngine!.analyzeConversation(conversation);
      }
      throw DetectionException(
        DetectionErrorType.providerUnavailable,
        'Failed to analyze conversation via remote AI: $e',
      );
    }
  }

  /// Builds request headers based on the provider.
  Map<String, String> _buildHeaders(String key) {
    if (provider.toLowerCase() == 'gemini') {
      return {'Content-Type': 'application/json'};
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $key',
    };
  }

  /// Formats the conversation into a structured analysis prompt.
  String _buildPrompt(List<ConversationLine> conversation) {
    final buffer = StringBuffer();
    buffer.writeln(
      'You are GuardCall, an AI protecting seniors from phone scams. Analyze this phone conversation transcript for manipulation:\n',
    );
    for (final line in conversation) {
      final speaker = line.speaker == Speaker.caller ? 'CALLER' : 'USER';
      buffer.writeln('$speaker: ${line.text}');
    }
    buffer.writeln('\nRespond STRICTLY with this JSON structure without markdown formatting:');
    buffer.writeln('''
{
  "risk_score": 0-100,
  "confidence": 0.0-1.0,
  "signals": [
    {
      "type": "urgency" | "fear_threat" | "authority_impersonation" | "sensitive_information_request" | "financial_pressure" | "isolation" | "emotional_manipulation" | "remote_access_request" | "suspicious_link",
      "severity": "low" | "medium" | "high" | "critical",
      "explanation": "concise plain text rationale"
    }
  ],
  "summary": "plain English explanation for an elderly person"
}''');
    return buffer.toString();
  }

  /// Constructs the JSON payload for OpenAI or Gemini.
  String _buildRequestBody(String prompt) {
    if (provider.toLowerCase() == 'gemini') {
      return jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        }
      });
    }

    return jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {'role': 'system', 'content': 'You are a phone scam detection system that outputs strictly structured JSON.'},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.1,
      'response_format': {'type': 'json_object'},
    });
  }

  /// Parses and strictly validates structured JSON from an AI provider.
  static RiskAnalysis parseStructuredOutput(String rawResponse) {
    dynamic decoded;
    try {
      decoded = jsonDecode(rawResponse);
    } catch (e) {
      throw DetectionException(
        DetectionErrorType.invalidJson,
        'Failed to parse JSON response: $e',
      );
    }

    Map<String, dynamic> data;
    if (decoded is Map<String, dynamic>) {
      // If wrapped in OpenAI response: choices[0].message.content
      if (decoded.containsKey('choices') && decoded['choices'] is List && (decoded['choices'] as List).isNotEmpty) {
        final choice = decoded['choices'][0];
        final content = choice['message']?['content'];
        if (content is String) {
          try {
            data = jsonDecode(content) as Map<String, dynamic>;
          } catch (_) {
            throw const DetectionException(
              DetectionErrorType.invalidJson,
              'Malformed JSON inside message content.',
            );
          }
        } else {
          throw const DetectionException(DetectionErrorType.invalidOutput, 'Missing choices message content.');
        }
      } else if (decoded.containsKey('candidates') && decoded['candidates'] is List && (decoded['candidates'] as List).isNotEmpty) {
        // If wrapped in Gemini response: candidates[0].content.parts[0].text
        final candidate = decoded['candidates'][0];
        final text = candidate['content']?['parts']?[0]?['text'];
        if (text is String) {
          try {
            data = jsonDecode(text) as Map<String, dynamic>;
          } catch (_) {
            throw const DetectionException(
              DetectionErrorType.invalidJson,
              'Malformed JSON inside Gemini part text.',
            );
          }
        } else {
          throw const DetectionException(DetectionErrorType.invalidOutput, 'Missing Gemini candidate text.');
        }
      } else {
        data = decoded;
      }
    } else {
      throw const DetectionException(
        DetectionErrorType.invalidOutput,
        'Expected JSON object from AI provider.',
      );
    }

    // 1. Validate risk_score
    if (!data.containsKey('risk_score') || data['risk_score'] is! num) {
      throw const DetectionException(
        DetectionErrorType.invalidOutput,
        'Response missing valid numeric "risk_score".',
      );
    }
    final rawScore = (data['risk_score'] as num).toDouble();
    if (rawScore < 0.0 || rawScore > 100.0) {
      throw DetectionException(
        DetectionErrorType.invalidOutput,
        'Risk score $rawScore is outside the valid 0–100 boundary.',
      );
    }
    final riskScore = rawScore.round();

    // 2. Validate confidence
    if (!data.containsKey('confidence') || data['confidence'] is! num) {
      throw const DetectionException(
        DetectionErrorType.invalidOutput,
        'Response missing valid numeric "confidence".',
      );
    }
    final confidence = (data['confidence'] as num).toDouble();
    if (confidence < 0.0 || confidence > 1.0) {
      throw DetectionException(
        DetectionErrorType.invalidOutput,
        'Confidence $confidence is outside the valid 0.0–1.0 boundary.',
      );
    }

    // 3. Validate signals
    final signalsList = <ScamSignal>[];
    final explanationsList = <String>[];

    if (data.containsKey('signals')) {
      if (data['signals'] is! List) {
        throw const DetectionException(
          DetectionErrorType.invalidOutput,
          '"signals" field must be a list.',
        );
      }

      final rawSignals = data['signals'] as List;
      for (final s in rawSignals) {
        if (s is! Map<String, dynamic>) {
          throw const DetectionException(
            DetectionErrorType.invalidOutput,
            'Each signal must be a JSON object.',
          );
        }

        final rawType = (s['type'] as String? ?? '').trim().toLowerCase();
        final signalType = _mapSignalType(rawType);
        if (signalType == null) {
          throw DetectionException(
            DetectionErrorType.unknownSignalType,
            'Unknown or unsupported scam signal type: "$rawType".',
          );
        }

        final explanation = (s['explanation'] as String? ?? '').trim();
        if (explanation.isEmpty) {
          throw const DetectionException(
            DetectionErrorType.invalidOutput,
            'Signal explanation must be non-empty.',
          );
        }

        signalsList.add(
          ScamSignal(
            type: signalType,
            explanation: explanation,
          ),
        );
        explanationsList.add(explanation);
      }
    }

    if (data.containsKey('summary') && data['summary'] is String && (data['summary'] as String).isNotEmpty) {
      explanationsList.insert(0, (data['summary'] as String).trim());
    }

    if (explanationsList.isEmpty) {
      explanationsList.add(
        riskScore < 40
            ? 'No significant scam indicators identified.'
            : 'Potential scam activity detected.',
      );
    }

    return RiskAnalysis(
      riskScore: riskScore,
      detectedSignals: signalsList,
      explanations: explanationsList,
      confidence: confidence,
      timestamp: DateTime.now(),
    );
  }

  /// Maps string identifiers to canonical [ScamSignalType] enums.
  static ScamSignalType? _mapSignalType(String raw) {
    final clean = raw.replaceAll(RegExp(r'[-_\s/]'), '').toLowerCase();
    switch (clean) {
      case 'urgency':
      case 'timepressure':
        return ScamSignalType.urgency;
      case 'fearthreat':
      case 'threat':
      case 'fear':
      case 'legalthreat':
        return ScamSignalType.fearThreat;
      case 'authorityimpersonation':
      case 'impersonation':
      case 'fakeofficial':
        return ScamSignalType.authorityImpersonation;
      case 'sensitiveinformationrequest':
      case 'sensitiveinformation':
      case 'otpsolicitation':
      case 'otprequest':
      case 'pinrequest':
        return ScamSignalType.sensitiveInformationRequest;
      case 'financialpressure':
      case 'paymentrequest':
      case 'wiretransfer':
      case 'moneyrequest':
        return ScamSignalType.financialPressure;
      case 'isolation':
      case 'secrecy':
        return ScamSignalType.isolation;
      case 'emotionalmanipulation':
      case 'familydistress':
      case 'grandchildemergency':
        return ScamSignalType.emotionalManipulation;
      case 'remoteaccessrequest':
      case 'remoteaccess':
      case 'screensharing':
        return ScamSignalType.remoteAccessRequest;
      case 'suspiciouslink':
      case 'paymentlink':
      case 'phishinglink':
        return ScamSignalType.suspiciousLink;
      default:
        return null;
    }
  }
}
