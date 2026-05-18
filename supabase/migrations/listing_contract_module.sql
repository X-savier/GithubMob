-- ─────────────────────────────────────────────
-- LISTING CONTRACT TEMPLATE: schema additions
-- ─────────────────────────────────────────────
-- Adds the columns needed for the landlord-side
-- contract template editor on the create-listing form:
--
--   1. listings.contract_template_url   — storage path to the
--      landlord's modified contract file (PDF / DOCX / TXT).
--      NULL means "use the system default template for the
--      current listing_type".
--   2. listings.contract_template_name  — original filename of
--      the uploaded file, kept so we can show "lease.pdf" in the
--      UI without round-tripping storage metadata.
--   3. listings.terms_override          — JSONB array of strings
--      that REPLACES the default per-type T&C terms when the
--      landlord customizes them in-app. NULL = use defaults.
--
-- Idempotent — safe to re-run.

ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS contract_template_url  text,
  ADD COLUMN IF NOT EXISTS contract_template_name text,
  ADD COLUMN IF NOT EXISTS terms_override         jsonb;

-- Storage bucket for contract template files. Created via a
-- separate dashboard step in production, but the convention is:
--
--   bucket: listing-contracts
--   path:   <listing_id>/contract_<timestamp>.<ext>
--
-- RLS on storage.objects should restrict writes to the listing's
-- landlord; reads are open to authenticated users (so tenants can
-- preview the template before applying).
