# Trenutni task: 50 — Galerija salona, logo i cover

Puni task: `tasks/sprint-5/50-galerija-logo-cover.md` · učitan 2026-09-26

## Status

U toku

## Ciljevi

- [ ] Migracija: RPC za logo/cover i RPC za galeriju (`security definer`, `private.is_admin`),
      galerija sa optimističkom provjerom zatečenog niza — drugi tab ne pregazi tiho prvi
- [ ] RPC prima samo URL iz `salon-media/<svoj salon_id>/<vrsta>/` (ili prazno) — nema tuđih ni
      vanjskih URL-ova
- [ ] pgTAP (pozitivno, tuđi salon, radnik, anon, konflikt) + Deno REST test; `supabase test db` zelen
- [ ] `core_api`: upis logo/cover/galerije + mapiranje konflikta u poruku
- [ ] Admin postavke: cover i logo umjesto „uskoro"; tekst da ikona i splash dolaze iz builda
- [ ] Admin editor galerije: dodaj, obriši, promijeni redoslijed; widget testovi
- [ ] Klijent: nova galerija i cover na početnoj i u lightboxu; prazna galerija = prazno stanje
- [ ] Uživo na oba tenanta (Vitez i beauty), 1440 i 402
- [ ] Dokumenti: `security.md`, `supabase/IMPLEMENTATION.md`, doc komentar `settings_screen.dart`

## Napomene

- **Put upisa ne postoji.** `authenticated` ima samo SELECT nad `salons` (task 36 oduzeo grant);
  pisanje ide isključivo kroz RPC. Kolone postoje od init migracije; `seed.sql` puni galeriju
  barbera, a beautyju ostavlja `[]`.
- ADR-0008: galerija ostaje jsonb niz, redoslijed = redoslijed niza. Task to izričito zadržava,
  pa `gallery_photos` **ne** nastaje.
- `security.md` („Postavke lokacije") i doc komentar `settings_screen.dart` tvrde da logo dolazi
  iz `tenant.yaml` — za `logo_url` to nije tačno (u `tenant.yaml` ga nema). Iz builda su **ikona
  i splash**. Ispraviti u istoj promjeni.
- Već postoji: `MediaRepository.upload` sa `MediaKind.galerija/logo/cover`, admin `SlikaPolje`
  (task 49), klijent `salonGalleryProvider` i `GalleryGrid`, `home_hero.dart` čita cover, admin
  sidebar i „Još" čitaju logo.
- Stari objekti nakon zamjene/brisanja su siročad — čisti ih task 51, ne ovaj.

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
