# GuardCall — Speech-to-Text (STT) Pipeline & Audio Ingestion

## 1. Architectural Overview

The GuardCall Speech-to-Text pipeline transforms acoustic audio data into typed dialogue structures (`List<ConversationLine>`) suitable for scam detection:

```
AudioInput
    ↓
[Audio Source Validation & Type Checks]
    ↓
SpeechToTextService (Mock / Remote / Edge Proxy)
    ↓
[Transcript Normalization & Speaker Attribution]
    ↓
List<ConversationLine> (Empty Transcripts Rejected)
    ↓
ConversationPipeline Orchestrator
```

---

## 2. Supported STT Providers

| Mode | `STT_BACKEND` | Implementation | Execution Target | Network |
| :--- | :--- | :--- | :--- | :--- |
| **OFFLINE MOCK** *(Default)* | `mock` | `MockSpeechToTextService` | In-Memory Deterministic | **None** |
| **DIRECT DEVELOPMENT** | `direct_dev` | `RemoteSpeechToTextService` | Direct Whisper API | Third-Party API |
| **EDGE FUNCTION** | `edge_function` | `EdgeFunctionSpeechToTextService` | Supabase `guardcall-stt` | TLS to Supabase Edge |

---

## 3. Speaker Attribution & Diarization Reality

### Technical Limitation of Speech Recognition:
Standard automated speech recognition models (such as OpenAI Whisper) do **not** perform speaker diarization on single-channel monaural voice audio. They return a single unsegmented stream of transcribed text without knowing whether words originated from the caller or the senior receiving the call.

### GuardCall Handling:
1. **Whisper Raw Text:** When Whisper outputs raw text, GuardCall segments sentences chronologically and defaults speaker attribution to `Speaker.caller` (the potential threat actor).
2. **Structured Multi-Line Payloads:** When testing with structured multi-speaker fixtures, speaker keys (`"caller"`, `"user"`) are mapped cleanly to `Speaker.caller` and `Speaker.user`.
3. **Honest Engineering:** GuardCall does **not** falsely claim that Whisper can magically distinguish telephone caller voices from receiver voices without multi-channel telephony hardware or dedicated diarization pipelines.

---

## 4. Platform Security & Cellular Call Capture Boundaries

### Platform Reality:
Standard Android releases (including Android API 37) explicitly restrict third-party user applications from intercepting, tapping, or recording live cellular voice calls. This protection is enforced by Android OS sandbox permissions (`android.permission.CAPTURE_AUDIO_OUTPUT` is restricted to system-signed firmware).

### Current Prototype Scope:
**GuardCall currently demonstrates conversation analysis through simulated/demo audio, pre-recorded audio files, and controlled audio inputs.**

The application does **not** implement or claim to implement:
- Covert cellular call interception
- `CallScreeningService` telephony hooks
- Baseband audio tapping

---

## 5. Privacy Guarantees

1. **Zero Raw Audio Persistence:** Neither the mobile client nor the Supabase Edge Functions store raw audio bytes or recordings on disk or in database tables.
2. **Ephemeral Memory:** Audio buffers are held in volatile RAM only for the duration of transcription and are immediately discarded.
3. **Credential Isolation:** In production Edge Function mode, Whisper API keys remain server-side in Supabase Edge Secrets. The client device never possesses third-party speech credentials.
