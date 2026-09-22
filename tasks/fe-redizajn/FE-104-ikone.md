# FE-104 — Ikone: jedan set, jedna debljina linije

| | |
|---|---|
| **Epik** | FE-1 · Temelji i dizajn tokeni |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | **ADR o setu ikona** (v. [README](README.md), odluka 3) |
| **Blokira** | — |
| **Reference** | `prototype/ui/SPEC.md:51` · `apps/admin/lib/src/core/navigation/admin_destinations.dart` |

## Cilj
Jedan tanko-linijski set kroz obje aplikacije, jedna debljina poteza, tri veličine.

## Zatečeno stanje
- **116 upotreba `Icons.*` / `CupertinoIcons`** u obje aplikacije van testova — Material set,
  pretežno ispunjen.
- `prototype/ui/SPEC.md:51` traži **Lucide, stroke 1.5, `currentColor`**, veličina 23×23 u
  donjoj navigaciji.
- Wireframe već koristi `lucide-react`, pa je jezik ikona odabran **na webu**, ali u Flutteru za
  Lucide ne postoji ništa u `pubspec.yaml` nijedne aplikacije.
- `IconData` se prosljeđuje kroz vlastite modele (`admin_destinations.dart:52`,
  `calendar_screen.dart:195`), pa zamjena seta dira ta mjesta, ne samo pozive.

## Definicija gotovog
- [ ] ADR bira nosioca: pub paket, zapakovan icon font ili SVG set — sa licencom, veličinom bundla
      i tree-shakingom kao kriterijima
- [ ] Nema ispunjenih ikona u UI-u
- [ ] Veličine svedene na 16 / 20 / 24 (plus 23 iz `SPEC.md` ako ostaje — ili se `SPEC.md` mijenja)
- [ ] Ikona nasljeđuje boju iz teme; nijedna je ne postavlja lokalno
- [ ] `uses-material-design: true` preispitan — ako Material ikone odu, font od ~1,6 MB nema razloga ostati

## Zamke
- **`uses-material-design: true` pakuje cijeli Material icon font.** Ostavljen uz novi set znači da
  bundle nosi oba, a to je tačno ono što FE-503 kasnije traži da ne bude.
- Ikona u `IconData` polju modela znači da set nije zamjenjiv bez dodirivanja modela; ako novi set
  ne daje `IconData`, to je promjena tipa kroz `admin_destinations.dart` i `calendar_screen.dart`.
- Tree-shaking ikona radi samo za konstantne `IconData`. Set koji ikonu bira po stringu u runtime-u
  isključi shaking i tiho naduva bundle.

## Status

Nije počet.
