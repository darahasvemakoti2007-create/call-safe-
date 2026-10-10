-- ==============================================================================
-- GuardCall — Supabase PostgreSQL Schema & Row Level Security (Step 8)
-- ==============================================================================
-- Designed for PostgreSQL 15+ in Supabase.
-- 
-- PRIVACY BY DESIGN:
-- - NO raw audio storage table.
-- - NO full conversation transcript table.
-- - Persists strictly structured risk telemetry, threat signals, and caregiver circle.
-- - Enforces zero-trust Row Level Security (RLS) bound to auth.uid().
-- ==============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 1. Profiles Table
-- Represents registered GuardCall user identities linked to Supabase Auth.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 2. Family Contacts Table
-- Designated caregiver and family emergency contacts for escalations.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.family_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    relationship TEXT,
    contact_identifier TEXT NOT NULL, -- E.164 phone number or verified email
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 3. Call Sessions Table
-- High-level telemetry of analyzed conversations.
-- (Stores threat scores, duration, and classification — NEVER raw audio).
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.call_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    risk_score INTEGER NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
    risk_level TEXT NOT NULL, -- 'safe', 'suspicious', 'high', 'critical'
    scenario_type TEXT,
    intervention_status TEXT, -- 'none', 'warningShown', 'userEnded', 'userDismissed', 'familyAlertRequested'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 4. Risk Signals Table
-- Granular explainable behavioral patterns triggered during an analyzed call.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.risk_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_session_id UUID NOT NULL REFERENCES public.call_sessions(id) ON DELETE CASCADE,
    signal_type TEXT NOT NULL, -- e.g. 'authority_impersonation', 'urgency', 'otp_solicitation'
    severity TEXT NOT NULL,    -- 'low', 'medium', 'high', 'critical'
    explanation TEXT NOT NULL,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 5. Alerts Table
-- Caregiver notification records dispatched during high-risk scam events.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_session_id UUID NOT NULL REFERENCES public.call_sessions(id) ON DELETE CASCADE,
    family_contact_id UUID NOT NULL REFERENCES public.family_contacts(id) ON DELETE CASCADE,
    risk_score INTEGER NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'sent', 'delivered', 'dismissed'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 6. User Settings Table
-- User-level privacy toggles and accessibility configurations.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_settings (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    family_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    transcript_retention BOOLEAN NOT NULL DEFAULT FALSE,
    reduce_motion BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- PERFORMANCE INDEXES
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_family_contacts_user_id ON public.family_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_call_sessions_user_id ON public.call_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_call_sessions_started_at ON public.call_sessions(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_risk_signals_call_session_id ON public.risk_signals(call_session_id);
CREATE INDEX IF NOT EXISTS idx_alerts_call_session_id ON public.alerts(call_session_id);
CREATE INDEX IF NOT EXISTS idx_alerts_family_contact_id ON public.alerts(family_contact_id);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Strict isolation ensuring users can only read, insert, and modify their own rows.
-- ==============================================================================

-- 1. Profiles RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (id = auth.uid());

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (id = auth.uid());

-- 2. Family Contacts RLS
ALTER TABLE public.family_contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own family contacts"
    ON public.family_contacts FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- 3. Call Sessions RLS
ALTER TABLE public.call_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own call sessions"
    ON public.call_sessions FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- 4. Risk Signals RLS
ALTER TABLE public.risk_signals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users view risk signals for their own calls"
    ON public.risk_signals FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.call_sessions cs
            WHERE cs.id = risk_signals.call_session_id
              AND cs.user_id = auth.uid()
        )
    );

CREATE POLICY "Users insert risk signals for their own calls"
    ON public.risk_signals FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.call_sessions cs
            WHERE cs.id = risk_signals.call_session_id
              AND cs.user_id = auth.uid()
        )
    );

-- 5. Alerts RLS
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users view alerts associated with their calls"
    ON public.alerts FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.call_sessions cs
            WHERE cs.id = alerts.call_session_id
              AND cs.user_id = auth.uid()
        )
    );

CREATE POLICY "Users insert alerts for their own calls"
    ON public.alerts FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.call_sessions cs
            WHERE cs.id = alerts.call_session_id
              AND cs.user_id = auth.uid()
        )
    );

-- 6. User Settings RLS
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own settings"
    ON public.user_settings FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 7. Family Relationships Table (Step 11)
-- Authenticated pairing between elderly owner account and caregiver account.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.family_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    caregiver_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    relationship TEXT,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_family_relationship UNIQUE (owner_user_id, caregiver_user_id)
);

CREATE INDEX IF NOT EXISTS idx_family_relationships_owner ON public.family_relationships(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_family_relationships_caregiver ON public.family_relationships(caregiver_user_id);

ALTER TABLE public.family_relationships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owners can view their family relationships"
    ON public.family_relationships FOR SELECT
    USING (owner_user_id = auth.uid());

CREATE POLICY "Owners can create family relationships"
    ON public.family_relationships FOR INSERT
    WITH CHECK (owner_user_id = auth.uid());

CREATE POLICY "Owners can update their family relationships"
    ON public.family_relationships FOR UPDATE
    USING (owner_user_id = auth.uid())
    WITH CHECK (owner_user_id = auth.uid());

CREATE POLICY "Owners can delete their family relationships"
    ON public.family_relationships FOR DELETE
    USING (owner_user_id = auth.uid());

CREATE POLICY "Caregivers can view relationships where they are designated"
    ON public.family_relationships FOR SELECT
    USING (caregiver_user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 8. Family Invitations Table (Step 11 Foundation)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.family_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    invited_email TEXT NOT NULL,
    relationship TEXT,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'accepted', 'expired', 'revoked'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days')
);

CREATE INDEX IF NOT EXISTS idx_family_invitations_owner ON public.family_invitations(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_family_invitations_email ON public.family_invitations(invited_email);

ALTER TABLE public.family_invitations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owners manage their family invitations"
    ON public.family_invitations FOR ALL
    USING (owner_user_id = auth.uid())
    WITH CHECK (owner_user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 9. Caregiver Access Policy for Alerts (Step 11)
-- ------------------------------------------------------------------------------
CREATE POLICY "Caregivers can view alerts for active linked family members"
    ON public.alerts FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.call_sessions cs
            JOIN public.family_relationships fr ON fr.owner_user_id = cs.user_id
            WHERE cs.id = alerts.call_session_id
              AND fr.caregiver_user_id = auth.uid()
              AND fr.enabled = TRUE
        )
    );
-- ------------------------------------------------------------------------------
-- 10. Realtime Replication for Alerts
-- ------------------------------------------------------------------------------
ALTER PUBLICATION supabase_realtime ADD TABLE public.alerts;
