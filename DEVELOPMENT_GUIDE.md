# GuardCall — Developer & Engineering Guide

## 1. Overview
This guide provides development standards, architectural rules, and security guidelines for engineers and contributors to GuardCall.

---

## 2. Hardening Policies

### 1. Logging Policy (`AppLogger`)
- **NEVER** use `print()`, `debugPrint()`, or direct `developer.log()` for operational code.
- Always use `AppLogger.debug()`, `AppLogger.info()`, `AppLogger.warning()`, or `AppLogger.error()`.
- The logger automatically sanitizes credentials (`Bearer`, `apiKey`, `password`, `otp`, `pin`, `cvv`).
- Never pass raw audio buffers, dialogue transcripts, or authentication tokens into log messages.
- In release builds, debug logs are completely suppressed.

### 2. Configuration & Secret Management
- Real secrets must NEVER be committed to Git.
- `.env` is ignored by Git; `.env.example` contains only harmless placeholders.
- Client Flutter code must NEVER reference or require Supabase `service_role` keys or provider private keys.
- Production AI and STT calls must always route through authenticated Supabase Edge Functions (`guardcall-ai-analyze`, `guardcall-stt`).

### 3. Accessibility & UX Guidelines
- **Target Audience:** Seniors and elderly individuals.
- **Typography:** Primary text must be legible (14sp+ body, bold headings).
- **Touch Targets:** All interactive buttons must have a minimum tap height of 48dp.
- **Color Independence:** Never communicate risk status by color alone; always pair text labels (`Safe`, `Suspicious`, `High Risk`, `Critical Threat`) with dedicated icons and scores.
- **Reduce Motion:** Always respect `AccessibilityPreferences.instance.reduceMotion`. When enabled, animations must be reduced or disabled, and intense glowing shadows replaced with subtle contrast borders.
- **Destructive Actions:** Actions like Sign Out, Revoking Invitations, and Clearing History must prompt for user confirmation.

### 4. Risk Threshold Canonical Definitions
Always use `RiskLevelScore.fromScore(score)`:
- `0–39`: Safe
- `40–70`: Suspicious
- `71–84`: High Risk
- `85–100`: Critical Threat
Never implement local ad-hoc threshold comparisons (e.g. `score >= 75`) that conflict with canonical tiers.

---

## 3. Testing & Verification

Run tests:
```bash
flutter test
```
Analyze code:
```bash
flutter analyze
```

---

## 4. Current Prototype Limitations
- Supabase deployment remains postponed.
- Outward notifications are simulated locally in-memory.
- Live cellular call audio recording is restricted by Android OS; controlled demo scenarios provide safe demonstration.
