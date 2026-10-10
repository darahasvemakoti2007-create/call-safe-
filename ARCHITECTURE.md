# GuardCall Architecture Document

Welcome to the **GuardCall** architecture guide. This document provides a beginner-friendly overview of how the GuardCall application is structured, how data flows through the system, how scams are detected, and how user privacy is preserved.

---

## 1. High-Level System Structure

The GuardCall system is structured into four main operational pillars:

```text
GuardCall
│
├── Frontend
│   ├── Screens
│   ├── Navigation
│   ├── Reusable UI components
│   └── Animations
│
├── Detection Engine
│   ├── Speech-to-text abstraction
│   ├── Scam signal detection
│   ├── Risk scoring
│   └── Explainable risk reasons
│
├── Local Layer
│   ├── Temporary processing
│   ├── Offline demo mode
│   └── Mock scenarios
│
└── Backend
    └── Supabase
        ├── Authentication
        ├── PostgreSQL database
        ├── Row Level Security (RLS)
        ├── Realtime family alerts
        └── Edge Functions
```

### Pillar Overview
* **Frontend**: The visible Flutter application running on the user's mobile device, providing clear visual warnings, real-time indicators, and management screens.
* **Detection Engine**: The brain of GuardCall. Converts spoken dialogue into text (or ingests simulated transcript streams), analyzes conversational behavioral patterns, calculates risk, and produces human-readable explanations.
* **Local Layer**: Runs on-device to handle temporary transient data processing, power offline demo modes, and simulate realistic mock scam calls without internet connectivity.
* **Backend (Supabase)**: Cloud infrastructure handling user accounts, storing structured call safety history, securing user data with Row Level Security, and dispatching realtime alerts to designated family members.

---

## 2. Planned Application Architecture Layers

To keep the Flutter codebase clean, maintainable, and beginner-friendly, the code follows a layered architecture separation of concerns:

```text
┌────────────────────────────────────────────────────────┐
│                  Presentation Layer                    │
│           (Screens, Widgets, UI State, Themes)         │
└───────────────────────────┬────────────────────────────┘
                            │ Calls / Observes
┌───────────────────────────▼────────────────────────────┐
│               Application / Service Layer              │
│       (Call Monitoring, Detection Coordinator, Alerts) │
└───────────────────────────┬────────────────────────────┘
                            │ Operates On
┌───────────────────────────▼────────────────────────────┐
│                   Domain / Models Layer                │
│    (ScamSignal, RiskAssessment, CallRecord, Contact)   │
└───────────────────────────┬────────────────────────────┘
                            │ Interacts With
┌───────────────────────────▼────────────────────────────┐
│                    Data / Backend Layer                │
│  (Supabase Client, Local Storage, Mock Scenario Feeds) │
└────────────────────────────────────────────────────────┘
```

### Layer Responsibilities Explained

1. **Presentation Layer**:
   * *What it does*: Renders everything the user sees and interacts with.
   * *Examples*: The incoming call screen, risk gauges, alert banners, call history lists, and animations.
   * *Rule*: The presentation layer never calculates scam scores or makes direct database queries; it simply observes and displays data.

2. **Application / Service Layer**:
   * *What it does*: Coordinates business logic, workflows, and communication between layers.
   * *Examples*: Coordinates starting a call session, feeding transcript chunks to the detection engine, updating current threat levels, and triggering alert notifications.
   * *Implemented*: [ScamDetectionEngine](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/detection/scam_detection_engine.dart) interface and [MockScamDetectionEngine](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/detection/mock_scam_detection_engine.dart).

3. **Domain / Models Layer**:
   * *What it does*: Defines core data types, entities, and business validation rules.
   * *Examples*: Data classes such as `ScamSignal`, `RiskScore`, `RiskReason`, `CallRecord`, and `FamilyContact`.
   * *Implemented*: [ScamSignal](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/detection/scam_signal.dart), [RiskAnalysis](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/detection/risk_analysis.dart), [DemoScenario](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/demo/demo_scenario.dart).
   * *Rule*: Pure Dart classes with no dependencies on Flutter UI or cloud APIs.

4. **Data / Backend Layer**:
   * *What it does*: Manages raw data retrieval and persistence from external sources.
   * *Examples*: Supabase authentication, PostgreSQL queries, local SQLite/SharedPreferences caching, and mock scenario data providers ([DemoScenarios](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/demo/demo_scenarios.dart)).

---

## 3. Planned Feature Areas

GuardCall includes 11 targeted feature areas:

| Feature Area | Description |
| :--- | :--- |
| **Onboarding** | Welcoming introduction explaining privacy-first real-time call protection, permissions, and setup steps. |
| **Home** | Dashboard displaying current protection status, quick access to the Demo Center, recent alerts, and family status. |
| **Active Call** | Simulated or active call screen showing live protection indicators, current threat meter, and instant intervention guidance. |
| **Scam Detection** | Core analysis engine identifying manipulative behavioral patterns in incoming conversation. |
| **Warnings** | High-visibility, non-intrusive heads-up visual alerts and haptic notifications when risk escalates. |
| **Call History** | Log of past call assessments, overall risk scores, detected patterns, and timestamps (without recording audio). |
| **Family Contacts** | Trusted circle configuration where vulnerable users can add trusted family members/caregivers. |
| **Family Alerts** | Real-time push/in-app alert pipeline to notify caregivers when a high-risk or critical scam call is detected. |
| **Privacy** | Transparency center highlighting zero-audio-storage policies, local processing principles, and data deletion toggles. |
| **Settings** | User preferences for alert thresholds, notification sounds, theme, and language. |
| **Demo Center** | Interactive sandbox with realistic pre-scripted scam scenarios (e.g., bank fraud, parcel delivery, relative emergency) to test detection without live calls. |

---

## 4. Planned Data Flow

During a call session (or simulated scenario), information flows sequentially through the system:

```text
[ Demo / Sample Conversation (Spoken Audio or Simulated Feed) ]
                           │
                           ▼
                  [ Real-time Transcript ]
                           │
                           ▼
                 [ Detection Engine ]
                           │
                           ▼
               [ Detected Scam Signals ]
      (e.g., Urgency + Impersonation + OTP Request)
                           │
                           ▼
                   [ Risk Analysis ]
          (Escalation modeling & sequence weight)
                           │
                           ▼
                     [ Risk Score ]
                    (0 to 100 Gauge)
                           │
                           ▼
                   [ User Warning ]
      (Clear, explainable warning banner on device)
                           │
                           ▼
              [ Optional Family Alert ]
     (Dispatched via Supabase Realtime if Risk ≥ High)
                           │
                           ▼
                    [ Call History ]
     (Structured record: timestamp, score, and reasons)
```

---

### Demo Center Progressive Detection Pipeline (Step 5)

In the interactive Demo Center, simulation flow is driven incrementally by an isolated state controller:

```text
Demo Scenario
     │ (Scripted turns & metadata)
     ▼
Demo Session Controller
     │ (Sequences turns, tracks displayed lines, coordinates analysis)
     ▼
Scam Detection Engine
     │ (MockScamDetectionEngine evaluates compounding behavioral patterns)
     ▼
Risk Analysis
     │ (Risk score 0-100, safety tier, detected signals, explainable reasons)
     ▼
Demo Player UI
     │ (Animated RiskMeter, real-time signal badges, dynamic reasons, final card)
     ▼
Call History Repository
       (In-memory telemetry record logged upon completion)
```

### Call Intervention Pipeline (Step 6)

When progressive analysis indicates severe social engineering, GuardCall presents an active intervention modal:

```text
Risk Analysis
     │
     ▼
Intervention Threshold (RiskLevel == High || RiskLevel == Critical)
     │
     ▼
Scam Warning Dialog (High-visibility modal, risk score, detected signals, reasons)
     │
     ├──────────────────────┬──────────────────────┐
     ▼                      ▼                      ▼
  End Call               I'm Safe             Alert Family
(Terminates Call)   (Dismisses Warning)   (Simulated Family Alert)
     │                      │                      │
     ▼                      ▼                      ▼
Call History           Simulation             Simulated Alert &
("User selected       Resumes (Score         History ("Family alert
   End Call")          retained intact)           requested")
```

### Audio Input & Speech-to-Text Pipeline (Step 7)

GuardCall establishes an independent, implementation-agnostic audio and speech-to-text pipeline:

```text
Audio Input (mockScenario / prerecorded / mic)
     │
     ▼
SpeechToTextService (Abstract Interface)
     │
     ▼
List<ConversationLine> (Transcribed chronological dialogue turns)
     │
     ▼
ScamDetectionEngine (MockScamDetectionEngine)
     │
     ▼
RiskAnalysis (Risk level, score, signals, explanations)
     │
     ▼
Intervention System (ScamWarningDialog / Family Alert)
```

**Implementation Status & Capabilities:**
- **Mock STT (`MockSpeechToTextService`):** Implemented prototype. Operates 100% offline in-memory, deterministic, zero network calls.
- **Real STT (`LocalSpeechToTextService` / `CloudSpeechToTextService`):** Future implementation.
- **Real cellular-call audio capture:** Platform-dependent / not guaranteed on general Android devices due to OS-level security sandboxing, carrier policies, and privacy restrictions.

---

## 5. Core Detection Philosophy: Pattern Analysis over Caller ID

### The Flaw of Traditional Solutions
Traditional spam-blocking applications rely almost exclusively on **Caller ID lookup** and **blacklists of reported phone numbers**. Modern scammers easily circumvent this by:
* Spoofing local telephone numbers.
* Cycling through thousands of newly acquired VoIP numbers.
* Hijacking legitimate corporate or government numbers.

### The GuardCall Approach
**GuardCall focuses on conversation and psychological manipulation patterns rather than the caller's phone number.** 

Scammers invariably rely on predictable social engineering techniques to bypass human critical thinking. GuardCall identifies these tactics directly from the live flow of conversation.

---

## 6. Scam Signals and Behavioral Escalation

### Main Scam Signals
GuardCall continuously inspects incoming dialogue for 9 critical manipulation signals:

1. **Urgency**: Creating panic and artificial deadlines ("You must act within the next 10 minutes").
2. **Fear / Threat**: Threatening legal action, arrest, account suspension, or immediate asset freezing.
3. **Authority Impersonation**: Claiming to be law enforcement, tax authorities, bank fraud departments, or tech support.
4. **Sensitive Information Request**: Asking for one-time passwords (OTPs), PINs, passwords, or full credit card numbers.
5. **Financial Pressure**: Demanding immediate payment via gift cards, cryptocurrency, wire transfers, or wire links.
6. **Isolation**: Instructing the victim not to hang up, not to speak to family members, or to stay quiet.
7. **Emotional Manipulation**: Fabricating family emergencies or preying on sympathy and trust.
8. **Remote Access / Screen Sharing**: Prompting the user to download tools like AnyDesk, TeamViewer, or remote screen viewers.
9. **Suspicious Links**: Directing the victim to click shortlinks, unverified portals, or fake security update pages.

### Sequence and Escalation Modeling
The detection engine **does not simply search for isolated keywords**. An innocent conversation can contain the word "urgent" or "bank".

Instead, the engine monitors **sequence and escalation**:
* *Step 1*: Establish false authority ("I am calling from Central Bank Security").
* *Step 2*: Introduce a crisis and create urgency ("Your account is compromised right now").
* *Step 3*: Pressure for action ("Do not hang up; you will be held liable").
* *Step 4*: Extract sensitive data ("Read me the 6-digit verification code you just received").

When these signals compound in rapid succession, the risk trajectory sharply escalates.

---

## 7. Risk Levels and Explainable Reasoning

### Planned Risk Scoring Tiers

```text
  [0 ──────────────── 40 ──────────────── 70 ────────────── 85 ──────────── 100]
         SAFE               SUSPICIOUS            HIGH              CRITICAL
      Green Tier           Yellow Tier         Orange Tier          Red Tier
```

* **0 – 40: Safe**
  Normal, expected conversational flow. No manipulative or predatory indicators detected.
* **40 – 70: Suspicious**
  Mild or isolated signals detected (e.g., someone asking for an urgent callback). The UI shows an informational warning.
* **70 – 85: High**
  Multiple compounding signals (e.g., urgent authority claim + financial demand). High-visibility alert banners trigger with recommended actions.
* **85 – 100: Critical**
  Severe scam pattern detected (e.g., impersonation + credential/OTP solicitation + isolation tactic). Screen displays an emergency intervention warning and initiates an automated caregiver/family notification.

### Explainable Risk Reasons
GuardCall avoids opaque scores. It provides clear, human-understandable explanations so the user understands *why* an alert was generated:

> **Example Warning:**
> *"Possible scam because the caller is using urgency, impersonating a bank official, and requesting an OTP."*

---

## 8. Privacy-by-Design Principles

User privacy and trust are paramount in GuardCall:

1. **Zero Raw Audio Storage**: Raw call audio is **never** recorded, uploaded, or permanently stored on cloud servers.
2. **Zero Permanent Transcript Storage**: Full call transcripts are not retained. Once processed for signal detection, transient text buffers are cleared from memory.
3. **Local & Ephemeral Processing**: Analysis happens locally or via transient stateless memory buffers.
4. **Structured Metadata Only**: When a call concludes, only structured, non-identifying telemetry is retained in the history:
   * Call timestamp and duration.
   * Final numerical risk score.
   * High-level detected categories (e.g., "Urgency", "OTP Request").

---

## 9. Prototype vs Production

| Aspect | Hackathon Prototype | Production Vision |
| :--- | :--- | :--- |
| **Speech-to-Text** | Simulated live transcript streams, mock audio dialogues, and pre-recorded scenarios in the Demo Center. | On-device streaming speech recognition models (e.g., Whisper on-device or native OS Speech APIs). |
| **Detection Engine** | Lightweight pattern heuristic matching and rule-based escalation state machine. | Hybrid edge/on-device NLP models supplemented by privacy-preserving cloud LLM verification. |
| **Backend Integration** | Supabase project configured with mock seed profiles and simulated realtime broadcast channels. | Enterprise Supabase deployment with production SMS/Push notification gateways and multi-member family dashboard. |
| **Telephony Integration** | Self-contained simulator and in-app active call interface for demonstration. | Android Call Screening and Accessibility Service hooks where permitted by platform security policies. |

---

## 10. Backend & Environment Architecture (Step 8)

GuardCall integrates a modular, offline-first cloud foundation:

```text
Flutter App
     │
     ▼
AppConfig (Loads environment variables from .env or fallback)
     │
     ▼
SupabaseService (Resilient gateway; manages client state)
     │
     ▼
Supabase Cloud
     │
     ▼
PostgreSQL Database + Row Level Security (RLS)
     ├── profiles (auth.uid() identity)
     ├── family_contacts (Caregivers circle)
     ├── call_sessions (Structured telemetry; NO audio)
     ├── risk_signals (Categorical threat indicators)
     ├── alerts (Caregiver escalation dispatch)
     └── user_settings (Privacy & accessibility preferences)
```

**Key Architectural Rules:**
1. **Offline-First Resilience:** If `.env` is absent, credentials are empty, or network fails, `SupabaseService` transitions gracefully to `SupabaseBackendState.offlineDemo`. The entire Demo Center and local analysis continue working flawlessly.
2. **Environment Configuration:** Secrets are externalized to `.env` (gitignored). `.env.example` serves as the safe, committed template.
3. **Privacy by Design:** Explicitly zero raw audio storage and no default full transcript tables. Only structured telemetry is persisted.
4. **Row Level Security (RLS):** Every PostgreSQL table enforces `auth.uid()` ownership. The Flutter app uses exclusively the `anon` publishable key—never the administrative `service_role` key.

---

## 11. Authentication & User Profile Architecture (Step 9)

```text
                  App Startup
                       │
                       ▼
                   AuthGate
                       │
         ┌─────────────┴─────────────┐
         ▼                           ▼
Offline Demo Mode            Supabase Configured
(USE_SUPABASE=false)         (USE_SUPABASE=true)
         │                           │
         ▼                           ▼
AppNavigation (Immediate)      Active Session?
                              ┌──────┴──────┐
                             Yes            No
                              │              │
                              ▼              ▼
                        AppNavigation   LoginScreen
                                       (with "Continue in Demo Mode")
```

### Key Components
1. **`AuthService`**: Unified authentication abstraction managing sign-in, registration, sign-out, session restoration, and offline demo fallback.
2. **`AuthState`**: Reactive `ChangeNotifier` providing application-wide authentication state (`unauthenticated`, `authenticated`, `offlineDemo`, `loading`).
3. **`ProfileService`**: Mediates interactions with `public.profiles` and `public.user_settings` tied strictly to the authenticated `auth.uid()`.
4. **`AuthGate`**: Non-blocking startup gate that immediately admits users in offline demo mode while gracefully guiding cloud-configured users through login.
5. **Privacy & Security Boundaries**:
   - Zero password storage locally.
   - Decoupled `auth.users` (credentials managed by Supabase Auth) vs. `public.profiles` (application data secured by RLS).
   - Prominent "Continue in Demo Mode" allows full feature evaluation without cloud credentials.

---

## 12. Supabase Realtime & Cloud Sync Architecture (Step 10)

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        Local Detection Engine                          │
│               (Heuristic pattern analysis on-device)                   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Local History & State                           │
│               (CallHistoryRepository & In-Memory State)                │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ If USE_SUPABASE=true & Authenticated
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                       Cloud Synchronization Layer                      │
│                                                                        │
│   • CallSessionService  ──► public.call_sessions (Metadata Only)      │
│   • RiskSignalService   ──► public.risk_signals  (Explainable Signals) │
│   • FamilyContactService──► public.family_contacts (Caregiver Circle)  │
│   • FamilyAlertService  ──► public.alerts (Status: pending)           │
│   • RealtimeService     ──► Supabase Realtime (WebSocket Replication)  │
└────────────────────────────────────────────────────────────────────────┘
```

### Core Architectural Principles:
1. **Local-First Precedence:** Detection and intervention never block on remote cloud requests. Completed sessions are logged locally first, followed by non-blocking asynchronous cloud synchronization.
2. **Zero-Audio & Zero-Transcript Privacy:**
   - Raw audio waveforms and microphone data are NEVER transmitted or stored.
   - Dialogue sentences and full conversational transcripts are NEVER stored in the database.
   - Only structured risk scores, risk levels, durations, and pattern classifications are synchronized.
3. **Realtime Event vs. Notification Delivery:**
   - Supabase Realtime emits WebSocket messages when an alert row is inserted.
   - Realtime DOES NOT send SMS, WhatsApp, or carrier push notifications.
   - True external caregiver dispatch requires downstream cloud triggers (Database Webhooks / Edge Functions -> Twilio / FCM).
4. **Caregiver RLS Architectural Boundary:**
   - Under the Step 8 PostgreSQL schema, `public.family_contacts` stored contact strings (`contact_identifier`) without a foreign key to a separate caregiver Supabase Auth account.
   - GuardCall identified this boundary and resolved it securely in Step 11 with authenticated account pairing.

---

## 13. Secure Family Circle & Caregiver Identity Architecture (Step 11)

```text
       Elderly Account (Owner)                  Caregiver Account
          [auth.users: id_A]                    [auth.users: id_B]
                  │                                     │
                  │  1. Create Invitation               │
                  ├──────────────────────────────►      │
                  │  (public.family_invitations)        │
                  │                                     │
                  │  2. Accept & Establish Pairing      │
                  ▼                                     ▼
        ┌────────────────────────────────────────────────────────┐
        │              public.family_relationships               │
        │  • owner_user_id: id_A                                 │
        │  • caregiver_user_id: id_B                             │
        │  • enabled: true                                       │
        └──────────────────────────┬─────────────────────────────┘
                                   │
                                   ▼
        ┌────────────────────────────────────────────────────────┐
        │         PostgreSQL Row-Level Security (RLS)            │
        │                                                        │
        │ Caregiver SELECT on public.alerts PERMITTED when:      │
        │ EXISTS (                                               │
        │   call_sessions.user_id = relationships.owner_user_id  │
        │   AND relationships.caregiver_user_id = auth.uid()     │
        │   AND relationships.enabled = true                     │
        │ )                                                      │
        └────────────────────────────────────────────────────────┘
```

### Key Architectural Concepts:
1. **Authenticated Authorization Records vs. Contact Labels:**
   - A phone number or email string in an address book cannot prove authorization. Anyone can type or spoof contact strings.
   - GuardCall pairs accounts using cryptographic Supabase Auth user IDs (`auth.users.id`).
2. **Dynamic Cross-Account RLS:**
   - Instead of opening table permissions or using the dangerous `service_role` key, the database kernel evaluates active relationship grants in `public.family_relationships`.
   - If an elderly user sets `enabled = false` or removes a caregiver, access to the user's alert stream is revoked immediately by PostgreSQL RLS.
3. **Dual-View Family Screen:**
   - **Elderly View ("My Family Circle"):** Displays linked caregivers, active status toggles, pending invitations, and privacy guarantees.
   - **Caregiver View ("Caregiver Mode (Preview)"):** Shows protected family member connection and structured scam alert cards permitted by RLS.
4. **Current Implementation Scope & Explicit Limitations:**
   - **Invitations:** Stored as pending authorization records in PostgreSQL. Client-side email/SMS delivery is not active.
   - **Alert Relay:** Stored in PostgreSQL with status `pending` and available over Realtime to authorized clients. Native push notifications (FCM/APNs) and cellular SMS are not active.

---

## 14. Real AI & Speech-to-Text Provider Architecture (Step 12)

```text
                     ┌───────────────────────────────┐
                     │          AudioInput           │
                     └───────────────┬───────────────┘
                                     │
                                     ▼
                     ┌───────────────────────────────┐
                     │      SpeechToTextService      │
                     │  (via STTProviderFactory)     │
                     ├───────────────┬───────────────┤
                     │ MockSTT       │ RemoteSTT     │
                     │ (Local Demo)  │ (Cloud API)   │
                     └───────────────┴───────────────┘
                                     │
                                     ▼ List<ConversationLine>
                     ┌───────────────────────────────┐
                     │      ScamDetectionEngine      │
                     │ (via DetectionProviderFactory)│
                     ├───────────────┬───────────────┤
                     │ MockDetection │ RemoteAIEngine│
                     │ (Heuristic)   │ (OpenAI/Gemini│
                     └───────────────┴───────────────┘
                                     │
                                     ▼
                     ┌───────────────────────────────┐
                     │         RiskAnalysis          │
                     │  • riskScore (0-100)          │
                     │  • riskLevel (Safe-Critical)  │
                     │  • detectedSignals (9 Types)  │
                     │  • explanations & confidence  │
                     └───────────────┬───────────────┘
                                     │
                                     ▼
                     ┌───────────────────────────────┐
                     │     Warning / Intervention    │
                     │   (Dialog & Family Alert)     │
                     └───────────────────────────────┘
```

### Key Architectural Concepts:
1. **Dual-Tier Factory Resolution:**
   - `DetectionProviderFactory` resolves `MockScamDetectionEngine` (offline default) or `RemoteAIScamDetectionEngine` (OpenAI / Gemini) based on `AI_PROVIDER` and API key readiness.
   - `STTProviderFactory` resolves `MockSpeechToTextService` (offline default) or `RemoteSpeechToTextService` based on `STT_PROVIDER`.
2. **Strict Structured Output Validation:**
   - Remote AI prompts enforce a strict JSON schema (`risk_score`, `confidence`, `signals`, `summary`).
   - Responses undergo validation: scores must be 0–100, confidence 0.0–1.0, signals must match GuardCall's 9 recognized manipulation categories, and explanations must be non-empty. Malformed or hallucinated responses are caught and handled safely.
3. **Graceful Error Fallback:**
   - If remote AI experiences network failures, socket timeouts, or missing credentials, the pipeline catches `DetectionException` and can fall back directly to on-device heuristic detection, ensuring the user is never left unprotected.
4. **Future Edge Function Proxy Model:**
   - Raw OpenAI/Gemini API keys should not reside permanently inside client mobile binaries.
   - In production, GuardCall transitions the remote provider to call an authenticated Supabase Edge Function that stores credentials server-side and scrubs private identifiers before calling AI providers.
5. **No Cellular Telephony Interception:**
   - GuardCall does NOT intercept cellular phone calls. Remote STT operates only on explicitly provided audio sources (prerecorded audio, controlled microphone input, test fixtures).

---

## 15. Secure Supabase Edge Function AI Backend Proxy (Step 13)

```text
                  ┌──────────────────────────────────────────┐
                  │          Flutter Mobile Client           │
                  │   (Holds only anon key + user session)   │
                  └────────────────────┬─────────────────────┘
                                       │
                        HTTPS / TLS    │  Authorization: Bearer <JWT>
                        PostgreSQL RLS │  apikey: <SUPABASE_ANON_KEY>
                                       ▼
                  ┌──────────────────────────────────────────┐
                  │          Supabase Edge Functions         │
                  │                                          │
                  │  ┌────────────────────────────────────┐  │
                  │  │ guardcall-ai-analyze               │  │
                  │  │ • Validates JWT authentication     │  │
                  │  │ • Validates conversation bounds    │  │
                  │  │ • Reads OPENAI/GEMINI_API_KEY      │  │
                  │  │ • Dispatches prompt to LLM         │  │
                  │  │ • Validates strict JSON schema     │  │
                  │  └────────────────────────────────────┘  │
                  │                                          │
                  │  ┌────────────────────────────────────┐  │
                  │  │ guardcall-stt                      │  │
                  │  │ • Validates JWT authentication     │  │
                  │  │ • Validates audio format & size    │  │
                  │  │ • Reads SPEECH_TO_TEXT_API_KEY     │  │
                  │  │ • Dispatches audio to Whisper      │  │
                  │  │ • Discards raw audio immediately   │  │
                  │  └────────────────────────────────────┘  │
                  └────────────────────┬─────────────────────┘
                                       │
                                       ▼
                  ┌──────────────────────────────────────────┐
                  │    Upstream Cloud Providers (Private)    │
                  │    • OpenAI (gpt-4o-mini, Whisper)       │
                  │    • Google Gemini (gemini-1.5-flash)    │
                  └──────────────────────────────────────────┘
```

### Key Principles of Step 13:
1. **API Secrets Kept Strictly Server-Side:**
   Mobile client binaries (APKs) can be easily disassembled. In production (`AI_BACKEND=edge_function`), no OpenAI, Gemini, or Speech-to-Text API keys are present in Flutter source, `.env`, or build configs. Secrets reside solely in Supabase Edge Function environment secrets (`Deno.env.get(...)`).
2. **Authenticated Access Only:**
   Edge Functions verify caller identity using `supabase.auth.getUser()`. Anonymous or unauthenticated requests are rejected immediately with HTTP 401.
3. **Payload Bounds & Defense-in-Depth:**
   `guardcall-ai-analyze` enforces a maximum of 100 conversation lines, a 2,000-character line limit, and a 50,000-character overall limit. `guardcall-stt` enforces a strict 10MB audio buffer limit.
4. **Zero Transcript or Audio Persistence in Database:**
   Neither the conversation text nor the audio recording is stored in PostgreSQL tables or Supabase Storage. Audio buffers are discarded immediately after transcription. Only structured risk telemetry (threat scores, signal types, timestamp) is synchronized for call history.
5. **Local Development Backward Compatibility:**
   Direct developer clients (`RemoteAIScamDetectionEngine`, `RemoteSpeechToTextService`) remain available for rapid local iteration under `AI_BACKEND=direct_dev`. Safe offline demonstrations default cleanly to `AI_BACKEND=mock`.

---

## 14. Step 15 — End-to-End AI & STT Pipeline Integration

Step 15 establishes a single, unified orchestration layer connecting audio ingestion, speech recognition, conversational dialogue models, threat evaluation, elderly-friendly UI indicators, and call history.

### End-to-End Pipeline Architecture:

```text
AudioInput (Scenario / Pre-recorded / Bytes)
    │
    ▼
SpeechToTextService
    ├── MockSpeechToTextService (100% offline, deterministic)
    ├── RemoteSpeechToTextService (Direct Dev Whisper API)
    └── EdgeFunctionSpeechToTextService (Secure Supabase proxy)
    │
    ▼
ConversationLine[] (Chronological dialogue turns, normalized speaker & text)
    │
    ▼
ScamDetectionEngine
    ├── MockScamDetectionEngine (Offline multi-turn compounding heuristics)
    ├── RemoteAIScamDetectionEngine (Direct OpenAI/Gemini client)
    └── EdgeFunctionScamDetectionEngine (Authenticated Edge Function proxy)
    │
    ▼
RiskAnalysis (riskScore 0–100, confidence 0–1, 9 canonical signals, deterministic tier)
    │
    ├──► Active Call / Demo UI (Live waveform, turn-by-turn dialogue stream)
    ├──► Risk Meter (Dynamic radial arc & color-coded badge)
    ├──► Scam Warning Dialog (High/Critical intervention triggers: "End Call", "I'm Safe", "Alert Family")
    └──► Call History Repository (In-memory record log, optional cloud sync)
```

### Three Execution Modes:
1. **OFFLINE MOCK (Default):**
   - Resolves: `MockSpeechToTextService` + `MockScamDetectionEngine`.
   - Requires zero network, zero secrets, zero cloud accounts.
   - Demo Center operates 100% offline with progressive multi-turn analysis.
2. **DIRECT DEVELOPMENT (Local Development Only):**
   - Resolves: `RemoteSpeechToTextService` + `RemoteAIScamDetectionEngine`.
   - Directly calls external OpenAI / Gemini / Whisper endpoints.
   - Strictly labeled Development Only; never exposed to production users.
3. **EDGE FUNCTION (Production Target):**
   - Resolves: `EdgeFunctionSpeechToTextService` + `EdgeFunctionScamDetectionEngine`.
   - Authenticated through Supabase user JWT tokens.
   - Provider API keys remain server-side in Supabase Secrets.

### Platform Boundaries & Limitations:
- **Cellular Audio Ingestion:** Standard Android permissions forbid user applications from intercepting or recording cellular voice calls. GuardCall currently demonstrates conversation analysis through simulated/demo audio and controlled audio inputs.
- **Whisper Speaker Diarization:** Automated single-channel speech recognition (Whisper) does not distinguish caller voice from receiver voice. Turns default to `Speaker.caller` or ingest structured multi-speaker fixtures.
- **Database Status:** Live Supabase database deployment remains postponed. All features operate fully in-memory without database dependencies.

---

## 15. Step 16 — Family Circle & Caregiver Experience

Step 16 implements a polished, coherent Family Circle and caregiver threat response experience for the hackathon prototype.

### Core Experience Flow:
```text
Senior User
    │
    ▼
Trusted Family Circle (Authorized via mutual consent / RLS)
    │
    ▼
Scam Detected (Compounded risk score ≥ 50 or 75)
    │
    ▼
"Alert Family" (Intervention action on warning dialog)
    │
    ▼
Simulated Family Alert (Recorded locally to FamilyAlertService with stream event)
    │
    ▼
Caregiver View & Detail Modal
    ├── WHAT HAPPENED: "GuardCall detected a high-risk scam conversation"
    ├── WHY IT WAS FLAGGED: Specific detected signals (e.g., Authority impersonation, Urgency)
    ├── WHAT THE USER DID: Senior intervention choice (e.g., User selected End Call)
    └── WHAT CAREGIVER CAN DO: Safe actions ("Contact Family Member", "Mark as Reviewed")
```

### Authorization & Security Model:
1. **Caregiver Access Foundation:**
   - Conceptual authorization depends strictly on: `owner_user_id` + `caregiver_user_id` + `is_active = true`.
   - Adding an email address or contact name does **not** grant authorization.
   - Contact identifiers (`contact_identifier`) are never treated as authentication credentials.
   - A disabled relationship (`is_active = false`) completely revokes alert access.
2. **Pending Invitations:**
   - Invitations require the invited caregiver to authenticate with Supabase Auth and accept the invite before access is granted.
   - In offline/demo mode, invitation delivery is simulated locally and clearly labeled: `"Demo Invitation Created: Invitation delivery is simulated in this prototype."`
   - Senior users can inspect and revoke pending invitations at any time.
3. **Caregiver View & Detail Presentation:**
   - Clearly labeled `CAREGIVER PERSPECTIVE • DEMO` when viewing simulated alerts.
   - Displays protected senior identity (`Robert Jenkins (Father)`) and active authorization status.
   - Shows risk level, numerical score (e.g., `92/100`), threat type, detected signal badges, plain-language explanation, and recorded intervention status.
   - Safe informational actions only: simulated call prompt and "Mark as Reviewed".
   - Never makes emergency, medical, or legal claims; never contacts authorities automatically.
4. **Zero-Audio & Zero-Transcript Privacy Boundary:**
   - Raw call audio is never retained, uploaded, or shared with caregivers.
   - Full conversational transcripts are never transmitted in family alerts.
   - Caregivers receive only structured risk metadata (threat tier, score, signal tags, explanation summary, intervention action).
5. **Simulated Delivery Constraints:**
   - Database deployment remains postponed.
   - No SMS, WhatsApp, FCM, email, or APNs push notifications are implemented or sent.

---

## 16. Step 17 — Caregiver Alert & Notification Delivery Architecture

Step 17 establishes the notification and caregiver-alert delivery architecture, decoupling threat assessment and senior intervention from notification transport mechanisms.

### Notification Delivery Pipeline:
```text
Scam Detection (MockScamDetectionEngine / Hybrid AI)
      ↓
RiskAnalysis (Threat classification & signal extraction)
      ↓
Intervention Dialog (Senior user presented with risk warnings)
      ↓
"Alert Family" (Explicit senior-authorized action)
      ↓
FamilyAlertService (Records alert & builds NotificationRequest)
      ↓
NotificationService Abstraction (Provider-neutral interface)
      ↓
┌────────────────────────────────────────────────────────┐
│ OFFLINE / DEMO DEFAULT: SimulatedNotificationService    │
│ • Zero network traffic / Zero third-party calls        │
│ • Deterministic, privacy-minimized in-memory dispatch  │
│ • Broadcasts local NotificationEvent stream            │
└────────────────────────────────────────────────────────┘
      ↓
Caregiver View & Notification UI
      ├── Alert Status: Created
      ├── Notification Status: SIMULATED
      └── Explicit Disclaimer: "Demo only — no message was actually sent."
```

### Future Extensibility:
```text
NotificationService Abstraction
      ↓
┌───────────────────────┬────────────────────────┬──────────────────────┐
│ FcmNotificationService│ ApnsNotificationService│ SmsNotificationService│
│   (NOT IMPLEMENTED)   │    (NOT IMPLEMENTED)   │   (NOT IMPLEMENTED)  │
└───────────────────────┴────────────────────────┴──────────────────────┘
```

### Core Architecture Components:

1. **`NotificationService` Abstraction (`lib/core/services/notification_service.dart`):**
   - Clean, provider-neutral interface with `sendFamilyAlert(NotificationRequest request)`.
   - Free from direct dependencies on Firebase, FCM, APNs, Twilio, WhatsApp, SMTP, or Supabase.
   - Injectable singleton with `NotificationService.instance`, `setInstance(...)`, and `resetToDefault()`.
   - Placeholder provider interfaces (`FcmNotificationService`, `ApnsNotificationService`, `SmsNotificationService`, `EmailNotificationService`) clearly marked `NOT IMPLEMENTED` with zero fake network code.

2. **Typed Lifecycle & Result Model:**
   - `NotificationStatus`: `simulated`, `queued`, `sent`, `delivered`, `failed`, `unavailable`.
   - Prototype rule: Only `SIMULATED` or `UNAVAILABLE` are returned by the offline demo. The system never claims `SENT` or `DELIVERED` without a verified physical transport channel.
   - `NotificationResult`: Typed outcome containing status, safe human-readable message, and optional metadata.
   - `NotificationEvent`: Stream-published event carrying structured threat telemetry for real-time UI observation.

3. **`SimulatedNotificationService` (`lib/core/services/simulated_notification_service.dart`):**
   - Default provider implementation operating completely offline and in-memory.
   - Exactly zero network requests, zero SMS, zero email, zero push notification APIs.
   - Publishes to `Stream<NotificationEvent>` so caregiver and debug views can react instantaneously.
   - Respects user preferences: if Family Alerts are toggled off in Settings, returns `NotificationStatus.unavailable`.

4. **Risk-Based Notification Policy (`lib/core/services/notification_policy.dart`):**
   - Pure decision layer evaluating whether a notification should be requested based on canonical risk tiers:
     - `SAFE` (0–39) → No family notification.
     - `SUSPICIOUS` (40–70) → No automatic family notification.
     - `HIGH` (71–84) & `CRITICAL` (85–100) → Eligible for family notification upon explicit senior user intervention.
   - Reuses existing `RiskAnalysis`; no duplicate ML or heuristic logic.

5. **Notification Preferences (`lib/core/services/notification_preferences.dart` & Settings Screen):**
   - Allows users to enable/disable Family Alerts.
   - Displays clear notification mode information (`Demo / Simulated Mode`).
   - Displays user-friendly explanation: *"Family alerts are simulated in this hackathon prototype. No real SMS, email, or push notifications are sent."*

6. **Caregiver Lifecycle Transparency:**
   - Caregiver view explicitly distinguishes `Alert: Created` from `Notification: SIMULATED` or `UNAVAILABLE`.
   - Detail modal features a dedicated `NOTIFICATION LIFECYCLE` card detailing alert ID, dispatch status, timestamp, and simulated delivery notices.
   - Guarantees complete honesty: no fake delivery receipts, no fabricated external timestamps.

---

## 18. Step 18 — Privacy, Security, Accessibility & Production Hardening Architecture

Step 18 hardens the GuardCall application across all operational domains:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   GUARDCALL HARDENING ARCHITECTURE                      │
├────────────────────────────────────────────────────────────────────────┤
│ 1. LOGGING & SENSITIVE DATA BOUNDARIES                                 │
│    • AppLogger centralized logging pipeline                            │
│    • Automated regex redaction of OTP, PIN, CVV, passwords, tokens     │
│    • Suppressed debug logs in release-oriented builds                  │
│    • Zero audio & zero transcript logging guarantee                    │
├────────────────────────────────────────────────────────────────────────┤
│ 2. CONFIGURATION & SECRET HARDENING                                    │
│    • .env git-ignored; .env.example strictly sanitized placeholders    │
│    • Zero provider secrets or service_role keys in Flutter client code │
│    • Fail-safe offline demo fallback if any credentials are missing    │
├────────────────────────────────────────────────────────────────────────┤
│ 3. ACCESSIBILITY & ELDERLY UX SAFETY                                   │
│    • AccessibilityPreferences reactive singleton for Reduce Motion     │
│    • Dynamic animation & shadow blur dampening for motion sensitivity  │
│    • Multi-modal risk status (Text label + Icon + Color)               │
│    • Destructive action confirmations (Sign Out, Revoke, Clear History)│
│    • Responsive layouts wrapped in Expanded widgets (Zero overflows)   │
├────────────────────────────────────────────────────────────────────────┤
│ 4. CANONICAL THREAT SCORE AGREEMENT                                    │
│    • Canonical risk thresholds (0–39 Safe, 40–70 Suspicious,           │
│      71–84 High Risk, 85–100 Critical Threat)                         │
│    • Harmonized Fake KYC scenario (Score 75 = High Risk everywhere)    │
├────────────────────────────────────────────────────────────────────────┤
│ 5. PLATFORM PERMISSIONS & DISCLOSURE                                   │
│    • Production AndroidManifest.xml has ZERO dangerous permissions     │
│    • Clear prototype disclosures across Settings, Demo Center, Alerts  │
│    • Database deployment remains strictly postponed                    │
└────────────────────────────────────────────────────────────────────────┘
```









