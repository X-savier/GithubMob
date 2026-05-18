// supabase/functions/paymongo-record-payment
//
// Called by the browser AFTER attach (and any redirect-return) resolves.
// Re-fetches the PaymentIntent from PayMongo (so we trust PayMongo, not
// the browser), upserts both the `payment` row and the
// `payment_transactions` ledger row, and flips contract.status='paid'
// and listings.status='rented'.
//
// The paymongo-webhook function performs the same writes
// asynchronously; this client-call closes the loop so the success
// page can render immediately.
//
// Request body: { contract_id: string, payment_intent_id: string }
// Response:     { ok: true } | { error: string }

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

    const { contract_id, payment_intent_id } = await req.json().catch(() => ({}));
    if (!contract_id || !payment_intent_id) {
      return json({ error: "Missing contract_id or payment_intent_id" }, 400);
    }

    const piRes = await pmFetch(`/payment_intents/${payment_intent_id}?include=payments`);
    if (!piRes.ok) return json({ error: firstPmError(piRes.body) }, piRes.status);

    const pi = piRes.body.data;
    const attrs = pi.attributes ?? {};
    if (attrs.status !== "succeeded") {
      return json({ error: `PaymentIntent status is ${attrs.status}` }, 400);
    }
    if (attrs.metadata?.contract_id !== contract_id) {
      return json({ error: "PaymentIntent / contract mismatch" }, 400);
    }
    if (attrs.metadata?.tenant_id !== user.id) {
      return json({ error: "This intent belongs to a different tenant" }, 403);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Pull method details from the first associated payment record.
    const payments = Array.isArray(attrs.payments) ? attrs.payments : [];
    const firstPayment = payments[0]?.attributes ?? {};
    const source = firstPayment.source ?? {};
    const sourceType = source.type ?? attrs.payment_method_allowed?.[0] ?? "card";
    const billingName = firstPayment.billing?.name ?? null;

    // Card brand/last4 live on the source for cards; e-wallet sources
    // expose `type` (gcash/grab_pay/etc.) as the brand.
    const brand = sourceType === "card" ? (source.brand ?? null) : sourceType;
    const last4 = sourceType === "card" ? (source.last4 ?? null) : null;

    // billing_month is non-null for recurring monthly rent PIs. When set,
    // we DO NOT flip contract.status (tenancy is already 'paid') and we
    // skip the listing-hiding side-effect for the same reason.
    const billingMonth = typeof attrs.metadata?.billing_month === "string"
      ? attrs.metadata.billing_month
      : null;
    const isMonthly = !!billingMonth;

    // Find the ledger row created at PI creation time (or the most
    // recent one for this PI) so we can link payment.payment_transaction_id.
    const { data: ledgerRow } = await admin
      .from("payment_transactions")
      .select("id")
      .eq("paymongo_payment_intent_id", payment_intent_id)
      .maybeSingle();

    const nowIso = new Date().toISOString();
    const paidAt = attrs.last_payment_error?.created_at ??
      (firstPayment.paid_at ? new Date(firstPayment.paid_at * 1000).toISOString() : nowIso);

    // Mirror the PayMongo PI id into the legacy stripe_payment_intent_id
    // column so the original NOT NULL on that column is satisfied and the
    // Flutter app (which still reads the legacy column) keeps seeing a value.
    // Matches the pattern in paymongo-record-mock-payment/index.ts.
    const { error: payErr } = await admin
      .from("payment")
      .upsert(
        {
          contract_id,
          stripe_payment_intent_id:   pi.id,
          paymongo_payment_intent_id: pi.id,
          amount_cents:               attrs.amount,
          currency:                   (attrs.currency ?? "php").toLowerCase(),
          status:                     "succeeded",
          paid_at:                    paidAt,
          method:                     brand,
          last4,
          name:                       billingName,
          payment_transaction_id:     ledgerRow?.id ?? null,
          billing_month:              billingMonth,
        },
        { onConflict: "paymongo_payment_intent_id" },
      );
    if (payErr) return json({ error: payErr.message }, 500);

    // Upsert ledger to succeeded (never downgrade if already succeeded).
    const { error: ledgerErr } = await admin
      .from("payment_transactions")
      .upsert(
        {
          contract_id,
          user_id:                    user.id,
          paymongo_payment_intent_id: pi.id,
          paymongo_payment_id:        payments[0]?.id ?? null,
          amount_cents:               attrs.amount,
          currency:                   (attrs.currency ?? "php").toLowerCase(),
          status:                     "succeeded",
          method_type:                sourceType,
          brand,
          last4,
          billing_name:               billingName,
          billing_month:              billingMonth,
          raw_response:               pi,
          updated_at:                 nowIso,
        },
        { onConflict: "paymongo_payment_intent_id" },
      );
    if (ledgerErr) return json({ error: ledgerErr.message }, 500);

    // Move-in only: flip contract → paid and listing → rented. Monthly
    // rent payments don't change either (tenancy is already active).
    if (!isMonthly) {
      const { error: cErr } = await admin
        .from("contract")
        .update({ status: "paid", updated_at: nowIso })
        .eq("id", contract_id);
      if (cErr) return json({ error: cErr.message }, 500);

      // Hide the listing from public browse and block new applies.
      const { data: contractMeta } = await admin
        .from("contract")
        .select("listing_id")
        .eq("id", contract_id)
        .maybeSingle();
      if (contractMeta?.listing_id) {
        await admin
          .from("listings")
          .update({ status: "rented", updated_at: nowIso })
          .eq("id", contractMeta.listing_id);
      }
    }

    return json({ ok: true, billingMonth });
  } catch (err) {
    return json({ error: (err as Error).message ?? String(err) }, 500);
  }
});
