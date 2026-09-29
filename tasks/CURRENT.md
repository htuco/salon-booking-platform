# Trenutni task: 53 — Vertikala `health` — masaža i fizioterapija

Puni task: [tasks/sprint-5/53-vertikala-health.md](sprint-5/53-vertikala-health.md) · učitan 2026-09-29

## Status

U toku (grana `feat/vertikala-health`, 2026-09-30).

## Ciljevi

- [x] ADR-0026: `warm_wellness` (masaža, nova) + `clinical_calm` (fizio, prepisan), Newsreader +
      Public Sans, izbor brandom; samo light, `health` bez galerije, shell ostaje bazni
- [ ] `warm_wellness` u `AppTheme` i `clinical_calm` prepisan: light neutrale iz handoffa, `AppFonts`
      (Newsreader + Public Sans), `AppSelectionColors`; `switch` ne kompajlira bez nove grane
- [ ] Newsreader i Public Sans kao OFL fajlovi u `apps/client/assets/fonts/` + `pubspec.yaml`
- [ ] `gen_flavors.dart` i komentar u `tenants.g.dart` prihvataju novu temu (danas
      `modern_barber` | `elegant_beauty`); `--check` zelen
- [ ] `vertical_packs` red `health` u `supabase/seed.sql`: terminologija §3, pravila §4
      (korak 30, buffer 10, `requireStaffChoice: true`, min unaprijed 12h, max 90 dana,
      otkaz 12h, pending 24h), flagovi §5
- [ ] `VerticalTerms`: `note.hint`, `service.acc`, `venue` u padežu (v. `prototype/masaza/README.md`);
      rečenica na `5d` bez zamjenice
- [ ] Dva tenanta kroz `/new-tenant` (masaža Mostar, fizio Zenica): `tenant.yaml`, seed salona
      sa uslugama i terapeutima, placeholder `google-services.json`, Android + iOS matrica
      u `flutter-build.yml`
- [ ] Grep: nijedan `vertical ==` / `flavor ==` u ekranu
- [ ] „Bilo koji dostupan" nestaje u koraku 2 — viđeno na ekranu
- [ ] Snimci početne i zakazivanja, sva četiri tenanta, 402; barber i beauty isti kao prije
- [ ] CI zelen za oba nova flavora

## Napomene

- **Dio platforme je već isporučen kroz 52** (PR #120, mergan u `main` 2026-09-30):
  `AppFonts` u `packages/core_ui/lib/src/tokens/typography.dart`, `AppSelectionColors`,
  `BrandRoles.derive` (OKLCH), `AppTheme.fonts`, Jost u `apps/client/pubspec.yaml`, ADR-0025.
  DoD stavke „`AppTheme` nosi par pisama" i „ADR pismo po temi" su time pokrivene.
- ADR-0025 danas stavlja `clinical_calm` na DM Serif + Archivo i kaže da se algoritam izvođenja
  za sve teme „vraća ako `health` handoff traži isto" — **traži** (`prototype/masaza/README.md`:
  tenant bira samo `primaryFill`, ostalo se izvodi). To ide u dopunu ADR-a.
- `clinical_calm` postoji u `app_theme.dart` i dijeli ga `dental`. Ako `health` dobija svoje
  teme, `clinical_calm` ostaje dentalu; dentalni veći font (`TODO(dental-tipografija)`) se ne uvodi.
- Šema već dozvoljava `health` (`check` u `20260910090000_init_schema.sql`) — **nema migracije**
  za sam pack. `require_staff_choice` postoji po salonu, a booking flow čita vertikalu kao fallback
  (`apps/client/lib/src/features/booking/booking_flow_provider.dart:120`).
- **Van ovog taska** (handoff ih traži, `prototype/masaza/README.md` §Sudari): više dužina po
  tretmanu, specijalizacija/iskustvo terapeuta (migracije), checkbox pristanka u koraku 4
  (`required_consents` postoji, ekran ne crta), „Pozovi studio" (task 58). Zapisati kao nove
  taskove, ne uvlačiti.
- Zamka: drugo pismo mijenja visinu redova — QA na 402 za obje nove teme.
- **Ova mašina nema Flutter** — Dart se dokazuje na CI-ju, snimci na drugoj mašini. Lokalno
  se dokazuje samo SQL dio (seed `health` packa i tenanta) kroz `supabase start && supabase test db`.
- Procjena: 4–5 dana ostaje; ADR i `AppFonts` su dijelom gotovi, ali handoff dodaje
  `VerticalTerms` ključeve i drugu temu, što task nije predvidio.

## Istorija

### 52 — Beauty tenant dotjeran (parkiran, kod u `main`-u)

[PR #120](https://github.com/htuco/salon-booking-platform/pull/120), mergan 2026-09-30. ADR-0025 (pismo i uloge izbora po temi, blur ostaje), paleta
`elegant_beauty`, `BrandRoles.derive`, `AppSelectionColors`, Jost; CI zelen (core_ui 119,
client 397, admin 470, `gen_flavors --check`). **Ostaje, sve traži nešto van ove mašine:**
snimci prije/poslije na 402 (Flutter), prave slike u seedu (izvor fotografija — prazno stanje
prebaciti, ne brisati, v. `supabase/seed.sql` ~65/84), `admin@beautystudiotravnik.test` na
hostovanom (pristup projektu), beauty build na Android uređaju.

### 51 — Čišćenje bucketa i prijava neprikladnog sadržaja (DoD ispunjen)

Spojen u `main` ([PR #116](https://github.com/htuco/salon-booking-platform/pull/116), #117, #118).
Sweep `cleanup-media` i prijava slike platformi (ADR-0024); na hostovanom migracija, oba cron joba,
obje funkcije, tajne i Vault, ručni sweep vraća `200`. **Ostaje na vlasniku projekta:**
`REPORT_WEBHOOK_URL` i probna prijava koja stiže u kanal platforme.

### 47 — Admin ljuska za radnika (gotov)

Spojen u `main` ([PR #107](https://github.com/htuco/salon-booking-platform/pull/107)) 2026-09-24.
Radnik dobija istu admin aplikaciju, suženu na Danas, kalendar i svoje termine. Bez migracije.
Time je Sprint 4 zatvoren.

### 46 — Uloga `employee` i sužena izolacija (gotov)

Spojen u `main` ([PR #106](https://github.com/htuco/salon-booking-platform/pull/106)) 2026-09-24.
Radnik čita i vodi samo svoje termine; `is_admin` netaknut. Poslije merge-a `supabase db push`.

### 45 — Kreiranje naloga za osoblje (gotov)

Spojen u `main` ([PR #105](https://github.com/htuco/salon-booking-platform/pull/105)) 2026-09-24,
migracija i `accept-staff-invite` na hostovanom projektu. Nalog osoblja nastaje iz koda poziva
(ADR-0023).

### 44 — Postavke i pravila salona jasnija (gotov)

Spojen u `main` ([PR #104](https://github.com/htuco/salon-booking-platform/pull/104)) 2026-09-24.
Objašnjenje i živi primjer uz postavke; četiri admin postavke koje nisu stizale do klijenta sada
stižu. Bez migracije.

### 43 — Korak rezervacije po usluzi (gotov)

Spojen u `main` ([PR #103](https://github.com/htuco/salon-booking-platform/pull/103)) 2026-09-24,
migracija na hostovanom projektu. `services.slot_step_minutes`, prazno = salonski; 514 pgTAP
asercija, viđeno uživo u adminu i klijentskom booking flowu.

### 42 — Neradni dan i zaključana prošlost (gotov)

Spojen u `main` ([PR #102](https://github.com/htuco/salon-booking-platform/pull/102)) 2026-09-24,
migracija na hostovanom projektu (`supabase db push`). `set_day_closed` otkazuje kroz
`cancel_appointment` i blokira cijeli dan; prošlost i danas-poslije-otvaranja odbija sa `PT400`.
497 pgTAP asercija, `melos run test` zelen, tok viđen uživo na admin webu.

### FE-403 — Kalendar termina (gotov)

Spojen u `main` ([PR #72](https://github.com/htuco/salon-booking-platform/pull/72)). Zahtjev na
odobrenju nosi isprekidan rub na mreži, u listi i u legendi — razlika **oblikom**, ne samo bojom.
309 testova PASS, viđeno na 1440×900, 402×874 i u tamnoj temi. Prekidač dan/sedmica i realtime
osvježavanje ostali **imenovan dug** — oba traže ADR jer ih `prototype/admin/SPEC.md` izričito
izostavlja. Time je admin blok FE-401…FE-406 zatvoren.

### FE-404 — Usluge, osoblje i klijenti (gotov)

Spojen u `main` ([PR #71](https://github.com/htuco/salon-booking-platform/pull/71)).
Terminologija po vertikali umjesto „Majstor" iz canvasa, zelen CI na oba joba.

### 39 — Push obavijesti na Androidu (gotov)

Zatvoren uživo 2026-09-22 i spojen u `main`: migracija za `auto` mod je na hostovanom projektu,
admin Firebase aplikacija i staff uređaj su registrovani, a push je dokazan u oba smjera. Zvuk i
vlastiti Android kanal spojeni su zasebno kroz PR #80. iOS push ostaje imenovan dug do Apple
developer naloga.

### 41 — Zakazivanje bez prijave se uklanja (gotov)

Zatvoren 2026-09-23 ([PR #100](https://github.com/htuco/salon-booking-platform/pull/100)): gost
uklonjen iz koda, `tenant.yaml`-a, šeme i admin postavki; `private.is_client()` odbija anonimnu
sesiju. 478 pgTAP asercija, 9 REST testova, `melos run test` i CI zeleni. `register_device` zadržava
push registraciju prije prijave. Nakon merge-a: `supabase db push`.

### 48 — Storage bucket po salonu (gotov)

Spojen u `main` ([PR #110](https://github.com/htuco/salon-booking-platform/pull/110)) 2026-09-26,
migracija na hostovanom projektu. Bucket `salon-media`, upis samo vlasniku salona iz prvog
segmenta putanje; 624 pgTAP, `rest_storage` 19 provjera.

### 49 — Vlasnik postavlja sliku usluge i radnika (gotov)

Spojen u `main` ([PR #112](https://github.com/htuco/salon-booking-platform/pull/112) i
[#113](https://github.com/htuco/salon-booking-platform/pull/113)) 2026-09-26. Upload iz admina u
`salon-media`, a klijent prikazuje sliku; viđeno uživo na Vitezu i beautyju. Dijalog osoblja piše
termin vertikale. Izbor iz galerije na uređaju je prebačen u 60.

### 50 — Galerija salona, logo i cover (gotov)

Spojen u `main` ([PR #114](https://github.com/htuco/salon-booking-platform/pull/114)) 2026-09-26,
migracija na hostovanom projektu. `set_salon_image` / `set_salon_gallery` (samo svoje slike,
konflikt dva taba je `PT409`), admin postavke i kartica galerije. 671 pgTAP, `rest_galerija` 26;
viđeno uživo na Vitezu i beautyju, 1440 i 402.
