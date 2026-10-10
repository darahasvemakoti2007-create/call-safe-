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

### GuardCall's Approach: Honest Demonstration
- GuardCall **does NOT claim** live cellular call interception or recording.
- GuardCall **does NOT request** dangerous call-recording permissions (`RECORD_AUDIO`, `READ_PHONE_STATE`, `PROCESS_OUTGOING_CALLS`) in its main production manifest.
- The prototype demonstrates real-time conversational scam analysis through controlled, structured voice audio scenarios in the Demo Center.

---

## 3. Production vs. Prototype Manifest Audit

### Production Manifest (`android/app/src/main/AndroidManifest.xml`)
- **Dangerous / Runtime Permissions Declared:** Exactly **ZERO**.
- No `android.permission.RECORD_AUDIO`.
- No `android.permission.READ_PHONE_STATE`.
- No `android.permission.PROCESS_OUTGOING_CALLS`.
- No `android.permission.READ_CALL_LOG`.
- No `android.permission.INTERNET` in main manifest (only in debug manifest for Flutter development tools).

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
