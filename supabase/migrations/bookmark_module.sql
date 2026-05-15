-- ─────────────────────────────────────────────
-- BOOKMARK MODULE
-- ─────────────────────────────────────────────
-- Run once in the Supabase SQL editor. Idempotent.
--
-- Repoints `bookmark.listing_id` from the legacy `listings_old`
-- table to the current `listings` table, adds RLS so users can
-- only see/manage their own rows, and indexes the lookup paths.

-- 1. Drop the legacy FK if it still references listings_old.
ALTER TABLE bookmark
  DROP CONSTRAINT IF EXISTS bookmark_listing_id_fkey;

-- 2. Null-purge any orphan listing_ids that don't exist in
--    `listings` so the new FK can be created cleanly.
DELETE FROM bookmark
 WHERE listing_id IS NOT NULL
   AND listing_id NOT IN (SELECT id FROM listings);

-- 3. Re-add the FK pointing at the current listings table.
ALTER TABLE bookmark
  ADD CONSTRAINT bookmark_listing_id_fkey
  FOREIGN KEY (listing_id)
  REFERENCES listings(id)
  ON DELETE CASCADE;

-- 4. Index the listing-side lookup (already have user-side).
CREATE INDEX IF NOT EXISTS idx_bookmark_listing
  ON bookmark(listing_id);

-- 5. RLS — users only see and manage their own bookmarks.
ALTER TABLE bookmark ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bookmark_owner_select ON bookmark;
CREATE POLICY bookmark_owner_select ON bookmark
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS bookmark_owner_insert ON bookmark;
CREATE POLICY bookmark_owner_insert ON bookmark
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS bookmark_owner_delete ON bookmark;
CREATE POLICY bookmark_owner_delete ON bookmark
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());
