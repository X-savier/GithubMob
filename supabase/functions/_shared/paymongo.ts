// supabase/functions/_shared/paymongo.ts
//
// Shared PayMongo helpers for Edge Functions:
//   * pmFetch — call PayMongo's REST API with Basic auth (server-side
//     secret key).
//   * verifyWebhookSignature — validate PayMongo's `Paymongo-Signature`
//     header (HMAC-SHA256). Test mode uses the `te=` component; live
//     mode uses `li=`.

const PAYMONGO_BASE = "https://api.paymongo.com/v1";

function basicAuth(secret: string): string {
  return "Basic " + btoa(secret + ":");
}

export async function pmFetch(path: string, init: RequestInit = {}): Promise<{
  ok: boolean;
  status: number;
  body: any;
}> {
  const sk = Deno.env.get("PAYMONGO_SECRET_KEY") ?? "";
  if (!sk) {
    return { ok: false, status: 500, body: { errors: [{ detail: "PAYMONGO_SECRET_KEY not configured" }] } };
  }
  const headers = new Headers(init.headers ?? {});
  headers.set("Authorization", basicAuth(sk));
  headers.set("Content-Type", "application/json");
  headers.set("Accept", "application/json");

  const res = await fetch(`${PAYMONGO_BASE}${path}`, { ...init, headers });
  const text = await res.text();
  let body: any = {};
  try { body = text ? JSON.parse(text) : {}; } catch { body = { raw: text }; }
  return { ok: res.ok, status: res.status, body };
}

export function firstPmError(body: any): string {
  const e = Array.isArray(body?.errors) ? body.errors[0] : null;
  return e?.detail ?? e?.code ?? "PayMongo request failed";
}

// PayMongo signs webhooks with a header like:
//   Paymongo-Signature: t=<unix>,te=<hex>,li=<hex>
// `te` is HMAC-SHA256(secret, `${t}.${rawBody}`) in test mode; `li` is
// the same in live mode. The endpoint should accept whichever matches
// the configured secret, so test-mode webhooks work without changing
// the secret when promoting to live.
function parseSignature(header: string): { t?: string; te?: string; li?: string } {
  const out: Record<string, string> = {};
  for (const part of header.split(",")) {
    const [k, v] = part.split("=").map((s) => s?.trim());
    if (k && v) out[k] = v;
  }
  return out;
}

async function hmacSha256Hex(secret: string, data: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(data));
  const bytes = new Uint8Array(sig);
  let hex = "";
  for (const b of bytes) hex += b.toString(16).padStart(2, "0");
  return hex;
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function verifyWebhookSignature(
  rawBody: string,
  sigHeader: string | null,
  secret: string,
): Promise<{ ok: true } | { ok: false; reason: string }> {
  if (!sigHeader) return { ok: false, reason: "Missing Paymongo-Signature header" };
  if (!secret)    return { ok: false, reason: "PAYMONGO_WEBHOOK_SECRET not configured" };

  const parts = parseSignature(sigHeader);
  if (!parts.t) return { ok: false, reason: "Signature header missing t=" };

  const expected = await hmacSha256Hex(secret, `${parts.t}.${rawBody}`);

  if (parts.te && timingSafeEqual(parts.te, expected)) return { ok: true };
  if (parts.li && timingSafeEqual(parts.li, expected)) return { ok: true };
  return { ok: false, reason: "Signature mismatch" };
}
