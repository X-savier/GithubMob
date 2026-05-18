-- ─────────────────────────────────────────────
-- AI VERIFICATION MODULE
-- ─────────────────────────────────────────────
-- Run once in the Supabase SQL editor. Idempotent.
-- Depends on: verification_module.sql (creates the `verifications`
--   storage bucket + base profile flags).
--
-- Adds:
--   * profiles columns for tiered verification decisions.
--   * `verifications` history table (one row per submission attempt)
--     with OCR + face-match scores written by the
--     `verify-identity` Edge Function.
--   * RLS that lets owners read/insert their own rows but reserves
--     UPDATE to the service-role (the Edge Function).

-- 1. profiles columns ─────────────────────────────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS verification_id_type TEXT,
  -- 'approved' | 'manual_review' | 'rejected' | NULL
  ADD COLUMN IF NOT EXISTS verification_decision TEXT,
  ADD COLUMN IF NOT EXISTS verification_processed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS verification_rejection_reason TEXT;

-- 2. verifications history table ─────────────────────────────────
CREATE TABLE IF NOT EXISTS verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  id_type TEXT NOT NULL,
  id_front_path TEXT NOT NULL,
  id_back_path TEXT,
  selfie_path TEXT NOT NULL,
  ocr_data JSONB,
  extracted_name TEXT,
  extracted_id_number TEXT,
  extracted_dob DATE,
  face_match_score NUMERIC(4,3),
  ocr_confidence NUMERIC(4,3),
  name_match_score NUMERIC(4,3),
  -- 'pending' | 'approved' | 'manual_review' | 'rejected'
  decision TEXT NOT NULL DEFAULT 'pending',
  decision_reason TEXT,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS verifications_user_created_idx
  ON verifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS verifications_manual_review_idx
  ON verifications (created_at DESC)
  WHERE decision = 'manual_review';

ALTER TABLE verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS verifications_owner_select ON verifications;
CREATE POLICY verifications_owner_select ON verifications
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS verifications_owner_insert ON verifications;
CREATE POLICY verifications_owner_insert ON verifications
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- UPDATE intentionally restricted to service_role (Edge Function).
-- DELETE not granted — preserve audit trail.
