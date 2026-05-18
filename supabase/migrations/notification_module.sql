-- =============================================================
-- Notification module: table, RLS, message -> notification trigger,
-- and realtime publication.
--
-- Idempotent — safe to re-run. Run this in the Supabase SQL editor.
--
-- Why this exists: the web/mobile clients drive a notification bell +
-- panel via NotificationContext, but the notification table itself was
-- previously created ad-hoc in the dashboard. It was missing from the
-- supabase_realtime publication (so live updates never fired), and the
-- client-side cross-user insert in messagingService.js was at the mercy
-- of whatever RLS policy happened to exist (likely none, or only-self).
-- This script makes the schema explicit and moves message-notification
-- creation server-side via a SECURITY DEFINER trigger.
-- =============================================================


-- ---------- 1. Table ----------
CREATE TABLE IF NOT EXISTS public.notification (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type            text NOT NULL,
  title           text NOT NULL,
  body            text,
  reference_id    uuid,
  reference_type  text,
  is_read         boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notification_user_created_idx
  ON public.notification (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notification_user_unread_idx
  ON public.notification (user_id) WHERE is_read = false;


-- ---------- 2. Row-level security ----------
ALTER TABLE public.notification ENABLE ROW LEVEL SECURITY;

-- Users can read their own notifications.
DROP POLICY IF EXISTS notification_select_owner ON public.notification;
CREATE POLICY notification_select_owner ON public.notification
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Users can update their own (mark-as-read, etc.).
DROP POLICY IF EXISTS notification_update_owner ON public.notification;
CREATE POLICY notification_update_owner ON public.notification
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Users can directly insert notifications for *themselves* — this powers
-- flows like "you just applied" / "your payment was recorded" where the
-- current user is also the recipient.
-- Cross-user inserts (e.g. tenant -> landlord on new message) go through
-- the SECURITY DEFINER trigger below, which bypasses this policy.
DROP POLICY IF EXISTS notification_insert_self ON public.notification;
CREATE POLICY notification_insert_self ON public.notification
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Users can delete their own (panel dismiss / cleanup).
DROP POLICY IF EXISTS notification_delete_owner ON public.notification;
CREATE POLICY notification_delete_owner ON public.notification
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());


-- ---------- 3. message -> notification trigger ----------
-- Runs as the function owner (SECURITY DEFINER) so it can insert a
-- notification row for the recipient regardless of RLS. Mirrors the body
-- text the client used to compute in messagingService.js.
CREATE OR REPLACE FUNCTION public.create_message_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  recipient_id uuid;
  notif_body   text;
BEGIN
  -- Find the other participant in the conversation.
  SELECT CASE
           WHEN c.tenant_id = NEW.sender_id THEN c.landlord_id
           WHEN c.landlord_id = NEW.sender_id THEN c.tenant_id
           ELSE NULL
         END
    INTO recipient_id
    FROM public.conversation c
   WHERE c.id = NEW.conversation_id;

  IF recipient_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Compose a short body matching the previous client-side format.
  IF NEW.type = 'image' THEN
    notif_body := 'Sent you an image';
  ELSIF NEW.type = 'file' THEN
    notif_body := 'Sent you a file' ||
                  COALESCE(': ' || NEW.file_name, '');
  ELSE
    notif_body := CASE
                    WHEN length(COALESCE(NEW.content, '')) > 80
                      THEN substring(NEW.content from 1 for 80) || '…'
                    ELSE COALESCE(NEW.content, '')
                  END;
  END IF;

  INSERT INTO public.notification (
    user_id, type, title, body, reference_id, reference_type
  ) VALUES (
    recipient_id,
    'message',
    'New message',
    notif_body,
    NEW.conversation_id,
    'message'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS message_create_notification ON public.message;
CREATE TRIGGER message_create_notification
  AFTER INSERT ON public.message
  FOR EACH ROW
  EXECUTE FUNCTION public.create_message_notification();


-- ---------- 4. Realtime ----------
-- The web client's NotificationContext subscribes to INSERTs on this
-- table filtered to the current user. Without this publication entry,
-- the subscription never fires.
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notification;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;


-- =============================================================
-- 5. Cross-user notification triggers
-- =============================================================
-- The client-side createNotification() call cannot cross users because
-- notification_insert_self only allows user_id = auth.uid(). All
-- cross-user flows below run server-side as SECURITY DEFINER so they
-- can write a row for the other party without broadening RLS.
--
-- Pattern mirrors create_message_notification: AFTER INSERT / UPDATE,
-- compute the recipient, INSERT a notification row, return NEW.
-- =============================================================


-- ---------- 5a. application: submit + status change ----------
CREATE OR REPLACE FUNCTION public.notify_application_submitted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  applicant_name text;
BEGIN
  IF NEW.landlord_id IS NULL THEN RETURN NEW; END IF;

  applicant_name := NULLIF(
    trim(both ' ' FROM COALESCE(NEW.first_name, '') || ' ' || COALESCE(NEW.last_name, '')),
    ''
  );

  INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
  VALUES (
    NEW.landlord_id,
    'application',
    'New rental application',
    CASE
      WHEN applicant_name IS NOT NULL THEN applicant_name || ' applied for your listing'
      ELSE 'A tenant applied for your listing'
    END,
    NEW.id,
    'application'
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS application_notify_submitted ON public.application;
CREATE TRIGGER application_notify_submitted
  AFTER INSERT ON public.application
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_application_submitted();


CREATE OR REPLACE FUNCTION public.notify_application_status_changed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
  IF NEW.tenant_id IS NULL THEN RETURN NEW; END IF;
  IF NEW.status NOT IN ('approved', 'rejected') THEN RETURN NEW; END IF;

  INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
  VALUES (
    NEW.tenant_id,
    'application',
    CASE NEW.status
      WHEN 'approved' THEN 'Application approved'
      WHEN 'rejected' THEN 'Application rejected'
      ELSE 'Application ' || NEW.status
    END,
    NULL,
    NEW.id,
    'application'
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS application_notify_status ON public.application;
CREATE TRIGGER application_notify_status
  AFTER UPDATE OF status ON public.application
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_application_status_changed();


-- ---------- 5b. contract: created + signed + cancelled ----------
CREATE OR REPLACE FUNCTION public.notify_contract_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.tenant_id IS NULL THEN RETURN NEW; END IF;

  INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
  VALUES (
    NEW.tenant_id,
    'contract',
    'New contract',
    'Your landlord sent you a contract to review and sign',
    NEW.id,
    'contract'
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS contract_notify_created ON public.contract;
CREATE TRIGGER contract_notify_created
  AFTER INSERT ON public.contract
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_contract_created();


CREATE OR REPLACE FUNCTION public.notify_contract_signed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  signer_role  text;
  recipient_id uuid;
  fully_signed boolean;
BEGIN
  -- Determine which side just signed (signature went from NULL → non-NULL).
  IF NEW.tenant_signature IS NOT NULL AND OLD.tenant_signature IS NULL THEN
    signer_role  := 'Tenant';
    recipient_id := NEW.landlord_id;
  ELSIF NEW.landlord_signature IS NOT NULL AND OLD.landlord_signature IS NULL THEN
    signer_role  := 'Landlord';
    recipient_id := NEW.tenant_id;
  ELSE
    RETURN NEW;
  END IF;

  IF recipient_id IS NULL THEN RETURN NEW; END IF;

  fully_signed := NEW.status = 'fully_signed';

  INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
  VALUES (
    recipient_id,
    'contract',
    CASE WHEN fully_signed THEN 'Contract fully signed' ELSE 'Contract signed' END,
    CASE
      WHEN fully_signed THEN 'Both parties have signed the contract.'
      ELSE signer_role || ' signed the contract'
    END,
    NEW.id,
    'contract'
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS contract_notify_signed ON public.contract;
CREATE TRIGGER contract_notify_signed
  AFTER UPDATE OF tenant_signature, landlord_signature ON public.contract
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_contract_signed();


CREATE OR REPLACE FUNCTION public.notify_contract_status_changed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor_id uuid := auth.uid();
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;

  -- Cancellation / move-out termination notifies the counter-party
  -- (whichever side did NOT initiate, falls back to both if unknown).
  IF NEW.status = 'cancelled' THEN
    IF actor_id IS NULL OR actor_id = NEW.landlord_id THEN
      IF NEW.tenant_id IS NOT NULL THEN
        INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
        VALUES (NEW.tenant_id, 'contract', 'Contract cancelled',
                'The lease contract has been cancelled.', NEW.id, 'contract');
      END IF;
    END IF;
    IF actor_id IS NULL OR actor_id = NEW.tenant_id THEN
      IF NEW.landlord_id IS NOT NULL THEN
        INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
        VALUES (NEW.landlord_id, 'contract', 'Contract cancelled',
                'The lease contract has been cancelled.', NEW.id, 'contract');
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS contract_notify_status ON public.contract;
CREATE TRIGGER contract_notify_status
  AFTER UPDATE OF status ON public.contract
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_contract_status_changed();


-- ---------- 5c. report: filed + status update + landlord response ----------
-- NB: the report table is created by a mobile migration not mirrored here.
-- These triggers assume it exists with columns tenant_id, landlord_id,
-- title, status, landlord_response. If the table is missing, run the
-- mobile report_module migration first.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'report') THEN

    CREATE OR REPLACE FUNCTION public.notify_report_submitted()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $body$
    BEGIN
      IF NEW.landlord_id IS NULL THEN RETURN NEW; END IF;
      INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
      VALUES (NEW.landlord_id, 'report', 'New maintenance report',
              NEW.title, NEW.id, 'report');
      RETURN NEW;
    END;
    $body$;

    DROP TRIGGER IF EXISTS report_notify_submitted ON public.report;
    CREATE TRIGGER report_notify_submitted
      AFTER INSERT ON public.report
      FOR EACH ROW
      EXECUTE FUNCTION public.notify_report_submitted();


    CREATE OR REPLACE FUNCTION public.notify_report_status_changed()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $body$
    BEGIN
      IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
      IF NEW.tenant_id IS NULL THEN RETURN NEW; END IF;
      IF NEW.status NOT IN ('in_progress', 'resolved') THEN RETURN NEW; END IF;

      INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
      VALUES (NEW.tenant_id, 'report',
              'Report ' || replace(NEW.status, '_', ' '),
              NULL, NEW.id, 'report');
      RETURN NEW;
    END;
    $body$;

    DROP TRIGGER IF EXISTS report_notify_status ON public.report;
    CREATE TRIGGER report_notify_status
      AFTER UPDATE OF status ON public.report
      FOR EACH ROW
      EXECUTE FUNCTION public.notify_report_status_changed();


    CREATE OR REPLACE FUNCTION public.notify_report_response()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $body$
    DECLARE
      notif_body text;
    BEGIN
      IF NEW.landlord_response IS NOT DISTINCT FROM OLD.landlord_response THEN
        RETURN NEW;
      END IF;
      IF NEW.landlord_response IS NULL THEN RETURN NEW; END IF;
      IF NEW.tenant_id IS NULL THEN RETURN NEW; END IF;

      notif_body := CASE
                      WHEN length(NEW.landlord_response) > 120
                        THEN substring(NEW.landlord_response from 1 for 120) || '…'
                      ELSE NEW.landlord_response
                    END;

      INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
      VALUES (NEW.tenant_id, 'report', 'Landlord responded',
              notif_body, NEW.id, 'report');
      RETURN NEW;
    END;
    $body$;

    DROP TRIGGER IF EXISTS report_notify_response ON public.report;
    CREATE TRIGGER report_notify_response
      AFTER UPDATE OF landlord_response ON public.report
      FOR EACH ROW
      EXECUTE FUNCTION public.notify_report_response();
  END IF;
END $$;


-- ---------- 5d. payment: succeeded ----------
-- Notifies both contract parties when a payment is recorded as succeeded.
-- Triggers on INSERT (new payment row) and on UPDATE when status transitions
-- to 'succeeded' (e.g. webhook flips a pending row).
CREATE OR REPLACE FUNCTION public.notify_payment_succeeded()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  tenant_uid    uuid;
  landlord_uid  uuid;
  listing_title text;
  amount_str    text;
  body_text     text;
BEGIN
  -- Only fire when crossing into 'succeeded'.
  IF TG_OP = 'UPDATE' AND OLD.status = 'succeeded' THEN RETURN NEW; END IF;
  IF NEW.status <> 'succeeded' THEN RETURN NEW; END IF;

  SELECT c.tenant_id, c.landlord_id, l.title
    INTO tenant_uid, landlord_uid, listing_title
    FROM public.contract c
    LEFT JOIN public.listings l ON l.id = c.listing_id
   WHERE c.id = NEW.contract_id;

  amount_str := to_char(NEW.amount_cents / 100.0, 'FM999,999,990.00');
  body_text  := 'Payment of ' || COALESCE(NEW.currency, 'PHP') || ' ' || amount_str ||
                COALESCE(' for ' || listing_title, '');

  IF tenant_uid IS NOT NULL THEN
    INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
    VALUES (tenant_uid, 'payment', 'Payment received', body_text,
            NEW.contract_id, 'contract');
  END IF;

  IF landlord_uid IS NOT NULL THEN
    INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
    VALUES (landlord_uid, 'payment', 'Tenant payment received', body_text,
            NEW.contract_id, 'contract');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS payment_notify_succeeded_ins ON public.payment;
CREATE TRIGGER payment_notify_succeeded_ins
  AFTER INSERT ON public.payment
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_payment_succeeded();

DROP TRIGGER IF EXISTS payment_notify_succeeded_upd ON public.payment;
CREATE TRIGGER payment_notify_succeeded_upd
  AFTER UPDATE OF status ON public.payment
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_payment_succeeded();


-- ---------- 5e. verifications: decision update ----------
CREATE OR REPLACE FUNCTION public.notify_verification_decision()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  title_text text;
  body_text  text;
BEGIN
  IF NEW.decision IS NOT DISTINCT FROM OLD.decision THEN RETURN NEW; END IF;
  IF NEW.user_id IS NULL THEN RETURN NEW; END IF;

  IF NEW.decision = 'approved' THEN
    title_text := 'Identity verified';
    body_text  := 'Your government ID was approved. You can now apply to listings.';
  ELSIF NEW.decision = 'rejected' THEN
    title_text := 'Identity verification rejected';
    body_text  := COALESCE(NEW.decision_reason,
                           'Please resubmit a clearer photo of your government ID.');
  ELSIF NEW.decision = 'manual_review' THEN
    title_text := 'Identity verification under review';
    body_text  := 'An admin is reviewing your submission. We''ll notify you once it''s decided.';
  ELSE
    RETURN NEW;
  END IF;

  INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
  VALUES (NEW.user_id, 'verification', title_text, body_text, NEW.id, 'verification');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS verifications_notify_decision ON public.verifications;
CREATE TRIGGER verifications_notify_decision
  AFTER UPDATE OF decision ON public.verifications
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_verification_decision();


-- ---------- 5f. listings: verification approved / rejected ----------
-- Fires when admin flips is_verified true (approval) or clears
-- verification_submitted_at while is_verified=false (rejection).
CREATE OR REPLACE FUNCTION public.notify_listing_verification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  approved boolean;
  rejected boolean;
BEGIN
  IF NEW.landlord_id IS NULL THEN RETURN NEW; END IF;

  approved := NEW.is_verified = true AND COALESCE(OLD.is_verified, false) = false;
  rejected := NEW.is_verified = false
              AND COALESCE(OLD.is_verified, false) = false
              AND OLD.verification_submitted_at IS NOT NULL
              AND NEW.verification_submitted_at IS NULL;

  IF approved THEN
    INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
    VALUES (NEW.landlord_id, 'listing', 'Listing approved',
            COALESCE('“' || NEW.title || '” is now live.',
                     'Your listing is now live.'),
            NEW.id, 'listing');
  ELSIF rejected THEN
    INSERT INTO public.notification (user_id, type, title, body, reference_id, reference_type)
    VALUES (NEW.landlord_id, 'listing', 'Listing verification rejected',
            'Please resubmit a verification document for your listing.',
            NEW.id, 'listing');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS listings_notify_verification ON public.listings;
CREATE TRIGGER listings_notify_verification
  AFTER UPDATE OF is_verified, verification_submitted_at ON public.listings
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_listing_verification();
