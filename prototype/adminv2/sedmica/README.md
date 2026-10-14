# Sedmica — skica za task 69

Sedmični prikaz kalendara u Meluri (`7a` desktop, `7b` telefon). Ovo nije dizajnerski handoff nego
**skica iz taska**, jer u `adminv2/export/` sedmice nema (`3c` crta samo prekidač). Oblik se
naslanja na `3c` (mreža dana) i `3l` (lista na telefonu), pa za sve što ovdje nije rečeno važe oni.

- `index.html` — skica, otvara se preko lokalnog servera (`npx http-server` u ovom folderu), jer
  browser blokira `file:`. Klik na čip radnika filtrira. Podaci su izmišljeni.
- `screenshots/7a-sedmica-1440.png`, `screenshots/7b-sedmica-402.png`

**Iz skice se uzimaju raspored i pravila, ne boja.** Boje termina i radnika dolaze iz admin teme,
kao u dnevnom prikazu.

## Pravila

| | |
|---|---|
| Ulaz | „Sedmica" u postojećem prekidaču `Dan · Sedmica · Mjesec`. „Mjesec" ostaje ugašen sa „Uskoro" |
| Kolone | 7 dana, ponedjeljak–nedjelja, sedmica u kojoj je izabrani datum. Strelice idu za sedmicu, „Ova sedmica" vraća na tekuću |
| Radnici | **Svi u istoj koloni dana** (odluka 2026-10-14). Svaki termin nosi inicijal radnika; čipovi `Svi · Emir · …` filtriraju. Radnik vidi samo svoje, bez čipova |
| Zaglavlje dana | Dan, datum, radno vrijeme salona i broj termina. Danas je istaknut. **Tap na zaglavlje otvara taj dan** u prikazu „Dan" |
| Vremenska osa | Od najranijeg početka do najkasnijeg kraja radnog vremena u toj sedmici, ne fiksno |
| Termin | Inicijal + početak + ime klijenta. Status kao u danu: potvrđen, čeka potvrdu (isprekidan rub, FE-403), završen, u toku |
| Preklapanje | Jedan pored drugog, kao u danu. Od tri trake naviše blok nosi samo inicijal i vrijeme; ime je u detalju. Termin kraći od ~40 px staje u jedan red |
| Neradno | Neradni dan je šrafirana cijela kolona („Neradni dan"). Prije otvaranja i poslije zatvaranja je šrafirano. Salonska blokada je šrafirana sa svojim tekstom; radnikova blokada se crta samo kad je filtriran taj radnik |
| Sada | Crvena linija samo u koloni današnjeg dana |
| Tap | Termin otvara **isti detalj** kao dnevni prikaz. Prazno mjesto nudi ručno zakazivanje za taj dan i vrijeme (zaokruženo na 30 min) |
| Telefon | Podrazumijevano je „Dan" (`3l`). „Sedmica" je **lista po danima**: zaglavlje dana, pa termini po vremenu sa inicijalom radnika. Neradni dan je jedan red. Mreža od 7 kolona se ne stiska na 402 px (`SPEC.md`) |
| Prazno | Sedmica bez termina i dalje crta kolone i radno vrijeme; prazna lista na telefonu kaže „Nema termina ove sedmice" |
