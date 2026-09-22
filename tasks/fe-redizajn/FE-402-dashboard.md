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
- [x] Kartice su linijski okviri; brojevi u kondenzovanom pismu, veliki — zatečeno
      (hairline obrub, `AdminText.metricNumber`), provjereno a ne mijenjano
- [x] „Novi termin" je jedina koralna akcija na ekranu — zatečeno: „Blokiraj termin" je
      `OutlinedButton`, „+ Novi termin" `FilledButton`. **Obrub kartice „Čeka potvrdu" je
      prebačen sa plave na koralnu**, jer je izmjereno iz `3b` da je `#EE6C4D`.
- [x] Kartice se preslažu u jednu kolonu ispod 900 px — `LayoutBuilder` + `AdminShell.bandZa`
- [x] Nema dekorativnih grafikona koji ne nose informaciju — zatečeno; „Zauzetost majstora"
      su trake sa minutama, a ne procenat kapaciteta koji bi bio izmišljen (task 30)
- [x] Prazan dan ima svoje stanje, ne nule u okvirima — zatečeno: naslov piše „Danas nema
      zakazanih termina.", tabela ima svoju poruku
- [x] Učitavanje je skeleton, ne spinner — `_SkeletonRasporeda`, oba `CircularProgressIndicator`
      uklonjena

## Zamke
- **Prihod je zbir nad terminima, a termin nosi snapshot cijene** (task 32): cijena upisana na
  termin ne mijenja se kad se promijeni cjenovnik. Zbir koji čita `services` umjesto snapshota daje
  drugi broj za isti dan.
- Dashboard je prvi ekran poslije prijave — svaki spinner na njemu se vidi na **svakom** ulasku.

## Status

Kod gotov i dokazan — grana `feat/fe-402-dashboard`.

**Dokaz:** `flutter test` u `apps/admin` — **302 prolazna** (bilo 299), čista analiza i format.

**Četiri od šest stavki DoD-a bile su zatečene.** Linijski okviri, jedina koralna akcija, odsustvo
dekorativnih grafikona i prazno stanje su već stajali iz taskova 28–30. Provjerio sam ih umjesto
da ih prepravljam. Stvarni rad su bile dvije: preslagivanje ispod 900 px i skeleton.

**Zamka o prihodu je već bila riješena.** Task upozorava da zbir mora čitati snapshot cijene sa
termina, a ne `services`. `DashboardSazetak.izracunaj` već radi
`termin.servicePrice ?? cijene[termin.serviceId] ?? 0` — snapshot ima prednost, cjenovnik je samo
fallback. Ništa nije mijenjano.

**Test je našao preliv koji niko nije tražio.** Kad sam dodao preslagivanje kartica metrika,
test na 1100 px je pao na `RenderFlex overflowed by 31 pixels`: raspored **ispod** njih
(`_DvijeKolone`) je i dalje bio fiksan, pa je na radnoj površini od 864 px desna kolona dobila
~330 px i zaglavlje kartice „Zahtjevi" je prelilo. Dvije kolone od kojih je jedna preuska nisu
raspored nego greška — i one se sada preslažu.

**Obrub `#EE6C4D`, brojka `#3D5A80`.** Izmjereno iz `3b`: kartica „Čeka potvrdu" ima koralan
obrub, ali joj velika brojka ostaje plava, ista kao u ostalim karticama. Koralna kaže „ovdje
treba nešto uraditi", plava ostaje boja podatka. Kod je koristio `accent` za oboje; promijenjen
je **samo obrub**.

Viđeno uživo (`flutter build web` + Chromium): **1100 px** — sve u jednoj koloni, bez preliva;
**1600 px** — tri kartice u redu, raspored i zahtjevi u dvije kolone, kao `3b`.

Ostalo:

- [ ] Zelen CI — dokaz iz čistog checkouta.
