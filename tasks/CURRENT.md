# Trenutni task: 44 — Postavke i pravila salona jasnija

Puni task: [tasks/sprint-4/44-postavke-jasnije.md](sprint-4/44-postavke-jasnije.md) · učitan 2026-09-24

## Status

Gotov — čeka review i merge PR #104 (bez migracije)

## Ciljevi

- [x] Objašnjenje uz svaku postavku — rečenica šta mijenja za klijenta
- [x] Grupisanje po temama — već isporučeno u tasku 36 (kartice), provjereno
- [x] Živi primjer uz vremenske postavke (`settings_primjeri.dart`), tekst a ne slot
- [x] `salon_policies` se uređuju iz admina — već isporučeno u tasku 36, provjereno
- [x] Widget test: promjena roka mijenja tekst primjera
- [x] **Proširenje (odluka 2026-09-24):** klijent čita `salon_settings` za granularnost, izbor
      majstora, raspon kalendara i cijene; vertikala samo kao rezerva
- [x] Viđeno uživo: prekidač u adminu mijenja klijentski ekran

## Napomene

- Nalaz: četiri admin postavke nisu imale efekta u klijentu — čitao je vertikalu.
- „Dozvoli izbor majstora" je pisao `require_staff_choice = true`, što znači **obavezan**
  izbor; labela preimenovana u „Klijent mora izabrati majstora".

## Istorija

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
