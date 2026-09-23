# FE-303 — Ekran „Zahtjev poslan"

| | |
|---|---|
| **Epik** | FE-3 · Klijentski ekrani |
| **Aplikacija** | `apps/client` |
| **Procjena** | 0,5 dan |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | `apps/client/lib/src/features/booking/booking_success_screen.dart` · `prototype/ui/screenshots/07-zahtjev-poslan.png` · [task 37](../sprint-4/37-automatsko-potvrdjivanje.md) |

## Cilj
Potvrdni ekran sa rezimeom termina i izlazima na „Moji termini" / „Početna".

## Zatečeno stanje
**Kriterij iz handoffa je zastario i ne smije se prepisati.** Handoff traži „jasno naznačeno da je
termin **na odobrenju**, ne potvrđen" — to je bilo tačno dok je `book_appointment` uvijek pravio
`pending` red. Od [taska 37](../sprint-4/37-automatsko-potvrdjivanje.md) salon u `auto` modu dobija
termin koji je **već `confirmed`**, i ekran grana po `appointment.status`:

- `manual` → „ZAHTJEV JE POSLAN" / „Salon vas je vidio" / badge „Na čekanju"
- `auto` → „TERMIN JE POTVRĐEN" / „Termin je vaš" / badge „Potvrđeno"

Badge ide kroz `statusLabel`/`statusTone`, isti helper koji koriste kartica i detalj termina.
Widget test pokriva obje grane i negativno provjerava da stari tekst ne ostane.

## Definicija gotovog
- [x] Obje grane prerisane po handoffu; `auto` grana nema svoj canvas, pa zadržava oblik `manual` grane
- [x] Ekran **i dalje čita status**, nikad postavku salona — postavku klijent ne vidi
- [x] Back gesta vodi na početnu, ne nazad u booking flow
- [x] Stanje flowa se čisti na izlasku, ne pri otvaranju ekrana
- [x] Widget test za obje grane ostaje zelen

## Zamke
- **Ne vraćati hardkodirano „na odobrenju".** Greška je skupa u oba smjera: lažno „potvrđeno" šalje
  korisnika u salon koji ga ne očekuje, lažno „čeka potvrdu" ga ostavlja da čeka obavijest koja
  neće stići.
- Tekst `auto` grane ne smije obećati podsjetnik — reminder push ne postoji
  ([task 39](../sprint-4/39-push-na-androidu.md)).

## Status

**Gotovo, dokazano testom; na uređaju nije viđeno.** Grana `feat/fe-303-zahtjev-poslan`.

### Ekran je već bio po handoffu — kvar je bio back gesta

Hero, kicker, serif naslov, `SpecCard` sa statusom kroz `statusLabel`/`statusTone` i grananje
po `appointment.status` stoje od taska 37. Čišćenje flowa na izlasku, ne pri otvaranju, već je
bilo tu.

Nedostajala je back gesta: flow ide kroz `context.go`, pa ispod `/book/success` nema rute i
sistemski back na Androidu **zatvara aplikaciju**. Ekran sada nosi `PopScope(canPop: false)`
koji ide istim izlazom kao dugme — čisti flow i `lastBookingProvider`, pa `go` na Početnu.
Izlaz na Početnu je tako back gesta; handoff drugo dugme nema.

### Dokaz

- Novi test „back sa success ekrana vodi na Početnu i čisti flow" (`handlePopRoute`):
  ruta je `/`, `lastBookingProvider` je `null`. Sabotaža (`canPop: true`) daje
  `Expected: true, Actual: <false>` — back bi izašao iz aplikacije.
- Klijent **253 testa PASS**, `flutter analyze` čist.

### Ostalo za sljedećeg

- Back gesta nije pritisnuta na stvarnom Android uređaju.
- Canvas ima hairline iznad donjeg CTA-a; ekran ga nema. Oblik se rješava u
  [FE-503](FE-503-ciscenje-legacy-stilova.md)/[FE-504](FE-504-qa-prolaz.md), ako se potvrdi na uređaju.
