# GuardCall Authentication Architecture (Step 9)

## 1. Overview
GuardCall integrates Supabase Authentication alongside an offline-first demo mode. This architecture guarantees that users and presentation evaluators can always access the core scam detection simulator, warning dialogues, and local history without requiring internet connectivity or cloud credentials, while providing secure cloud profile syncing when configured.

---

## 2. Supabase Auth Architecture

### `auth.users` vs `public.profiles`
In Supabase, user authentication and application data are separated by design:
- **`auth.users`**: An internal system table managed exclusively by the Supabase Auth daemon in the `auth` PostgreSQL schema. It stores sensitive authentication primitives (bcrypt password hashes, email confirmation tokens, recovery keys, and MFA secrets). Direct client SELECT, UPDATE, or INSERT access to this table is blocked by PostgreSQL system permissions to protect credentials.
- **`public.profiles`**: An application-level table in the `public` schema whose primary key `id` is a foreign key referencing `auth.users(id)` with `ON DELETE CASCADE`. GuardCall stores public identity metadata (`name`, timestamps) here. It is exposed to the PostgREST API and secured with Row Level Security.
- **`public.user_settings`**: Stores user privacy toggles and accessibility configurations, keyed to `public.profiles(id)`.

---

## 3. Session Handling
A Supabase session consists of:
- **`access_token`**: Short-lived JSON Web Token (JWT) bearing the user's `sub` claim (`auth.uid()`) and role claims. PostgreSQL inspects this JWT to enforce Row Level Security.
- **`refresh_token`**: Secure, long-lived token used to refresh expired access tokens automatically.
- **Local Persistence**: `supabase_flutter` persists session credentials in encrypted device storage (via SharedPreferences / Keychain). Upon startup, the app restores active sessions automatically.

---

## 4. Password Security
- **Zero Local Password Storage**: The client app never writes passwords to disk, SQLite, logs, or unmanaged memory.
- Passwords are submitted directly over TLS to Supabase Auth's `/auth/v1/signup` or `/auth/v1/token` endpoints.
- Supabase hashes passwords with `bcrypt` (work factor 10) before storage.

---

## 5. Row Level Security (RLS) Relationship
Every database request through `SupabaseClient` attaches the user's JWT. In PostgreSQL, RLS policies execute:
```sql
CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (id = auth.uid());
```
Even if a compromised client attempts to pass another user's UUID, PostgreSQL discards or blocks the request because `auth.uid()` resolves strictly from the verified JWT cryptographic signature.

---

## 6. Offline / Demo Mode Mechanics
When `USE_SUPABASE=false` or credentials are placeholders:
- `AppConfig.isOfflineDemoMode` evaluates to `true`.
- `SupabaseService` transitions to `SupabaseBackendState.offlineDemo`.
- `AuthService` provides mock/local sessions with user `demo-user-offline`.
- `AuthGate` immediately opens the main application experience (`AppNavigation`), enabling instant access to the Demo Center and progressive scam detection.
- `LoginScreen` features a prominent **"Continue in Demo Mode"** button so cloud configuration is never a prerequisite to testing.

---

## 7. Email Confirmation Behavior
Depending on Supabase Project settings (`Confirm email` enabled or disabled):
- If email confirmation is disabled: `signUp` immediately returns an active session and redirects the user into the authenticated app.
- If email confirmation is enabled: `signUp` returns a user without an active session. The app displays an accessible **"Confirm Your Email"** confirmation screen instructing the user to verify their email before logging in.

---

## 8. Prototype vs. Production Behavior
| Feature | Prototype / Step 9 Implementation | Production Target |
|---|---|---|
| Credentials | `.env` file with `USE_SUPABASE=false` default | Managed environment variables / secure CI builds |
| Demo Mode | In-memory session, local mock profile | Isolated sandbox account |
| Verification | Simulated or cloud email confirmation | Phone SMS OTP or Biometric WebAuthn |
| Password Reset | Form validation and error mapping | Supabase Deep Link password recovery flow |
