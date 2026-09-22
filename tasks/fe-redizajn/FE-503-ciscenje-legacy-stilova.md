# FE-503 — Čišćenje legacy stilova

| | |
|---|---|
| **Epik** | FE-5 · Kvalitet i konzistentnost |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 1 dan |
| **Zavisi od** | FE-1xx, FE-3xx, FE-4xx |
| **Blokira** | — |
| **Reference** | `apps/admin/test/no_hardcoded_colors_test.dart` · `.claude/skills/cleanup/` |

## Cilj
Poslije migracije ekrana ne ostaje mrtav stilski sloj.

## Zatečeno stanje
Ovo je zadnji task epika po redoslijedu i **ne smije početi prije** nego što su ekrani prevedeni —
inače briše ono što još nije zamijenjeno. Konkretni kandidati nastaju tek tokom epika:

- stara pisma (Space Grotesk, JetBrains Mono, DM Serif Display, Archivo) i njihove OFL licence,
  ako [FE-102](FE-102-tipografija-barlow.md) prođe;
- `uses-material-design: true` i Material icon font, ako [FE-104](FE-104-ikone.md) prođe;
- zaobljene varijante komponenti i `borderRadius` koji nije `zero` ([FE-103](FE-103-skala-razmaka.md)).

## Definicija gotovog
- [ ] Nema neiskorištenih pisama, boja ni widgeta
- [ ] Grep provjere čiste: `Color(0x` van tokena, `fontFamily:` u ekranu, `borderRadius` koji nije `zero`
- [ ] Veličina bundla **nije porasla** u odnosu na stanje prije epika — izmjereno, sa brojem u status bloku
- [ ] `no_hardcoded_colors_test` prošireni ekvivalent postoji i za klijenta

## Zamke
- **Font se ne briše iz `pubspec.yaml` dok grep nad `lib/` nije čist.** Flutter ne prijavi
  nedostajuću porodicu kao grešku nego tiho supstituiše sistemskim pismom — i to se vidi tek na uređaju.
- Mjerenje bundla prije i poslije mora biti isti build tip na istoj platformi, inače broj ne znači ništa.

## Status

Nije počet.
