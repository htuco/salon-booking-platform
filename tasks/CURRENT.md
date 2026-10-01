# Trenutni task: 53 — Vertikala `health` — masaža i fizioterapija

Puni task: [tasks/sprint-5/53-vertikala-health.md](sprint-5/53-vertikala-health.md) · učitan 2026-09-29

## Status

U toku (grana `feat/vertikala-health`, 2026-09-30).

## Ciljevi

- [x] ADR-0026: `warm_wellness` (masaža, nova) + `clinical_calm` (fizio, prepisan), Newsreader +
      Public Sans, izbor brandom; samo light, `health` bez galerije, shell ostaje bazni
- [x] `warm_wellness` i prepisan `clinical_calm` u `AppTheme` (neutrale iz handoffa, `AppFonts.newsreader`
      sa `opsz`, izbor brandom); pisma uz aplikaciju sa OFL licencom. CI: `core_ui` testovi
      (kontrast, a11y slotova, pismo po temi, pragovi brand uloga) zeleni na PR #121
- [x] Pack `health` i dva salona u `supabase/seed.sql` (terminologija §3, pravila §4, flagovi §5,
      `require_staff_choice` i u `salon_settings`, `terminology_override` masaže). Lokalno
      `tool/test_supabase.sh` od nule: pgTAP 716 PASS + svi REST/Deno; CI `Supabase tests` zelen
- [x] `serviceAccusative` u `VerticalTerms` → „Izaberite tretman / terapiju"; `core_domain`
      lokalno 88 PASS. `noteHint` i mjesto u padežu odgođeni (ADR-0026)
- [x] Tenanti `masazamostar` i `fiziozenica`: `tenant.yaml`, placeholder ikona i
      `google-services.json`, generisano (`gen_flavors`, launcher ikone, `gen_ios_flavors.rb`),
      sve tri CI matrice; `gen_flavors --check` ažuran; demo overrides za oba
- [x] Grep: nijedan `vertical ==` / `flavor ==` u ekranu (samo doc komentari koji to zabranjuju)
- [x] CI zelen na PR #121 (`5ad6895`): `Analiza, format i testovi` i `Supabase tests`
- [ ] APK i iOS build novih flavora — ti jobovi idu tek na push u `main`, ne na PR
- [ ] „Bilo ko od nas" nestaje u koraku 2 — **viđeno na ekranu** (traži Flutter mašinu)
- [ ] Snimci početne i zakazivanja, sva četiri tenanta, 402; barber i beauty isti kao prije
      (traži Flutter mašinu: `tool/run_tenant.sh mostar demo -d chrome`, isto za `zenica`,
      `vitez`, `travnik`)

## Napomene

- Pismo po temi, `AppFonts`, `AppSelectionColors` i `BrandRoles.derive` su došli iz taska 52
  (PR #120, mergan 2026-09-30); 53 ih samo koristi.
- **Hostovani projekat nema nove salone.** Seed se ne primjenjuje kroz `supabase db push`, pa
  `masazamostar` i `fiziozenica` na hostovanom backendu ne nađu svoj salon. Uživo provjera ide
  lokalno ili kroz `demo`; red na hostovanom traži pristup projektu (isti blok kao task 52).
- Seed namjerno nema admin naloge za nova dva salona ni fotografije — prazni okviri su
  predviđeno stanje. `health` nema galeriju (`docs/05` §5, ADR-0026).
- `features.gallery` flag se u klijentu nigdje ne čita — galerija se krije samo kad salon nema
  slika. Za `health` je to danas isto ponašanje; kad masaža dobije galeriju (override flagova),
  flag mora početi da se čita.
- **Van taska, kandidati za nove taskove** (ADR-0026 §Razmatrane opcije): dark varijanta tema,
  override feature flagova po salonu (galerija za masažu), više dužina po tretmanu,
  specijalizacija terapeuta, checkbox pristanka + polje napomene sa `noteHint`, oblik Početne
  iz handoffa (hero ispod, „Naš tim", sedmično radno vrijeme), onemogućeno dugme otkazivanja.
- Dart na ovoj mašini: `dart format` i `core_domain` testovi idu kroz Docker `dart:3.13`
  (isti Dart kao CI); `gen_flavors` sa zasebnim package configom; iOS generator u
  `ruby:3.3-slim` sa `xcodeproj` gemom (sistemski Ruby 2.6 ga ne može instalirati).
  `flutter_launcher_icons` dira `project.pbxproj` — vratiti i pustiti `gen_ios_flavors.rb`.
- Supabase CLI i Deno nisu instalirani — `npx -y supabase@2.117.0` i `npx -y deno` rade kao
  zamjena za `tool/test_supabase.sh`. Poslije `db reset` edge runtime zna ostati ugašen
  (503 u `rest_delete_account`); `supabase stop` pa skripta od nule to rješava.

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
