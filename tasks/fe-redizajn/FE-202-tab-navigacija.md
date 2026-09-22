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
- [ ] Cross-fade 120 ms; nema klizanja ni push tranzicije između tabova
- [ ] Scroll pozicija po tabu preživi prebacivanje (`PageStorageKey`)
- [ ] Promjena taba ne rebuilduje cijelo stablo — mjereno, ne pretpostavljeno
- [ ] Dodirna meta taba ≥ 44 px visine
- [ ] Aktivni tab nosi oznaku po handoffu; boja oznake dolazi iz teme tenanta, ne iz konstante

## Zamke
- **`IndexedStack` čuva stanje tako što sve tabove drži živima.** To je i cijena: svaki tab gradi
  svoje stablo i drži svoje providere. Ako neki tab ima skup `build`, cijena se plaća pri svakom
  pokretanju aplikacije, ne pri prvom otvaranju taba.
- Koralna kao boja aktivnog taba je admin akcent — u klijentu boja dolazi iz `tenant.yaml`
  (v. [README](README.md), odluka 2).

## Status

Nije počet.
