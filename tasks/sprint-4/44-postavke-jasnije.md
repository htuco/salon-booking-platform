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
- [x] **Objašnjenje uz svaku postavku** — jedna rečenica šta konkretno mijenja za klijenta
- [x] **Grupisanje po temama** — rezervacije, otkazivanje, obavještenja, prikaz — umjesto jedne liste
- [x] **Živi primjer** uz postavke koje se tiču vremena, na stvarnim brojevima: „sa 3 h klijent ne
      može otkazati termin u 9:00 poslije 6:00"
- [x] **`salon_policies` se uređuju iz admina** — otkazivanje, kašnjenje, kontakt; danas ih piše samo SQL
- [x] Widget test nad primjerom: promjena postavke mijenja i tekst primjera

## Zamke
- **Pravila su u dvije tabele, ne u jednoj** ([ADR-0009](../../docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md)):
  `app_policies` obavezuju firmu i **ne** ulaze u admin, `salon_policies` obavezuju salon i ulaze.
  Miješanje daje salonu da mijenja tekst koji obavezuje platformu.
- Sekcije se crtaju dinamično `01..NN`, ne šest zakucanih — v. task 21.
- Primjer koji se računa u Dartu je availability logika u aplikaciji. Neka bude **tekst** izveden iz
  postavke, ne izračunat slot.

## Status (2026-09-24)

Gotov — [PR #104](https://github.com/htuco/salon-booking-platform/pull/104).

- **Grupisanje i uređivanje `salon_policies` su isporučeni već u tasku 36** — kartice po temi i
  „Pravila salona" sa uređivanjem; provjereno na ekranu, nije rađeno ponovo.
- Rečenica uz svaki prekidač šta vidi klijent; živi primjer uz pet vremenskih polja
  (`settings_primjeri.dart`, tekst na terminu u 9:00, ne slot).
- **Nalaz i proširenje (odluka 2026-09-24):** klijent je granularnost, izbor majstora, raspon
  kalendara i cijene čitao iz vertikale — prekidači u adminu nisu mijenjali ništa. Sada
  `salon_settings` prvo, vertikala kao rezerva. „Dozvoli izbor majstora" je pisao
  `require_staff_choice = true` (obavezan izbor) → preimenovano u „Klijent mora izabrati majstora".
- Dokaz: `melos run test` PASS (admin 422, client 393), `melos run analyze` čist. Testovi postavljaju
  vertikalu i postavke suprotno, pa padaju na pogrešnom izvoru.
- **Viđeno uživo 2026-09-24:** admin → „Klijent mora izabrati majstora" uključen, „Prikaži cijene"
  isključen, sačuvano (`t|f` u bazi). Klijent: Početna bez cijena, korak 2 nudi samo Amara i Emira,
  bez „Bilo ko od nas". Primjer roka se na desktopu rezao na 4 reda — prošireno na 8, viđeno cijelo.

