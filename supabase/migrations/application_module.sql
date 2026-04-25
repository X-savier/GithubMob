-- ─────────────────────────────────────────────
-- APPLICATION MODULE: schema additions
-- ─────────────────────────────────────────────
-- Run this once in the Supabase SQL editor.
-- Idempotent — safe to re-run.

-- 1. listings.listing_type ─ 'lease' (fixed-term) | 'rent' (month-to-month)
ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS listing_type text NOT NULL DEFAULT 'lease'
  CHECK (listing_type IN ('lease', 'rent'));

-- 2. contract ─ one row per approved application; tracks dual signing.
CREATE TABLE IF NOT EXISTS contract (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES application(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES auth.users(id),
  landlord_id uuid NOT NULL REFERENCES auth.users(id),
  listing_type text NOT NULL DEFAULT 'lease'
    CHECK (listing_type IN ('lease', 'rent')),
  status text NOT NULL DEFAULT 'awaiting_tenant'
    CHECK (status IN (
      'awaiting_tenant',
      'awaiting_landlord',
      'fully_signed',
      'paid',
      'cancelled'
    )),
  tenant_signature text,
  tenant_signed_name text,
  tenant_signed_at timestamptz,
  landlord_signature text,
  landlord_signed_name text,
  landlord_signed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (application_id)
);

CREATE INDEX IF NOT EXISTS contract_tenant_id_idx ON contract(tenant_id);
CREATE INDEX IF NOT EXISTS contract_landlord_id_idx ON contract(landlord_id);

-- 3. payment ─ one row per successful Stripe charge against a contract.
CREATE TABLE IF NOT EXISTS payment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES contract(id) ON DELETE CASCADE,
  stripe_payment_intent_id text NOT NULL,
  amount_cents integer NOT NULL CHECK (amount_cents > 0),
  currency text NOT NULL DEFAULT 'php',
  status text NOT NULL DEFAULT 'succeeded'
    CHECK (status IN ('succeeded', 'pending', 'failed', 'refunded')),
  paid_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (stripe_payment_intent_id)
);

CREATE INDEX IF NOT EXISTS payment_contract_id_idx ON payment(contract_id);

-- 4. RLS — enable on the new tables and add a minimal policy set.
ALTER TABLE contract ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment  ENABLE ROW LEVEL SECURITY;

-- Tenant or landlord on the contract row can read it.
DROP POLICY IF EXISTS contract_select_party ON contract;
CREATE POLICY contract_select_party ON contract
  FOR SELECT
  USING (auth.uid() = tenant_id OR auth.uid() = landlord_id);

-- Either party can insert/update their own row (the app guards which
-- columns get touched; per-column RLS is overkill for sandbox).
DROP POLICY IF EXISTS contract_write_party ON contract;
CREATE POLICY contract_write_party ON contract
  FOR ALL
  USING (auth.uid() = tenant_id OR auth.uid() = landlord_id)
  WITH CHECK (auth.uid() = tenant_id OR auth.uid() = landlord_id);

-- Payments are visible to the contract's parties.
DROP POLICY IF EXISTS payment_select_party ON payment;
CREATE POLICY payment_select_party ON payment
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM contract c
      WHERE c.id = payment.contract_id
        AND (auth.uid() = c.tenant_id OR auth.uid() = c.landlord_id)
    )
  );

DROP POLICY IF EXISTS payment_insert_party ON payment;
CREATE POLICY payment_insert_party ON payment
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM contract c
      WHERE c.id = payment.contract_id
        AND (auth.uid() = c.tenant_id OR auth.uid() = c.landlord_id)
    )
  );
