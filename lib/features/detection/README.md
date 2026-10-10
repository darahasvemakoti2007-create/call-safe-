# GuardCall Scam Detection Engine (Step 4B)

Welcome to the **GuardCall Scam Detection Engine** documentation. This document provides a beginner-friendly overview of how conversational pattern analysis works in GuardCall, how risk scores are calculated, and how false positives are prevented.

---

## 1. What the Detection Engine Does

The Detection Engine is the core intelligence layer of GuardCall. Rather than querying remote blacklists of spam phone numbers or looking up caller IDs, GuardCall inspects the **behavioral and psychological flow of the conversation** itself.

Given a series of dialogue turns (implemented via `ConversationLine`), the engine:
1. Evaluates spoken lines for manipulative patterns.
2. Identifies specific predatory signals (urgency, threats, isolation, credential requests, etc.).
3. Recognizes protective or reassuring context (official banking notices).
4. Calculates a deterministic risk score (0 to 100).
5. Maps the score to a clear safety tier (`Safe`, `Suspicious`, `High`, `Critical`).
6. Generates human-understandable explanations for *why* an alert was generated.

---

## 2. Why Keyword-Only Detection Is Insufficient

A naive approach to scam detection simply searches for words like `"bank"`, `"hospital"`, `"OTP"`, or `"emergency"`. This fails immediately in real life:

* **Innocent Bank Calls**: A legitimate bank representative calling about card fraud will say:
  > *"For your security, we will never ask for your OTP, PIN, CVV, or password."*
  A keyword-only detector finds the word "OTP" and incorrectly flags this legitimate call as a severe scam.
* **Innocent Hospital Calls**: A clinic calling to reschedule an appointment might say:
  > *"Your appointment needs to be moved because the doctor had an emergency."*
  A keyword-only detector finds "hospital" and "emergency" and falsely alarms the user.
* **Scammer Flexibility**: Scammers constantly vary specific vocabulary, but **cannot avoid the psychological manipulation sequence** needed to extract money or credentials.

Therefore, GuardCall analyzes **compounding signals, context, and conversation escalation**, not isolated dictionary words.

---

## 3. What Signals Are Detected

GuardCall tracks 9 distinct behavioral scam signals defined in [scam_signal.dart](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/detection/scam_signal.dart):

| Signal | Human-Readable Title | What It Detects |
| :--- | :--- | :--- |
| **`authorityImpersonation`** | Possible authority impersonation | Caller claims to be police, tax officer, central bank, or official investigator. |
| **`urgency`** | Urgency or time pressure | Artificial deadlines (e.g., "within 10 minutes", "expires today", "act now"). |
| **`fearThreat`** | Threat or fear-based pressure | Intimidation, threats of arrest, lawsuits, or immediate account blocking. |
| **`sensitiveInformationRequest`** | Sensitive information request | Asking for one-time passwords (OTP), ATM PINs, CVV codes, or passwords. |
| **`financialPressure`** | Financial pressure or payment request | Demanding wire transfers, UPI payments, gift cards, or funds movement. |
| **`isolation`** | Isolation from family or trusted people | Coercing the user to stay on the line, not call family, or keep the call secret. |
| **`emotionalManipulation`** | Emotional manipulation | Fabricating accidents, distress of a grandchild, or urgent medical emergencies. |
| **`remoteAccessRequest`** | Remote access or screen-sharing request | Directing the user to install AnyDesk, TeamViewer, or share their screen. |
| **`suspiciousLink`** | Suspicious link or payment link | Directing the user to click unverified payment URLs or external links. |

---

## 4. How the Prototype Score Works

Each detected signal contributes a baseline weight:
* **Authority Impersonation**: 10
* **Urgency**: 15
* **Fear / Threat**: 20
* **Sensitive Info Request (OTP/PIN)**: 25
* **Financial Pressure**: 20
* **Isolation**: 15
* **Emotional Manipulation**: 15
* **Remote Access**: 25
* **Suspicious Link**: 20

### Contextual Combination Bonuses
Real-world scams combine tactics in coordinated ways. When dangerous combinations appear together, the engine adds compounding bonuses:
* `Authority + Urgency`: +10
* `Authority + Threat`: +10
* `Urgency + Sensitive Info`: +10
* `Financial Pressure + Urgency`: +10
* `Isolation + Threat`: +10
* `Emotional Manipulation + Financial Pressure`: +10
* `Authority + Sensitive Info`: +15

### Sequence & Escalation Bonus
If conversation turns demonstrate a multi-step escalation (e.g. setting up authority/emergency in early turns $\rightarrow$ demanding OTP or wire transfer in later turns), an additional **+10 sequence bonus** is awarded.

### Tier Thresholds
* **0 – 40: Safe**
* **41 – 70: Suspicious**
* **71 – 84: High**
* **85 – 100: Critical**

*Critical Tier Qualification*: Critical risk (85–100) is strictly reserved for calls featuring severe coercive threats (arrest/lawsuits) or direct credential solicitation (OTP/PIN/remote access). Urgent appeals without threats or credential theft cap at High (70–84).

---

## 5. False-Positive Protection (Protective Context)

GuardCall actively searches for **protective statements**:
* *"we will never ask for your OTP"*
* *"we will never ask for your PIN or password"*
* *"contact the official bank number on your card"*
* *"official banking app"*
* *"no payment or sensitive information is required"*

When protective phrases appear:
1. Mention of words like "OTP" or "PIN" within protective context are **disregarded** and never trigger a credential request flag.
2. The overall risk score is reduced in a controlled manner (capping at safe boundaries).
3. The explanation explicitly informs the user that the caller provided verifiable safety advice.

---

## 6. Prototype vs. Production AI Model

* **Current Implementation (`MockScamDetectionEngine`)**:
  * Purely deterministic Dart implementation with zero external dependencies.
  * Fast, offline-capable, and fully testable for hackathon demonstrations.
  * Clearly documents rule logic and explainable rationales.
* **Future Production Implementation**:
  * The abstract contract [ScamDetectionEngine](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/lib/features/detection/scam_detection_engine.dart) decouples detection from the application.
  * A future `OnDeviceMlScamDetectionEngine` or `CloudLlmScamDetectionEngine` can implement the exact same interface `analyzeConversation()` using small on-device transformer models (e.g. Gemma on-device or Whisper STT + LLM pipeline) with **zero changes to the UI or presentation layer**.

---

## 7. Progressive Demo Analysis (Step 5)

In real phone-call protection, an AI assistant does not wait for a 10-minute scam call to finish before warning the user; it evaluates speech continuously in real-time.

In the Demo Center:
1. When a scenario starts, the simulation begins at **Turn 1**.
2. Only the dialogue turns spoken up to that moment (`displayedLines`) are submitted to `ScamDetectionEngine.analyzeConversation(displayedLines)`.
3. The engine outputs a refreshed `RiskAnalysis`, recalculating the risk score, risk level, active scam signals, and human-readable explanations.
4. The UI instantly updates the animated **`RiskMeter`**, signal chips, and explanation notes.
5. As new turns arrive every 1.5–2.0 seconds, the score progressively climbs (for predatory calls) or stays securely at zero (for legitimate calls).
6. When the final turn completes, a comprehensive **Final Risk Assessment** card is rendered, and the result is logged to the local in-memory **Call History**.

