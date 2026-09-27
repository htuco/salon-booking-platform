# Trenutni task: 51 — Čišćenje bucketa i prijava neprikladnog sadržaja

Puni task: [tasks/sprint-5/51-ciscenje-bucketa-i-prijava-sadrzaja.md](sprint-5/51-ciscenje-bucketa-i-prijava-sadrzaja.md) · učitan 2026-09-27

## Status

U toku — grana `feat/ciscenje-bucketa-i-prijava` sa `main` 06eda42 (2026-09-27). Zavisnost 48
je ✅ (#110); 49 i 50 su zatvoreni, pa sve vrste slika već pišu u bucket. Prvi korak je ADR.

## Ciljevi

- [ ] Odluka: čišćenje u istoj operaciji, periodično brisanje siročadi, ili oboje — i kome stiže
      prijava i ko odlučuje (ADR, jer se ne čita iz koda)
- [ ] Siročad nestaju: objekat u `salon-media/<salon>/<vrsta>/` koji nijedna kolona ne
      referencira se briše, **samo unutar prefiksa tog salona**
- [ ] Zamjena slike usluge, radnika, loga, covera i uklanjanje iz galerije ostavlja jedan fajl
- [ ] Prijava neprikladne slike iz klijentske galerije → platforma (ne salon), sa zapisom
- [ ] pgTAP/Deno: fajl bez reference nestaje, fajl sa referencom ostaje, tuđi salon netaknut
- [ ] Uživo: zamjena slike → jedan fajl u bucketu, ne dva
- [ ] `security.md` (novi objekti/politike) i task status blokovi

## Napomene

**Šta već postoji (provjereno na `main` 06eda42):**

- Bucket `salon-media`, javan, 5 MiB, jpeg/png/webp; putanja `<salon_id>/<vrsta>/<fajl>`,
  `private.storage_salon_id(name)` i četiri admin politike —
  `supabase/migrations/20260926100000_storage_bucket_po_salonu.sql`.
- Vrste su `MediaKind { usluge, radnici, galerija, logo, cover }` u
  `packages/core_api/lib/src/catalog/media_repository.dart`. Svaki upload dobija **novo ime**
  (CDN keš), pa svaka zamjena danas ostavlja siroče — komentar tamo eksplicitno čeka ovaj task.
  Mapa vrsta → kolona: `usluge`→`services.image_url`, `radnici`→`employees.image_url`,
  `galerija`→`salons.gallery_urls` (jsonb niz), `logo`→`salons.logo_url`,
  `cover`→`salons.cover_image_url`.
- `MediaRepository` nema nijedan `remove`; u kodu ne postoji ništa što briše objekat.
- Prijava sadržaja ne postoji nigdje (ni tabela, ni UI, ni funkcija).

**Zamke koje nisu u task fajlu:**

- **„Brisanje" usluge i radnika je `is_active = false`**, ne `delete`
  (`20260920120000_service_crud.sql`, `20260921140000_employee_crud.sql`). Deaktivirana usluga
  se može vratiti — ako se fajl obriše pri deaktivaciji, vraćena usluga ima mrtav URL. DoD stavka
  „brisanje usluge/radnika briše fajl" mora se protumačiti: prijedlog je da referenca iz
  neaktivnog reda i dalje čuva fajl, a fajl nestaje kad se `image_url` očisti ili zamijeni.
  Zapisati u ADR umjesto da se tiho suzi.
- **Direktan `delete from storage.objects` Supabase blokira** (`storage.protect_delete`) —
  red bi nestao, a fajl ostao u backendu. Brisanje mora ići kroz Storage API: Edge Function sa
  service role ključem (periodično, `pg_cron` + `pg_net` kao `dispatch_push` u
  `20260915140417_push_dispatch.sql`) ili `remove` iz admina poslije uspješnog RPC-a.
  Postojeće `expire-pending` / `send-reminders` su samo README stubovi, nisu uzor.
- Čišćenje iz admina poslije RPC-a nije dovoljno samo za sebe: prekinut upload (fajl gore,
  RPC nije prošao) ostavlja siroče koje niko ne referencira — zato je periodični sweep potreban
  bez obzira.
- Zatečeni seed URL-ovi (Unsplash) nisu u bucketu; sweep ide od objekata ka referencama, ne
  obrnuto, i nikad ne dira URL van `salon-media`.
- Sweep ne smije obrisati fajl koji je upravo uploadovan, a RPC još nije upisao referencu —
  treba prag starosti (npr. `created_at` stariji od sat vremena).
- Prijava: nema super admin konzole (`docs/01` §6.1 odgođen), a `staff_role` ima
  `super_admin` (`init_schema.sql`). Prijava mora u tabelu koju salon **ne čita** (RLS samo
  `private.is_super_admin()`), a platformi treba stići obavijest (email/Slack) — kanal je
  odluka za ADR. Klijent prijavljuje, anon vjerovatno ne (ADR-0024/task 41: nema gosta).
- Svaka promjena u `supabase/` → `security.md`, `rls-auditor`, lokalno `supabase test db` prije
  tvrdnje; CI `Supabase tests` na PR-u.
- Lokalno: `supabase` CLI nije na PATH-u u ovoj ljusci — provjeriti prije `/task start`.
  Storage kontejner mora biti iste verzije kao `supabase/.temp/storage-version`
  (`workflows.md`, treća zamka).

**Procjena:** 1–2 dana je tijesno — ADR + sweep funkcija + prijava (tabela, UI, obavijest) +
testovi. Realnije 2–3 dana.

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
