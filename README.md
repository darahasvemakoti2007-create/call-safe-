# GuardCall — AI-Powered Phone Scam Shield

GuardCall protects vulnerable individuals and elderly users from social engineering, financial fraud, and impersonation phone scams by analyzing conversational behavior in real time.

---

## Key Highlights

- **Dynamic Pattern Recognition**: Identifies social engineering markers (urgency, legal threats, authority impersonation, OTP requests, and isolation tactics) rather than relying on easily-spoofed Caller IDs.
- **End-to-End AI & STT Pipeline**: Unified audio-to-intelligence pipeline (`ConversationPipeline`) orchestrating `AudioInput` → `SpeechToTextService` → `ConversationLine[]` → `ScamDetectionEngine` → `RiskAnalysis` → Warning UI → History.
- **Three Operational Execution Modes**:
  1. **OFFLINE MOCK** (Default): 100% in-memory heuristic engine and mock audio pipeline. Zero internet, zero credentials, zero network needed.
  2. **DIRECT DEVELOPMENT**: Local testing with direct OpenAI/Gemini/Whisper endpoints (strictly labeled development only; never for production APKs).
  3. **EDGE FUNCTION**: Secure production architecture proxying all AI/STT calls through authenticated Supabase Edge Functions (`guardcall-ai-analyze`, `guardcall-stt`), keeping provider secrets server-side.
- **Offline Demo Mode**: Evaluators and hackathon judges can immediately test realistic scam simulations in the Demo Center without requiring backend accounts, API keys, or active internet.
- **Platform Telephony Boundaries**: GuardCall currently demonstrates conversation analysis through simulated/demo audio and controlled audio inputs. Standard Android OS permissions restrict user-space applications from intercepting live cellular calls.
- **Family Circle & Caregiver Threat Experience**:
  - Senior View ("My Family Circle") displaying authorized caregivers, pending invitations, and explicit privacy guarantees.
  - Add Family Member modal with email and relationship validation, generating simulated pending invitations.
  - Caregiver View ("Caregiver View (Preview)") presenting protected senior accounts and recent scam escalations.
  - Caregiver Alert Detail dialog breaking down: WHAT HAPPENED, WHY IT WAS FLAGGED (canonical signals), WHAT THE USER DID (senior intervention action), and WHAT YOU CAN DO (safe informational actions).
  - Mutual Authorization: Conceptually requires `owner_user_id` + `caregiver_user_id` + active relationship. Email/phone is never treated as authentication.
  - Zero-Audio & Zero-Transcript Privacy: Audio is never shared; transcripts are never delivered. Only high-level risk telemetry is shared with caregivers.
- **Caregiver Alert & Notification Architecture (Step 17)**:
  - Provider-neutral `NotificationService` abstraction decoupling alert creation from notification delivery mechanisms.
  - Offline `SimulatedNotificationService` default with exactly **zero network calls**, zero SMS, zero WhatsApp, zero emails, and zero push notification APIs.
  - In-memory `NotificationEvent` stream for reactive UI updates across senior and caregiver views.
  - Risk-based `NotificationPolicy` layer ensuring `SAFE` and `SUSPICIOUS` calls never trigger family alerts, while `HIGH` and `CRITICAL` threats support explicit senior-initiated alerts.
  - Settings screen `Family Alerts` preference toggle with transparent `Demo / Simulated Mode` disclosure.
  - Caregiver view lifecycle transparency distinguishing `Alert: Created` from `Notification: SIMULATED` or `UNAVAILABLE`.
  - Future-ready provider interfaces (`FcmNotificationService`, `ApnsNotificationService`, `SmsNotificationService`, `EmailNotificationService`) marked `NOT IMPLEMENTED` without fake network code.
- **Simulated Delivery Constraints**: GuardCall currently simulates caregiver notifications locally. No SMS, WhatsApp, email, FCM, or APNs message is sent.
- **Database Deployment Status**: Supabase database deployment remains postponed. All features operate fully in-memory without database dependencies.
- **Privacy by Design**: Zero raw audio retention, no full transcript logging, privacy-minimized notification payloads (threat metadata only), and zero client-side password storage.
- **Hackathon Presentation & Demo Guide (Step 19)**: Complete judge walkthrough script, offline execution guarantees, and scenario catalog available in [DEMO_GUIDE.md](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/DEMO_GUIDE.md).
- **Explainable Threat Scores**: Translates complex manipulation heuristics into plain-language risk tiers (`Safe`, `Suspicious`, `High`, `Critical`) and actionable safety dialogues.

---

## Project Structure

```text
lib/
├── app/                  # Theme, navigation, and AuthGate
├── core/
│   ├── config/           # AppConfig (.env parsing and validation)
│   ├── services/         # AuthService, CallSessionService, RiskSignalService, FamilyContactService, FamilyAlertService, RealtimeService, FamilyRelationshipService
│   └── widgets/          # Accessible UI primitives (GlassCard, RiskBadge, PrimaryButton)
└── features/
    ├── auth/             # Login, Sign-up, and Auth documentation
    ├── calls/            # Active call monitoring view
    ├── demo/             # Demo Center and simulated scenario player
    ├── detection/        # Scam detection engine and heuristic rules
    ├── family/           # Caregiver emergency circle
    ├── history/          # Call risk logs
    ├── home/             # Primary protection dashboard
    └── settings/         # Accessibility, privacy, and account status
```

---

## Getting Started

### 1. Offline Demo Mode (Default)
To run the app immediately in offline demo mode without setting up cloud services:
```bash
flutter run
```
The app defaults to `USE_SUPABASE=false`, giving immediate access to the Home dashboard, Demo Center, and simulated call scenarios.

### 2. Cloud Configuration (Optional)
To connect GuardCall to your own Supabase project:
1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Populate `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `.env`.
3. Set `USE_SUPABASE=true`.
4. Run the database migration script located at `supabase/schema.sql` in your Supabase SQL Editor.
5. Refer to [`SUPABASE_SETUP.md`](file:///SUPABASE_SETUP.md) for full instructions.

---

## Step 18 — Privacy, Security, Accessibility & Production Hardening

- **Privacy-Safe Logging (`AppLogger`)**: Automatic credential scrubbing and zero audio/transcript logging guarantee.
- **Accessibility & Reduce Motion**: `AccessibilityPreferences` singleton controlling transitions and glow effects across widgets.
- **Destructive Action Confirmation**: Confirmation dialogs for Sign Out, Revoking Invitations, and Clearing History.
- **Harmonized Risk Tiering**: Consistent canonical thresholds (`0–39` Safe, `40–70` Suspicious, `71–84` High, `85–100` Critical). Score 75 consistently labeled `High Risk`.
- **Zero Dangerous Permissions**: Clean `AndroidManifest.xml` with zero dangerous runtime permissions.
- **Layout Safety**: Responsive mobile layout preventing horizontal overflow across all screens.
- **Documentation**: Detailed guides in [`PRIVACY.md`](file:///PRIVACY.md), [`ARCHITECTURE.md`](file:///ARCHITECTURE.md), [`ANDROID_LIMITATIONS.md`](file:///ANDROID_LIMITATIONS.md), and [`DEVELOPMENT_GUIDE.md`](file:///DEVELOPMENT_GUIDE.md).

---

## Running Tests
Run automated unit, widget, and domain tests (223/223 passing):
```bash
flutter test
```

