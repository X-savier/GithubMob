// supabase/functions/paymongo-record-mock-payment
//
// Synthetic payment writer for school-demo / screenshot scenarios.
// Skips PayMongo entirely: when a tenant picks a saved payment_method
// with is_mock=true and clicks Pay, this function computes the amount
// from the contract, writes a succeeded row to payment +
// payment_transactions with a synthetic 'pi_mock_<uuid>' id, and
// flips contract.status='paid' / listings.status='rented'.
//
// Gated by MOCK_PAYMENTS_ENABLED=true on the server. Refuses otherwise
// so production deployments cannot accidentally accept fake payments.
//
// Request body: { contract_id: string, payment_method_record_id: string }
// Response:     { ok: true, paymentIntentId: 'pi_mock_<uuid>' } | { error }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { corsHeaders } from "../_shared/cors.ts";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST")    return json({ error: "Method not allowed" }, 405);

  if (Deno.env.get("MOCK_PAYMENTS_ENABLED") !== "true") {
    return json({ error: "Mock payments are disabled on this server" }, 403);
  }

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

    const { contract_id, payment_method_record_id } = await req.json().catch(() => ({}));
    if (!contract_id || !payment_method_record_id) {
      return json({ error: "Missing contract_id or payment_method_record_id" }, 400);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Verify the saved method belongs to the caller and is actually mock.
    const { data: pm, error: pmErr } = await admin
      .from("payment_methods")
      .select("id, user_id, type, label, is_mock, deleted_at")
      .eq("id", payment_method_record_id)
      .maybeSingle();
    if (pmErr) return json({ error: pmErr.message }, 500);
    if (!pm || pm.deleted_at) return json({ error: "Payment method not found" }, 404);
    if (pm.user_id !== user.id) return json({ error: "Not your payment method" }, 403);
    if (!pm.is_mock) return json({ error: "Payment method is not a mock — use the real flow" }, 400);

    // Same amount validation as paymongo-create-payment-intent so a
    // mock payment cannot mis-record an amount.
    const { data: contract, error: cErr } = await supabase
      .from("contract")
      .select(`
        id, status, tenant_id, landlord_id, listing_id,
        monthly_rent, security_deposit, advance_rent
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

    const piId = `pi_mock_${crypto.randomUUID()}`;
    const nowIso = new Date().toISOString();

    // Insert ledger row first so payment.payment_transaction_id can FK to it.
    const { data: ledgerRow, error: ledgerErr } = await admin
      .from("payment_transactions")
      .insert({
        contract_id,
        user_id:                    user.id,
        payment_method_id:          pm.id,
        paymongo_payment_intent_id: piId,
        paymongo_payment_id:        piId,
        amount_cents:               amount,
        currency:                   "php",
        status:                     "succeeded",
        method_type:                pm.type,
        brand:                      pm.type,
        last4:                      null,
        billing_name:               null,
        raw_response:               { source: "mock", payment_method_label: pm.label ?? null },
        updated_at:                 nowIso,
      })
      .select("id")
      .single();
    if (ledgerErr) return json({ error: ledgerErr.message }, 500);

    const { error: payErr } = await admin
      .from("payment")
      .insert({
        contract_id,
        stripe_payment_intent_id:   piId,
        paymongo_payment_intent_id: piId,
        amount_cents:               amount,
        currency:                   "php",
        status:                     "succeeded",
        paid_at:                    nowIso,
        method:                     pm.type,
        last4:                      null,
        name:                       null,
        payment_transaction_id:     ledgerRow?.id ?? null,
      });
    if (payErr) return json({ error: payErr.message }, 500);

    const { error: cUpdErr } = await admin
      .from("contract")
      .update({ status: "paid", updated_at: nowIso })
      .eq("id", contract_id);
    if (cUpdErr) return json({ error: cUpdErr.message }, 500);

    if (contract.listing_id) {
      await admin
        .from("listings")
        .update({ status: "rented", updated_at: nowIso })
        .eq("id", contract.listing_id);
    }

    return json({ ok: true, paymentIntentId: piId });
  } catch (err) {
    return json({ error: (err as Error).message ?? String(err) }, 500);
  }
});
