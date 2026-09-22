# FE-104 — Ikone: jedan set, jedna debljina linije

| | |
|---|---|
| **Epik** | FE-1 · Temelji i dizajn tokeni |
| **Aplikacija** | `apps/client` (admin ostaje na Materialu) |
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | ~~ADR o setu ikona~~ — **pao**, [ADR-0017](../../docs/adr/0017-lucide-je-set-ikona-klijenta-material-ostaje-u-adminu.md) |
| **Blokira** | — |
| **Reference** | `prototype/ui/SPEC.md:51` · `packages/core_ui/lib/src/components/` |

## Cilj
Jedna debljina poteza i svedene veličine u **klijentskoj** aplikaciji. Set je odabran:
Lucide u klijentu i `core_ui`-ju, Material ostaje u adminu (ADR-0017).

## Zatečeno stanje

**Ovaj odjeljak je 2026-09-22 ispravljen — ranija verzija je bila netačna i po njoj je task
izgledao mnogo veći nego što jeste.**

Ranije je pisalo „116 upotreba `Icons.*`" i da „za Lucide ne postoji ništa u `pubspec.yaml`
nijedne aplikacije". Izmjereno stanje:

- `lucide_icons_flutter: ^3.1.19` **je** u `apps/client/pubspec.yaml:68` i
  `packages/core_ui/pubspec.yaml:20`; uvezen u 12 fajlova klijenta i četiri `core_ui` komponente.
- Ukupno `Icons.*` je **109, ne 116**, i **71 je u `apps/admin`/`packages`** — admin se po
  ADR-0017 **ne prevodi**, pa to nije dug ovog taska.
- **Zamka u brojanju:** `lucide_icons_flutter` svoju klasu zove **`Icons`**, isto kao Material.
  Zato `grep "Icons\."` u klijentu daje 34 pogotka, ali su **`Icons.scissors`, `Icons.cloudOff`,
  `Icons.calendarX`, `Icons.chevronRight` itd. već Lucide.**
- **Stvarni Material ostatak u klijentu su četiri upotrebe dvije ikone**, prepoznatljive po
  `snake_case` imenu:
  - `Icons.cloud_off_outlined` — `about_screen.dart:57`, `home_screen.dart:470`,
    `services_screen.dart:91`
  - `Icons.inbox_outlined` — `services_screen.dart:80`
- `uses-material-design: true` stoji u **oba** `pubspec.yaml`-a.

## Definicija gotovog
- [x] ADR bira nosioca — [ADR-0017](../../docs/adr/0017-lucide-je-set-ikona-klijenta-material-ostaje-u-adminu.md): pub paket `lucide_icons_flutter`
- [ ] Četiri preostale Material upotrebe u klijentu zamijenjene Lucide ekvivalentom
      (`cloudOff`, `inbox`)
- [ ] Nema ispunjenih ikona u klijentskom UI-u
- [ ] Veličine svedene na 16 / 20 / 24 (plus 23 iz `SPEC.md` ako ostaje — ili se `SPEC.md` mijenja)
- [ ] Ikona nasljeđuje boju iz teme; nijedna je ne postavlja lokalno
- [ ] `uses-material-design: true` **ostaje u oba** — admin po ADR-0017 crta Material ikone, a
      klijent ga treba za Material komponente. Ovo je izmjena u odnosu na raniju verziju taska.

## Zamke
- **`Icons` je dvosmislen identifikator.** Lucide i Material obje klase zovu `Icons`, i u fajlu
  koji uvozi oba pobjeđuje zadnji import. Ime u `camelCase` je Lucide, u `snake_case` Material —
  to je jedini pouzdan način da se razlikuju grepom.
- **Lucide nema punu zvjezdicu** — set je cijeli linijski. `StarRating` je zato crtana površina, ne
  ikona; razlog je zapisan u `packages/core_ui/lib/src/components/star_rating.dart:11` i ne
  vraća se na ikonu.
- Ikona u `IconData` polju modela znači da set nije zamjenjiv bez dodirivanja modela.
- Tree-shaking ikona radi samo za konstantne `IconData`. Set koji ikonu bira po stringu u
  runtime-u isključi shaking i tiho naduva bundle.

## Status

Nije počet. **Odblokiran** ADR-om 0017 i **sužen** — ostatak posla je četiri upotrebe u klijentu
plus provjera veličina, ne zamjena seta kroz obje aplikacije.
