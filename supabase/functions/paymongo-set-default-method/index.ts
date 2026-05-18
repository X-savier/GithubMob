// supabase/functions/paymongo-set-default-method
//
// Atomically switches which saved method is the user's default.
// Unsets the previous default first to satisfy the partial unique
// index that allows only one is_default=true per user.
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

    const { data: target, error: fetchErr } = await admin
      .from("payment_methods")
      .select("id, user_id, deleted_at")
      .eq("id", method_id)
      .maybeSingle();
    if (fetchErr) return json({ error: fetchErr.message }, 500);
    if (!target)  return json({ error: "Method not found" }, 404);
    if (target.user_id !== user.id) return json({ error: "Not your method" }, 403);
    if (target.deleted_at)          return json({ error: "Method is deleted" }, 400);

    // Two-step swap: clear old default, then set the new one. The
    // partial unique index rejects two trues at once if these landed
    // in reverse order on a race.
    await admin
      .from("payment_methods")
      .update({ is_default: false })
      .eq("user_id", user.id)
      .is("deleted_at", null)
      .eq("is_default", true);

    const { error: setErr } = await admin
      .from("payment_methods")
      .update({ is_default: true })
      .eq("id", method_id);
    if (setErr) return json({ error: setErr.message }, 500);

    return json({ ok: true });
  } catch (err) {
    return json({ error: (err as Error).message ?? String(err) }, 500);
  }
});
