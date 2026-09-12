# Trenutni task: 11 — Client: booking flow (redizajn po `prototype/ui/`)

Puni task: [`tasks/sprint-1/11-booking-flow.md`](sprint-1/11-booking-flow.md) · U toku ·
Grana: `feat/booking-flow-ekrani`, PR [#18](https://github.com/htuco/salon-booking-platform/pull/18)

## Status

**Redizajn je gotov i dokazan slikom.** Ostaje ono što je i prije ostajalo: poziv protiv prave
baze i `409` uživo (Sprint 2), plus dvije sitnice iz napomena ispod.

<details>
<summary>Zatečeno stanje na početku ovog prolaza</summary>

**Flow radi, ali ne izgleda kao handoff.** Ekrani su pisani po tekstu iz `prototype/ui/SPEC.md`, a
ne po slikama iz `prototype/ui/screenshots/` — i razlika nije kozmetička: prototip je uglat sistem
(radius 0), sa serif naslovima, hairline granicama i drugim rasporedom koraka.

Ovo je drugi prolaz kroz iste ekrane: logika, provideri, rute i testovi ostaju, mijenja se **oblik**.
Boja i dalje dolazi iz `tenant.yaml`, tekst iz `vertical.terms` — iz handoffa se uzima oblik, ne
paleta (`prototype/ui/README.md`).

**Odlučeno prije početka:** tokeni se mijenjaju **sistemski u `core_ui`** (ne samo na booking
ekranima), i fontovi **DM Serif Display + Archivo se pakuju** u `apps/client/assets/fonts/`.

</details>

## Pravilo: barber je 1:1, ostale vertikale nisu

**Odluka (2026-09-12):** barber aplikacija mora biti **1:1 sa `prototype/ui/`, u najsitniji
detalj**. Beauty i ostale vertikale dobijaju **svoj dizajn**, pa se ne pokušava jedan raspored
razvući preko svih.

To je obrnulo raniji kompromis: copy i paleta više nisu izvedeni iz vertikale da bi bili tačni
svuda, nego prepisani iz handoffa. Konkretno:

- Naslov koraka 1 je **"Izaberite uslugu"** (bio: `vertical.terms.servicePlural`).
- Success naslov je **"Salon vas je vidio"** (bio: "Čekamo potvrdu").
- `modern_barber` neutrale su **tačne vrijednosti iz `SPEC.md`**, ne približne.
- Ikone su **Lucide** (`lucide_icons_flutter`), ne Material.
- Demo podaci nose **placeholder ploče iz handoffa**; produkcija ostavlja okvir prazan.

### Šta još nije 1:1

- **Zlatna brand boja ostaje** iako je handoff monohroman (primarni CTA `#F2F2F3`). Tvoja odluka,
  odgođena — to je danas jedina razlika u boji.
- **Usluge nemaju fotografiju.** `services` tabela nema `image_url`, pa red usluge ima prazan
  okvir dok migracija ne doda kolonu. Handoff traži thumb 1:1, 76 px.
- **Radnici nemaju godine staža.** Handoff piše "Barber · 9 godina"; `employees` nema to polje.
- **Ekrani `5a` Početna i `5b` O nama nisu rađeni po handoffu**, a `5h`–`5q` ne postoje.

## Ciljevi

- [x] **Fontovi** — DM Serif Display + Archivo u `apps/client/assets/fonts/` sa OFL licencama.
      Archivo je varijabilni (staticki rezovi ne postoje u izvoru), pa tezine idu kroz
      `FontVariation('wght', …)` — sam `fontWeight` na varijabilnom fontu zna ostati bez efekta
- [x] **Tokeni u `core_ui`** — `AppRadius.none` je jedina vrijednost (klasa sa jednom konstantom
      namjerno, da se 8 ne vrati "privremeno"), gutter 22, CTA 60, slot 58, ćelija 44, traka 5
- [x] **Tipografska skala** u `core_ui/tokens/typography.dart`, vezana u `buildAppTheme`
- [x] **Komponente**: `PhotoFrame`, `SelectableRow`, `CalendarMonth`, `SpecCard`; `TimeSlotChip`
      uglat i invertovan; `DateStrip` **obrisan** — bio je pogrešna komponenta za ovaj korak
- [x] **Korak 1** — izbor više ne vodi odmah dalje; zaključuje ga "Dalje" na dnu
- [x] **Korak 2** — `?` okvir za "bilo ko od nas", inicijal dok fotografija nema, ✓ kvadratić
- [x] **Korak 3** — mjesečni kalendar sa ‹ ›, pa "Prijepodne"/"Poslijepodne"
- [x] **Korak 4** — "Još jedan korak", kartica "Čuvamo vam", tri dugmeta za prijavu, pravna napomena
- [x] **Success** — hero, kicker, serif naslov, `SpecCard`, "Dodaj u kalendar" (neaktivno do
      Sprinta 2), CTA "Moji termini". **Konfete uklonjene**, `confetti` izbačen iz `pubspec.yaml`
- [x] Testovi prilagođeni — **215 PASS**, analiza i format čisti
- [x] Vizuelni dokaz: svih pet ekrana u Chromiumu na 402×874 (širina handoffa), oba tenanta —
      `docs/screenshots/task-11-*`

## Napomene

**Prototip i raniji izvori se na tri mjesta ne slažu — prototip je jači** (`CLAUDE.md`,
`prototype/CLAUDE.md`):

1. **Korak 3 nije traka datuma nego mjesečni kalendar.** `docs/02 §16` traži `DateStrip`;
   `05-korak3-vrijeme.png` crta mrežu 7×N sa ‹ › navigacijom po mjesecu. `DateStrip` iz prvog
   prolaza time postaje pogrešna komponenta.
2. **Korak 4 je ekran prijave, ne sažetak sa napomenom.** Prototip nema polje za napomenu; ima
   karticu "Čuvamo vam" i tri dugmeta za prijavu. Polje za napomenu iz prvog prolaza ispada.
3. **Success ekran nema konfete.** DoD ih traži "kao u prototipu", a prototip ih nema — ima hero
   fotografiju, kicker i tabelu. `confetti` zavisnost time postaje suvišna.

**Screenshot `05-korak3-vrijeme.png` je polupokvaren** — izvoz nije izrenderovao petlje, pa u njemu
stoje `{{ d.num }}` i `{{ t.label }}`. Struktura se čita iz `screens-flat.html`, ne iz te slike.

**Ranija zabuna je razriješena:** `SPEC.md` tabela za 5f spominje "phone sign-in", ali sam ekran
nudi samo Apple / Google / email. To se slaže sa `docs/06 §3.1` — telefon se ne traži nigdje.

**Fotografije su placeholderi** (`assets/ph1–6.png`, čelik/ugalj plate). Svih 45 slotova čeka prave
slike; do tada `PhotoFrame` crta praznu površinu sa hairline granicom, ne prazan prostor.

**Šta se ne dira:** provideri, `BookingRepository`, `BookingFlowState`, rute, `409` putanja i
guard. Sve to je dokazano u prvom prolazu i ostaje.

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
