# GuardCall — Privacy by Design Policy

## 1. Executive Summary
GuardCall is designed from the ground up as a **privacy-first conversational threat protection system**. We believe that protecting vulnerable individuals from deceptive social engineering scams must not come at the cost of sacrificing personal privacy or turning mobile devices into warrantless wiretaps.

---

## 2. Core Privacy Principles

### 1. No Raw Audio Storage
* **Policy:** GuardCall **never** saves, persists, or exports raw audio waveform recordings of incoming or outgoing phone calls to disk, flash memory, or remote servers.
* **Mechanism:** Audio input buffers are ephemeral and processed entirely in transient memory during active analysis, after which they are immediately discarded.

### 2. No Default Full Transcript Retention
* **Policy:** Full conversation transcripts are **not** persisted to the backend database by default.
* **Mechanism:** Only high-level structured risk metadata is logged:
  - Assessed threat score (0–100)
  - Risk tier (`Safe`, `Suspicious`, `High`, `Critical`)
  - Detected signal categories (e.g. `Urgency`, `Authority Impersonation`, `OTP Request`)
  - Timestamp and duration
  - Intervention outcome (`End Call`, `I'm Safe`, `Family Alert Requested`)

### 3. Local-First Processing
* **Prototype & Demo Mode:** Operates 100% locally and offline on-device with zero network traffic, zero third-party AI calls, and zero external telemetry.
* **Future Production Mode:** Prioritizes local, on-device neural inference (e.g., on-device TFLite / Whisper models) to evaluate conversation lines without streaming private dialogue over the internet.

### 4. Zero Hard-Coded Credentials
* Secrets, API tokens, and private endpoints are strictly externalized via `.env` and environment configurations.
* No API keys are embedded into compiled Dart binaries or repository commits.

### 5. Strict Row Level Security (RLS)
* When connected to a Supabase backend, PostgreSQL **Row Level Security (RLS)** is enforced across every single database table.
* Every query is bound cryptographically to `auth.uid()`. No user can view, query, or mutate another user's call records, family contacts, or alert history.

### 6. Client Key Security (No Service-Role Keys)
* The client application is configured strictly with the Supabase `anon` / public client key.
* The administrative `service_role` key is **never** included in client application code or configuration.

### 7. Zero Local Password Storage
* GuardCall never stores, caches, or logs user passwords on the local device filesystem or unmanaged memory.
* Authentication credentials are transmitted exclusively to Supabase Auth over TLS, where passwords are cryptographically hashed using `bcrypt` before persistence.

---

## 3. Prototype vs. Future Production Behavior

| Dimension | Prototype / Hackathon Demo (Current) | Future Production Release (Roadmap) |
| :--- | :--- | :--- |
| **Conversations** | Predefined simulated scenarios in Demo Center | User-submitted voice memos or permitted speakerphone input |
| **Call Audio** | Simulated in-memory dialogue turns | Processed in-memory; discarded immediately after STT |
| **Transcripts** | Displayed in demo UI during simulation; not uploaded | Discarded after heuristic threat extraction |
| **Data Storage** | In-memory transient call history; optional Supabase sync | PostgreSQL backed by Row Level Security |
| **Caregiver Alerts** | Visual confirmation modal tagged `"SIMULATED FAMILY ALERT"` | Supabase Realtime push notification to verified caregiver |
| **Cellular Tapping** | None (explicitly disclaimed; impossible on standard Android) | None (GuardCall will never deploy covert baseband interceptors) |

---

---

## 4. Step 10 Cloud Synchronization & Realtime Boundaries

When cloud synchronization is active (`USE_SUPABASE=true`):

### What IS Synchronized:
1. **Call Session Telemetry (`public.call_sessions`):**
   - Assessed threat score (0–100)
   - Risk classification tier (`Safe`, `Suspicious`, `High`, `Critical`)
   - Duration in seconds and start timestamp
   - Scenario identifier and user intervention outcome (`End Call`, `I'm Safe`, `Family Alert Requested`)
2. **Explainable Risk Signals (`public.risk_signals`):**
   - Behavioral pattern type (e.g. `authority_impersonation`, `urgency`, `otp_solicitation`)
   - Severity level (`low`, `medium`, `high`, `critical`)
   - Human-readable explanation of why the signal flagged
   - Detection timestamp
3. **Designated Caregivers (`public.family_contacts`):**
   - Contact name, relationship, and designated phone/email identifier
   - Active/enabled status
4. **Caregiver Alert Events (`public.alerts`):**
   - Session reference, contact reference, risk score, and status (`pending`)

### What is NEVER Synchronized or Uploaded:
- **NO raw audio:** Microphone waveforms, audio streams, or voice recordings are NEVER uploaded or retained.
- **NO full transcripts:** The spoken conversation text and dialogue turns are NEVER uploaded or saved to database tables.
- **NO credentials:** Passwords and secrets are never stored in database tables or logs.
- **NO service_role keys:** Only authenticated client tokens are used; administrative keys are strictly banned from client code.

### Realtime Event Security:
- Realtime subscriptions on `public.alerts` are filtered strictly to the authenticated user's session.
- PostgreSQL Row Level Security (RLS) prevents any client from snooping or subscribing to foreign users' alert streams.

---

## 5. Step 11 Secure Family Circle & Caregiver Identity

Step 11 establishes cryptographically authenticated pairing between accounts:

### Core Identity Principles:
1. **Family Relationships are Authorization Records:**
   - A row in `public.family_relationships` binds the account of an elderly user (`owner_user_id`) to a distinct authenticated caregiver account (`caregiver_user_id`).
   - It is an authorization grant in the database kernel, not an address-book entry.
2. **Contact Strings are NOT Authorization Credentials:**
   - A phone number, name, or email string stored in a contact card cannot authorize access to sensitive threat telemetry. Anyone can type a phone number or claim an email address.
   - Caregiver authorization requires a verified, authenticated Supabase Auth identity (`auth.users.id`).
3. **Caregiver Access Requires Authenticated Identity & Active Consent:**
   - A caregiver must sign in to their own verified GuardCall account.
   - An owner can revoke caregiver access instantly by setting `enabled = false` or deleting the relationship.
4. **Privacy Protection During Escalation:**
   - **Zero Raw Audio:** Audio waveforms are never uploaded or shared with caregivers.
   - **Zero Conversation Transcripts:** Full transcripts never leave the user's phone.
   - **Structured Metadata Only:** Caregivers only receive high-level threat telemetry (e.g. Threat Type: Bank Impersonation, Score: 90/100, Time: 3:15 PM). Caregivers can never listen in on live calls or read private dialogue.
5. **PostgreSQL RLS Enforces Cross-User Isolation:**
   - Caregivers can ONLY view alerts for elderly users who have created an active `family_relationships` record referencing their `caregiver_user_id`.
   - Without this record, RLS returns 0 rows.
6. **Delivery Implementation Notice:**
   - **Invitation delivery is not yet implemented:** Creating an invitation records the authorization request in PostgreSQL; automated SMS/email delivery is not active.
   - **Push/SMS notification delivery is not yet implemented:** Alert rows are recorded in PostgreSQL; client-side SMS or FCM push relay is not yet active.

### Why GuardCall Cannot Safely Use a Phone Number or Email Address Alone as Proof of Caregiver Identity
> **Beginner-Friendly Explanation:**  
> In many casual mobile apps, typing a phone number like `+1 555-019-2834` or an email like `daughter@example.com` into a contact form is treated as adding a contact. However, on the internet, **phone numbers and email strings can be easily spoofed or mistyped**. If GuardCall allowed anyone who enters a senior's phone number to view their incoming scam alerts, an attacker or bad actor could simply guess or enter a victim's phone number and immediately receive notifications about when that senior is distressed or vulnerable!
>
> To protect vulnerable seniors from surveillance and stalkers, GuardCall treats family relationships as **cryptographic authorizations**. A phone number in a contact list is only a label. For someone to actually observe alert telemetry, they must prove who they are by logging into their own authenticated GuardCall account (`auth.users`), and the senior must explicitly approve that specific account in their Family Circle.

---

## 6. Step 12 Remote AI & Speech-to-Text Privacy Boundaries

Step 12 introduces modular provider abstractions for remote AI and Cloud Speech-to-Text. This introduces a distinct privacy boundary:

### 1. Local/Mock Mode (Default):
- **Zero Network Traffic:** Conversation text and simulated audio remain 100% on the local device.
- **Privacy Guarantee:** True zero-transcript and zero-audio cloud exposure.

### 2. Remote Provider Mode (Opt-In):
- **When Active (`USE_REMOTE_AI=true` or `USE_CLOUD_STT=true`):** Spoken audio or transcribed conversation sentences are transmitted over TLS to third-party AI/STT providers (e.g. OpenAI or Google Gemini).
- **Explicit Privacy Boundary:** We do **NOT** claim zero-transcript privacy when remote AI or cloud STT is enabled. Dialogue lines leave device control for processing by the designated provider.
- **Disabled by Default:** Remote providers are strictly disabled by default (`AI_PROVIDER=mock`, `STT_PROVIDER=mock`, `USE_REMOTE_AI=false`). Users must explicitly configure keys and enable flags.
- **Zero Raw Audio Storage in Supabase:** Regardless of provider mode, raw audio files are **never** persisted to Supabase database tables or device flash storage.
- **Zero Full Transcript Storage in Supabase:** The backend audit database stores exclusively structured risk telemetry (scores, signal types, intervention status), never conversational transcripts.

### 3. API Key Security & Backend Proxy Architecture:
- Embedding raw provider API keys in a production client APK is insecure due to decompilation risks.
- In production, GuardCall routes requests through an authenticated backend proxy (e.g. Supabase Edge Functions) that stores secrets server-side, rate-limits requests, and scrubs sensitive user identifiers before calling external AI providers.

---

## 7. Step 15 End-to-End AI & STT Pipeline Privacy Boundaries

GuardCall defines three explicit operational models with clear privacy boundaries:

### MODE 1 — Offline Mock (Default)
- **Audio & Dialogue:** 100% on-device transient RAM. Temporary/local only.
- **Network Traffic:** Exactly ZERO bytes transmitted.
- **Database:** None. Operates completely in-memory.
- **Privacy Assurance:** Complete mathematical privacy—data cannot be intercepted because it never traverses a network interface.

### MODE 2 — Direct Development Provider (LOCAL DEVELOPMENT ONLY)
- **Audio & Dialogue:** Spoken sentences or audio buffers may be transmitted directly over HTTPS to OpenAI (`api.openai.com`) or Google Gemini (`generativelanguage.googleapis.com`).
- **Privacy Boundary:** Dialogue leaves device control to the configured third-party AI provider.
- **Restriction:** Staged solely for local engineering experiments and fixture tests. Strictly marked LOCAL DEVELOPMENT ONLY; never released in public APKs.

### MODE 3 — Production Edge Function AI & STT Proxy
- **Audio & Dialogue:** Transmitted via TLS with user JWT authentication to GuardCall's Supabase Edge Functions (`guardcall-ai-analyze`, `guardcall-stt`).
- **Secret Protection:** Provider keys (`OPENAI_API_KEY`, `GEMINI_API_KEY`, `SPEECH_TO_TEXT_API_KEY`) reside exclusively in server-side environment secrets.
- **Zero Database Persistence:**
  - Raw audio buffers are processed in memory and **never written to Supabase Storage or PostgreSQL**.
  - Full conversation transcripts are **never saved to PostgreSQL tables**.
  - Only high-level structured threat indicators (e.g. `riskScore: 88`, `signals: ["authority_impersonation"]`, `timestamp`) are persisted when cloud sync is active.

### Platform Boundary Notice:
**GuardCall currently demonstrates conversation analysis through simulated/demo audio and controlled audio inputs.** Standard Android OS permissions restrict user-space applications from intercepting live cellular voice calls.

### Database Deployment Postponement:
Live Supabase database deployment remains postponed. The application architecture and Edge Functions are designed to seamlessly integrate with database tables when deployed, but all current functionality is fully operational without live database connectivity.

---

---

## 9. Step 16 Family Circle & Caregiver Telemetry Privacy Boundary

Step 16 provides an explicit, elderly-friendly privacy guarantee regarding what caregivers can and cannot observe:

### Protected Privacy Guarantees:
1. **Zero Call Audio Sharing:** GuardCall **never** shares microphone audio or voice recordings with family members. Audio remains 100% private to the senior.
2. **Zero Full Conversation Transcripts:** Full dialogue turns and spoken sentences are **never** delivered to caregivers in alert notifications or stored in alert telemetry records.
3. **Structured Threat Telemetry Only:** Caregivers receive only structured safety metadata:
   - Evaluated risk score (e.g., `92/100`) and risk classification tier (`Critical Scam Threat`)
   - Behavioral manipulation tags (e.g., `Authority impersonation`, `Urgency or time pressure`, `Sensitive information request`)
   - High-level pattern explanation (e.g., *"Caller impersonated a bank official threatening account closure without OTP verification."*)
   - User intervention action (e.g., *"User selected End Call"*)
4. **Strict Mutual Authorization:**
   - Only family members approved by the account owner can access authorized family alerts.
   - Merely typing an email address into the app does **not** grant access. Caregivers must authenticate and accept before access is granted.
   - In offline/demo mode, invitations and alerts are simulated locally on-device. No real emails, SMS, WhatsApp messages, or push notifications are sent.

---

## 10. Step 17 Caregiver Alert & Notification Payload Privacy Boundary

**"Family alerts share safety metadata, not the conversation itself."**

Step 17 introduces the notification and caregiver-alert delivery architecture (`NotificationService`). The notification payload is strictly privacy-minimized by design.

### What is Included in the Notification Payload:
- **Alert ID:** Unique identifier for the threat alert record.
- **Recipient/Caregiver Identifier:** Designee ID or relationship identifier.
- **Risk Level & Risk Score:** Standard GuardCall risk tier (`Safe`, `Suspicious`, `High`, `Critical`) and score (`0–100`).
- **Scenario / Threat Category:** Classification identifier (e.g., `fake_kyc`, `tech_support`, `lottery_prize`).
- **Detected Signal Summaries:** High-level manipulation tags (e.g., `Authority Impersonation`, `Urgency`, `Sensitive Information Request`).
- **Intervention Status:** Senior action taken (e.g., `User selected End Call`, `Alert Family`).
- **Timestamp:** ISO-8601 creation timestamp.

### What is STRICTLY EXCLUDED from the Notification Payload:
- **NO Raw Audio:** No audio bytes, waveforms, or voice recording streams are ever included.
- **NO Conversation Transcripts:** Full spoken dialogue turns and conversational text are never placed in notification payloads.
- **NO Credentials or Financial Data:** Zero bank account numbers, passwords, OTPs, PINs, or CVVs.
- **NO Authentication Tokens:** Zero user JWTs, session tokens, or API keys.
- **NO Caller Phone Numbers:** Unredacted caller phone numbers are excluded unless explicitly authorized by a future privacy-reviewed contact verification flow.

### Notification Delivery Security & Prototype Realism:
- **Default Provider:** `SimulatedNotificationService` runs locally in-memory with exactly **zero network requests**, zero SMS, zero WhatsApp, zero emails, and zero FCM/APNs calls.
- **Explicit Labeling:** All events and confirmation displays are stamped as `SIMULATED` or `UNAVAILABLE`. GuardCall never falsely displays "Sent" or "Delivered" without verified physical transmission.
- **User Control:** Senior users maintain complete control. Family alerts are triggered exclusively via explicit user interaction (`Alert Family`). If Family Alerts are disabled in Settings, the notification request is blocked.

---

## 11. Step 18 Privacy, Security, Accessibility & Production Hardening

Step 18 establishes system-wide hardening across privacy, logging, secrets, accessibility, and elderly-safety controls:

### 1. Centralized Privacy-Safe Logging (`AppLogger`):
- All debug, info, warning, and error events pass through `AppLogger`.
- **Automatic Sanitization:** Regex filters redact sensitive credentials (`[REDACTED_CREDENTIAL]`, `[REDACTED_SECRET]`, `Bearer [REDACTED]`, `[REDACTED_JWT]`) before output.
- **Zero Sensitive Data:** Raw call audio, full conversation transcripts, OTPs, PINs, CVVs, passwords, authentication tokens, API keys, and notification tokens are NEVER logged.
- **Release Gating:** Debug logs are suppressed in release builds; non-sensitive diagnostic traces are preserved.

### 2. Secret & Configuration Hardening:
- `.env` is ignored by Git; `.env.example` contains only harmless placeholders.
- Zero provider API keys (`OPENAI_API_KEY`, `GEMINI_API_KEY`, `SPEECH_TO_TEXT_API_KEY`) or Supabase `service_role` keys in Flutter source.
- Default execution path is 100% offline-first mock mode (`AI_BACKEND=mock`, `STT_BACKEND=mock`).
- If production secrets are missing, the system defaults safely without crashing.

### 3. Elderly-First Accessibility & Safety:
- **Readable Typography & Touch Targets:** Large text styles, high-contrast badges, and generous 48dp+ tap targets designed for elderly users.
- **Multi-Modal Risk Communication:** Threat levels are communicated with explicit text (`Safe`, `Suspicious`, `High Risk`, `Critical Threat`) and icons (`verified_user`, `info`, `warning`, `report`), never color alone.
- **Reduce Motion Support:** The `AccessibilityPreferences` singleton propagates to `RiskMeter`, `ScamWarningDialog`, and modal alerts, disabling bouncing transitions and heavy glow animations when active.
- **Destructive Action Confirmation:** Irreversible actions (Sign Out, Revoking Invitations, Clearing Local History) require clear, elderly-friendly confirmation dialogs.

### 4. Canonical Risk Score & Terminology Harmonization:
- Risk thresholds strictly adhere to canonical tiers:
  - `0–39`: Safe
  - `40–70`: Suspicious
  - `71–84`: High
  - `85–100`: Critical
- At score 75 (Fake KYC scenario), score and label agree everywhere as `High Risk` / `High Threat`.

### 5. Honest Prototype Disclosure & Android Permission Minimization:
- The production `AndroidManifest.xml` declares ZERO runtime/dangerous permissions (no `RECORD_AUDIO`, no `READ_PHONE_STATE`, no `PROCESS_OUTGOING_CALLS`).
- Standard Android permissions prevent third-party apps from intercepting cellular voice calls. GuardCall honestly demonstrates conversation protection through simulated audio scenarios.
- Database deployment remains postponed; cloud synchronization is disabled by default.





