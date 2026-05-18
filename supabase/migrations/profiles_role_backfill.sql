-- ─────────────────────────────────────────────
-- PROFILES: is_landlord capability flag
-- ─────────────────────────────────────────────
-- Run this once in the Supabase SQL editor.
-- Idempotent — safe to re-run.
--
-- Why a separate column instead of overwriting `role`:
-- A user can be a landlord (owns listings) AND a tenant (rents another
-- listing) at the same time. `role` represents primary identity; the
-- new `is_landlord` boolean represents the landlord *capability* and
-- is what the UI checks when deciding whether to show landlord-only
-- features. This keeps capability and identity from fighting each
-- other when one user does both.

-- 1. Add the column with a safe default.
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_landlord boolean NOT NULL DEFAULT false;

-- 2. Backfill: every user who already owns at least one listing
--    gets is_landlord=true. We leave `role` untouched so existing
--    UI labels and any external assumptions are preserved.
UPDATE profiles
SET is_landlord = true
WHERE id IN (
  SELECT DISTINCT landlord_id
  FROM listings
  WHERE landlord_id IS NOT NULL
)
AND is_landlord = false;
