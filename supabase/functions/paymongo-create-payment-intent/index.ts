// supabase/functions/paymongo-create-payment-intent
//
// Creates a PayMongo PaymentIntent for a contract's move-in payment.
// The amount is computed server-side from the contract row (so the
// browser cannot dictate the price) and the caller must be the tenant
// on the contract.
//
// Also inserts a `pending` row into payment_transactions so the ledger
// records the attempt before any method is attached.
//
// Request body:  { contract_id: string }
// Response:      { paymentIntentId, clientKey, amount, currency }

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

    const { contract_id } = await req.json().catch(() => ({}));
    if (!contract_id) return json({ error: "Missing contract_id" }, 400);

    const { data: contract, error: cErr } = await supabase
      .from("contract")
      .select(`
        id, status, tenant_id, landlord_id, listing_id,
        monthly_rent, security_deposit, advance_rent,
        listings ( title )
      `)
      .eq("id", contract_id)
      .maybeSingle();

    if (cErr)      return json({ error: cErr.message }, 500);
    if (!contract) return json({ error: "Contract not found" }, 404);
    if (user.id !== contract.tenant_id) {
      return json({ error: "Only the tenant on this contract can pay" }, 403);
    }
    if (contract.status !== "fully_signed") {
      return json({
        error: `Contract is not ready for payment (status=${contract.status})`,
      }, 400);
    }

    const totalPesos =
      Number(contract.monthly_rent     ?? 0) +
      Number(contract.security_deposit ?? 0) +
      Number(contract.advance_rent     ?? 0);
    const amount = Math.round(totalPesos * 100);
    if (!Number.isFinite(amount) || amount <= 0) {
      return json({ error: "Contract has no rent amount set" }, 400);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Reuse an open `pending` PI for this contract if one exists — avoids
    // creating a fresh intent on every page mount. PayMongo has no
    // server-side search like Stripe; we track open intents ourselves
    // via the payment_transactions ledger.
    const { data: openTx } = await admin
      .from("payment_transactions")
      .select("paymongo_payment_intent_id, amount_cents")
      .eq("contract_id", contract_id)
      .eq("user_id", user.id)
      .in("status", ["pending", "requires_action"])
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (openTx?.paymongo_payment_intent_id) {
      const getRes = await pmFetch(`/payment_intents/${openTx.paymongo_payment_intent_id}`);
      const piData = getRes.body?.data;
      const piStatus = piData?.attributes?.status;
      if (getRes.ok && piStatus && piStatus !== "succeeded" && piStatus !== "cancelled") {
        // Reuse — but if the amount has drifted (landlord edited
        // pricing), cancel and create a new PI with the correct total.
        if (Number(piData.attributes.amount) === amount) {
          return json({
            paymentIntentId: piData.id,
            clientKey:       piData.attributes.client_key,
            amount:          piData.attributes.amount,
            currency:        piData.attributes.currency,
          });
        }
        // Drop stale ledger row so a new pending row can take its place.
        await admin
          .from("payment_transactions")
          .update({ status: "cancelled", updated_at: new Date().toISOString() })
          .eq("paymongo_payment_intent_id", openTx.paymongo_payment_intent_id);
      }
    }

    const createRes = await pmFetch("/payment_intents", {
      method: "POST",
      body: JSON.stringify({
        data: {
          attributes: {
            amount,
            currency: "PHP",
            payment_method_allowed: ["card", "gcash", "paymaya", "grab_pay"],
            payment_method_options: {
              card: { request_three_d_secure: "any" },
            },
            capture_type: "automatic",
            description:  `ViewxRent move-in for ${contract.listings?.title ?? "rental"}`,
            metadata: {
              contract_id,
              tenant_id:   user.id,
              landlord_id: contract.landlord_id,
            },
          },
        },
      }),
    });

    if (!createRes.ok) return json({ error: firstPmError(createRes.body) }, createRes.status);

    const pi = createRes.body.data;
    const piId = pi.id as string;

    // Seed the ledger with a pending row. method_type is provisional
    // ('card' as a default placeholder) and gets overwritten by
    // paymongo-attach-payment-method once the user picks one.
    await admin.from("payment_transactions").insert({
      contract_id,
      user_id: user.id,
      paymongo_payment_intent_id: piId,
      amount_cents:  amount,
      currency:      "php",
      status:        "pending",
      method_type:   "card",
      raw_response:  pi,
    });

    return json({
      paymentIntentId: piId,
      clientKey:       pi.attributes.client_key,
      amount:          pi.attributes.amount,
      currency:        pi.attributes.currency,
    });
  } catch (err) {
    return json({ error: (err as Error).message ?? String(err) }, 500);
  }
});
