# Task 31 — Kalendar dana

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [29](29-responsive-shell.md) |
| **Blokira** | — |
| **Reference** | `SPEC.md` prikazi `3c` `3l` · [16](../sprint-2/16-moji-termini-i-otkazivanje.md) |

## Cilj
`/calendar` prestaje biti placeholder: dan po radnicima, sa terminima na svojim mjestima.

## Definicija gotovog
- [ ] Desktop `3c`: kolona po radniku, vremenska osa, termin kao blok
- [ ] Telefon `3l`: isti podaci kao lista po vremenu — ne stisnuta mreža
- [ ] Termin vodi na detalj iz [30](30-postojeci-ekrani-na-handoff.md)
- [ ] Pauze, neradni dani i blokade se **vide**, ne samo kao praznina
- [ ] Čita se kroz postojeći `StaffAppointmentRepository`, bez novog direktnog upita
- [ ] Testovi rade u bilo koje doba dana i bilo koji dan u sedmici

## Koraci
1. Model dana i mapiranje termina na osu, sa testovima nad rubnim slučajevima
2. Desktop mreža, pa mobilna lista
3. Commit: `feat(admin): kalendar dana po radnicima`

## Zamke
- **`get_available_slots` vraća red po radniku.** Ista osobina je u tasku 24 dala duplirana vremena
  u ručnom unosu, zbog čega `distinctTimes` i postoji. Kalendaru red po radniku **i treba** — ali
  svako miješanje ta dva pogleda daje ili duplikate ili izgubljene termine.
- **Test koji radi samo u dijelu dana nije test.** Tri zatečena testa nađena u tasku 17 bila su
  zelena samo poslije 09:30 ili ponedjeljkom. Kalendar je najgore mjesto za tu grešku — fiksiraj
  vrijeme umjesto da se oslanjaš na `DateTime.now()`.
- Termin duži od jednog slota i prekoračenje preko ponoći moraju imati svoj slučaj.

## Status

U toku (2026-09-20). Grana `feat/admin-kalendar-dana`.
