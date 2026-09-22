# FE-102 — Tipografija Barlow / Barlow Condensed

| | |
|---|---|
| **Epik** | FE-1 · Temelji i dizajn tokeni |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 2–3 dana |
| **Zavisi od** | **ADR o zamjeni pisama** (v. [README](README.md), odluka 1) |
| **Blokira** | FE-3xx, FE-4xx |
| **Reference** | `apps/admin/lib/src/core/theme/admin_typography.dart` · `prototype/admin/SPEC.md:54` · `prototype/ui/SPEC.md:110` |

## Cilj
**Barlow Condensed** za naslove, sekcijske oznake i navigaciju, **Barlow** za tijelo, forme i
dugmad — u obje aplikacije.

## Zatečeno stanje
Ovo nije prazan teren nego **zamjena dva zapakovana para pisama**:

- `apps/admin/pubspec.yaml:81` — **Space Grotesk** + **JetBrains Mono**, oba varijabilna
  (`SpaceGrotesk[wght].ttf`), težina se postavlja kroz `FontVariation`, ne kroz `fontWeight`.
- `apps/client/pubspec.yaml:115` — **DM Serif Display** + **Archivo**
  (`Archivo[wdth,wght].ttf`, dvije ose).
- Oba handoffa to **izričito propisuju**: `prototype/admin/SPEC.md:54` i `prototype/ui/SPEC.md:110`.
  `prototype/ui/SPEC.md:124` uz to traži da se pisma isporuče sa aplikacijom, ne učitavaju sa mreže —
  pravilo koje ostaje i poslije zamjene.
- Mono u adminu **nije dekoracija**: `SPEC.md:65` ga vezuje za inline podatak (vrijeme, iznos).
  Barlow nema mono rez, pa odluka mora reći šta biva sa tim slojem.

## Definicija gotovog
- [ ] ADR zapisan prije koda — zamjena pisama mijenja oba `SPEC.md`-a, pa se oni mijenjaju u istoj promjeni
- [ ] Barlow i Barlow Condensed zapakovani lokalno uz OFL licencu u istom folderu, bez mrežnog učitavanja
- [ ] `TextTheme` definisan po **stilovima** (`displayLarge`…`labelSmall`), ne po ekranima
- [ ] Nijedan widget ne postavlja `fontFamily` sam — provjereno grepom, kao što se boja već provjerava testom
- [ ] Odlučeno i zapisano šta nosi inline podatak u adminu kad JetBrains Mono ode
- [ ] Nema fallbacka na sistemsko pismo — provjereno na Androidu i iOS-u, ne samo u testu
- [ ] Minimalna veličina tijela na mobilnom 14px

## Zamke
- **Varijabilno pismo se ne postavlja `fontWeight`-om.** Admin tema koristi `FontVariation`; ko
  zamijeni pismo a ostavi `fontWeight`, dobije jednu težinu na svim mjestima i to izgleda kao
  namjerno dok se ne uporedi sa canvasom.
- **Condensed nije `fontStretch` nad Barlowom** nego zasebna porodica. Pogrešno vezivanje prolazi
  na Androidu (koji sam supstituiše) i pada na iOS-u.
- Uppercase + letterspacing `~0.1em` je stil, ne `toUpperCase()` nad stringom u kodu: veliko slovo
  upisano u tekst razbija čitače ekrana i prevod.
- Zamjena pisma mijenja visinu svakog reda. Ekrani koji su „taman stali" počinju prelijevati — zato
  FE-504 postoji i zato ide poslije.

## Status

Nije počet.
