# Handoff: ViewxRent — Variation B "Dusk Edit"

## Overview

Apply the **Variation B "Dusk Edit"** visual system to the existing ViewxRent
Flutter app (`vxr_flutter` — package `vxr_flutter`). This is a re-skin of the
existing app, not a re-architecture: routes, models, services, and business
logic stay as-is. The work is concentrated in styling, recurring widget
patterns, and a handful of layout moves on the major screens.

The four defining moves of Variation B:

1. **Horizontal property cards** — image left, content right, favorite far right.
   Twice as dense as the previous vertical card.
2. **Square-bottom headers** — drop the rounded bottom corners on Home / Search
   gradient headers. Profile keeps its rounded bottom by design.
3. **Surface header on Search** — Search uses a light surface header (not
   the coral gradient). Home and Profile keep the gradient. This is the move
   that visually distinguishes Variation B from Variation A.
4. **Warmer paper-and-ink neutrals** — `#F7F5F3` paper bg + `#1A1310` ink, with
   `#FF7043` coral as the single accent. All other neutrals are warm-grey
   (no cool blues).

Scope: **light mode only** for now. Dark mode tokens exist in the source design
system but are not part of this delivery.

## About the Design Files

The HTML files in this bundle (`Variation B — Dusk Edit.html` and the `.jsx`
files it loads) are **design references** — interactive prototypes that show
the intended look and behavior of every screen, plus a built-in patch guide
with before/after Dart snippets for each file in `lib/`.

**The Dart files in `dart/` are the exception** — they are real, production-ready
Flutter code intended to be copied verbatim into the project at
`lib/theme/vxr_theme.dart` and `lib/theme/vxr_widgets.dart`. They depend only
on packages already in the app's `pubspec.yaml` (`google_fonts`,
`cached_network_image`).

The task is not to "translate the HTML to Flutter from scratch" — it is to
**drop the two Dart files into the existing Flutter codebase**, then edit each
screen file in `lib/` to use the new widgets and theme tokens, following the
per-file diffs in the Patch Guide.

## Fidelity

**High-fidelity.** Every color, radius, font weight, font size, and spacing
value in the prototypes is final. The Dart drop-in files in this bundle encode
those exact values as `VxrTokens.*` constants — use those rather than literal
hex codes or magic numbers when editing screen files. Where the Patch Guide
shows hard-coded values (e.g. `padding: const EdgeInsets.fromLTRB(18, 12, 18, 12)`),
those are also final.

## The codebase

Target repo lives at the user's local mount `mobile-proj/GithubMob/`. Key
facts about the existing Flutter project:

- **Package name**: `vxr_flutter`
- **State management**: plain `StatefulWidget` + `setState`. Do not introduce
  Provider, Riverpod, or Bloc unless explicitly asked.
- **Auth + data**: Supabase (`supabase_flutter`). Don't change auth flows.
- **Payments**: Stripe (`flutter_stripe`). Don't change payment flows.
- **Fonts**: `google_fonts` is already in `pubspec.yaml`. Plus Jakarta Sans
  (display/headings) + DM Sans (body/UI) are the two families.
- **Routing**: plain `Navigator.push(MaterialPageRoute(builder: ...))`. Keep it.
- **Folder layout**: everything is flat in `lib/` except `lib/auth/`.

Recommended new folder for this work:

```
lib/
├── theme/                  ← NEW — drop the two Dart files here
│   ├── vxr_theme.dart
│   └── vxr_widgets.dart
├── auth/                   (unchanged)
├── main.dart               (light edits — see Patch Guide)
├── home_page.dart          (edits)
├── login_screen.dart       (edits)
... etc
```

## Implementation order

Do the work in this order — each step unblocks the next:

1. **Drop in the two Dart files** to `lib/theme/`. Do not edit them.
2. **Wire `VxrTheme` in `main.dart`** (see Patch Guide → `lib/main.dart` →
   "Import + wrap MaterialApp"). After this, run the app — every screen will
   look subtly different already because the global `InputDecorationTheme`,
   `ElevatedButtonTheme`, etc. now apply.
3. **Apply the patches screen-by-screen**, starting with the user-facing
   surfaces in this order:
   - `lib/main.dart` (landing) — primary CTA buttons
   - `lib/login_screen.dart` + `lib/signup_screen.dart` — hero-and-card layout
   - `lib/home_page.dart` — app bar, chips, **horizontal `VxrPropertyCard`**,
     bottom nav. This screen exercises the most new widgets at once.
   - `lib/search_field.dart` — **surface app bar** (the Variation B signature)
   - `lib/unit_details.dart` — tabs, amenity chips, sticky CTA bar
   - `lib/profile_screen.dart` — gradient hero + accent-soft icon tiles
4. **Then the secondary screens** in any order — the Patch Guide sidebar lists
   every file. Six files at the bottom are tagged "NO visual changes" — those
   are pure data/service files and should not be edited.

## Screens / Views

The prototype renders six screens in iOS frames (see the **Screens** tab of
`Variation B — Dusk Edit.html`). Each maps to a single Flutter file:

### 1. Landing (`lib/main.dart` — `LandingPage`)

- **Top 58% of viewport**: full-bleed `VxrTokens.brandGradient` background.
  Logo + "Find Rental Homes Made Easy" headline (Plus Jakarta Sans 800,
  28px, white). Subtitle in `rgba(255,255,255,0.80)`. Search bar
  (`VxrSearchBar` with `onGradient: true`) sits at the bottom of the gradient
  section.
- **Bottom 42%**: white surface, rounded top corners (`radiusSheet = 28`).
  Overlaps the gradient by ~20px (`margin-top: -20`).
- **Buttons**: `VxrPrimaryButton("Get Started")`, then
  `VxrSecondaryButton("Create Account")` directly below.
- **"WHY CHOOSE US" row**: three icon tiles (44×44 `accentSoft` background,
  accent icon, 14px radius) in a `MainAxisAlignment.spaceAround` row, with
  small label below each.

### 2. Login (`lib/login_screen.dart`)

- Full-bleed `brandGradient` Scaffold body.
- **Hero (top, gradient)**: small 36×36 back button (translucent white),
  `VxrLogoMark(onGradient: true)`, "Welcome Back" headline, "Sign in to
  continue" subtitle.
- **White card** slides up from bottom — `BorderRadius.only(topLeft, topRight)`
  both `radiusSheet = 28`. Padding `EdgeInsets.fromLTRB(24, 28, 24, 24)`.
- Inside the card: `VxrInputField` for email and password (with
  `Icons.mail_outline` and `Icons.lock_outline` prefix icons), "Forgot
  Password?" right-aligned in accent, `VxrPrimaryButton("Sign In")`, then
  `VxrSecondaryButton("Continue with Google")` below.
- "Don't have an account? **Sign Up**" at the bottom — accent + bold for
  the "Sign Up" portion.

`lib/signup_screen.dart` mirrors this exact layout with different fields and
copy.

### 3. Home Feed (`lib/home_page.dart`)

- **App bar**: `VxrAppBar` — coral gradient, **square bottom corners** (no
  rounded radius on the bottom — this is the Variation B move), height
  determined by content. Contains:
  - Row: `VxrLogoMark(onGradient: true)` on the left, two icon buttons
    (heart-outline, bell-outline) on the right
  - "Find Your Perfect Home" headline (Plus Jakarta Sans 800, 17px, white)
  - "Discover rental properties near you" subtitle (DM Sans 11px, white 75%)
  - `VxrSearchBar(onGradient: true)`
- **Category chip rail**: horizontal scroll, padding `EdgeInsets.fromLTRB(18, 14, 18, 8)`.
  Chips: "All", "1 Bedroom", "2 Bedrooms", "3+ Beds". Active chip uses
  `VxrTokens.accent` background + white text 700 weight. Inactive uses
  `surface2` background + `text` color 500 weight.
- **Section heading**: "Featured in Dasmariñas", Plus Jakarta Sans 700, 13px.
- **Property list**: vertical column of `VxrPropertyCard` widgets, 10px gap.
- **Bottom nav**: `VxrBottomNav` — gradient pill indicator above active icon.

### 4. Search (`lib/search_field.dart`)

The Variation B signature — **surface header instead of gradient**:

- **App bar**: `VxrSurfaceAppBar` — `VxrTokens.surface` background, hairline
  bottom border (`VxrTokens.border`). Contains:
  - "Search Properties" title (Plus Jakarta Sans 800, 16px, `VxrTokens.text`)
  - "Find your perfect rental home" subtitle (DM Sans 11px, `VxrTokens.textSub`)
  - `VxrSearchBar()` (light variant, no `onGradient`)
- **Chip rail**: same as Home, with "Studio / 1 Bed / 2 Bed / 3+ Bed" options.
- **Results header row**: "24 Properties Found" (Plus Jakarta Sans 700, 12px)
  on left, **List / Map segmented toggle** on right (`surface2` background,
  active segment uses `VxrTokens.accent`).
- **Results**: vertical column of `VxrPropertyCard`.

### 5. Unit Details (`lib/unit_details.dart`)

- **Hero image**: 220px tall, full-width image, with a top-to-bottom dark
  gradient overlay (`rgba(0,0,0,0.25)` → transparent → `rgba(0,0,0,0.5)`).
- **Floating back button**: 34×34, `rgba(255,255,255,0.2)` + `backdropFilter:
  blur(8px)`, top-left at 44/16.
- **Floating label pill**: bottom-left of image, `VxrTokens.accent` background.
- **Content area**:
  - Title + price row. Title left (Plus Jakarta Sans 800, 17px); price right
    (Plus Jakarta Sans 800, 18px, `VxrTokens.accent`) with "/mo" small + muted.
  - Spec tiles row: 3 equal-width tiles, `surface2` background, 12px radius,
    centered icon + value.
  - **Tab bar**: 3 tabs ("Details", "Amenities", "Location"). Indicator
    `VxrTokens.accent`, weight 2, label Plus Jakarta Sans 700, 12px.
  - Body text 12px, line-height 1.7, `VxrTokens.textSub`.
  - **Landlord card**: 42×42 gradient avatar (initial in white), name + sub,
    "Message" pill (`accentSoft` bg + accent text).
- **Sticky bottom CTA**: surface bg with top border. Row of two buttons —
  `VxrSecondaryButton("360° Tour")` (flex 1) and `VxrPrimaryButton("Apply
  Now")` (flex 2).

### 6. Profile (`lib/profile_screen.dart`)

- **Gradient hero with rounded bottom** (this is the one screen where the
  rounded bottom is *kept* — design intent). 24px radius bottom corners.
- Back row at top: white back chevron + "Profile" title (Plus Jakarta Sans 700,
  15px, white).
- Centered: 72×72 circular avatar with 3px white-translucent border. Below:
  full name (Plus Jakarta Sans 800, 16px, white), email (DM Sans 11px, 75%
  white), then "Edit Profile" pill — `rgba(255,255,255,0.2)` background with
  1.5px white-translucent border.
- **Menu card**: single rounded surface card wrapping all menu rows. Each row
  is `13px vertical / 14px horizontal` padding, with a 36×36 `accentSoft`
  icon tile (radius 11) on the left, two-line text in the middle (label
  DM Sans 600 12px, sublabel DM Sans 10px `textSub`), and a chevron-right on
  the right. Rows separated by 1px `border` dividers indented by 62px.
- Below: full-width `VxrPrimaryButton("Logout")`.

## Reusable widgets (in `vxr_widgets.dart`)

| Widget | Use |
|---|---|
| `VxrLogoMark` | Brand mark + wordmark. `onGradient: true` for use over the coral header. |
| `VxrAppBar` | Gradient app bar with title/subtitle, leading, actions, and an optional bottom slot (typically a search bar). |
| `VxrSurfaceAppBar` | Same shape, surface background, for screens that need a calmer header (Search, Messages, etc). |
| `VxrSearchBar` | Pill-shape search input with magnifier + filter button. `onGradient` swaps to translucent-white variant. |
| `VxrChip` | Selectable category chip. |
| `VxrPropertyCard` | **The big one — horizontal card.** Image left, content middle, favorite right. |
| `VxrInputField` | Labeled text field with prefix icon. Replaces all `TextField + InputDecoration` repetition. |
| `VxrPrimaryButton` | Gradient + glow CTA. Has `loading` and optional `icon` props. |
| `VxrSecondaryButton` | Outline button — accent border + accent text. |
| `VxrBottomNav` | 4-tab bottom nav with gradient pill indicator above the active item. |

## Interactions & Behavior

The visual layer changes; interaction logic stays. Specifically:

- All existing `Navigator.push` calls are preserved.
- `setState` patterns stay — `VxrChip`, `VxrBottomNav`, etc. expose `onTap`
  callbacks that match the existing pattern.
- `VxrInputField` exposes `controller`, `onChanged`, `validator` — direct
  swap for existing `TextField` usage.
- Property cards: tap anywhere opens detail; tapping the favorite icon
  toggles bookmark (`onFavoriteTap` is a separate callback that should NOT
  bubble up to `onTap`).
- Loading state on `VxrPrimaryButton`: when `loading: true`, show a 16×16
  white `CircularProgressIndicator` in place of the label, and disable taps.
- The `Container` + `BoxDecoration` patterns in the Patch Guide assume
  Flutter 3.16+ (the `WidgetStateProperty` API). The app's current SDK
  satisfies this.

## State Management

No new state to introduce. Reuse existing state in each screen file. The new
widgets are pure — they take values and emit callbacks.

## Design Tokens

All tokens live in `vxr_theme.dart` as `VxrTokens.*`. Summary:

### Colors

| Token | Hex | Use |
|---|---|---|
| `VxrTokens.bg` | `#F7F5F3` | Page background — warm paper |
| `VxrTokens.surface` | `#FFFFFF` | Cards, sheets, modals |
| `VxrTokens.surface2` | `#F2F0EE` | Inputs, chips, secondary fills |
| `VxrTokens.border` | `#EBEBEB` | Hairlines, card outlines |
| `VxrTokens.text` | `#1A1310` | Primary text (ink) |
| `VxrTokens.textSub` | `#7A6E68` | Secondary text |
| `VxrTokens.textMuted` | `#B0A8A2` | Placeholder / inactive |
| `VxrTokens.accent` | `#FF7043` | Primary actions, price, brand |
| `VxrTokens.accentSoft` | `#FDEAE4` | Soft accent — icon tile bg, pills |
| `VxrTokens.success` | `#22C55E` | Approved / paid / resolved |
| `VxrTokens.warning` | `#FF9800` | Pending / awaiting action |
| `VxrTokens.danger` | `#EF4444` | Reject / destructive |

### Brand gradient

`VxrTokens.brandGradient` — 135° linear: `#FF7043 → #FF5252 → #FF8A80`.
Used on Home/Profile headers, primary buttons, active nav indicator,
gradient avatars, message bubbles ("my" side), step indicator bars.

### Radii

| Token | Value | Use |
|---|---|---|
| `VxrTokens.radiusSm` | 8 | Inputs interior, small chips |
| `VxrTokens.radiusPill` | 50 | Pills, search bar, chips |
| `VxrTokens.radius` | 16 | Cards, buttons (default) |
| `VxrTokens.radiusSheet` | 28 | Bottom sheets, modal tops |

### Shadows

- `VxrTokens.shadowSm`: single `BoxShadow(blur: 6, y: 1, color: black 8%)` —
  cards and list rows.
- `VxrTokens.shadowCta`: single `BoxShadow(blur: 20, y: 4, color: accent 27%)` —
  primary buttons (paired with `brandGradient` background).

### Typography

| Style | Family | Weight | Size | Use |
|---|---|---|---|---|
| Display | Plus Jakarta Sans | 800 | 28 | Hero headlines |
| Title | Plus Jakarta Sans | 800 | 17 | Screen titles, property title |
| Heading | Plus Jakarta Sans | 700 | 13 | Section headers |
| Body | DM Sans | 400 | 12 | Body text |
| Caption | DM Sans | 500 | 11 | Subtitles, metadata |
| Micro | DM Sans | 600 | 9 | Pill labels, micro tags |

All sizes are in logical pixels. Use `GoogleFonts.plusJakartaSans(...)` /
`GoogleFonts.dmSans(...)` — `google_fonts` is already a dependency.

## Assets

Image placeholders in `assets/` (5 property images) come from the source design
system. The real app uses `cached_network_image` to load property photos from
Supabase storage — no changes there. The placeholder images are ONLY for
running the HTML prototype; do not copy them into the Flutter `assets/` folder.

## Files in this bundle

| File | Purpose |
|---|---|
| `dart/vxr_theme.dart` | **Production Dart** — drop into `lib/theme/`. |
| `dart/vxr_widgets.dart` | **Production Dart** — drop into `lib/theme/`. |
| `Variation B — Dusk Edit.html` | The visual spec + patch guide app. Open in a browser. The "Patch Guide" tab is the most useful surface for implementing this — it lists every screen file with before/after Dart snippets. |
| `screens.jsx` | Source of the six iOS-frame screen renders. Reference only — not used in the implementation. |
| `patches.jsx` | Source data for the Patch Guide tab. Reference only. |
| `design-canvas.jsx`, `ios-frame.jsx` | UI helpers for the prototype HTML. Reference only. |
| `assets/` | Placeholder property images for the HTML prototype only. |

## Implementation checklist

When you're done, the user should be able to verify with this checklist:

- [ ] `lib/theme/vxr_theme.dart` and `lib/theme/vxr_widgets.dart` exist
- [ ] `main.dart` wraps `MaterialApp` with `VxrTheme.lightThemeData()` and the
      `builder: (context, child) => VxrTheme(child: child!)` shim
- [ ] No `TextField` + `InputDecoration` usages remain — all replaced with
      `VxrInputField`
- [ ] No `ElevatedButton` for primary CTAs — all replaced with
      `VxrPrimaryButton`
- [ ] All property list cards are horizontal (image left, content right)
- [ ] Home page header has square bottom corners
- [ ] Search page header is light-surface (no gradient)
- [ ] Profile page header has rounded bottom corners (24px)
- [ ] Bottom nav has a gradient pill indicator above the active item
- [ ] No remaining literal hex colors like `0xFFF36C6C` or `Color(0xFFFF7043)` —
      everything routes through `VxrTokens.*` or `VxrTokens.brandGradient`

## Notes

- Don't touch `lib/property_data.dart`, `lib/contract_templates.dart`,
  `lib/auth/auth_service.dart`, `lib/psgc_service.dart`,
  `lib/panorama_post_processor.dart`, or `lib/panorama_stitcher.dart` — these
  are pure data / services with no visual surface.
- Keep `lib/panorama_capture_screen.dart` dark — only the shutter button picks
  up the brand gradient; the camera scaffold itself stays black.
- The payment screen's payment-method card uses a separate orange-pay accent
  (`#FF9800`) — that's deliberate from the source design system and is not the
  same as `VxrTokens.accent`.
