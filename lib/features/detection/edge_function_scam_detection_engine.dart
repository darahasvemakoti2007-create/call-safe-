import 'dart:developer' as developer;

import '../../core/services/guardcall_edge_function_client.dart';
import '../demo/demo_scenario.dart';
import 'detection_exception.dart';
import 'mock_scam_detection_engine.dart';
import 'risk_analysis.dart';
import 'scam_detection_engine.dart';

/// Production scam detection engine that routes analysis through GuardCall
/// Supabase Edge Functions.
///
/// In production, no external AI provider credentials reside on the mobile device.
/// All conversation analysis requests are securely proxied through authenticated
/// Edge Functions (`guardcall-ai-analyze`), preserving API secret confidentiality.
class EdgeFunctionScamDetectionEngine implements ScamDetectionEngine {
  final GuardCallEdgeFunctionClient edgeClient;
  final ScamDetectionEngine? fallbackEngine;
  final bool enableFallback;

  EdgeFunctionScamDetectionEngine({
    required this.edgeClient,
    this.fallbackEngine = const MockScamDetectionEngine(),
    this.enableFallback = false,
  });

  @override
  Future<RiskAnalysis> analyzeConversation(List<ConversationLine> conversation) async {
    if (conversation.isEmpty) {
      return RiskAnalysis.safe(explanations: ['No conversation lines to analyze.']);
    }

    try {
      return await edgeClient.analyzeConversation(conversation);
    } on DetectionException catch (e) {
      if (enableFallback && fallbackEngine != null) {
        developer.log('Edge Function AI failed ($e). Falling back to local heuristic engine.');
        return fallbackEngine!.analyzeConversation(conversation);
      }
      rethrow;
    } catch (e) {
      if (enableFallback && fallbackEngine != null) {
        developer.log('Edge Function AI unexpected error ($e). Falling back to local heuristic engine.');
        return fallbackEngine!.analyzeConversation(conversation);
      }
      throw DetectionException(
        DetectionErrorType.providerUnavailable,
        'Edge Function AI analysis failed: $e',
      );
    }
  }
}
