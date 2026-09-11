# Tehnička arhitektura — struktura repozitorija i izbor paketa

Konkretan, izvodljiv referentni dokument: kako izgleda repo do nivoa foldera, i koji paket ide gdje. [01 §16](01-mvp-spec.md#16-tech-stack) i [04](04-flutter-tenant-factory.md) su odlučili *šta* (Flutter, Supabase, Next.js) — ovaj dokument odlučuje *čime tačno* se to piše.

| | |
|---|---|
| **Verzija** | v1 |
| **Datum** | 23.08.2026. |
| **Prati** | [01-mvp-spec.md §16](01-mvp-spec.md#16-tech-stack) · [04-flutter-tenant-factory.md §2](04-flutter-tenant-factory.md#2-struktura-repozitorija) · [06-auth-login-flow.md](06-auth-login-flow.md) |

---

## 1. Puna struktura repozitorija

Nadogradnja na skicu iz [04 §2](04-flutter-tenant-factory.md#2-struktura-repozitorija) — ovdje je i `supabase/` (nedostaje u 04, a to je backend izvor istine) i unutrašnjost svakog paketa.

```
salon_platform/
├── pubspec.yaml                     # root — Dart pub workspace (`workspace:` lista) + `melos:` config
├── analysis_options.yaml            # linting, dijeli se preko melos-a na sve Dart pakete
├── lefthook.yml                     # git hooks — Dart i Node u istom fajlu
│
├── apps/
│   ├── client/                      # N flavora, v. tenants/
│   │   ├── lib/
│   │   │   ├── main.dart            # čita SALON_ID + API_URL iz --dart-define
│   │   │   ├── bootstrap.dart       # Sentry, Supabase.initialize, ProviderScope
│   │   │   └── src/
│   │   │       ├── features/        # feature-first, ne layer-first
│   │   │       │   ├── booking/     # service → employee → slot → details → success
│   │   │       │   ├── auth/        # login, OTP, AuthConfig po platformi
│   │   │       │   ├── account/     # moj račun, brisanje računa
│   │   │       │   ├── appointments/# moji termini, otkazivanje
│   │   │       │   └── home/        # salon landing, usluge, tim, galerija
│   │   │       ├── core/
│   │   │       │   ├── router/      # go_router config, deep links /s/:slug
│   │   │       │   ├── theme/       # poziva core_ui theme factory sa runtime bojama
│   │   │       │   └── env/         # tipizovan pristup dart-define vrijednostima
│   │   │       └── l10n/            # bs.arb (jedini jezik za MVP, v. §3)
│   │   ├── android/app/src/<flavor>/# google-services.json, ic_launcher po tenantu
│   │   └── ios/flavors/<flavor>.xcconfig
│   │
│   └── admin/                       # jedna generička app, ista struktura features/core
│       └── lib/src/features/{dashboard,appointments,calendar,services,employees,settings}/
│
├── packages/
│   ├── core_domain/                 # čist Dart, nula Flutter/Supabase importa
│   │   └── lib/src/
│   │       ├── entities/            # Salon, Service, Employee, Appointment, ... (freezed)
│   │       ├── vertical/            # Vertical, VerticalPack, terminology
│   │       └── formatting/          # cijena, trajanje, datum — vertical-aware
│   │
│   ├── core_api/                    # jedini paket koji zna za Supabase
│   │   └── lib/src/
│   │       ├── datasources/         # SupabaseClient pozivi, edge function pozivi
│   │       ├── repositories/        # apstraktni interfejsi + Supabase implementacija
│   │       ├── models/              # freezed + json_serializable, mapiraju na core_domain
│   │       └── errors/              # AppException hijerarhija, mapiranje PostgrestException
│   │
│   └── core_ui/
│       └── lib/src/
│           ├── theme/               # ThemeFactory.fromColors(), onPrimary po luminanciji
│           ├── tokens/               # spacing, radius, typography scale
│           └── components/          # dugmad, kartice, bottom sheet, empty states
│
├── tenants/                         # build-time config po klijentu, v. 04 §3
├── tool/                            # new_tenant.dart, gen_flavors.dart, build_tenant.sh
│
├── supabase/                        # ⬅ backend izvor istine, nedostaje u dosadašnjim docs
│   ├── config.toml
│   ├── migrations/                  # 20260823120000_init_schema.sql, timestamp-first
│   ├── seed.sql                     # demo saloni iz 01 §14
│   ├── functions/                   # Edge Functions, Deno
│   │   ├── send-push/               # FCM HTTP v1 poziv
│   │   ├── expire-pending/          # pg_cron trigeruje, v. 01 §8
│   │   ├── send-reminders/          # D-1 / H-3, piše NotificationLog
│   │   └── dental-recall/           # v. 05 §9
│   └── tests/                       # pgTAP — RLS izolacija, v. 06 §4.4
│
└── web/                             # Next.js, svoj toolchain (pnpm), van melosa
    ├── app/
    │   ├── super-admin/             # salons, salons/new, salons/:id
    │   └── privatnost/[slug]/       # politika privatnosti po tenantu, obavezna za store
    ├── components/                  # shadcn/ui, v. §4
    └── lib/
        ├── supabase/                # @supabase/ssr klijenti (server + browser)
        └── database.types.ts        # generisano: supabase gen types typescript
```

**Feature-first, ne layer-first, u oba Flutter app-a.** Sa layer-first strukturom (`screens/`, `widgets/`, `providers/` na vrhu) svaka nova funkcionalnost dira tri direktorija. Feature-first znači da booking flow, auth i account žive svaki u svom folderu sa svime što im treba — i da je jasno gdje ide novi kod bez rasprave.

---

## 2. Ovaj repo danas — šta je prototip, šta ostaje

`prototype/wireframe/src/app/` u ovom repou (React + Vite) je **wireframe prototip**, ne production kod — potvrđeno u [README.md](../README.md).

**Ažurirano 12.09.2026:** prototip je **zamrznut**. Referenca za dizajn sistem nije postao on nego [`prototype/ui/`](../prototype/ui/README.md) — dizajnerski handoff sa 17 ekrana u punoj vjernosti. Prototip je premješten iz roota u `prototype/` zajedno sa svojim toolchainom, a `@mui/*` + `@emotion/*` su tada uklonjeni (prvi red tabele ispod je time zatvoren). Nalazi o ikonama i animacijama i dalje važe.

| Nalaz | Akcija |
|---|---|
| `package.json` ima **i** `@mui/material` + `@mui/icons-material` + `@emotion/*` **i** puni `@radix-ui/*` set. Provjereno: **0 importa** `@mui` bilo gdje u `src/` — mrtva težina iz Figma Make templatea. | Ukloni `@mui/*` i `@emotion/*` iz `dependencies`. Prototip koristi isključivo shadcn/ui (Radix + Tailwind), što se poklapa sa odlukom za super admin konzolu ([01 §16.2](01-mvp-spec.md#162-frontend--šta-u-čemu)). |
| `lucide-react` je već izabrana ikonografija u prototipu. | Zadrži je kao **jedini jezik ikona kroz cijeli sistem** — u Flutteru koristi `lucide_icons` paket (§3) da klijent app, admin app i web konzola dijele isti vizuelni rječnik ikona, ne tri različita seta. |
| `canvas-confetti` + `motion` (Framer Motion) postoje u prototipu za success ekrane. | Kad se prebacuje u Flutter: `confetti` + `flutter_animate` daju isti efekat (§3) — zadrži parodiju osjećaja, ne kod. |

---

## 3. Flutter paketi — konkretan izbor

Primjenjuje se identično na `apps/client` i `apps/admin` (dijele se preko `packages/*`).

| Namjena | Paket | Zašto ovaj, ne alternativa |
|---|---|---|
| **State management** | `flutter_riverpod` + `riverpod_generator` | Solo/mali tim: manje boilerplate-a od BLoC-a, testabilno bez `BuildContext`-a, i služi kao DI kontejner — ne treba ti odvojen `get_it` |
| **Routing** | `go_router` | Deklarativan, deep linking (`/s/:slug/book/service`), i **jedini** realan izbor za web build klijent app-a ([01 §16.2](01-mvp-spec.md#162-frontend--šta-u-čemu)) gdje URL mora odražavati ekran |
| **Backend klijent** | `supabase_flutter` | Auth + Postgrest + Realtime + Storage u jednom paketu, službeni SDK |
| **Serijalizacija / modeli** | `freezed` + `json_serializable` + `build_runner` | Immutable modeli, `copyWith`, union tipovi za `Appointment.status` — smanjuje klasu grešaka gdje se zaboravi ažurirati polje |
| **Push (foreground prikaz)** | `firebase_messaging` + `flutter_local_notifications` | FCM dostavlja poruku, ali foreground prikaz na oba OS-a traži lokalne notifikacije — FCM sam to ne radi kad je app otvorena |
| **Slike** | `cached_network_image` | Logo/cover/galerija sa Supabase Storage URL-ova; keširanje je obavezno jer se isti brend učitava na svakom otvaranju |
| **SVG** | `flutter_svg` | Ikone i brend asseti koji dolaze kao SVG iz dizajna |
| **Ikone** | `lucide_icons` | Poklapa se sa `lucide-react` iz web prototipa — jedan jezik ikona kroz sistem (v. §2) |
| **Animacije** | `flutter_animate` + `confetti` | Success ekran nakon potvrde termina — poklapa `motion`/`canvas-confetti` iz prototipa |
| **Kalendar (admin)** | `table_calendar` | Dnevni/sedmični pregled termina u admin app-u ([01 §12](01-mvp-spec.md#12-screens)) |
| **Lokalno skladište** | `shared_preferences` | `deviceId`, FCM token cache, "zapamti izbor jezika" — nema potrebe za `hive` dok nema offline-first zahtjeva |
| **App ikone / splash** | `flutter_launcher_icons` + `flutter_native_splash` | Generisano po tenantu iz `tenants/*/assets/`, v. [04 §7](04-flutter-tenant-factory.md#7-automatizacija--šta-mora-biti-skriptovano) |
| **Lokalizacija** | `intl` + `.arb` fajlovi | Samo `bs` za MVP, ali struktura mora postojati od početka — terminologija je već runtime kroz `VerticalPack` ([05](05-vertical-packs.md)), jezik app-a (dugmad, greške) ide kroz `.arb` |
| **Greške / crash tracking** | `sentry_flutter` | **Ne** `firebase_crashlytics` — Firebase ostaje strogo FCM-only ([01 §16.1](01-mvp-spec.md#161-odluka-supabase-ne-firebase-)), Sentry pokriva i Flutter i Next.js pod jednim dashboardom (§7) |
| **Linting** | `flutter_lints` (+ nekoliko `very_good_analysis` pravila ručno) | Jedan `analysis_options.yaml` u rootu, dijeli se preko melos-a |
| **Testiranje — unit/widget** | `flutter_test` + `mocktail` | `mocktail` umjesto `mockito` — bez code generation koraka |
| **Testiranje — integration/e2e** | `integration_test` | Booking flow end-to-end, i **generiše store screenshotove** ([04 §7](04-flutter-tenant-factory.md#7-automatizacija--šta-mora-biti-skriptovano)) |

---

## 4. Next.js paketi — super admin konzola i javne stranice

| Namjena | Paket | Zašto |
|---|---|---|
| **UI komponente** | shadcn/ui (Radix primitives + Tailwind, već u repou) | Već izabrano i implementirano u prototipu; gusti admin UI (tabele, forme, modali) |
| **Fetching / cache** | `@tanstack/react-query` | Salon lista, build status, invalidacija nakon mutacije — bez ovoga se piše ručni loading/error state svuda |
| **Tabele** | `@tanstack/react-table` | Lista salona sa filterima, sortiranjem, `SalonBuild` status pregled |
| **Forme** | `react-hook-form` (već u repou) + `zod` + `@hookform/resolvers` | Validacija forme za novi salon prije slanja — ista `zod` shema može validirati i na Supabase Edge Function strani |
| **Supabase klijent** | `@supabase/ssr` + `@supabase/supabase-js` | Server i browser klijenti za Next.js App Router; server komponente čitaju sa service role gdje treba mimoići RLS (super admin je iznad tenant izolacije) |
| **Grafovi** | `recharts` (već u repou) | Zadrži za dashboard analitiku (rezervacije po danu, no-show rate) |
| **Ikone** | `lucide-react` (već u repou) | V. §2 — jedinstven jezik ikona |
| **Tip generisanje** | `supabase gen types typescript` | `web/lib/database.types.ts` generisan iz stvarne šeme, ne pisan ručno — sprječava drift između migracije i koda |
| **Testiranje** | `vitest` + `@testing-library/react` (unit/komponente), `playwright` (e2e) | Playwright ima smisla ovdje jer prototip **jeste** booking flow koji se testira end-to-end; Chromium je već dostupan u CI okruženju |
| **Lint/format** | `eslint` + `typescript-eslint` + `prettier` + `prettier-plugin-tailwindcss` | Automatsko sortiranje Tailwind klasa, sprječava svađu oko reda klasa u PR review-u |

Ukloni iz `dependencies`: `@mui/material`, `@mui/icons-material`, `@emotion/react`, `@emotion/styled` — v. §2.

---

## 5. Supabase — struktura i konvencije

### 5.1 Migracije
- Fajlovi u `supabase/migrations/`, ime `<timestamp>_<opis>.sql` (npr. `20260823120000_add_customer_table.sql`) — generisano preko `supabase migration new <opis>`, nikad ručno preimenovano.
- **Nikad `ALTER` direktno na produkciji.** Tok je: lokalni Supabase (Docker) → migracija → `supabase db push` na staging projekat → verifikacija → push na produkcijski projekat.
- Odvojeni Supabase projekti za `dev` / `staging` / `production` (ne sheme u istom projektu) — RLS greška na jednom ne smije ugroziti druge.

### 5.2 Edge Functions
Svaka funkcija je izolovana u svom folderu pod `supabase/functions/<ime>/index.ts`, Deno runtime:

| Funkcija | Okidač | Šta radi |
|---|---|---|
| `send-push` | Poziv iz drugih funkcija ili trigera | FCM HTTP v1 API poziv, piše `NotificationLog` |
| `expire-pending` | `pg_cron`, svakih 15 min | Termini u `pending` duže od `pendingExpiryHours` → `cancelled` |
| `send-reminders` | `pg_cron`, jednom dnevno + na sat | D-1 i H-3 reminderi, provjerava `NotificationLog` prije slanja ([01 §11](01-mvp-spec.md#11-database-entities)) |
| `dental-recall` | `pg_cron`, sedmično | Recall notifikacije za dentalnu vertikalu ([05 §9](05-vertical-packs.md)) |

`pg_cron` raspored se registruje **u migraciji** (`cron.schedule(...)`), ne ručno u Supabase dashboardu — inače nije reproducibilno između `dev`/`staging`/`production`.

### 5.3 Testiranje RLS-a
`supabase/tests/` — pgTAP testovi koji provjeravaju tenant izolaciju direktno na SQL nivou (npr. "korisnik salona A ne može SELECT-ovati `appointments` salona B"), plus Deno skripta koja hita REST API sa dva različita JWT-a i asertuje 403/prazan rezultat — v. [06 §4.4](06-auth-login-flow.md). Ovo se pokreće u CI-ju na svaku promjenu migracije, ne samo ručno.

---

## 6. Monorepo alati i konvencije

| Alat | Za šta |
|---|---|
| **melos** | Skripte kroz sve Dart pakete: `melos run analyze`, `melos run test`, `melos run build:all` (rebuild svih tenanata, v. [04 §8.1](04-flutter-tenant-factory.md#81-pravila-koja-se-ne-pregovaraju)) |
| **lefthook** | Git hook runner koji radi i za Dart i za Node u istom repou (husky je Node-only) — pre-commit: `dart format` + `flutter analyze` na dodirnute pakete, `eslint --fix` + `prettier` na `web/` |
| **Conventional Commits** | `feat:`, `fix:`, `chore:` — čita se u CI-ju za changelog i olakšava `git log` kad ima 6+ meseci istorije na jednom repou sa dva jezika |
| **CI/CD** | Codemagic za Flutter build/store matrix ([04 §8](04-flutter-tenant-factory.md#8-cicd)), GitHub Actions za `web/` (lint, test, deploy na Vercel) i za pgTAP/RLS testove na svaki PR koji dira `supabase/migrations/` |

**`versionName` je zajednički, `versionCode`/`buildNumber` je po tenantu** — već odlučeno u [04 §8.1](04-flutter-tenant-factory.md#81-pravila-koja-se-ne-pregovaraju), ponovljeno ovdje jer direktno utiče na CI matrix konfiguraciju.

### 6.1 Melos ≥7 — config je u `pubspec.yaml`, ne u `melos.yaml`
Stariji Melos (≤6) je koristio standalone `melos.yaml` + generisan `pubspec_overrides.yaml` po paketu. Od verzije 7 Melos se oslanja na **Dart native pub workspaces** (Dart SDK ≥3.6): root `pubspec.yaml` ima `workspace:` listu paketa (bez globova — [dart-lang/pub#4391](https://github.com/dart-lang/pub/issues/4391) — lista je eksplicitna) i `melos:` ključ sa onim što je ranije bilo u `melos.yaml`; svaki paket u workspace-u dobija `resolution: workspace` u svom `pubspec.yaml`. `melos bootstrap` tad samo pokreće `flutter pub get` u workspace-u, bez linkovanja preko `pubspec_overrides.yaml`.

---

## 7. Observability

| Sloj | Alat | Napomena |
|---|---|---|
| Flutter (client + admin) crash/error | **Sentry** (`sentry_flutter`) | Ne Crashlytics — Firebase ostaje FCM-only |
| Next.js error tracking | **Sentry** (`@sentry/nextjs`) | Isti projekat/organizacija kao Flutter — jedan dashboard za cijeli sistem, filtriran po `platform` tagu |
| Backend logovi | Supabase built-in log explorer (Postgres + Edge Function logovi) | Dovoljno za MVP obim; ne uvoditi Logflare/Datadog dok ne postoji stvaran volumen koji to opravdava |
| Poslovni signal (ne crash) | `NotificationLog` tabela ([01 §11](01-mvp-spec.md#11-database-entities)) | Već postoji u shemi — koristi je i za dashboard "koliko reminder-a je poslano/failovalo", ne samo za deduplikaciju |

---

## 8. Ključne odluke

| Odluka | Obrazloženje |
|---|---|
| Feature-first folderi u oba Flutter app-a, ne layer-first | Nova funkcionalnost živi na jednom mjestu; manje trenja pri dodavanju ekrana |
| `supabase/` je u glavnom repou, migracije su izvor istine | Bez ovoga schema drift između `dev`/`staging`/`production` je pitanje vremena |
| Riverpod umjesto BLoC-a | Manje boilerplate-a za solo/mali tim, dupla je uloga i state management i DI |
| `go_router` je obavezan, ne `Navigator` imperativno | Web build client app-a mora imati prave URL-ove po ekranu |
| Sentry za oba frontenda, Crashlytics nigdje | Čuva granicu "Firebase = samo FCM" iz [01 §16.1](01-mvp-spec.md#161-odluka-supabase-ne-firebase-) čistom |
| `lucide_icons` u Flutteru | Isti vizuelni jezik ikona kao `lucide-react` u web prototipu i super admin konzoli |
| Ukloniti `@mui/*` i `@emotion/*` iz `package.json` | Mrtva težina iz Figma Make templatea, 0 stvarnih importa, kolidira sa odlukom za shadcn/ui |
| `pg_cron` raspored se registruje u migraciji, ne ručno u dashboardu | Reproducibilnost između okruženja |
| pgTAP + Deno skripta za RLS izolaciju u CI-ju na svaki PR koji dira migracije | Tenant izolacija je poslovni rizik ([06 §4.3](06-auth-login-flow.md)), ne smije zavisiti od toga da se neko sjeti ručno testirati |
