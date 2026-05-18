# Level-1 Data Flow Diagram — ViewXRent (VXR) Mobile Application

*Prepared for academic defense*

| Field | Value |
|---|---|
| Document type | Level-1 Data Flow Diagram (textual specification + narration script) |
| System | ViewXRent (VXR) — property rental platform |
| Application | Flutter mobile app (`vxr_flutter` v1.0.0+1) |
| Backend | Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions) + PayMongo sandbox |
| Date | 2026-05-18 |
| Author | _________________________ |

## Abstract

This document presents the **Level-1 Data Flow Diagram (DFD)** of the ViewXRent mobile application. A Level-1 DFD decomposes the single high-level "VXR System" process shown in a context (Level-0) diagram into its major subsystems, identifies the data stores that persist between them, and traces the data that flows among external actors, processes, and stores. The diagram is intentionally limited to Level 1: it is granular enough to expose every architecturally significant subsystem (authentication, listings, applications, contracts, payments, messaging, in-stay management, panorama tours, identity verification) without descending into per-screen or per-function detail, which would belong to Level-2 sub-diagrams. The document is organised into nine sections — notation legend, system boundary, external entities, processes, data stores, a per-process textual DFD, a numbered flow catalogue, and a defense-ready explanation script — so that each section can be reviewed independently by the panel.

---

## 1. DFD Notation Legend (Gane–Sarson Convention)

| Symbol | Meaning | Example in this DFD |
|---|---|---|
| Rounded rectangle | **Process** — a transformation of incoming data into outgoing data, numbered hierarchically (1.0, 2.0, …) | `1.0 Authentication & Profile` |
| Square | **External Entity** — an actor or external system that lies outside the boundary; sources or sinks of data | `E1 Tenant`, `E3 PayMongo` |
| Open rectangle (two parallel lines) | **Data Store** — persisted data the system reads from or writes to, labelled `D1, D2, …` | `D1 profiles`, `D7 payment` |
| Labeled arrow | **Data Flow** — the movement of a specific named piece of data; arrowhead shows direction | `F-01 signup credentials →` |

The diagram follows the Gane–Sarson convention as commonly adopted in Philippine undergraduate Information Technology / Computer Science thesis defenses.

---

## 2. System Scope and Boundary

The system under study is the **ViewXRent mobile application together with its Supabase backend** (database, storage buckets, and Edge Functions). Everything implemented by the project team is considered **inside** the boundary. The following are **outside** the boundary and are therefore represented as external entities:

- The end users — tenants and landlords — who interact with the app through its UI.
- **PayMongo**, the third-party payment gateway used to tokenise payment instruments, create payment intents, generate checkout links, and deliver webhook events.
- The **Google Maps Platform**, used for map tiles, geocoding, and reverse geocoding inside the search and property-detail screens.
- **Gemini 2.5 Flash** (Google AI), invoked server-side by the `verify-identity` Edge Function to perform optical character recognition of submitted government IDs and to score the similarity of a selfie against the ID portrait.
- The **Supabase Auth federated provider** (Google OAuth), which mediates Google sign-in. (Supabase Auth as a whole is *inside* the boundary; only the Google OAuth provider it federates with is external.)

The **PSGC (Philippine Standard Geographic Code)** dataset is bundled as static JSON inside the application package (`assets/psgc/*.json`); because no network call is made to obtain it, it is treated as an **internal** asset, not an external entity.

A separate Level-0 (context) diagram would show the entire system as a single "VXR System" process with arrows to and from each of the six external entities above. This Level-1 diagram refines that single process into the ten subsystems enumerated below.

---

## 3. External Entities

| Code | Entity | Role in the system |
|---|---|---|
| E1 | Tenant user | Browses listings, books, applies, signs contracts, pays rent, chats, submits reports |
| E2 | Landlord user | Enlists property, reviews applications, signs contracts, receives payments, manages tenants and listings |
| E3 | PayMongo | External payment gateway; processes cards, e-wallets (GCash, Maya, GrabPay), payment links, and delivers webhook events |
| E4 | Google Maps API | Returns map tiles and geocoding results to the search and property-detail screens |
| E5 | Gemini 2.5 Flash (Google AI) | OCR of government IDs and face-match scoring during identity verification |
| E6 | Google OAuth provider | Federated sign-in authority used by Supabase Auth |

---

## 4. Major Processes (Level 1)

| # | Process | Primary screen and service files | Brief purpose |
|---|---|---|---|
| 1.0 | Authentication & Profile | [lib/login_screen.dart](../../lib/login_screen.dart), [lib/signup_screen.dart](../../lib/signup_screen.dart), [lib/profile_screen.dart](../../lib/profile_screen.dart), [lib/profile_information_screen.dart](../../lib/profile_information_screen.dart), [lib/auth/auth_service.dart](../../lib/auth/auth_service.dart), [lib/auth/auth_gate.dart](../../lib/auth/auth_gate.dart) | Sign-up, sign-in, OAuth, password reset, profile editing |
| 2.0 | Identity Verification | [lib/verification_screen.dart](../../lib/verification_screen.dart), Edge Function `verify-identity` | Tenant/landlord submits ID front, ID back, and selfie; Gemini decides approve / manual review / reject |
| 3.0 | Listing Discovery (browse, search, filter, map) | [lib/home_page.dart](../../lib/home_page.dart), [lib/search_field.dart](../../lib/search_field.dart), [lib/filter_widget.dart](../../lib/filter_widget.dart), [lib/unit_details.dart](../../lib/unit_details.dart), [lib/property_data.dart](../../lib/property_data.dart) | Listing feed, search, filter, map view, property details, embedded 360° tour viewer |
| 4.0 | Bookmarks | [lib/favorites_screen.dart](../../lib/favorites_screen.dart) | Save and unsave listings |
| 5.0 | Rental Application | [lib/rental_application.dart](../../lib/rental_application.dart), [lib/my_applications_screen.dart](../../lib/my_applications_screen.dart), [lib/enlistment_application.dart](../../lib/enlistment_application.dart) | Tenant submits 5-step form; landlord reviews and decides |
| 6.0 | Contract Management | [lib/contract_view_screen.dart](../../lib/contract_view_screen.dart), [lib/landlord_contracts_screen.dart](../../lib/landlord_contracts_screen.dart), [lib/contract_templates.dart](../../lib/contract_templates.dart) | Generate the lease PDF, run the dual-signing workflow, store the signed PDF |
| 7.0 | Payments | [lib/contract_payment_screen.dart](../../lib/contract_payment_screen.dart), [lib/payment_screen.dart](../../lib/payment_screen.dart), [lib/services/payments_service.dart](../../lib/services/payments_service.dart), [lib/services/paymongo.dart](../../lib/services/paymongo.dart), Edge Functions `paymongo-create-payment-intent`, `paymongo-attach-payment-method`, `paymongo-record-payment`, `paymongo-record-mock-payment`, `paymongo-add-method`, `paymongo-delete-method`, `paymongo-set-default-method`, `paymongo-webhook`, `paymongo-create-payment-link`, `landlord-record-offline-payment` | Move-in payment, monthly rent, payment-link checkout, offline payment recording, saved methods, webhook reconciliation |
| 8.0 | Messaging (Realtime Chat) | [lib/conversations_screen.dart](../../lib/conversations_screen.dart), [lib/chat_thread_screen.dart](../../lib/chat_thread_screen.dart) | Per-listing tenant ↔ landlord chat |
| 9.0 | In-Stay Management & Reports | [lib/in_stay_dashboard_screen.dart](../../lib/in_stay_dashboard_screen.dart), [lib/report_management_screen.dart](../../lib/report_management_screen.dart), [lib/tenantmanagement_screen.dart](../../lib/tenantmanagement_screen.dart) | Tenant dashboard, maintenance / cleaning / noise reports, landlord tenant management |
| 10.0 | Listing & Tour Management (Landlord) | [lib/house_enlistment_screen.dart](../../lib/house_enlistment_screen.dart), [lib/manage_listing.dart](../../lib/manage_listing.dart), [lib/listing_image_manager.dart](../../lib/listing_image_manager.dart), [lib/panorama_capture_screen.dart](../../lib/panorama_capture_screen.dart), [lib/panorama_manager.dart](../../lib/panorama_manager.dart), [lib/panorama_stitcher.dart](../../lib/panorama_stitcher.dart), [lib/panorama_post_processor.dart](../../lib/panorama_post_processor.dart), [lib/panorama_tour_viewer.dart](../../lib/panorama_tour_viewer.dart) | Create and edit listings, upload photos, capture and publish 360° panoramas |

---

## 5. Data Stores

| Code | Store | Backing | Purpose |
|---|---|---|---|
| D1 | profiles | Supabase table | User profile, role (`tenant` / `landlord`), `is_verified`, contact information |
| D2 | listings | Supabase table | Property records: title, price, location, amenities, status |
| D3 | listing_image | Supabase table + `listing-images` and `panoramas` Storage buckets | Photo and panorama URLs with sort order and cover flag |
| D4 | bookmark | Supabase table | Per-user saved listings |
| D5 | application | Supabase table | Rental applications, with status `submitted → approved / rejected` |
| D6 | contract | Supabase table + `listing-contracts` Storage bucket | Lease records with dual-signature fields, status workflow `awaiting_tenant → awaiting_landlord → fully_signed → paid → terminating / expiring → terminated / ended` |
| D7 | payment | Supabase table | Historical succeeded payments (one per `billing_month` per contract) |
| D8 | payment_transactions | Supabase table | Per-attempt ledger; statuses `pending / requires_action / succeeded / failed / refunded / cancelled` |
| D9 | payment_methods | Supabase table | Saved e-wallet shortcuts (GCash, Maya, GrabPay, bank transfer) with `is_default` and `is_mock` flags |
| D10 | payment_links | Supabase table | Landlord-generated PayMongo checkout links, one per (contract, billing_month) |
| D11 | conversation | Supabase table | Chat rooms, unique per (listing, tenant, landlord), with last-message metadata |
| D12 | message | Supabase table, Realtime-enabled | Individual chat messages |
| D13 | report | Supabase table | In-stay maintenance, cleaning, noise, amenity, and other reports |
| D14 | verifications | Supabase table + `verifications` Storage bucket | Identity-verification submissions, OCR scores, face-match scores, decisions |
| D15 | notification | Supabase table | Audit and push-notification log |

---

## 6. Textual Level-1 DFD (Per Process)

Each subsection lists, for the process identified, every inbound flow, every outbound flow, the data stores read and written, and any internal trigger that hands control to another process. Flow IDs reference the master catalogue in Section 7.

### Process 1.0 — Authentication & Profile

- **Inbound from E1 Tenant / E2 Landlord:** signup or sign-in credentials (`email`, `password`, `full_name`, `phone`, `role`); profile-edit payloads.
- **Inbound from E6 Google OAuth:** federated `id_token` after consent screen.
- **Outbound to E1 / E2:** session JWT, profile view payload, password-reset email confirmation.
- **Outbound to E6 Google OAuth:** OAuth authorisation request.
- **Reads:** D1 profiles.
- **Writes:** D1 profiles (insert on signup, update on edit).
- **Flows:** F-01 through F-08.

### Process 2.0 — Identity Verification

- **Inbound from E1 / E2:** government ID front image, ID back image, selfie image.
- **Outbound to E5 Gemini:** OCR and face-match request containing the three images.
- **Inbound from E5 Gemini:** decision (`approved` / `manual_review` / `rejected`), OCR-extracted fields, face-match score, OCR confidence score.
- **Outbound to E1 / E2:** verification status banner on profile.
- **Reads:** D1 profiles.
- **Writes:** D14 verifications (file upload to Storage, then row insert with decision); D1 profiles (`is_verified=true` on approval).
- **Flows:** F-09 through F-14.

### Process 3.0 — Listing Discovery

- **Inbound from E1 Tenant:** search query, filter parameters (beds, baths, area, price, furnishing, pet policy), map viewport.
- **Outbound to E4 Google Maps:** tile and geocode requests.
- **Inbound from E4 Google Maps:** map tiles, geocoding results.
- **Outbound to E1 Tenant:** filtered listing feed (with Haversine-computed distance from the device location, performed locally), property-detail view, embedded 360° tour stream.
- **Reads:** D2 listings, D3 listing_image, D1 profiles (landlord public fields).
- **Writes:** none.
- **Flows:** F-15 through F-22.

### Process 4.0 — Bookmarks

- **Inbound from E1 Tenant:** bookmark / unbookmark action against a listing.
- **Outbound to E1 Tenant:** the user's bookmark list.
- **Reads:** D4 bookmark, D2 listings.
- **Writes:** D4 bookmark (insert or delete).
- **Flows:** F-23 through F-25.

### Process 5.0 — Rental Application

- **Inbound from E1 Tenant:** 5-step application (personal, employment, income, references, move-in date) and target `listing_id`.
- **Inbound from E2 Landlord:** review decision (`approve` / `reject`) with optional remarks.
- **Outbound to E1 Tenant:** application status (My Applications view).
- **Outbound to E2 Landlord:** new-application notification, applicant detail view.
- **Reads:** D1 profiles, D2 listings, D5 application, D14 verifications.
- **Writes:** D5 application (insert with `status='submitted'`, then update on decision); D15 notification.
- **Triggers Process 6.0** when the landlord approves an application.
- **Flows:** F-26 through F-32.

### Process 6.0 — Contract Management

- **Inbound from Process 5.0:** approved-application context (parties, listing, terms).
- **Inbound from E1 Tenant:** tenant signature image and metadata.
- **Inbound from E2 Landlord:** landlord signature image, contract-template selection, term overrides.
- **Outbound to E1 / E2:** generated PDF view and download.
- **Reads:** D1 profiles, D2 listings, D6 contract.
- **Writes:** D6 contract (table row and signed-PDF file in the `listing-contracts` Storage bucket); status transitions `awaiting_tenant → awaiting_landlord → fully_signed`.
- **Triggers Process 7.0** when the contract reaches `fully_signed` and a payment is required.
- **Flows:** F-33 through F-40.

### Process 7.0 — Payments

- **Inbound from E1 Tenant:** request to pay (move-in or monthly rent), selected payment method, saved-method management actions.
- **Inbound from E2 Landlord:** request to issue a payment link; request to record an offline payment.
- **Outbound to E3 PayMongo:** create-intent request, attach-method request, create-link request.
- **Inbound from E3 PayMongo:** `payment_intent_id` + `client_key`, redirect URL for 3-D Secure or e-wallet confirmation, checkout URL for links, webhook events (`payment.paid`, `link.payment.paid`, `payment.failed`).
- **Outbound to E1 / E2:** receipt, status updates, error messages.
- **Reads:** D1 profiles, D6 contract, D7 payment, D8 payment_transactions, D9 payment_methods, D10 payment_links.
- **Writes:** D7 payment (one row per succeeded `billing_month` per contract); D8 payment_transactions (one row per attempt); D9 payment_methods (CRUD on saved methods); D10 payment_links (insert on link creation, update on webhook); D6 contract (`status='paid'` on first move-in payment); D2 listings (`status='rented'` on first move-in payment); D15 notification.
- **Flows:** F-41 through F-60.

### Process 8.0 — Messaging (Realtime Chat)

- **Inbound from E1 Tenant / E2 Landlord:** chat message (text, image, file), read receipt.
- **Outbound to E1 / E2:** delivered message via Supabase Realtime.
- **Reads:** D11 conversation, D12 message, D1 profiles.
- **Writes:** D12 message (insert), D11 conversation (`last_message`, `last_at` update), D12 message (`is_read=true` on read receipt).
- **Flows:** F-61 through F-65.

### Process 9.0 — In-Stay Management & Reports

- **Inbound from E1 Tenant:** maintenance / cleaning / noise / amenity / other report (type, priority, description, photos).
- **Inbound from E2 Landlord:** status update on a report (`open → in_progress → resolved`), maintenance notes.
- **Outbound to E1 Tenant:** in-stay dashboard view aggregating active contract, next-due payment, open reports.
- **Outbound to E2 Landlord:** tenant-management view aggregating active tenancies, rent status, open reports.
- **Reads:** D6 contract, D7 payment, D13 report, D1 profiles.
- **Writes:** D13 report (insert and status update); D15 notification.
- **Flows:** F-66 through F-72.

### Process 10.0 — Listing & Tour Management (Landlord)

- **Inbound from E2 Landlord:** new-listing form (title, price, location, amenities, contract-template URL, term overrides); property photos; captured 360° camera frames; metadata edits.
- **Outbound to E2 Landlord:** uploaded-asset feedback, draft preview, publish confirmation.
- **Internal:** local OpenCV stitching and post-processing of 360° frames runs in-process on the mobile device before the stitched panorama is uploaded.
- **Reads:** D2 listings, D3 listing_image, D1 profiles (verification gate).
- **Writes:** D2 listings (insert and update); D3 listing_image (file upload to `listing-images` and `panoramas` Storage buckets, then row insert with `type='normal'` or `type='panorama'`, `sort_order`, `is_cover`).
- **Flows:** F-73 through F-81.

---

## 7. Numbered Data-Flow Catalogue

| Flow ID | From | To | Data |
|---|---|---|---|
| F-01 | E1 / E2 | 1.0 | Signup credentials: `email`, `password`, `full_name`, `phone`, `role` |
| F-02 | 1.0 | E6 Google OAuth | OAuth authorisation request |
| F-03 | E6 Google OAuth | 1.0 | `id_token`, profile basics |
| F-04 | 1.0 | D1 profiles | New profile row (`id`, `role`, `full_name`, `phone`, `is_verified=false`) |
| F-05 | 1.0 | E1 / E2 | Session JWT, profile view |
| F-06 | E1 / E2 | 1.0 | Profile edit payload |
| F-07 | 1.0 | D1 profiles | Updated profile row |
| F-08 | E1 / E2 | 1.0 | Password-reset request → confirmation email (out-of-band via Supabase Auth) |
| F-09 | E1 / E2 | 2.0 | ID front, ID back, selfie images |
| F-10 | 2.0 | D14 verifications (Storage) | Uploaded image files |
| F-11 | 2.0 | E5 Gemini | OCR + face-match request |
| F-12 | E5 Gemini | 2.0 | Decision, OCR fields, OCR confidence, face-match score |
| F-13 | 2.0 | D14 verifications (table) | Verification row with decision and scores |
| F-14 | 2.0 | D1 profiles | `is_verified=true` (only on approval) |
| F-15 | E1 | 3.0 | Search query and filter parameters |
| F-16 | 3.0 | D2 listings | Read filtered listings |
| F-17 | 3.0 | D3 listing_image | Read images for the listing list |
| F-18 | 3.0 | E4 Google Maps | Tile and geocode request |
| F-19 | E4 Google Maps | 3.0 | Tiles, geocoded coordinates |
| F-20 | 3.0 | E1 | Listing feed with locally computed Haversine distance |
| F-21 | E1 | 3.0 | Listing-detail tap |
| F-22 | 3.0 | E1 | UnitDetails view (Details / Amenities / Location, embedded 360° tour) |
| F-23 | E1 | 4.0 | Bookmark / unbookmark action |
| F-24 | 4.0 | D4 bookmark | Insert or delete row |
| F-25 | 4.0 | E1 | Bookmark list |
| F-26 | E1 | 5.0 | 5-step rental-application payload + `listing_id` |
| F-27 | 5.0 | D5 application | New application row (`status='submitted'`) |
| F-28 | 5.0 | D15 notification | New-application notification for the landlord |
| F-29 | D15 notification | E2 | In-app alert |
| F-30 | E2 | 5.0 | Review decision (`approve` / `reject`) |
| F-31 | 5.0 | D5 application | Status update |
| F-32 | 5.0 | 6.0 | Trigger on approval: parties, listing, terms |
| F-33 | 6.0 | D6 contract (table) | New contract row (`status='awaiting_tenant'`) |
| F-34 | 6.0 | D6 contract (Storage) | Generated lease PDF |
| F-35 | E1 | 6.0 | Tenant signature image, `tenant_signed_at` |
| F-36 | 6.0 | D6 contract | Tenant-signed update → `status='awaiting_landlord'` |
| F-37 | E2 | 6.0 | Landlord signature image, term-override edits |
| F-38 | 6.0 | D6 contract | Landlord-signed update → `status='fully_signed'` |
| F-39 | 6.0 | E1 / E2 | Final PDF view and download |
| F-40 | 6.0 | 7.0 | Trigger: `fully_signed` contract awaits move-in payment |
| F-41 | E1 | 7.0 | Pay request (move-in or `billing_month`), method choice |
| F-42 | 7.0 | E3 PayMongo | `paymongo-create-payment-intent` (amount computed server-side from contract) |
| F-43 | E3 PayMongo | 7.0 | `payment_intent_id`, `client_key` |
| F-44 | 7.0 | E3 PayMongo | `paymongo-attach-payment-method` (with optional redirect URL for 3-D Secure / e-wallet) |
| F-45 | E3 PayMongo | 7.0 | Attachment confirmation |
| F-46 | 7.0 | D8 payment_transactions | Insert pending row, update to succeeded |
| F-47 | 7.0 | D7 payment | Insert succeeded row (one per `billing_month`) |
| F-48 | 7.0 | D6 contract | `status='paid'` on first move-in payment |
| F-49 | 7.0 | D2 listings | `status='rented'` on first move-in payment |
| F-50 | E2 | 7.0 | `paymongo-create-payment-link` request for a (contract, `billing_month`) |
| F-51 | 7.0 | E3 PayMongo | Link creation request |
| F-52 | E3 PayMongo | 7.0 | Hosted checkout URL |
| F-53 | 7.0 | D10 payment_links | Link row (`status='pending'`) |
| F-54 | 7.0 | E1 | Checkout URL delivered to tenant (in-app and via chat) |
| F-55 | E3 PayMongo | 7.0 | Webhook event (`payment.paid`, `link.payment.paid`, or `payment.failed`) to `paymongo-webhook` |
| F-56 | 7.0 | D10 payment_links | Status update (`paid` / `expired` / `cancelled`) |
| F-57 | E2 | 7.0 | `landlord-record-offline-payment` (cash, direct GCash, bank transfer) |
| F-58 | 7.0 | D8 payment_transactions | Offline-recorded row with `recorded_by=landlord.id` |
| F-59 | E1 | 7.0 | Manage saved methods (add / delete / set-default) |
| F-60 | 7.0 | D9 payment_methods | CRUD on saved-method rows |
| F-61 | E1 / E2 | 8.0 | Outgoing chat message (text / image / file) |
| F-62 | 8.0 | D12 message | Insert message row |
| F-63 | D12 message (Realtime) | E1 / E2 | Broadcast to the recipient |
| F-64 | 8.0 | D11 conversation | Update `last_message` and `last_at` |
| F-65 | E1 / E2 | 8.0 | Read receipt → `is_read=true` |
| F-66 | E1 | 9.0 | Submit report (type, priority, description, photos) |
| F-67 | 9.0 | D13 report | Insert row (`status='open'`) |
| F-68 | 9.0 | D15 notification | Landlord notification |
| F-69 | E2 | 9.0 | Update report status (`in_progress` / `resolved`), notes |
| F-70 | 9.0 | D13 report | Status update |
| F-71 | 9.0 | E1 | In-stay dashboard (active contract + next-due payment + open reports) |
| F-72 | 9.0 | E2 | Tenant-management view (active tenancies + rent status + open reports) |
| F-73 | E2 | 10.0 | New-listing form (title, price, location, amenities, contract-template URL, term overrides) |
| F-74 | 10.0 | D2 listings | Insert / update listing row |
| F-75 | E2 | 10.0 | Property photo upload |
| F-76 | 10.0 | D3 listing_image (Storage) | Photo files in `listing-images` bucket |
| F-77 | 10.0 | D3 listing_image (table) | Row with `url`, `sort_order`, `is_cover`, `type='normal'` |
| F-78 | E2 | 10.0 | 360° camera frames |
| F-79 | 10.0 (internal) | 10.0 | Local stitch + OpenCV post-process |
| F-80 | 10.0 | D3 listing_image (Storage) | Stitched panorama in `panoramas` bucket |
| F-81 | 10.0 | D3 listing_image (table) | Row with `type='panorama'` |

---

## 8. Explanation Script (Defense Narration)

*The following narration is written to be read aloud during the panel defense at a pace of roughly 130–150 words per minute, giving a delivery time of approximately ten minutes. Square-bracketed cues such as `[point to E3]` are stage directions for the presenter; they should not be read aloud.*

### 8.1 Opening

Good morning, honourable panel. The diagram before you is the **Level-1 Data Flow Diagram of the ViewXRent mobile application**. A Level-0 — or context — diagram would represent the entire system as a single bubble, with arrows to every external entity it interacts with. A **Level-1 diagram refines that single bubble** into its major subsystems, exposes the data stores that persist information between them, and traces the data that flows from each external entity through each subsystem and into each store. We chose to present Level 1 today because it is the highest level of detail at which the architectural intent of the application is still legible on a single page, yet every subsystem the development team built can be identified and audited individually. Lower levels — such as the breakdown of the Payments process into create-intent, attach-method, record-payment, and webhook sub-processes — would belong to Level-2 diagrams and are out of scope for this defense.

### 8.2 External Entities

The diagram identifies six external entities. **[point to E1 and E2]** The first two are the human users — the **Tenant**, who discovers, applies for, signs, pays for, and lives in a property, and the **Landlord**, who enlists the property, reviews applications, signs contracts, and receives payments. **[point to E3]** The third entity is **PayMongo**, the licensed Philippine payment gateway that processes the cards, e-wallets, bank transfers, and checkout links the application uses; it is external because the system delegates the handling of payment credentials and the issuance of webhook events to it. **[point to E4]** The fourth is the **Google Maps Platform**, which serves map tiles and performs geocoding inside the search and property-detail screens. **[point to E5]** The fifth is **Gemini 2.5 Flash**, Google's multimodal model, which the `verify-identity` Edge Function calls to perform optical character recognition on submitted government IDs and to score the similarity of a selfie against the ID portrait. **[point to E6]** Finally, the **Google OAuth provider** mediates federated sign-in; only this provider is external — Supabase Auth itself, which acts as the federator, sits inside the system boundary. Notably, the PSGC location dataset is *not* an external entity because it is bundled as static JSON inside the application package.

### 8.3 The Ten Subsystems

**[gesture across all ten processes]** The application boundary contains ten subsystems, each represented as a numbered process.

**Process 1.0, Authentication and Profile**, handles sign-up, sign-in, federated Google sign-in, password reset, and profile editing. A user submits credentials by way of flow F-01; the process exchanges an OAuth challenge with Google via F-02 and F-03, persists a new row to the `profiles` store by F-04, and returns a session JWT to the user through F-05.

**Process 2.0, Identity Verification**, takes the front and back of a government ID and a selfie via F-09, uploads the files to the `verifications` Storage bucket through F-10, and calls Gemini through F-11. Gemini returns a decision, OCR-extracted fields, an OCR confidence score, and a face-match score in F-12. The decision is persisted in F-13, and a positive decision flips the `is_verified` flag on the user's profile through F-14 — a flag that gates a landlord's ability to enlist properties.

**Process 3.0, Listing Discovery**, is the tenant's principal interaction with the system. The tenant supplies a search query and filter parameters in F-15; the process reads the `listings` and `listing_image` stores in F-16 and F-17, requests map tiles from Google Maps in F-18, and returns a filtered listing feed in F-20. Importantly, the **distance from the tenant's current location is computed locally on the device using the Haversine formula**, with no network call.

**Process 4.0, Bookmarks**, persists per-user favourites in the `bookmark` store through flows F-23 to F-25.

**Process 5.0, Rental Application**, accepts the five-step application form in F-26, writes a `submitted` row to the `application` store in F-27, and notifies the landlord through F-28 and F-29. Upon the landlord's decision, flow F-30, the status is updated in F-31 and — if approved — the application becomes the trigger for **Process 6.0, Contract Management**, in F-32.

**Process 6.0** generates the lease PDF from the chosen template, persists the contract row and the PDF in `listing-contracts`, runs the dual-signing workflow — first the tenant in F-35 and F-36, then the landlord in F-37 and F-38 — and transitions the contract through `awaiting_tenant`, `awaiting_landlord`, and finally `fully_signed`, at which point control passes to **Process 7.0, Payments**, via F-40.

**Process 7.0** is the most behaviourally rich subsystem. It supports four payment funnels: the **tenant-initiated move-in payment**, the **tenant-initiated monthly rent payment**, the **landlord-initiated payment-link checkout** that lets the tenant pay from any device, and the **landlord-recorded offline payment** for cash, direct GCash transfers, or bank transfers. All four are mediated by the Supabase Edge Functions visible at flows F-42, F-44, F-51, and F-57. PayMongo's asynchronous webhook callbacks arrive at F-55 and reconcile the `payment_links` and `payment_transactions` ledgers. Successful first move-in payments propagate to `contract.status='paid'` and `listings.status='rented'` through F-48 and F-49.

**Process 8.0, Messaging**, is enabled by Supabase Realtime. A message is written to the `message` store in F-62 and broadcast to the recipient in F-63; the parent conversation's `last_message` is updated in F-64, and read receipts flow through F-65.

**Process 9.0, In-Stay Management and Reports**, supports both sides of the tenancy. The tenant submits maintenance, cleaning, noise, or amenity reports in F-66; the landlord transitions each report through `open`, `in_progress`, and `resolved` in F-69 and F-70. Aggregate dashboard views — F-71 for the tenant and F-72 for the landlord — combine active contracts, next-due payments, and open reports.

**Process 10.0, Listing and Tour Management**, is the landlord's content-authoring surface. New listings are written to `listings` in F-74, photos to the `listing-images` bucket in F-76, and **stitched 360° panoramas to the `panoramas` bucket** in F-80, after the OpenCV stitching and post-processing pipeline runs locally on the device in F-79.

### 8.4 Cross-cutting Concerns

Three cross-cutting concerns deserve explicit mention even though they are not themselves processes. **First, Row-Level Security**: every Supabase table has RLS policies that constrain every read and write to the rows owned by `auth.uid()` or to rows in tables the user is party to — for example, only the tenant and landlord on a contract can read its row, and only a payment's intended payer can insert into the `payment_transactions` ledger. RLS therefore acts as an invariant on every inbound arrow into a data store. **Second, Realtime broadcast**: Supabase Realtime is enabled specifically on the `message` table, which is why flow F-63 is shown as an outbound arrow from a data store rather than from a process — the broadcast originates from the database itself. **Third, webhook idempotency**: the `paymongo-webhook` Edge Function, the receiver of flow F-55, deduplicates events using the PayMongo event identifier so that a redelivered webhook never produces a second succeeded `payment` row, preserving the database constraint that there be at most one succeeded payment per contract per `billing_month`.

### 8.5 Closing

To close: the diagram intentionally **does not show** the internal Flutter widget tree, the OS-level concerns of camera or location permissions, or the Level-2 sub-processes of the Payments subsystem; those belong to lower-level artefacts. Within its scope, however, the diagram covers every external entity the application speaks to, every subsystem the team built, every Supabase table and Storage bucket the application persists to, and every named flow that crosses a process boundary. **[pause]** Thank you. I welcome the panel's questions.

---

## 9. Document Verification Checklist

- [ ] All ten processes (1.0 – 10.0) listed in Section 4 are present in Section 6 with inbound, outbound, reads, and writes.
- [ ] All fifteen data stores (D1 – D15) listed in Section 5 appear in at least one process subsection.
- [ ] All six external entities (E1 – E6) are referenced in at least one flow in Section 7.
- [ ] Every flow ID referenced in Section 8 exists in the catalogue in Section 7.
- [ ] Every Edge Function named in Process 7.0 exists under `supabase/functions/`.
- [ ] Every screen file linked in Section 4 exists under `lib/`.

*End of document.*
