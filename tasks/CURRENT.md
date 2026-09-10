# Trenutni task: 06 — `VerticalPack` + `Vertical` klasa u `core_domain`

Puni task: [`tasks/06-vertical-pack.md`](06-vertical-pack.md) · Učitano: 2026-09-10

## Status

Nije počet

## Ciljevi

Iz DoD-a taska, **samo ono što stvarno preostaje** — backend polovina je isporučena kroz [task 02](02-supabase-schema-rls.md) (v. Napomene):

- [ ] `packages/core_domain/lib/src/vertical/vertical.dart` — `Vertical` (`key`, `terms`, `defaultSettings`, `defaultTheme`) i `VerticalTerms`, freezed i immutable
- [ ] `VerticalTerms` pokriva svih 13 ključeva koji već postoje u seedu (`businessSingular`, `customerSingular/Plural`, `serviceSingular/Plural`, `staffSingular/Plural`, `appointmentSingular`, `bookCta`, `noteLabel`, `myAppointments`, `priceLabel`, `durationLabel`)
- [ ] `VerticalRepository` u `core_api` čita `vertical_packs` po `salonId` i **primjenjuje `salons.terminology_override` preko default-a vertikale**
- [ ] `verticalProvider` (Riverpod) izlaže trenutni `Vertical` cijelom stablu widgeta u `apps/client`
- [ ] Placeholder ekran koristi `vertical.terms.appointmentSingular` i dokazuje lanac baza → repo → provider → widget
- [ ] Konvencija zapisana tamo gdje se čita: `.claude/docs/conventions.md` je već nosi, dopuni je primjerom kad mehanizam proradi
- [ ] Test: promjena terminologije mijenja tekst **bez rebuilda app-a** (dokaz da je runtime, ne compile-time)

## Napomene

- **Backend dio DoD-a je već gotov** — provjereno u `supabase/migrations/20260910090000_init_schema.sql` i `supabase/seed.sql`:
  - `vertical_packs` tabela postoji sa `terminology`, `default_settings`, `default_theme`, `default_services`, `feature_flags`, `required_consents`
  - `salons.vertical_pack_key` (NOT NULL FK) i `salons.terminology_override` (nullable JSONB) postoje
  - seed sadrži **tri** vertikale: `barber`, `beauty`, `generic` — sa punom terminologijom i booking postavkama
  - Ostaje isključivo Dart strana. Procjena iz task fajla (2–3 dana) je zato pesimistična; realno 1–2.
- **Zavisnost koja nije u task fajlu:** `verticalProvider` traži Riverpod, kojeg u `apps/client` još nema. Ili prvo [task 07](sprint-1/07-app-plumbing.md), ili minimalni `ProviderScope` ovdje pa 07 preuzme.
- `Vertical` je čisti entitet i pripada `core_domain` — bez Fluttera i bez mreže. Mapiranje JSON-a i `terminology_override` merge idu u `core_api`.
- Pravilo bez izuzetka: nijedan string koji se razlikuje po vertikali ne smije ostati u `.dart` fajlu ekrana. Ako je u ekranu, ne može se promijeniti bez store submissiona.
- Rod je stvaran zahtjev, ne kozmetika: beauty seed već koristi "Klijentica" i "Stilistica". `terminology_override` po salonu postoji upravo zbog toga.
- Zašto ovaj task prije prvog ekrana: [01 §17](../docs/01-mvp-spec.md#17-build-order) ga zove "2–3 dana koje, ako se odgode, znače prepisivanje svakog ekrana".

## Istorija

- **01 — Skeleton repozitorija** (2026-08) — melos workspace, `apps/client`, `apps/admin`, `packages/core_*`, `supabase init`. `melos bootstrap`/`analyze`/`test` prolaze.
- **02 — Supabase šema + RLS** (2026-09-10) — 15 tabela, RLS na svakoj, `private.*` autorizacioni helperi, seed sa dva demo salona i tri vertikale. Dokazano na CI-ju: 38 pgTAP testova + 24 REST asercije sa dva stvarna JWT-a.
- **03 — Flavor sistem** (2026-09-10) — Android i iOS flavori za dva demo tenanta, ikone po flavoru, generatori u `tool/`. Dokazano na artefaktima: `aapt2 dump badging`, oba APK-a na istom emulatoru istovremeno, `CFBundleIdentifier`/`CFBundleDisplayName`/ikona iz gotovog iOS bundlea.
