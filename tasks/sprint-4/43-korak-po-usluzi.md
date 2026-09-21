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
- [ ] `services.slot_step_minutes` — nullable, `check` na razuman raspon, fallback na salonsku vrijednost
- [ ] `get_available_slots` koristi korak usluge; `book_appointment` provodi isti ugovor
- [ ] Admin editor usluge nudi korak, sa objašnjenjem šta mijenja i šta znači prazno
- [ ] pgTAP: ista usluga sa korakom 15 i 30 daje različit broj slotova; prazan korak = salonski
- [ ] Postojeće usluge ostaju netaknute — migracija ne mijenja nijedno ponašanje dok se korak ne upiše

## Zamke
- **Trajanje i korak nisu ista stvar.** Trajanje puni termin, korak bira dozvoljene početke. Usluga
  od 15 minuta sa korakom 30 je legitimna i namjerna.
- Ovo dira `get_available_slots`, dakle i klijentsku aplikaciju — regresija se vidi tek u booking
  flowu, ne u adminu.
- Snapshot termina (task 32) ne nosi korak i ne treba ga: korak utiče na **izbor** početka, ne na
  ono što je dogovoreno.

## Status

Nije počet.
