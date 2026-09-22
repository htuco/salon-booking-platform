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
- [ ] Obje grane prerisane po handoffu; `auto` grana nema svoj canvas, pa zadržava oblik `manual` grane
- [ ] Ekran **i dalje čita status**, nikad postavku salona — postavku klijent ne vidi
- [ ] Back gesta vodi na početnu, ne nazad u booking flow
- [ ] Stanje flowa se čisti na izlasku, ne pri otvaranju ekrana
- [ ] Widget test za obje grane ostaje zelen

## Zamke
- **Ne vraćati hardkodirano „na odobrenju".** Greška je skupa u oba smjera: lažno „potvrđeno" šalje
  korisnika u salon koji ga ne očekuje, lažno „čeka potvrdu" ga ostavlja da čeka obavijest koja
  neće stići.
- Tekst `auto` grane ne smije obećati podsjetnik — reminder push ne postoji
  ([task 39](../sprint-4/39-push-na-androidu.md)).

## Status

Nije počet.
