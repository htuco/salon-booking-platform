# FE-501 — Stanja učitavanja, greške i prazna stanja

| | |
|---|---|
| **Epik** | FE-5 · Kvalitet i konzistentnost |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | [FE-205](FE-205-ukidanje-default-flutter-indikatora.md) |
| **Blokira** | — |
| **Reference** | `packages/core_ui/lib/src/components/` · `packages/core_api/lib/src/errors/error_mapper.dart` |

## Cilj
Jedan obrazac za učitavanje, grešku i prazno stanje, primijenjen na svim ekranima obje aplikacije.

## Zatečeno stanje
- [FE-205](FE-205-ukidanje-default-flutter-indikatora.md) **sklanja** spinnere; ovaj task postavlja
  ono što dolazi umjesto njih. Zato idu u paru — sam FE-205 ostavlja prazan bijeli prostor.
- `error_mapper.dart` već prevodi greške baze u poruke (`PT409` → „termin je upravo zauzet",
  `PT403` → istekao rok). Obrazac greške ne počinje od nule; počinje od toga da te poruke stignu na
  ekran u istom obliku svuda.
- Prazna stanja postoje neujednačeno — `bookingEmptyList` („Ovdje trenutno nema nijedne stavke")
  je generička rečenica koja se pojavljuje na više mjesta.

## Definicija gotovog
- [ ] Skeleton umjesto spinnera za liste i kartice, u obje aplikacije
- [ ] Nijedan ekran ne pokazuje prazan bijeli prostor tokom učitavanja
- [ ] Greška: kratka rečenica i „Pokušaj ponovo"; nijedna tehnička poruka ni kod greške korisniku
- [ ] Poruke iz `error_mapper` se koriste, ne zamjenjuju generičkim tekstom
- [ ] Prazno stanje: jedna rečenica i relevantan CTA — ne ista rečenica na svim ekranima
- [ ] Prazno stanje razlikuje „nema podataka" od „filter ništa ne vraća"

## Zamke
- **Skeleton koji ne liči na sadržaj koji dolazi je gori od spinnera** — sadržaj poskoči kad stigne.
- „Pokušaj ponovo" mora stvarno ponovo tražiti od baze, ne prikazati keširani neuspjeh.
- Greška i prazno stanje nisu isto. Lista koja je pala i lista koja je prazna izgledaju identično
  ako se obje riješe rečenicom „nema stavki" — a korisnik u prvom slučaju treba dugme.

## Status

Nije počet.
