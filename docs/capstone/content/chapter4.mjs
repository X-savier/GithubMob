// Chapter 4 — Methodology, Results and Discussion
// Returns an array of docx children, with embedded diagram figures.

import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  chapterTitle,
  sectionHeading,
  subsectionHeading,
  inlineHeading,
  para,
  richPara,
  blank,
  bullet,
  bulletLead,
  figure,
  ucTable,
} from "../lib/docx-helpers.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DIAG = path.join(__dirname, "..", "out", "diagrams");

// Portrait section: chapter intro, 4.1, and 4.2 through 4.2.3.
// Returns the array of docx children that live on portrait pages.
export function chapter4Portrait() {
  const out = [];

  // Title
  out.push(chapterTitle("Chapter IV: Methodology, Results and Discussion"));

  // Chapter intro
  out.push(richPara(
    "This chapter documents how the requirements for **ViewXRent (VXR)** were identified and how those requirements were translated into a concrete design. **Section 4.1** presents the requirement analysis — functional, input, output, and other non-functional needs — together with the project's development approach, conceptual framework, and use case diagram. **Section 4.2** then presents four standard design artifacts: the **Context Level Diagram** that shows the system's external boundary, the **Data Flow Diagrams** at Level 0 and Level 1 that decompose the system into processes and data stores, the **HIPO Diagram** that lays out the modular hierarchy, and the **Entity Relationship Diagram (ERD)** that documents the persistent data model. Because ViewXRent's mobile and web clients share a single Supabase backend, every diagram in this chapter describes the **unified system** rather than each platform separately; platform-specific behavior (such as 360-degree panorama capture being mobile-only) is annotated where relevant.",
    { firstLineIndent: true }
  ));

  // ─── 4.1 ───
  out.push(sectionHeading("4.1 Requirement Analysis and Documentation"));

  out.push(richPara(
    "Requirements for ViewXRent were collected through three complementary activities: consultation with prospective tenants and landlords about their pain points with existing rental processes, comparative review of how popular property platforms (such as Lamudi, Carousell, and Airbnb) structure their workflows, and iterative prototyping in which a feature was implemented on one client and adjusted after testing before being mirrored on the other. The resulting requirements are organized below into four classes — **Functional**, **Input**, **Output**, and **Other** (non-functional) requirements — following the structure recommended by the capstone manual.",
    { firstLineIndent: true }
  ));

  out.push(inlineHeading("Functional Requirements"));

  out.push(richPara(
    "Functional requirements describe the tasks the system must perform. They are listed below grouped by the actor who initiates them, in line with the role model (Tenant, Landlord, Administrator) enforced by the profiles.role column in the database.",
    { firstLineIndent: true }
  ));

  out.push(inlineHeading("As a Tenant, the system must allow the user to:"));
  for (const t of [
    "Register an account using email and password, and (on mobile) sign in with a Google account.",
    "Submit identity verification documents and a selfie for review.",
    "Browse listings as a vertical feed, with filters for price, bedrooms, bathrooms, area, furnishing, and pet policy.",
    "Switch between a list view and an interactive Google Maps view that places markers at each listing's coordinates.",
    "View a listing's full details, amenities, and location on three tabs, with photos in a lightbox and 360-degree panorama tours when available.",
    "Save a listing to a personal wishlist of bookmarks.",
    "Submit a rental application through a five-step form that captures personal information, employment, rental history, identity documents, and a declaration.",
    "Track the status of submitted applications (pending, approved, rejected).",
    "View a generated lease contract, electronically sign it, and download the signed PDF.",
    "Pay the first month's rent through Stripe using a saved or new card.",
    "Open an in-stay dashboard that surfaces the active rental, recent payments, open reports, and the conversation with the landlord.",
    "File maintenance, cleaning, amenity, noise, or other reports with a chosen priority.",
    "Send and receive real-time messages with the landlord about a specific listing.",
    "Complete a move-out checklist and terminate the active contract.",
  ]) out.push(bullet(t));

  out.push(inlineHeading("As a Landlord, the system must allow the user to:"));
  for (const t of [
    "Submit identity verification before the right to create listings is granted.",
    "Create, edit, and remove property listings with title, description, price, bedrooms, bathrooms, area, location (region/province/city/barangay), amenities, furnishing status, and pet policy.",
    "Upload multiple property images and capture 360-degree panorama tours directly on a mobile device.",
    "Choose between the lease and rent listing types and upload a custom contract template or override its default terms.",
    "View applications submitted against each listing and approve or reject them with optional notes.",
    "Generate a lease contract from an approved application, sign it electronically, and forward it to the tenant.",
    "Manage active tenants, view their contracts, and track upcoming rent due dates.",
    "Receive and resolve maintenance reports, recording a written response and a resolution timestamp.",
    "Send and receive real-time messages with tenants.",
    "Receive Stripe payments and view a history of all charges credited against each contract.",
    "Re-list a property when the previous tenancy ends.",
  ]) out.push(bullet(t));

  out.push(inlineHeading("As an Administrator, the system must allow the user to:"));
  for (const t of [
    "Read, edit, and remove every profile, listing, application, and contract in the database (bypassing normal RLS through the is_admin() helper).",
    "Review and approve or reject identity verification submissions for both tenants and landlords.",
    "Create, edit, and publish content management pages (e.g., About, Terms of Service, Privacy Policy, Help) used by the public website.",
    "Publish active announcements scoped to all users, tenants only, or landlords only.",
    "Maintain a list of FAQ entries by category for the Help Center.",
  ]) out.push(bullet(t));

  out.push(inlineHeading("Input Requirements"));

  out.push(richPara(
    "Input requirements identify the data the system must accept from its actors and from external services in order to perform its functions. The principal inputs are summarized below, grouped by the workflow that consumes them.",
    { firstLineIndent: true }
  ));

  out.push(bulletLead("Authentication inputs", " — email address, password, full name, phone number, and (when applicable) a Google OAuth token returned by the provider."));
  out.push(bulletLead("Identity-verification inputs", " — a government-issued ID image and a selfie photograph, uploaded to a private storage bucket; submission timestamp."));
  out.push(bulletLead("Listing inputs (landlord)", " — title, descriptive text, price, bedrooms, bathrooms, area, region/province/city/barangay codes plus a free-form location string, latitude/longitude from the map picker, listing type (lease or rent), list of amenities, furnishing status, pet policy, and zero or more property images including optional 360-degree panoramas."));
  out.push(bulletLead("Contract-template inputs (landlord)", " — an uploaded PDF, DOCX, or TXT file representing the landlord's preferred lease template, plus optional overrides for the default per-type terms and conditions stored as a JSON array."));
  out.push(bulletLead("Rental-application inputs (tenant)", " — personal information, employment details, prior rental history, identity documents, and a declaration accepting the application's truthfulness."));
  out.push(bulletLead("Signature inputs", " — base64-encoded handwritten signatures and printed full names from both tenant and landlord on the contract page."));
  out.push(bulletLead("Payment inputs", " — Stripe payment method (card details collected by the SDK; the application itself never sees raw card numbers), the contract identifier being paid, and the amount in centavos."));
  out.push(bulletLead("Messaging inputs", " — message body text and optional image or file attachments uploaded into a private storage bucket."));
  out.push(bulletLead("Report inputs", " — category (maintenance, cleaning, amenity, noise, other), priority (low, medium, high), title, description, and optionally a photograph documenting the issue."));
  out.push(bulletLead("Administrator inputs", " — user-management actions (role changes, account suspension), content management body text and slug, and announcement scheduling windows."));

  out.push(inlineHeading("Output Requirements"));

  out.push(richPara(
    "Output requirements describe the artifacts the system must produce in response to its inputs. The most important outputs are listed below.",
    { firstLineIndent: true }
  ));

  out.push(bulletLead("Property listings", " — paginated lists with thumbnails, prices, locations, and amenities; map view with clustered markers; full detail pages with image galleries and 360-degree tours."));
  out.push(bulletLead("Wishlists and recommendations", " — a tenant's personal list of bookmarked properties, plus algorithmic suggestions based on previous browsing."));
  out.push(bulletLead("Application reviews", " — landlord-facing list of pending and decided applications, with the tenant's submitted information and uploaded documents."));
  out.push(bulletLead("Signed contracts", " — a downloadable PDF containing both signatures, signing timestamps, and the agreed lease terms."));
  out.push(bulletLead("Payment receipts", " — a list of all Stripe charges per contract with amount, currency, status, and timestamp."));
  out.push(bulletLead("In-stay dashboards", " — a unified screen for tenants and tenant-management screen for landlords showing current contracts, recent payments, open reports, and chat shortcuts."));
  out.push(bulletLead("Real-time chat threads", " — inboxes ordered by most recent activity, message threads with read receipts, and notification of new messages while the app is open."));
  out.push(bulletLead("Report acknowledgments", " — visible status transitions (open → in_progress → resolved) and a written response from the landlord when the report is closed."));
  out.push(bulletLead("Administrator dashboards", " — system-wide views of users, listings, applications, contracts, and CMS content."));

  out.push(inlineHeading("Other (Non-Functional) Requirements"));

  out.push(richPara(
    "Beyond the visible features, the system must also satisfy several non-functional requirements that govern its quality of service.",
    { firstLineIndent: true }
  ));

  out.push(bulletLead("Privacy and access control", " — every database table that holds user data must enforce RLS so that a user can only see rows that name them as tenant, landlord, sender, recipient, or owner. Administrators have full access through a SECURITY DEFINER helper."));
  out.push(bulletLead("Security in transit", " — all client-server traffic must use HTTPS with TLS 1.2 or higher; the Stripe secret key must never be exposed to a client."));
  out.push(bulletLead("Performance", " — search and listing-feed loads must complete in under two seconds on a 5 Mbps connection; real-time chat latency must remain below one second under normal conditions."));
  out.push(bulletLead("Reliability", " — Supabase Realtime must fall back to polling when WebSockets are unavailable; failed Stripe payments must surface a human-readable error and leave the contract status unchanged."));
  out.push(bulletLead("Usability", " — both clients must follow the orange-gradient design language documented in the design handoff, support a one-handed mobile workflow, and degrade gracefully on tablets and small laptops on the web."));
  out.push(bulletLead("Localization", " — the address picker must use PSGC codes so that all addresses are consistent and machine-readable for Philippine deployments."));
  out.push(bulletLead("Maintainability", " — the data model is defined entirely in SQL migration files under supabase/migrations, allowing a fresh database to be provisioned from scratch."));

  // ─── 4.1.1 ───
  out.push(subsectionHeading("4.1.1 Project Design Development"));

  out.push(richPara(
    "The development of ViewXRent followed an **iterative, mobile-first approach** that allowed the proponent to validate each feature on real hardware before generalizing it to the web platform. Work proceeded in three broad iterations: a foundation iteration that established authentication, listings, and the database schema; a transaction iteration that added rental applications, contract signing, and Stripe payments; and an operations iteration that introduced in-stay dashboards, reports, real-time messaging, and the move-out flow. Each iteration produced a working, demonstrable mobile build before any equivalent web code was written, which kept the scope concrete and prevented design decisions from being made in the abstract.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "Two concrete artifacts support this iterative approach. The first is the **modular SQL migration set** under supabase/migrations, which is split into focused files such as application_module.sql, listing_contract_module.sql, chat_module.sql, report_module.sql, bookmark_module.sql, listing_image_module.sql, verification_module.sql, and admin_module.sql. Each file is idempotent and can be applied independently; this allowed the proponent to evolve the schema feature by feature without losing previously-entered data. The second is the **design handoff** under design_handoff_variation_b/, which captures the system's visual language — typography, color tokens, component shapes — as both HTML prototypes and Dart drop-in widgets. By writing the visual specification once and translating it twice (into Flutter widgets and Tailwind classes), the proponent kept the two clients visually consistent without coupling their codebases.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "The development tools, all of which are free or open source, are summarized as follows: **Visual Studio Code** is the primary editor; **Android Studio** hosts the Android emulator used for daily mobile testing; **Xcode** is used on borrowed Mac hardware for iOS builds; **Chrome DevTools** is used to debug the web client; and **Git** is used for source control with the project living in a private repository.",
    { firstLineIndent: true }
  ));

  // ─── 4.1.2 ───
  out.push(subsectionHeading("4.1.2 Conceptual Framework of the Study"));

  out.push(richPara(
    "The conceptual framework of ViewXRent follows the **Input–Process–Output (IPO) model** with an explicit feedback loop. The framework identifies the categories of data the system accepts, the major business processes that transform that data into useful results, and the artifacts that those processes produce for the system's users. The feedback loop captures the fact that outputs (resolved reports, completed leases, accumulated payment history) become inputs to subsequent cycles, allowing the platform to learn from its own operation. Figure 4.1 presents the framework visually.",
    { firstLineIndent: true }
  ));

  out.push(...figure(
    path.join(DIAG, "412_conceptual_framework.png"),
    "4.1",
    "Conceptual Framework of the ViewXRent System (Input–Process–Output)."
  ));

  out.push(richPara(
    "On the **Input** side, six categories of data enter the system: user credentials, listing details and photos, rental application information, contract templates and lease terms, payment information, and ongoing communications (chat messages and maintenance reports). These inputs are supplied by the system's three actors — tenant, landlord, and administrator — and by external services such as Google OAuth and Stripe.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "The **Process** layer applies seven major business operations to the inputs: authentication and identity verification, listing creation and image management, application submission and review, contract generation and dual signing, Stripe payment processing, real-time messaging delivered via Supabase Realtime, and report handling. Each process is backed by one or more rows in the database, and each is guarded by the row-level security policies that limit visibility to the rightful parties.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "The **Output** layer delivers seven categories of artifacts: verified user accounts ready to act on the platform, published property listings, decided applications, signed PDF lease contracts, recorded payments with receipts, active in-stay rental records, and resolved maintenance reports. These outputs are not terminal — they re-enter the input stream through the **feedback loop**: a resolved report becomes the basis for the next cycle of tenant trust; a completed lease becomes a re-list candidate; an accumulated payment history becomes part of the landlord's track record.",
    { firstLineIndent: true }
  ));

  // ─── 4.1.3 ───
  out.push(subsectionHeading("4.1.3 Use Case Diagram"));

  out.push(richPara(
    "The use case diagram in Figure 4.2 summarizes the interactions between ViewXRent and its three actors. Use cases are grouped into five thematic clusters — Property Discovery, Rental Process, Listing Management, In-Stay Operations, and Administration — to keep the diagram readable; in practice, several use cases (for example, Sign Lease Contract and Send and Receive Messages) involve more than one actor working in concert.",
    { firstLineIndent: true }
  ));

  out.push(...figure(
    path.join(DIAG, "413_use_case.png"),
    "4.2",
    "Use Case Diagram showing Tenant, Landlord, and Administrator interactions."
  ));

  out.push(richPara(
    "The **Tenant** actor participates in property discovery (browse, search, view 360-degree tour, save to wishlist), the rental process (submit application, sign contract, pay first month), and in-stay operations (chat, file reports, complete move-out). The **Landlord** actor participates in listing management (enlist, capture panorama, manage images, generate contract), the rental process (review application, sign contract), and the remaining in-stay operations (resolve report, manage tenants, chat with tenant). The **Administrator** actor is responsible for the entire administration cluster (manage users, moderate listings, verify identity, publish announcements, edit FAQ and pages).",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "To complement the visual diagram, four representative use cases are presented below in narrative form. Each narrative documents the actor, preconditions, main flow of events, and postconditions, following the structure recommended by the Software Engineering Body of Knowledge.",
    { firstLineIndent: true }
  ));

  // UC-01
  out.push(inlineHeading("UC-01 — Submit Rental Application"));
  out.push(ucTable([
    ["Actor", "Tenant"],
    ["Preconditions", "The tenant is authenticated, has completed identity verification, and is viewing the details of an active listing."],
    ["Main Flow", "1. The tenant taps Apply Now on the listing's details screen. 2. The system opens the five-step rental application form. 3. The tenant fills in personal information (Step 1), employment details (Step 2), prior rental history (Step 3), and identity documents (Step 4). 4. At Step 5, the tenant accepts a declaration of truthfulness and submits the form. 5. The system uploads supporting documents to private storage, inserts a row into the application table with status set to pending, and presents a confirmation screen showing the application reference."],
    ["Alternate Flow", "If the tenant abandons the form before Step 5, no row is inserted; partial data is retained on-device for resumption."],
    ["Postconditions", "An application row exists with status = pending. The landlord can see the application in their Applicants screen; the tenant can see it in My Applications with a tracking status."],
  ]));

  out.push(blank());

  // UC-02
  out.push(inlineHeading("UC-02 — Approve Application and Generate Contract"));
  out.push(ucTable([
    ["Actor", "Landlord"],
    ["Preconditions", "The landlord is authenticated, owns the listing, and is viewing a pending application in the Applicants screen."],
    ["Main Flow", "1. The landlord reads the applicant's full submission and uploaded documents. 2. The landlord taps Approve. 3. The system updates application.status to approved, then inserts a contract row with status set to awaiting_tenant, linking the application, listing, tenant, and landlord. 4. The system generates a PDF lease using either the landlord's uploaded template (listings.contract_template_url) or the default for the listing's listing_type. 5. The tenant receives an in-app notification that a contract is ready to sign."],
    ["Alternate Flow", "If the landlord taps Reject, the system updates application.status to rejected and no contract is created; the tenant sees the rejection in My Applications."],
    ["Postconditions", "An application row has status = approved and a corresponding contract row exists with status = awaiting_tenant."],
  ]));

  out.push(blank());

  // UC-03
  out.push(inlineHeading("UC-03 — Sign Contract and Pay First Month"));
  out.push(ucTable([
    ["Actor", "Tenant (followed by Landlord, then back to Tenant)"],
    ["Preconditions", "A contract exists with status = awaiting_tenant for which the authenticated user is the tenant."],
    ["Main Flow", "1. The tenant opens the contract from the In-Stay Dashboard or notification. 2. The tenant reviews the PDF and signs in the signature panel. 3. The system records tenant_signature and tenant_signed_at and transitions the contract to awaiting_landlord. 4. The landlord countersigns; the system records landlord_signature and landlord_signed_at and transitions the contract to fully_signed. 5. The tenant taps Pay First Month. 6. The client calls the Supabase Edge Function create-payment-intent, receives a Stripe client secret, and presents the card form. 7. Upon Stripe confirmation, the client inserts a payment row referencing the contract; an associated trigger or follow-up update may promote the contract to paid."],
    ["Alternate Flow", "If Stripe returns a failure, the payment row is not inserted and the contract remains at fully_signed; the user is shown a human-readable error and may retry."],
    ["Postconditions", "The contract is fully signed by both parties, the first payment is recorded against it, and the active rental phase begins."],
  ]));

  out.push(blank());

  // UC-04
  out.push(inlineHeading("UC-04 — File and Resolve a Maintenance Report"));
  out.push(ucTable([
    ["Actor", "Tenant (filing) / Landlord (resolving)"],
    ["Preconditions", "A contract exists with status = paid (active rental) between the tenant and landlord."],
    ["Main Flow", "1. The tenant opens the In-Stay Dashboard and taps File a Report. 2. The system presents the report form with category (maintenance/cleaning/amenity/noise/other), priority (low/medium/high), title, and description. 3. The tenant submits; the system inserts a report row with status set to open. 4. The landlord receives the report in the Report Management screen. 5. The landlord changes the status to in_progress while addressing the issue. 6. When resolved, the landlord writes a response and changes the status to resolved; the system records landlord_responded_at and resolved_at."],
    ["Alternate Flow", "If the landlord deems the report invalid, status is set to cancelled with a written response, and the timestamps are recorded accordingly."],
    ["Postconditions", "The report row has a terminal status (resolved or cancelled), a landlord response, and resolution timestamps, all visible to both tenant and landlord."],
  ]));

  // ─── 4.2 ───
  out.push(sectionHeading("4.2 Design of Software, Systems, Product, and/or Processes"));

  out.push(richPara(
    "Having documented the requirements, this section presents the design of ViewXRent through four standard artifacts that move progressively from outside the system to its internals. The **Context Level Diagram** (Section 4.2.1) shows the system as a single box surrounded by the actors and external services that exchange data with it. The **Data Flow Diagrams** (Section 4.2.2) decompose that box into the major processes inside the system, identifying the data stores that persist information between processes. The **HIPO Diagram** (Section 4.2.3) lays the system's functionality out as a module hierarchy, useful for understanding how features are grouped logically. Finally, the **Entity Relationship Diagram** (Section 4.2.4) documents the persistent data model — the tables, columns, and relationships that hold every piece of information visible to the user.",
    { firstLineIndent: true }
  ));

  // ─── 4.2.1 ───
  out.push(subsectionHeading("4.2.1 Context Level Diagram"));

  out.push(richPara(
    "Figure 4.3 shows the highest-level view of ViewXRent. The system is rendered as a single shaded box that represents both the mobile and web clients together with their shared Supabase backend. Around this box are the three actor entities (Tenant, Landlord, Administrator) and three external service entities (Stripe Payment Gateway, Google Maps API, Google OAuth Provider). Arrows describe the data exchanged across each interface.",
    { firstLineIndent: true }
  ));

  out.push(...figure(
    path.join(DIAG, "421_context_diagram.png"),
    "4.3",
    "Context Level Diagram of the ViewXRent System."
  ));

  out.push(richPara(
    "The diagram makes three important properties of the design explicit. First, the **two clients and the backend are treated as one system** at this level of abstraction — a tenant interacts with ViewXRent regardless of whether they are holding a phone or sitting at a laptop. Second, **all payment traffic is routed through the backend** rather than directly between client and Stripe; this is what allows the secret Stripe key to remain server-side. Third, **the system is mostly self-contained** — Google Maps, Google OAuth, and Stripe are the only external dependencies, which keeps the system's reliability and security posture under the proponent's control.",
    { firstLineIndent: true }
  ));

  // ─── 4.2.2 ───
  out.push(subsectionHeading("4.2.2 Data Flow Diagram"));

  out.push(richPara(
    "The Data Flow Diagram (DFD) decomposes the single Context-level box into the processes that exist inside the system and the data stores that persist information between those processes. Two levels are presented: Level 0 shows the whole system as one process surrounded by its entities (essentially expanding the Context diagram with explicit external services), and Level 1 then explodes that single process into eight numbered sub-processes, each connected to one or more data stores.",
    { firstLineIndent: true }
  ));

  out.push(...figure(
    path.join(DIAG, "422_dfd_level0.png"),
    "4.4",
    "Data Flow Diagram — Level 0."
  ));

  out.push(richPara(
    "At Level 0, process 0.0 represents the entire ViewXRent Rental Platform. The three actors send commands into 0.0 (signup, search, apply, sign, pay, message, report on the tenant side; enlist, approve, sign, respond, manage on the landlord side; admin actions on the administrator side) and receive the corresponding outputs (listings, contracts, receipts, dashboards). On the external-service side, 0.0 maintains bidirectional links with the Stripe API for payments, the Google Maps API for geocoding and map tiles, and the Supabase cloud for SQL CRUD, file uploads, and Realtime channels. The Supabase cloud is shown as an external entity in this diagram — although it is part of the platform from the user's perspective, it is third-party managed infrastructure from the proponent's perspective.",
    { firstLineIndent: true }
  ));

  out.push(...figure(
    path.join(DIAG, "422_dfd_level1.png"),
    "4.5",
    "Data Flow Diagram — Level 1 (expanded processes and data stores)."
  ));

  out.push(richPara(
    "At Level 1, the single 0.0 process is broken into eight numbered sub-processes that align directly with the source modules in supabase/migrations. **1.0 Auth and Verification** reads and writes the profiles data store (D1) and is invoked at every login. **2.0 Listing Management** writes to listings (D2) and listing_image (D2b), and reads bookmarks (D8) when the tenant adds or removes a wishlist entry. **3.0 Application Management** writes to the application store (D3) and, on approval, hands off to **4.0 Contract Management**, which manages the contract store (D4). **5.0 Payment Processing** is activated when a contract becomes fully signed; it talks to Stripe and writes to the payment store (D5). **6.0 Real-time Messaging** manages the conversation and message stores (D6) and is subscribed to over WebSocket by both clients. **7.0 Report Management** manages the report store (D7). Finally, **8.0 Administration** can read or write to all the major stores, reflecting the elevated privileges granted by the is_admin() helper, and is the only process that interacts with the CMS stores (D9).",
    { firstLineIndent: true }
  ));

  // ─── 4.2.3 ───
  out.push(subsectionHeading("4.2.3 High-Input-Output Diagram (HIPO)"));

  out.push(richPara(
    "The HIPO diagram in Figure 4.6 presents the same functionality from a different angle: rather than tracing how data flows through the system, it shows how the system's features are organized into a module hierarchy. The root node represents the whole system; the second level groups features by the actor primarily responsible for them; and the leaf nodes are the individual features themselves. This hierarchical view is particularly useful for communicating scope to non-technical stakeholders and for assigning development effort.",
    { firstLineIndent: true }
  ));

  out.push(...figure(
    path.join(DIAG, "423_hipo.png"),
    "4.6",
    "High-Input-Output (HIPO) Diagram showing the modular hierarchy of ViewXRent."
  ));

  out.push(richPara(
    "Four top-level modules sit under the root. The **Tenant Module** (1.0) collects all nine tenant-facing features, from property search through move-out checklist. The **Landlord Module** (2.0) collects all eight landlord-facing features, from property enlistment through re-list. The **Shared Services** module (3.0) collects the six features that both tenant and landlord depend on but neither owns exclusively — authentication, profile and identity, the PSGC location picker, Google Maps, real-time messaging, and the PDF contract renderer. The **Administrator Module** (4.0) collects the six features behind the admin console.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "Two leaf modules deserve a brief input-process-output discussion. **Module 2.2 (360 Panorama Capture)** takes as input a continuous stream of camera frames plus accelerometer and gyroscope readings (process: stitch and post-process via OpenCV); its output is a single equirectangular panorama image written to listing_image with type = panorama. This module is mobile-only because no current web API can match the quality of the native sensor stack. **Module 1.6 (Stripe Payment)** takes as input a fully-signed contract and a Stripe card token (process: create a PaymentIntent via the Edge Function and confirm it on the device); its output is a payment row referencing the contract.",
    { firstLineIndent: true }
  ));

  return out;
}

// Landscape section: 4.2.4 ERD only. Lives on a separate landscape page
// because the full 28-table schema does not fit comfortably in portrait.
export function chapter4Landscape() {
  const out = [];

  out.push(subsectionHeading("4.2.4 Entity Relationship Diagram (ERD)"));

  out.push(richPara(
    "Figure 4.7 documents the complete persistent data model of ViewXRent — twenty-eight tables and one read-only view (`listings_full`), drawn directly from the production Supabase schema. Because the schema spans several functional clusters (identity, listing aggregate, application, contract lifecycle, payments, communication, engagement, and administration), the diagram is rendered on a landscape page so that every table, column list, and foreign-key relationship remains legible. Relationships use the standard crow's-foot notation: a vertical bar denotes a mandatory single relationship and the three-pronged crow's foot denotes a many-side that may be empty.",
    { firstLineIndent: true }
  ));

  out.push(...figure(
    path.join(DIAG, "424_erd.png"),
    "4.7",
    "Entity Relationship Diagram of the ViewXRent database schema (28 tables, 1 view).",
    { maxWidth: 1400, maxHeight: 720 }
  ));

  out.push(richPara(
    "The **identity cluster** sits at the top of the diagram and consists of two tables. The **profiles** table, keyed one-to-one to Supabase Auth's users table, stores each user's role (tenant, landlord, or admin), full name, phone, avatar, and identity-verification flags. The **verifications** table records the history of every KYC submission, including the file paths of the uploaded ID front, ID back, and selfie, plus the OCR, face-match, and name-match scores produced by the verify-identity Edge Function. Keeping verifications as a separate table (rather than a single column on profiles) lets administrators audit every prior attempt and resubmission.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "The **listing aggregate** is the most distinctive part of the schema. Rather than collecting every attribute of a property into one wide row, ViewXRent splits a listing across **one hub table and ten one-to-one spoke tables**. The **listings** hub holds only the identifying fields (title, description, status, listing_type, cover photo, verification status), while the spokes — `listing_details` (size, floor, bedrooms), `listing_locations` (address, barangay, city, lat/lng), `listing_amenities` (in-unit appliances), `listing_utilities` (water, electricity, parking), `listing_building_features` (security, elevator, gym), `listing_financials` (rent, deposits, dues), `listing_availability` (move-in date, lease term, renewable), `listing_policies` (pets, smoking, guests), `listing_requirements` (proof of income, valid ID), and `listing_host_info` (host name, response time) — each carry one tightly-focused aspect of the property. This hub-and-spoke layout makes the model far easier to evolve: a new amenity field, for example, can be added to `listing_amenities` without altering any of the other ten tables. The convenience **`listings_full` view** flattens the entire aggregate back into a single wide read-only row, which is what the search feed and unit-detail pages on both clients consume.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "Two additional listing-side tables round out the aggregate. The **amenity / listing_amenity** pair implements a many-to-many relationship between properties and a curated master list of amenity names, complementing the boolean `listing_amenities` flags with extensible tags. The **listing_image** and **listing_images** tables both store property photographs (including the 360-degree panoramas distinguished by the `type` or `image_type` column); these two tables exist for historical reasons — `listing_image` is the original implementation still used by the mobile client, while `listing_images` is the newer canonical schema being migrated to. Both clients can read either table during the transition.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "The **transaction backbone** of the system runs `application` → `contract` → `payment` → `report`, and is reinforced by several lifecycle support tables. The **application** table captures the tenant's complete five-step submission (personal info, employment, rental history, identity, and declaration), with **application_document** holding pointers to each uploaded file (primary ID front, ID back, secondary ID, selfie with ID, proof of income, employment certificate, or other). On approval, exactly one **contract** row is created (enforced by a UNIQUE constraint on `contract.application_id`); contracts carry both signatures, lease dates, monthly rent, and a detailed termination block (`terminated_by`, `notice_date`, `effective_end_date`, `actual_end_date`). Every state transition on a contract is journaled to **contract_event** for audit, and when a tenancy ends, a **contract_termination** row is opened. That termination can itemize an arbitrary number of **contract_deduction** rows (damage, cleaning, unpaid rent, utilities, keys, other) against the security deposit. Maintenance, cleaning, amenity, noise, and other tenant complaints are filed as **report** rows tied to the active contract.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "**Payments** are intentionally implemented twice, reflecting an architectural evolution that the diagram exposes. The legacy **payment** table is Stripe-specific: each row records a successful Stripe PaymentIntent against a contract with amount, currency, and status. The newer **payment_provider** / **payment_intent** / **payment_transaction** trio is provider-agnostic — a `payment_provider` row configures one acquirer (Stripe today, GCash or PayMaya tomorrow); a `payment_intent` represents an obligation to pay (rent, deposit, advance, or other) against a listing for a tenant/landlord pair, with an idempotency key to prevent duplicate charges; and a `payment_transaction` captures each charge attempt against an intent, including refunds and disputes. The newer subsystem is the canonical implementation going forward, while the legacy `payment` table remains in place for back-compatibility with rows already created.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "**Communication** is modeled by three tables. The **conversation** table binds a tenant, a landlord, and an optional listing, with a unique tuple `(listing_id, tenant_id, landlord_id)` ensuring exactly one thread per pair-per-listing. Every chat bubble is stored as a **message** row carrying its type (text, image, or file), content, optional URL, and read receipt. A database trigger keeps `conversation.last_message` and `last_message_at` in sync with the latest insert, sparing the inbox query from an expensive aggregate. Supabase Realtime publishes both tables over WebSocket so that new messages reach the recipient within roughly one second. **Notification** rows complement the chat by recording out-of-band alerts (e.g., \"your application was approved\") that surface even when the user is not actively viewing the conversation.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "**Engagement tables** capture lighter-weight interactions. **Bookmark** is the wishlist — a simple (user_id, listing_id) pair recording that a tenant saved a property. **Review** lets tenants rate listings on a 1–5 scale with an optional comment after their stay. **Report**, already discussed in the transaction backbone, also belongs here because it is the principal mechanism for tenants to flag problems during an active lease.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "Finally, the **administration cluster** sits to one side of the diagram and supports the admin console. The CMS family — **cms_page** (slugged content like About and Terms of Service), **cms_announcement** (scoped banners with start/end windows), and **cms_faq** (categorized Q&A) — all track their `updated_by` profile and follow the same publishing model (drafts are private; published rows are world-readable through RLS). **audit_log** records administrator and high-privilege actions with action type, target type/id, IP address, and user-agent, providing a tamper-evident trail for sensitive changes such as role promotions or listing takedowns.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "Every table in Figure 4.7 enables PostgreSQL row-level security. The combination of foreign-key constraints, RLS policies, and database-level CHECK constraints (on enum-like columns such as `contract.status`, `application.status`, `report.priority`, `message.type`, `payment.status`, and `payment_transaction.status`) means that even a buggy client cannot put the database into an inconsistent state. This database-centred design is what allows the Flutter mobile and React web clients to evolve independently while sharing one trustworthy source of truth.",
    { firstLineIndent: true }
  ));

  return out;
}
