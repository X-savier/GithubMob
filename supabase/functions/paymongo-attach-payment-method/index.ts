// supabase/functions/paymongo-attach-payment-method
//
// The browser created a PayMongo PaymentMethod (card via PayMongo.js
// iframe, or an e-wallet/bank PM via the public-key REST call) and
// hands us its id. We attach it server-side using the secret key and
// return the resulting status + redirect URL (for e-wallets).
//
// Request body:  {
//   payment_intent_id: string,
//   payment_method_id: string,
//   return_url:        string,
//   payment_method_record_id?: string  // links the ledger row to a saved method
// }
// Response:      {
//   status: string,
//   next_action: { type: string, redirect: { url: string } } | null,
//   payment_method_id: string
// }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { corsHeaders } from "../_shared/cors.ts";
import { pmFetch, firstPmError } from "../_shared/paymongo.ts";

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

    const {
      payment_intent_id,
      payment_method_id,
      return_url,
      payment_method_record_id,
    } = await req.json().catch(() => ({}));

    if (!payment_intent_id || !payment_method_id || !return_url) {
      return json({ error: "Missing payment_intent_id, payment_method_id, or return_url" }, 400);
    }

    // Verify the caller owns the ledger row for this PI.
    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const { data: ledger } = await admin
      .from("payment_transactions")
      .select("id, user_id, contract_id")
      .eq("paymongo_payment_intent_id", payment_intent_id)
      .maybeSingle();

    if (!ledger) return json({ error: "Unknown payment intent" }, 404);
    if (ledger.user_id !== user.id) return json({ error: "Not your payment" }, 403);

    const attachRes = await pmFetch(`/payment_intents/${payment_intent_id}/attach`, {
      method: "POST",
      body: JSON.stringify({
        data: {
          attributes: {
            payment_method: payment_method_id,
            return_url,
          },
        },
      }),
    });

    if (!attachRes.ok) {
      await admin
        .from("payment_transactions")
        .update({
          status: "failed",
          failure_reason: firstPmError(attachRes.body),
          raw_response: attachRes.body,
          updated_at: new Date().toISOString(),
        })
        .eq("paymongo_payment_intent_id", payment_intent_id);
      return json({ error: firstPmError(attachRes.body) }, attachRes.status);
    }

    const pi = attachRes.body.data;
    const piStatus = pi.attributes.status as string;
    const nextAction = pi.attributes.next_action ?? null;

    // Pull payment method details to populate brand/last4/method_type
    // in the ledger so the UI can render the method on a redirect-return.
    const pmRes = await pmFetch(`/payment_methods/${payment_method_id}`);
    const pmAttrs = pmRes.body?.data?.attributes;
    const methodType = (pmAttrs?.type ?? "card") as string;
    const card       = pmAttrs?.details ?? {};
    const brand      = card.brand ?? null;
    const last4      = card.last4 ?? null;
    const billingName = pmAttrs?.billing?.name ?? null;

    // Map PayMongo status → ledger status.
    const ledgerStatus =
      piStatus === "succeeded"           ? "succeeded" :
      piStatus === "awaiting_next_action" ? "requires_action" :
      piStatus === "processing"           ? "pending" :
      piStatus === "awaiting_payment_method" ? "pending" :
      piStatus === "cancelled"            ? "cancelled" : "pending";

    await admin
      .from("payment_transactions")
      .update({
        status:          ledgerStatus,
        method_type:     methodType,
        brand,
        last4,
        billing_name:    billingName,
        payment_method_id: payment_method_record_id ?? null,
        raw_response:    pi,
        updated_at:      new Date().toISOString(),
      })
      .eq("paymongo_payment_intent_id", payment_intent_id);

    return json({
      status:            piStatus,
      next_action:       nextAction,
      payment_method_id,
    });
  } catch (err) {
    return json({ error: (err as Error).message ?? String(err) }, 500);
  }
});
