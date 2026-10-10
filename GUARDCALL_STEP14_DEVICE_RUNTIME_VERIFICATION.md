# GuardCall — Step 14: Android Device & Runtime Verification Report

**Date:** October 11, 2026  
**Commit Hash:** `455344bb6eeaa7198d90b2c8506397ba2dcf6aec`  
**Target Environment:** Android Virtual Device (`emulator-5554`) — Android 17 (API 37), `sdk_gphone16k_x86_64`, 1080x2400 @ 420 dpi (411dp width)  
**Hardware Classification:** **Android Emulator** *(No physical USB/Wi-Fi Android handset was attached; emulator utilized per Step 14 requirements)*

---

## 1. Device & Build Verification

- **Device Detection:**
  - `flutter devices` detected: `sdk gphone16k x86 64 (mobile) • emulator-5554 • android-x64 • Android 17 (API 37)`
  - Physical hardware check: `adb devices -l` confirmed no physical hardware was connected.
- **Build Execution:**
  - `flutter build apk --debug` succeeded in 29.1 seconds.
  - Output binary: `build/app/outputs/flutter-apk/app-debug.apk`.
- **Installation & Launch:**
  - Streamed install via `adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk` returned `Success`.
  - Application launched via intent `com.example.guard_call/.MainActivity`.
  - App shell initialized cleanly with the dark neon glassmorphism UI design. Bottom navigation across Home, Calls, Family, and History functioned smoothly.

---

## 2. Runtime Functional Verification

| Test Scenario | Verification Steps | Result | Notes |
| :--- | :--- | :--- | :--- |
| **Permission Revocation & Blocked State** | Revoked `RECORD_AUDIO` via ADB; navigated to Microphone Shield; tapped "Grant Microphone Access" -> tapped "Don't allow" | **PASS** | UI immediately presented red warning banner *"Microphone permission is permanently disabled"*, *"Microphone Permission Blocked"*, and Pipeline Diagnostics indicated `PERMANENTLYDENIED`. |
| **Permission Grant & Idle State** | Granted `RECORD_AUDIO` via ADB; relaunched app | **PASS** | UI displayed green checkmark, diagnostics updated to `Audio Record: GRANTED`, and `Start Microphone Shield` button became interactive. |
| **Microphone Capture Lifecycle** | Tapped "Start Microphone Shield" -> monitored OS indicators -> tapped "Stop Microphone Shield" | **PASS** | Android green microphone privacy indicator chip illuminated in the system status bar. Diagnostics showed `Capturing Live Audio (16000Hz • Mono • 16-bit)`. Tapping Stop successfully extinguished OS mic indicator. |
| **Audio Level Metering** | Captured audio; observed decibel/amplitude level meter | **PASS** | Audio level meter actively reflected amplitude (`Level: 0%` in silent room). |
| **Honest Unconfigured STT State** | Evaluated live status while capturing without configured STT backend | **PASS** | Recognizer badge showed `ACOUSTIC ONLY` & `Offline / Unconfigured`. Threat status showed orange banner: *"Transcription Error: Speech recognition failed or is unconfigured. GuardCall cannot confirm whether this call is safe."* Status displayed `Evaluation Unavailable`. **Never displayed "Safe"**. |
| **Live Scam Intervention & Warning Dialog** | Injected synthetic threat: *"This is police investigation. Send money immediately or you will be arrested"* | **PASS** | Triggered `ScamWarningDialog` with `CRITICAL THREAT: 100/100`, full threat bar, and detected signals: `Possible authority impersonation`, `Urgency or time pressure`, `Threat or fear-based pressure`, `Financial pressure`. |
| **Live Alert Family Action** | Tapped "Alert Family" inside the live warning dialog | **PASS** | Dialog dismissed and honest SnackBar displayed: *"Family alert recorded locally for this call session."* |
| **Safe SMS Analysis** | Analyzed routine clinic confirmation: *"Your appointment at City Health Clinic is confirmed for tomorrow at 10:30 AM."* | **PASS** | Assessed as `Safe (0/100)`. Green badge and no scam indicators flagged. |
| **Suspicious SMS Analysis** | Analyzed preset `Bank OTP Scam` | **PASS** | Assessed as `Critical Threat: 100 / 100`. Flagged `Fake Authority / Impersonation` and `OTP / Credential Request`. Safe Action Checklist displayed. |
| **SMS Empty & Truncation Handling** | Tapped Analyze on empty input; analyzed >500 character payload | **PASS** | Empty input displayed validation error banner: *"Please enter or paste message text to analyze."* Long payload safely truncated without crashing. |
| **SMS Alert Family Circle & Deduplication** | Tapped "Alert Family Circle"; tapped it a second time | **PASS** | First tap showed *"Family circle notified regarding this suspicious message."* Second tap showed *"An alert has already been recorded for this message."* |
| **History Persistence & Source Labeling** | Inspected History tab; force-stopped app (`am force-stop`); relaunched app | **PASS** | Both live microphone and SMS assessments appeared with timestamps, threat pills, and explicit source badges (`LIVE CALL` vs `MANUAL SMS`). Records persisted perfectly across process termination. |
| **Family Circle UI** | Navigated to Family tab; viewed active caregiver & emergency toggle | **PASS** | Rendered active caregiver "Sarah Jenkins (Daughter)", verified active status and local alert guarantee. |

---

## 3. Discovered Defects & Fixes

### Layout Overflow on Mobile Screens in SMS Results Card
- **Symptom:** On standard Android mobile width (411dp / 1080px at 420 dpi), analyzing a message triggered a Flutter layout defect:
  ```
  A RenderFlex overflowed by 6.9 pixels on the right.
  ```
- **Root Cause:** In [lib/features/sms/sms_protection_screen.dart](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/sms/sms_protection_screen.dart), the header card used an unconstrained `Row` with `mainAxisAlignment: MainAxisAlignment.spaceBetween` containing `RiskBadge` and `'Threat Score: 100 / 100'`. On narrower screens or high font scales, the contents exceeded the available container width.
- **Fix Applied:** Replaced the unconstrained `Row` with a responsive `Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8)` layout and refined font sizing (`fontSize: 14`).
- **Validation:** Rebuilt APK, installed on emulator, and retested. Overflow banner was completely eliminated and text scales responsively.

---

## 4. Automated Regression Verification

- **Flutter Analyze:**
  ```
  Analyzing nsrit-app...
  No issues found! (ran in 8.7s)
  ```
- **Flutter Test Suite:**
  ```
  00:11 +385: All tests passed!
  ```
  All 385 automated unit, widget, and integration tests across 24 test suites passed with 0 failures.

---

## 5. Summary of Architecture Guarantees Verified

1. **Strictly Honest State:** Audio capture in unconfigured STT mode never fabricates transcripts or reports false "Safe" assessments.
2. **Local vs Remote Honesty:** The app never claims remote push notifications were dispatched across the internet when functioning in local standalone mode.
3. **Responsive Visual Quality:** UI renders cleanly with zero overflows across native Android device viewports.
