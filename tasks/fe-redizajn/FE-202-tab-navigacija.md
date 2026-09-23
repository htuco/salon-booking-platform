# FE-202 — Prelaz između tabova

| | |
|---|---|
| **Epik** | FE-2 · Navigacija i tranzicije |
| **Aplikacija** | `apps/client` |
| **Procjena** | 1 dan |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | `packages/core_ui/lib/src/components/bottom_nav_bar.dart` · `apps/client/test/client_shell_test.dart` |

## Cilj
Prebacivanje taba je trenutni cross-fade (120 ms), bez horizontalnog klizanja, uz očuvano stanje i
scroll poziciju svakog taba.

## Zatečeno stanje
- Donja navigacija postoji (`packages/core_ui/lib/src/components/bottom_nav_bar.dart`) i vodi je `go_router`
  shell ruta.
- `apps/client/test/client_shell_test.dart` već tvrdi „tab pamti gdje je korisnik stao" — taj test
  je **polazna zaštita**, ne stavka koju treba napisati; mora ostati zelen kroz cijelu promjenu.

## Definicija gotovog
- [x] Cross-fade 120 ms; nema klizanja ni push tranzicije između tabova — `TabCrossFade` kao
      `navigatorContainerBuilder`; test mjeri providnost na 60 ms i kraj na 121 ms
- [x] Scroll pozicija po tabu preživi prebacivanje — grane ostaju žive i stablo ne mijenja oblik
      (ključ po indeksu, `FadeTransition` uvijek prisutan); `PageStorageKey` nije potreban.
      `client_shell_test.dart` „tab pamti gdje je korisnik stao" ostao zelen
- [x] Promjena taba ne rebuilduje cijelo stablo — mjereno brojačem `build`-a po tabu
- [x] Dodirna meta taba ≥ 44 px visine — zatečeno, `bottom_nav_bar_test.dart:142`
- [x] Aktivni tab nosi oznaku po handoffu; boja oznake dolazi iz teme tenanta, ne iz konstante
      — zatečeno, traka je `scheme.onSurface`

## Zamke
- **`IndexedStack` čuva stanje tako što sve tabove drži živima.** To je i cijena: svaki tab gradi
  svoje stablo i drži svoje providere. Ako neki tab ima skup `build`, cijena se plaća pri svakom
  pokretanju aplikacije, ne pri prvom otvaranju taba.
- Koralna kao boja aktivnog taba je admin akcent — u klijentu boja dolazi iz `tenant.yaml`
  (v. [README](README.md), odluka 2).

## Status

**Gotovo, dokazano testovima.** Grana `feat/fe-202-prelaz-tabova`.

`StatefulShellRoute.indexedStack` je zamijenjen `StatefulShellRoute` sa `TabCrossFade`
kontejnerom (`apps/client/lib/src/core/router/tab_cross_fade.dart`). Dolazeći tab se pretapa
**preko** odlazećeg, koji ostaje pun: da blijede oba, na pola prelaza proviri pozadina.
Reduce Motion prebacuje bez pretapanja.

**Dokaz (2026-09-23):** `apps/client` `flutter analyze` — No issues found; `flutter test` —
**243 pass** (5 novih u `tab_cross_fade_test.dart`). Sabotaža (uklonjen ključ po indeksu) obara
„promjena taba ne gradi ostale tabove iznova" i „odlazeći tab ne prima dodir".

Nije viđeno na uređaju.
