-- =============================================================
-- ViewxRent Web — Admin & CMS module
-- Adds the 'admin' role + Content Management tables (pages,
-- announcements, FAQs) with RLS that lets admins manage everything
-- and the public read only published content.
--
-- Paste into Supabase SQL Editor and run once. Idempotent.
-- After running, promote your account with:
--   UPDATE public.profiles SET role = 'admin' WHERE email = 'you@example.com';
-- =============================================================


-- =====================================================
-- 1. is_admin() helper
--    SECURITY DEFINER so it can read profiles even from
--    inside a policy without recursion against itself.
-- =====================================================
CREATE OR REPLACE FUNCTION public.is_admin(uid uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = uid AND p.role = 'admin'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated;


-- =====================================================
-- 2. Profiles: let admins read/manage every row
-- =====================================================
DROP POLICY IF EXISTS profiles_admin_all ON public.profiles;
CREATE POLICY profiles_admin_all ON public.profiles
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Self-read so a logged-in user can always load their own profile
DROP POLICY IF EXISTS profiles_self_select ON public.profiles;
CREATE POLICY profiles_self_select ON public.profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS profiles_self_update ON public.profiles;
CREATE POLICY profiles_self_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());


-- =====================================================
-- 3. Admins can manage all listings / applications / contracts
-- =====================================================
DROP POLICY IF EXISTS listings_admin_all ON public.listings;
CREATE POLICY listings_admin_all ON public.listings
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS application_admin_all ON public.application;
CREATE POLICY application_admin_all ON public.application
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS contract_admin_all ON public.contract;
CREATE POLICY contract_admin_all ON public.contract
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- =====================================================
-- 4. CMS: PAGES (static marketing/legal pages)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.cms_page (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        text NOT NULL UNIQUE,
  title       text NOT NULL,
  body        text NOT NULL DEFAULT '',
  status      text NOT NULL DEFAULT 'draft'
                CHECK (status IN ('draft','published','archived')),
  updated_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cms_page_status_idx ON public.cms_page(status);

ALTER TABLE public.cms_page ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cms_page_public_read   ON public.cms_page;
DROP POLICY IF EXISTS cms_page_admin_all     ON public.cms_page;

CREATE POLICY cms_page_public_read ON public.cms_page
  FOR SELECT USING (status = 'published');

CREATE POLICY cms_page_admin_all ON public.cms_page
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- =====================================================
-- 5. CMS: ANNOUNCEMENTS (banners / system messages)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.cms_announcement (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title       text NOT NULL,
  body        text NOT NULL DEFAULT '',
  audience    text NOT NULL DEFAULT 'all'
                CHECK (audience IN ('all','tenant','landlord')),
  level       text NOT NULL DEFAULT 'info'
                CHECK (level IN ('info','warning','success','danger')),
  is_active   boolean NOT NULL DEFAULT true,
  starts_at   timestamptz,
  ends_at     timestamptz,
  updated_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cms_announcement_active_idx
  ON public.cms_announcement(is_active, starts_at, ends_at);

ALTER TABLE public.cms_announcement ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cms_announcement_public_read ON public.cms_announcement;
DROP POLICY IF EXISTS cms_announcement_admin_all   ON public.cms_announcement;

CREATE POLICY cms_announcement_public_read ON public.cms_announcement
  FOR SELECT
  USING (
    is_active = true
    AND (starts_at IS NULL OR starts_at <= now())
    AND (ends_at   IS NULL OR ends_at   >= now())
  );

CREATE POLICY cms_announcement_admin_all ON public.cms_announcement
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- =====================================================
-- 6. CMS: FAQs
-- =====================================================
CREATE TABLE IF NOT EXISTS public.cms_faq (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category      text NOT NULL DEFAULT 'general',
  question      text NOT NULL,
  answer        text NOT NULL DEFAULT '',
  sort_order    int  NOT NULL DEFAULT 0,
  is_published  boolean NOT NULL DEFAULT true,
  updated_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cms_faq_category_idx
  ON public.cms_faq(category, sort_order);

ALTER TABLE public.cms_faq ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cms_faq_public_read ON public.cms_faq;
DROP POLICY IF EXISTS cms_faq_admin_all   ON public.cms_faq;

CREATE POLICY cms_faq_public_read ON public.cms_faq
  FOR SELECT USING (is_published = true);

CREATE POLICY cms_faq_admin_all ON public.cms_faq
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- =====================================================
-- 7. Generic updated_at trigger reused by all CMS tables
-- =====================================================
CREATE OR REPLACE FUNCTION public.cms_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['cms_page','cms_announcement','cms_faq']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I_touch ON public.%I', t, t);
    EXECUTE format(
      'CREATE TRIGGER %I_touch BEFORE UPDATE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.cms_touch_updated_at()',
      t, t
    );
  END LOOP;
END $$;


-- =====================================================
-- 8. Seed a few starter rows (only if empty)
-- =====================================================
INSERT INTO public.cms_page (slug, title, body, status)
SELECT * FROM (VALUES
  ('about',          'About ViewxRent',  'ViewxRent is a community-driven rental marketplace.',                       'published'),
  ('terms',          'Terms of Service', 'Add your terms here.',                                                       'draft'),
  ('privacy',        'Privacy Policy',   'Add your privacy policy here.',                                              'draft'),
  ('help',           'Help Center',      'Common questions and how to reach support.',                                 'published')
) AS v(slug, title, body, status)
WHERE NOT EXISTS (SELECT 1 FROM public.cms_page);

INSERT INTO public.cms_faq (category, question, answer, sort_order)
SELECT * FROM (VALUES
  ('general',  'How do I list my property?',           'Sign up as a landlord and use the My Listings page.', 1),
  ('general',  'How do I apply for a unit?',           'Open the unit and tap Apply.',                        2),
  ('payments', 'What payment methods are supported?',  'GCash, Maya, GrabPay, and cards via PayMongo.',       3)
) AS v(category, question, answer, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM public.cms_faq);
