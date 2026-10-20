# Trenutni task: 67 — Pisanje recenzija

Puni task: [tasks/zero-crisis/67-pisanje-recenzija.md](zero-crisis/67-pisanje-recenzija.md) · učitan 2026-10-20

## Status

U toku (grana `feat/pisanje-recenzija`, [PR #139](https://github.com/htuco/salon-booking-platform/pull/139), 2026-10-20). Kod, testovi i provjera uživo su gotovi; ostaje pregled, CI i deploy.

## Ciljevi

- [x] Migracija `20261020100000_pisanje_recenzija`: `reviews.appointment_id` i `auth_identity_id`,
      jedna po terminu, samo `completed`; `authenticated` gubi `insert/update/delete`
- [x] `submit_review`, `set_review_published` (tekst ne dira), `client_own`; agregat samo objavljene
- [x] Prijava recenzije kroz `content_reports` (ADR-0024), `notify-content-reports` zna za recenziju
- [x] Push `review_request` kad termin postane `completed`, tekst u `send-push`
- [x] Brisanje naloga: recenzija ostaje kao ocjena, ime i tekst nestaju
- [x] pgTAP `032` (43 asercije), 8 mutacija, svaka obara bar jednu; `006` usklađen
- [x] Klijent: „Ocijeni" na završenom terminu u „Moji termini", prijava recenzije na `/reviews`
- [x] Admin: `/more/reviews` — lista, sakrij / vrati
- [x] Dokumenti: `security.md`, `supabase/IMPLEMENTATION.md`, `architecture.md`, `docs/01` §12,
      `prototype/ui/README.md`, `prototype/admin/SPEC.md`, komentari „read-only" u kodu
- [x] Uživo (lokalni stack, web 402): Završen u Meluri → klijent ocijeni → 26 ocjena; Sakrij → 25
- [ ] CI zelen, pregled, merge u `develop`
- [ ] Deploy (Hamza): `supabase db push` za `20261020100000`, `supabase functions deploy send-push notify-content-reports`
- [ ] Push `review_request` na uređaju

## Napomene

- **Već isporučeno:** prosjek i broj na Početnoj i na `/reviews` čitaju `salon_rating_summary`
  (task 20, `salonRatingProvider`). Od ove stavke DoD-a ostaje samo osvježavanje poslije slanja.
- **Postojeći redovi** (seed, budući import) nemaju termin ni identitet. Ostaju takvi; nova kolona je
  nullable, a pisati bez termina može samo `service_role`.
- **Ime autora** pravi baza iz `auth_identities.display_name` („Nedim H."), ne klijent — inače bi
  klijent potpisao recenziju tuđim imenom.
- **Admin danas nema ekran recenzija** i canvas ga ne crta. „Salon sakriva" traži mjesto u Meluri, pa
  je `/more/reviews` po obrascu postojećih lista u „Još".
- Push poslije termina danas vodi na `/appointments` (`send-push`, `route`); isto važi i za
  `review_request` — tamo stoji „Ocijeni".
- Zamka iz `security.md`: nova funkcija traži `revoke ... from public, anon`; `not (A and B)` sa
  `client_salon_id()` je rupa kad nema headera.
- Poslije `git pull` na `develop` treba `flutter gen-l10n` u `apps/client` prije `melos run analyze`.

## Istorija

### 58 — Kontakt klijenta jednim tapom (PR otvoren, 2026-10-20)

[PR #138](https://github.com/htuco/salon-booking-platform/pull/138), spreman za pregled.
„Pozovi" i „Poruka" (Viber, WhatsApp) u detalju termina i profilu klijenta, samo uz broj; pravila u
`apps/admin/lib/src/core/kontakt.dart`. Pregled zatvoren u grani (`+387 061 …` gubi nulu, prekratak
broj nema link), admin 697. **Ostaje:** odobrenje i merge; sve tri akcije na Android uređaju.

### 66 — Registracija: ime, telefon i uslovi (spojen u `develop`, 2026-10-19)

[PR #136](https://github.com/htuco/salon-booking-platform/pull/136), ADR-0030. Registracija sa
imenom, telefonom i checkboxom; „Dopuni profil" poslije Apple/Google, za novu verziju uslova i
prije svakog slanja termina; kasni sudar na `unique(salon_id, phone)` se preskače
(`20261019120000`). pgTAP 888, klijent 667, admin 677. **Ostaje:** Hamza `supabase db push` za
`20261019120000`; „Dopuni profil" poslije prave Apple/Google prijave na uređaju; poređenje telefona
ne normalizuje prefiks (`061 …` naspram `+387 61 …`).

### 69 — Sedmični kalendar u Meluri (spojen u `develop`, 2026-10-19)

[PR #137](https://github.com/htuco/salon-booking-platform/pull/137). Sedmica u Meluri: mreža od 7
kolona na ≥ 840 px, lista po danima na telefonu, avatar radnika (slika ili inicijali na boji iz
`AdminPalette.radnici`), red odsutnih uz „Svi". Dva pregleda zatvorena u grani; admin 677, viđeno
uživo na demo buildu na 1440, 1024 i 402. Bez migracije, deploy ne treba. **Ostaje svjesno:** mali
mjesečni kalendar dana sa starim obrascem semantike (v. `conventions.md`).

### 56 — Push podsjetnici D-1 i H-3 (odložen, 2026-10-13)

Učitan pa vraćen: nema Android uređaja ni emulatora (treba API 36, arm64-v8a, Google Play image),
a fale dvije odluke (kad ide D-1, jedan ili dva prekidača). Nalazi su u status bloku task fajla.

### 64, 65 i 70 — istek, limit zahtjeva i istorija obavijesti (spojeno i deployano, 2026-10-13)

[PR #133](https://github.com/htuco/salon-booking-platform/pull/133),
[#134](https://github.com/htuco/salon-booking-platform/pull/134) i
[#135](https://github.com/htuco/salon-booking-platform/pull/135) su spojeni u `develop`. Sve tri
zajedno prolaze lokalno: 848 pgTAP, svi REST i Deno testovi, klijent 640, `core_api` 142.
Na hostovanom su tri migracije i `send-push`, a stari logovi su označeni pročitanim. Prvi prolaz
`expire-pending` (21:00) je `succeeded` i zatvorio je jedan stari `pending`.
**Ostaje:**
- uživo viđeni „Isteklo" u Meluri, poruka o punom limitu i Obavijesti na uređaju;
- redovi 65 i 70 u `tasks/zero-crisis/README.md` i status blokovi u task fajlovima.

### 55 — Prerada admin dashboarda (premješten u `polishing/`, 2026-10-13)

Danas, zahtjevi, raspored i panel viđeni uživo na demo buildu i na hostovanom (Amko, 1440).
**Ostaje:** Danas kao radnik na hostovanom i na telefonu. V. `tasks/polishing/55-prerada-dashboarda.md`.

### Sprint 5 zatvoren, otvoreni `zero-crisis/` i `polishing/` (2026-10-12)

Nedovršeno iz Sprinta 5 je premješteno: 52–55, 59–63 u `polishing/`, 56–58 u `zero-crisis/`.
Opseg do lansiranja je [ADR-0029](../docs/adr/0029-opseg-do-lansiranja-zero-crisis.md); novi
taskovi 64–90, brojevi po redoslijedu (73–80: produkcija od nule). Sljedeći predloženi task: **64 — istek neodgovorenih zahtjeva**.

### Tenant `authenticbarber` i popravke sa uređaja (spojeno u `develop`, 2026-10-13)

[PR #129](https://github.com/htuco/salon-booking-platform/pull/129) — Authentic Barbershop, Vitez;
salon, admin nalog i slike na hostovanom. [PR #130](https://github.com/htuco/salon-booking-platform/pull/130)
(na #129) — swipe nazad u booking flowu, nativni iOS prelaz (ADR-0028), prijava bez duplog koraka,
poruka za nepotvrđen email, test preklapanja termina. Oba spojena u `develop`. **Ostaje:** Confirm
email isključen na hostovanom.

### Grane: `main` je produkcija, `develop` integracija (2026-10-13)

Repo je javan; rulesetovi `main-zastita` (mijenja samo Hamza, kroz PR) i `develop-zastita` (PR sa
jednim odobrenjem). Pravila u `CLAUDE.md`, `ai-interaction.md` §4 i `TEAM_HANDBOOK.md` §2 i §6.

### 62 — Toast obavijesti u adminu (PR otvoren)

[PR #123](https://github.com/htuco/salon-booking-platform/pull/123), otvoren 2026-10-01. `AdminToast`
umjesto `SnackBar`-a u adminu, viđeno na 1440 i 402. **Ostaje:** hostovani projekat sa pravim
nalogom, CI zelen, merge.

### 61 — Moj profil u adminu (spojen, ostaje telefon)

[PR #122](https://github.com/htuco/salon-booking-platform/pull/122), mergan 2026-10-01, zajedno sa
tenantom `amkobarber` i popravkama za Flutter 3.47. Migracija `moj_profil` je na hostovanom,
viđeno na Amku. **Ostaje:** telefon sa kamerom.

### 53 — Vertikala `health` (spojen, ostaje ekran)

[PR #121](https://github.com/htuco/salon-booking-platform/pull/121), mergan 2026-10-01. ADR-0026,
teme `warm_wellness` i `clinical_calm`, pack `health`, tenanti `masazamostar` i `fiziozenica`.
**Ostaje:** APK/iOS build na `main`-u, „Bilo ko od nas" u koraku 2 viđeno na ekranu, snimci sva
četiri tenanta na 402. Hostovani projekat nema nova dva salona.

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
