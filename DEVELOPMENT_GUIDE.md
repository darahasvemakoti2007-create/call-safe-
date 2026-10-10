# GuardCall — Developer & Engineering Guide

## 1. Overview
This guide provides development standards, architectural rules, and security guidelines for engineers and contributors to GuardCall.

---

## 2. Hardening Policies

### 1. Logging Policy (`AppLogger`)
- **NEVER** use `print()`, `debugPrint()`, or direct `developer.log()` for operational code.
- Always use `AppLogger.debug()`, `AppLogger.info()`, `AppLogger.warning()`, or `AppLogger.error()`.
- The logger automatically sanitizes credentials (`Bearer`, `apiKey`, `password`, `otp`, `pin`, `cvv`).
- Never pass raw audio buffers, dialogue transcripts, or authentication tokens into log messages.
- In release builds, debug logs are completely suppressed.

### 2. Configuration & Secret Management
- Real secrets must NEVER be committed to Git.
- `.env` is ignored by Git; `.env.example` contains only harmless placeholders.
- Client Flutter code must NEVER reference or require Supabase `service_role` keys or provider private keys.
- Production AI and STT calls must always route through authenticated Supabase Edge Functions (`guardcall-ai-analyze`, `guardcall-stt`).

### 3. Accessibility & UX Guidelines
- **Target Audience:** Seniors and elderly individuals.
- **Typography:** Primary text must be legible (14sp+ body, bold headings).
- **Touch Targets:** All interactive buttons must have a minimum tap height of 48dp.
- **Color Independence:** Never communicate risk status by color alone; always pair text labels (`Safe`, `Suspicious`, `High Risk`, `Critical Threat`) with dedicated icons and scores.
- **Reduce Motion:** Always respect `AccessibilityPreferences.instance.reduceMotion`. When enabled, animations must be reduced or disabled, and intense glowing shadows replaced with subtle contrast borders.
- **Destructive Actions:** Actions like Sign Out, Revoking Invitations, and Clearing History must prompt for user confirmation.

### 4. Risk Threshold Canonical Definitions
Always use `RiskLevelScore.fromScore(score)`:
- `0–39`: Safe
- `40–70`: Suspicious
- `71–84`: High Risk
- `85–100`: Critical Threat
Never implement local ad-hoc threshold comparisons (e.g. `score >= 75`) that conflict with canonical tiers.

---

## 3. Testing & Verification

Run tests:
```bash
flutter test
```
Analyze code:
```bash
flutter analyze
```

---

## 4. Current Prototype Limitations
- Supabase deployment remains postponed.
- Outward notifications are simulated locally in-memory.
- Live cellular call audio recording is restricted by Android OS; controlled demo scenarios and speakerphone microphone mode provide safe demonstration.

---

## 5. Live Microphone Audio Shield (Step 5 Foundation)

### 1. Architecture & Capabilities
- **Consent-Based Capture:** Microphone activates exclusively when the user explicitly taps **"Start Microphone Shield"** and halts immediately on **"Stop"**.
- **Ambient & Speakerphone Scope:** Evaluates acoustic speech captured by the physical device microphone (suitable for in-person conversations or calls placed on speakerphone).
- **Android Telephony Limitations:** Standard Android security sandboxes incoming cellular telephony streams at the hardware/baseband HAL level. GuardCall operates within honest platform boundaries and does not claim background cellular call wiretapping.
- **Zero-Audio Persistence:** Audio buffers are processed ephemerally in volatile memory for transcription and immediately scrubbed. No raw audio files are written to disk.

### 2. Speech-to-Text Setup Requirements
To enable live cloud speech recognition:
1. **Production Target (Supabase Edge Function Proxy):**
   - Deploy `guardcall-stt` Edge Function in your Supabase project.
   - Provider API keys (Whisper/Google STT) stay securely in Supabase server secrets (`supabase secrets set STT_API_KEY=...`).
   - Configure `.env`:
     ```bash
     SUPABASE_URL=https://<your-project-id>.supabase.co
     SUPABASE_ANON_KEY=<your-anon-key>
     USE_SUPABASE=true
     STT_BACKEND=edge_function
     ```
2. **Local Developer Direct STT:**
   - Configure `.env`:
     ```bash
     USE_CLOUD_STT=true
     STT_BACKEND=direct_dev
     STT_PROVIDER=remote
     SPEECH_TO_TEXT_API_KEY=<provider-api-key>
     ```
3. **Offline / Test Automation Default:**
   - Defaults safely to `STT_BACKEND=mock` without making external network calls.

---

## 6. Real Microphone Capture & STT Validation (Step 6)

### 1. Audio Capture Pipeline Specifications
- **Format:** 16,000 Hz, 16-bit linear PCM, 1 channel (Mono).
- **Encoding:** `audio/pcm;rate=16000;channels=1`.
- **Buffer Scope:** Ephemeral in-memory streaming; buffers are discarded immediately after transcription.
- **Hardware Binding:** Without external native audio plugins, `DefaultMicrophoneAudioCaptureService` operates as an in-memory stream adapter with amplitude visualizer and PCM chunk passthrough. When integrating native audio packages (e.g. `record` or custom Android MethodChannels), PCM chunks are fed directly via `feedAudioBytes(List<int> bytes)`.

### 2. Expected Behavior When Offline or Unconfigured
- **Honest UI Indicators:** If no STT backend is configured, the UI clearly displays:
  - Header badge: `ACOUSTIC ONLY` / `STANDBY` (never claims `LIVE RECOGNIZER ACTIVE`).
  - Pipeline status: `Speech Recognizer (ASR): Offline / Unconfigured`.
  - Transcript section: Labeled as `Manual Speech Test: Type spoken phrases here to test scam heuristics without a live ASR backend.`
- **Zero Silent Fallback:** The application never generates fake transcripts or claims speech recognition occurred when operating offline.

### 3. Android Device Testing Procedure
When testing on a real Android device or emulator:
1. **Microphone Permission:**
   - Launch app -> Navigate to **Calls** -> Tap **Start Microphone Shield**.
   - Verify Android runtime permission prompt appears (`RECORD_AUDIO`).
   - Test **Deny**: Verify error message surfaces clearly.
   - Test **Settings**: Verify permanently denied prompt routes to device settings.
   - Test **Grant**: Verify capture begins with live amplitude meter.
2. **Speakerphone / Ambient Call Testing:**
   - Place a second phone on speakerphone next to the test device.
   - Speak phrases containing compounding scam tokens:
     * *"This is police investigation regarding arrest warrant, transfer money immediately."*
   - Verify risk score escalates to **Critical Threat (85+)**.
   - Verify single warning intervention popup fires without duplicate spam on partial updates.
3. **Interruption & Resource Cleanup:**
   - Trigger an incoming phone call or press the home button.
   - Verify capture pauses or stops cleanly without leaking audio drivers.
4. **Logcat Monitoring:**
   ```bash
   adb logcat -s Flutter | grep -i "microphone"
   ```

### 4. Privacy & Telephony Boundaries
- Standard Android security prohibits third-party user applications from recording or intercepting cellular telephone call audio directly (`VOICE_CALL` audio source is restricted to system dialers).
- GuardCall operates honestly in ambient/speakerphone mode and does not claim background cellular wiretapping.

---

## 7. Native Android AudioRecord Capture (Step 7)

### 1. Native Platform Channel Architecture
To achieve optimal latency and 100% compliant audio capture without third-party plugin version conflicts, GuardCall implements a direct Android SDK `AudioRecord` platform channel:

- **MethodChannel (`guardcall/audio_capture`):**
  - `isAvailable`: Verifies physical microphone hardware via `PackageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)`.
  - `checkPermission`: Checks `ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)`.
  - `requestPermission`: Requests runtime permission via `ActivityCompat.requestPermissions` and returns `'granted'`, `'denied'`, or `'permanentlyDenied'`.
  - `getAudioFormat`: Returns map with `sampleRate: 16000`, `channelCount: 1`, `bitDepth: 16`, `encoding: "audio/pcm;rate=16000;channels=1"`.
  - `startCapture`: Initializes `AudioRecord(MediaRecorder.AudioSource.MIC, 16000, CHANNEL_IN_MONO, ENCODING_PCM_16BIT, bufferSize)` and spawns background recording thread `GuardCallNativeAudioRecorder`.
  - `stopCapture`: Gracefully interrupts recording thread, stops and releases `AudioRecord` native hardware driver.
  - `isCapturing`: Returns atomic capture status.

- **EventChannel (`guardcall/audio_stream`):**
  - Streams raw `ByteArray` chunks directly from native `AudioRecord.read` loop into Flutter's Dart engine over `EventSink.success(chunk)`.
  - Posts errors (`EventSink.error`) on driver error or read failure.
  - Releases resources in `onDestroy()` and stream cancellation.

### 2. Dart Capture Pipeline Integration
- **`DefaultMicrophoneAudioCaptureService`:**
  - Manages `MethodChannel` and `EventChannel` lifecycle.
  - Dynamically sets `isHardwareBound = true` when native hardware recording is active and usable.
  - In automated test and non-Android environments, falls back gracefully to in-memory mode (`isHardwareBound = false`).
  - Converts incoming 16-bit linear PCM byte buffers into normalized Root-Mean-Square (RMS) amplitude levels `[0.0, 1.0]` to drive the visualizer with real acoustic dynamics.
  - Forwards raw PCM byte chunks directly into `audioDataStream` and `LiveSpeechRecognitionService.processAudioBytes`.

### 3. Verification & Privacy Controls
- **Zero File Persistence:** Audio bytes are never written to disk, SQLite, shared preferences, or device storage.
- **Truthful Status:** `LiveMicrophoneController` inspects `isHardwareBound` to update diagnostics (`Capturing Live Audio (16000Hz • Mono • 16-bit)` vs `Active Capture (16000Hz • Mono • 16-bit, Volatile Buffer)`).
- **Physical Device Testing Steps:**
  1. Connect Android device or launch Android emulator:
     ```bash
     flutter devices
     flutter run -d <device-id>
     ```
  2. Navigate to **Calls** -> **Start Microphone Shield**.
  3. Grant `RECORD_AUDIO` permission in the system dialog.
  4. Verify the **Pipeline Diagnostics** card reflects:
     - `Microphone Permission: GRANTED`
     - `Audio Capture: Capturing Live Audio (16000Hz • Mono • 16-bit)`
  5. Speak into the microphone; observe real-time waveform reacting to vocal amplitude.
  6. Tap **Stop Shield**; verify `AudioRecord` stops and native audio resources are released immediately.

---

## 8. Genuine Live Speech-to-Text Pipeline (Step 8)

### 1. Audio Container & Chunk Aggregation Architecture
Raw 16-bit linear PCM microphone streams (produced every ~128ms) cannot be submitted directly as complete recordings to batch STT engines. GuardCall implements a bounded in-memory aggregation pipeline:

- **WAV Packaging (`WavEncoder`):** Converts raw linear PCM byte buffers into standard 44-byte RIFF/WAVE (`audio/wav`) containers at 16,000 Hz, 1 channel (Mono), 16 bits per sample.
- **Bounded In-Memory Buffer:**
  - `bufferThresholdBytes: 48000` (~1.5 seconds of speech): Accumulates micro-chunks in volatile RAM before dispatching to the STT backend.
  - `maxBufferSize: 160000` (5.0 seconds maximum): Strict upper bound that trims oldest samples to prevent unbounded volatile memory consumption.
  - **Flush on Stop:** When capture stops or the screen disposes, any pending buffered speech is flushed and evaluated immediately.

### 2. Speech-to-Text Backend Integration Modes
1. **Production Architecture — Supabase Edge Function (`guardcall-stt`):**
   - Enabled via:
     ```bash
     USE_CLOUD_STT=true
     STT_BACKEND=edge_function
     STT_PROVIDER=edge_function
     ```
   - Client sends base64-encoded WAV containers over authenticated HTTPS to the Edge Function proxy.
   - Provider API keys (OpenAI Whisper or Google Cloud Speech) reside strictly in server-side Edge Function secrets and are never bundled in the mobile application binary.
2. **Local Development Mode — Direct Cloud STT (`RemoteSpeechToTextService`):**
   - Enabled via:
     ```bash
     USE_CLOUD_STT=true
     STT_BACKEND=direct_dev
     STT_PROVIDER=remote
     SPEECH_TO_TEXT_API_KEY=<openai-api-key>
     ```
   - Intended exclusively for local developer experimentation. Secrets in `.env` are excluded from Git via `.gitignore`.
3. **Offline / Safe Default (`MockSpeechToTextService`):**
   - Automatically selected when credentials are unconfigured or placeholder strings (`STT_BACKEND=mock`).
   - Prevents network failure crashes and enables offline-first demonstration.

### 3. Transcript Processing & Threat Assessment Flow
1. **Response Ingestion:** Provider responses are parsed into chronological [LiveSpeechSegment](file:///lib/features/detection/live_speech_recognition_service.dart#L11) items.
2. **Scam Risk Evaluation:** Real recognized phrases are piped directly to [ScamDetectionEngine](file:///lib/features/detection/scam_detection_engine.dart).
3. **Warning Deduplication:** Warnings trigger only when a critical or high-risk threshold is crossed, preventing repeated popups on incremental hypotheses.
4. **History Logging:** Persists completed assessments to [CallHistoryRepository](file:///lib/features/history/call_history_repository.dart) with `isSimulated: false` only after genuine speech has been transcribed and scored.
5. **UI Truthfulness:** If the recognizer encounters an error or is unconfigured, the pipeline displays `ACOUSTIC ONLY` rather than falsely claiming `LIVE RECOGNIZER ACTIVE`.

### 4. Privacy & Telephony Disclosure
- **Volatile In-Memory Processing:** GuardCall maintains zero raw audio retention on the local device or Supabase database.
- **External Provider Disclosure:** If an external STT service is configured, audio buffers are transmitted securely over HTTPS and are subject to the provider's API privacy policy (e.g. OpenAI's 30-day API data retention policy).
- **Speakerphone / Ambient Only:** GuardCall operates in speakerphone mode and does not wiretap background cellular telephone calls.



