-- ─────────────────────────────────────────────
-- LISTING IMAGE MODULE — RLS + INDEXES
-- ─────────────────────────────────────────────
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New query).
-- It is fully idempotent; safe to run multiple times.
--
-- Actual table schema (already exists):
--   id            uuid PK
--   listing_id    uuid NOT NULL → listings(id) ON DELETE CASCADE
--   url           text NOT NULL   ← Supabase Storage path
--   type          text DEFAULT 'normal'   ('normal' | 'panorama')
--   upload_source text DEFAULT 'upload'   ('upload' | 'capture')
--   sort_order    integer DEFAULT 0
--   is_cover      boolean DEFAULT false
--   uploaded_by   uuid → profiles(id)
--   created_at    timestamptz DEFAULT now()

-- ── STEP 1: Diagnostic — check current RLS state ──────────────
-- (Optional) Run this SELECT first to see what policies exist:
--
--   SELECT policyname, cmd, qual, with_check
--   FROM pg_policies
--   WHERE tablename = 'listing_image';
--
-- If the result is empty, that is why inserts are failing:
-- RLS is enabled with no policies = all writes denied.

-- ── STEP 2: Indexes ───────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_listing_image_listing
  ON public.listing_image(listing_id);

CREATE INDEX IF NOT EXISTS idx_listing_image_type
  ON public.listing_image(listing_id, type);

CREATE INDEX IF NOT EXISTS idx_listing_image_sort
  ON public.listing_image(listing_id, sort_order);

-- ── STEP 3: Enable RLS ────────────────────────────────────────
ALTER TABLE public.listing_image ENABLE ROW LEVEL SECURITY;

-- ── STEP 4: Policies ──────────────────────────────────────────

-- Public SELECT — anyone can view images for any listing.
DROP POLICY IF EXISTS listing_image_select_all ON public.listing_image;
CREATE POLICY listing_image_select_all ON public.listing_image
  FOR SELECT
  USING (true);

-- INSERT — any authenticated user can insert.
-- Simple check: just require the user to be logged in.
-- The uploaded_by is validated client-side (set to auth.uid()).
DROP POLICY IF EXISTS listing_image_insert_auth ON public.listing_image;
CREATE POLICY listing_image_insert_auth ON public.listing_image
  FOR INSERT TO authenticated
  WITH CHECK (auth.role() = 'authenticated');

-- UPDATE — only the listing's landlord can update images.
DROP POLICY IF EXISTS listing_image_update_landlord ON public.listing_image;
CREATE POLICY listing_image_update_landlord ON public.listing_image
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.listings
      WHERE listings.id = listing_image.listing_id
        AND listings.landlord_id = auth.uid()
    )
  );

-- DELETE — only the listing's landlord can delete images.
DROP POLICY IF EXISTS listing_image_delete_landlord ON public.listing_image;
CREATE POLICY listing_image_delete_landlord ON public.listing_image
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.listings
      WHERE listings.id = listing_image.listing_id
        AND listings.landlord_id = auth.uid()
    )
  );

