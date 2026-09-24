# Trenutni task: 46 — Uloga `employee` i sužena izolacija

Puni task: [tasks/sprint-4/46-uloga-employee-i-izolacija.md](sprint-4/46-uloga-employee-i-izolacija.md) · učitan 2026-09-24

## Status

U toku — task 47, grana `feat/admin-ljuska-za-radnika`

## Ciljevi

- [x] `users.employee_id`, `is_employee`, `current_employee_id`
- [x] Politike: radnik čita svoje termine; ostalo admin-only ili javno čitanje
- [x] `set_appointment_status` / `cancel_appointment` samo za njegov termin
- [x] pgTAP `021` + REST `rest_employee_izolacija.ts` sa stvarnim JWT-om
- [x] `security.md` red za radnika
- [x] `rls-auditor` pregled — nalazi zatvoreni (deaktiviran radnik, krhko brojanje u `020`)

## Napomene

- Sljedeći: task 47 (admin ljuska za radnika) — zadnji u sprintu 4. Poslije toga nema
  raspisanih taskova; Sprint 5 (slike, ADR-0015) treba raspisati.
- Hostovani poslije merge-a: `supabase db push`.

## Istorija

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
