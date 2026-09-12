# Trenutni task: 11 — Client: booking flow (4 koraka + success)

Puni task: [`tasks/sprint-1/11-booking-flow.md`](sprint-1/11-booking-flow.md) · U toku ·
Učitano ponovo: 2026-09-12 · Grana: `feat/booking-flow-ekrani`, draft PR [#18](https://github.com/htuco/salon-booking-platform/pull/18)
(ne-UI sloj je stigao ranije kroz PR #17 i mergovan je)

## Status

**Ekrani su gotovi i dokazani lokalno i slikom. Ostaje dokaz protiv prave baze.**

Ne-UI sloj je stigao ranije (PR #17). Ovaj rad je UI iznad njega: pet ekrana, slanje, dvije nove
`core_ui` komponente. 215 testova PASS, čist checkout prolazi, oba tenanta snimljena u Chromiumu.

Ono što **nije** dokazano i drži task na 🟡: `book(...)` nije nijednom pozvan protiv prave baze i
`409` nije izazvan uživo — oboje traži Supabase vrijednosti i prijavljenog korisnika (Sprint 2).

<details>
<summary>Zatečeno stanje na početku (provjereno u repou)</summary>

**Ne-UI sloj je bio gotov i na `origin/main`; UI sloj nije bio počet.** Task 11 je jedini otvoren task —
Sprint 1 nema ničega iza njega, a Sprint 2 nije raspisan. "Iduće po redu" je zato ostatak ovog
taska: četiri ekrana i success.

Provjereno u repou, ne prepisano iz statusa:

- `packages/core_api/lib/src/booking/booking_repository.dart` ima `availableSlots`,
  `availableDates`, `book` — sve tri na `rpc`.
- `apps/client/lib/src/features/booking/` ima `booking_flow_state.dart` i
  `booking_flow_provider.dart` (`bookingFlowProvider`, `availableSlotsProvider`,
  `availableDatesProvider`, `bookingDateOnlyProvider`, `bookingRequiresStaffChoiceProvider`).
- `apps/client/lib/src/core/router/app_router.dart` — svih pet `/book/*` ruta postoji kao
  `ClientRoute` enum, ali svaka vodi na `PlaceholderScreen`.
- `packages/core_ui/lib/src/components/` — šest komponenti; `date_strip` i `step_progress_bar`
  **ne postoje**.
- `apps/client/pubspec.yaml` — nema ni `flutter_animate` ni `confetti`.

</details>

## Ciljevi

- [x] Grana sa svježeg `origin/main` — `feat/booking-flow-ekrani`; draft PR ide uz prvi commit
- [x] `DateStrip` i `StepProgressBar` u `core_ui` — oba u `_DemoEkran`-u, pa prolaze postojeće
      provjere kontrasta i dodirne mete u obje palete
- [x] `flutter_animate` + `confetti` u `apps/client/pubspec.yaml`
- [x] `/book/service` — čita `?serviceId=`; pokriveno testom (regresija iz taska 10)
- [x] `/book/employee` — "bilo ko od nas" prvi; lista je presjek sa `employee_services`
- [x] `/book/slot` — datumi i slotovi iz providera; `date_only` grana pokrivena testom
- [x] `/book/details` — sažetak, napomena i slanje; bez polja za telefon
- [x] `/book/success` — `StatusBadge` "Na čekanju", konfete u brand bojama
- [x] `409` kao prvoklasno stanje: poruka, `ref.invalidate`, povratak na korak 3 sa zadržanim danom
- [x] Svaki ekran ima prazno / greška / učitavanje stanje
- [x] Svi tekstovi kroz `vertical.terms.*` i `app_bs.arb`
- [x] Widget testovi: 8 novih — prelaz, guard, preselekcija, prazan dan, `date_only`, `409`, success.
      **215 testova PASS** (bilo 205), analiza čista, format čist, `gen_flavors --check` ažurno
- [x] Vizuelni dokaz kroz `lib/demo_main.dart` za oba tenanta — svih pet ekrana u Chromiumu,
      `docs/screenshots/task-11-*`. **Našao grešku koju suita nije:** korak 2 je u demou
      prikazivao grešku jer `employeeServiceLinksProvider` nije bio override-ovan
- [x] `./tool/verify_clean.sh` prolazi iz čistog checkouta — 84 client testa iz praznog klona

## Napomene

**Grana u task fajlu je zastarjela.** `feat/booking-repozitorij-availability` je mergovan (PR #17),
kao i `chore/reorganizacija-dizajn-handoff` (PR #16). Lokalni `main` je iza — `git fetch` pa
`git switch main && git pull` prije nego što se otvori nova grana. Radna kopija je trenutno na
`chore/reorganizacija-dizajn-handoff`, jedan commit iza `origin/main`.

**Dizajn handoff je premješten.** Ekrani 5c–5g su sada u `prototype/ui/SPEC.md` (ne više u
`design/`), `prototype/wireframe/` je zamrznuti React prototip. Task fajl još pokazuje na
`prototype/wireframe/src/app/pages/BookingFlow.tsx` — to je referenca za flow, ne za izgled.

**`prototype/ui/SPEC.md` i `docs/06` se ne slažu oko koraka 4.** SPEC 5f crta "Apple / Google /
phone sign-in"; `docs/06 §3.1` i `docs/06 §1.1` kažu da se **broj telefona ne traži nigdje**
(push zamjenjuje SMS), a auth u cjelini dolazi tek u Sprintu 2. **Docs pobjeđuje na flowu**,
SPEC na obliku. Korak 4 je do Sprinta 2 sažetak + slanje sa guest/mock identitetom, bez
polja za telefon.

**SPEC 5e crta mjesečni kalendar, task traži `DateStrip`.** Uzmi oblik iz SPEC-a (grupisanje
AM/PM, hit target ≥ 44px, prošli dani neselektabilni), ali komponenta ide u `core_ui` sa
tokenima — hex iz handoffa je paleta jednog brenda.

**`customerId` još nema odakle doći.** `book(...)` ga traži, upis u `customers` nema validiranu
funkciju, a `book_appointment` je grantovan samo roli `authenticated`. Do Sprinta 2 zadnji korak
ide guest/mock putanjom — **struktura poziva ostaje ista**.

**CI je blokiran naplatom na `htuco` nalogu do 29.09.2026.** Crven CI nije greška u kodu. Dokaz
ide lokalno: `melos run analyze`, `melos run test`, `./tool/verify_clean.sh` (čist checkout,
hvata necommitovan fajl i codegen drift) i `./tool/test_supabase.sh` za bazu.

**Zamke koje su već platili raniji taskovi:**

- **Nula availability logike u Dartu.** Iskušenje je "privremeno" filtrirati slotove; task 05
  postoji da to spriječi. DoD traži provjeru `grep`-om, ne pretpostavkom.
- **Konflikt stiže kao `PT409`**, ne `409` — mapiranje je ispravljeno u ne-UI sloju, ali
  **ponašanje ekrana na 409 još nije izazvano uživo** (korak 4 iz Koraka taska).
- **Home tap već vodi na `/book/service?serviceId=<id>`.** Ako prvi korak ne pročita taj query
  parametar, preselekcija tiho ne radi i korisnik bira uslugu dvaput.
- **`pumpAndSettle` ne radi na ekranu sa skeletonom** — puls se ponavlja, test istekne i kad je
  ekran ispravan. Koristi `pump()`.
- **Svaki widget test koji podiže app mora override-ovati podatkovne providere**, inače
  repozitorij posegne za `Supabase.instance` kojeg u testu nema.
- **Screenshot nalazi ono što testovi ne mogu** — task 10 (plavi badge preko zlatnog brenda) i
  task 07 (prazna bijela stranica). Vizuelna provjera ide kroz `lib/demo_main.dart`.
- **Ekran zove providere, ne repozitorij.** Osvježavanje liste je `ref.invalidate(...)`; stanje
  flowa namjerno **ne** nosi listu slotova.

**Procjena ostatka: 2–3 dana** od izvornih 3–4 (ne-UI sloj je pojeo oko jedan dan).

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
