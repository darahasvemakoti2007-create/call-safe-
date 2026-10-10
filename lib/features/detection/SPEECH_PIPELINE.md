# GuardCall Speech-to-Text & Audio Pipeline Architecture

## 1. What is Speech-to-Text (STT)?
Speech-to-Text (also referred to as Automatic Speech Recognition or ASR) is the algorithmic process of converting spoken acoustic audio signals into readable, structured written text. 

In GuardCall, STT translates spoken dialogue turns from incoming or outgoing audio into chronological `ConversationLine` objects:
```
Acoustic Audio Waveform  ──▶  Phoneme & Acoustic Modeling  ──▶  Structured Text (Speaker + Utterance)
```

---

## 2. Why GuardCall Needs STT Before Conversational Analysis
Scam callers exploit psychological manipulation tactics:
- Impersonating authoritative entities (police, tax bureaus, bank fraud departments).
- Fabricating urgent time pressure and deadlines.
- Demanding immediate financial transfers (gift cards, wire transfers, crypto, instant UPI).
- Soliciting confidential authentication credentials (OTPs, PINs, passwords).
- Attempting emotional coercion and isolation.

To detect these behavioral tactics, GuardCall's **Scam Detection Engine** evaluates semantic phrases, syntactic framing, and psychological patterns. Converting speech into text turns enables:
1. **Semantic Pattern Matching:** Transparent regex, keyword heuristics, and NLP token analysis.
2. **Explainable AI:** Explicitly citing verbatim phrases (e.g., *"arrest warrant"*, *"share the 6-digit OTP"*) in user-facing warning dialogs.
3. **Low-Latency On-Device Processing:** Processing text tokens requires a fraction of the compute and memory footprint required for raw audio signal classification.

---

## 3. Why the Prototype Uses a Mock STT Implementation
This prototype implements `MockSpeechToTextService` rather than a live acoustic model:
- **Deterministic Hackathon Demos:** Demonstrations remain 100% reliable, reproducible, and impervious to noisy demo rooms, background chatter, or network dropouts.
- **Zero Third-Party Cloud Dependencies:** No API keys, cloud billing accounts, or proprietary speech SDKs are needed to build, test, and evaluate the application.
- **Architectural Decoupling:** By establishing the `SpeechToTextService` interface early, future on-device speech engines can be plugged in without refactoring UI screens or detection logic.

> [!NOTE]
> `MockSpeechToTextService` is a deterministic, offline component strictly designed for simulated scenario playback and automated unit/widget testing. It performs zero external network calls.

---

## 4. Why Real Microphone Input is Different from Cellular-Call Audio
A common misconception in mobile security apps is conflating **microphone recording** with **cellular phone call audio capture**:

| Capability | Device Microphone Input | Cellular Call Audio Capture (Both Parties) |
| :--- | :--- | :--- |
| **API Availability** | Standard Android `AudioRecord` / `MediaRecorder` API | Heavily restricted; no universal third-party API |
| **Hardware Path** | Captures ambient physical audio around phone | Routed through cellular baseband chip and Telecom HAL |
| **Speaker Audio** | Captures only what the phone's physical mic hears | Requires capturing remote party downlink stream |
| **Use Cases** | In-person conversations, voice memos, speakerphone | Private phone calls, cellular carrier conversations |

---

## 5. Android Cellular Call Recording Restrictions
Modern Android versions (starting prominently with Android 9 Pie and reinforced in Android 10, 11, 12, 13, and 14) enforce strict security and privacy boundaries:
1. **Deprecation of Call Audio Streams:** The `VOICE_CALL`, `VOICE_UPLINK`, and `VOICE_DOWNLINK` audio sources were locked down from general third-party applications.
2. **Accessibility API Bans:** Google Play policies strictly prohibit using Android Accessibility Services for background call audio recording.
3. **Carrier and Regional Privacy Laws:** Wiretapping and two-party consent laws vary across jurisdictions. Android enforces OS-level sandboxing so unprivileged apps cannot secretly eavesdrop on telephony streams.

---

## 6. Why the Hackathon Demo Must Not Claim Universal Call Recording
It is technically inaccurate and ethically misleading to claim that an unprivileged Flutter mobile app can monitor or intercept arbitrary incoming cellular calls across arbitrary Android devices. 

GuardCall's presentation and codebase explicitly clarify:
- All scenarios inside Demo Center are **simulated calls**.
- No background cellular tapping or covert call recording is active.
- Warnings and intervention dialogs operate on simulated transcript dialogue.

---

## 7. Future Production Implementation Pathways
A future production-grade version of GuardCall can support legitimate conversational protection via:
1. **User-Provided Audio:** Users may submit pre-recorded voice notes, call recordings, or voicemails for post-call forensic scam analysis.
2. **Permitted Microphone Capture (Speakerphone Mode):** With explicit user consent and runtime permissions, GuardCall can listen via the device microphone when a call is placed on speakerphone or during in-person interactions.
3. **OEM / Carrier Integration:** Partnering with telecommunication carriers or smartphone manufacturers with system-level (`privileged`) telephony access to process real-time call audio directly in the baseband dialer.
4. **Platform-Supported Accessibility / Telecom APIs:** Utilizing enterprise device administration profiles or carrier-authorized call screening services where legally authorized.

---

## 8. Privacy by Design: Audio Handling Principles
GuardCall is built around strict data privacy tenets:
- **No Permanent Raw Audio Storage:** Raw audio buffers should never be saved to persistent disk or flashed to external storage by default.
- **Zero Cloud Audio Uploads:** Audio is processed locally into text representations. Acoustic audio is discarded immediately after phonetic tokenization.
- **Transient Ephemeral Memory:** In-memory audio buffers exist only during active transcription and are scrubbed upon completion or cancellation.
- **Local Call History Only:** Call history records retain only high-level risk scores, timestamp, and triggered signal categories—never full audio recordings.

---

## 9. Provider Architecture (Step 12 Implementation)
The GuardCall pipeline swaps speech backends seamlessly by adhering to the `SpeechToTextService` abstraction and `STTProviderFactory`:

```
                      ┌───────────────────────────┐
                      │   SpeechToTextService     │ (Abstract Contract)
                      └─────────────┬─────────────┘
                                    │
         ┌──────────────────────────┴──────────────────────────┐
         │                                                     │
┌────────┴──────────────┐                           ┌──────────┴──────────────┐
│MockSpeechToTextService│                           │RemoteSpeechToTextService│
│ (Default / Offline:   │                           │ (Step 12 Provider:      │
│  Deterministic Demo)  │                           │  OpenAI Whisper / Cloud)│
└───────────────────────┘                           └─────────────────────────┘
```

### Step 12 Speech Provider Details:
- **`MockSpeechToTextService`:** Deterministic offline playback used for hackathon evaluations and unit tests.
- **`RemoteSpeechToTextService`:** Direct client for **LOCAL DEVELOPMENT ONLY**. Implements remote transcription calls with strict audio validation, configurable timeouts, network resilience, and typed exceptions (`SpeechToTextException`).
- **`STTProviderFactory`:** Resolves the appropriate service instance dynamically based on `AppConfig` (`STT_BACKEND=mock|direct_dev|edge_function`), defaulting safely to mock mode.
- **Privacy Guarantee:** Even when using remote STT, raw audio buffers are never saved to persistent storage or uploaded to Supabase.

---

## 10. Secure Backend Proxy: Edge Function Speech-to-Text (Step 13)
In production, mobile applications must never hold speech recognition provider secrets (e.g. OpenAI Whisper API keys). GuardCall routes production transcription requests through the authenticated `guardcall-stt` Supabase Edge Function:

```
Flutter Client (Audio Buffer + User JWT)
   │
   ▼ (HTTPS / TLS)
Supabase Edge Function: guardcall-stt
   │ 1. Validates user JWT authentication (401 on failure)
   │ 2. Validates audio format and 10MB payload size limit (400 on failure)
   │ 3. Injects server-side Deno.env.get('SPEECH_TO_TEXT_API_KEY')
   │ 4. Calls speech transcription provider (OpenAI Whisper)
   │ 5. Discards raw audio from memory immediately (ZERO database/bucket storage)
   ▼
Structured Conversation Turns
   │
   ▼
Flutter Client
```

### STT Backend Modes:
1. **`mock` (Default):** Zero network calls, uses predefined transcripts.
2. **`direct_dev`:** Direct client-to-Whisper connection for local development only.
3. **`edge_function`:** Production architecture where keys are held safely on the backend.


