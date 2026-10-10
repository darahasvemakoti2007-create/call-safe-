# GuardCall — End-to-End AI Scam Detection Pipeline

## 1. Architectural Overview

GuardCall provides a modular, privacy-respecting conversation analysis pipeline engineered to protect seniors from social engineering and phone scams. The pipeline is designed around a single orchestration layer:

```
AudioInput
    ↓
SpeechToTextService
    ↓
ConversationLine[]
    ↓
ScamDetectionEngine
    ↓
RiskAnalysis
    ↓
Demo / Active Call UI
    ↓
Risk Meter (0–100) & Status Badge
    ↓
Warning / Intervention Dialog
    ↓
Call History Repository
```

The system strictly decouples audio transcription and threat intelligence from Flutter UI widgets, enabling seamless switching between operational backends without code modifications.

---

## 2. Supported Execution Modes

GuardCall supports three distinct operational modes, selectable via `.env` or build environment variables:

| Mode | `AI_BACKEND` | Engine Implementation | Credential Location | Network Required | Production Ready? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **OFFLINE MOCK** *(Default)* | `mock` | `MockScamDetectionEngine` | None (zero credentials) | **No** (100% offline) | Yes (for offline demos) |
| **DIRECT DEVELOPMENT** | `direct_dev` | `RemoteAIScamDetectionEngine` | Local client device (`.env`) | Yes (OpenAI / Gemini API) | **No** (Local dev only) |
| **EDGE FUNCTION** | `edge_function` | `EdgeFunctionScamDetectionEngine` | Server-side Supabase Secrets | Yes (Supabase Edge Proxy) | **Yes** (Production target) |

### 1. OFFLINE MOCK MODE (Default)
- **Engine:** `MockScamDetectionEngine`
- **Behavior:** Executes a sophisticated multi-turn heuristic rules engine entirely in memory. It detects compounding indicators, evaluates sequence escalation, and enforces protective banking context filters.
- **Privacy:** 100% on-device. Zero network traffic, zero analytics, zero external API keys required.
- **Reliability:** Guaranteed to function in low-connectivity or air-gapped environments.

### 2. DIRECT DEVELOPMENT MODE (Local Development Only)
- **Engine:** `RemoteAIScamDetectionEngine`
- **Behavior:** Directly invokes OpenAI (`gpt-4o-mini`) or Google Gemini (`gemini-1.5-flash`) REST endpoints from the mobile device.
- **Scope:** Restricted strictly to internal testing, prompt engineering, and fixture generation.
- **Warning:** Direct client API keys MUST NEVER be bundled into production APK builds.

### 3. EDGE FUNCTION MODE (Production Target)
- **Engine:** `EdgeFunctionScamDetectionEngine`
- **Behavior:** Routes requests to the secure Supabase Edge Function `guardcall-ai-analyze` via `GuardCallEdgeFunctionClient`.
- **Security:** External AI provider keys (`OPENAI_API_KEY`, `GEMINI_API_KEY`) reside exclusively in Supabase server-side secrets. The Flutter app only sends an authenticated user JWT token.
- **Zero Transcript Storage:** The Edge Function processes dialogue turns transiently in server memory and returns structured threat metadata. No raw transcripts or audio are stored in the database.

---

## 3. Threat Signal Taxonomy

GuardCall enforces a strict, closed taxonomy of **nine canonical scam signals**. Neither LLMs nor rule engines may emit arbitrary signal types:

1. `urgency`: Artificial time pressure or manufactured deadlines.
2. `fear_threat`: Coercive intimidation, legal threats, or arrest warnings.
3. `authority_impersonation`: Impersonating police, central banks, tax officials, or courts.
4. `sensitive_information_request`: Demanding OTPs, PINs, passwords, or CVVs.
5. `financial_pressure`: Demands for instant wire transfers or UPI payments.
6. `isolation`: Instructing the victim to keep the call secret from family.
7. `emotional_manipulation`: Fabricating emergencies regarding grandchildren or relatives.
8. `remote_access_request`: Requesting installation of AnyDesk, TeamViewer, or screen-sharing tools.
9. `suspicious_link`: Sending unverified payment links or phishing URLs.

---

## 4. Deterministic Risk Scoring & Thresholds

LLMs are strictly forbidden from inventing arbitrary risk tiers. Risk tiers are deterministically derived from the numeric risk score (0–100):

| Risk Score | Tier | Action & UI State |
| :--- | :--- | :--- |
| **0 – 40** | `Safe` | Green badge, normal conversational monitoring. |
| **41 – 70** | `Suspicious` | Orange badge, elevated monitoring notice. |
| **71 – 84** | `High` | Red badge, high-prominence scam warning modal displayed. |
| **85 – 100** | `Critical` | Red badge, immediate intervention warning (`End Call` / `Alert Family`). |

---

## 5. What is Real vs. What Remains Simulated

### What is Real:
- Single-orchestration end-to-end pipeline (`ConversationPipeline.processAudio(AudioInput)`).
- Turn-by-turn progressive risk detection during simulated calls.
- Strict response normalization, numeric validation, and error typing (`DetectionException`).
- Supabase Edge Functions (`guardcall-ai-analyze` and `guardcall-stt`) with JWT authentication and input validation.
- Settings diagnostic dashboard reflecting active engine status (`OFFLINE`, `DIRECT DEV`, `EDGE PROXY`).
- Comprehensive unit and integration test coverage (168 tests passing).

### What Remains Simulated:
- **Cellular Call Audio Capture:** Standard Android APIs explicitly prohibit user applications from recording or intercepting cellular voice calls. Audio input is supplied via controlled test fixtures, mock scenarios, or pre-recorded audio.
- **Caregiver Push Notifications:** Simulated via in-app UI modals (`SimulatedFamilyAlert`) rather than production FCM/APNs services.
- **Database Deployment:** Live Supabase database deployment remains postponed; all features operate safely using in-memory repositories and client abstractions.
