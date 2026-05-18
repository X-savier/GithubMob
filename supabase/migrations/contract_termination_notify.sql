-- =============================================================
-- contract_termination -> notification trigger
--
-- When a tenant or landlord inserts a termination request into
-- public.contract_termination, notify the counter-party so the
-- request surfaces in the bell + tenant-management screen.
--
-- Idempotent. Safe to re-apply. Mirrors the SECURITY DEFINER
-- pattern used by notify_contract_status_changed in
-- notification_module.sql.
-- =============================================================

CREATE OR REPLACE FUNCTION public.notify_contract_termination_requested()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  c_landlord_id uuid;
  c_tenant_id   uuid;
  recipient_id  uuid;
  notif_title   text;
  notif_body    text;
  effective_str text;
BEGIN
  SELECT landlord_id, tenant_id
    INTO c_landlord_id, c_tenant_id
    FROM public.contract
   WHERE id = NEW.contract_id;

  -- Counter-party = whoever did NOT initiate.
  IF NEW.initiated_by = 'tenant' THEN
    recipient_id := c_landlord_id;
    notif_title  := 'Tenant requested termination';
  ELSIF NEW.initiated_by = 'landlord' THEN
    recipient_id := c_tenant_id;
    notif_title  := 'Landlord requested termination';
  ELSE
    RETURN NEW;
  END IF;

  IF recipient_id IS NULL THEN
    RETURN NEW;
  END IF;

  effective_str := COALESCE(to_char(NEW.effective_date, 'Mon DD, YYYY'), 'soon');

  notif_body := CASE NEW.type
                  WHEN 'mutual'      THEN 'Mutual termination proposed, effective ' || effective_str || '.'
                  WHEN 'notice'      THEN '30-day notice filed, effective ' || effective_str || '.'
                  WHEN 'non_renewal' THEN 'Non-renewal filed, effective ' || effective_str || '.'
                  WHEN 'eviction'    THEN 'Eviction notice filed, effective ' || effective_str || '.'
                  ELSE 'Termination requested, effective ' || effective_str || '.'
                END;

  INSERT INTO public.notification (
    user_id, type, title, body, reference_id, reference_type
  ) VALUES (
    recipient_id,
    'contract',
    notif_title,
    notif_body,
    NEW.contract_id,
    'contract'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS contract_termination_notify ON public.contract_termination;
CREATE TRIGGER contract_termination_notify
  AFTER INSERT ON public.contract_termination
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_contract_termination_requested();
