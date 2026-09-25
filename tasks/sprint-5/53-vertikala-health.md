# Task 53 — Vertikala `health` — salon za masažu

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [49](49-slike-usluga-i-radnika.md), [50](50-galerija-logo-cover.md) |
| **Blokira** | — |
| **Reference** | `docs/05` §3–5 · `/new-tenant` skill · `.claude/docs/tenant-factory.md` |

## Cilj
Salon za masažu dobija svoju brandiranu aplikaciju kao barber i beauty — demo tenant, isti kod,
razlika samo kroz vertikalu `health` i `tenant.yaml`.

## Definicija gotovog
- [ ] `vertical_packs` seed za `health`: terminologija, pravila i flagovi po `docs/05` (danas u seedu: barber, beauty, generic)
- [ ] Pravila po tabeli §4: korak 30 min, buffer 10, `requireStaffChoice: true` (booking flow ga već poštuje)
- [ ] Tema `clinical_calm` dotjerana — postoji u `AppTheme`, ali nije viđena ni na jednom tenantu
- [ ] Demo tenant salona za masažu kroz `/new-tenant`: `tenant.yaml`, seed red sa uslugama i terapeutima, sve tri CI matrice
- [ ] Nijedan `if (vertical == 'health')` u ekranu — razlika je podatak (`vertical.terms`, flagovi)
- [ ] CI zelen za novi flavor; snimci početne i zakazivanja uz barber i beauty

## Zamke
- Fizioterapija, SPA i veterinari su ista vertikala po `docs/05`, ali nisu cilj ovog taska —
  terminologija i pravila se pišu za masažu, bez posebnih polja za druge.
- `health` dijeli temu `clinical_calm` sa `dental`. Veći body font (`TODO(dental-tipografija)`) je
  dentalni zahtjev i ovdje se **ne** uvodi — zubari su van sprinta.
- „Bilo koji dostupan" mora nestati iz koraka 2 kad je `requireStaffChoice: true`; provjeri na
  ekranu, ne samo u testu.
- Pravi `google-services.json` ne ide u repo — novi flavor dobija placeholder kao i ostali.

## Status
Nije počet.
