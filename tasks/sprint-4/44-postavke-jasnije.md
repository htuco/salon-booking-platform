# Task 44 — Postavke i pravila salona jasnija

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [36](../sprint-3/36-postavke-lokacije.md) |
| **Blokira** | — |
| **Reference** | `prototype/admin/SPEC.md` prikaz `3i` `3t` · task [21](../sprint-2/21-obavijesti-o-aplikaciji-i-pravni-ekrani.md) |

## Cilj
Postavke su lista polja bez konteksta. Vlasnik ne zna šta koja mijenja za njegovog klijenta, pa ih
ne dira — ili ih dira i iznenadi se.

## Definicija gotovog
- [ ] **Objašnjenje uz svaku postavku** — jedna rečenica šta konkretno mijenja za klijenta
- [ ] **Grupisanje po temama** — rezervacije, otkazivanje, obavještenja, prikaz — umjesto jedne liste
- [ ] **Živi primjer** uz postavke koje se tiču vremena, na stvarnim brojevima: „sa 3 h klijent ne
      može otkazati termin u 9:00 poslije 6:00"
- [ ] **`salon_policies` se uređuju iz admina** — otkazivanje, kašnjenje, kontakt; danas ih piše samo SQL
- [ ] Widget test nad primjerom: promjena postavke mijenja i tekst primjera

## Zamke
- **Pravila su u dvije tabele, ne u jednoj** ([ADR-0009](../../docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md)):
  `app_policies` obavezuju firmu i **ne** ulaze u admin, `salon_policies` obavezuju salon i ulaze.
  Miješanje daje salonu da mijenja tekst koji obavezuje platformu.
- Sekcije se crtaju dinamično `01..NN`, ne šest zakucanih — v. task 21.
- Primjer koji se računa u Dartu je availability logika u aplikaciji. Neka bude **tekst** izveden iz
  postavke, ne izračunat slot.

## Status

Nije počet.
