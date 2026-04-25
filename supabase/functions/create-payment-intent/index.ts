// Supabase Edge Function: create-payment-intent
//
// Creates a Stripe PaymentIntent server-side and returns the client_secret
// to the mobile app. The Stripe SECRET key (sk_test_…) lives ONLY here as
// a Supabase secret — it must never be embedded in the Flutter app.
//
// Deploy:
//   supabase functions deploy create-payment-intent
//
// Set the secret once:
//   supabase secrets set STRIPE_SECRET_KEY=sk_test_...
//
// Request body (JSON):
//   { "amount_cents": 250000, "currency": "php", "contract_id": "..." }
//
// Response (JSON):
//   { "client_secret": "pi_..._secret_...", "payment_intent_id": "pi_..." }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!STRIPE_SECRET_KEY) {
    return new Response(
      JSON.stringify({ error: "STRIPE_SECRET_KEY not configured" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  try {
    const body = await req.json();
    const amountCents = Number(body.amount_cents);
    const currency = String(body.currency ?? "php").toLowerCase();
    const contractId = String(body.contract_id ?? "");

    if (!Number.isFinite(amountCents) || amountCents <= 0) {
      return new Response(
        JSON.stringify({ error: "amount_cents must be a positive integer" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Stripe expects application/x-www-form-urlencoded
    const form = new URLSearchParams();
    form.set("amount", String(Math.round(amountCents)));
    form.set("currency", currency);
    form.set("automatic_payment_methods[enabled]", "true");
    if (contractId) form.set("metadata[contract_id]", contractId);

    const stripeRes = await fetch("https://api.stripe.com/v1/payment_intents", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: form.toString(),
    });

    const data = await stripeRes.json();
    if (!stripeRes.ok) {
      return new Response(JSON.stringify({ error: data }), {
        status: stripeRes.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({
        client_secret: data.client_secret,
        payment_intent_id: data.id,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
