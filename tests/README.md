# ViewXRent Integration Test Harness

Shared test harness for the Flutter mobile app + React web app. Exercises real Supabase + real PayMongo sandbox.

## One-time setup

1. **Create the test Supabase project.** Go to https://supabase.com/dashboard, create a second project (e.g. `vxr-test`). Capture URL + anon key + service-role key.

2. **Apply schema.** The canonical app's `listings`, `listing_financials`, `application`, and `profiles` tables are not versioned in `supabase/migrations/`. Easiest path: use `pg_dump` from the dev project's schema and apply to the test project. Then run every `.sql` in `supabase/migrations/` (in the dashboard SQL editor) on top.

3. **Deploy Edge Functions** to the test project:
   ```
   supabase functions deploy --project-ref <test-ref>
   ```
   Set secrets:
   ```
   supabase secrets set PAYMONGO_SECRET_KEY=sk_test_... MOCK_PAYMENTS_ENABLED=true --project-ref <test-ref>
   ```

4. **Fill in env.**
   ```
   cp .env.test.example .env.test
   ```
   Edit `.env.test` with the test project's URL / keys.

   Also create the web-side env file with `VITE_` prefixes:
   ```
   D:\school works\vxr-web\my-react-app\.env.test
   ```
   ```
   VITE_SUPABASE_URL=...
   VITE_SUPABASE_ANON_KEY=...
   VITE_PAYMONGO_PUBLIC_KEY=...
   TEST_TENANT_A_EMAIL=...     # (Vitest setup also reads non-prefixed test-user vars)
   TEST_TENANT_A_PASSWORD=...
   TEST_TENANT_B_EMAIL=...
   TEST_TENANT_B_PASSWORD=...
   TEST_LANDLORD_EMAIL=...
   TEST_LANDLORD_PASSWORD=...
   ```

5. **Install deps.**
   ```
   cd tests
   npm install
   ```

## Running tests

```
# Seed / reset fixture data (idempotent — safe to re-run between suites).
npm --prefix tests run seed

# Cross-platform contract tests (Node, Vitest).
npm --prefix tests run test:contract

# Web service-layer tests.
cd "D:\school works\vxr-web\my-react-app"
npm run test

# Mobile service-layer tests (needs an attached Android emulator or device).
flutter test integration_test/services --dart-define-from-file=tests/.env.test.json
```

## What gets created in the test project

After `npm run seed`:

| User                | Role     | Verified |
|---------------------|----------|----------|
| tenant-a@vxr.test   | tenant   | yes      |
| tenant-b@vxr.test   | tenant   | no       |
| landlord@vxr.test   | landlord | yes      |

Plus: 1 listing + 1 listing_financials + 1 approved application + 1 fully_signed contract (₱10,000 rent / ₱10,000 deposit / ₱10,000 advance).

## Teardown

```
npm --prefix tests run teardown
```

Removes all fixture rows owned by the test users. Leaves the auth users in place (cheap to re-seed against them).
