// supabase/functions/paymongo-create-payment-link
//
// Landlord-initiated checkout: create a PayMongo Link the tenant can
// pay from any device. The link is for a single (contract, billing_month)
// and the amount is computed server-side from contract.monthly_rent so
// the browser can't dictate the price.
//
// When the tenant pays the link, PayMongo emits `link.payment.paid`,
// which the paymongo-webhook handler picks up and records as a normal
// rent payment (with billing_month populated from the link row).
//
// Request body: { contract_id: string, billing_month: 'YYYY-MM' | 'YYYY-MM-DD',
//                 note?: string, expires_at?: ISO string }
// Response:     { ok: true, link_id, checkout_url, expires_at } | { error }

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

function normalizeBillingMonth(input: unknown): string | null {
  if (input == null) return null;
  const s = String(input).trim();
  if (!s) return null;
  const m = /^(\d{4})-(\d{2})(?:-\d{2})?$/.exec(s);
  if (!m) return null;
  return `${m[1]}-${m[2]}-01`;
}

serve(async (req: Request) => {
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
    const { contract_id, note, expires_at } = body ?? {};
    if (!contract_id) return json({ error: "Missing contract_id" }, 400);

    const billingMonth = normalizeBillingMonth(body?.billing_month);
    if (!billingMonth) {
      return json({ error: "billing_month is required (YYYY-MM or YYYY-MM-DD)" }, 400);
    }

    const { data: contract, error: cErr } = await supabase
      .from("contract")
      .select("id, status, tenant_id, landlord_id, listing_id, monthly_rent, listings ( title )")
      .eq("id", contract_id)
      .maybeSingle();
    if (cErr)      return json({ error: cErr.message }, 500);
    if (!contract) return json({ error: "Contract not found" }, 404);
    if (user.id !== contract.landlord_id) {
      return json({ error: "Only the landlord on this contract can send payment links" }, 403);
    }
    if (!["paid", "terminating", "expiring"].includes(contract.status)) {
      return json({
        error: `Cannot create a payment link until the tenancy is active (status=${contract.status})`,
      }, 400);
    }

    const amountCents = Math.round(Number(contract.monthly_rent ?? 0) * 100);
    if (!Number.isFinite(amountCents) || amountCents <= 0) {
      return json({ error: "Contract has no rent amount set" }, 400);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Reject if this month is already paid OR if an open link already exists.
    const { data: alreadyPaid } = await admin
      .from("payment")
      .select("id")
      .eq("contract_id", contract_id)
      .eq("status", "succeeded")
      .eq("billing_month", billingMonth)
      .maybeSingle();
    if (alreadyPaid) return json({ error: "This month is already paid" }, 409);

    const { data: openLink } = await admin
      .from("payment_links")
      .select("id, checkout_url, paymongo_link_id, expires_at")
      .eq("contract_id", contract_id)
      .eq("billing_month", billingMonth)
      .eq("status", "pending")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (openLink) {
      // Reuse — don't burn a fresh PayMongo Link for the same month.
      return json({
        ok: true,
        link_id:      openLink.paymongo_link_id,
        checkout_url: openLink.checkout_url,
        expires_at:   openLink.expires_at,
        reused:       true,
      });
    }

    // Create PayMongo Link.
    const description = `ViewxRent rent for ${contract.listings?.title ?? "rental"} (${billingMonth.slice(0, 7)})`;
    const createRes = await pmFetch("/links", {
      method: "POST",
      body: JSON.stringify({
        data: {
          attributes: {
            amount:      amountCents,
            description,
            remarks:     note ? String(note).slice(0, 500) : undefined,
          },
        },
      }),
    });
    if (!createRes.ok) {
      return json({ error: firstPmError(createRes.body) }, createRes.status);
    }
    const link    = createRes.body.data;
    const linkId  = link?.id as string | undefined;
    const linkUrl = link?.attributes?.checkout_url as string | undefined;
    if (!linkId || !linkUrl) {
      return json({ error: "PayMongo returned no link id / url" }, 500);
    }

    const expiresAtIso = expires_at && !isNaN(new Date(String(expires_at)).getTime())
      ? new Date(String(expires_at)).toISOString()
      : null;

    const { error: insErr } = await admin
      .from("payment_links")
      .insert({
        contract_id,
        landlord_id:      user.id,
        billing_month:    billingMonth,
        amount_cents:     amountCents,
        paymongo_link_id: linkId,
        checkout_url:     linkUrl,
        status:           "pending",
        note:             note ? String(note).slice(0, 500) : null,
        expires_at:       expiresAtIso,
      });
    if (insErr) return json({ error: insErr.message }, 500);

    return json({
      ok: true,
      link_id:      linkId,
      checkout_url: linkUrl,
      expires_at:   expiresAtIso,
      reused:       false,
    });
  } catch (err) {
    return json({ error: (err as Error).message ?? String(err) }, 500);
  }
});
