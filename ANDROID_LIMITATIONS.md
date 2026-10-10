# GuardCall — Android Platform & Technical Telephony Limitations

## 1. Executive Summary

GuardCall is an Android-first assistive Flutter application designed to shield seniors from deceptive social engineering phone scams.

This document clearly details Android operating system constraints, permission handling, audio privacy boundaries, and prototype vs. production realities.

---

## 2. Cellular Call Audio Interception on Android

### The Platform Reality
Modern Android operating system releases (Android 9 Pie through Android 15/API 37) strictly forbid standard user-space applications from intercepting, tapping, or recording cellular telephone conversations.

1. **AudioSource Limitations:**
   - `AudioSource.VOICE_CALL`, `AudioSource.VOICE_DOWNLINK`, and `AudioSource.VOICE_UPLINK` require system-level signature permissions (`CAPTURE_AUDIO_OUTPUT`) which are restricted to pre-installed platform system apps.
2. **Accessibility Service Restrictions:**
   - Google Play policy strictly prohibits abusing Accessibility Services for voice recording.
3. **Hardware Baseband Isolation:**
   - On Android devices, the cellular modem (baseband processor) routes voice call audio directly to telephony audio hardware paths. Third-party apps without system privilege cannot snoop on cellular voice calls.

### GuardCall's Approach: Honest Demonstration & Opt-In Speakerphone Shield
- GuardCall **does NOT claim** cellular telephony call interception or baseband wiretapping.
- GuardCall requires explicit runtime consent for `android.permission.RECORD_AUDIO`: acoustic monitoring operates via the ambient room microphone when the user explicitly taps "Start Microphone Shield" (e.g. placing a call on speakerphone).
- GuardCall **does NOT request** call-spying permissions (`READ_PHONE_STATE`, `PROCESS_OUTGOING_CALLS`, `READ_CALL_LOG`, `CAPTURE_AUDIO_OUTPUT`).

---

## 3. Production vs. Prototype Manifest Audit

### Production Manifest (`android/app/src/main/AndroidManifest.xml`)
- Declared permissions:
  - `android.permission.RECORD_AUDIO`: User-consented runtime permission for Microphone Shield. Only active when explicitly started by user.
  - `android.permission.INTERNET`: For secure HTTPS edge function communication (when cloud ASR backend is configured).
- Zero call-spying permissions:
  - No `android.permission.READ_PHONE_STATE`.
  - No `android.permission.PROCESS_OUTGOING_CALLS`.
  - No `android.permission.READ_CALL_LOG`.
  - No `android.permission.CAPTURE_AUDIO_OUTPUT`.

### Debug Manifest (`android/app/src/debug/AndroidManifest.xml`)
- Only `android.permission.INTERNET` is included, strictly required by Flutter tooling for Dart VM service, observatory, and hot reload during local development.

---

## 4. Audio Pipeline & Data Retention

1. **Zero Raw Audio Storage:**
   - Raw audio waveforms are never saved to flash memory, disk, or remote cloud storage.
   - Any audio buffer processed during analysis is ephemeral, held purely in memory, and immediately discarded upon phrase analysis.
2. **Zero Full Conversation Transcript Retention:**
   - Full conversation transcripts are never saved to backend databases.
   - Only structured risk metadata (score, risk tier, detected manipulation signals, intervention actions, timestamps) is retained.
3. **Zero Secret / Key Exposure:**
   - No AI provider API keys or administrative secrets are compiled into the client APK.

---

## 5. Caregiver Alert Simulation

1. **Simulated Notification Delivery:**
   - Outward notifications to family members and caregivers are simulated locally in-memory.
   - Exactly zero network requests, zero SMS, zero WhatsApp, zero emails, and zero push notification APIs (FCM/APNs) are executed.
2. **Simulated vs. Real Transparency:**
   - All alert events are stamped `SIMULATED` or `UNAVAILABLE`.
   - The app never falsely displays "Sent" or "Delivered" without verified physical transmission.
3. **Database Deployment Postponed:**
   - Supabase database deployment remains postponed. The application runs 100% offline in memory by default.

---

## 6. SMS Scam Detection & Platform Permission Boundaries

### The Android Operating System & Google Play Reality
1. **Default SMS Handler Requirement:**
   - Under Google Play Developer Program Policies (specifically the *SMS and Call Log Permissions Policy* introduced across Android 9 through Android 15), apps cannot request `READ_SMS`, `RECEIVE_SMS`, or `READ_CELL_BROADCASTS` unless the application is actively designated as the device's **Default SMS Handler**.
   - Assistive security tools and call blockers that are not messaging clients are barred from automatically reading user inboxes in the background. Violating this leads to immediate Google Play Store rejection and potential account suspension.
2. **User Privacy & Snooping Prevention:**
   - An assistive fraud app should never snoop on private SMS conversations, sensitive bank balance updates, personal two-factor verification codes, or family text threads without explicit, focused intent.

### GuardCall's Safe Message Analysis Architecture
1. **Manual On-Device Analysis (Safe & Non-Intrusive):**
   - Seniors or caregivers can paste or type any suspicious message into the dedicated **SMS Scam Shield** screen.
   - Evaluation is executed entirely on-device via GuardCall's heuristic engine, assessing urgent payment demands, OTP credential theft, fake authority claims, and phishing URLs.
   - Zero inbox access permissions (`READ_SMS`, `RECEIVE_SMS`) are requested in `AndroidManifest.xml`.
2. **Strict Privacy Policy Compliance:**
   - Only the specific message submitted by the user is evaluated.
   - Private contacts, unrelated inbox threads, and unanalyzed text messages are never accessed, inspected, or transmitted.
   - The user-facing history log only stores the structured threat metadata and an excerpt of the analyzed text for audit review.
3. **Future Incoming SMS Integration Path (Roadmap):**
   - Automated incoming message triage requires either:
     - User opting into Android's system **SMS Retriever API** / Google Play Services consent flow (strictly for sender-consented verification), or
     - Registering as an enterprise Default SMS Handler with full messaging UI support and explicit Google Play Policy Declaration approval.
   - Until authorized under these strict platform constraints, GuardCall maintains manual analysis as the reliable, completely secure, and 100% private production baseline.

