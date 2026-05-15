-- ─────────────────────────────────────────────
-- PROFILES: allow landlord to read tenant rows
-- ─────────────────────────────────────────────
-- Run this once in the Supabase SQL editor.
-- Idempotent — safe to re-run.
--
-- Why: the landlord-side "Active Tenants" list pulls tenant
-- avatar_url + full_name from `profiles`. By default, RLS only lets
-- a user read their own profile row, so the join in
-- fetchActiveTenants() returned empty for the landlord and the UI
-- fell back to a gradient initial avatar.
--
-- This policy lets a landlord SELECT a profile row when they have
-- at least one contract with that user as the tenant. Other rows
-- remain protected.

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_select_landlord_tenants ON profiles;

CREATE POLICY profiles_select_landlord_tenants ON profiles
  FOR SELECT
  TO authenticated
  USING (
    id IN (
      SELECT tenant_id
      FROM contract
      WHERE landlord_id = auth.uid()
    )
  );
