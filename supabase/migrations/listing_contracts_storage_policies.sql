-- ─────────────────────────────────────────────
-- listing-contracts BUCKET — RLS POLICIES
-- ─────────────────────────────────────────────
-- Path convention: <listing_id>/contract_<timestamp>.<ext>
-- The first path segment is the listing UUID; we use that to
-- gate writes to the listing's landlord and reads to any
-- authenticated user (so tenants can preview before applying).
--
-- Run once in the Supabase SQL editor. Idempotent.

-- 1. READ — any authenticated user can download contract files.
DROP POLICY IF EXISTS "listing_contracts_read_authenticated"
  ON storage.objects;
CREATE POLICY "listing_contracts_read_authenticated"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'listing-contracts');

-- 2. INSERT — only the listing's landlord can upload.
--    `(storage.foldername(name))[1]` extracts the first path segment
--    (the listing UUID) and we check the landlord_id against the
--    caller's auth.uid().
DROP POLICY IF EXISTS "listing_contracts_insert_landlord"
  ON storage.objects;
CREATE POLICY "listing_contracts_insert_landlord"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'listing-contracts'
    AND (
      -- Allow temp_* prefix used during initial create (when there
      -- is no listing row yet). The application moves/renames after
      -- the listing is inserted; this is sandbox-grade.
      (storage.foldername(name))[1] LIKE 'temp_%'
      OR EXISTS (
        SELECT 1 FROM listings l
        WHERE l.id::text = (storage.foldername(name))[1]
          AND l.landlord_id = auth.uid()
      )
    )
  );

-- 3. UPDATE — landlord may overwrite their own listing's files.
DROP POLICY IF EXISTS "listing_contracts_update_landlord"
  ON storage.objects;
CREATE POLICY "listing_contracts_update_landlord"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'listing-contracts'
    AND EXISTS (
      SELECT 1 FROM listings l
      WHERE l.id::text = (storage.foldername(name))[1]
        AND l.landlord_id = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'listing-contracts'
    AND EXISTS (
      SELECT 1 FROM listings l
      WHERE l.id::text = (storage.foldername(name))[1]
        AND l.landlord_id = auth.uid()
    )
  );

-- 4. DELETE — landlord may delete their own listing's files.
DROP POLICY IF EXISTS "listing_contracts_delete_landlord"
  ON storage.objects;
CREATE POLICY "listing_contracts_delete_landlord"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'listing-contracts'
    AND EXISTS (
      SELECT 1 FROM listings l
      WHERE l.id::text = (storage.foldername(name))[1]
        AND l.landlord_id = auth.uid()
    )
  );
