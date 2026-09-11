# Trenutni task: 08 — `core_api`: freezed modeli + repozitoriji

Puni task: [`tasks/sprint-1/08-core-api-repozitoriji.md`](sprint-1/08-core-api-repozitoriji.md) · Učitano: 2026-09-11 · Grana: `feat/core-api-repozitoriji`

## Status

Gotov — CI zelen ([Flutter 34620424824](https://github.com/htuco/salon-booking-platform/actions/runs/34620424824),
[Supabase tests 34619433879](https://github.com/htuco/salon-booking-platform/actions/runs/34619433879)).
PR [#9](https://github.com/htuco/salon-booking-platform/pull/9) je još draft — zatvara ga `/task complete`.

## Ciljevi

- [x] `freezed` + `json_serializable` + `build_runner` podešeni — **u `core_domain`, ne `core_api`**
      (posljedica odluke o sloju, v. ADR-0006); `melos run codegen` + `codegen:watch`, dokumentovano
      u `.claude/docs/workflows.md`
- [x] Modeli javnog kataloga: `Salon`, `Service`, `Employee`, `EmployeeService`, `WorkingHour`,
      `SalonSettings` — `@JsonKey` prati `snake_case` iz šeme
- [x] `Appointment` sa tipiziranim `status`-om — `AppointmentStatus` enum sa `unknown` fallbackom
- [x] `SalonRepository.byId`, `ServiceRepository.forSalon`, `EmployeeRepository.forSalon`
      (+ `serviceLinksForSalon`), `WorkingHoursRepository.forSalon`, `SettingsRepository.forSalon`
- [x] Radi bez prijave — dokazano na CI-ju: `rest_public_catalog.ts`, **26 asercija bez
      korisničkog tokena** ([run 34619433879](https://github.com/htuco/salon-booking-platform/actions/runs/34619433879))
- [x] `core_api/src/errors/`: `ApiError` (`sealed`) → `NetworkError`, `NotFoundError`,
      `ConflictError`, `ServerError`, `MappingError`; `guard()` obavija svaki poziv
- [x] Riverpod provider po repozitoriju + `FutureProvider` po podatku, bez ručnog cache sloja
- [x] `mocktail` unit testovi: mapiranje iz stvarnih seed payloada + svaka klasa grešaka
- [x] Nula `supabase` importa u `apps/*` van bootstrapa — `supabaseClientProvider` prešao u `core_api`

## Napomene

**Šta već postoji.** `core_api` ima tačno jedan fajl —
[`vertical_repository.dart`](../packages/core_api/lib/src/vertical/vertical_repository.dart) iz
taska 06. Nema `errors/`, nema modela, nema providera u paketu. `freezed`, `json_serializable` i
`build_runner` **nisu u nijednom `pubspec.yaml`-u u repou** — ovaj task uvodi codegen prvi put, pa
uz njega ide i `.gitignore` za `*.g.dart`/`*.freezed.dart` (ili svjesna odluka da se commituju) i
korak u CI-ju prije `analyze`.

**`VerticalRepository` je šablon koji vrijedi preslikati**, ne zaobići: eksplicitno nabrojane
kolone umjesto `select('*')`, mapiranje izdvojeno u `@visibleForTesting` top-level funkciju (test
ne lažira cijeli PostgREST builder lanac), i jasna razlika između praznog rezultata i mrežne
greške. `core_api` već ima `mocktail` u `dev_dependencies`.

**Gdje živi model — task i `architecture.md` se ne slažu.** Korak 1 taska traži entitete u
`core_domain` i DTO/mapiranje u `core_api`; [`architecture.md:35`](../.claude/docs/architecture.md)
kaže da su "modeli" u `core_api`. Presedan iz taska 06 ide trećim putem — `Vertical` je u
`core_domain` i **ima** `fromJson`. Odluči prije prvog modela i uskladi dokument u istoj promjeni;
ako ostane kako je u `Vertical`, `core_domain` mora ostati bez `json_serializable` (paket je čist
Dart, bez Fluttera — v. komentar u njegovom `pubspec.yaml`).

**Šema je provjerena, DoD imena se poklapaju.** Svih šest tabela postoji u
`20260910090000_init_schema.sql`, i `grant select ... to anon` plus politike `public_salons` /
`public_active` pokrivaju baš njih — javni katalog stvarno radi bez tokena, pod uslovom da je
`salons.status = 'active'`. `services` i `employees` dodatno filtriraju `is_active`, pa model ne
treba to raditi ponovo.

**`appointments` nema `anon` politiku** — samo `staff_manage` (authenticated admin) i
`own_appointments`. `Appointment` model se ovdje piše za task 11 i admin; ne planiraj čitanje
termina kao anon, neće proći.

**Test payload za `Appointment` se ne može kopirati iz seeda.** `supabase/seed.sql` puni samo
`vertical_packs`, `salons`, `salon_builds`, `services`, `employees`, `employee_services`,
`working_hours`, `salon_settings` — nema `customers` ni `appointments`. Za ostalih šest modela DoD
vrijedi doslovno: kopiraj stvarni red.

**`apps/client` već krši zadnju DoD stavku.**
[`vertical_provider.dart:4`](../apps/client/lib/src/core/vertical_provider.dart#L4) uvozi
`supabase_flutter` zbog `supabaseClientProvider`-a. Taj provider pripada `core_api`-ju; prebaci ga
tamo dok se dodaju ostali provideri, inače stavka ostaje nečekirana.

**Vremena su lokalno zidno vrijeme salona.** `working_hours.start_time`/`end_time` su `time` bez
zone, `day_of_week` je ISO 1–7. Model ne smije parsirati u `DateTime` sa UTC-om "za svaki slučaj" —
to pomjeri radno vrijeme za sat i vidi se tek kad neko rezerviše.

**Prvi pravi mrežni poziv.** Task 07 je digao `Supabase.initialize`, ali ništa nije pozvano protiv
pravog backenda jer nema naloga. Ako naloga i dalje nema, integracioni smoke test iz koraka 4 ide
na CI (`supabase/` stack), a ne lokalno — bez Dockera lokalno se dokazuje samo mapiranje.

## Istorija

- **01 — Skeleton repozitorija** (2026-08) — melos workspace, `apps/client`, `apps/admin`, `packages/core_*`, `supabase init`. `melos bootstrap`/`analyze`/`test` prolaze.
- **02 — Supabase šema + RLS** (2026-09-10) — 15 tabela, RLS na svakoj, `private.*` autorizacioni helperi, seed sa dva demo salona i tri vertikale. Dokazano na CI-ju: 38 pgTAP testova + 24 REST asercije sa dva stvarna JWT-a.
- **03 — Flavor sistem** (2026-09-10) — Android i iOS flavori za dva demo tenanta, ikone po flavoru, generatori u `tool/`. Dokazano na artefaktima: `aapt2 dump badging`, oba APK-a na istom emulatoru istovremeno, `CFBundleIdentifier`/`CFBundleDisplayName`/ikona iz gotovog iOS bundlea.
- **04 — CI pipeline** (2026-09-10, 🟡) — `tool/build_tenant.sh` kao jedina ulazna tačka u build, `release-artifacts` job pravi AAB za oba tenanta na ručni trigger, `BUILD_NUMBER` iz CI-ja stiže do artefakta (`versionCode='42'` naspram `'1'`). Ostaju keystore i stvarne Supabase vrijednosti — oboje traži naloge.
- **05 — Availability engine** (2026-09-11) — `get_available_slots`, `get_available_dates`, `book_appointment`, exclusion constraint `appointments_no_overlap`. Dokazano na CI-ju ([run 34542304820](https://github.com/htuco/salon-booking-platform/actions/runs/34542304820)): 66 pgTAP testova PASS. Availability logika je isključivo u bazi — nula u Dartu.
- **06 — VerticalPack** (2026-09-11) — `Vertical`/`VerticalTerms`/`BookingRules`/`VerticalFeatures` u `core_domain` (preveden na čist Dart), `VerticalRepository` u `core_api`, `verticalProvider` u `apps/client`; ekran uzima tekst iz `vertical.terms`. Dokazano na CI-ju ([run 34544339115](https://github.com/htuco/salon-booking-platform/actions/runs/34544339115)) i lokalno: 32 testa PASS, uključujući promjenu terminologije bez rebuilda app-e i parsiranje stvarnog `seed.sql`; uz testove prolaze i oba Android APK-a i oba iOS builda. **Sprint 0 je time gotov.**
- **07 — App plumbing** (2026-09-11) — `AppEnv`/`AdminEnv`, `bootstrap()` sa `Supabase.initialize` i `x-salon-id` headerom, `go_router` u oba app-a po 01 §12, `.arb` lokalizacije. Dokazano: 44 testa PASS plus deep link u pravom Chromiumu nad web artefaktom. Browser je našao dvije greške koje je test suite propustila — praznu bijelu stranicu (env je tražio `SUPABASE_*`) i deep link koji tiho ne radi (`initialLocation` + `usePathUrlStrategy`); obje pokrivene testom.
