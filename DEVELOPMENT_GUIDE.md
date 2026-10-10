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

