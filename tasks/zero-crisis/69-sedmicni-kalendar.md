# Task 69 — Sedmični kalendar u Meluri

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | — |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | ADR-0029 · FE-403 (imenovan dug: prekidač dan/sedmica) · `prototype/adminv2/` |

## Cilj
Salon vidi cijelu sedmicu odjednom za planiranje. Primarno tablet i računar; na telefonu dnevni
prikaz ostaje default.

## Definicija gotovog
- [ ] Dizajn prije koda (handoff ili skica u `prototype/adminv2/`)
- [ ] Prekidač dan/sedmica; sedmica = 7 kolona sa terminima, blokadama i neradnim danima
- [ ] Tap na termin otvara isti detalj kao u dnevnom prikazu; tap na prazno nudi ručno zakazivanje
- [ ] Radnik vidi samo svoje termine i u sedmici
- [ ] Widget testovi za obje uloge; viđeno na 1440 i 402

## Status
U toku (grana `feat/sedmicni-kalendar`, 2026-10-14).
