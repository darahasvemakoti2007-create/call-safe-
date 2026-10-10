# GuardCall — Core Services Layer

This directory houses the foundational services managing local-first state, authentication, PostgreSQL cloud synchronization, and Realtime event subscriptions for GuardCall.

---

## Service Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Flutter UI Layer                      │
│     (AuthGate, DemoPlayerScreen, SettingsScreen, History)   │
└──────────────────────────────┬──────────────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
 ┌──────────────────────┐             ┌──────────────────────┐
 │     Local First      │             │  Cloud Repositories  │
 │ (In-Memory Fallback) │             │ (USE_SUPABASE=true)  │
 ├──────────────────────┤             ├──────────────────────┤
 │ - CallHistoryRepo    │             │ - AuthService        │
 │ - DemoSessionCtrl    │             │ - ProfileService     │
 │ - MockDetectionEngine│             │ - CallSessionService │
 └──────────────────────┘             │ - RiskSignalService  │
                                      │ - FamilyContactService│
                                      │ - FamilyAlertService │
                                      │ - RealtimeService    │
                                      └──────────┬───────────┘
                                                 │
                                                 ▼
                                      ┌──────────────────────┐
                                      │  Supabase PostgreSQL │
                                      │  + Realtime Engine   │
                                      └──────────────────────┘
```

---

## Services Overview

### 1. `SupabaseService` (`supabase_service.dart`)
- **Role:** Central gateway managing the `SupabaseClient` lifecycle.
- **Resilience:** Gracefully falls back to `SupabaseBackendState.offlineDemo` if credentials are absent or network is unavailable. Never throws uncaught exceptions during startup.

### 2. `AuthService` (`auth_service.dart`) & `AuthState` (`auth_state.dart`)
- **Role:** Manages email/password registration, login, logout, and reactive authentication state.
- **Demo Mode:** Simulates in-memory demo sessions without remote network calls.
- **Security:** Zero password persistence locally; zero `service_role` key usage.

### 3. `ProfileService` (`profile_service.dart`)
- **Role:** Synchronizes user profile display names in `public.profiles` and default settings in `public.user_settings`.
- **Security:** Enforces zero-trust ID checks matching `auth.uid()`.

### 4. `CallSessionService` (`call_session_service.dart`)
- **Role:** Persists completed call session metadata into `public.call_sessions`.
- **Privacy By Design:** Stores only threat score, risk level, duration, and intervention outcome. **NEVER stores raw audio or conversational transcripts.**

### 5. `RiskSignalService` (`risk_signal_service.dart`)
- **Role:** Synchronizes granular explainable threat patterns into `public.risk_signals`.
- **Privacy By Design:** Stores pattern tags, severity, and human-readable reasoning without dialogue text.

### 6. `FamilyContactService` (`family_contact_service.dart`)
- **Role:** Manages trusted caregiver records in `public.family_contacts`.
- **Demo Mode:** Pre-populated with demo caregiver `Sarah Jenkins (Daughter)`.

### 7. `FamilyAlertService` (`family_alert_service.dart`)
- **Role:** Records emergency intervention escalation events in `public.alerts` with status `pending`.
- **Honest Delivery Boundary:** Clearly designated as an event/audit sync layer. **Does NOT claim to deliver SMS, WhatsApp, or carrier push notifications directly from the client.**

### 8. `RealtimeService` (`realtime_service.dart`)
- **Role:** Subscribes to PostgreSQL database replication changes over WebSockets using Supabase Realtime.
- **Security:** Subscribes exclusively to the authenticated user's alert stream. Evaluated against PostgreSQL Row Level Security (RLS).

### 9. `FamilyRelationshipService` (`family_relationship_service.dart`) — Step 11
- **Role:** Manages cryptographically authenticated caregiver pairings in `public.family_relationships` and pending caregiver invitations in `public.family_invitations`.
- **Identity Model:** Binds elderly `owner_user_id` to caregiver `caregiver_user_id` (both foreign keys to `auth.users`).
- **Dynamic RLS:** Enables PostgreSQL to authorize caregivers to query `public.alerts` for their linked active family members without weakening security or exposing foreign user alerts.
- **Invitation Boundary:** Records pending invitations in PostgreSQL with status `pending`. Automated SMS/email dispatch is not active from the client.

---

## Architectural & Security Boundary

### What Supabase Realtime Is:
Supabase Realtime is a persistent WebSocket-based event stream that broadcasts PostgreSQL database changes (inserts, updates, deletes) to authorized subscribers.

### What Supabase Realtime is NOT:
- **It is NOT an SMS gateway:** Does not deliver carrier SMS or WhatsApp messages.
- **It is NOT an APNs/FCM push notification:** Does not wake sleeping devices or alert phones when the application is terminated.
- **Future Integration:** True outward caregiver alerts require a backend Supabase Database Webhook or Edge Function connecting to a notification gateway (e.g. Twilio / Firebase Cloud Messaging).

### Caregiver Recipient RLS Model:
In Step 8, `public.family_contacts` stored contact strings (`contact_identifier`) without a foreign key to a separate caregiver Supabase Auth account.
In Step 11, `public.family_relationships` introduces authenticated identity pairing. A caregiver who authenticates with their own Supabase account can only access alert telemetry for elderly accounts that have an active, enabled relationship granting them access.

