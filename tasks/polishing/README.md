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
| [52](52-beauty-dotjeran.md) | Beauty tenant dotjeran ✅ | refinement | kod u `main`-u (#120); prave fotografije u seedu ostaju, provjera na uređaju ide u 60 | fotografije |
| [53](53-vertikala-health.md) | Vertikala `health` ✅ | feature | kod u `main`-u (#121); snimci i buildovi idu u 60 | — |
| [54](54-uklanjanje-nepotrebnog-iz-admina.md) | Uklanjanje nepotrebnog iz admina | popravka | lista šta se uklanja; blokira 71 | **odluka vlasnika proizvoda** |
| [55](55-prerada-dashboarda.md) | Prerada admin dashboarda ✅ | redizajn | kod u `main`-u (#124–#126); radnik na telefonu ide u 60 | — |
| [61](61-moj-profil.md) | Moj profil u adminu ✅ | feature | kod u `main`-u (#122); kamera na telefonu ide u 60 | — |
| [62](62-toast-obavijesti.md) | Toast obavijesti u adminu ✅ | redizajn | kod u `main`-u (#123); hostovani sa pravim nalogom ide u 60 | — |
| [63](63-animacija-ucitavanja.md) | Animacija učitavanja „Termin i sada" | dizajn | nije počet; lava animacija iz #127 je na auth ekranima i ne zatvara ovaj task | — |
| [59](59-radnik-u-seedu.md) | Radnik u lokalnom seedu | chore | nije počet | ide uz 60 |
| [60](60-regresija-i-testiranje.md) | Regresija i testiranje | test | nije počet | poslije 71 i 87, **prije** 89 i 90 |

🟡 ima isto značenje kao u sprintovima: djelimično, sa imenovanim ostatkom. ✅ znači da je kod u
`main`-u; provjera na uređaju i hostovanom za 52, 53, 55, 61 i 62 je dio regresije (60).

**Ko šta uzima:** [`RASPODJELA.md`](../RASPODJELA.md).

## Status

Folder otvoren 2026-10-12. Starija istorija ovih taskova je u status blokovima
[`sprint-5/README.md`](../sprint-5/README.md#status).
