-- ─────────────────────────────────────────────
-- VERIFICATION MODULE
-- ─────────────────────────────────────────────
-- Run once in the Supabase SQL editor. Idempotent.
--
-- Identity verification gate for landlords:
--   * profiles.is_verified — gate for creating listings
--   * listings.is_verified — proof-of-ownership doc submitted at create
-- All existing rows are backfilled to verified=true so the new gate
-- doesn't lock out the current dataset.

-- 1. profiles columns ─────────────────────────────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS verification_id_url TEXT,
  ADD COLUMN IF NOT EXISTS verification_selfie_url TEXT,
  ADD COLUMN IF NOT EXISTS verification_submitted_at TIMESTAMPTZ;

-- 2. listings columns ─────────────────────────────────────────────
ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS verification_doc_url TEXT,
  ADD COLUMN IF NOT EXISTS verification_submitted_at TIMESTAMPTZ;

-- 3. Backfill: grandfather the current dataset as verified.
UPDATE profiles SET is_verified = true WHERE is_verified = false;
UPDATE listings SET is_verified = true WHERE is_verified = false;

-- 4. Private storage bucket for verification documents.
INSERT INTO storage.buckets (id, name, public)
VALUES ('verifications', 'verifications', false)
ON CONFLICT (id) DO NOTHING;

-- 5. Storage policies — owners manage their own files only.
DROP POLICY IF EXISTS verifications_owner_insert ON storage.objects;
CREATE POLICY verifications_owner_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'verifications'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS verifications_owner_select ON storage.objects;
CREATE POLICY verifications_owner_select ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'verifications'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS verifications_owner_update ON storage.objects;
CREATE POLICY verifications_owner_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'verifications'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
