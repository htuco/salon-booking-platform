# Trenutni task: 10 — Client: home ekran sa runtime brandingom

Puni task: [`tasks/sprint-1/10-client-home-runtime-branding.md`](sprint-1/10-client-home-runtime-branding.md) · U toku · Grana: `feat/client-home-runtime-branding`

## Status

Task 09 je gotov i mergovan — v. Istoriju. **Task 10 je u toku** na grani
`feat/client-home-runtime-branding`.

Ovo je **prvi pravi ekran** i prvi end-to-end dokaz da lanac baza → repozitorij → provider → tema →
tekst radi: isti build sa drugim `SALON_ID` daje drugi salon, druge boje i drugu terminologiju, bez
ijedne izmjene koda.

## Ciljevi

- [ ] `/` prikazuje logo i cover, ime, vertikalno tačne naslove sekcija, usluge sa cijenom i
      trajanjem, tim i primarni CTA
- [ ] Svaki tekst koji se razlikuje po vertikali ide kroz `vertical.terms.*` — nijedan takav
      literal u `.dart` fajlu ekrana
- [ ] Ostali tekstovi (dugmad, greške, prazna stanja) idu kroz `.arb`
- [ ] Ekran radi bez prijave
- [ ] Tri stanja: skeleton, greška sa retryjem, prazno
- [ ] Slike kroz `cached_network_image`
- [ ] Dokaz: isti build, dva `SALON_ID`-a, dva screenshota — ime, boje **i** terminologija
- [ ] Web build iste rute radi i ima ispravan URL

## Šta je spremno, a šta nije

**Sve tri zavisnosti su na mjestu.** `core_domain` ima modele, `core_api` ima pet repozitorija i
Riverpod providere (`salonProvider`, `servicesProvider`, `employeesProvider`, `verticalProvider`),
`core_ui` ima temu i šest komponenti. Ekran ne treba ništa od toga da piše ponovo — korak 1 taska
izričito traži čitanje providera, ne direktan poziv repozitorija.

**Komponente koje postoje**: `AppButton`, `ServiceCard`, `TimeSlotChip`, `StatusBadge`, `EmptyState`,
`SkeletonLoader`. **Ne postoje** (`docs/02 §16`): `AppTextField`, `AppSelect`, `DateStrip`,
`StepProgressBar`, `AppBottomSheet`, `StatTile`, `ContactActionRow`. Ako home traži nešto od toga,
piše se u `core_ui` sa tokenima, ne kao ad-hoc widget u ekranu.

**`cached_network_image` nije u `pubspec.yaml`** — DoD ga traži, pa ga ovaj task uvodi.

**`PlaceholderScreen` je privremeno tijelo svake rute** i za `/` ga zamjenjuje ovaj task; ostale
rute ga zadržavaju do taska 11.

## Zamke koje su već poznate

**Ovo je prvi ekran, pa postaje šablon.** Šta god ovdje bude prečica — literal boja, literal string,
poziv repozitorija iz widgeta — bit će kopirano petnaest puta. Task to kaže izričito.

**Terminologija ide kroz `verticalOf(ref)`**, ne kroz `.arb` i ne kroz literal: CTA je
`terms.bookCta`, tim je `terms.staffPlural`, usluge su `terms.servicePlural`. `.arb` nosi samo ono
što je isto u svakoj vertikali (dugmad, greške, prazna stanja).

**`Theme.of(context)` u `build` metodi koja postavlja `MaterialApp` vraća Flutterov default.** Tijelo
mora biti zaseban widget. Ista zamka je pogodila i test u tasku 09 — `_temaEkrana` u
`tenant_theme_test.dart` zato čita `MaterialApp.theme` sa widgeta, a ne kroz `Theme.of` potomka koji
na prvom frameu još ne postoji.

**Tri stanja prije sretnog slučaja.** `docs/02 §14`: skeleton, ne spinner preko praznog ekrana;
greška je poruka plus retry; prazno stanje nije prazan ekran. `SkeletonLoader` i `EmptyState` već
postoje za to.

**Dokaz traži dva screenshota** — isti build, dva `SALON_ID`-a, vidljiva razlika u imenu, bojama **i**
terminologiji. To je prvi put u projektu da se nešto dokazuje slikom, i prvi put da se app stvarno
pokreće; task 09 je namjerno ostao na widget-test nivou.

## Istorija

- **01 — Skeleton repozitorija** (2026-08) — melos workspace, `apps/client`, `apps/admin`, `packages/core_*`, `supabase init`. `melos bootstrap`/`analyze`/`test` prolaze.
- **02 — Supabase šema + RLS** (2026-09-10) — 15 tabela, RLS na svakoj, `private.*` autorizacioni helperi, seed sa dva demo salona i tri vertikale. Dokazano na CI-ju: 38 pgTAP testova + 24 REST asercije sa dva stvarna JWT-a.
- **03 — Flavor sistem** (2026-09-10) — Android i iOS flavori za dva demo tenanta, ikone po flavoru, generatori u `tool/`. Dokazano na artefaktima: `aapt2 dump badging`, oba APK-a na istom emulatoru istovremeno, `CFBundleIdentifier`/`CFBundleDisplayName`/ikona iz gotovog iOS bundlea.
- **04 — CI pipeline** (2026-09-10, 🟡) — `tool/build_tenant.sh` kao jedina ulazna tačka u build, `release-artifacts` job pravi AAB za oba tenanta na ručni trigger, `BUILD_NUMBER` iz CI-ja stiže do artefakta (`versionCode='42'` naspram `'1'`). Ostaju keystore i stvarne Supabase vrijednosti — oboje traži naloge.
- **05 — Availability engine** (2026-09-11) — `get_available_slots`, `get_available_dates`, `book_appointment`, exclusion constraint `appointments_no_overlap`. Dokazano na CI-ju ([run 34542304820](https://github.com/htuco/salon-booking-platform/actions/runs/34542304820)): 66 pgTAP testova PASS. Availability logika je isključivo u bazi — nula u Dartu.
- **06 — VerticalPack** (2026-09-11) — `Vertical`/`VerticalTerms`/`BookingRules`/`VerticalFeatures` u `core_domain` (preveden na čist Dart), `VerticalRepository` u `core_api`, `verticalProvider` u `apps/client`; ekran uzima tekst iz `vertical.terms`. Dokazano na CI-ju ([run 34544339115](https://github.com/htuco/salon-booking-platform/actions/runs/34544339115)) i lokalno: 32 testa PASS, uključujući promjenu terminologije bez rebuilda app-e i parsiranje stvarnog `seed.sql`; uz testove prolaze i oba Android APK-a i oba iOS builda. **Sprint 0 je time gotov.**
- **07 — App plumbing** (2026-09-11) — `AppEnv`/`AdminEnv`, `bootstrap()` sa `Supabase.initialize` i `x-salon-id` headerom, `go_router` u oba app-a po 01 §12, `.arb` lokalizacije. Dokazano: 44 testa PASS plus deep link u pravom Chromiumu nad web artefaktom. Browser je našao dvije greške koje je test suite propustila — praznu bijelu stranicu (env je tražio `SUPABASE_*`) i deep link koji tiho ne radi (`initialLocation` + `usePathUrlStrategy`); obje pokrivene testom.
- **08 — `core_api` modeli i repozitoriji** (2026-09-11) — sedam modela u `core_domain` (odluka: [ADR-0006](../docs/adr/0006-modeli-u-core-domain.md)), pet repozitorija i `sealed ApiError` u `core_api`, svi Riverpod provideri; `supabaseClientProvider` prešao iz app-a u `core_api`. Codegen (`freezed`/`json_serializable`) ulazi prvi put, generisani fajlovi **nisu** u gitu. Dokazano na CI-ju ([Flutter 34620424824](https://github.com/htuco/salon-booking-platform/actions/runs/34620424824), [Supabase tests 34619433879](https://github.com/htuco/salon-booking-platform/actions/runs/34619433879)): 97 testova plus 26 REST asercija **bez korisničkog tokena** — javni katalog stvarno radi prije prijave. CI je uhvatio grešku koju lokalna suita nije: codegen treba svakom jobu koji kompajlira, ne samo `analyze`-u.
- **09 — `core_ui` theme factory** (2026-09-11) — `buildAppTheme` kao jedina funkcija koja pravi `ThemeData`, tokeni (razmaci, radijusi, trajanja, statusne boje kao `ThemeExtension`), šest komponenti, i fallback lanac `salons.primary_color → tenant.yaml → default` u `appThemeProvider`-u; `main.dart` više nema nijedan heks. Generator nosi branding boje u `tenants.g.dart` kao ARGB i validira `#RRGGBB` pri generisanju. Dokazano na CI-ju ([Flutter 34630719984](https://github.com/htuco/salon-booking-platform/actions/runs/34630719984)): **140 testova**, oba APK-a, oba iOS builda. `onPrimary` se bira poređenjem WCAG odnosa, ne pragom luminancije — zlatna `#C6A667` (luminancija 0.42) bi sa naivnim pragom dobila bijeli tekst i 2.6:1. Test u obje teme je našao roze cijenu sa 4.12:1: brand tekst je bio mjeren na `surface`, a kartica stoji na `surfaceContainer`. **Ništa nije pokrenuto na uređaju** — to prvi put traži task 10.
