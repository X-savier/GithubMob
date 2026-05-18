// supabase/functions/paymongo-add-method
//
// Saves an e-wallet or bank-transfer payment method shortcut for the
// current user. Cards are NOT saved (PayMongo doesn't expose card
// vaulting in PH; saving display metadata would mislead users).
//
// If set_default is true, the function atomically unsets any other
// default for this user before flipping the new row.
//
// Request body: {
//   type: 'gcash' | 'paymaya' | 'grab_pay' | 'bank_transfer',
//   label?: string,
//   account_hint?: string,
//   billing_name?: string,
//   set_default?: boolean
// }
// Response: { method }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { corsHeaders } from "../_shared/cors.ts";

const ALLOWED_TYPES = new Set(["gcash", "paymaya", "grab_pay", "bank_transfer"]);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST")    return json({ error: "Method not allowed" }, 405);

  try {
    const auth = req.headers.get("Authorization") ?? "";
    if (!auth) return json({ error: "Missing Authorization header" }, 401);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: auth } } },
    );

    const { data: userRes, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userRes?.user) return json({ error: "Invalid session" }, 401);
    const user = userRes.user;

    const { type, label, account_hint, billing_name, set_default, is_mock } =
      await req.json().catch(() => ({}));

    if (!type || !ALLOWED_TYPES.has(type)) {
      return json({ error: "Invalid type. Must be gcash, paymaya, grab_pay, or bank_transfer" }, 400);
    }

    if (is_mock === true && Deno.env.get("MOCK_PAYMENTS_ENABLED") !== "true") {
      return json({ error: "Mock payments are disabled on this server" }, 403);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // If this is the user's first method, force it to be the default
    // regardless of the flag — they'll always need one preselected.
    const { count } = await admin
      .from("payment_methods")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .is("deleted_at", null);

    const becomesDefault = set_default === true || (count ?? 0) === 0;

    if (becomesDefault) {
      // Atomically unset other defaults (the partial unique index
      // prevents two true rows at once).
      await admin
        .from("payment_methods")
        .update({ is_default: false })
        .eq("user_id", user.id)
        .is("deleted_at", null)
        .eq("is_default", true);
    }

    const { data: inserted, error: insErr } = await admin
      .from("payment_methods")
      .insert({
        user_id:      user.id,
        type,
        label:        label ?? null,
        account_hint: account_hint ?? null,
        billing_name: billing_name ?? null,
        is_default:   becomesDefault,
        is_mock:      is_mock === true,
      })
      .select("*")
      .single();

    if (insErr) return json({ error: insErr.message }, 500);

    return json({ method: inserted });
  } catch (err) {
    return json({ error: (err as Error).message ?? String(err) }, 500);
  }
});
