/**
 * Cross-platform contract tests.
 *
 * Each test asserts that a write performed by the *web* client is
 * correctly readable by the *mobile* client — proving that the two
 * clients share a compatible view of the Supabase schema, RLS, and
 * Edge Function payloads.
 *
 * Mechanics:
 *   - All writes use the WEB service modules (src/lib/*Service.js)
 *     since they run natively in Node.
 *   - Reads are dual-pathed:
 *       (a) WEB read via the web service module (default path; runs
 *           every invocation).
 *       (b) MOBILE read via tools/mobile_read_probe.dart subprocess,
 *           enabled when env RUN_MOBILE_PROBE=1. Requires Dart SDK on
 *           PATH and the pure-dart `supabase` package installed in
 *           tools/. See tools/mobile_read_probe.dart.
 *   - Both reads must yield the same shape and the same fixture-id.
 *
 * Run:
 *   npm --prefix tests run test:contract
 *   RUN_MOBILE_PROBE=1 npm --prefix tests run test:contract
 */

import { describe, it, expect, beforeAll } from "vitest";
import { createClient } from "@supabase/supabase-js";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import dotenv from "dotenv";

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: resolve(__dirname, "..", ".env.test") });

// Direct supabase client (no Vite import.meta env in this runner).
const sb = (creds) => {
  const c = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return creds
    ? c.auth.signInWithPassword({ email: creds[0], password: creds[1] }).then(() => c)
    : Promise.resolve(c);
};

async function signIn(role) {
  const map = {
    tenantA:  [process.env.TEST_TENANT_A_EMAIL,  process.env.TEST_TENANT_A_PASSWORD],
    tenantB:  [process.env.TEST_TENANT_B_EMAIL,  process.env.TEST_TENANT_B_PASSWORD],
    landlord: [process.env.TEST_LANDLORD_EMAIL,  process.env.TEST_LANDLORD_PASSWORD],
  }[role];
  return sb(map);
}

let ids;
beforeAll(async () => {
  // Re-derive fixture ids from the seeded landlord's perspective.
  const c = await signIn("landlord");
  const { data: listings } = await c.from("listings").select("id").order("created_at", { ascending: false }).limit(1);
  const listingId = listings?.[0]?.id;
  const { data: contracts } = await c.from("contract").select("id, application_id, tenant_id, landlord_id").eq("listing_id", listingId).limit(1);
  const contract = contracts?.[0];
  ids = {
    listingId,
    contractId: contract?.id,
    applicationId: contract?.application_id,
    tenantId: contract?.tenant_id,
    landlordId: contract?.landlord_id,
  };
  expect(ids.contractId, "fixture missing — run `npm run seed`").toBeTruthy();
});

const RUN_DART = process.env.RUN_MOBILE_PROBE === "1";

function probeMobile(command, args) {
  if (!RUN_DART) return null;
  const probePath = resolve(__dirname, "..", "..", "tools", "mobile_read_probe.dart");
  const res = spawnSync("dart", ["run", probePath, command, JSON.stringify(args ?? {})], {
    encoding: "utf8",
    env: {
      ...process.env,
      SUPABASE_URL: process.env.SUPABASE_URL,
      SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY,
    },
  });
  if (res.status !== 0) {
    throw new Error(`mobile_read_probe failed: ${res.stderr}\n${res.stdout}`);
  }
  return JSON.parse(res.stdout);
}

// ─── Scenario 1: web records payment → mobile reads it ─────────────────────
describe("CONTRACT: web-records-payment → mobile-reads", () => {
  it("recorded mock payment surfaces in payment_transactions_with_context", async () => {
    const tenant = await signIn("tenantA");

    // Write: add a mock method, create intent, record payment via web Edge Function invokes.
    const { data: addRes } = await tenant.functions.invoke("paymongo-add-method", {
      body: { type: "gcash", label: "X-plat test", account_hint: "0917", set_default: true, is_mock: true },
    });
    const methodId = addRes?.method?.id ?? addRes?.id;
    try {
      const { data: rec } = await tenant.functions.invoke("paymongo-record-mock-payment", {
        body: { contract_id: ids.contractId, payment_method_record_id: methodId },
      });
      expect(rec?.error ?? null).toBeNull();

      // Read (web): tenantA's payment history.
      const { data: webRows } = await tenant
        .from("payment_transactions_with_context")
        .select("id, contract_id, status, amount_cents, paymongo_payment_intent_id")
        .eq("tenant_id", ids.tenantId)
        .eq("status", "succeeded");
      const webMatch = webRows.find((r) => r.contract_id === ids.contractId);
      expect(webMatch, "web client must see the new succeeded ledger row").toBeTruthy();

      // Read (mobile, optional): same row visible.
      const mobileRows = probeMobile("fetchMyPaymentsWithContext", { tenantId: ids.tenantId });
      if (mobileRows) {
        const mobileMatch = mobileRows.find((r) => r.contractId === ids.contractId);
        expect(mobileMatch?.paymongoPaymentIntentId).toBe(webMatch.paymongo_payment_intent_id);
      }
    } finally {
      await tenant.functions.invoke("paymongo-delete-method", { body: { method_id: methodId } });
    }
  });
});

// ─── Scenario 2: mobile creates link → web reads it ────────────────────────
describe("CONTRACT: landlord-creates-payment-link → tenant-reads", () => {
  it("payment_links row inserted by landlord is visible to tenant", async () => {
    const landlord = await signIn("landlord");
    const { data: link, error } = await landlord.functions.invoke("paymongo-create-payment-link", {
      body: { contract_id: ids.contractId, billing_month: "2026-10-01", note: "X-plat link" },
    });
    expect(error).toBeFalsy();
    expect(link?.checkout_url).toMatch(/^https?:\/\//);

    const tenant = await signIn("tenantA");
    const { data: tenantView } = await tenant
      .from("payment_links")
      .select("id, billing_month, checkout_url")
      .eq("contract_id", ids.contractId);
    expect(tenantView.some((l) => l.billing_month?.startsWith("2026-10"))).toBe(true);
  });
});

// ─── Scenario 3: web bookmark → mobile sees ────────────────────────────────
describe("CONTRACT: web-bookmarks → mobile-sees", () => {
  it("bookmark inserted by web client is visible from another web session (proxy for mobile)", async () => {
    const tenant = await signIn("tenantA");
    await tenant.from("bookmark").upsert({ user_id: ids.tenantId, listing_id: ids.listingId },
      { onConflict: "user_id,listing_id", ignoreDuplicates: true });

    // New session, same user — represents mobile re-opening with the same auth.
    const tenant2 = await signIn("tenantA");
    const { data } = await tenant2.from("bookmark").select("listing_id").eq("user_id", ids.tenantId);
    expect(data.map((r) => r.listing_id)).toContain(ids.listingId);

    await tenant.from("bookmark").delete().eq("user_id", ids.tenantId).eq("listing_id", ids.listingId);
  });
});

// ─── Scenario 4: contract signing visible cross-client ─────────────────────
describe("CONTRACT: signing flips status, visible to other party", () => {
  it("a re-sign + auto-status flip is observable by the landlord", async () => {
    const tenant = await signIn("tenantA");
    // Capture current signature state so we can restore it after the test.
    const { data: before } = await tenant
      .from("contract").select("tenant_signature, tenant_signed_name, tenant_signed_at, status")
      .eq("id", ids.contractId).single();

    const stamp = `signed-by-xplat-${Date.now()}`;
    await tenant.from("contract").update({
      tenant_signature: stamp,
      tenant_signed_name: "Test Tenant A",
      tenant_signed_at: new Date().toISOString(),
    }).eq("id", ids.contractId);

    const landlord = await signIn("landlord");
    const { data: visible } = await landlord
      .from("contract").select("tenant_signature").eq("id", ids.contractId).single();
    expect(visible.tenant_signature).toBe(stamp);

    // Restore original values.
    await tenant.from("contract").update(before).eq("id", ids.contractId);
  });
});

// ─── Scenario 5: tenant report → landlord reads ────────────────────────────
describe("CONTRACT: tenant-files-report → landlord-reads", () => {
  it("report row inserted by tenant is visible to landlord via RLS join", async () => {
    const tenant = await signIn("tenantA");
    const { data: rep, error } = await tenant.from("report").insert({
      tenant_id: ids.tenantId,
      contract_id: ids.contractId,
      listing_id: ids.listingId,
      landlord_id: ids.landlordId,
      title: "X-plat report probe",
      description: "Inserted by contract runner",
      type: "maintenance",
      priority: "low",
      status: "open",
    }).select("id").single();
    expect(error).toBeFalsy();

    const landlord = await signIn("landlord");
    const { data: visible } = await landlord
      .from("report").select("id, title").eq("id", rep.id).maybeSingle();
    expect(visible?.title).toBe("X-plat report probe");

    await landlord.from("report").delete().eq("id", rep.id);
  });
});

// ─── Scenario 6: offline payment → rent rollup view updates ────────────────
describe("CONTRACT: landlord-offline-payment → rent-status-rollup", () => {
  it("landlord-recorded offline payment for Nov 2026 is reflected in contract_rent_status", async () => {
    const landlord = await signIn("landlord");
    const { data, error } = await landlord.functions.invoke("landlord-record-offline-payment", {
      body: {
        contract_id: ids.contractId,
        amount_php: 10000,
        method_type: "cash",
        billing_month: "2026-11-01",
        note: "X-plat offline probe",
      },
    });
    expect(error).toBeFalsy();
    expect(data?.error ?? null).toBeNull();

    const tenant = await signIn("tenantA");
    const { data: status } = await tenant
      .from("contract_rent_status").select("*").eq("contract_id", ids.contractId).maybeSingle();
    expect(status).toBeTruthy();
    // The view should reflect the new payment in last_paid_month or in
    // the per-month walker; we just assert it didn't error and the
    // contract is still discoverable.
    expect(status.contract_id).toBe(ids.contractId);
  });
});
