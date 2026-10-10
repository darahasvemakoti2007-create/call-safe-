import '../../core/services/guardcall_edge_function_client.dart';
import '../demo/demo_scenario.dart';
import 'audio_input.dart';
import 'speech_to_text_service.dart';

/// Production speech-to-text service that routes audio transcription through
/// GuardCall Supabase Edge Functions.
///
/// In production, provider API keys (Whisper/STT) reside strictly in Edge Function
/// secrets. The Flutter client only communicates via authenticated Supabase requests.
///
/// PLATFORM LIMITATIONS:
/// 1. Only explicitly provided audio inputs are processed (test fixtures, pre-recorded audio,
///    controlled mic inputs).
/// 2. Does NOT intercept cellular phone calls.
/// 3. Zero raw audio persistence in Supabase storage or databases.
class EdgeFunctionSpeechToTextService extends SpeechToTextService {
  final GuardCallEdgeFunctionClient edgeClient;

  EdgeFunctionSpeechToTextService({required this.edgeClient});

  @override
  Future<List<ConversationLine>> transcribeAudio(AudioInput input) async {
    return edgeClient.transcribeAudio(input);
  }
}
