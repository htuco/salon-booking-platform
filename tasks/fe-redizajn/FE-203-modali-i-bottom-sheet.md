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
- [x] Modal: backdrop fade uz scale 0,98 → 1, 180 ms — `AppModal.dialog`. Ciljna alfa **nije
      0,4** nego token `scrim` (0,72 iz `prototype/ui/SPEC.md` 5p), jer je SPEC vizuelni izvor istine
- [x] Bottom sheet: klizanje iz dna 240 ms, `easeOutCubic`, drag-to-dismiss — `AppModal.sheet`.
      Klijent danas **nema nijedan** sheet; helper je spreman za prvi
- [x] Backdrop je neutralan crni sa alfom — **nikad koralni** — `colorScheme.scrim`, test
- [x] Zatvaranje radi i tapom na backdrop i sistemskim *back*-om (i `Escape`) — test
- [x] Nema Material „grow from center" animacije u klijentu — `AppDialog.show` ide kroz
      `AppModal`. Lightbox (`gallery_lightbox.dart`) ostaje na `showDialog` do [FE-204](FE-204-lightbox-galerija.md)
- [ ] ~~Admin dijalozi koriste isti jezik~~ — **ne radi se**: admin je 1:1 sa `adminv2`
      ([ADR-0020](../../docs/adr/0020-admin-je-1na1-sa-adminv2-barlow-i-svijetla-tema.md)), odluka vlasnika 2026-09-23

## Zamke
- **`showDialog` ignoriše `pageTransitionsTheme`.** Tranzicija iz [FE-201](FE-201-zamjena-default-tranzicije.md)
  ne pokriva modale — oni idu kroz `transitionBuilder` svog poziva, i to je razlog zašto je ovo
  zaseban task, a ne posljedica prethodnog.
- Drag-to-dismiss nad sheetom koji sadrži listu koja se skroluje traži da gesta zna razliku; bez
  toga se sheet zatvara pri pokušaju skrolanja.

## Status

**Gotovo za klijenta, dokazano testovima.** Grana `feat/fe-203-modali-i-sheet`.

`AppModal` u `core_ui` (`lib/src/components/app_modal.dart`) drži obje animacije na jednom
mjestu; `AppDialog.show` je prebačen na njega.

**Dokaz (2026-09-23):** `packages/core_ui` `flutter test` — **76 pass** (9 novih u
`app_modal_test.dart`), analiza čista. `apps/client` — **238 pass**, analiza čista. Sabotaže:
dijalog od 150 ms i sheet od 250 ms obaraju po jedan test.
