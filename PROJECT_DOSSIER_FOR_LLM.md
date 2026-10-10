# GuardCall — Complete Project Dossier & LLM Context Document

> **System Prompt / LLM Context Instruction:**  
> This document contains the complete, authoritative specification, architecture, database schema, code structure, testing state, and operational boundaries of the **GuardCall** project. Feed this document to any LLM (Claude, ChatGPT, Gemini, etc.) to give it full context on the codebase, architecture, hackathon presentation, and implementation details.

---

## 1. Executive Summary & Vision

- **Project Name:** GuardCall
- **Tagline:** AI-Powered Real-Time Social Engineering & Phone Scam Shield for Elderly & Vulnerable Users
- **Primary Tech Stack:** Flutter (Dart 3.x), Android (API 34–37), Supabase (PostgreSQL 15+, Auth, RLS, Edge Functions, Realtime)
- **Problem Statement:**  
  Over $10B+ is stolen annually through social engineering phone scams targeting elderly citizens (e.g., Fake Bank KYC updates, Digital Arrest / Police impersonation, Lottery / Prize fraud, Urgent Family Emergency impersonation). Traditional Caller ID / spam-blocking apps rely on static blacklists that fail against dynamically spoofed numbers and VoIP rotation.
- **GuardCall’s Solution:**  
  GuardCall analyzes **in-conversation conversational behavior in real time** using explainable linguistic heuristics and conversational AI:
  1. Identifies high-risk social engineering markers (manufactured urgency, authority threats, OTP requests, unverified APK download coercion, isolation tactics).
  2. Dynamically calculates a progressive threat score (0–100) and risk tier (`Safe`, `Suspicious`, `High`, `Critical`).
  3. Displays an immediate, accessible, elderly-friendly **Scam Intervention Dialog** at score ≥ 75.
  4. Provides a **Family Circle & Caregiver Network** with verified zero-trust pairing and structured threat alerts.

---
t
## 2. Privacy by Design & Platform Boundaries

GuardCall adheres to strict privacy and regulatory compliance boundaries:

1. **Zero Raw Audio Retention:** Raw call audio is never recorded to disk, never uploaded to a cloud database, and never shared with caregivers.
2. **Zero Full-Transcript Cloud Storage:** Complete spoken dialogue is never persisted to any cloud database table. Only structured threat signals (`signal_type`, `severity`, `explanation`) and telemetry (`risk_score`, `duration`, `started_at`) are saved.
3. **Android Telephony Limitations:** Standard Android OS platform restrictions (API 29+) sandbox phone call audio. Third-party applications cannot intercept or tap active cellular call audio streams without root or OEM integration. GuardCall demonstrates its engine via controlled audio input, high-fidelity mock scenario players, and live microphone demos.
4. **Caregiver Notification Boundary:** External notifications (SMS, WhatsApp, FCM push) are currently simulated locally in-memory (`SimulatedNotificationService`). No third-party notification keys or external carrier charges are required.
5. **Zero-Trust Row-Level Security (RLS):** Every database row in Supabase is strictly isolated by `auth.uid()`. Caregivers can only view alerts for seniors who have mutually and actively linked them in `family_relationships`.

---

## 3. Architecture & Operational Modes

GuardCall is built with a clean, decoupled architecture supporting three execution modes:

```
[Audio Input / Microphone / Demo Audio]
                     │
                     ▼
           [Speech-to-Text Pipeline]
                     │
                     ▼
         [ConversationLine Stream]
                     │
                     ▼
           [Scam Detection Engine]
       ┌─────────────┴─────────────┐
       ▼                           ▼
[Mock Heuristic Engine]    [Supabase Edge Function]
 (100% Offline / Fast)     (guardcall-ai-analyze)
       │                           │
       └─────────────┬─────────────┘
                     ▼
           [RiskAnalysis (0–100)]
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
 [Scam Warning Dialog]     [Telemetry Sync]
 (Score ≥ 75 Intervention) (Supabase / In-Memory)
        │                         │
        ▼                         ▼
 [Alert Family Action]     [Caregiver View]
 (Simulated Notification)  (Zero-Trust Circle)
```

### The Three Operational Execution Modes:
1. **OFFLINE MOCK (Default / Hackathon-Proof):**  
   Uses `MockScamDetectionEngine` and `MockSpeechToTextService`. 100% in-memory heuristic matching, 0 network latency, 0 external dependencies, completely functional when air-gapped without Wi-Fi or mobile data.
2. **DIRECT DEVELOPMENT (Dev Only):**  
   Direct API calls to OpenAI / Gemini / Whisper for local rapid prototyping. Strictly prohibited in production APK builds to avoid client-side API key exposure.
3. **EDGE FUNCTION (Production Cloud Architecture):**  
   Proxies speech and AI requests through secure Supabase Edge Functions (`guardcall-ai-analyze`, `guardcall-stt`) using user JWT tokens (`Authorization: Bearer <token>`). AI provider keys remain secret on the server.

---

## 4. Canonical Risk Scoring & Detection Heuristics

### Harmonized Risk Tiers
| Score Range | Risk Level | Meaning & App Behavior |
| :--- | :--- | :--- |
| **0 – 39** | `Safe` | Green badge. Normal conversation, standard banking notifications. |
| **40 – 70** | `Suspicious` | Orange badge. Mild pressure or unverified claims detected. Caution advised. |
| **71 – 84** | `High Risk` | Crimson badge. **Threshold 75 triggers Scam Warning Dialog** and unlocks Alert Family. |
| **85 – 100** | `Critical` | Red pulsing badge. Active extortion, digital arrest threat, OTP demand. |

### Canonical Scam Heuristic Signals
- `authority_impersonation`: Falsely claiming to be police, CBI, RBI, tax department, or bank security.
- `urgency`: Setting extreme time limits ("within 15 minutes", "account blocked in 2 hours").
- `otp_solicitation`: Demanding 6-digit one-time password or UPI PIN.
- `remote_access`: Coercing the user to install TeamViewer, AnyDesk, or QuickSupport APKs.
- `digital_arrest`: Threatening immediate legal arrest or interrogation over video call.
- `suspicious_link`: Directing user to open unverified payment or verification links.
- `isolation_tactic`: Warning user not to inform family members, spouse, or local police.

---

## 5. Complete Database Schema & RLS Policies (PostgreSQL)

Located in `supabase/schema.sql` and `supabase/migrations/`:

```sql
-- 1. PROFILES
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own profile" ON public.profiles FOR SELECT USING (id = auth.uid());
CREATE POLICY "Users insert own profile" ON public.profiles FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE USING (id = auth.uid());

-- 2. FAMILY CONTACTS (Emergency phone/email registry)
CREATE TABLE public.family_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    relationship TEXT,
    contact_identifier TEXT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.family_contacts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own contacts" ON public.family_contacts FOR ALL 
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 3. CALL SESSIONS (High-level call metadata — ZERO raw audio / ZERO transcripts)
CREATE TABLE public.call_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    risk_score INTEGER NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
    risk_level TEXT NOT NULL,
    scenario_type TEXT,
    intervention_status TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.call_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own call sessions" ON public.call_sessions FOR ALL 
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 4. RISK SIGNALS (Structured behavioral telemetry)
CREATE TABLE public.risk_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_session_id UUID NOT NULL REFERENCES public.call_sessions(id) ON DELETE CASCADE,
    signal_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    explanation TEXT NOT NULL,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.risk_signals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view signals for own calls" ON public.risk_signals FOR SELECT 
USING (EXISTS (SELECT 1 FROM public.call_sessions cs WHERE cs.id = risk_signals.call_session_id AND cs.user_id = auth.uid()));
CREATE POLICY "Users insert signals for own calls" ON public.risk_signals FOR INSERT 
WITH CHECK (EXISTS (SELECT 1 FROM public.call_sessions cs WHERE cs.id = risk_signals.call_session_id AND cs.user_id = auth.uid()));

-- 5. ALERTS (Caregiver escalations during high-risk calls)
CREATE TABLE public.alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_session_id UUID NOT NULL REFERENCES public.call_sessions(id) ON DELETE CASCADE,
    family_contact_id UUID NOT NULL REFERENCES public.family_contacts(id) ON DELETE CASCADE,
    risk_score INTEGER NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owners view own alerts" ON public.alerts FOR SELECT 
USING (EXISTS (SELECT 1 FROM public.call_sessions cs WHERE cs.id = alerts.call_session_id AND cs.user_id = auth.uid()));
CREATE POLICY "Owners insert own alerts" ON public.alerts FOR INSERT 
WITH CHECK (EXISTS (SELECT 1 FROM public.call_sessions cs WHERE cs.id = alerts.call_session_id AND cs.user_id = auth.uid()));

-- CAREGIVER READ POLICY (Step 11 Circle)
CREATE POLICY "Caregivers view alerts for active linked members" ON public.alerts FOR SELECT 
USING (EXISTS (
    SELECT 1 FROM public.call_sessions cs
    JOIN public.family_relationships fr ON fr.owner_user_id = cs.user_id
    WHERE cs.id = alerts.call_session_id
      AND fr.caregiver_user_id = auth.uid()
      AND fr.enabled = TRUE
));

-- 6. USER SETTINGS
CREATE TABLE public.user_settings (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    family_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    transcript_retention BOOLEAN NOT NULL DEFAULT FALSE,
    reduce_motion BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own settings" ON public.user_settings FOR ALL 
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 7. FAMILY RELATIONSHIPS (Mutual Pairing)
CREATE TABLE public.family_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    caregiver_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    relationship TEXT,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_family_relationship UNIQUE (owner_user_id, caregiver_user_id)
);
ALTER TABLE public.family_relationships ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owners view relationships" ON public.family_relationships FOR SELECT USING (owner_user_id = auth.uid());
CREATE POLICY "Owners create relationships" ON public.family_relationships FOR INSERT WITH CHECK (owner_user_id = auth.uid());
CREATE POLICY "Owners update relationships" ON public.family_relationships FOR UPDATE USING (owner_user_id = auth.uid());
CREATE POLICY "Owners delete relationships" ON public.family_relationships FOR DELETE USING (owner_user_id = auth.uid());
CREATE POLICY "Caregivers view relationships" ON public.family_relationships FOR SELECT USING (caregiver_user_id = auth.uid());

-- 8. FAMILY INVITATIONS
CREATE TABLE public.family_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    invited_email TEXT NOT NULL,
    relationship TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days')
);
ALTER TABLE public.family_invitations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owners manage invitations" ON public.family_invitations FOR ALL 
USING (owner_user_id = auth.uid()) WITH CHECK (owner_user_id = auth.uid());
```

---

## 6. Directory Structure & Key Files

```text
c:\Users\venup\OneDrive\Desktop\nsrit-app\
├── lib/
│   ├── app/
│   │   ├── app.dart                     # App root, MaterialApp, dark luxury theme
│   │   └── auth_gate.dart               # Session listener, route between Login and MainShell
│   ├── core/
│   │   ├── config/
│   │   │   └── app_config.dart          # Environment configuration (.env / compile defines)
│   │   ├── logging/
│   │   │   └── app_logger.dart          # Privacy-safe logger (scrubs tokens, zero audio/transcript)
│   │   ├── services/
│   │   │   ├── auth_service.dart        # Supabase Auth / Offline mock fallback
│   │   │   ├── auth_state.dart          # Global authentication state provider
│   │   │   ├── profile_service.dart     # User profile CRUD
│   │   │   ├── call_session_service.dart# Session telemetry persistence
│   │   │   ├── risk_signal_service.dart # Granular signal telemetry persistence
│   │   │   ├── family_contact_service.dart # Emergency contacts
│   │   │   ├── family_relationship_service.dart # Circle pairing & caregiver link
│   │   │   ├── family_alert_service.dart# Caregiver alert dispatcher
│   │   │   ├── notification_service.dart# Provider-neutral alert notification abstraction
│   │   │   ├── simulated_notification_service.dart # Zero-network in-memory alert service
│   │   │   ├── realtime_service.dart    # Supabase Realtime CDC listener
│   │   │   └── accessibility_preferences.dart # Reduce motion & high-contrast toggles
│   │   └── widgets/
│   │       ├── glass_card.dart          # Luxury frosted container widget
│   │       ├── risk_badge.dart          # Harmonized score badge widget
│   │       └── primary_button.dart      # Accessible touch button
│   └── features/
│       ├── alerts/
│       │   ├── scam_warning_dialog.dart # High-risk modal (End Call / I'm Safe / Alert Family)
│       │   └── simulated_family_alert.dart # Simulated notification confirmation modal
│       ├── calls/
│       │   └── active_call_screen.dart  # Live call monitoring view
│       ├── demo/
│       │   ├── demo_scenario.dart       # Scenario data model & turn definitions
│       │   ├── demo_scenarios.dart      # Catalog: Fake KYC, Digital Arrest, Lottery, Safe Bank
│       │   ├── demo_center_screen.dart  # Hackathon evaluator launchpad
│       │   └── demo_scenario_player_screen.dart # Progressive multi-turn simulator
│       ├── detection/
│       │   ├── scam_detection_engine.dart # Engine interface
│       │   ├── mock_scam_detection_engine.dart # Rule-based heuristic pattern matcher
│       │   ├── edge_function_scam_detection_engine.dart # Supabase proxy engine
│       │   ├── speech_to_text_service.dart # STT interface
│       │   └── risk_analysis.dart       # Score, signals, and explanation container
│       ├── family/
│       │   ├── family_screen.dart       # Senior Circle View & Caregiver Preview
│       │   ├── caregiver_view.dart      # Monitored seniors and threat feed
│       │   └── caregiver_alert_detail_dialog.dart # 4-part transparent alert breakdown
│       ├── history/
│       │   ├── call_history_screen.dart # Call telemetry and risk log
│       │   └── call_history_repository.dart # In-memory and cached repository
│       ├── home/
│       │   ├── home_screen.dart         # Main status shield, quick actions, tips
│       │   └── main_shell.dart          # Bottom navigation bar (5 tabs)
│       └── settings/
│           └── settings_screen.dart     # Preferences, security audit, sign-out
├── supabase/
│   ├── schema.sql                       # Complete PostgreSQL DDL and RLS policies
│   └── migrations/                      # Step 11 Family relationship migrations
├── tool/
│   ├── generate_crimson_deck.py         # 10-slide 16:9 executive presentation generator
│   ├── run_clean_e2e_verification.py    # 16-step automated Android UI verification
│   └── verify_category_o_offline.py     # Air-gapped offline test script
└── test/                                # 16 test suites (223/223 automated unit tests)
```

---

## 7. Automated Testing & Verification State

- **Unit & Domain Tests (`flutter test`):** **223 / 223 PASSING** (0 failures).
- **Static Analysis (`flutter analyze`):** **PASS** (0 warnings, 0 errors).
- **Air-Gapped Offline Verification (Category O):** **PASS (11/11 Steps)**. Tested on Android API 37 with `svc wifi disable` and `svc data disable`. The app cold-launches in 1.8s, navigates the Demo Center, runs multi-turn KYC simulation (10 ➔ 35 ➔ 75 High Risk), triggers Scam Warning Dialog, dispatches simulated family alert, and logs locally without network hangs or ANRs.
- **16-Step Live Demo Verification:** **PASS (16/16 Steps in 1m 30s)**.
- **RLS & Security Policies (Category J):** **PASS on Schema Inspection**. All 7 tables enforce zero-trust isolation bound to `auth.uid()`.

---

## 8. Demo Scenarios & Progressive Script

### 1. Fake KYC Update (Primary Demo — High Risk)
- **Turn 1 (Safe, Score 10):** "Hello, this is SBI customer service regarding your pending KYC..."
- **Turn 2 (Suspicious, Score 35):** "Your account will be blocked within 24 hours if not verified." (Triggers `urgency`).
- **Turn 3 (High Risk, Score 75):** "Please install our QuickSupport APK link or share your 6-digit OTP immediately." (Triggers `otp_solicitation`, `remote_access`, `authority_impersonation`).
- **Outcome:** Scam Warning Dialog appears immediately with 3 options:
  1. *End Call* (Terminates call and resets session)
  2. *I'm Safe* (Dismisses dialog, remains vigilant)
  3. *Alert Family* (Dispatches simulated alert to linked caregivers)

### 2. Digital Arrest / Contraband Extortion (Critical Risk — Score 95)
- Impersonates Mumbai Police / CBI.
- Threatens immediate arrest over seized parcel containing illegal passports and narcotics.
- Commands user not to disconnect or talk to anyone (`isolation_tactic`, `digital_arrest`).

### 3. Legitimate Bank Fraud Check (Benign Control — Score 15)
- Standard bank alert confirming a genuine transaction with yes/no response.
- Explicitly reminds user *never* to share OTPs or passwords.
- Demonstrates zero false positives.

---

## 9. Presentation Deck Details

A standalone, editable 16:9 widescreen presentation deck is available in the repository root:
- **File:** `GuardCall_Executive_Pitch.pptx`
- **Design Aesthetic:** Corporate Editorial / Burgundy & Sand (Deep Crimson `#781D2A`, Sand Ivory `#F6F4EE`, Slate Charcoal `#1E252B`, Accent Gold `#C99700`).
- **Slide Breakdown (10 Slides):**
  1. Title Slide: Executive Pitch & Problem Statement
  2. The Epidemic: $10B+ Lost to Social Engineering Scams
  3. The Architectural Blind Spot: Why Caller IDs & Blacklists Fail
  4. The Solution: Real-Time In-Call Linguistic Behavior Intelligence
  5. End-to-End Technical Architecture & Pipeline
  6. Explainable Threat Engine & Risk Matrix (0–100)
  7. Caregiver Circle: Zero-Trust Telemetry & Emergency Escalation
  8. Privacy by Design: Zero Audio Storage & PostgreSQL RLS
  9. Live Demonstration Flow & Verifications
  10. Business Model, Roadmap & Team

---

## 10. Rules for Any LLM Working with this Project

When assisting with GuardCall, any AI model MUST follow these rules:

1. **Maintain Privacy Guarantees:** NEVER propose code that logs raw audio, writes raw speech transcripts to a database, or sends unprotected PII to third-party endpoints.
2. **Never Claim Direct Cellular Call Recording is Implemented:** Always acknowledge standard Android OS permission boundaries and explain that live calls use controlled/simulated audio input.
3. **Keep Caregiver Notifications Transparent:** Acknowledge that external delivery (SMS, WhatsApp, FCM) is currently simulated in-memory (`SimulatedNotificationService`) and avoid generating fake networking code that pretends to send real external messages without credentials.
4. **Preserve RLS Model:** All database queries must remain bound to `auth.uid()` and follow the mutual pairing model in `family_relationships`.
5. **No Credentials in Code:** Never embed API keys, secrets, or `.env` contents directly into client-side Flutter source files.
