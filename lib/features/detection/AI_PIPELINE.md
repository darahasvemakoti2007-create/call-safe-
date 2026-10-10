# GuardCall — AI Detection Pipeline (Steps 12 & 13)

This document provides a comprehensive, beginner-friendly guide to GuardCall's AI Scam Detection Engine, provider abstractions, and secure backend proxy architecture.

---

## 1. What the Scam Detection Engine Does
The Scam Detection Engine is GuardCall's cognitive reasoning layer. When a telephone conversation occurs, the engine analyzes the transcript of spoken dialogue to identify predatory manipulation patterns.

Unlike traditional Caller ID databases (which merely check a phone number against a blocklist that scammers easily bypass with VoIP spoofing), GuardCall evaluates **conversational psychology**:
- Is the caller creating artificial time urgency?
- Are they impersonating a law enforcement agency or bank department?
- Are they demanding one-time passwords (OTPs) or wire transfers?
- Are they attempting to isolate the victim from their loved ones?

The engine outputs an explainable `RiskAnalysis` object containing a threat score (0–100), a risk tier (`Safe`, `Suspicious`, `High`, `Critical`), confidence metric (0.0–1.0), and specific tagged `ScamSignal` items.

---

## 2. Operational Modes

GuardCall supports three distinct detection backend modes:

### Mode 1 — Offline Demo (Default)
- **Engine:** `MockScamDetectionEngine`
- **Execution:** 100% on-device, zero network traffic.
- **Privacy:** Transcript lines exist only in transient local memory. Nothing leaves the device.
- **Use Case:** Hackathon demonstrations, offline environments, zero-setup testing.

### Mode 2 — Direct Development Provider (LOCAL DEVELOPMENT ONLY)
- **Engine:** `RemoteAIScamDetectionEngine`
- **Execution:** Direct HTTPS requests from Flutter to OpenAI (`gpt-4o-mini`) or Gemini (`gemini-1.5-flash`).
- **Privacy:** Spoken dialogue is transmitted directly from the phone to third-party APIs.
- **Security Boundary:** **LOCAL DEVELOPMENT ONLY.** Requires local API keys in `.env`. NOT suitable for production APK releases.

### Mode 3 — Secure Supabase Edge Function AI Proxy (Production Target)
- **Engine:** `EdgeFunctionScamDetectionEngine`
- **Execution:** Mobile app authenticates via Supabase JWT and calls `guardcall-ai-analyze`.
- **Security Boundary:** Provider API secrets (`OPENAI_API_KEY`, `GEMINI_API_KEY`) live exclusively in Supabase Edge Function environment secrets. The mobile client holds zero provider secrets.

---

## 3. Difference Between Mock, Direct, and Edge Function Modes

| Dimension | Mode 1: Offline Mock | Mode 2: Direct Dev | Mode 3: Production Edge Function |
| :--- | :--- | :--- | :--- |
| **Execution** | 100% On-Device & Deterministic | Direct HTTPS from Phone to LLM | Authenticated Proxy via Supabase Edge Function |
| **Provider** | Local keyword & heuristic logic | OpenAI / Google Gemini directly | OpenAI / Gemini via `guardcall-ai-analyze` |
| **Internet Required**| **No** (operates offline) | Yes | Yes |
| **Mobile Secrets** | None | Requires local API key in `.env` | **None** (only public `anon` key + user JWT) |
| **Server Secrets** | None | None | `OPENAI_API_KEY` or `GEMINI_API_KEY` in Supabase |
| **Privacy Boundary** | Audio/dialogue never leaves device | Audio/dialogue sent to 3rd-party directly | Audio/dialogue sent to authenticated backend proxy |
| **Database Storage**| None | None | **Zero database storage** (transcripts never stored) |

---

## 4. Why Provider Abstraction Exists
GuardCall defines the abstract interface `ScamDetectionEngine`:
```dart
abstract class ScamDetectionEngine {
  Future<RiskAnalysis> analyzeConversation(List<ConversationLine> conversation);
}
```
Because the UI and audio pipeline interact **only** with this abstract interface:
1. **Offline Demonstrations Never Break:** When evaluators, hackathon judges, or users run the app without internet or API keys, `DetectionProviderFactory` injects `MockScamDetectionEngine`.
2. **Pluggable AI Backends:** The app can switch between Mock, Direct Dev, and Edge Function backends with zero UI code modifications.
3. **Graceful Degradation:** If remote AI encounters a network dropout or timeout, the pipeline falls back gracefully to local heuristic rules without crashing.

---

## 5. Why "An API Key Inside an Android APK Cannot Be Treated as a Production Secret"
> [!CAUTION]
> **Mobile Client Secret Vulnerability:**  
> Anyone who downloads an Android `.apk` file can decompile it in seconds using standard reverse-engineering tools like `apktool` or `jadx`. Any API key (such as an OpenAI or Gemini secret key) bundled inside the application code or build configuration can be extracted by an attacker.
>
> If an attacker extracts your secret key:
> 1. They can drain your billing account with unauthorized API calls.
> 2. They can launch prompt injection attacks using your quota.
> 3. They can cause denial of service for all legitimate users.
>
> **The Secure Architecture:**  
> In Step 13, GuardCall introduces the secure backend proxy pattern:
> ```
> Flutter Client (User JWT + Anon Key)
>    │
>    ▼ (HTTPS / TLS)
> Supabase Edge Function: guardcall-ai-analyze
>    │ (Validates JWT + rate limits + sanitizes prompt)
>    │ (Reads Deno.env.get('OPENAI_API_KEY') server-side)
>    ▼
> OpenAI / Gemini API
>    │
>    ▼ (Strict JSON schema validation)
> Sanitized RiskAnalysis telemetry
>    │
>    ▼
> Flutter Client
> ```

---

## 6. Strict AI Response Schema Validation
The `guardcall-ai-analyze` function and `RemoteAIScamDetectionEngine` validate AI output against a strict schema:
- `risk_score`: Integer between `0` and `100`.
- `confidence`: Float between `0.0` and `1.0`.
- `signals`: Array of objects matching the 9 recognized GuardCall signal categories:
  1. `urgency`
  2. `fear_threat`
  3. `authority_impersonation`
  4. `sensitive_information_request`
  5. `financial_pressure`
  6. `isolation`
  7. `emotional_manipulation`
  8. `remote_access_request`
  9. `suspicious_link`
- `summary`: Non-empty plain text explanation.

Any malformed, out-of-range, or unrecognized AI response is immediately rejected with a typed `DetectionException`.

---

## 7. Platform Limitation: Why Real Cellular Call Capture is Still NOT Implemented
Standard Android security restrictions strictly isolate cellular telephony audio for user privacy and wiretapping prevention. Standard Android SDK apps cannot intercept cellular voice calls or eavesdrop on phone lines. GuardCall respects platform security and evaluates speech through simulated scenarios, prerecorded audio files, or user-consented microphone inputs.
