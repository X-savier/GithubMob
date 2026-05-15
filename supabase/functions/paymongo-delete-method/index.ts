// supabase/functions/paymongo-delete-method
//
// Soft-deletes a saved payment method (sets deleted_at). If the
// deleted method was the user's default, promotes the next-newest
// remaining method to default so the picker always has a preselection.
//
// Request body: { method_id: string }
// Response:     { ok: true }

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

    const { method_id } = await req.json().catch(() => ({}));
    if (!method_id) return json({ error: "Missing method_id" }, 400);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const { data: existing, error: fetchErr } = await admin
      .from("payment_methods")
      .select("id, user_id, is_default")
      .eq("id", method_id)
      .maybeSingle();

    if (fetchErr) return json({ error: fetchErr.message }, 500);
    if (!existing) return json({ error: "Method not found" }, 404);
    if (existing.user_id !== user.id) return json({ error: "Not your method" }, 403);

    const nowIso = new Date().toISOString();
    const { error: delErr } = await admin
      .from("payment_methods")
      .update({ deleted_at: nowIso, is_default: false })
      .eq("id", method_id);
    if (delErr) return json({ error: delErr.message }, 500);

    if (existing.is_default) {
      const { data: next } = await admin
        .from("payment_methods")
        .select("id")
        .eq("user_id", user.id)
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (next?.id) {
        await admin
          .from("payment_methods")
          .update({ is_default: true })
          .eq("id", next.id);
      }
    }

    return json({ ok: true });
  } catch (err) {
    return json({ error: (err as Error).message ?? String(err) }, 500);
  }
});
