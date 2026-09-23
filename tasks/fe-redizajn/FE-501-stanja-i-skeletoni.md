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
- [x] Skeleton umjesto spinnera za liste i kartice, u obje aplikacije
- [x] Nijedan ekran ne pokazuje prazan bijeli prostor tokom učitavanja
- [x] Greška: kratka rečenica i „Pokušaj ponovo"; nijedna tehnička poruka ni kod greške korisniku
- [x] Poruke iz `error_mapper` se koriste, ne zamjenjuju generičkim tekstom
- [x] Prazno stanje: jedna rečenica i relevantan CTA — ne ista rečenica na svim ekranima
- [x] Prazno stanje razlikuje „nema podataka" od „filter ništa ne vraća"

## Zamke
- **Skeleton koji ne liči na sadržaj koji dolazi je gori od spinnera** — sadržaj poskoči kad stigne.
- „Pokušaj ponovo" mora stvarno ponovo tražiti od baze, ne prikazati keširani neuspjeh.
- Greška i prazno stanje nisu isto. Lista koja je pala i lista koja je prazna izgledaju identično
  ako se obje riješe rečenicom „nema stavki" — a korisnik u prvom slučaju treba dugme.

## Status

✅ **Gotovo, dokazano testovima.** Grana `feat/fe-501-stanja-i-skeletoni`, PR #93. Šest
commitova, svaki zaokružen korak.

**1. Povlačenje za osvježavanje bez spinnera.** `AppRefresh` (`core_ui`) i `AdminRefresh`
(admin, namjerni blizanac jer admin ne uvozi `core_ui`). Gestu daje
`RefreshIndicator.noSpinner`, a umjesto spinnera ide hairline traka od 2 px, mirna uz
`reduce motion`. Zamijenjeno je svih 7 upotreba: klijentski „Moji termini" (**zatvara ostatak
FE-304**, PR #90) i pet admin ekrana. Admin guard `no_material_indicators_test` sada hvata i
`RefreshIndicator(`.

**2. Tehnička poruka ne ide na ekran.** Admin je na devet mjesta prikazivao `ApiError.message`,
a to je po ugovoru poruka za log („Greška baze (42P01)", „Neočekivana greška: …").
`displayMessage` u `core_api` propušta samo tekst pisan za čovjeka: mreža, konflikt i SQL
validacije sa `errcode 'PT…'`. Admin koristi `porukaGreske(e, opsta:)`.

**3. Greška nije prazno stanje.** Galerija, recenzije i pravila su pad upita crtali kao „nema
slika", „još nema recenzija" i „tekst nije dostupan". Galerija i pravila su to radili
**namjerno** (komentari „galerija je ukras", „korisniku je svejedno"). DoD ovog taska tu odluku
izričito obara, pa su komentari zamijenjeni obrazloženjem. „O aplikaciji" je na grešci
pokazivala tekst o pravilima, a „Moji termini" grešku bez retryja. Sve ide kroz `LoadError`:
rečenica po tipu greške, „Pokušaj ponovo" koji radi `invalidate`, i isti mirni oblik kao prazno
stanje. U adminu je retry falio na pet sekcija (dashboard ×2, pravila salona, izbor usluge,
detalj termina) i sada ide kroz `AdminLoadError`.

**4. Prazno stanje po ekranu.** Generička `bookingEmptyList` („Ovdje trenutno nema nijedne
stavke") je uklonjena. Korak usluga i korak radnika imaju svoju rečenicu i CTA na Početnu.
Test je otkrio da je prva verzija teksta za radnike („uslugu niko ne radi") bila netačna, jer
`_radniciZaUslugu` bez veza vraća sve radnike.

**5. Filter prema praznim podacima.** Admin klijenti i termini su već imali različite rečenice.
Dodat je izlaz: „Poništi pretragu", „Prikaži sve klijente", „Prikaži sve statuse". Polje pretrage
sada prati provider, pa poništavanje briše i upisani tekst.

**Dokaz (2026-09-23), svaki novi test provjeren sabotažom:**
- `packages/core_ui`: **87 pass**; `packages/core_api`: **134 pass**; `apps/admin`: **334 pass**;
  `apps/client`: **260 pass, 1 skip**. `flutter analyze` čist u sva četiri.
- Sabotaže: Material spinner u `AppRefresh` obara test (`+1 -1`); ugašena reduce-motion grana
  obara svoj test; vraćen `RefreshIndicator(` u jedan admin ekran guard prijavi sa fajlom i
  redom; `displayMessage` koji propušta svaki `ServerError` obara 3 `core_api` testa i 1 admin
  test; stara galerija i pravila obaraju 4 od 5 u `load_error_test`; stari dashboard obara oba
  nova testa; uklonjen `ref.listen` u pretrazi obara test klijenata.

**Izostavljeno, imenovano:**
- **`SnackBar`** nije diran. FE-205 ga je spomenuo uz `RefreshIndicator`, ali DoD FE-501 ga ne
  traži, a admin ima 45 poziva. To je zaseban posao, ako ga dizajn uopšte traži.
- **Spinner u `AppButton` (`loading: true`)** ostaje. To je radnja u dugmetu, ne učitavanje
  liste ni kartice, a admin za isto ima `AdminButtonBusy`.
- **Lokalni `_Greska` widgeti u adminu** (klijenti, termini, kalendar, usluge, radno vrijeme)
  već nude retry i nisu objedinjeni u `AdminLoadError`. To bi bio refaktor bez promjene
  ponašanja.

Na uređaju nije viđeno. Traka pri povlačenju je dokazana samo testom.
