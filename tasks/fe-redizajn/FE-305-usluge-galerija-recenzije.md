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
- [x] Usluge: lista grupisana po kategoriji, sa trajanjem; cijena se poštuje `vertical.features.prices`
- [x] Galerija: grid **3** kolone (`prototype/ui/SPEC.md` 5l je jači od „2"), oštre ivice, lightbox iz [FE-204](FE-204-lightbox-galerija.md)
- [x] Slike lazy-loaded i keširane
- [x] Recenzije: brojčana ocjena i tanka linija, bez obojenih zvjezdica
- [x] Duge recenzije skraćene sa „Prikaži više"
- [x] Salon bez recenzija i salon bez slika imaju svoje prazno stanje, ne prazan ekran

## Zamke
- **Prazan okvir slike je predviđeno stanje, ne greška.** Beauty tenant namjerno ima uslugu bez
  fotografije da se to stanje vidi u demou; redizajn koji ga „popravi" placeholder slikom sakrije
  ono što se htjelo pokazati.
- `services_screen_test.dart` očekuje `CircularProgressIndicator` — sudar sa
  [FE-205](FE-205-ukidanje-default-flutter-indikatora.md), uskladiti redoslijed.

## Status

✅ **Gotovo, dokazano testovima.** Grana `feat/fe-305-usluge-galerija-recenzije`.

Pet od šest stavki je već bilo isporučeno kroz taskove 19–21 i FE-204/FE-205 (provjereno
čitanjem koda i postojećim testovima):
- **Usluge:** `groupServices` grupiše po kategoriji, red nosi `formatDurationLong`, a cijena ide
  iza `vertical.features.prices`. Testovi u `services_screen_test.dart` pokrivaju zaglavlja,
  „Ostalo" i vertikalu bez cijena. Očekivanje `CircularProgressIndicator` iz Zamki je FE-205 već
  okrenuo u `findsNothing`.
- **Galerija:** ima **3 kolone, ne 2.** `prototype/ui/SPEC.md` 5l kaže „3-col square photo grid",
  a `prototype/ui/` je jači od handoffa. Ćelije su kvadratne bez radiusa, a tap vodi u lightbox
  iz FE-204.
- **Slike:** `SliverGrid.builder` gradi samo vidljive ćelije. `PhotoFrame` ide kroz
  `CachedNetworkImage`, sa `memCacheWidth` po veličini ćelije i `maxWidthDiskCache: 1200`.
- **Ocjena:** broj „4,8" uz histogram od tankih traka u `onSurface`. `StarRating` je u boji
  teksta, ne brenda, i punu zvjezdicu razlikuje oblikom, ne bojom.
- **Prazna stanja:** `salon bez slika dobije poruku` i `salon bez ijedne ocjene ne crta „0,0 od 5"`.

**Urađeno u ovom tasku:** duge recenzije se skraćuju na 4 reda, uz „Prikaži više" / „Prikaži
manje" (`_Komentar` u `reviews_screen.dart`). Dugme se pojavi samo kad `TextPainter` na stvarnoj
širini kaže da tekst ne stane. Kratak komentar ga ne dobija, jer bi obećao sadržaj kojeg nema.
Meta je `AppSize.touchTarget`, a `Semantics(expanded:)` kaže čitaču ekrana da li je tekst otvoren.

**Dokaz (2026-09-23):**
- `apps/client`: `flutter test` → **254 pass, 1 skip**; `flutter analyze` → No issues found.
- Novi test `duga recenzija je skraćena, kratka nema „Prikaži više"`. Kad se uslov `predug`
  isključi, pada tačno taj test (`+8 -1`).

Na uređaju nije viđeno.
