// supabase/functions/paymongo-webhook
//
// Public endpoint PayMongo calls on payment lifecycle events. Acts as
// the source of truth for fulfillment so a payment lands in the
// database even if the tenant closes the browser between attach and
// the paymongo-record-payment call (common on e-wallet redirects).
//
// Deploy with:
//   supabase functions deploy paymongo-webhook --no-verify-jwt
//
// Register in PayMongo dashboard:
//   https://<project>.supabase.co/functions/v1/paymongo-webhook
//   events: payment.paid, payment.failed, payment.refunded
//
// The webhook signing secret protects the endpoint instead of a JWT.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { pmFetch, verifyWebhookSignature } from "../_shared/paymongo.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

const WEBHOOK_SECRET = Deno.env.get("PAYMONGO_WEBHOOK_SECRET") ?? "";

// Map PayMongo PI status → ledger status. Never downgrades to pending
// from a terminal state — the caller checks the existing row first.
function mapStatus(pmStatus: string): string {
  switch (pmStatus) {
    case "succeeded":             return "succeeded";
    case "awaiting_next_action":  return "requires_action";
    case "processing":            return "pending";
    case "cancelled":             return "cancelled";
    default:                      return "pending";
  }
}

async function applySucceeded(payment: any) {
  const piId       = payment.attributes?.payment_intent_id;
  if (!piId) return;
  const piRes = await pmFetch(`/payment_intents/${piId}?include=payments`);
  if (!piRes.ok) return;
  const pi    = piRes.body.data;
  const attrs = pi.attributes ?? {};
  const contractId = attrs.metadata?.contract_id;
  if (!contractId) return;

  const source     = payment.attributes?.source ?? {};
  const sourceType = source.type ?? attrs.payment_method_allowed?.[0] ?? "card";
  const billingName = payment.attributes?.billing?.name ?? null;
  const brand      = sourceType === "card" ? (source.brand ?? null) : sourceType;
  const last4      = sourceType === "card" ? (source.last4 ?? null) : null;
  const paidAt     = payment.attributes?.paid_at
    ? new Date(payment.attributes.paid_at * 1000).toISOString()
    : new Date().toISOString();

  // Idempotent: ON CONFLICT updates the same row. We DON'T downgrade
  // status, so a duplicate webhook after a manual record-payment call
  // is a no-op.
  const { data: existing } = await admin
    .from("payment")
    .select("status")
    .eq("paymongo_payment_intent_id", piId)
    .maybeSingle();
  if (existing?.status === "succeeded") {
    // Already fulfilled — skip the rest to avoid clobbering paid_at.
    return;
  }

  await admin.from("payment").upsert(
    {
      contract_id:                contractId,
      paymongo_payment_intent_id: piId,
      amount_cents:               attrs.amount,
      currency:                   (attrs.currency ?? "php").toLowerCase(),
      status:                     "succeeded",
      paid_at:                    paidAt,
      method:                     brand,
      last4,
      name:                       billingName,
    },
    { onConflict: "paymongo_payment_intent_id" },
  );

  await admin.from("payment_transactions").upsert(
    {
      contract_id:                contractId,
      user_id:                    attrs.metadata?.tenant_id,
      paymongo_payment_intent_id: piId,
      paymongo_payment_id:        payment.id,
      amount_cents:               attrs.amount,
      currency:                   (attrs.currency ?? "php").toLowerCase(),
      status:                     "succeeded",
      method_type:                sourceType,
      brand,
      last4,
      billing_name:               billingName,
      raw_response:               pi,
      updated_at:                 new Date().toISOString(),
    },
    { onConflict: "paymongo_payment_intent_id" },
  );

  await admin
    .from("contract")
    .update({ status: "paid", updated_at: new Date().toISOString() })
    .eq("id", contractId);

  const { data: contractMeta } = await admin
    .from("contract")
    .select("listing_id")
    .eq("id", contractId)
    .maybeSingle();
  if (contractMeta?.listing_id) {
    await admin
      .from("listings")
      .update({ status: "rented", updated_at: new Date().toISOString() })
      .eq("id", contractMeta.listing_id);
  }
}

async function applyFailed(payment: any) {
  const piId = payment.attributes?.payment_intent_id;
  if (!piId) return;
  const failureReason =
    payment.attributes?.failed_message ??
    payment.attributes?.last_payment_error?.message ??
    "Payment failed";

  // Don't downgrade a succeeded payment if a late `failed` webhook
  // arrives out of order.
  const { data: existingLedger } = await admin
    .from("payment_transactions")
    .select("status")
    .eq("paymongo_payment_intent_id", piId)
    .maybeSingle();
  if (existingLedger?.status === "succeeded" || existingLedger?.status === "refunded") return;

  await admin
    .from("payment_transactions")
    .update({
      status: "failed",
      failure_reason: failureReason,
      updated_at: new Date().toISOString(),
    })
    .eq("paymongo_payment_intent_id", piId);
}

async function applyRefunded(payment: any) {
  const piId = payment.attributes?.payment_intent_id;
  if (!piId) return;
  const nowIso = new Date().toISOString();
  await admin
    .from("payment_transactions")
    .update({ status: "refunded", updated_at: nowIso })
    .eq("paymongo_payment_intent_id", piId);
  await admin
    .from("payment")
    .update({ status: "refunded" })
    .eq("paymongo_payment_intent_id", piId);
}

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const raw = await req.text();
  const sig = req.headers.get("Paymongo-Signature") ?? req.headers.get("paymongo-signature");

  const verified = await verifyWebhookSignature(raw, sig, WEBHOOK_SECRET);
  if (!verified.ok) {
    return new Response(`Webhook signature failed: ${verified.reason}`, { status: 400 });
  }

  let event: any;
  try {
    event = JSON.parse(raw);
  } catch (err) {
    return new Response(`Bad JSON: ${(err as Error).message}`, { status: 400 });
  }

  try {
    const type    = event?.data?.attributes?.type;
    const payload = event?.data?.attributes?.data;
    if (!type || !payload) return new Response("ok (no event)", { status: 200 });

    if (type === "payment.paid")      await applySucceeded(payload);
    if (type === "payment.failed")    await applyFailed(payload);
    if (type === "payment.refunded")  await applyRefunded(payload);

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(`Webhook handler error: ${(err as Error).message}`, { status: 500 });
  }
});
