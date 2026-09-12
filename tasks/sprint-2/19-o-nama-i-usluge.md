# Task 19 — Client: "O nama" i "Usluge"

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [18](18-pocetna-i-tab-bar.md) |
| **Blokira** | — |
| **Reference** | `prototype/ui/screenshots/02-o-nama.png`, `09-usluge.png` |

## Cilj
Dva ekrana koja žive od istih podataka koje app već ima: priča salona i pun cjenovnik.

## Definicija gotovog
- [ ] `/about` po `02-o-nama.png`: priča, par fotografija, radno vrijeme, kontakt, društvene mreže
- [ ] `/services` po `09-usluge.png`: pun cjenovnik, **tap vodi direktno u booking** sa
      preselektovanom uslugom (`?serviceId=`, već podržano)
- [ ] Usluge grupisane po `category` — polje postoji u modelu i nikad nije iskorišteno
- [ ] Oba ekrana rade bez prijave
- [ ] Screenshot uz referentne PNG-ove

## Koraci
1. `/services` prvo — kraći je i dokazuje grupisanje po kategoriji
2. `/about` koristi `salon.description`, radno vrijeme i kontakt iz taska 10
3. Commit: `feat(client): o nama i cjenovnik`

## Zamke
- **Kategorija je slobodan tekst, ne enum** — salon je mijenja iz admina; sortiranje mora
  podnijeti praznu i nepoznatu vrijednost.
- `vertical.features.socialLinks` gasi sekciju mreža; ordinacija ih nema.
