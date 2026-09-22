# FE-403 — Kalendar termina

| | |
|---|---|
| **Epik** | FE-4 · Admin panel |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 2–3 dana |
| **Zavisi od** | [FE-401](FE-401-admin-shell.md), [FE-406](FE-406-desktop-fluidni-layout.md) |
| **Blokira** | — |
| **Reference** | `apps/admin/lib/src/features/calendar/calendar_screen.dart` · `prototype/adminv2/export/3c-kalendar-dana.png`, `3l-telefon-kalendar.png` |

## Cilj
Dnevni i sedmični prikaz po radniku, sa odobravanjem i odbijanjem zahtjeva.

## Zatečeno stanje
Najveći ekran u adminu (`calendar_screen.dart`, preko 1600 redova) i **jedini koji već računa
raspored po dostupnoj širini**: `constraints.maxWidth - _sirinaOse` dijeli prostor na kolone. To je
temelj na kojem FE-406 gradi, ne kod koji treba zamijeniti.

Sedmični prikaz danas **ne postoji** — postoji dnevni ([task 31](../sprint-3/31-kalendar-dana.md)).
To je jedina stavka ovog taska koja je nova funkcionalnost, ne redizajn, i zato nosi najviše rizika.

## Definicija gotovog
- [ ] Prebacivanje dan / sedmica
- [ ] Kolone po radniku, termin je blok sa oštrim ivicama
- [ ] Zahtjevi na odobrenju vizuelno odvojeni (isprekidan rub)
- [ ] Preklapajući termini idu jedan pored drugog, nikad jedan preko drugog
- [ ] Odobravanje ne traži ponovno učitavanje — lista se osvježava na realtime signal
- [ ] Kolone se raspoređuju po dostupnoj širini i na 2560 px

## Zamke
- **Sedmični prikaz je nova funkcionalnost unutar vizuelnog epika.** Ako sprint pukne, puca on, a
  dnevni ostaje — tako i planirati.
- Termin nosi `buffer_minutes` **sa sebe**, ne iz postavki: pauza upisana u trenutku rezervacije se
  ne mijenja kad salon promijeni postavku. Blok koji crta pauzu iz `salon_settings` pomjera već
  dogovorene termine.
- Preklapanje se ne rješava sortiranjem po početku; dva termina istog radnika u isto vrijeme baza
  ne dozvoljava (exclusion constraint), ali dva **različita** radnika u istoj koloni znače da je
  kolona pogrešno izvedena.

## Status

Nije počet.
