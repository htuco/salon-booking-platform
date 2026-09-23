# Task 43 — Korak rezervacije po usluzi

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | `supabase/migrations/20260911090000_availability_engine.sql` · task [32](../sprint-3/32-usluge-i-cjenovnik.md) |

## Cilj
Kratka usluga ostavlja rupu koju niko ne može iskoristiti. Brada traje 15 minuta, korak salona je
15, pa termin u 11:00 završi u 11:15 — a sljedeći koristan početak je tek 11:30. Barber stoji 15
minuta koje sistem vodi kao slobodne.

## Odluka
**Korak se pomjera sa salona na uslugu.** `services` dobija vlastiti korak; `salon_settings.slot_step_minutes`
ostaje podrazumijevani kad usluga svoj nema. Odbijene alternative i razlog: [ADR-0014](../../docs/adr/0014-korak-rezervacije-je-po-usluzi.md).

## Definicija gotovog
- [x] `services.slot_step_minutes` — nullable, `check` na razuman raspon, fallback na salonsku vrijednost
- [x] `get_available_slots` koristi korak usluge; `book_appointment` provodi isti ugovor
- [x] Admin editor usluge nudi korak, sa objašnjenjem šta mijenja i šta znači prazno
- [x] pgTAP: ista usluga sa korakom 15 i 30 daje različit broj slotova; prazan korak = salonski
- [x] Postojeće usluge ostaju netaknute — migracija ne mijenja nijedno ponašanje dok se korak ne upiše

## Zamke
- **Trajanje i korak nisu ista stvar.** Trajanje puni termin, korak bira dozvoljene početke. Usluga
  od 15 minuta sa korakom 30 je legitimna i namjerna.
- Ovo dira `get_available_slots`, dakle i klijentsku aplikaciju — regresija se vidi tek u booking
  flowu, ne u adminu.
- Snapshot termina (task 32) ne nosi korak i ne treba ga: korak utiče na **izbor** početka, ne na
  ono što je dogovoreno.

## Status (2026-09-24)

Gotov — [PR #103](https://github.com/htuco/salon-booking-platform/pull/103).

- Migracija `20260924120000_korak_po_usluzi.sql`: nullable `services.slot_step_minutes` (1–120),
  `get_available_slots` sa `coalesce(usluga, salon)` — jedino mjesto koje računa korak;
  `book_appointment` re-validira kroz njega. `create_service`/`update_service` dobili
  `p_slot_step_minutes` (stari potpisi obrisani).
- Dokaz: `supabase test db` **514 PASS** (`019` nosi 17); vraćen salonski korak obara 6.
  `melos run test` PASS, `flutter analyze` čist.
- **Viđeno uživo 2026-09-24** (lokalni stack): admin editor „Korak početaka" → „svakih 30 min" za
  Muško šišanje, sačuvano (`slot_step_minutes = 30`, ostale usluge NULL). Klijentski web, 29.09.:
  početci 09:00, 09:30, 10:00… Brada (bez koraka) i dalje 09:00, 09:15, 09:30 — salonski 15.
- Nakon merge-a: `supabase db push`, **prije** deploya admina — novi admin šalje
  `p_slot_step_minutes`, koji stara baza ne zna.

