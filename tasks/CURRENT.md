# Trenutni task: 07 — App plumbing: Riverpod, go_router, env i Supabase klijent

Puni task: [`tasks/sprint-1/07-app-plumbing.md`](sprint-1/07-app-plumbing.md) · Učitano: 2026-09-11 · Grana: `feat/app-plumbing`

## Status

U toku

## Ciljevi

- [ ] `bootstrap()` koji radi async inicijalizaciju prije `runApp` — u oba app-a
- [ ] `core/env/app_env.dart` — jedno mjesto za sve `--dart-define` vrijednosti, **pada glasno**
      ako `SALON_ID` fali, umjesto da se to vidi kao tekst na ekranu
- [ ] `go_router` u oba app-a, rute po [01 §12](../docs/01-mvp-spec.md#12-screens)
- [ ] Web build daje prave URL-ove po ekranu
- [ ] `supabase_flutter` inicijalizovan jednom i izložen kao provider
- [ ] Klijent šalje `x-salon-id` na svaki zahtjev; **admin ga ne šalje**
- [ ] `intl` + `flutter_localizations`, `app_bs.arb` sa bar pet stvarnih stringova
- [ ] `apps/admin` prestaje biti `flutter create` counter demo
- [ ] `melos run analyze` i `melos run test` prolaze; `tenant_theme_test.dart` i dalje prolazi

## Napomene

- **Riverpod je već uveden u tasku 06** (`flutter_riverpod: ^2.6.1` u `apps/client`), zajedno sa
  `ProviderScope`, `tenantProvider`, `supabaseClientProvider` i `verticalProvider` u
  `apps/client/lib/src/core/vertical_provider.dart`. Ovaj task to **preuređuje**, ne piše ispočetka:
  `supabaseClientProvider` danas vraća `Supabase.instance.client` bez ijedne inicijalizacije.
- **`riverpod_generator` iz DoD-a je pod znakom pitanja.** Task ga traži, ali task 06 je namjerno
  izbjegao `build_runner` u `core_domain`. Ako se uvodi, uvodi se svjesno i samo u `apps/*`.
- **`tool/build_tenant.sh` već prosljeđuje `SUPABASE_URL`, `SUPABASE_ANON_KEY` i `API_URL`** kao
  `--dart-define` (linije 49–52) — env sloj treba čitati **ta** imena, ne izmišljati nova.
- **`x-salon-id` nije sigurnosna mjera** ([ADR-0003](../docs/adr/0003-x-salon-id-bira-kontekst-ne-daje-prava.md)) —
  sužava pogled, nikad ga ne proširuje. Nedostajući header daje **prazan rezultat, ne grešku**;
  to izgleda kao bug ("nema mojih termina") i prvo se provjerava header. Admin ga ne šalje jer
  njegova prava idu kroz `private.is_admin()`, a ne kroz kontekst.
- **Ekrani se u ovom tasku ne pišu.** Rute dobijaju placeholder tijela; sadržaj je 10 i 11.
  Ovdje se dokazuje kičma — da ruta postoji, da ima URL i da provider stigne do nje.
- **`tenant_theme_test.dart` traži `--dart-define=SALON_ID=<uuid>`** da bi uopšte radio nešto; bez
  definea se skipuje. Ako `AppEnv` počne da baca na prazan `SALON_ID`, taj test i `widget_test`
  (koji namjerno testira prazan slučaj) moraju i dalje prolaziti.
- Bez Supabase naloga nema pravog URL-a ni ključa, pa se `Supabase.initialize` dokazuje sa
  placeholder vrijednostima i testom da klijent **šalje header**, ne stvarnim odgovorom servera.

## Istorija

- **01 — Skeleton repozitorija** (2026-08) — melos workspace, `apps/client`, `apps/admin`, `packages/core_*`, `supabase init`. `melos bootstrap`/`analyze`/`test` prolaze.
- **02 — Supabase šema + RLS** (2026-09-10) — 15 tabela, RLS na svakoj, `private.*` autorizacioni helperi, seed sa dva demo salona i tri vertikale. Dokazano na CI-ju: 38 pgTAP testova + 24 REST asercije sa dva stvarna JWT-a.
- **03 — Flavor sistem** (2026-09-10) — Android i iOS flavori za dva demo tenanta, ikone po flavoru, generatori u `tool/`. Dokazano na artefaktima: `aapt2 dump badging`, oba APK-a na istom emulatoru istovremeno, `CFBundleIdentifier`/`CFBundleDisplayName`/ikona iz gotovog iOS bundlea.
- **04 — CI pipeline** (2026-09-10, 🟡) — `tool/build_tenant.sh` kao jedina ulazna tačka u build, `release-artifacts` job pravi AAB za oba tenanta na ručni trigger, `BUILD_NUMBER` iz CI-ja stiže do artefakta (`versionCode='42'` naspram `'1'`). Ostaju keystore i stvarne Supabase vrijednosti — oboje traži naloge.
- **05 — Availability engine** (2026-09-11) — `get_available_slots`, `get_available_dates`, `book_appointment`, exclusion constraint `appointments_no_overlap`. Dokazano na CI-ju ([run 34542304820](https://github.com/htuco/salon-booking-platform/actions/runs/34542304820)): 66 pgTAP testova PASS. Availability logika je isključivo u bazi — nula u Dartu.
- **06 — VerticalPack** (2026-09-11) — `Vertical`/`VerticalTerms`/`BookingRules`/`VerticalFeatures` u `core_domain` (preveden na čist Dart), `VerticalRepository` u `core_api`, `verticalProvider` u `apps/client`; ekran uzima tekst iz `vertical.terms`. Dokazano na CI-ju ([run 34544339115](https://github.com/htuco/salon-booking-platform/actions/runs/34544339115)) i lokalno: 32 testa PASS, uključujući promjenu terminologije bez rebuilda app-e i parsiranje stvarnog `seed.sql`; uz testove prolaze i oba Android APK-a i oba iOS builda. **Sprint 0 je time gotov.**
