/**
 * Idempotent seed for the ViewXRent test Supabase project.
 *
 * Creates / refreshes:
 *   - 3 auth users (tenant-a verified, tenant-b unverified, landlord verified)
 *   - 1 listing owned by landlord, with listing_financials populated
 *   - 1 approved application from tenant-a on that listing
 *   - 1 fully_signed contract linking tenant-a + landlord + listing
 *
 * Also writes `.env.test.json` next to `.env.test` — a flat JSON copy
 * the Flutter integration tests consume via --dart-define-from-file.
 *
 * Usage:
 *   npm run seed                  # seed (deletes prior test data, re-inserts)
 *   npm run seed -- --teardown    # delete only, no re-insert
 *
 * Prerequisites: the test Supabase project must have these tables already
 * (created via the Supabase Studio UI or imported via pg_dump, since the
 * canonical app does not version them in migrations):
 *   profiles, listings, listing_financials, application, contract
 * Plus all tables created by supabase/migrations/*.sql.
 */

import { createClient, SupabaseClient } from "@supabase/supabase-js";
import dotenv from "dotenv";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ENV_PATH  = resolve(__dirname, "..", ".env.test");
const JSON_PATH = resolve(__dirname, "..", ".env.test.json");

dotenv.config({ path: ENV_PATH });

const TEARDOWN_ONLY = process.argv.includes("--teardown");

// ─── env validation ─────────────────────────────────────────────────────────
const REQUIRED = [
  "SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY",
  "TEST_TENANT_A_EMAIL", "TEST_TENANT_A_PASSWORD",
  "TEST_TENANT_B_EMAIL", "TEST_TENANT_B_PASSWORD",
  "TEST_LANDLORD_EMAIL", "TEST_LANDLORD_PASSWORD",
];
for (const k of REQUIRED) {
  if (!process.env[k]) {
    console.error(`Missing env var: ${k}. Copy .env.test.example to .env.test.`);
    process.exit(1);
  }
}

const admin: SupabaseClient = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

// Stable user identifiers (email is the lookup key — admin API also lets us
// resolve them via listUsers, which is what we use for idempotency).
const USERS = [
  {
    email: process.env.TEST_TENANT_A_EMAIL!,
    password: process.env.TEST_TENANT_A_PASSWORD!,
    full_name: "Test Tenant A",
    role: "tenant",
    is_landlord: false,
    is_verified: true,
  },
  {
    email: process.env.TEST_TENANT_B_EMAIL!,
    password: process.env.TEST_TENANT_B_PASSWORD!,
    full_name: "Test Tenant B",
    role: "tenant",
    is_landlord: false,
    is_verified: false,
  },
  {
    email: process.env.TEST_LANDLORD_EMAIL!,
    password: process.env.TEST_LANDLORD_PASSWORD!,
    full_name: "Test Landlord",
    role: "landlord",
    is_landlord: true,
    is_verified: true,
  },
] as const;

interface SeededUser { id: string; email: string; }

async function findOrCreateUser(u: typeof USERS[number]): Promise<SeededUser> {
  // Admin listUsers is paginated; we filter by email locally.
  const { data: list, error: listErr } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (listErr) throw listErr;
  const existing = list.users.find((x) => x.email?.toLowerCase() === u.email.toLowerCase());
  if (existing) {
    // Refresh the password in case it changed in .env.test.
    await admin.auth.admin.updateUserById(existing.id, { password: u.password, email_confirm: true });
    return { id: existing.id, email: u.email };
  }
  const { data: created, error } = await admin.auth.admin.createUser({
    email: u.email,
    password: u.password,
    email_confirm: true,
    user_metadata: { full_name: u.full_name, role: u.role },
  });
  if (error) throw error;
  return { id: created.user!.id, email: u.email };
}

async function upsertProfile(userId: string, u: typeof USERS[number]) {
  const { error } = await admin.from("profiles").upsert({
    id: userId,
    email: u.email,
    full_name: u.full_name,
    role: u.role,
    is_landlord: u.is_landlord,
    is_verified: u.is_verified,
  }, { onConflict: "id" });
  if (error) throw new Error(`profiles upsert failed (${u.email}): ${error.message}. ` +
    `Confirm the test project has a 'profiles' table with these columns.`);
}

async function deleteFixtureData(tenantAId: string, landlordId: string) {
  // Order matters — FKs cascade from contract → application → listing,
  // but we delete narrowly by owner to avoid blowing away anything else
  // a developer happened to add to the test project.
  await admin.from("contract").delete().eq("tenant_id", tenantAId);
  await admin.from("application").delete().eq("tenant_id", tenantAId);
  // Find listings owned by the seed landlord and cascade through them.
  const { data: listings } = await admin
    .from("listings").select("id").eq("landlord_id", landlordId);
  const ids = (listings ?? []).map((r: { id: string }) => r.id);
  if (ids.length) {
    await admin.from("listing_financials").delete().in("listing_id", ids);
    await admin.from("listings").delete().in("id", ids);
  }
  await admin.from("payment_methods").delete().in("user_id", [tenantAId, landlordId]);
  await admin.from("bookmark").delete().eq("user_id", tenantAId);
}

async function seedListing(landlordId: string): Promise<string> {
  const { data, error } = await admin.from("listings").insert({
    title: "VXR Test Listing",
    description: "Deterministic listing seeded for integration tests. Do not edit by hand.",
    property_type: "apartment",
    listing_type: "lease",
    status: "active",
    cover_photo_url: null,
    landlord_id: landlordId,
  }).select("id").single();
  if (error) throw new Error(`listings insert failed: ${error.message}. ` +
    `Confirm the test project has a 'listings' table.`);
  return data.id as string;
}

async function seedFinancials(listingId: string) {
  const { error } = await admin.from("listing_financials").insert({
    listing_id: listingId,
    monthly_rent: 10000,
    security_deposit: 10000,
    advance_payment: 10000,
    payment_terms: "Monthly",
    payment_method: "PayMongo",
  });
  if (error) throw new Error(`listing_financials insert failed: ${error.message}.`);
}

async function seedApplication(listingId: string, tenantId: string, landlordId: string): Promise<string> {
  const { data, error } = await admin.from("application").insert({
    listing_id: listingId,
    tenant_id: tenantId,
    landlord_id: landlordId,
    status: "approved",
    first_name: "Test",
    last_name: "Tenant",
    email: process.env.TEST_TENANT_A_EMAIL,
    phone_number: "+639170000000",
    num_of_occupants: 1,
  }).select("id").single();
  if (error) throw new Error(`application insert failed: ${error.message}.`);
  return data.id as string;
}

async function seedContract(appId: string, listingId: string, tenantId: string, landlordId: string): Promise<string> {
  const { data, error } = await admin.from("contract").insert({
    application_id: appId,
    listing_id: listingId,
    tenant_id: tenantId,
    landlord_id: landlordId,
    listing_type: "lease",
    status: "fully_signed",
    tenant_signed_name: "Test Tenant A",
    tenant_signed_at: new Date("2026-01-01T00:00:00Z").toISOString(),
    landlord_signed_name: "Test Landlord",
    landlord_signed_at: new Date("2026-01-02T00:00:00Z").toISOString(),
    monthly_rent: 10000,
    security_deposit: 10000,
    advance_rent: 10000,
    start_date: "2026-02-01",
  }).select("id").single();
  if (error) throw new Error(`contract insert failed: ${error.message}.`);
  return data.id as string;
}

function writeDartDefineJson(payload: Record<string, string>) {
  // Flutter --dart-define-from-file expects a flat string→string JSON map.
  writeFileSync(JSON_PATH, JSON.stringify(payload, null, 2) + "\n", "utf8");
}

async function main() {
  console.log(`[seed] target: ${process.env.SUPABASE_URL}`);

  console.log("[seed] resolving test users...");
  const seeded: Record<string, SeededUser> = {};
  for (const u of USERS) {
    const s = await findOrCreateUser(u);
    seeded[u.email] = s;
    await upsertProfile(s.id, u);
    console.log(`  ✓ ${u.email} → ${s.id}`);
  }

  const tenantA  = seeded[process.env.TEST_TENANT_A_EMAIL!];
  const landlord = seeded[process.env.TEST_LANDLORD_EMAIL!];

  console.log("[seed] deleting prior fixture rows owned by test users...");
  await deleteFixtureData(tenantA.id, landlord.id);

  if (TEARDOWN_ONLY) {
    console.log("[seed] --teardown specified; skipping re-insert.");
    return;
  }

  console.log("[seed] inserting listing + financials...");
  const listingId = await seedListing(landlord.id);
  await seedFinancials(listingId);
  console.log(`  ✓ listing ${listingId}`);

  console.log("[seed] inserting application + contract...");
  const appId      = await seedApplication(listingId, tenantA.id, landlord.id);
  const contractId = await seedContract(appId, listingId, tenantA.id, landlord.id);
  console.log(`  ✓ application ${appId}`);
  console.log(`  ✓ contract    ${contractId}`);

  // Surface the IDs to test runners via the JSON twin + stdout. Tests can
  // also re-derive them at runtime by querying `landlord_id = $landlord`.
  const dartDefine = {
    SUPABASE_URL:                process.env.SUPABASE_URL!,
    SUPABASE_ANON_KEY:           process.env.SUPABASE_ANON_KEY ?? "",
    PAYMONGO_PUBLIC_KEY:         process.env.PAYMONGO_PUBLIC_KEY ?? "",
    TEST_TENANT_A_EMAIL:         process.env.TEST_TENANT_A_EMAIL!,
    TEST_TENANT_A_PASSWORD:      process.env.TEST_TENANT_A_PASSWORD!,
    TEST_TENANT_B_EMAIL:         process.env.TEST_TENANT_B_EMAIL!,
    TEST_TENANT_B_PASSWORD:      process.env.TEST_TENANT_B_PASSWORD!,
    TEST_LANDLORD_EMAIL:         process.env.TEST_LANDLORD_EMAIL!,
    TEST_LANDLORD_PASSWORD:      process.env.TEST_LANDLORD_PASSWORD!,
    TEST_TENANT_A_ID:            tenantA.id,
    TEST_LANDLORD_ID:            landlord.id,
    TEST_LISTING_ID:             listingId,
    TEST_APPLICATION_ID:         appId,
    TEST_CONTRACT_ID:            contractId,
  };
  writeDartDefineJson(dartDefine);
  console.log(`[seed] wrote ${JSON_PATH}`);

  console.log("[seed] done.");
}

main().catch((err) => {
  console.error("[seed] FAILED:", err);
  process.exit(1);
});
