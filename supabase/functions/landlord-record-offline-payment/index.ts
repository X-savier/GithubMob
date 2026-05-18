// supabase/functions/landlord-record-offline-payment
//
// Landlord logs a payment received outside the app (cash, direct GCash
// to the landlord's wallet, bank transfer the tenant did manually, etc).
//
// Mirrors paymongo-record-mock-payment in shape, but:
//   * Auth caller must be the contract's landlord (not the tenant).
//   * Contract must be 'paid' (i.e. active tenancy) so this can't be
//     used to bypass the move-in flow.
//   * Writes payment_transactions with recorded_by = landlord.id,
//     paymongo_payment_intent_id = 'offline_<uuid>' to satisfy the
//     existing UNIQUE constraint on that column.
//   * Does NOT mutate contract.status — the tenancy is already 'paid'.
//
// Request body:
//   { contract_id: string,
//     amount_php: number,           // pesos, will be multiplied by 100
//     method_type: 'cash'|'bank_transfer'|'gcash'|'paymaya'|'grab_pay'|'offline_other',
//     billing_month?: 'YYYY-MM-01', // first of the rent month this covers
//     paid_at?: ISO string,         // defaults to now
//     note?: string }
//
// Response:
//   { ok: true, transactionId: uuid, paymentIntentId: 'offline_<uuid>' }
//   | { error: string }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { corsHeaders } from "../_shared/cors.ts";

const ALLOWED_METHODS = new Set([
  "cash", "bank_transfer", "gcash", "paymaya", "grab_pay", "offline_other",
]);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Coerce 'YYYY-MM' or 'YYYY-MM-DD' to the first-of-month date string.
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
    const {
      contract_id,
      amount_php,
      method_type,
      billing_month,
      paid_at,
      note,
    } = body ?? {};

    if (!contract_id) return json({ error: "Missing contract_id" }, 400);
    if (!ALLOWED_METHODS.has(String(method_type))) {
      return json({ error: "Invalid method_type" }, 400);
    }
    const amountPesos = Number(amount_php);
    if (!Number.isFinite(amountPesos) || amountPesos <= 0) {
      return json({ error: "amount_php must be a positive number" }, 400);
    }
    const amountCents = Math.round(amountPesos * 100);

    const billingMonth = normalizeBillingMonth(billing_month);
    if (billing_month != null && billingMonth === null) {
      return json({ error: "billing_month must be YYYY-MM or YYYY-MM-DD" }, 400);
    }

    const paidAtIso = (() => {
      if (!paid_at) return new Date().toISOString();
      const d = new Date(String(paid_at));
      return isNaN(d.getTime()) ? new Date().toISOString() : d.toISOString();
    })();

    // Authorise: caller must be the landlord on this contract, and the
    // tenancy must be active (status 'paid' or a later post-move-in state).
    const { data: contract, error: cErr } = await supabase
      .from("contract")
      .select("id, status, tenant_id, landlord_id, listing_id")
      .eq("id", contract_id)
      .maybeSingle();
    if (cErr)      return json({ error: cErr.message }, 500);
    if (!contract) return json({ error: "Contract not found" }, 404);
    if (user.id !== contract.landlord_id) {
      return json({ error: "Only the landlord on this contract can record a payment" }, 403);
    }
    if (!["paid", "terminating", "expiring", "terminated", "ended"].includes(contract.status)) {
      return json({
        error: `Cannot record payment until the move-in is settled (status=${contract.status})`,
      }, 400);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const piId = `offline_${crypto.randomUUID()}`;
    const nowIso = new Date().toISOString();

    // Insert ledger row first so payment.payment_transaction_id can FK to it.
    const { data: ledgerRow, error: ledgerErr } = await admin
      .from("payment_transactions")
      .insert({
        contract_id,
        user_id:                    contract.tenant_id,  // payment belongs to tenant
        paymongo_payment_intent_id: piId,
        paymongo_payment_id:        piId,
        amount_cents:               amountCents,
        currency:                   "php",
        status:                     "succeeded",
        method_type,
        brand:                      method_type,
        last4:                      null,
        billing_name:               null,
        recorded_by:                user.id,
        note:                       note ? String(note).slice(0, 1000) : null,
        billing_month:              billingMonth,
        raw_response:               { source: "offline", recorded_by_landlord: true },
        updated_at:                 nowIso,
      })
      .select("id")
      .single();
    if (ledgerErr) return json({ error: ledgerErr.message }, 500);

    // Mirror into `payment` table for parity with the PayMongo flow.
    // stripe_payment_intent_id is NOT NULL on legacy schema, so reuse piId.
    const { error: payErr } = await admin
      .from("payment")
      .insert({
        contract_id,
        stripe_payment_intent_id:   piId,
        paymongo_payment_intent_id: piId,
        amount_cents:               amountCents,
        currency:                   "php",
        status:                     "succeeded",
        paid_at:                    paidAtIso,
        method:                     method_type,
        last4:                      null,
        name:                       null,
        payment_transaction_id:     ledgerRow?.id ?? null,
        billing_month:              billingMonth,
      });
    if (payErr) return json({ error: payErr.message }, 500);

    return json({ ok: true, transactionId: ledgerRow?.id, paymentIntentId: piId });
  } catch (err) {
    return json({ error: (err as Error).message ?? String(err) }, 500);
  }
});
