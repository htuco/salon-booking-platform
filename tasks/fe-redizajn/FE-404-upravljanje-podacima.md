# FE-404 — Usluge, osoblje i klijenti

| | |
|---|---|
| **Epik** | FE-4 · Admin panel |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 2–3 dana |
| **Zavisi od** | [FE-401](FE-401-admin-shell.md), [FE-406](FE-406-desktop-fluidni-layout.md) |
| **Blokira** | — |
| **Reference** | `apps/admin/lib/src/features/services/`, `employees/`, `clients/` · `prototype/adminv2/export/3e-klijenti.png`, `3f-usluge.png`, `3g-osoblje.png` |

## Cilj
CRUD ekrani: usluge (cijena, trajanje), osoblje (raspored, usluge), klijenti (historija).

## Zatečeno stanje
Sva tri ekrana postoje i **imaju backend iza sebe** (taskovi 32, 33, 35): pisanje ide kroz `rpc`,
ne kroz direktan `insert`/`update`. Redizajn ne smije uvesti put koji zaobilazi validaciju.

`employees_screen.dart` već računa broj kolona iz `constraints.maxWidth / 280` — isti obrazac koji
FE-406 traži, već primijenjen na jednom mjestu.

Riječ „majstor" iz handoffa je barber terminologija; u kodu je `employees`, a u tekstu dolazi iz
`vertical.terms`.

## Definicija gotovog
- [ ] Tabele sa tematskim zaglavljem i linijama redova, bez zebra pruga
- [ ] Kratki unosi u modalu, duži na zasebnoj strani
- [ ] Brisanje uvijek uz potvrdu
- [ ] Sortiranje i pretraga
- [ ] Validacijske greške **inline uz polje**, ne kao toast
- [ ] Pisanje i dalje isključivo kroz `rpc`
- [ ] Nazivi uloga dolaze iz `vertical.terms`, ne iz canvasa

## Zamke
- **Klijent nije nalog.** `customers` je knjiga salona; telefonski klijent i prijavljeni korisnik su
  namjerno dva reda dok ih salon ne spoji. Ekran koji ih spaja po broju telefona donosi odluku koja
  pripada salonu.
- **Radnik nije nalog.** `employees` je osoblje, `public.users` je prijava; vezivanje je
  [task 46](../sprint-4/46-uloga-employee-i-izolacija.md), ne ovaj.
- Brisanje usluge koja stoji na terminu ne smije obrisati istoriju — snapshot na terminu je razlog
  zašto to i radi.

## Status

Nije počet.
