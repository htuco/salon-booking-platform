# Trenutni task: 11 — Client: booking flow (4 koraka + success)

Puni task: [`tasks/sprint-1/11-booking-flow.md`](sprint-1/11-booking-flow.md) · Sljedeći na redu · Grana: još nije otvorena

## Status

Task 10 je gotov; PR [#11](https://github.com/htuco/salon-booking-platform/pull/11) čeka merge —
v. Istoriju. **Task 11 još nije počet**: `/task start` otvara granu sa svježeg `main`-a, nakon što
PR #11 uđe.

Ovo je **najveći ekranski task sprinta** i jedini koji piše u bazu. Sve do sada je bilo čitanje;
ovdje prvi put ide `book_appointment` i prvi put postoji utrka za isti termin.

## Šta je spremno, a šta nije

**Availability engine iz taska 05 je gotov i dokazan na CI-ju** — `get_available_slots`,
`get_available_dates`, `book_appointment` i exclusion constraint `appointments_no_overlap`.
Availability logika je isključivo u bazi; Dart je ne smije ni dotaknuti.

**`core_api` nema `AppointmentRepository`** i nema nijedan upis. Ovaj task ga uvodi — poziv ide na
RPC funkciju, nikad `insert` sa klijenta (`.claude/docs/security.md`).

**Home ekran je uspostavio šablon** koji ovaj task nasljeđuje: podaci iz providera, tekst kroz
`vertical.terms` i `.arb`, tri stanja prije sretnog slučaja. Detalji su u doc komentaru
`apps/client/lib/src/features/home/home_screen.dart` i u `.claude/docs/conventions.md`.

**Komponente koje postoje**: `AppButton`, `ServiceCard`, `TimeSlotChip`, `StatusBadge`,
`EmptyState`, `SkeletonLoader`. **Ne postoje** (`docs/02 §16`): `AppTextField`, `DateStrip`,
`StepProgressBar`, `AppBottomSheet`. Booking flow traži bar `DateStrip` i `StepProgressBar` —
pišu se u `core_ui` sa tokenima, ne kao ad-hoc widgeti u ekranu.

**`flutter_animate`/`confetti` nisu u `pubspec.yaml`** — DoD ih traži za success ekran.

## Zamke koje su već poznate

**Iskušenje ovog taska je "privremeno" filtrirati slotove u Dartu.** To je tačno ono što task 05
postoji da spriječi. DoD traži provjeru pretragom, ne pretpostavkom.

**`409 Conflict` je prvoklasno stanje**, ne generička greška — poruka i automatski povratak na
osvježenu listu slotova. `ApiError` već ima `ConflictError`; `switch` nad `sealed` tipom će oboriti
build tamo gdje nije obrađen.

**Home tap na uslugu već vodi na `/book/service?serviceId=<id>`.** Ruta postoji i URL je ispravan,
ali tijelo je `PlaceholderScreen`. Ako prvi korak ne pročita taj query parametar, preselekcija
usluge iz `docs/02 §3` tiho ne radi — izgleda ispravno, a korisnik bira uslugu dvaput.

**`pumpAndSettle` ne radi na ekranu sa skeletonom.** Puls se ponavlja dok je vidljiv, pa test
istekne i kad je ekran ispravan. Svi testovi koji podižu `/` koriste `pump()`; isto važi za svaki
ekran ovog flowa.

**Podatkovni provideri se moraju override-ovati u svakom widget testu** koji podiže app. Otkad `/`
nije placeholder, provider bez override-a napravi repozitorij i posegne za `Supabase.instance`,
kojeg u testu nema.

**Login se traži tek na kraju flowa** (`docs/06 §1.1`) — ne stavljati guard na `/book/*`. Broj
telefona se ne traži nigdje.

**Screenshot nalazi ono što testovi ne mogu.** U tasku 10 je zelena suita propustila plavi status
badge preko zlatnog brenda; u tasku 07 praznu bijelu stranicu. Vizuelna provjera ide kroz
`lib/demo_main.dart` (v. `.claude/docs/workflows.md`).

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
- **10 — Client home sa runtime brandingom** (2026-09-11) — `/` je prvi pravi ekran: hero, usluge, tim, radno vrijeme, kontakt i sticky CTA, sve iz `core_ui` komponenti i isključivo iz providera. **Prvi dokaz slikom**: isti web build, dva `SALON_ID`-a, razlika u imenu, bojama (zlatna tamna naspram roze svijetle) i terminologiji ("Zakaži termin" naspram "Rezerviši termin") — `docs/screenshots/task-10-home-*.png`. Dokazano na CI-ju ([run 34637330417](https://github.com/htuco/salon-booking-platform/actions/runs/34637330417)): 165 testova PASS (bilo 140), čista analiza, oba Android APK-a i oba iOS builda. Screenshot je našao grešku koju nijedan test nije mogao: živi status je bio `StatusBadge(tone: info)`, a statusne boje su brand-neutralne, pa je plava mrlja stajala preko oba brenda — sada ide u `primaryContainer`. Kontrast test je usput ispravljen na dva mjesta gdje je mjerio pogrešne parove (tekst na obojenoj površini, CTA usred Material prelaza — 2.13:1 na dugmetu koje je 8.07:1). **Ništa nije pokrenuto na uređaju i nijedan podatak nije došao sa stvarnog backenda** — `demo_main.dart` ih nosi prepisane iz `seed.sql`.
