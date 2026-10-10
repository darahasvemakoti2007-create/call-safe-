# GuardCall — Supabase Backend Setup Guide

## 1. What is Supabase?
[Supabase](https://supabase.com) is an open-source Firebase alternative built on top of **PostgreSQL**. It provides:
- A dedicated PostgreSQL relational database.
- Real-time data streaming and subscriptions.
- Built-in user authentication.
- Enterprise-grade **Row Level Security (RLS)**.
- Scalable cloud storage and edge functions.

---

## 2. Why Does GuardCall Use Supabase?
In GuardCall, Supabase handles cloud persistence and multi-device coordination:
1. **Call History Synchronization:** Syncing high-level risk scores, timestamps, and detected threat tags across a user's registered devices.
2. **Caregiver Escalation & Realtime Alerts:** Enabling a vulnerable user's device to dispatch high-priority alerts to their designated family contact via Supabase Realtime channels.
3. **Emergency Circle Registry:** Storing trusted family contacts securely with strict cryptographic access control.
4. **Row Level Security (RLS):** Ensuring users can strictly query and modify their own data and contacts.

---

## 3. Creating Your Supabase Project
1. Visit [https://supabase.com](https://supabase.com) and sign in or create an account.
2. In the Supabase Dashboard, click **New Project**.
3. Choose an organization, enter a name (e.g. `guardcall-backend`), set a strong database password, and select your preferred hosting region.
4. Click **Create new project** and wait ~2 minutes for PostgreSQL provisioning to complete.

---

## 4. Finding Your Project URL & Anon/Publishable Key
Once your project dashboard opens:
1. Navigate to **Project Settings** (gear icon in the left sidebar).
2. Select **API** under Configuration.
3. Locate the **Project URL** box:
   - Example: `https://xyzprojectref.supabase.co`
4. Locate the **Project API keys** section:
   - Find the key labeled **`anon`** / **`public`**.
   - This key is designed to be public-facing and is protected by PostgreSQL Row Level Security.

---

## 5. Configuring Your `.env` File
1. In your local repository root, copy `.env.example` to create your private `.env` file:
   ```bash
   cp .env.example .env
   ```
2. Open `.env` in your editor and paste your credentials:
   ```env
   SUPABASE_URL=https://xyzprojectref.supabase.co
   SUPABASE_ANON_KEY=your-actual-anon-key-here
   USE_SUPABASE=true
   ```
3. Save the file. GuardCall's configuration system will automatically read these values upon launch.

---

## 6. CRITICAL SECURITY: Why Service-Role Keys Must NEVER Be in Flutter
In your Supabase API settings, you will also see a key named **`service_role`** / **`secret`**.

> [!CAUTION]
> **NEVER put the `service_role` key into your Flutter application, `.env` file, or version control!**
> 
> - The `anon` key respects Row Level Security and only allows access to records owned by the authenticated user (`auth.uid()`).
> - The `service_role` key **completely bypasses Row Level Security** and possesses full administrative control over your entire database.
> - If placed in a mobile app, anyone can decompile the Flutter APK, extract the service-role key, and view, alter, or delete every user's private data.

---

## 7. `.env` vs. `.env.example`
- **`.env.example` (Tracked in Git):** A public template containing key names with empty or placeholder values (`your-supabase-url`). It documents for developers and evaluators which configuration variables are supported without disclosing secrets.
- **`.env` (Ignored by Git):** Your local, secret-bearing file containing real project credentials. It is listed in `.gitignore` so it can never be accidentally pushed to GitHub.

---

---

## 8. Offline-First Demo Mode
If you run GuardCall **without** a `.env` file, or with `USE_SUPABASE=false`, or without network connectivity:
- The app launches seamlessly into **Offline Demo Mode**.
- The Demo Center, all 5 simulated conversation scenarios, progressive risk meter, and intervention dialogs function with 100% fidelity.
- Call history records are stored in local transient memory.
- No network requests are made, ensuring completely crash-free hackathon presentations.

---

## 9. Executing the SQL Schema Migration
To establish the tables, indexes, and Row Level Security policies:
1. In your Supabase Dashboard, open the **SQL Editor** from the left navigation menu.
2. Click **New Query**.
3. Copy the entire contents of [supabase/schema.sql](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/supabase/schema.sql) and paste them into the editor.
4. Click **Run**.
5. Verify that all 6 tables (`profiles`, `family_contacts`, `call_sessions`, `risk_signals`, `alerts`, `user_settings`) are created with Row Level Security enabled.

---

## 10. Enabling Supabase Realtime on `public.alerts`
By default, PostgreSQL tables in Supabase do not broadcast changes over WebSockets until explicitly enabled in the Realtime publication.

### Option A: Using the Supabase Dashboard UI
1. Navigate to **Database** in the left sidebar, then select **Replication**.
2. Under **Source**, locate the `supabase_realtime` publication.
3. Click the table count (e.g. `0 tables`) to manage replication sources.
4. Toggle the switch **ON** for `public.alerts`.
5. Click **Save**.

### Option B: Using the SQL Editor
Execute the following SQL command in the SQL Editor:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.alerts;
```

> [!NOTE]
> Supabase Realtime strictly honors Row Level Security (RLS). When a client subscribes to Postgres changes on `public.alerts`, Supabase evaluates the RLS policy (`USING (EXISTS (SELECT 1 FROM call_sessions cs WHERE cs.id = alerts.call_session_id AND cs.user_id = auth.uid()))`) before delivering events over the WebSocket.

---

## 11. Realtime Boundaries & Notification Delivery
- **WebSocket Streaming:** Supabase Realtime delivers instant table-change events to actively connected clients.
- **What Realtime Does NOT Do:** It does NOT send SMS messages, WhatsApp messages, or OS-level APNs/FCM push notifications to phones that are locked or running in the background.
- **Future Production Step:** To send actual cellular SMS or push notifications, add a Supabase Database Webhook on `public.alerts` triggering a Supabase Edge Function that invokes Twilio or Firebase Cloud Messaging.

---

## 12. Step 11 Migration: Secure Caregiver Identity & Family Relationships

If you have already applied the Step 8 base schema, apply the Step 11 migration:

1. In Supabase Dashboard, go to **SQL Editor**.
2. Open [supabase/migrations/20261001000000_step11_family_relationships.sql](file:///c:/Users/venup/OneDrive/Desktop/nsrit-app/supabase/migrations/20261001000000_step11_family_relationships.sql).
3. Paste and click **Run**.
4. This adds:
   - `public.family_relationships` (authenticated owner-caregiver user ID pairs)
   - `public.family_invitations` (pending caregiver authorization requests)
   - Extended RLS policy on `public.alerts` granting active linked caregivers read permissions for elderly family members.

---

## 13. Step 13 Edge Function Deployment & Secret Management

In production, provider API keys (OpenAI / Gemini / Whisper) are stored **only** in Supabase Edge Function environment secrets. The mobile app never contains these keys.

### 1. Edge Function Directory Structure:
```
supabase/functions/
├── guardcall-ai-analyze/
│   └── index.ts          # Authenticated scam analysis proxy
└── guardcall-stt/
    └── index.ts          # Authenticated speech-to-text proxy
```

### 2. Configuring Secrets via Supabase CLI:
Set your provider secrets in your Supabase project without placing them in code or version control:
```bash
# Set AI provider credentials
supabase secrets set AI_PROVIDER=openai
supabase secrets set OPENAI_API_KEY=your-actual-secret-key-here

# Or for Google Gemini:
supabase secrets set AI_PROVIDER=gemini
supabase secrets set GEMINI_API_KEY=your-actual-gemini-key-here

# Set Speech-to-Text credentials
supabase secrets set SPEECH_TO_TEXT_API_KEY=your-whisper-api-key
```

### 3. Deploying the Functions:
```bash
supabase functions deploy guardcall-ai-analyze
supabase functions deploy guardcall-stt
```

### 4. Client App Configuration:
In your mobile client `.env` file, point to the Edge Function backend:
```env
AI_BACKEND=edge_function
STT_BACKEND=edge_function
USE_SUPABASE=true
```
No `OPENAI_API_KEY` or `GEMINI_API_KEY` is required in the mobile `.env` when using `edge_function` mode.


