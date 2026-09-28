# Trenutni task: 51 — Čišćenje bucketa i prijava neprikladnog sadržaja

Puni task: [tasks/sprint-5/51-ciscenje-bucketa-i-prijava-sadrzaja.md](sprint-5/51-ciscenje-bucketa-i-prijava-sadrzaja.md) · učitan 2026-09-27

## Status

DoD ispunjen, mergan kao [PR #116](https://github.com/htuco/salon-booking-platform/pull/116).
Na hostovanom projektu su migracija, oba cron joba, obje funkcije, tajne i Vault (2026-09-29).
Sweep je okinut ručno i vraća 200. Ostaje samo `REPORT_WEBHOOK_URL` vlasnika projekta i probna
prijava, pa se task zatvara. Puni status blok je u task fajlu.

## Ciljevi

- [x] Uživo u klijentu: zastavica u lightboxu — gost ide na prijavu i vraća se, prijavljen
      klijent šalje razlog, red se pojavi u `content_reports`
- [x] Uživo u adminu: zamjena slike → poslije sweepa u bucketu jedan fajl (zadnji DoD checkbox)
- [x] Poslije merge-a: `supabase db push`, deploy `cleanup-media` i `notify-content-reports`
- [x] Tajne i Vault (`.claude/docs/workflows.md` → „Workeri taska 51"), pa
      `private.call_worker('cleanup-media')` → 200
- [ ] `REPORT_WEBHOOK_URL` (vlasnik projekta)
- [ ] Probna prijava na hostovanom stiže u kanal platforme

## Napomene

- Odluke su u ADR-0024: sweep umjesto brisanja iz admina, prag 24h plus trigger koji odbija
  referencu na obrisan objekat, deaktivirana usluga čuva sliku, prijava samo sa naloga, salon je
  ne vidi, slika ostaje dok platforma ne odluči.
- Mašina koja je pisala task nema Flutter SDK. Supabase CLI i Deno rade kroz
  `npx -y supabase@2.117.0` i `npx -y deno@2`.
- Webhook traži `REPORT_WEBHOOK_URL` koji ima samo vlasnik projekta.

## Istorija

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
