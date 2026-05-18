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

  // billing_month set => recurring rent (skip status flip); null => move-in.
  const billingMonth = typeof attrs.metadata?.billing_month === "string"
    ? attrs.metadata.billing_month
    : null;
  const isMonthly = !!billingMonth;

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

  // Mirror the PayMongo PI id into the legacy stripe_payment_intent_id
  // column so its original NOT NULL is satisfied on first-time inserts
  // (when the webhook beats the foreground record-payment call). The
  // mock payment function uses the same pattern.
  await admin.from("payment").upsert(
    {
      contract_id:                contractId,
      stripe_payment_intent_id:   piId,
      paymongo_payment_intent_id: piId,
      amount_cents:               attrs.amount,
      currency:                   (attrs.currency ?? "php").toLowerCase(),
      status:                     "succeeded",
      paid_at:                    paidAt,
      method:                     brand,
      last4,
      name:                       billingName,
      billing_month:              billingMonth,
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
      billing_month:              billingMonth,
      raw_response:               pi,
      updated_at:                 new Date().toISOString(),
    },
    { onConflict: "paymongo_payment_intent_id" },
  );

  // Move-in only: flip contract → paid and listing → rented. Monthly
  // rent payments don't change either (tenancy is already active).
  if (!isMonthly) {
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

// Landlord-initiated payment link was paid by the tenant. The event
// payload is the Link object (NOT a PaymentIntent), so we look up our
// payment_links row to recover the contract + billing_month context,
// then write payment + payment_transactions rows the same way as a
// normal rent payment. The link itself is marked 'paid'.
async function applyLinkPaid(link: any) {
  const linkId = link?.id as string | undefined;
  if (!linkId) return;

  // Find the matching payment_links row (created by paymongo-create-payment-link).
  const { data: linkRow } = await admin
    .from("payment_links")
    .select("id, contract_id, landlord_id, billing_month, amount_cents, status")
    .eq("paymongo_link_id", linkId)
    .maybeSingle();
  if (!linkRow) {
    // Unknown link — nothing to do. Don't 500; this can happen if the
    // landlord created a link manually in the PayMongo dashboard.
    return;
  }
  if (linkRow.status === "paid") return;

  // Find the actual payment record nested under the link payload.
  const linkPayments = Array.isArray(link?.attributes?.payments) ? link.attributes.payments : [];
  const firstPayment = linkPayments[0];
  const paymentAttrs = firstPayment?.attributes ?? {};
  const paymongoPaymentId = firstPayment?.id ?? null;
  const source     = paymentAttrs.source ?? {};
  const sourceType = source.type ?? "card";
  const billingName = paymentAttrs.billing?.name ?? null;
  const brand      = sourceType === "card" ? (source.brand ?? null) : sourceType;
  const last4      = sourceType === "card" ? (source.last4 ?? null) : null;
  const paidAt     = paymentAttrs.paid_at
    ? new Date(paymentAttrs.paid_at * 1000).toISOString()
    : new Date().toISOString();
  // No PaymentIntent for Links — use the link id as the dedup key.
  const dedupId = `link_${linkId}`;
  const amountCents = Number(paymentAttrs.amount ?? linkRow.amount_cents);
  const currency    = String(paymentAttrs.currency ?? "php").toLowerCase();
  const nowIso      = new Date().toISOString();

  // Look up tenant_id for user_id on the ledger row — link belongs to
  // contract, ledger row belongs to tenant.
  const { data: contractMeta } = await admin
    .from("contract")
    .select("tenant_id, listing_id")
    .eq("id", linkRow.contract_id)
    .maybeSingle();

  // Idempotent: skip if we already recorded this link's payment.
  const { data: existingTx } = await admin
    .from("payment_transactions")
    .select("id")
    .eq("paymongo_payment_intent_id", dedupId)
    .maybeSingle();

  let ledgerId = existingTx?.id ?? null;
  if (!existingTx) {
    const { data: insTx, error: insTxErr } = await admin
      .from("payment_transactions")
      .insert({
        contract_id:                linkRow.contract_id,
        user_id:                    contractMeta?.tenant_id,
        paymongo_payment_intent_id: dedupId,
        paymongo_payment_id:        paymongoPaymentId,
        amount_cents:               amountCents,
        currency,
        status:                     "succeeded",
        method_type:                sourceType,
        brand,
        last4,
        billing_name:               billingName,
        billing_month:              linkRow.billing_month,
        raw_response:               link,
        updated_at:                 nowIso,
      })
      .select("id")
      .maybeSingle();
    if (insTxErr) return; // bail silently; PayMongo will retry the webhook
    ledgerId = insTx?.id ?? null;
  }

  // Upsert into payment for parity with the regular flow.
  await admin.from("payment").upsert(
    {
      contract_id:                linkRow.contract_id,
      stripe_payment_intent_id:   dedupId,
      paymongo_payment_intent_id: dedupId,
      amount_cents:               amountCents,
      currency,
      status:                     "succeeded",
      paid_at:                    paidAt,
      method:                     brand,
      last4,
      name:                       billingName,
      payment_transaction_id:     ledgerId,
      billing_month:              linkRow.billing_month,
    },
    { onConflict: "paymongo_payment_intent_id" },
  );

  await admin
    .from("payment_links")
    .update({
      status:              "paid",
      paid_transaction_id: ledgerId,
      updated_at:          nowIso,
    })
    .eq("id", linkRow.id);
}

serve(async (req: Request) => {
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

    if (type === "payment.paid")       await applySucceeded(payload);
    if (type === "payment.failed")     await applyFailed(payload);
    if (type === "payment.refunded")   await applyRefunded(payload);
    if (type === "link.payment.paid")  await applyLinkPaid(payload);

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(`Webhook handler error: ${(err as Error).message}`, { status: 500 });
  }
});
