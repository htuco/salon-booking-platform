# Trenutni task: 43 — Korak rezervacije po usluzi

Puni task: [tasks/sprint-4/43-korak-po-usluzi.md](sprint-4/43-korak-po-usluzi.md) · učitan 2026-09-24

## Status

Gotov — čeka review i merge PR #103, pa `supabase db push`

## Ciljevi

- [x] Migracija: `services.slot_step_minutes int null`, `check between 1 and 120` (isti raspon kao salonski)
- [x] `get_available_slots` koristi `coalesce(usluga, salon)`; `book_appointment` ga već zove, pa provodi isti ugovor
- [x] Upis koraka kroz postojeći RPC usluge (task 32) + `core_domain` model + `core_api`
- [x] Admin editor usluge: polje „Korak" sa objašnjenjem i praznim = salonski
- [x] pgTAP: korak 15 vs 30 daje različit broj slotova, prazno = salonski, rezervacija van koraka odbijena
- [x] Viđeno uživo: klijentski booking flow nudi početke po koraku usluge
- [x] `security.md`/`IMPLEMENTATION.md` ako se mijenja ugovor RPC-a

## Napomene

- Zavisnosti nema. Ništa nije isporučeno ranije — `services` nema kolonu koraka.
- **Jedno mjesto računa korak:** `get_available_slots` u `20260914150000_admin_akcije_nad_terminima.sql`
  (`cfg.step = st.slot_step_minutes`). `book_appointment` re-validira kroz njega, pa promjena tamo
  pokriva i klijenta i admin ručni unos.
- ADR-0014 je odluka; ne otvara se ponovo.
- Zamka: trajanje ≠ korak. Snapshot termina ne nosi korak.

## Istorija

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
