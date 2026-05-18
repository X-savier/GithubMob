-- =====================================================
-- MODULE: CONTRACT + PAYMENT — Phases A / B / C
--
-- Brings the mobile schema up to web parity (May 17, 2026):
--   * contract       — 22 editor columns from the web contract editor
--   * payment_transactions — Phase A (recorded_by / note) + Phase B (billing_month)
--   * payment        — Phase B billing_month, UNIQUE CONSTRAINT for upsert,
--                      partial unique index for one-paid-per-month
--   * contract_rent_status (view) — Phase B rent-due rollup
--   * payment_links (table)       — Phase C landlord-generated checkout links
--   * payment_transactions_with_context (view) — adds A+B fields
--
-- Idempotent — safe to re-apply. Additive only; does NOT drop existing
-- columns or constraints from earlier migrations.
-- =====================================================


-- -----------------------------------------------------
-- contract — extra editor columns
-- Mirrors vxr-web/.../modules.sql lines 349–372.
-- -----------------------------------------------------
ALTER TABLE public.contract
  ADD COLUMN IF NOT EXISTS landlord_name             text,
  ADD COLUMN IF NOT EXISTS landlord_contact          text,
  ADD COLUMN IF NOT EXISTS tenant_name               text,
  ADD COLUMN IF NOT EXISTS tenant_contact            text,
  ADD COLUMN IF NOT EXISTS property_address          text,
  ADD COLUMN IF NOT EXISTS property_type             text,
  ADD COLUMN IF NOT EXISTS entered_on                date,
  ADD COLUMN IF NOT EXISTS start_date                date,
  ADD COLUMN IF NOT EXISTS end_date                  date,
  ADD COLUMN IF NOT EXISTS duration                  text,
  ADD COLUMN IF NOT EXISTS monthly_rent              numeric,
  ADD COLUMN IF NOT EXISTS security_deposit          numeric,
  ADD COLUMN IF NOT EXISTS advance_rent              numeric,
  ADD COLUMN IF NOT EXISTS payment_due_date          int,
  ADD COLUMN IF NOT EXISTS grace_period_days         int,
  ADD COLUMN IF NOT EXISTS payment_method            text,
  ADD COLUMN IF NOT EXISTS account_info              text,
  ADD COLUMN IF NOT EXISTS late_fee                  numeric,
  ADD COLUMN IF NOT EXISTS minor_repairs_threshold   numeric,
  ADD COLUMN IF NOT EXISTS quiet_hours               text,
  ADD COLUMN IF NOT EXISTS overnight_guest_threshold int,
  ADD COLUMN IF NOT EXISTS governing_city            text,
  ADD COLUMN IF NOT EXISTS updated_at                timestamptz DEFAULT now();


-- -----------------------------------------------------
-- payment_transactions — Phase A (offline) + Phase B (monthly)
-- -----------------------------------------------------
-- Phase A: landlord-recorded offline payments.
--   recorded_by — null for tenant-paid PayMongo rows, set to landlord's
--                 user_id when the landlord logs a cash / bank / direct
--                 GCash payment they received off-platform.
--   note        — free-text landlord note (e.g. "Cash, receipt #042").
-- Phase B: monthly rent tracking.
--   billing_month — first day of the month this payment covers
--                   (e.g. 2026-05-01). Nullable so legacy move-in and
--                   pre-PayMongo rows stay valid; recurring rent rows
--                   populate it so a tenant knows which month was paid.
ALTER TABLE public.payment_transactions
  ADD COLUMN IF NOT EXISTS recorded_by   uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS note          text,
  ADD COLUMN IF NOT EXISTS billing_month date;

-- Relax method_type to allow offline methods landlords can record.
ALTER TABLE public.payment_transactions DROP CONSTRAINT IF EXISTS payment_transactions_method_type_check;
ALTER TABLE public.payment_transactions ADD CONSTRAINT payment_transactions_method_type_check
  CHECK (method_type IN ('card','gcash','paymaya','grab_pay','bank_transfer','cash','offline_other'));

CREATE INDEX IF NOT EXISTS pt_billing_month_idx
  ON public.payment_transactions(contract_id, billing_month)
  WHERE billing_month IS NOT NULL;


-- -----------------------------------------------------
-- payment — Phase B billing_month + upsert-friendly unique constraint
-- -----------------------------------------------------
ALTER TABLE public.payment
  ADD COLUMN IF NOT EXISTS billing_month date;

-- Replace the partial index with a real UNIQUE CONSTRAINT so Supabase's
-- .upsert({ onConflict: "paymongo_payment_intent_id" }) can match it.
-- Postgres treats NULLs as distinct, so legacy Stripe-only rows with
-- paymongo_payment_intent_id IS NULL coexist safely.
ALTER TABLE public.payment DROP CONSTRAINT IF EXISTS payment_paymongo_pi_unique;
DROP INDEX IF EXISTS public.payment_paymongo_pi_idx;
ALTER TABLE public.payment
  ADD CONSTRAINT payment_paymongo_pi_unique UNIQUE (paymongo_payment_intent_id);

-- At most one succeeded payment per (contract, billing_month). Partial
-- so legacy / move-in rows (billing_month IS NULL) don't trip it.
CREATE UNIQUE INDEX IF NOT EXISTS payment_one_per_month
  ON public.payment(contract_id, billing_month)
  WHERE status = 'succeeded' AND billing_month IS NOT NULL;


-- -----------------------------------------------------
-- contract_rent_status (Phase B view)
--
-- One row per active contract describing the current rent state:
--   last_paid_month — newest billing_month with a succeeded payment
--   months_unpaid   — count of months from start_date through current
--                     month with NO succeeded payment row
--   next_due_month  — oldest unpaid month, or current month if none
--
-- Drives the tenant dashboard's "Pay this month" and the landlord's
-- arrears view without recomputing on the client.
-- -----------------------------------------------------
CREATE OR REPLACE VIEW public.contract_rent_status AS
SELECT
  c.id                                       AS contract_id,
  c.tenant_id,
  c.landlord_id,
  c.listing_id,
  c.start_date,
  c.monthly_rent,
  date_trunc('month', current_date)::date    AS current_month,
  (SELECT max(p.billing_month) FROM public.payment p
    WHERE p.contract_id = c.id
      AND p.status = 'succeeded'
      AND p.billing_month IS NOT NULL)       AS last_paid_month,
  (
    SELECT count(*)::int FROM generate_series(
      date_trunc('month', c.start_date),
      date_trunc('month', current_date),
      interval '1 month'
    ) AS m
    WHERE NOT EXISTS (
      SELECT 1 FROM public.payment p
      WHERE p.contract_id = c.id
        AND p.status = 'succeeded'
        AND p.billing_month = m::date
    )
  )                                          AS months_unpaid,
  (
    SELECT min(m::date) FROM generate_series(
      date_trunc('month', c.start_date),
      date_trunc('month', current_date),
      interval '1 month'
    ) AS m
    WHERE NOT EXISTS (
      SELECT 1 FROM public.payment p
      WHERE p.contract_id = c.id
        AND p.status = 'succeeded'
        AND p.billing_month = m::date
    )
  )                                          AS next_due_month
FROM public.contract c
WHERE c.start_date IS NOT NULL
  AND c.status IN ('paid','terminating','expiring','terminated','ended');

ALTER VIEW public.contract_rent_status SET (security_invoker = true);


-- -----------------------------------------------------
-- payment_links (Phase C)
--
-- Landlord-generated PayMongo Link URLs the tenant can pay from any
-- device. Each link is for a single (contract, billing_month). When the
-- tenant pays, the paymongo-webhook flips the link to 'paid' and links
-- it to the resulting payment_transactions row.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_links (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id         uuid NOT NULL REFERENCES public.contract(id) ON DELETE CASCADE,
  landlord_id         uuid NOT NULL REFERENCES auth.users(id),
  billing_month       date NOT NULL,
  amount_cents        integer NOT NULL CHECK (amount_cents > 0),
  paymongo_link_id    text UNIQUE NOT NULL,
  checkout_url        text NOT NULL,
  status              text NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','paid','expired','cancelled')),
  paid_transaction_id uuid REFERENCES public.payment_transactions(id),
  note                text,
  expires_at          timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payment_links_contract_idx ON public.payment_links(contract_id);
CREATE INDEX IF NOT EXISTS payment_links_status_idx   ON public.payment_links(contract_id, status);

ALTER TABLE public.payment_links ENABLE ROW LEVEL SECURITY;

-- Tenant + landlord on the contract can both SEE links (tenant needs
-- the URL; landlord manages them). Writes are service-role only — the
-- Edge Function paymongo-create-payment-link does the insert, the
-- webhook does the status update.
DROP POLICY IF EXISTS pl_select_party ON public.payment_links;
CREATE POLICY pl_select_party ON public.payment_links
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.contract c
      WHERE c.id = payment_links.contract_id
        AND (auth.uid() = c.tenant_id OR auth.uid() = c.landlord_id)
    )
  );


-- -----------------------------------------------------
-- payment_transactions_with_context — replace view to add A+B columns
-- DROP + CREATE (not CREATE OR REPLACE) because Postgres rejects
-- column-list changes via REPLACE.
-- -----------------------------------------------------
DROP VIEW IF EXISTS public.payment_transactions_with_context;
CREATE VIEW public.payment_transactions_with_context AS
-- New ledger entries (PayMongo + mock + landlord-recorded offline payments)
SELECT
  pt.id, pt.contract_id, pt.user_id, pt.payment_method_id,
  pt.paymongo_payment_intent_id, pt.paymongo_payment_id,
  pt.amount_cents, pt.currency, pt.status,
  pt.method_type, pt.brand, pt.last4, pt.billing_name,
  pt.failure_reason, pt.raw_response,
  pt.recorded_by, pt.note, pt.billing_month,
  pt.created_at, pt.updated_at,
  c.tenant_id, c.landlord_id, c.listing_id,
  l.title AS listing_title,
  pm.type AS pm_type, pm.label AS pm_label
FROM   public.payment_transactions pt
JOIN   public.contract c          ON c.id = pt.contract_id
LEFT JOIN public.listings l       ON l.id = c.listing_id
LEFT JOIN public.payment_methods pm ON pm.id = pt.payment_method_id

UNION ALL

-- Legacy `payment` rows (pre-PayMongo Stripe payments without a ledger entry)
SELECT
  p.id, p.contract_id,
  c.tenant_id AS user_id,
  NULL::uuid AS payment_method_id,
  COALESCE(p.paymongo_payment_intent_id, p.stripe_payment_intent_id) AS paymongo_payment_intent_id,
  COALESCE(p.paymongo_payment_intent_id, p.stripe_payment_intent_id) AS paymongo_payment_id,
  p.amount_cents, p.currency, p.status,
  'card'::text AS method_type,
  p.method AS brand,
  p.last4,
  p.name AS billing_name,
  NULL::text  AS failure_reason,
  NULL::jsonb AS raw_response,
  NULL::uuid  AS recorded_by,
  NULL::text  AS note,
  p.billing_month,
  p.paid_at AS created_at,
  p.paid_at AS updated_at,
  c.tenant_id, c.landlord_id, c.listing_id,
  l.title AS listing_title,
  NULL::text AS pm_type,
  NULL::text AS pm_label
FROM   public.payment p
JOIN   public.contract c     ON c.id = p.contract_id
LEFT JOIN public.listings l  ON l.id = c.listing_id
WHERE  p.payment_transaction_id IS NULL;

ALTER VIEW public.payment_transactions_with_context SET (security_invoker = true);
