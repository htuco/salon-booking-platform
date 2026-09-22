# FE-305 — Usluge, galerija, recenzije

| | |
|---|---|
| **Epik** | FE-3 · Klijentski ekrani |
| **Aplikacija** | `apps/client` |
| **Procjena** | 2–3 dana |
| **Zavisi od** | [FE-204](FE-204-lightbox-galerija.md) |
| **Blokira** | — |
| **Reference** | `apps/client/lib/src/features/services/`, `gallery/`, `reviews/` · `prototype/ui/screenshots/09-usluge.png`, `12-galerija.png`, `13-recenzije.png` |

## Cilj
Tri sadržajna ekrana: cjenovnik, galerija radova, recenzije.

## Zatečeno stanje
Sva tri foldera postoje. Tri ograničenja koja redizajn ne može zaobići:

- **Cijena se ne prikazuje uvijek.** `vertical.features.prices` odlučuje; ekran koji je uvijek crta
  pada na vertikali koja cijene nema.
- **Galerija nema tabelu.** Slike su `salons.gallery_urls`, jsonb niz, redoslijed niza je redoslijed
  prikaza ([ADR-0008](../../docs/adr/0008-galerija-ostaje-u-salons-gallery-urls.md)). Storage još nije
  postavljen — to je Sprint 5, ne ovaj epik.
- **Recenzije su read-only za klijenta.** `anon` i `authenticated` imaju samo `select`; pisanje ide
  kroz osoblje. Salon bez recenzija **nema red** u `salon_rating_summary` — ne red sa nulama, nego
  ništa, pa prazno stanje mora postojati.

## Definicija gotovog
- [ ] Usluge: lista grupisana po kategoriji, sa trajanjem; cijena se poštuje `vertical.features.prices`
- [ ] Galerija: grid 2 kolone, oštre ivice, lightbox iz [FE-204](FE-204-lightbox-galerija.md)
- [ ] Slike lazy-loaded i keširane
- [ ] Recenzije: brojčana ocjena i tanka linija, bez obojenih zvjezdica
- [ ] Duge recenzije skraćene sa „Prikaži više"
- [ ] Salon bez recenzija i salon bez slika imaju svoje prazno stanje, ne prazan ekran

## Zamke
- **Prazan okvir slike je predviđeno stanje, ne greška.** Beauty tenant namjerno ima uslugu bez
  fotografije da se to stanje vidi u demou; redizajn koji ga „popravi" placeholder slikom sakrije
  ono što se htjelo pokazati.
- `services_screen_test.dart` očekuje `CircularProgressIndicator` — sudar sa
  [FE-205](FE-205-ukidanje-default-flutter-indikatora.md), uskladiti redoslijed.

## Status

Nije počet.
