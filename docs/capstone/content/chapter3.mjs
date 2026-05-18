// Chapter 3 — Technical Background
// Returns an array of docx children (paragraphs/tables/figures).

import {
  chapterTitle,
  sectionHeading,
  inlineHeading,
  para,
  richPara,
  blank,
  bullet,
  bulletLead,
  table,
} from "../lib/docx-helpers.mjs";

export function chapter3() {
  const out = [];

  // Title
  out.push(chapterTitle("Chapter III: Technical Background"));

  // Chapter intro
  out.push(richPara(
    "This chapter presents the technical foundation of **ViewXRent (VXR)** — a Philippine-focused property rental platform delivered through a Flutter mobile application and a React web application that share a single Supabase cloud backend. The discussion is divided into two sections. **Section 3.1** lists the technologies used to develop and run the system, classified into Hardware, Software, Peopleware, and Network. **Section 3.2** then ties those technologies together by describing how a tenant or landlord moves through the platform end-to-end and which technical components support each stage of that journey.",
    { firstLineIndent: true }
  ));

  // ─── 3.1 ───
  out.push(sectionHeading("3.1 Details of the Technology to be Used"));

  out.push(richPara(
    "The proponent grouped the technologies behind ViewXRent into four conventional categories — **Hardware**, **Software**, **Peopleware**, and **Network** — so that readers can see at a glance which physical devices the system runs on, which software products and libraries make it work, which people are involved in operating it, and how those pieces communicate. The descriptions below are written in plain language; specific software versions are listed so that the system can be reproduced exactly as it was developed and tested.",
    { firstLineIndent: true }
  ));

  // ─── Hardware ───
  out.push(inlineHeading("Hardware"));

  out.push(richPara(
    "ViewXRent does not require any specialized server hardware on the proponent's side because the backend is hosted on **Supabase**, a managed cloud platform that takes care of database servers, file storage, and authentication infrastructure. The hardware footprint of the project therefore covers three groups: the developer's workstation, the end-user devices, and the cloud server resources rented from third-party providers.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "The **developer workstation** used to build the system is a Windows 11 personal computer with at least 16 GB of RAM, a multi-core processor capable of running an Android emulator alongside Visual Studio Code, and roughly 80 GB of free disk space for the Flutter SDK, Android Studio, Xcode tooling (when targeting iOS through a Mac), Node.js, and project source files. An internet connection is mandatory because the project relies on remote cloud services for authentication, data, and payments during development.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "**End-user mobile devices** must run Android 7.0 (API level 24) or higher, or iOS 13.0 or higher. The mobile app actively uses several on-device sensors that are not optional. The rear camera and the device's accelerometer/gyroscope are required for the landlord-side 360-degree panorama capture feature implemented in lib/panorama_capture_screen.dart. The GPS receiver is used for distance calculations between the user's current location and listings near them, and to power the address picker that landlords use when enlisting a property. Approximately 80 megabytes of free internal storage is needed for the application binary plus space for cached photos and PDF contracts.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "**End-user web devices** are far less restrictive. Any desktop, laptop, or tablet running a current version of Chrome, Edge, Firefox, or Safari can access the web application. There is no installation step — the React application is loaded from the hosting provider on demand. Web users do not perform panorama capture, so a camera is not required; only an internet connection and a modern browser are needed.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "**Cloud server resources** are provided by Supabase (which itself runs on Amazon Web Services data centers) and consist of a managed PostgreSQL database, file storage buckets for listing photos and contract templates, and serverless Edge Function runtimes for the Stripe payment handler. Stripe provides additional payment-processing infrastructure on its own servers. The proponent does not operate any physical server.",
    { firstLineIndent: true }
  ));

  // ─── Software ───
  out.push(inlineHeading("Software"));

  out.push(richPara(
    "The software stack of ViewXRent is intentionally lean: each platform layer is served by a single well-supported product or library, and the same backend product (Supabase) is shared between the mobile and web clients so that data, contracts, and conversations are perfectly synchronized. The table below groups the most important software products used in the project; package versions are taken directly from pubspec.yaml on the mobile side and package.json on the web side.",
    { firstLineIndent: true }
  ));

  out.push(blank());

  out.push(table(
    ["Category", "Product / Library", "Version", "Purpose"],
    [
      ["Mobile framework", "Flutter / Dart", "3.16+ / 3.11+", "Cross-platform native mobile UI used to build the Android and iOS clients."],
      ["Web framework", "React + Vite", "19 / 7", "Single-page web client served as static assets after bundling."],
      ["Web router", "react-router-dom", "7.13", "Client-side routing for all 22 pages of the web app."],
      ["Backend platform", "Supabase", "—", "Managed PostgreSQL, Auth, Storage, Edge Functions, and Realtime in one cloud product."],
      ["Mobile Supabase SDK", "supabase_flutter", "2.12", "Connects the Flutter app to Supabase for queries, auth, storage, and Realtime."],
      ["Web Supabase SDK", "@supabase/supabase-js", "2.104", "Connects the React app to the same Supabase project as the mobile client."],
      ["Database", "PostgreSQL", "15 (Supabase-managed)", "Stores all user, listing, application, contract, payment, chat, and report data."],
      ["Row-level security", "PostgreSQL RLS", "—", "Restricts every row to its rightful tenant, landlord, or admin via SQL policies."],
      ["Payment SDK (mobile)", "flutter_stripe", "11.4", "Card collection and confirmation on the device using Stripe's mobile SDK."],
      ["Payment SDK (web)", "@stripe/stripe-js + react-stripe-js", "9.4 / 6.3", "Card collection and confirmation in the browser via Stripe Elements."],
      ["Payment server", "Supabase Edge Function (Deno)", "—", "create-payment-intent function that holds the secret Stripe key server-side."],
      ["Maps (mobile)", "google_maps_flutter", "2.17", "Interactive map with markers used in search, address picker, and unit details."],
      ["Maps (web)", "@react-google-maps/api", "2.20", "Web equivalent of the same map experience."],
      ["360° capture", "camerawesome + camera_360 + opencv_dart", "2.5 / 1.1 / 1.4", "Capture and OpenCV-based stitching of 360° photos on mobile only."],
      ["360° viewer", "panorama_viewer", "2.0", "Renders stitched 360° images as interactive tours inside unit details."],
      ["GPS / sensors", "geolocator + sensors_plus", "13.0 / 6.1", "Current-location distance calculations and panorama-capture guidance."],
      ["Image handling", "image_picker + file_picker + image", "1.1 / 8.1 / 4.0", "Photo selection from gallery, file uploads, and image manipulation."],
      ["PDF (mobile)", "pdf + printing", "3.11 / 5.13", "Generate lease contracts as PDF and display the in-app preview/print sheet."],
      ["PDF (web)", "html2pdf.js", "0.14", "Convert the rendered HTML contract into a downloadable PDF in the browser."],
      ["Web styling", "Tailwind CSS + Lucide React", "4.2 / 0.577", "Utility-first CSS and icon set for all web pages."],
      ["Mobile styling", "Material 3 + Google Fonts", "—", "Material Design widgets with Plus Jakarta Sans / DM Sans typography."],
      ["Location data", "PSGC JSON", "—", "Static Philippine Standard Geographic Code regions/provinces/cities/barangays used by both clients."],
      ["Auth providers", "Email/Password + Google OAuth", "—", "Supabase Auth handles both flows; Google OAuth is currently mobile-only."],
      ["Dev tooling", "Git, VS Code, Android Studio, Xcode, Chrome DevTools", "—", "Source control, IDEs, emulators, and browser debugging."],
    ],
    [16, 26, 14, 44]
  ));

  out.push(blank());

  out.push(richPara(
    "Two products in the table deserve a brief expanded explanation because they are unfamiliar to readers outside the project. **Supabase** is an open-source alternative to Firebase that bundles a PostgreSQL database, an authentication service, file storage, server-side functions, and a real-time event subscription system into a single managed cloud product. ViewXRent leans heavily on Supabase: every screen ultimately reads from or writes to its database, every uploaded photo lives in its storage, every chat message is delivered through its Realtime channels, and the Stripe payment handler runs inside one of its Edge Functions. The use of Supabase is what allows the mobile and web clients to feel like one unified system rather than two separate apps.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "**Stripe** is a third-party online payments company used here in sandbox (test) mode to charge the tenant the first month's rent after a contract is fully signed by both parties. The publishable key is embedded in the mobile and web clients (this is safe to expose), while the secret key never leaves the Supabase Edge Function. This separation is important: it means that even if a determined attacker decompiled the mobile app or inspected the web bundle, they would not be able to recover the credentials needed to issue charges.",
    { firstLineIndent: true }
  ));

  // ─── Peopleware ───
  out.push(inlineHeading("Peopleware"));

  out.push(richPara(
    "Peopleware refers to the human roles directly involved in producing and using ViewXRent. The proponent identified two principal groups: the project team responsible for designing, developing, and defending the capstone, and the end users who interact with the deployed system. A few supporting roles outside the project itself are also documented because they affect technical decisions, such as account ownership of the Stripe and Google Cloud consoles.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "On the project side, the **development team** consists of the student proponent(s) acting as full-stack developer, a **technical adviser** who reviews milestones and provides architectural guidance, and the **capstone panel** of faculty members who evaluate the system. A **UI/UX designer role** was filled in-house through the design handoff documented in design_handoff_variation_b/README.md, which produced the visual style now applied to both clients.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "On the end-user side, ViewXRent recognizes three roles inside the system, which are also encoded in the role column of the profiles table in the database. **Tenants** are the prospective and current renters who browse listings, file rental applications, sign contracts, pay rent, file maintenance reports, and message landlords. **Landlords** are property owners who enlist their properties, capture 360-degree panorama tours, review applications, generate contracts, manage tenants, and respond to reports. **Administrators** are operators with elevated privileges who moderate listings, review verification documents, manage announcements and FAQs through the Content Management module, and resolve disputes.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "Outside the project itself, three **supporting service owners** influence the technical configuration: the holder of the Google Cloud project that provisions the Maps API key and the OAuth client used for Google sign-in, the holder of the Stripe account whose dashboard issues the publishable and secret keys used to charge rent, and the holder of the Supabase organization where the database lives. For this capstone all three accounts are owned by the proponent.",
    { firstLineIndent: true }
  ));

  // ─── Network ───
  out.push(inlineHeading("Network"));

  out.push(richPara(
    "ViewXRent is a network-bound application: nearly every visible feature requires data to move between the client device and the Supabase backend, and several features additionally call third-party services such as Google Maps and Stripe. Every connection used by the system is encrypted in transit, and sensitive credentials are never exposed to the client.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "All communication between the mobile or web client and Supabase travels over **HTTPS using TLS 1.2 or higher**. Database queries, file uploads, and authentication requests use the standard Supabase REST and PostgREST endpoints. **Real-time chat** is delivered over a persistent **WebSocket** connection managed by Supabase Realtime; when a tenant or landlord sends a message, the new row inserted into the message table is pushed to the other party's open subscription within roughly one second. The same mechanism is used to keep the conversation inbox sorted by the time of the latest message.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "**Stripe traffic** is double-wrapped to protect the secret key. The client first asks the Supabase Edge Function named create-payment-intent for a PaymentIntent corresponding to a contract; that function, running on Supabase's server, then talks to Stripe over HTTPS using the secret key and returns a temporary client secret. The client uses that client secret to confirm the payment with Stripe's mobile SDK or Stripe Elements on the web. At no point does the secret key touch the user's device.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "**Google Maps and Google OAuth** calls are made directly from the client over HTTPS using API keys that are restricted to the project's package name (mobile) and origin (web). **PSGC location data** is bundled as static JSON inside both clients — there is no network call needed to look up regions, provinces, cities, or barangays, which keeps the address picker fast even on slow connections.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "In terms of bandwidth, a baseline of **1 megabit per second** is sufficient for normal chat and listing browsing, while **5 megabits per second** is recommended when uploading or viewing listings that contain many photographs or 360-degree panoramas. The application degrades gracefully on slower connections: listing thumbnails load progressively, and Supabase Realtime falls back to polling when the WebSocket cannot be established.",
    { firstLineIndent: true }
  ));

  // ─── 3.2 ───
  out.push(sectionHeading("3.2 Project Technical Description"));

  out.push(richPara(
    "Having listed the individual technologies in Section 3.1, this section describes how they cooperate to form one coherent rental platform. The most important architectural decision in ViewXRent is that **the mobile application and the web application are two clients of one backend, not two separate systems**. Both clients connect to the same Supabase project (mqsdtgvxyrvkornnifen.supabase.co), authenticate against the same user accounts, read the same listings, sign the same contracts, and chat through the same message table. A tenant who creates an account on the mobile app can sign in on a friend's laptop the same evening and continue exactly where they left off; a landlord can capture 360-degree panoramas on a phone in the morning and approve a tenant's application from a desk PC in the afternoon.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "This shared-backend model also drives the choice of database technology. **PostgreSQL with row-level security (RLS)** allows the proponent to enforce the platform's privacy rules at the database itself rather than inside each client. For example, the policy contract_select_party on the contract table states that only the tenant or the landlord named on a contract row may read it. Whether the request comes from the Flutter app, the React app, or even a future third-party integration, the database will return zero rows to any user who is neither party to the contract. The same pattern protects applications, payments, reports, messages, and bookmarks. RLS effectively replaces a large swath of authorization code that would otherwise have to be duplicated in both clients.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "To illustrate how the technologies interlock, consider a full rental lifecycle. A **tenant** signs up using email and password (or, on mobile, Google OAuth) — Supabase Auth verifies the credentials and inserts a row into the profiles table. The tenant browses listings on either client; behind the scenes, both clients run the same SQL SELECT against the listings table, filtered by the search criteria and any active bookmarks. When the tenant taps a listing, the photos are streamed from the Supabase Storage bucket listing-images, and the 360-degree panorama (if any) is rendered by panorama_viewer using a normal image of type panorama. To apply for the unit, the tenant fills out a five-step rental application form, whose final step uploads supporting documents to private storage and inserts an application row.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "On the landlord side, the application appears in the **Applicants** screen — read directly from the same application table, filtered by the landlord_id of the linked listing. When the landlord approves, the system inserts a contract row whose status begins at awaiting_tenant; this triggers the creation of a PDF using either the landlord's uploaded contract template or the bundled default for the chosen listing type (lease versus rent). The tenant signs first (writing a base64-encoded signature image into tenant_signature and stamping tenant_signed_at), and the contract moves to awaiting_landlord. The landlord countersigns and the contract status becomes fully_signed.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "Now the **payment** path activates. The contract page on either client surfaces a Pay button; tapping it asks the Supabase Edge Function create-payment-intent to create a Stripe PaymentIntent against the contract's monthly rent. The client receives a Stripe client secret and presents the card sheet (using flutter_stripe on mobile or Stripe Elements on web). On successful confirmation, the client records a payment row referencing the contract; an additional database trigger could promote the contract's status to paid. Once the first payment lands, the **in-stay phase** begins.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "During the in-stay phase, **real-time messaging** between tenant and landlord is delivered through the conversation and message tables, each subscribed to by both clients via Supabase Realtime channels. **Maintenance reports** are filed by the tenant into the report table, classified as maintenance, cleaning, amenity, noise, or other, and tracked through the lifecycle open → in_progress → resolved by the landlord. When the lease ends, the tenant completes a **move-out checklist** on the mobile or web client, which transitions the contract to a terminated state and surfaces a **re-list prompt** to the landlord so the same property can be returned to the listings feed.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "Several cross-cutting technical concerns deserve explicit mention. **Identity verification** is gated at the database level by the is_verified column on profiles, which must be true before a user can create a listing or sign a contract as landlord; verification documents are uploaded to a private storage bucket whose RLS rule restricts each file to its owner. **PSGC location data**, derived from the Philippine Standard Geographic Code, is bundled as JSON inside both clients so that addresses are guaranteed to be consistent and machine-readable. **Pretty addresses** are still entered as free text in location_text, but the cascading region → province → city → barangay picker prevents the kind of inconsistent spelling that would otherwise make search results unreliable.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "Lastly, the choice to keep mobile and web on parallel codebases — rather than using a single cross-platform framework such as Flutter Web — was made deliberately. The mobile app needs deep camera, sensor, and OpenCV integration to capture 360-degree panoramas, which is best served by native Flutter packages. The web app, on the other hand, primarily needs to render listings and contracts beautifully on a large screen, where a fast, SEO-friendly React build with Tailwind CSS gives the proponent more control over typography and layout than Flutter Web currently offers. Both stacks talk to the same Supabase backend, so the cost of having two front-end codebases is recovered by avoiding compromises on either platform.",
    { firstLineIndent: true }
  ));

  out.push(richPara(
    "In summary, ViewXRent is a **two-client, one-backend** rental platform that pairs Flutter and React on the front end with Supabase, Stripe, and Google Maps on the back end. Every feature visible to the user — search, application, contract, payment, chat, report, move-out, re-list — is implemented once at the data and business-logic level (inside Supabase) and rendered twice (once in Flutter for mobile and once in React for the web). The chapters that follow build on this technical foundation to present the system's requirements, design artifacts, and methodology.",
    { firstLineIndent: true }
  ));

  return out;
}
