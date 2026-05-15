// Shared CORS headers for browser → Edge Function calls. Allowing all
// origins is fine for a public-facing API that authenticates with a
// Supabase JWT; the JWT itself is the actual access control.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
