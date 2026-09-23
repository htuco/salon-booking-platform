# FE-603 — Koralna za jednu akciju, tri nivoa naslova, status tagovi

| | |
|---|---|
| **Epik** | FE-6 · Admin kao radni alat |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 1 dan |
| **Zavisi od** | [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) (grupa 2) |
| **Blokira** | — |
| **Reference** | `core/theme/admin_typography.dart` · `core/theme/admin_status_colors.dart` · `appointments/status_pill.dart` |

## Cilj
Koralna nosi samo primarnu akciju ekrana; naslovi u Barlow Condensed imaju tri nivoa; status se čita iz oblika taga.

## Zatečeno stanje
Koralna je u adminu platformska boja (ADR-0018 važi samo za klijenta), pa ovo nije pitanje tenanta nego hijerarhije. FE-402 je „Novi termin” već učinio jedinom koralnom akcijom dashboarda, ali je obrub „Čeka potvrdu” koralan jer ga `3b` tako crta. Isprekidan rub za `pending` postoji na kalendaru (FE-403).

## Definicija gotovog
- [ ] Popis svih koralnih upotreba po ekranu, sa odlukom za svaku
- [ ] Najviše jedna koralna akcija po ekranu; badgevi i okviri idu na neutralnu ili statusnu boju
- [ ] Status tag: isprekidan = na odobrenju, pun = potvrđen, prigušen = otkazan — isti u listi, detalju i kalendaru
- [ ] `AdminText` svodi naslove na tri nivoa; stari stilovi uklonjeni, ne ostavljeni kao alias

## Zamke
- Pilula brojača u sidebaru je koralna u izvozu (FE-401) — mijenja se samo uz dopunu handoffa.

## Status

Nije počet. Blokiran: [ADR-0021](../../docs/adr/0021-admin-kao-radni-alat-odstupanje-od-adminv2.md) je `predložen`.
