# GuardCall Call Intervention & Warning System (Step 6)

Welcome to the **GuardCall Intervention System** documentation. This document explains the purpose, threshold criteria, user actions, accessibility design, and future production roadmap for call interventions.

---

## 1. What the Warning System Does

In a live telephone call, presenting passive risk badges is often inadequate when a user is under active psychological manipulation. When social engineering escalates to intense urgency, legal threats, or credential extortion, GuardCall provides an active **visual intervention modal** (`ScamWarningDialog`).

The warning interrupts the user's attention, presents the current threat assessment, and offers immediate protective actions.

```text
Progressive Conversation
          │
          ▼
   RiskAnalysis
          │
          ▼
Is RiskLevel >= High?
    ├── YES (First time in call) ──► Present ScamWarningDialog (Modal)
    │                                         │
    │                   ┌─────────────────────┼─────────────────────┐
    │                   ▼                     ▼                     ▼
    │               End Call               I'm Safe            Alert Family
    │         (Terminates playback)  (Continues dialogue)  (Simulated alert)
    │                   │                     │                     │
    │                   ▼                     ▼                     ▼
    │           History: "Ended"      History: "Dismissed"  History: "Alerted"
    │
    └── NO ────────────────────────► Normal Playback Continues
```

---

## 2. Why High and Critical Trigger Intervention

Interventions are intentionally reserved for elevated threat tiers:

* **Safe (0–40)**: No intervention. Routine conversation flow.
* **Suspicious (41–70)**: Informational UI updates only. An isolated phrase (e.g. asking for an urgent callback) should not disrupt a user's phone call with an aggressive modal.
* **High (71–84)**: **Intervention Triggers**. Compounding pressure tactics detected (e.g., emotional manipulation + urgent wire transfer request in *Grandchild Emergency*).
* **Critical (85–100)**: **Intervention Triggers**. Severe coercion detected (e.g., arrest threats, official impersonation, or OTP/PIN credential solicitation in *Fake KYC* and *Digital Arrest*).

### Single-Intervention Guarantee
To prevent frustrating the user with repetitive modal popups during an ongoing conversation, the warning triggers **exactly once** per session when the threshold is first crossed.

---

## 3. What Each Action Means

The modal presents three unambiguous actions with large touch targets ($\ge 48\text{px}$):

### 1. "End Call" (Primary Action)
* **Demo Behavior**: Immediately pauses and halts the simulated playback, records the final `RiskAnalysis` in the local Call History with the status `"User selected End Call"`, and displays the final assessment.
* **Safety Philosophy**: Empowers vulnerable users with a single tap to disconnect from high-pressure scammers without having to confront them verbally.

### 2. "I'm Safe" (Secondary Action)
* **Demo Behavior**: Closes the warning dialog and resumes conversation playback from the next turn.
* **Crucial Invariant**: **Dismissal does NOT lower the risk score or clear detected signals.** GuardCall respects user autonomy but does not pretend a malicious conversation has magically become safe.

### 3. "Alert Family" (Tertiary Action)
* **Demo Behavior**: Records that a caregiver emergency alert was requested (`"Family alert requested"` in Call History) and opens the `SimulatedFamilyAlert` confirmation dialog.
* **Privacy & Isolation**: Operates entirely in memory with **zero network requests, zero SMS dispatch, and zero cloud persistence** in this prototype.

---

## 4. Why Actions are Simulated in the Prototype

1. **No Real Cellular Audio Capture**: GuardCall operates as a safe demo sandbox using pre-scripted conversational scenarios.
2. **No Real Cellular Call Termination**: Android platform security policies heavily restrict third-party apps from forcefully disconnecting standard cellular calls (`TelecomManager.endCall()` requires privileged system permissions or Android 9+ default dialer designation).
3. **No Unsolicited Push/SMS Notifications**: The hackathon prototype avoids accidental automated messaging to real telephone numbers.

---

## 5. Production Telecom & Platform Integration Roadmap

In a future production deployment:

1. **Android CallScreeningService**:
   - Registered as an official call screening service to inspect incoming caller metadata before the phone rings.
2. **Accessibility & In-Call Overlay**:
   - Utilizing an in-call system alert overlay (`SYSTEM_ALERT_WINDOW`) displaying the `RiskMeter` and intervention modal over the native in-call screen.
3. **Automated Caregiver Notification**:
   - When "Alert Family" is tapped (or automatically if Risk is Critical and caller refuses to disconnect), an authenticated Edge Function will dispatch an instant push notification and SMS to designated family circle members via Supabase Realtime and Twilio/Firebase.
