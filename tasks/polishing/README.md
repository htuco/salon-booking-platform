# Polishing — dotjerivanje onoga što već postoji

Ovdje su taskovi kojima je funkcija već napisana, ili koji samo dotjeruju postojeće. Ne donose novu
funkciju. Došli su iz [Sprinta 5](../sprint-5/) kad je zatvoren (2026-10-12). Nova funkcionalnost
do lansiranja je u [`zero-crisis/`](../zero-crisis/).

**Ovo nije sprint.** Taskovi nemaju zajednički redoslijed. Većina čeka nešto izvan repoa (uređaj,
hostovani projekat, tvoju odluku), pa se radi kad to stigne. Dva su vezana za redoslijed
`zero-crisis/`: **54** ide prije 71 (Melura za svakoga), a **60** (regresija, uz 59) ide u fazi D —
poslije sigurnosnog pregleda (87), a **prije** prelaska salona na produkciju (89) i objave (90).

| # | Task | Vrsta | Šta ostaje | Čeka |
|---|---|---|---|---|
| [52](52-beauty-dotjeran.md) | Beauty tenant dotjeran 🟡 | refinement | snimci prije/poslije na 402, prave slike u seedu, `admin@beautystudiotravnik.test` na hostovanom, build na Androidu | uređaj, fotografije |
| [53](53-vertikala-health.md) | Vertikala `health` 🟡 | feature | snimci sva četiri tenanta, APK/iOS build na `main`-u, „Bilo ko od nas" na ekranu; masaža i fizio nisu na hostovanom | uređaj, hostovani |
| [54](54-uklanjanje-nepotrebnog-iz-admina.md) | Uklanjanje nepotrebnog iz admina | popravka | lista šta se uklanja; blokira 71 | **odluka vlasnika proizvoda** |
| [55](55-prerada-dashboarda.md) | Prerada admin dashboarda 🟡 | redizajn | Danas kao radnik na hostovanom i na telefonu | uređaj |
| [61](61-moj-profil.md) | Moj profil u adminu 🟡 | feature | slika iz kamere na telefonu | uređaj |
| [62](62-toast-obavijesti.md) | Toast obavijesti u adminu 🟡 | redizajn | provjera na hostovanom sa pravim nalogom | hostovani |
| [63](63-animacija-ucitavanja.md) | Animacija učitavanja „Termin i sada" | dizajn | nije počet; lava animacija iz #127 je na auth ekranima i ne zatvara ovaj task | — |
| [59](59-radnik-u-seedu.md) | Radnik u lokalnom seedu | chore | nije počet | ide uz 60 |
| [60](60-regresija-i-testiranje.md) | Regresija i testiranje | test | nije počet | poslije 71 i 87, **prije** 89 i 90 |

🟡 ima isto značenje kao u sprintovima: djelimično, sa imenovanim ostatkom.

**Ko šta uzima:** [`RASPODJELA.md`](../RASPODJELA.md).

## Status

Folder otvoren 2026-10-12. Starija istorija ovih taskova je u status blokovima
[`sprint-5/README.md`](../sprint-5/README.md#status).
