// Supabase Edge Function: verify-identity
//
// Runs the AI pipeline for a verifications row:
//   1. Authenticates the caller and scopes to their user_id.
//   2. Generates short-lived signed URLs for the ID front, back, and selfie.
//   3. Calls Gemini 2.5 Flash twice — once to OCR the ID into a per-type
//      JSON schema, once to score face similarity between the ID portrait
//      and the selfie.
//   4. Cross-checks the extracted name against profiles.full_name.
//   5. Tiers the decision (approved / manual_review / rejected) and
//      writes scores + decision back to `verifications`. On approval,
//      flips profiles.is_verified.
//
// Deploy:
//   supabase functions deploy verify-identity
//
// Set secrets once:
//   supabase secrets set GEMINI_API_KEY=...
//
// Request body (JSON):
//   { "verification_id": "<uuid>" }
//
// Response (JSON):
//   {
//     "decision": "approved" | "manual_review" | "rejected",
//     "reason": "...",
//     "scores": {
//       "ocr_confidence": 0.92,
//       "face_match_score": 0.88,
//       "name_match_score": 0.95
//     },
//     "extracted": { ...id-type fields... }
//   }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

// Multimodal Gemini model used for OCR + face similarity. We use
// gemini-2.5-flash because it is the current GA multimodal flash model
// with free-tier quota (gemini-1.5-flash was retired Sept 2025).
// gemini-2.0-flash also works if you prefer the older stable build.
const GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_URL = (model: string) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ── Decision thresholds ───────────────────────────────────────────
const APPROVE_OCR = 0.85;
const APPROVE_FACE = 0.80;
const APPROVE_NAME = 0.85;
const REJECT_OCR = 0.50;
const REJECT_FACE = 0.50;
const REJECT_NAME = 0.50;

// ── Per-ID-type OCR schemas (passed to Gemini as responseSchema) ──
type IdSchema = {
  required: string[];
  properties: Record<string, { type: string; description?: string }>;
};

const ID_SCHEMAS: Record<string, IdSchema> = {
  philsys: {
    required: ["full_name", "date_of_birth", "id_number"],
    properties: {
      id_number: { type: "string", description: "PCN / PhilSys Card Number" },
      full_name: { type: "string" },
      date_of_birth: { type: "string", description: "YYYY-MM-DD" },
      sex: { type: "string" },
      address: { type: "string" },
    },
  },
  umid: {
    required: ["full_name", "date_of_birth", "id_number"],
    properties: {
      id_number: { type: "string", description: "CRN" },
      full_name: { type: "string" },
      date_of_birth: { type: "string", description: "YYYY-MM-DD" },
      sex: { type: "string" },
      address: { type: "string" },
    },
  },
  drivers_license: {
    required: ["full_name", "date_of_birth", "id_number"],
    properties: {
      id_number: { type: "string", description: "License No." },
      full_name: { type: "string" },
      date_of_birth: { type: "string", description: "YYYY-MM-DD" },
      address: { type: "string" },
      expiry_date: { type: "string" },
    },
  },
  passport: {
    required: ["full_name", "date_of_birth", "id_number"],
    properties: {
      id_number: { type: "string", description: "Passport No." },
      full_name: { type: "string" },
      nationality: { type: "string" },
      date_of_birth: { type: "string", description: "YYYY-MM-DD" },
      sex: { type: "string" },
      expiry_date: { type: "string" },
    },
  },
  postal_id: {
    required: ["full_name", "date_of_birth", "id_number"],
    properties: {
      id_number: { type: "string", description: "PRN" },
      full_name: { type: "string" },
      date_of_birth: { type: "string", description: "YYYY-MM-DD" },
      address: { type: "string" },
    },
  },
  sss: {
    required: ["full_name", "date_of_birth", "id_number"],
    properties: {
      id_number: { type: "string", description: "SSS No." },
      full_name: { type: "string" },
      date_of_birth: { type: "string", description: "YYYY-MM-DD" },
    },
  },
  prc: {
    required: ["full_name", "date_of_birth", "id_number"],
    properties: {
      id_number: { type: "string", description: "License No." },
      profession: { type: "string" },
      full_name: { type: "string" },
      date_of_birth: { type: "string", description: "YYYY-MM-DD" },
    },
  },
  voters_id: {
    required: ["full_name", "date_of_birth", "id_number"],
    properties: {
      id_number: { type: "string", description: "VIN" },
      full_name: { type: "string" },
      date_of_birth: { type: "string", description: "YYYY-MM-DD" },
      address: { type: "string" },
      precinct: { type: "string" },
    },
  },
  senior_citizen: {
    required: ["full_name", "date_of_birth", "id_number"],
    properties: {
      id_number: { type: "string", description: "OSCA No." },
      full_name: { type: "string" },
      date_of_birth: { type: "string", description: "YYYY-MM-DD" },
      address: { type: "string" },
    },
  },
  tin: {
    required: ["full_name", "date_of_birth", "id_number"],
    properties: {
      id_number: { type: "string", description: "TIN" },
      full_name: { type: "string" },
      date_of_birth: { type: "string", description: "YYYY-MM-DD" },
    },
  },
};

const ID_LABELS: Record<string, string> = {
  philsys: "PhilSys (National ID)",
  umid: "UMID",
  drivers_license: "Driver's License",
  passport: "Philippine Passport",
  postal_id: "Postal ID",
  sss: "SSS ID",
  prc: "PRC ID",
  voters_id: "Voter's ID",
  senior_citizen: "Senior Citizen ID",
  tin: "TIN ID",
};

// ── Helpers ───────────────────────────────────────────────────────

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Token-set name similarity (order-insensitive).
//
// Philippine IDs print names in many formats — "DELA CRUZ, JUAN P.",
// "Juan P. Dela Cruz", "JUAN DELA CRUZ" — so a flat string distance
// punishes word-order swaps that are not actually mismatches.
//
// Algorithm:
//   1. Normalize: strip diacritics (José → Jose), lowercase, drop honorifics
//      and suffixes (jr/sr/ii–v, dr/mr/mrs/ms/atty/engr/prof/rev/hon),
//      strip punctuation, collapse whitespace, split on spaces.
//   2. Drop single-letter tokens so middle initials don't count as words.
//   3. For each token in the *shorter* set, find the best fuzzy match
//      (normalized Levenshtein) in the *longer* set; each longer-side
//      token can only be consumed once. Tokens ≥ 0.85 similarity count as
//      a match (full credit); near-misses get half credit.
//   4. Score = coverage − extraPenalty + anchorBonus, where:
//        coverage     = sum(best matches) / shorter.length
//                       (rewards full coverage of the shorter side instead
//                       of penalising every extra middle name on the ID)
//        extraPenalty = 0.05 × min(extras, 3) — soft penalty so 1–3 extra
//                       middle/surname tokens reduce the score by 5–15 %
//        anchorBonus  = +0.10 when the first and last tokens of the shorter
//                       side both match strongly (≥ 0.90) — the classic
//                       "First Last" profile vs "First Middle Last" ID case
//      The whole thing is clamped to [0, 1].
function nameMatchScore(a: string, b: string): number {
  const tokens = (s: string): string[] => {
    const cleaned = s
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .toLowerCase()
      .replace(/\b(jr|sr|ii|iii|iv|v|dr|mr|mrs|ms|atty|engr|prof|rev|hon)\b\.?/g, "")
      .replace(/[^a-z\s]/g, " ")
      .replace(/\s+/g, " ")
      .trim();
    if (!cleaned) return [];
    return cleaned.split(" ").filter((t) => t.length > 1); // drop initials
  };
  const tokenSimilarity = (x: string, y: string): number => {
    if (!x || !y) return 0;
    if (x === y) return 1;
    const m = x.length;
    const n = y.length;
    const dp: number[][] = Array.from(
      { length: m + 1 },
      () => new Array(n + 1).fill(0),
    );
    for (let i = 0; i <= m; i++) dp[i][0] = i;
    for (let j = 0; j <= n; j++) dp[0][j] = j;
    for (let i = 1; i <= m; i++) {
      for (let j = 1; j <= n; j++) {
        const cost = x[i - 1] === y[j - 1] ? 0 : 1;
        dp[i][j] = Math.min(
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        );
      }
    }
    return Math.max(0, 1 - dp[m][n] / Math.max(m, n));
  };
  // Best similarity of `tok` against any token in `pool`, ignoring the
  // assignment-consumption rule (used only for the anchor bonus).
  const bestSimAny = (tok: string, pool: string[]): number => {
    let best = 0;
    for (const p of pool) {
      const sim = tokenSimilarity(tok, p);
      if (sim > best) best = sim;
    }
    return best;
  };

  const ta = tokens(a);
  const tb = tokens(b);
  if (ta.length === 0 || tb.length === 0) {
    console.log("[name-match]", { a, b, ta, tb, score: 0, reason: "empty" });
    return 0;
  }

  // Iterate over the shorter list; each token in the longer list can only
  // be consumed once. Sum bestSim per shorter token (with half credit for
  // sub-threshold near-misses, matching the prior behavior).
  const [shorter, longer] = ta.length <= tb.length ? [ta, tb] : [tb, ta];
  const used = new Array(longer.length).fill(false);
  let total = 0;
  for (const tok of shorter) {
    let bestIdx = -1;
    let bestSim = 0;
    for (let i = 0; i < longer.length; i++) {
      if (used[i]) continue;
      const sim = tokenSimilarity(tok, longer[i]);
      if (sim > bestSim) {
        bestSim = sim;
        bestIdx = i;
      }
    }
    if (bestIdx >= 0 && bestSim >= 0.85) {
      used[bestIdx] = true;
      total += bestSim;
    } else if (bestIdx >= 0) {
      total += bestSim * 0.5; // partial credit for near-misses
    }
  }

  // Coverage of the shorter set (perfect coverage = 1.0).
  const coverage = total / shorter.length;

  // Soft penalty for extra tokens on the longer side — 5% each up to 15%.
  const extras = longer.length - shorter.length;
  const extraPenalty = 0.05 * Math.min(Math.max(extras, 0), 3);

  // Anchor bonus: if the first AND last tokens of the shorter side both
  // strongly match SOME token in the longer side, the names are almost
  // certainly the same person (just one side carries a middle name).
  const firstSim = bestSimAny(shorter[0], longer);
  const lastSim  = bestSimAny(shorter[shorter.length - 1], longer);
  const anchorBonus = firstSim >= 0.90 && lastSim >= 0.90 ? 0.10 : 0;

  const score = Math.max(0, Math.min(1, coverage - extraPenalty + anchorBonus));
  console.log("[name-match]", {
    a, b, ta, tb,
    coverage: Number(coverage.toFixed(3)),
    extraPenalty: Number(extraPenalty.toFixed(3)),
    anchorBonus,
    firstSim: Number(firstSim.toFixed(3)),
    lastSim:  Number(lastSim.toFixed(3)),
    score: Number(score.toFixed(3)),
  });
  return score;
}

async function fetchAsBase64(url: string): Promise<{ data: string; mime: string }> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to fetch image (${res.status})`);
  const mime = res.headers.get("content-type") ?? "image/jpeg";
  const buf = new Uint8Array(await res.arrayBuffer());
  // base64-encode in chunks to avoid stack overflow on large images
  let binary = "";
  const CHUNK = 0x8000;
  for (let i = 0; i < buf.length; i += CHUNK) {
    binary += String.fromCharCode(...buf.subarray(i, i + CHUNK));
  }
  return { data: btoa(binary), mime };
}

type GeminiPart =
  | { text: string }
  | { inline_data: { mime_type: string; data: string } };

async function callGemini(
  parts: GeminiPart[],
  responseSchema?: Record<string, unknown>,
): Promise<unknown> {
  const body: Record<string, unknown> = {
    contents: [{ role: "user", parts }],
  };
  if (responseSchema) {
    body.generationConfig = {
      responseMimeType: "application/json",
      responseSchema,
    };
  }
  const res = await fetch(GEMINI_URL(GEMINI_MODEL), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini ${res.status}: ${errText}`);
  }
  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  if (!text) throw new Error("Gemini returned empty response");
  try {
    return JSON.parse(text);
  } catch {
    // The face-similarity prompt may return non-JSON if the schema is
    // omitted; the caller checks for that.
    return text;
  }
}

function buildOcrSchema(idType: string) {
  const fields = ID_SCHEMAS[idType] ?? ID_SCHEMAS.umid;
  return {
    type: "object",
    required: [...fields.required, "ocr_confidence", "is_valid_id"],
    properties: {
      ...fields.properties,
      ocr_confidence: {
        type: "number",
        description:
          "0.0–1.0, your overall confidence the fields above were read correctly.",
      },
      is_valid_id: {
        type: "boolean",
        description:
          "True only if the image is clearly a Philippine government-issued " +
          ID_LABELS[idType] +
          " (or close equivalent). False for non-ID images, screenshots of IDs, or other ID types.",
      },
      notes: {
        type: "string",
        description: "Optional: short note about anything unusual or unclear.",
      },
    },
  };
}

const FACE_MATCH_SCHEMA = {
  type: "object",
  required: ["face_match_score", "verdict"],
  properties: {
    face_match_score: {
      type: "number",
      description: "0.0–1.0 similarity between the ID portrait and the selfie.",
    },
    verdict: {
      type: "string",
      description: "One of: same_person, different, unsure",
    },
    notes: { type: "string" },
  },
};

// ── Main ──────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return jsonResponse({ error: "Supabase env not configured" }, 500);
  }
  if (!GEMINI_API_KEY) {
    return jsonResponse({ error: "GEMINI_API_KEY not configured" }, 500);
  }

  // Service-role client — needed for storage signed URLs + privileged updates.
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  // Resolve caller from JWT.
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return jsonResponse({ error: "Missing auth token" }, 401);
  const { data: userRes, error: userErr } = await admin.auth.getUser(token);
  if (userErr || !userRes?.user) {
    return jsonResponse({ error: "Invalid auth token" }, 401);
  }
  const userId = userRes.user.id;

  let verificationId = "";
  try {
    const body = await req.json();
    verificationId = String(body.verification_id ?? "");
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }
  if (!verificationId) {
    return jsonResponse({ error: "verification_id required" }, 400);
  }

  try {
    // 1. Load the verifications row, scoped to this user.
    const { data: row, error: rowErr } = await admin
      .from("verifications")
      .select("*")
      .eq("id", verificationId)
      .eq("user_id", userId)
      .maybeSingle();
    if (rowErr) throw rowErr;
    if (!row) return jsonResponse({ error: "Verification not found" }, 404);
    if (row.decision !== "pending") {
      return jsonResponse({
        decision: row.decision,
        reason: row.decision_reason,
        scores: {
          ocr_confidence: row.ocr_confidence,
          face_match_score: row.face_match_score,
          name_match_score: row.name_match_score,
        },
      });
    }

    // 2. Generate signed URLs (5 min) for each image.
    const sign = async (path: string | null): Promise<string | null> => {
      if (!path) return null;
      const { data, error } = await admin.storage
        .from("verifications")
        .createSignedUrl(path, 300);
      if (error) throw error;
      return data.signedUrl;
    };
    const frontUrl = await sign(row.id_front_path);
    const backUrl = await sign(row.id_back_path);
    const selfieUrl = await sign(row.selfie_path);
    if (!frontUrl || !selfieUrl) {
      throw new Error("Could not sign storage URLs");
    }

    const [front, back, selfie] = await Promise.all([
      fetchAsBase64(frontUrl),
      backUrl ? fetchAsBase64(backUrl) : Promise.resolve(null),
      fetchAsBase64(selfieUrl),
    ]);

    // 3. OCR call.
    const idLabel = ID_LABELS[row.id_type] ?? row.id_type;
    const ocrParts: GeminiPart[] = [
      {
        text:
          `You are an OCR + ID verification model. The image(s) below are ` +
          `from a Philippine government-issued ${idLabel}. ` +
          `Extract the structured fields per the schema. Set ocr_confidence ` +
          `low if any field was hard to read or guessed. Set is_valid_id=false ` +
          `if the image is not actually a real ${idLabel}. ` +
          `Return dates in strict YYYY-MM-DD form.`,
      },
      { inline_data: { mime_type: front.mime, data: front.data } },
    ];
    if (back) {
      ocrParts.push({ inline_data: { mime_type: back.mime, data: back.data } });
    }
    const ocrSchema = buildOcrSchema(row.id_type);
    const ocrResultRaw = await callGemini(ocrParts, ocrSchema);
    const ocr = (typeof ocrResultRaw === "object" && ocrResultRaw !== null
      ? ocrResultRaw
      : {}) as Record<string, unknown>;

    const ocrConfidence = Number(ocr.ocr_confidence ?? 0);
    const isValidId = Boolean(ocr.is_valid_id);
    const extractedName = String(ocr.full_name ?? "");
    const extractedIdNumber = String(ocr.id_number ?? "");
    const extractedDob = String(ocr.date_of_birth ?? "");

    // 4. Face-match call.
    const faceParts: GeminiPart[] = [
      {
        text:
          `Compare the person in the first image (the ID document portrait) ` +
          `to the person in the second image (a live selfie). Return a ` +
          `face_match_score from 0.0 to 1.0 and a verdict (same_person, ` +
          `different, or unsure). Account for ID-photo age, lighting, and ` +
          `facial hair changes. Be strict — do not score above 0.8 unless ` +
          `you are confident it is the same individual.`,
      },
      { inline_data: { mime_type: front.mime, data: front.data } },
      { inline_data: { mime_type: selfie.mime, data: selfie.data } },
    ];
    const faceResultRaw = await callGemini(faceParts, FACE_MATCH_SCHEMA);
    const face = (typeof faceResultRaw === "object" && faceResultRaw !== null
      ? faceResultRaw
      : {}) as Record<string, unknown>;
    const faceMatchScore = Number(face.face_match_score ?? 0);
    const faceVerdict = String(face.verdict ?? "unsure");

    // 5. Name cross-check vs profile.full_name.
    const { data: profile } = await admin
      .from("profiles")
      .select("full_name")
      .eq("id", userId)
      .maybeSingle();
    const profileName = String(profile?.full_name ?? "");
    const nameScore = nameMatchScore(profileName, extractedName);

    // 6. Tiered decision.
    let decision: "approved" | "manual_review" | "rejected";
    let reason = "";

    if (!isValidId) {
      decision = "rejected";
      reason = `The image does not appear to be a valid ${idLabel}.`;
    } else if (
      ocrConfidence < REJECT_OCR ||
      faceMatchScore < REJECT_FACE ||
      nameScore < REJECT_NAME ||
      faceVerdict === "different"
    ) {
      decision = "rejected";
      const parts: string[] = [];
      if (ocrConfidence < REJECT_OCR) parts.push("ID details could not be read clearly");
      if (faceMatchScore < REJECT_FACE || faceVerdict === "different") {
        parts.push("the selfie does not match the ID photo");
      }
      if (nameScore < REJECT_NAME) {
        parts.push("the name on the ID does not match your profile");
      }
      reason = parts.length
        ? `We couldn't approve this submission: ${parts.join(", ")}.`
        : "Verification did not meet our automated thresholds.";
    } else if (
      ocrConfidence >= APPROVE_OCR &&
      faceMatchScore >= APPROVE_FACE &&
      nameScore >= APPROVE_NAME &&
      faceVerdict === "same_person"
    ) {
      decision = "approved";
      reason = "All checks passed.";
    } else {
      decision = "manual_review";
      reason = "Submission needs a quick admin review before approval.";
    }

    // 7. Persist results.
    const updatePayload: Record<string, unknown> = {
      ocr_data: ocr,
      extracted_name: extractedName || null,
      extracted_id_number: extractedIdNumber || null,
      extracted_dob: /^\d{4}-\d{2}-\d{2}$/.test(extractedDob) ? extractedDob : null,
      face_match_score: Number.isFinite(faceMatchScore) ? faceMatchScore : null,
      ocr_confidence: Number.isFinite(ocrConfidence) ? ocrConfidence : null,
      name_match_score: Number.isFinite(nameScore) ? nameScore : null,
      decision,
      decision_reason: reason,
      processed_at: new Date().toISOString(),
    };
    const { error: updErr } = await admin
      .from("verifications")
      .update(updatePayload)
      .eq("id", verificationId);
    if (updErr) throw updErr;

    const profilePatch: Record<string, unknown> = {
      verification_id_type: row.id_type,
      verification_decision: decision,
      verification_processed_at: updatePayload.processed_at,
      verification_rejection_reason: decision === "rejected" ? reason : null,
    };
    if (decision === "approved") profilePatch.is_verified = true;
    await admin.from("profiles").update(profilePatch).eq("id", userId);

    return jsonResponse({
      decision,
      reason,
      scores: {
        ocr_confidence: ocrConfidence,
        face_match_score: faceMatchScore,
        name_match_score: nameScore,
      },
      extracted: {
        name: extractedName,
        id_number: extractedIdNumber,
        date_of_birth: extractedDob,
      },
    });
  } catch (e) {
    // Best-effort: mark the row as manual_review with the error so the user
    // isn't left in 'pending' indefinitely.
    try {
      await admin
        .from("verifications")
        .update({
          decision: "manual_review",
          decision_reason: `Processing error: ${String(e)}`,
          processed_at: new Date().toISOString(),
        })
        .eq("id", verificationId);
    } catch (_) {
      // swallow
    }
    return jsonResponse({ error: String(e) }, 500);
  }
});
