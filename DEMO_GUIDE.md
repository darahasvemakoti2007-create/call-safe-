# GuardCall — Hackathon Presentation & Demonstration Guide

## 1. Executive Summary

**GuardCall** is an Android-first, elderly-friendly scam call protection prototype designed to detect psychological manipulation in real time while preserving 100% user privacy.

### Key Value Propositions
1. **Zero-Audio & Zero-Transcript Privacy:** Audio and speech streams are processed transiently in memory. No call audio, conversation transcripts, OTPs, or passwords are ever recorded, saved to disk, or transmitted to cloud storage.
2. **Explainable Psychological Signal Detection:** Instead of opaque AI black boxes, GuardCall isolates specific manipulative tactics:
   - Authority Impersonation
   - Artificial Urgency & Time Pressure
   - Intimidation & Fear-Based Coercion
   - Sensitive Credential Solicitation (OTP/PIN/CVV)
   - Social Isolation Demands ("Do not tell your family")
   - Suspicious Financial Pressure (UPI / Wire transfers)
3. **Elderly-Friendly & Accessible UX:** High contrast, large touch targets (minimum 48×48dp), clear typography, multi-modal risk badges (icon + text + color), simple plain-language warnings, and native **Reduce Motion** support.
4. **Caregiver Escalation Circle:** When a user requests help, structured threat telemetry (risk score, detected signals, timestamps) is relayed to authorized caregivers without exposing the elder's private conversation.

---

## 2. Safe Demo Architecture (Offline by Default)

- **Execution Mode:** 100% Offline / Local Demo (`USE_SUPABASE=false`).
- **External Network Requests:** **Zero (0)**.
- **Provider API Keys:** None required. The app operates with complete determinism and zero risk of network latency or service outages during live hackathon judging.
- **Real Cellular Call Interception:** Not claimed. Modern Android operating systems isolate cellular baseband audio from third-party applications. GuardCall demonstrates this capability via its interactive **Demo Center**.

---

## 3. Recommended Hackathon Presentation Flow (3–5 Minutes)

### Step 1: The Elderly Experience (Home Screen)
1. Launch the app. Point out the calm, reassuring interface:
   - **Protection Status:** Large shield icon confirming *"Protection Active"*.
   - **Accessibility:** Clear contrast, readable sizing for seniors.
   - **Family Circle Widget:** Shows connected caregiver (*"Sarah Jenkins (Daughter)"*).
   - **Recent Activity:** Summary showing recent protection health.

### Step 2: Launching a Scam Simulation (Demo Center)
1. Tap **"Start Demo Call"** (or navigate to the **Calls** tab and tap **"Open Demo Center"**).
2. Showcase the **5 Predefined Scenarios**:
   - **Fake KYC Update** (Banking Impersonation — Critical/High Threat)
   - **Digital Arrest Threat** (Law Enforcement Impersonation — Critical Threat)
   - **Grandchild Emergency** (Family Distress / UPI Phishing — High Threat)
   - **Legitimate Bank Alert** (Official Fraud Alert — Safe Benchmark)
   - **Hospital Appointment Reschedule** (Healthcare Routine — Safe Benchmark)
3. Note the top banner: *"These conversations are simulated. No real phone call is being monitored."*

### Step 3: Progressive Detection (Fake KYC Update)
1. Tap **"Play Scenario"** under **Fake KYC Update**.
2. Tap **"Start Simulation"**.
3. Watch the turns progress in real time:
   - Turn 1: Caller claims to be from the bank. (Risk: 10 / Safe).
   - Turn 2: Caller creates urgency: *"Your KYC expires today."* (Risk rises to 35).
   - Turn 3: Caller threatens: *"Your account will be blocked in 10 minutes."* (Threat signal detected).
   - Turn 4: Caller demands OTP. Risk surges to **75 / 100 (HIGH RISK)**.

### Step 4: Heads-Up Intervention Dialog
1. At the 75-point threshold, the **Scam Warning Dialog** automatically interrupts:
   - **Prominent Title:** *"Possible Scam — This conversation shows signs of manipulation."*
   - **Multi-Modal Threat Indicator:** Warning icon + text label **"HIGH RISK"** + orange progress meter (75 / 100).
   - **Plain-Language Explanations:** Explains *why* GuardCall is concerned (authority impersonation, urgency, coercion) without technical jargon.
   - **Three Distinct Actions:**
     - **END CALL** (Primary red emergency exit)
     - **I'M SAFE** (Dismisses false alarm)
     - **ALERT FAMILY** (Explicit caregiver escalation)

### Step 5: Caregiver Escalation (Simulated Family Alert)
1. Tap **"Alert Family"**.
2. The **Simulated Family Alert** modal appears:
   - Clearly discloses: *"Simulation only: No real SMS, push notification, or internet request was dispatched."*
   - Shows what the caregiver would receive: Risk score, detected signals, caller persona, and recommended action.
3. Tap **"Close"**.

### Step 6: The Caregiver Perspective (Family Screen)
1. Tap the **Family** tab in the bottom navigation.
2. Tap the **"Caregiver View (Preview)"** tab at the top.
3. Review the caregiver dashboard:
   - Protected family member: *Robert Jenkins (Father)*.
   - Recent scam escalation card: **High Risk Threat (Score: 75/100)**.
   - Shows active signals (*Authority impersonation, Urgency, Threat*).
   - Emphasize: The caregiver sees the threat analysis, but **never hears the call audio or reads personal conversations**.

### Step 7: Zero False-Positive Benchmark (Legitimate Bank Alert)
1. Return to **Demo Center** and launch **"Legitimate Bank Alert"**.
2. Start the simulation:
   - Bank representative advises: *"We will never ask for your OTP, PIN, CVV, or password."*
   - Caller directs elder to the official number printed on their card.
3. Observe: Risk score remains at **0 / 100 (SAFE)** with **zero scam indicators** and **no interruption dialogs**.

### Step 8: Audit Logging & History (History Screen)
1. Navigate to the **History** tab.
2. Observe the chronological risk assessment log:
   - Both the simulated legitimate call and previous scam evaluations appear with timestamps and duration.
   - Reiterate privacy guarantee: Records store only mathematical scores, categories, and tags.

### Step 9: Accessibility & Privacy Controls (Settings Screen)
1. Navigate to the **Settings** tab.
2. Toggle **Reduce Motion**:
   - When enabled, dynamic pulsing glow and animations are disabled for sensitive or motion-averse users.
3. Review the **Zero-Audio Policy** tile (*Guaranteed*).
4. Tap **Clear Local History**:
   - Shows a destructive confirmation dialog (*"Clear Call History?"*) ensuring users never accidentally delete data.

---

## 4. Technical Disclosure Checklist

| Feature | Hackathon Prototype Status |
| :--- | :--- |
| **Scam Detection Engine** | Active & Deterministic (Heuristic pattern sequence analysis) |
| **Demo Scenarios** | 5 comprehensive scripted scenarios |
| **Risk Scoring & Thresholds** | 0–39 Safe, 40–70 Suspicious, 71–84 High Risk, 85–100 Critical Threat |
| **Intervention Dialog** | Active (Interrupts at configured threshold) |
| **Simulated Family Alert** | Active (In-memory structured dispatch) |
| **Caregiver Telemetry View** | Active (Simulated RLS-authorized view) |
| **Reduce Motion** | Active (Global preference propagates across widgets) |
| **Supabase Cloud Sync** | Intentionally postponed / Offline-first |
| **Real Cellular Audio Recording** | Simulated (Restricted by Android OS hardware isolation) |
| **Live SMS / WhatsApp / Push** | Simulated (Zero external messaging credentials) |
