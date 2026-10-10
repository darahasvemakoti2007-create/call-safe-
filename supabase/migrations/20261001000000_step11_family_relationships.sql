-- ==============================================================================
-- GuardCall — Step 11 Migration: Secure Family Circle & Caregiver Relationships
-- ==============================================================================
-- This migration establishes the database layer for verified caregiver accounts:
-- 1. `family_relationships`: authenticated pairing between owner & caregiver auth.users
-- 2. `family_invitations`: pending caregiver invitations created by account owners
-- 3. Extended RLS policy on `public.alerts` to grant authorized caregivers read access
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Family Relationships Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.family_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    caregiver_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    relationship TEXT, -- e.g. 'Daughter', 'Son', 'Guardian', 'Spouse'
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_family_relationship UNIQUE (owner_user_id, caregiver_user_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_family_relationships_owner ON public.family_relationships(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_family_relationships_caregiver ON public.family_relationships(caregiver_user_id);

-- Enable RLS
ALTER TABLE public.family_relationships ENABLE ROW LEVEL SECURITY;

-- Owner Policies: full control over their own designated caregivers
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

-- Caregiver Policy: view relationships where they are designated caregiver
CREATE POLICY "Caregivers can view relationships where they are designated"
    ON public.family_relationships FOR SELECT
    USING (caregiver_user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 2. Family Invitations Table (Secure Invitation Foundation)
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_family_invitations_owner ON public.family_invitations(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_family_invitations_email ON public.family_invitations(invited_email);

-- Enable RLS
ALTER TABLE public.family_invitations ENABLE ROW LEVEL SECURITY;

-- Owner Policies: owners manage their invitations
CREATE POLICY "Owners manage their family invitations"
    ON public.family_invitations FOR ALL
    USING (owner_user_id = auth.uid())
    WITH CHECK (owner_user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 3. Caregiver Access Policy for Alerts
-- Enables verified caregivers to view alert telemetry for sessions belonging
-- to the owners who have explicitly granted them active relationship access.
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
