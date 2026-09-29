# Trenutni task: 52 — Beauty tenant dotjeran

Puni task: [tasks/sprint-5/52-beauty-dotjeran.md](sprint-5/52-beauty-dotjeran.md) · učitan 2026-09-29

## Status

U toku (grana `feat/beauty-dotjeran`, 2026-09-29).

## Ciljevi

- [ ] **Odluka o pismu prije koda**: handoff (`prototype/beauty/README.md`) traži Jost za sav
      tekst, ADR-0019 kaže jedan par pisama. Ili ADR (pismo vezano za temu — isti ADR treba i 53),
      ili izričita odluka da beauty ostaje na DM Serif + Archivo
- [ ] Odluka o blur-u modala: handoff ga skida, a to dira `AppDialog` za sve teme
- [ ] Svježi snimci beauty flavora *prije* promjene (zadnji su od taskova 10–24, prije FE-5xx)
- [ ] Paleta `elegant_beauty` u `core_ui` (`AppNeutrals` u `app_theme.dart`) dotjerana po handoffu;
      brand uloge izvedene iz jedne boje po algoritmu iz handoffa, AA provjeren
- [ ] Prave slike usluga, radnika i galerije u seedu (sada `images.demo.invalid` za usluge,
      `null` za radnike, prazna galerija)
- [ ] `admin@beautystudiotravnik.test` na hostovanom projektu (ostatak taska 30)
- [ ] `auth.googleReversedClientId: ''` u beauty `tenant.yaml`, `gen_flavors.dart` pa `--check`
- [ ] Uživo: beauty build na Android uređaju — ime, ikona, boje, zakazivanje, push salonu
- [ ] Snimci poslije, uz barber za poređenje

## Napomene

- **Rod u terminologiji je već isporučen** kroz vertical pack `beauty` u `supabase/seed.sql`
  („Klijentica", „Stilistica", „Naš tim") — ne treba `terminology_override` na salonu. Mehanizam
  override-a postoji i testiran je (`packages/core_api/test/vertical_repository_test.dart`,
  `packages/core_domain/test/vertical_test.dart`). Ostaje samo provjeriti uživo da ekrani to pišu.
- Seed namjerno drži prazna stanja na beautyju (radnici bez slike, bez recenzija, bez „Kontakt").
  Kad beauty dobije slike, **prazan okvir mora ostati dokazan negdje** — komentari u
  `supabase/seed.sql` (oko reda 65 i 84) to traže; prebaci to stanje na jednu uslugu/radnika ili
  na barber, ne briši ga.
- Slike u seedu idu u `salon-media` (task 48); siročad čisti sweep taska 51 — seed ne smije
  referencirati objekat koji ne postoji (trigger iz ADR-0024 ga odbija).
- Hostovani admin nalog nije provjeren ovom sesijom: Supabase MCP nema access token. Task 30 je
  zadnji zabilježio da ne postoji (`400` na `/auth/v1/token`).
- Sirova `#B76E79` kao `primary` pada AA sa bijelim tekstom (~3.8:1). Hex ne ide u ekran.
- Pismo: task 53 počinje ADR-om koji veže par pisama za temu — ako 52 bira Jost, taj ADR je
  zajednički i piše se jednom.
- Zavisnosti 49 i 50 su ✅.

## Istorija

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
