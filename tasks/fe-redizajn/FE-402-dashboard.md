# FE-402 — Dashboard

| | |
|---|---|
| **Epik** | FE-4 · Admin panel |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | [FE-401](FE-401-admin-shell.md), [FE-406](FE-406-desktop-fluidni-layout.md) |
| **Blokira** | — |
| **Reference** | `apps/admin/lib/src/features/dashboard/dashboard_screen.dart` · `prototype/adminv2/export/3b-lokacija-danas.png` |

## Cilj
Pregled dana: broj termina, zahtjevi na odobrenju, prihod, lista predstojećih termina.

## Zatečeno stanje
`dashboard_screen.dart` postoji i nosi `CircularProgressIndicator` (v.
[FE-205](FE-205-ukidanje-default-flutter-indikatora.md)). Referentni prikaz u novom handoffu je
`3b-lokacija-danas.png`.

## Definicija gotovog
- [ ] Kartice su linijski okviri; brojevi u kondenzovanom pismu, veliki
- [ ] „Novi termin" je jedina koralna akcija na ekranu
- [ ] Kartice se preslažu u jednu kolonu ispod 900 px
- [ ] Nema dekorativnih grafikona koji ne nose informaciju
- [ ] Prazan dan ima svoje stanje, ne nule u okvirima
- [ ] Učitavanje je skeleton, ne spinner

## Zamke
- **Prihod je zbir nad terminima, a termin nosi snapshot cijene** (task 32): cijena upisana na
  termin ne mijenja se kad se promijeni cjenovnik. Zbir koji čita `services` umjesto snapshota daje
  drugi broj za isti dan.
- Dashboard je prvi ekran poslije prijave — svaki spinner na njemu se vidi na **svakom** ulasku.

## Status

Nije počet.
