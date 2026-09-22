# FE-203 — Modali i bottom sheet

| | |
|---|---|
| **Epik** | FE-2 · Navigacija i tranzicije |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 1 dan |
| **Zavisi od** | — |
| **Blokira** | [FE-304](FE-304-moji-termini.md) |
| **Reference** | `packages/core_ui/lib/src/components/app_dialog.dart` · `packages/core_ui/lib/src/theme/theme_factory.dart:184` · `apps/admin/lib/src/features/working_hours/working_hours_dialogs.dart` |

## Cilj
Modali i bottom sheetovi otvaraju se istim jezikom kao ostatak redizajna, u obje aplikacije.

## Zatečeno stanje
- `AppDialog` postoji u `core_ui` i nosi jedan od dva hex-a koja su ostala van tokena (v. [FE-101](FE-101-tokeni-boja.md)).
- `bottomSheetTheme` je već definisan sa `BorderRadius.zero` (`theme_factory.dart:184`) — oštra ivica
  je time riješena, animacija nije.
- Admin ima vlastite dijaloge (`working_hours_dialogs.dart`) sa `maxWidth: 460` i komentarom zašto
  nije fiksna širina; oni moraju ući u isti jezik, a ne dobiti drugi.

## Definicija gotovog
- [ ] Modal: backdrop fade 0 → 0,4 uz scale 0,98 → 1, 180 ms
- [ ] Bottom sheet: klizanje iz dna 240 ms, `easeOutCubic`, drag-to-dismiss
- [ ] Backdrop je neutralan crni sa alfom — **nikad koralni**
- [ ] Zatvaranje radi i tapom na backdrop i sistemskim *back*-om
- [ ] Nema Material „grow from center" animacije ni u jednoj aplikaciji
- [ ] Admin dijalozi koriste isti jezik; njihova `maxWidth` logika ostaje

## Zamke
- **`showDialog` ignoriše `pageTransitionsTheme`.** Tranzicija iz [FE-201](FE-201-zamjena-default-tranzicije.md)
  ne pokriva modale — oni idu kroz `transitionBuilder` svog poziva, i to je razlog zašto je ovo
  zaseban task, a ne posljedica prethodnog.
- Drag-to-dismiss nad sheetom koji sadrži listu koja se skroluje traži da gesta zna razliku; bez
  toga se sheet zatvara pri pokušaju skrolanja.

## Status

Nije počet.
