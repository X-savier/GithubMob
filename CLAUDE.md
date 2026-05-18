# ViewXRent (VXR) — Project Context for Claude

## Project Overview

**ViewXRent** is a property rental platform currently built as a Flutter mobile app, with a web app integration planned for the future. The app connects tenants with landlords, supporting listing management, rental applications, contracts, payments, in-stay management, and 360° panorama property tours.

- **App Package Name**: `vxr_flutter`
- **Current Version**: 1.0.0+1
- **Platform**: Flutter (Android + iOS), targeting Dart SDK ^3.11.0
- **Backend**: Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **Payment**: PayMongo (sandbox mode — direct REST from the app for tokenization, Supabase Edge Functions for secret-key operations)
- **Maps**: Google Maps Flutter (`google_maps_flutter`)

---

## Tech Stack

### Mobile (Current)
| Layer | Technology |
|---|---|
| Framework | Flutter / Dart |
| Backend | Supabase (Auth, Database, Storage, Realtime) |
| Maps | Google Maps Flutter |
| Location | Geolocator |
| Payments | PayMongo (REST via `http`, redirect flows via `webview_flutter`, secret-key calls in Supabase Edge Functions) |
| Camera / 360° | `camerawesome`, `camera_360`, `panorama_viewer`, `opencv_dart` | *(capture is mobile-only; viewer is shared)* |
| Image Handling | `image_picker`, `file_picker`, `image`, `flutter_image_compress` |
| PDF / Contracts | `pdf`, `printing` |
| Fonts | Google Fonts |
| HTTP | `http` |
| Location Data | PSGC (Philippine Standard Geographic Code) JSON assets |

### Backend (Supabase)
- **Auth**: Email/password + Google OAuth, JWT tokens
- **Database**: PostgreSQL with RLS (Row Level Security)
- **Edge Functions**: `paymongo-create-payment-intent`, `paymongo-attach-payment-method`, `paymongo-record-payment`, `paymongo-record-mock-payment`, `paymongo-add-method`, `paymongo-delete-method`, `paymongo-set-default-method`, `paymongo-webhook` (PayMongo secret-key calls live server-side)
- **Storage**: Property images, listing contracts, panoramas

### Web (Planned)
- To be integrated with the same Supabase backend
- Should share the same database schema, auth system, and storage buckets
- Consider: Flutter Web, Next.js/React, or similar — decision pending

---

## Repository Structure

```
lib/
├── main.dart                      # Entry point, LandingPage (splash/onboarding)
├── application_view.dart          # Application overview
├── auth/
│   ├── auth_gate.dart             # StreamBuilder auth state router
│   └── auth_service.dart          # Supabase email/password + Google OAuth
├── login_screen.dart
├── signup_screen.dart
├── verification_screen.dart       # Identity/document verification flow
├── home_page.dart                 # HomeScreen (main bottom nav shell)
├── search_field.dart              # Search + Google Maps toggle view
├── filter_widget.dart             # Filter drawer (price, beds, baths, area, etc.)
├── unit_details.dart              # Property details (Details / Amenities / Location tabs)
├── favorites_screen.dart          # Bookmarked listings
├── profile_screen.dart            # User profile hub
├── profile_information_screen.dart
├── house_enlistment_screen.dart   # Landlord: enlist a property
├── manage_listing.dart            # Landlord: CRUD for listings (ManageListingScreen)
├── listing_image_manager.dart     # Upload/manage listing images
├── rental_application.dart        # Tenant: 5-step rental application form
├── my_applications_screen.dart    # Tenant: view submitted applications
├── enlistment_application.dart    # Landlord: view applicants (ApplicantsScreen / ApplicationsScreen)
├── contract_templates.dart        # Predefined contract templates
├── contract_view_screen.dart      # View/sign contracts (PDF)
├── landlord_contracts_screen.dart # Landlord: manage all contracts
├── in_stay_dashboard_screen.dart  # Tenant: in-stay hub (InStayDashboardScreen)
├── tenantmanagement_screen.dart   # Landlord: manage current tenants
├── report_management_screen.dart  # Maintenance/cleaning reports
├── conversations_screen.dart      # Chat list
├── chat_thread_screen.dart        # Chat thread (ChatThreadScreen)
├── payment_screen.dart            # Payment history & methods
├── property_data.dart             # Property model, sample data, geolocation helpers
├── psgc_service.dart              # PSGC location data service
├── psgc_location_field.dart       # Location picker widget (region/province/city/barangay)
├── panorama_capture_screen.dart   # 360° photo capture         [MOBILE ONLY]
├── panorama_manager.dart          # Manage panorama tours       [MOBILE ONLY]
├── panorama_post_processor.dart   # OpenCV post-processing      [MOBILE ONLY]
├── panorama_stitcher.dart         # Stitch captured frames      [MOBILE ONLY]
└── panorama_tour_viewer.dart      # View 360° tours (PanoramaTourViewer) [MOBILE + WEB]

supabase/
├── migrations/                    # SQL migration files
│   ├── application_module.sql
│   ├── bookmark_module.sql
│   ├── chat_module.sql
│   ├── listing_contract_module.sql
│   ├── report_module.sql
│   ├── verification_module.sql
│   └── ...
└── functions/
    ├── paymongo-create-payment-intent/   # Create a PayMongo PaymentIntent for a contract
    ├── paymongo-attach-payment-method/   # Attach a PaymentMethod to an intent (handles redirects)
    ├── paymongo-record-payment/          # Confirm + write the succeeded intent to the ledger
    ├── paymongo-record-mock-payment/     # Demo-mode payment recorder (gated by MOCK_PAYMENTS_ENABLED)
    ├── paymongo-add-method/              # Save a tokenized method for one-tap reuse
    ├── paymongo-delete-method/           # Remove a saved method
    ├── paymongo-set-default-method/      # Mark a saved method as default
    └── paymongo-webhook/                 # PayMongo webhook receiver

assets/
├── images/                        # property1–10.jpg, logo.jpg
└── psgc/                          # regions.json, provinces.json, cities.json, barangays.json
```

---

## Database Schema (Supabase Modules)

| Table / Module | Description |
|---|---|
| `profiles` | User profile, synced from Supabase Auth. Has `role` field (tenant/landlord) |
| `listings` | Property listings with location, price, amenities, etc. |
| `applications` | Rental applications submitted by tenants |
| `bookmarks` | Saved/favorited listings per user |
| `conversations` | Chat conversations between tenant and landlord |
| `messages` | Individual chat messages |
| `listing_contracts` | Lease contracts linked to listings and users |
| `reports` | Maintenance/cleaning reports submitted by tenants |
| `verification` | Identity verification documents and status |

RLS is enabled — all queries are scoped by `auth.uid()`.

---

## Authentication Flow

1. `main.dart` → `LandingPage` (splash with Get Started / Sign Up buttons)
2. `auth/auth_gate.dart` → Watches `Supabase.instance.client.auth.onAuthStateChange`
3. Authenticated → `HomeScreen` (bottom nav shell)
4. Unauthenticated → `LoginScreen` / `SignUpScreen`
5. Metadata: `full_name`, `phone` stored in `auth.users` user_metadata
6. `profiles` table synced on signup

---

## Navigation Structure

```
LandingPage
└── HomeScreen (BottomNavigationBar — 4 tabs)
    ├── [0] Home          → home_page.dart (listings feed)
    ├── [1] Search        → search_field.dart (list + Google Maps toggle)
    ├── [2] Messages      → conversations_screen.dart
    └── [3] Profile       → profile_screen.dart
```

Deep navigation from Home/Search:
- `UnitDetailsScreen` → tabs: Details / Amenities / Location
  - → `RentalApplicationScreen` (5-step form)
  - → `PanoramaTourViewer`
- Profile → `ManageListingScreen`, `PaymentScreen`, `VerificationScreen`, etc.

---

## Key Features

### Tenant-Side
- Browse and search listings with map view
- Filter by bedrooms, bathrooms, area, price, furnishing, pet policy
- View 360° panorama property tours
- Save favorite listings
- Submit 5-step rental applications
- View and sign lease contracts (PDF)
- In-stay dashboard: reports, payments, chat with landlord
- Real-time chat with landlords

### Landlord-Side
- Enlist and manage property listings (CRUD)
- Upload multiple property images
- Capture and publish 360° panorama tours *(capture: mobile only)*
- Review and approve/reject rental applications
- Generate and manage lease contracts
- Manage current tenants
- Receive and track maintenance/cleaning reports
- Receive payments via PayMongo

### Shared
- Supabase Realtime for chat
- PSGC-based location picker (Philippines: region → province → city → barangay)
- PayMongo payments (sandbox) — cards, GCash, Maya, GrabPay, bank transfer
- Identity verification flow
- Google Maps with property markers and user location

---

## Property Data Model

```dart
class Property {
  String image;        // asset path
  String title;
  String location;     // display string
  double price;        // monthly rent
  int beds;
  String baths;
  String area;         // e.g. "45 m²"
  double lat;          // latitude
  double lng;          // longitude
  double? distanceKm;  // calculated from user location
  String? label;       // "Popular", "New", "Featured"
}
```

Distance calculation uses the **Haversine formula** (no API calls). Fallback location: Dasmariñas, Cavite center (14.3270, 120.9540).

---

## Environment & Secrets

> **Note**: The following keys are present in the codebase. Rotate them before going to production.

- `SUPABASE_URL`: `https://mqsdtgvxyrvkornnifen.supabase.co`
- `SUPABASE_ANON_KEY`: stored in `main.dart` (move to `.env` or `--dart-define` before production)
- `PAYMONGO_PUBLIC_KEY`: `pk_test_…` passed via `--dart-define=PAYMONGO_PUBLIC_KEY=...` (see [dart_defines.example.json](dart_defines.example.json)); used by `lib/services/paymongo.dart` for tokenization
- `PAYMONGO_SECRET_KEY`: stored server-side as a Supabase secret; only the `paymongo-*` Edge Functions ever see it
- `MOCK_PAYMENTS_ENABLED`: optional `--dart-define` flag that surfaces the "Use mock payment" toggle on the checkout screen

---

## Build & Run Commands

```bash
# Install dependencies
flutter pub get

# Run on connected device / emulator
flutter run

# Build Android APK
flutter build apk --release

# Build iOS
flutter build ios --release

# Run tests
flutter test
```

---

## Integration Test Harness

A cross-platform integration suite lives under `tests/` (Node) plus
`integration_test/services/` (Flutter) and `tools/` (pure-Dart probe).
It exercises real Supabase + real PayMongo sandbox for both the mobile
app and the web app at `D:\school works\vxr-web\my-react-app`.

Setup + run instructions are in [tests/README.md](tests/README.md).
Short version:

```bash
# 1. One-time: create a dedicated TEST Supabase project, apply migrations,
#    deploy Edge Functions, copy tests/.env.test.example → tests/.env.test
cd tests && npm install

# 2. Seed deterministic test users + listing + contract
npm --prefix tests run seed

# 3. Mobile service-layer tests (requires emulator/device)
flutter test integration_test/services \
  --dart-define-from-file=tests/.env.test.json

# 4. Web service-layer tests (run from the web repo)
cd "D:\school works\vxr-web\my-react-app" && npm run test

# 5. Cross-platform contract tests
npm --prefix tests run test:contract
```

---

## Coding Conventions

- **State management**: Local `StatefulWidget` + `setState` (no external state manager)
- **Async**: `async/await` with `try/catch`; Supabase queries via `supabase_flutter`
- **Styling**: Material Design with custom orange gradient theme (`0xFFFF7043` → `0xFFFF8A80`)
- **Fonts**: Google Fonts (used throughout)
- **File naming**: `snake_case.dart` for all files
- **Class naming**: `PascalCase`
- **No global state library** currently (potential future consideration: Riverpod or Bloc for web)

---

## Planned: Web App Integration

The web app will share the **same Supabase project** (same auth, database, storage). Key considerations:

- **Shared backend**: No schema changes needed; add web-compatible RLS policies if required
- **Auth**: Supabase JS SDK (`@supabase/supabase-js`) on web mirrors the mobile Flutter SDK
- **Payments**: PayMongo on web — use `paymongo.js` (or direct REST calls) for tokenization; reuse the existing `paymongo-*` Supabase Edge Functions unchanged for server-side intent/method operations
- **Maps**: Replace `google_maps_flutter` with Google Maps JavaScript API or a React/Vue map library
- **360° Tours**: Three.js or Pannellum for panorama **viewing only** on web — panorama capture (`camerawesome`, `camera_360`, OpenCV stitching) is **mobile-only** and has no web equivalent
- **Real-time Chat**: Supabase Realtime channels work identically on web
- **PSGC Data**: Same JSON assets can be served statically on web
- **Contracts/PDF**: Use a web PDF library (e.g., `pdf-lib`, `react-pdf`)

Suggested web stack: **Next.js (React) + TypeScript + Supabase JS + PayMongo (REST / paymongo.js) + Tailwind CSS**

---

## Known Issues / TODOs

- Supabase URL and keys are hardcoded in `main.dart` — should use `--dart-define` or a secrets manager
- PayMongo is in sandbox mode — production keys and `paymongo-webhook` signature verification needed before launch
- The `payment` table still carries a legacy `stripe_payment_intent_id NOT NULL` column from the pre-PayMongo era; new rows dual-write to it (see `paymongo-record-mock-payment`) and reads `COALESCE` it with `paymongo_payment_intent_id`
- Some screens may still have stub/placeholder implementations
- Web app: not yet started; framework decision pending
- Consider adding a global state manager (Riverpod) when introducing the web app to share logic patterns
