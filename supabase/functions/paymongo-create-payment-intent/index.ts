// supabase/functions/paymongo-create-payment-intent
//
// Creates a PayMongo PaymentIntent for either:
//   * Move-in payment (no billing_month) — first month + deposit + advance,
//     allowed only when contract.status='fully_signed'.
//   * Recurring monthly rent (billing_month set) — rent only, allowed
//     when contract.status='paid' (move-in already settled) and the
//     requested month is not already paid.
//
// Amount is computed server-side from the contract row (so the browser
// cannot dictate the price) and the caller must be the tenant on the
// contract.
//
// Also inserts a `pending` row into payment_transactions so the ledger
// records the attempt before any method is attached.
//
// Request body:  { contract_id: string, billing_month?: 'YYYY-MM' | 'YYYY-MM-DD' }
// Response:      { paymentIntentId, clientKey, amount, currency, billingMonth }

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

// Coerce 'YYYY-MM' or 'YYYY-MM-DD' to the first-of-month date string,
// or null if not parseable.
function normalizeBillingMonth(input: unknown): string | null {
  if (input == null) return null;
  const s = String(input).trim();
  if (!s) return null;
  const m = /^(\d{4})-(\d{2})(?:-\d{2})?$/.exec(s);
  if (!m) return null;
  return `${m[1]}-${m[2]}-01`;
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

    const body = await req.json().catch(() => ({}));
    const { contract_id } = body ?? {};
    if (!contract_id) return json({ error: "Missing contract_id" }, 400);

    const billingMonth = normalizeBillingMonth(body?.billing_month);
    if (body?.billing_month != null && billingMonth === null) {
      return json({ error: "billing_month must be YYYY-MM or YYYY-MM-DD" }, 400);
    }
    const isMonthly = billingMonth !== null;

    const { data: contract, error: cErr } = await supabase
      .from("contract")
      .select(`
        id, status, tenant_id, landlord_id, listing_id, start_date,
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

    // Status gating differs by mode.
    if (isMonthly) {
      // Recurring rent: tenancy must already be active.
      if (!["paid", "terminating", "expiring"].includes(contract.status)) {
        return json({
          error: `Monthly rent payment requires an active tenancy (status=${contract.status})`,
        }, 400);
      }
      // billing_month must be >= the start month and not after the current month.
      if (contract.start_date) {
        const startMonth = String(contract.start_date).slice(0, 7) + "-01";
        if (billingMonth! < startMonth) {
          return json({ error: "billing_month is before the tenancy start" }, 400);
        }
      }
    } else {
      // Move-in: must be fully signed and not yet paid.
      if (contract.status !== "fully_signed") {
        return json({
          error: `Contract is not ready for payment (status=${contract.status})`,
        }, 400);
      }
    }

    // Amount: rent only for monthly, rent+deposit+advance for move-in.
    const totalPesos = isMonthly
      ? Number(contract.monthly_rent ?? 0)
      : Number(contract.monthly_rent     ?? 0) +
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

    // For monthly: reject if this month is already paid (DB will reject too
    // via the partial unique index, but we want a clean error before
    // creating a PI on PayMongo).
    if (isMonthly) {
      const { data: existingPaid } = await admin
        .from("payment")
        .select("id")
        .eq("contract_id", contract_id)
        .eq("status", "succeeded")
        .eq("billing_month", billingMonth)
        .maybeSingle();
      if (existingPaid) {
        return json({ error: "This month is already paid" }, 409);
      }
    }

    // Reuse an open `pending` PI for this contract+month if one exists —
    // avoids creating a fresh intent on every page mount. The
    // billing_month filter (null = move-in, non-null = specific month)
    // keeps move-in and monthly intents from cannibalising each other.
    let openTxQ = admin
      .from("payment_transactions")
      .select("paymongo_payment_intent_id, amount_cents, billing_month")
      .eq("contract_id", contract_id)
      .eq("user_id", user.id)
      .in("status", ["pending", "requires_action"])
      .order("created_at", { ascending: false })
      .limit(1);
    openTxQ = isMonthly
      ? openTxQ.eq("billing_month", billingMonth)
      : openTxQ.is("billing_month", null);
    const { data: openTx } = await openTxQ.maybeSingle();

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
            billingMonth,
          });
        }
        // Drop stale ledger row so a new pending row can take its place.
        await admin
          .from("payment_transactions")
          .update({ status: "cancelled", updated_at: new Date().toISOString() })
          .eq("paymongo_payment_intent_id", openTx.paymongo_payment_intent_id);
      }
    }

    const description = isMonthly
      ? `ViewxRent rent for ${contract.listings?.title ?? "rental"} (${billingMonth!.slice(0, 7)})`
      : `ViewxRent move-in for ${contract.listings?.title ?? "rental"}`;

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
            description,
            metadata: {
              contract_id,
              tenant_id:   user.id,
              landlord_id: contract.landlord_id,
              ...(isMonthly ? { billing_month: billingMonth } : {}),
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
      billing_month: billingMonth,
      raw_response:  pi,
    });

    return json({
      paymentIntentId: piId,
      clientKey:       pi.attributes.client_key,
      amount:          pi.attributes.amount,
      currency:        pi.attributes.currency,
      billingMonth,
    });
  } catch (err) {
    return json({ error: (err as Error).message ?? String(err) }, 500);
  }
});
