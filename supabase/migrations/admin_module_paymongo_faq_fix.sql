-- Follow-up to admin_module.sql:
-- The original seed shipped with stale Stripe-era copy. The payment stack is
-- now PayMongo (see paymongo_payment_module.sql). Update any FAQ row that
-- still carries the old answer; rows already edited via the admin CMS are
-- left untouched.

UPDATE public.cms_faq
   SET answer = 'GCash, Maya, GrabPay, and cards via PayMongo.'
 WHERE question = 'What payment methods are supported?'
   AND answer   = 'GCash and Stripe-supported cards.';
