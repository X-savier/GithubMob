-- =============================================================
-- POST-RENT MODULE
-- Adds termination, move-out, deposit deduction, audit, relisting.
-- Idempotent — safe to re-run.
--
-- Status flow:
--   active ──(notice)──► terminating ──(effective + tenant-vacated)──► terminated ──(close)──► closed
--   active ──(propose+accept)──► terminating ──► terminated ──► closed     [mutual / fixed-term]
--   active ──(at endDate, no renewal)──► expiring ──(endDate)──► ended ──(close)──► closed
--   active ──(eviction)──► terminating(eviction) ──► terminated ──► closed
--   listings.status: rented → archived (on close) → active (on relist)
-- =============================================================


-- ========== contract: extend status + add lifecycle columns ==========
-- Drop the old status check before adding the new statuses, then re-add
-- with the wider allowed set. The old check rejected the new values.
ALTER TABLE public.contract DROP CONSTRAINT IF EXISTS contract_status_check;

ALTER TABLE public.contract
  ADD COLUMN IF NOT EXISTS terminated_by       text,
  ADD COLUMN IF NOT EXISTS termination_reason  text,
  ADD COLUMN IF NOT EXISTS notice_date         date,
  ADD COLUMN IF NOT EXISTS effective_end_date  date,
  ADD COLUMN IF NOT EXISTS actual_end_date     timestamptz;

ALTER TABLE public.contract
  ADD CONSTRAINT contract_status_check CHECK (status IN (
    'awaiting_tenant','awaiting_landlord',
    'fully_signed','paid','cancelled',
    'terminating','terminated','expiring','ended','closed'
  ));

ALTER TABLE public.contract DROP CONSTRAINT IF EXISTS contract_terminated_by_check;
ALTER TABLE public.contract
  ADD CONSTRAINT contract_terminated_by_check CHECK (
    terminated_by IS NULL OR terminated_by IN ('tenant','landlord','mutual','expired','eviction')
  );


-- ========== listings: add 'archived' status ==========
-- listings.status check varies between environments; do the dance defensively.
DO $$
DECLARE conname text;
BEGIN
  SELECT con.conname INTO conname
  FROM pg_constraint con
  JOIN pg_class cls ON cls.oid = con.conrelid
  JOIN pg_namespace n ON n.oid = cls.relnamespace
  WHERE n.nspname = 'public' AND cls.relname = 'listings'
    AND con.contype = 'c'
    AND pg_get_constraintdef(con.oid) ILIKE '%status%';
  IF conname IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.listings DROP CONSTRAINT %I', conname);
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.listings
  ADD CONSTRAINT listings_status_check CHECK (status IN (
    'active','pending','rented','archived','rejected','draft','inactive'
  ));


-- ========== contract_termination ==========
CREATE TABLE IF NOT EXISTS public.contract_termination (
  id                              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id                     uuid NOT NULL REFERENCES public.contract(id) ON DELETE CASCADE,
  initiated_by                    text NOT NULL CHECK (initiated_by IN ('tenant','landlord')),
  type                            text NOT NULL CHECK (type IN (
                                    'notice','mutual','non_renewal','eviction','expired'
                                  )),
  notice_date                     date NOT NULL DEFAULT CURRENT_DATE,
  effective_date                  date NOT NULL,
  reason                          text,

  -- Mutual termination handshake (fixed-term only)
  mutual_proposed_at              timestamptz,
  mutual_accepted_by_tenant_at    timestamptz,
  mutual_accepted_by_landlord_at  timestamptz,
  mutual_withdrawn_at             timestamptz,

  -- Move-out gates
  tenant_vacated_confirmed_at     timestamptz,
  reports_carry_over_ack          boolean DEFAULT false,
  outstanding_balance_waived      boolean DEFAULT false,
  outstanding_balance_waive_note  text,

  -- Deposit summary (running totals; itemized rows live in contract_deduction)
  security_deposit_amount         numeric NOT NULL DEFAULT 0,
  total_deductions                numeric NOT NULL DEFAULT 0,
  amount_returned                 numeric NOT NULL DEFAULT 0,
  deposit_acknowledged_by_tenant  timestamptz,
  deposit_disputed_by_tenant      timestamptz,
  deposit_dispute_note            text,

  -- Closure
  landlord_closed_at              timestamptz,
  forced_close_reason             text,

  created_at                      timestamptz NOT NULL DEFAULT now(),
  updated_at                      timestamptz NOT NULL DEFAULT now(),

  UNIQUE (contract_id)
);

CREATE INDEX IF NOT EXISTS contract_termination_contract_idx
  ON public.contract_termination(contract_id);
CREATE INDEX IF NOT EXISTS contract_termination_effective_idx
  ON public.contract_termination(effective_date);

ALTER TABLE public.contract_termination ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS contract_termination_select_party ON public.contract_termination;
CREATE POLICY contract_termination_select_party ON public.contract_termination
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.contract c
    WHERE c.id = contract_termination.contract_id
      AND (c.tenant_id = auth.uid() OR c.landlord_id = auth.uid())
  ));

DROP POLICY IF EXISTS contract_termination_insert_party ON public.contract_termination;
CREATE POLICY contract_termination_insert_party ON public.contract_termination
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.contract c
    WHERE c.id = contract_id
      AND (c.tenant_id = auth.uid() OR c.landlord_id = auth.uid())
  ));

-- Tenant can only update tenant-side fields (vacated confirmation, deposit ack/dispute).
-- Landlord can update everything else. Since RLS can't gate per-column cleanly here,
-- we allow both parties to UPDATE and rely on app-level guards in postRentService.
DROP POLICY IF EXISTS contract_termination_update_party ON public.contract_termination;
CREATE POLICY contract_termination_update_party ON public.contract_termination
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.contract c
    WHERE c.id = contract_termination.contract_id
      AND (c.tenant_id = auth.uid() OR c.landlord_id = auth.uid())
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.contract c
    WHERE c.id = contract_termination.contract_id
      AND (c.tenant_id = auth.uid() OR c.landlord_id = auth.uid())
  ));

-- DELETE: allow either party to remove a superseded (withdrawn or closed)
-- termination row so a fresh request can be filed. App layer is responsible
-- for only deleting rows that are no longer load-bearing; the contract_event
-- log preserves the audit trail.
DROP POLICY IF EXISTS contract_termination_delete_party ON public.contract_termination;
CREATE POLICY contract_termination_delete_party ON public.contract_termination
  FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.contract c
    WHERE c.id = contract_termination.contract_id
      AND (c.tenant_id = auth.uid() OR c.landlord_id = auth.uid())
  ));


-- ========== contract_deduction ==========
CREATE TABLE IF NOT EXISTS public.contract_deduction (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  termination_id  uuid NOT NULL REFERENCES public.contract_termination(id) ON DELETE CASCADE,
  category        text NOT NULL CHECK (category IN (
                    'damage','cleaning','unpaid_rent','utilities','keys','other'
                  )),
  description     text,
  amount          numeric NOT NULL CHECK (amount >= 0),
  photo_url       text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS contract_deduction_termination_idx
  ON public.contract_deduction(termination_id);

ALTER TABLE public.contract_deduction ENABLE ROW LEVEL SECURITY;

-- Read: both parties on the underlying contract.
-- Write: landlord only (verified via contract.landlord_id = auth.uid()).
DROP POLICY IF EXISTS contract_deduction_select_party ON public.contract_deduction;
CREATE POLICY contract_deduction_select_party ON public.contract_deduction
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.contract_termination ct
    JOIN public.contract c ON c.id = ct.contract_id
    WHERE ct.id = contract_deduction.termination_id
      AND (c.tenant_id = auth.uid() OR c.landlord_id = auth.uid())
  ));

DROP POLICY IF EXISTS contract_deduction_landlord_write ON public.contract_deduction;
CREATE POLICY contract_deduction_landlord_write ON public.contract_deduction
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.contract_termination ct
    JOIN public.contract c ON c.id = ct.contract_id
    WHERE ct.id = contract_deduction.termination_id
      AND c.landlord_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.contract_termination ct
    JOIN public.contract c ON c.id = ct.contract_id
    WHERE ct.id = termination_id
      AND c.landlord_id = auth.uid()
  ));


-- ========== contract_event (audit log) ==========
CREATE TABLE IF NOT EXISTS public.contract_event (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id  uuid NOT NULL REFERENCES public.contract(id) ON DELETE CASCADE,
  actor_id     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type   text NOT NULL,
  payload      jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS contract_event_contract_idx
  ON public.contract_event(contract_id, created_at DESC);

ALTER TABLE public.contract_event ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS contract_event_select_party ON public.contract_event;
CREATE POLICY contract_event_select_party ON public.contract_event
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.contract c
    WHERE c.id = contract_event.contract_id
      AND (c.tenant_id = auth.uid() OR c.landlord_id = auth.uid())
  ));

DROP POLICY IF EXISTS contract_event_insert_party ON public.contract_event;
CREATE POLICY contract_event_insert_party ON public.contract_event
  FOR INSERT TO authenticated
  WITH CHECK (
    actor_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.contract c
      WHERE c.id = contract_id
        AND (c.tenant_id = auth.uid() OR c.landlord_id = auth.uid())
    )
  );


-- ========== contract_termination: keep totals in sync with deductions ==========
CREATE OR REPLACE FUNCTION public.contract_termination_recalc_totals()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  tid uuid;
  total numeric;
BEGIN
  tid := COALESCE(NEW.termination_id, OLD.termination_id);
  SELECT COALESCE(SUM(amount), 0) INTO total
  FROM public.contract_deduction
  WHERE termination_id = tid;

  UPDATE public.contract_termination
  SET total_deductions = total,
      amount_returned  = GREATEST(security_deposit_amount - total, 0),
      updated_at       = now()
  WHERE id = tid;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS contract_deduction_recalc ON public.contract_deduction;
CREATE TRIGGER contract_deduction_recalc
  AFTER INSERT OR UPDATE OR DELETE ON public.contract_deduction
  FOR EACH ROW EXECUTE FUNCTION public.contract_termination_recalc_totals();
