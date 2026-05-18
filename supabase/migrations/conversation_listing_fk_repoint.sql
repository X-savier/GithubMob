-- ─────────────────────────────────────────────
-- Repoint conversation.listing_id FK from legacy
-- listings_old → current listings table.
-- ─────────────────────────────────────────────
-- Run once in the Supabase SQL editor. Idempotent.
--
-- Symptom this fixes:
--   "insert or update on table \"conversation\" violates foreign key
--    constraint \"conversation_listing_id_fkey\". Key is not present
--    in table \"listings_old\"."
-- New listings live in `listings`; the FK was never updated.

-- 1. Drop the legacy FK if it still points at listings_old.
ALTER TABLE conversation
  DROP CONSTRAINT IF EXISTS conversation_listing_id_fkey;

-- 2. Null out any orphan listing_ids that don't exist in `listings`
--    so the new constraint can be added without errors.
UPDATE conversation
   SET listing_id = NULL
 WHERE listing_id IS NOT NULL
   AND listing_id NOT IN (SELECT id FROM listings);

-- 3. Re-add the FK pointing at the current listings table.
ALTER TABLE conversation
  ADD CONSTRAINT conversation_listing_id_fkey
  FOREIGN KEY (listing_id)
  REFERENCES listings(id)
  ON DELETE SET NULL;
