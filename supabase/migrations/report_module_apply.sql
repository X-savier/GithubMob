-- Drop the existing simple report table and replace with the full schema.
-- Run this once in the Supabase SQL editor.

DROP TABLE IF EXISTS public.report CASCADE;

-- ─────────────────────────────────────────────
-- REPORT MODULE: maintenance / cleaning / noise reports
-- ─────────────────────────────────────────────

CREATE TABLE public.report (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES contract(id) ON DELETE CASCADE,
  listing_id  uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  tenant_id   uuid NOT NULL REFERENCES auth.users(id),
  landlord_id uuid NOT NULL REFERENCES auth.users(id),
  type text NOT NULL DEFAULT 'maintenance'
    CHECK (type IN ('maintenance', 'cleaning', 'amenity', 'noise', 'other')),
  priority text NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_progress', 'resolved', 'cancelled')),
  title text NOT NULL,
  description text,
  landlord_response text,
  landlord_responded_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX report_tenant_id_idx   ON public.report(tenant_id);
CREATE INDEX report_landlord_id_idx ON public.report(landlord_id);
CREATE INDEX report_listing_id_idx  ON public.report(listing_id);
CREATE INDEX report_contract_id_idx ON public.report(contract_id);
CREATE INDEX report_status_idx      ON public.report(status);

-- updated_at auto-bump
CREATE OR REPLACE FUNCTION report_set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS report_updated_at_trg ON public.report;
CREATE TRIGGER report_updated_at_trg
  BEFORE UPDATE ON public.report
  FOR EACH ROW EXECUTE FUNCTION report_set_updated_at();

-- RLS
ALTER TABLE public.report ENABLE ROW LEVEL SECURITY;

CREATE POLICY report_select_party ON public.report
  FOR SELECT USING (auth.uid() = tenant_id OR auth.uid() = landlord_id);

CREATE POLICY report_insert_tenant ON public.report
  FOR INSERT WITH CHECK (auth.uid() = tenant_id);

CREATE POLICY report_update_party ON public.report
  FOR UPDATE
  USING (auth.uid() = tenant_id OR auth.uid() = landlord_id)
  WITH CHECK (auth.uid() = tenant_id OR auth.uid() = landlord_id);
