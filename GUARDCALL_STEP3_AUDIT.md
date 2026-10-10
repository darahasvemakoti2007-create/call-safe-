# GuardCall — Step 3: Complete Incomplete-Feature Audit

**Audit Date:** October 2026  
**Audited Location:** `C:\Users\venup\OneDrive\Desktop\nsrit-app`  
**Execution Context:** Post-Step 2 Local Data Persistence  
**Test Suite Results:** **233 / 233 tests passing** (13.0s) | **`flutter analyze`: 0 issues found**

---

## 1. Executive Summary

GuardCall has completed **Step 2 (Reliable Local Data Persistence)**. All call risk assessment history, accessibility settings (`reduceMotion`), notification preferences (`familyAlertsEnabled`), family contacts, and mutual caregiver relationship pairs now reliably survive application process restarts using `shared_preferences` without large database dependencies.

The application possesses a robust offline demo foundation:
- **Zero-Network Demonstration**: 100% of core scam detection heuristics, turn-by-turn simulation playback, warning dialog interventions, local persistence, and caregiver threat detail views execute reliably without requiring an active internet connection, external API keys, or backend accounts.
- **Privacy by Design**: Exactly **zero raw audio bytes**, zero audio waveform files, and zero full conversation transcripts are written to disk, flash storage, or database tables.
- **Honest Platform Boundaries**: The application does not claim live cellular call interception on Android (which modern Android security isolates at the baseband processor level without root permissions). It does not request dangerous call recording permissions in `AndroidManifest.xml`.
- **Honest Notification Boundaries**: Caregiver alerts are simulated on-device in prototype mode. Future provider abstractions (`FcmNotificationService`, `ApnsNotificationService`, `SmsNotificationService`, `EmailNotificationService`) are explicitly stubbed as unintegrated interfaces without fake network dispatches.

This audit evaluates the codebase across 16 functional areas (A–P), cataloging what is complete, partial, simulated, missing, or blocked, and establishes a prioritized backlog for subsequent development phases.

---

## 2. Current Application Architecture and Data Flow

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                            FLUTTER PRESENTATION LAYER                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐ │
│  │  Home Screen │  │ Calls Screen │  │History Screen│  │  Family Screen  │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └────────┬────────┘ │
│         │                 │                 │                   │           │
│         │         ┌───────▼────────┐        │          ┌────────▼─────────┐ │
│         │         │  Demo Player   │        │          │ Caregiver Dialog │ │
│         │         └───────┬────────┘        │          └──────────────────┘ │
│         │                 │                 │                               │
│         │         ┌───────▼────────┐        │                               │
│         │         │ Scam Warning   ├────────┼───────────────────────────────┤
│         │         │     Modal      │        │                               │
│         │         └───────┬────────┘        │                               │
└─────────┼─────────────────┼─────────────────┼───────────────────────────────┼─┘
          │                 │                 │                               │
┌─────────▼─────────────────▼─────────────────▼───────────────────────────────▼─┐
│                             CORE SERVICE LAYER                              │
│                                                                             │
│  ┌───────────────────────┐  ┌─────────────────────────┐  ┌───────────────┐ │
│  │ Conversation Pipeline │  │  CallHistoryRepository   │  │ Family Contact│ │
│  │ (STT -> Heuristics)   │  │  (Local Persistence)     │  │ & Rel Service │ │
│  └──────────┬────────────┘  └───────────┬─────────────┘  └───────┬───────┘ │
│             │                           │                        │         │
│  ┌──────────▼────────────┐  ┌───────────▼─────────────┐  ┌───────▼───────┐ │
│  │ MockScamDetection     │  │ NotificationService     │  │ Accessibility │ │
│  │ Engine (9 Signals)    │  │ (Simulated Dispatch)    │  │ Preferences   │ │
│  └───────────────────────┘  └─────────────────────────┘  └───────────────┘ │
└─────────────────────────────────────┬───────────────────────────────────────┘
                                      │
┌─────────────────────────────────────▼───────────────────────────────────────┐
│                     LOCAL STORAGE & FALLBACK BOUNDARY                       │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     SharedPreferences (Key-Value)                     │  │
│  │  - guardcall_call_history_v1         - guardcall_reduce_motion_v1     │  │
│  │  - guardcall_family_contacts_v1      - guardcall_family_alerts_v1     │  │
│  │  - guardcall_family_relationships_v1 - guardcall_family_invitations_v1│  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │              Supabase Client Gateway (Dormant in Demo Mode)           │  │
│  │  - PostgreSQL RLS Schema Ready       - Edge Functions Prepared        │  │
│  │  - AuthGate & Realtime Stubbed       - Controlled via AppConfig       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow Lifecycle (Simulated Call Flow)
1. **Scenario Selection**: User selects one of 5 scenarios in [DemoCenterScreen](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/demo/demo_center_screen.dart).
2. **Turn-by-Turn Stepping**: [DemoSessionController](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/demo/demo_session_controller.dart) feeds conversational lines to [MockScamDetectionEngine](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/detection/mock_scam_detection_engine.dart).
3. **Progressive Heuristic Scoring**: Evaluates signals (Authority, Urgency, Threat, Sensitive Info, Financial, Isolation, Emotional, Remote Access, Links) + Compounding Bonuses + Sequence Modeling.
4. **Intervention Trigger**: When risk score reaches High (71+) or Critical (85+), [ScamWarningDialog](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/alerts/scam_warning_dialog.dart) opens with 3 explicit user options.
5. **Persistence**: The completed assessment metadata (score, level, signals, duration, intervention status) is saved to [CallHistoryRepository](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/history/call_history_repository.dart) and persisted to `SharedPreferences`. Audio and conversation transcripts are permanently discarded.

---

## 3. Feature-by-Feature Audit Table

| ID | Area / Feature | Status | Primary Implementation File | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **A1** | Email/Password Registration | COMPLETE (Offline) / PARTIAL (Cloud) | `lib/core/services/auth_service.dart` | Automated tests (`auth_test.dart`) |
| **A2** | Email/Password Login & Validation | COMPLETE | `lib/features/auth/login_screen.dart` | Automated tests (`auth_test.dart`) |
| **A3** | Session Restoration across restarts | COMPLETE (Cloud) / SIMULATED (Offline) | `lib/core/services/auth_state.dart` | Source inspection & tests |
| **A4** | Password Reset / Recovery Flow | MISSING | `lib/features/auth/login_screen.dart` | Source inspection |
| **B1** | Supabase Client Gateway & Configuration | COMPLETE | `lib/core/services/supabase_service.dart` | Automated tests (`app_config_test.dart`) |
| **B2** | Non-crashing Offline Fallback | COMPLETE | `lib/core/config/app_config.dart` | Automated tests & app startup |
| **B3** | Cloud Database Synchronization Queue | MISSING | `lib/features/history/call_history_repository.dart` | Source inspection |
| **C1** | Call History Local Persistence | COMPLETE | `lib/features/history/call_history_repository.dart` | Automated tests (`local_persistence_test.dart`) |
| **C2** | User Settings (Reduce Motion) Persistence | COMPLETE | `lib/core/services/accessibility_preferences.dart` | Automated tests (`local_persistence_test.dart`) |
| **C3** | Notification Preferences Persistence | COMPLETE | `lib/core/services/notification_preferences.dart` | Automated tests (`local_persistence_test.dart`) |
| **C4** | Family Contacts Persistence | COMPLETE | `lib/core/services/family_contact_service.dart` | Automated tests (`local_persistence_test.dart`) |
| **C5** | Family Relationships & Invitations Persistence | COMPLETE | `lib/core/services/family_relationship_service.dart` | Automated tests (`local_persistence_test.dart`) |
| **D1** | Heuristic Scam Detection (9 Canonical Signals)| COMPLETE | `lib/features/detection/mock_scam_detection_engine.dart` | Automated tests (`detection_engine_test.dart`) |
| **D2** | Canonical Risk Tiers & Scoring (0–100) | COMPLETE | `lib/core/widgets/risk_badge.dart` | Automated tests (`detection_engine_test.dart`) |
| **D3** | False-Positive Protective Context Checks | COMPLETE | `lib/features/detection/mock_scam_detection_engine.dart` | Automated tests (legit bank & hospital tests) |
| **D4** | Remote AI / Edge Function Detection Engines | PARTIAL / STUBBED | `lib/features/detection/edge_function_scam_detection_engine.dart` | Automated tests (`edge_function_backend_test.dart`) |
| **E1** | Audio Input Abstraction (`AudioInput`) | COMPLETE | `lib/features/detection/audio_input.dart` | Automated tests (`speech_pipeline_test.dart`) |
| **E2** | Mock Speech-to-Text Pipeline | COMPLETE | `lib/features/detection/mock_speech_to_text_service.dart` | Automated tests (`speech_pipeline_test.dart`) |
| **E3** | Hardware Microphone Audio Recording | MISSING / INTENTIONALLY EXCLUDED | `lib/features/detection/audio_input.dart` | Source inspection (`pubspec.yaml`, `AndroidManifest.xml`) |
| **E4** | Android Cellular Call Interception | BLOCKED (OS Limitation) | `ANDROID_LIMITATIONS.md` | Android OS architecture audit |
| **F1** | Senior View: Caregiver List & Authorization | COMPLETE | `lib/features/family/family_screen.dart` | Automated tests (`family_caregiver_experience_test.dart`)|
| **F2** | Senior View: Create / Revoke Caregiver Invitation| COMPLETE | `lib/features/family/family_screen.dart` | Automated tests (`family_caregiver_experience_test.dart`)|
| **F3** | Caregiver View: Protected Senior Preview & Alerts | COMPLETE | `lib/features/family/family_screen.dart` | Automated tests (`family_caregiver_experience_test.dart`)|
| **F4** | Caregiver View: Accept Pending Invitation | MISSING | `lib/core/services/family_relationship_service.dart` | Source inspection |
| **G1** | Provider-Neutral Notification Service Layer | COMPLETE | `lib/core/services/notification_service.dart` | Automated tests (`caregiver_notification_architecture_test.dart`) |
| **G2** | In-Memory Simulated Notification Service | SIMULATED | `lib/core/services/simulated_notification_service.dart` | Automated tests (`caregiver_notification_architecture_test.dart`) |
| **G3** | Real SMS, WhatsApp, FCM, APNs Dispatch | MISSING / PREPARED INTERFACE | `lib/core/services/notification_service.dart` | Source inspection |
| **H1** | Realtime WebSocket Alert Stream (Client-side) | SIMULATED (Offline) / PARTIAL (Cloud) | `lib/core/services/realtime_service.dart` | Automated tests (`cloud_sync_realtime_test.dart`) |
| **H2** | Live Cross-User Synchronization | NOT VERIFIED (Cloud Dormant) | `lib/core/services/realtime_service.dart` | Source inspection |
| **I1** | Demo Center: 5 Realistic Offline Scenarios | COMPLETE | `lib/features/demo/demo_scenarios.dart` | Automated tests (`demo_center_test.dart`) |
| **I2** | Demo Player: Interactive Stepping & Audio Sim | COMPLETE | `lib/features/demo/demo_player_screen.dart` | Automated tests (`demo_session_controller_test.dart`) |
| **J1** | Scam Warning Modal: End Call Action | COMPLETE | `lib/features/alerts/scam_warning_dialog.dart` | Automated tests (`intervention_test.dart`) |
| **J2** | Scam Warning Modal: I'm Safe Action | COMPLETE | `lib/features/alerts/scam_warning_dialog.dart` | Automated tests (`intervention_test.dart`) |
| **J3** | Scam Warning Modal: Alert Family Action | COMPLETE (Simulated Dispatch) | `lib/features/alerts/scam_warning_dialog.dart` | Automated tests (`intervention_test.dart`) |
| **K1** | Call History List Display & Risk Badging | COMPLETE | `lib/features/history/history_screen.dart` | Automated tests (`local_persistence_test.dart`) |
| **K2** | Call History Search & Text Filtering | MISSING | `lib/features/history/history_screen.dart` | Source inspection |
| **K3** | Call History Risk Tier Filtering Chips | MISSING | `lib/features/history/history_screen.dart` | Source inspection |
| **K4** | Call History Record Detail Dialog | MISSING | `lib/features/history/history_screen.dart` | Source inspection |
| **K5** | Clear History Action with Confirmation | COMPLETE | `lib/features/settings/settings_screen.dart` | Automated tests (`local_persistence_test.dart`) |
| **L1** | High-Contrast Dark Theme & Scaled Typography | COMPLETE | `lib/app/app_theme.dart` | Automated tests (`accessibility_security_hardening_test.dart`) |
| **L2** | Reduce Motion Toggle & Global Animation Bypass | COMPLETE | `lib/core/services/accessibility_preferences.dart` | Automated tests (`accessibility_security_hardening_test.dart`) |
| **L3** | Minimum 48px Accessible Touch Targets | COMPLETE | `lib/core/widgets/primary_button.dart` | Automated tests (`accessibility_security_hardening_test.dart`) |
| **M1** | Screen Loading States & Progress Indicators | COMPLETE | Across all feature screens | Widget tests |
| **M2** | Screen Empty States | COMPLETE | Across calls, history, and family screens | Widget tests |
| **N1** | Zero-Audio & Zero-Transcript Privacy Retention | COMPLETE | Verified in models, repositories, and tests | Automated tests (`local_persistence_test.dart`) |
| **N2** | Zero-Dangerous Android Permissions in Manifest | COMPLETE | `android/app/src/main/AndroidManifest.xml` | Source inspection |
| **N3** | Supabase Row Level Security (RLS) SQL Policies | COMPLETE (Schema) / NOT VERIFIED (Live) | `supabase/schema.sql` | SQL schema audit |
| **O1** | Android Package Configuration | PARTIAL | `android/app/build.gradle.kts` | Source inspection |
| **O2** | Android Release Signing Configuration | PARTIAL (Debug Key Placeholder) | `android/app/build.gradle.kts` | Source inspection |
| **P1** | Bottom Navigation Shell (5 Destinations) | COMPLETE | `lib/app/app_navigation.dart` | Automated tests (`widget_test.dart`) |
| **P2** | Dynamic User Greeting on Home Dashboard | PARTIAL / BUGGY | `lib/features/home/home_screen.dart` | Source inspection (line 55) |

---

## 4. Evidence for Important Statuses

### A. Local Persistence Verification (Step 2)
- **Suite**: `test/local_persistence_test.dart`
- **Output**: 10 tests passed in under 1 second.
- **Verification Details**:
  - `AccessibilityPreferences`: Survives service reset, persists `reduceMotion: true` and `reduceMotion: false`.
  - `NotificationPreferences`: Survives service reset, persists `familyAlertsEnabled: true` and `false`.
  - `CallHistoryRepository`: Survives service reset, persists custom added simulated records with signals and risk scores; persists empty state on `clear()`.
  - Privacy verification: Explicit test confirms serialized map contains neither `'audio'`, `'raw_audio'`, `'transcript'`, nor `'full_transcript'`.
  - Corrupt JSON resilience: Test with invalid JSON (`INVALID_CORRUPT_JSON_DATA{{{[[[`) falls back cleanly to default demo records without throwing.
  - `FamilyContactService` and `FamilyRelationshipService`: Survive service reset, persist added contacts, relationships, and invitations.
  - Credential security: Inspection of all keys stored in `SharedPreferences` confirms zero storage of JWT tokens, service role keys, API secrets, or passwords.

### B. Scam Detection Engine Verification
- **Suite**: `test/detection_engine_test.dart`
- **Output**: 20 tests passed.
- **Verification Details**:
  - `Fake KYC` scenario flags Authority Impersonation, Urgency, Threat, and Sensitive Info Request, generating Risk Score 95 (Critical).
  - `Digital Arrest` scenario flags Authority Impersonation, Fear/Threat, Isolation, Financial Demand, and Urgency, generating Risk Score 95 (Critical).
  - `Grandchild Emergency` scenario flags Emotional Manipulation and Financial Pressure, generating Risk Score 80 (High).
  - `Legitimate Bank Alert` and `Hospital Reschedule` scenarios detect protective phrases ("will never ask for your otp", "no payment or sensitive information is required"), reducing risk score to $\le 20$ (Safe).

### C. Caregiver Notification Architecture Verification
- **Suite**: `test/caregiver_notification_architecture_test.dart`
- **Output**: 15 tests passed.
- **Verification Details**:
  - `NotificationPolicy`: Blocks alert dispatch for Safe (score 12) and Suspicious (score 55) calls. Supports alerts for High (score 78) and Critical (score 92).
  - `NotificationRequest.isPrivacyCompliant`: Verified to reject payloads containing transcript or raw audio references.
  - `SimulatedNotificationService`: Correctly stamps all events with `NotificationStatus.simulated` and logs `"Zero network calls made"`. When disabled in Settings, stamps `NotificationStatus.unavailable`.

---

## 5. Exact File Paths for Incomplete Features

1. **Caregiver Invitation Acceptance (Missing)**:
   - File: [`lib/core/services/family_relationship_service.dart`](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/core/services/family_relationship_service.dart)
   - Missing Method: `Future<void> acceptInvitation(String invitationId, String caregiverUserId)`
   - File: [`lib/features/family/family_screen.dart`](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/family/family_screen.dart)
   - Missing UI: No "Accept Invitation" button in Caregiver View.
2. **History Search & Risk Tier Filtering (Missing)**:
   - File: [`lib/features/history/history_screen.dart`](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/history/history_screen.dart)
   - Missing UI: No search field (`TextField`), no filter chips (`FilterChip`), and no record detail dialog on tap.
3. **Hardcoded User Greeting (Usability Bug)**:
   - File: [`lib/features/home/home_screen.dart`](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/home/home_screen.dart#L55)
   - Issue: Line 55 hardcodes `'Welcome back, Eleanor'` instead of binding to `AuthState.instance.displayName`.
4. **Password Reset Flow (Missing)**:
   - File: [`lib/features/auth/login_screen.dart`](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/auth/login_screen.dart)
   - Missing UI/Logic: No "Forgot Password?" dialog or reset request integration.
5. **Android Release Package & Keystore (Incomplete)**:
   - File: [`android/app/build.gradle.kts`](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/android/app/build.gradle.kts#L19)
   - Issue: `applicationId = "com.example.guard_call"` uses default `com.example` namespace; release build signs with debug keystore.
6. **External Notification Providers (Prepared Architecture Only)**:
   - File: [`lib/core/services/notification_service.dart`](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/core/services/notification_service.dart#L204-L237)
   - Issue: `FcmNotificationService`, `ApnsNotificationService`, `SmsNotificationService`, and `EmailNotificationService` are abstract interfaces marked `NOT IMPLEMENTED`.

---

## 6. User-Facing Bugs and Usability Issues

1. **Hardcoded User Greeting on Dashboard**:
   - `HomeScreen` displays "Welcome back, Eleanor" regardless of whether the user signed in with their own name or is exploring as "Demo User".
2. **History Cards Non-Interactive**:
   - Tapping an item in `HistoryScreen` does not trigger a detailed inspection dialog. The user cannot view full signal descriptions, why the call was flagged, or the full timestamp.
3. **History Screen Lacks Search and Filtering**:
   - As history logs grow, seniors or caregivers cannot filter for "Critical Threats" or search by caller entity (e.g. "Bank", "Police").
4. **Caregiver View Cannot Complete Invitation Loop**:
   - When a senior invites a caregiver via email, the Caregiver View shows the incoming invitation as pending, but offers no action to "Accept" and link the account.
5. **Login Screen Has No Password Reset Mechanism**:
   - Users cannot recover forgotten passwords through the mobile interface if Supabase authentication is active.

---

## 7. Security and Privacy Concerns

1. **Sensitive Data Protection**:
   - **Compliant**: Zero raw audio waveforms, recordings, or full transcripts are written to persistent storage or emitted over notification payloads.
   - **Compliant**: API secrets, JWT secrets, and passwords are not stored in local preferences.
2. **Row Level Security (RLS)**:
   - All PostgreSQL tables in `supabase/schema.sql` and `supabase/migrations/` have RLS enabled and strictly enforce `auth.uid()` scoping.
   - **Status**: RLS policies are structurally sound in SQL files, but live remote database deployment is currently postponed.
3. **Android Permissions**:
   - **Compliant**: Production manifest `android/app/src/main/AndroidManifest.xml` declares zero dangerous runtime permissions. No `RECORD_AUDIO`, `READ_PHONE_STATE`, or `PROCESS_OUTGOING_CALLS`.
4. **Notification Truthfulness**:
   - The app explicitly warns seniors and caregivers: *"Family notifications are simulated in hackathon prototype mode. No SMS, WhatsApp, or push notifications are dispatched."*

---

## 8. Dependency & Infrastructure Requirements

1. **Current Dependencies**:
   - `shared_preferences: ^2.5.5` (Active — handles all local persistence).
   - `supabase_flutter: ^2.17.2` (Present — handles auth/client when cloud mode is activated).
   - `cupertino_icons: ^1.0.8` (Active — icons).
2. **Future Dependency Needs (When Unlocking Features)**:
   - For real microphone speech testing: `record` or `speech_to_text`, plus `permission_handler`. (Note: strictly for testing microphone input, not cellular call snooping).
   - For real push notifications: `firebase_core` and `firebase_messaging`.
   - For production Android signing: Keystore generation (`key.properties`).

---

## 9. Prioritized Backlog of Missing Features

### P0 — Correctness, Accuracy, Privacy & Usability Fixes
- **P0.1: Dynamic User Greeting**: Update `HomeScreen` line 55 to dynamically display `AuthState.instance.displayName` rather than hardcoded "Eleanor".
- **P0.2: Caregiver Invitation Acceptance Action**: Add `acceptInvitation` to `FamilyRelationshipService` and provide an "Accept Invitation" action in `FamilyScreen` (Caregiver View) to complete the mutual authorization loop.

### P1 — Essential for a Credible Hackathon Demonstration
- **P1.1: Call History Filtering & Search**:
  - Add search bar to `HistoryScreen` to query by title and threat keywords.
  - Add filter chips for risk tiers: `All`, `Critical`, `High`, `Suspicious`, `Safe`.
- **P1.2: Call History Assessment Detail Modal**:
  - Make history cards interactive (`onTap`) to open a detailed breakdown dialog showing all detected signals, threat explanations, duration, and senior intervention actions.
- **P1.3: Clear History Button on History Screen**:
  - Add a direct "Clear History" button with confirmation dialog directly in the `HistoryScreen` app bar or header (currently only accessible through Settings).

### P2 — Advanced Features & Polish
- **P2.1: Android Release Build Hardening**:
  - Update `applicationId` from `com.example.guard_call` to a production identifier (`com.guardcall.shield`).
  - Configure production signing configuration template in `android/app/build.gradle.kts`.
- **P2.2: Password Reset / Recovery Flow**:
  - Add "Forgot Password?" dialog to `LoginScreen` for cloud mode.
- **P2.3: Offline-to-Cloud Sync Reconciliation**:
  - Provide an option to sync locally persisted demo assessments to Supabase `call_sessions` once cloud authentication is established.

### P3 — Optional Enhancements (Future / Post-Hackathon)
- **P3.1: Hardware Microphone Audio Input Testing**: Integrate local audio recording plugin for user voice testing in Demo Center.
- **P3.2: External FCM / APNs Push Notification Service**: Connect Firebase Cloud Messaging gateway for remote caregiver push delivery.
- **P3.3: Safety Report PDF Export**: Generate a printable safety summary of detected scam patterns for local law enforcement or family reviews.

---

## 10. Recommended Next Implementation Step (Step 4)

### Recommended Focus: **Step 4 — History Usability, Search, Filtering, Detail Modal & Greeting Polish**

This step addresses the critical P0 and P1 gaps in the existing local experience without introducing new cloud infrastructure, external dependencies, or breaking changes:

#### Acceptance Criteria for Step 4:
1. **Dynamic Greeting**: Replace hardcoded "Eleanor" in `HomeScreen` with `AuthState.instance.displayName`.
2. **Interactive History Detail Dialog**: Tapping any past assessment in `HistoryScreen` opens a dialog displaying:
   - Full title, formatted timestamp, and call duration.
   - Risk meter, numeric score (0–100), and canonical risk badge.
   - List of all detected threat signals with individual explanations.
   - Intervention action taken (e.g. "User ended call", "Family alert requested").
3. **History Filtering & Search**:
   - Add search field to filter records by keyword matching title, subtitle, or signal names.
   - Add filter chips (`All`, `Critical`, `High`, `Suspicious`, `Safe`) that immediately filter the list.
4. **Direct Clear History Option**:
   - Provide a clean "Clear" action icon in `HistoryScreen` with the existing confirmation dialog.
5. **Caregiver Invitation Acceptance**:
   - Add `acceptInvitation` to `FamilyRelationshipService` and wire an "Accept" button in `FamilyScreen` (Caregiver View) so pending invitations can transition to active caregivers in the local demo.
6. **Testing & Stability**:
   - All new interactions must be covered by automated tests.
   - `flutter analyze` must pass with 0 issues.
   - Full `flutter test` suite must pass with 100% success.
