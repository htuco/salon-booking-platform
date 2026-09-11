# Handoff: Barber Studio Vitez — mobilna aplikacija za zakazivanje (iOS, dark)

## Overview
Client-facing mobile app for a single barbershop (Barber Studio Vitez, BiH): browse services,
send a booking request, track its confirmation, browse the gallery/reviews, and manage the
account. Copy is Bosnian. 16 screens + 2 overlay patterns, all at iPhone 402×874 @1x.

## About the Design Files
The files in this bundle are **design references created in HTML** — prototypes that show the
intended look, layout and behavior. They are **not production code to copy**. The task is to
recreate them in the target codebase's environment (SwiftUI / React Native / React, whatever the
app already uses) with its established components, navigation and styling patterns. If no
environment exists yet, pick the framework that fits the product and implement the designs there.

`Salon App v2.dc.html` is a design canvas: every screen is one option card (id `5a`…`5q`)
inside an iPhone frame. Open it in a browser and pan/zoom.

## Fidelity
**High-fidelity.** Final colors, type, spacing and copy. Recreate pixel-perfectly, mapping the
literal values below onto the codebase's own token layer. Photography is placeholder only (see Assets).

## Screens / Views

All screens share: full-bleed background `#0F1012`, a scrollable content column, and — on the five
tab-level screens — the bottom tab bar. Safe-area top padding is 64–72px, bottom tab bar adds 26px.

| id | Screen | Purpose | Chrome |
| --- | --- | --- | --- |
| 5a | Početna (Home) | Hero photo + primary CTA, price list, gallery grid, rating summary | tab bar, Početna active |
| 5b | O nama (About the shop) | Story, photo pair, hours, contact, socials | tab bar, Početna active |
| 5c | Korak 1 — Izaberite uslugu | Pick one service | back + "Korak 1 od 4" + 4-segment progress |
| 5d | Korak 2 — Kod koga dolazite? | Pick barber ("Bilo ko od nas" first) | back + step 2 |
| 5e | Korak 3 — Izaberite vrijeme | Month calendar, then AM/PM slot grid | back + step 3 |
| 5f | Korak 4 — Prijava | Apple / Google / phone sign-in, booking summary card | back + step 4 |
| 5g | Zahtjev poslan | Request sent, **not** confirmed; status "Na čekanju" | hero photo + back |
| 5h | Moji termini | Upcoming / past tabs, appointment detail, cancel entry | tab bar, Termini active |
| 5i | Usluge | Full price list, tap = book directly | tab bar, Usluge active |
| 5j | Obavijesti | Confirmations, reminders, shop announcements | tab bar, Obavijesti active |
| 5k | Postavke | Profile, account, notifications, language, about, logout | tab bar, Postavke active |
| 5l | Galerija | 3-col square photo grid | back header ("Početna"), no tab bar |
| 5m | Recenzije | 4,8 average, 5→1 histogram, review list | back header, no tab bar |
| 5n | O aplikaciji | Version, 3-step "Kako radi", legal + contact rows | back header ("Postavke") |
| 5o | Pravila korištenja | Six numbered legal sections (booking, cancellation, lateness, prices, data, contact) | back header |
| 5p | Modal — otkazivanje termina | Confirm destructive cancel | dialog over blurred + dimmed screen |
| 5q | Lightbox galerije | Fullscreen photo, counter, thumbnail strip | overlay, no tab bar |

### Bottom tab bar (the one shared component to build first)
- Grid, 5 equal columns, `border-top: 1px solid #33383C`, background `#0B0C0D`,
  cell padding `11px 0 8px`, bottom padding `26px` (home indicator).
- Order, left→right: **Usluge · Termini · Početna · Obavijesti · Postavke** — Home deliberately centred.
- Icon 23×23, Lucide, `stroke-width 1.5`, `currentColor`. Label 12px Archivo, gap 5px.
- **Active**: color `#FFFFFF`, label weight 600, plus a 3px bar `#F2F2F3` pinned to the top of the
  cell, inset 16% left/right. **Inactive**: `#9AA1A7`, weight 400, no bar.
- Sub-screens (Galerija, Recenzije, O aplikaciji, Pravila, Lightbox) have **no** tab bar — they are
  pushed views with a back header (`←` 22px + 18px/600 label, min-height 48px).

### Recurring components
- **Service row** — `display:flex; gap:14px; padding:14px; border:1px solid #454B50`; 76×76 photo,
  name 20px/600 `#FFF`, duration 16px/400 `#C3C9CE`, price 24px DM Serif Display `#FFF`.
  Selected: `border:2px solid #F2F2F3`, background `rgba(242,242,243,.10)`.
- **Primary CTA** — height 60–66px, background `#F2F2F3`, label 19–21px/600 Archivo `#10161C`,
  square corners, full width. Disabled: background `#2A2E32`, label `#8B9298`.
- **Secondary CTA** — transparent, `1px solid #6B7176`, label `#FFF`.
- **Time slot** — 58–64px tall, `1px solid #454B50`, 20–22px/500 Archivo `#FFF`;
  selected `2px solid #F2F2F3` on `#F2F2F3` with `#10161C` text.
- **Calendar day** — 44px square cell, `1px solid #33383C`; selected inverted (`#F2F2F3` fill);
  past days `#5F666B` and non-interactive.
- **Spec card / list group** — `1px solid #454B50`, rows separated by `1px solid #33383C`,
  row min-height 60px, padding 18px, chevron `›` `#9AA1A7`.
- **Step progress** — 4 columns, 5px tall, gap 5px; done `#F2F2F3`, pending `#3A3F44`.
- **Photo frame** — square/portrait, `1px solid #454B50`, background `#1A1D20`, never rounded,
  never cropped round.
- **Modal (5p)** — background screen gets `filter: blur(1.5px)` and a `rgba(6,7,8,.72)` scrim;
  dialog: inset 20px, bottom 120px, `1px solid #6B7176`, background `#141618`, padding 24px 22px 22px,
  kicker 14px/600 letterspacing .18em uppercase `#9AA1A7`, title 34px DM Serif Display,
  body 17px/1.5 `#C3C9CE`, destructive primary + "Zadrži termin" secondary stacked, gap 10px.
- **Bottom sheet** — 52×4px `#4A5055` grab handle, `border-top:1px solid #6B7176`, background `#141618`.

## Interactions & Behavior
- **Booking flow** is linear 4 steps; back returns one step, state is kept. CTA is disabled until the
  step's required choice exists ("Izaberite vrijeme" label while no slot).
- Step 3: picking a day filters the slot grid (AM group then PM group). Past days not selectable.
- Step 4 sign-in: Apple / Google / phone; phone path is a 6-digit OTP, no password anywhere.
- **After submit the appointment is a request, not a booking** — 5g and the appointments list both show
  status "Na čekanju" until the shop confirms; the confirmation arrives as a push/notification (5j).
  Do not show a fake success state.
- Cancel: from the appointment detail → modal 5p → on confirm the slot is released immediately.
  Per 5o, cancellation is allowed up to 2h before start.
- Gallery: tap a grid cell → lightbox 5q (counter "4 / 18", close ✕, share ⤴, thumbnail strip).
  No titles or captions on photos.
- Tab switches are instant, no cross-fade. Tabs reset to their root on re-tap.
- States to cover per element: default / pressed / selected / disabled; disabled = 45% opacity or the
  `#2A2E32` fill above. Hit targets ≥ 44px everywhere (tab cells, slots, calendar days, rows).

## State Management
- `selectedService` (index | null), `selectedBarber` (index, 0 = any), `selectedDay` (date),
  `selectedSlot` (string | null) — the booking draft; cleared after submit.
- `bookingStep` 1–4, `appointmentsTab` 'upcoming' | 'past', `cancelDialogOpen` bool,
  `lightboxIndex` (int | null), `otp` (string ≤6).
- Data needed from the backend: services (name, duration, price, photo), staff, availability per
  day/barber, the user's appointments with status, gallery photos, reviews + rating histogram,
  notifications, shop info (hours, phone, address, socials).

## Design Tokens
Colors — `#0F1012` app background · `#0B0C0D` tab bar · `#141618` modal/sheet surface ·
`#151719` raised card · `#1A1D20` photo frame ground · `#33383C` hairline/divider ·
`#454B50` card border · `#6B7176` strong border/secondary button · `#8B9298` disabled text ·
`#9AA1A7` muted/inactive · `#C3C9CE` body text · `#E3E7EA` hero subtext · `#F2F2F3` primary fill ·
`#FFFFFF` headings · `#10161C` text on light fill · `#2A2E32` disabled fill.
Typography — headings **DM Serif Display** 400 (26 / 32 / 34 / 40 / 42 / 52px, line-height 1–1.05;
numerals 44–58px for times); body **Archivo** 400/500/600 (12 / 14 / 15 / 16 / 17 / 18 / 19 / 20 / 21px,
line-height 1.5–1.6); uppercase kickers 14px/600, letter-spacing .18em.
Spacing — screen gutter 22px; block rhythm 14 / 18 / 20 / 22 / 26 / 34px; grid gap 8px (photos),
10–12px (lists/slots).
Radius — **0 everywhere** (square corners are the system). Shadows — none; depth comes from
hairline borders, the scrim and `blur(1.5px)`.
Layout — 3-col photo grids and 2-col photo pairs use `repeat(n, minmax(0,1fr))`.

## Assets
- **Photography is placeholder.** `assets/ph1–6.png` are generated steel/charcoal plates standing in
  for real salon photos. Replace all 45 image slots with real shots: hero (portrait, 3:4), service
  thumbs (1:1, 76px), barber portraits (1:1), gallery (1:1), about pair (1:1), avatar (1:1).
- Icons: **Lucide**, stroke-width 1.5 (home, scissors, calendar, bell, sliders, chevron).
- Fonts: DM Serif Display + Archivo (Google Fonts). Ship them with the app rather than loading remotely.
- No logo asset yet; the "BV" monogram in 5n is a text placeholder.

## Screenshots
`screenshots/01…17-*.png` — one PNG per screen at 2× (402pt wide), full scroll length, in flow order:
01 Početna · 02 O nama · 03–06 booking steps 1–4 · 07 Zahtjev poslan · 08 Moji termini · 09 Usluge ·
10 Obavijesti · 11 Postavke · 12 Galerija · 13 Recenzije · 14 O aplikaciji · 15 Pravila korištenja ·
16 Modal otkazivanja · 17 Lightbox galerije. The two overlay screens (16, 17) are cropped to the
874pt viewport; the rest show the full scrollable content.

## Files
- `Salon App v2.dc.html` — all screens (option ids `5a`…`5q`).
- `assets/ph1–6.png` — placeholder photo plates.
- `screens-flat.html` — the same 17 screens as static, full-length HTML (no device frame, no JS);
  handy for side-by-side diffing while implementing.
- `screenshots/` — reference PNGs, see above.
- `ios-frame.jsx`, `image-slot.js`, `support.js` — prototype scaffolding only (device bezel,
  drop-in photo slots, renderer). **Do not port these.**
