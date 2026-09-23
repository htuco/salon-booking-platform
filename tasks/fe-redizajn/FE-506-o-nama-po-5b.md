# FE-506 — „O nama" (`/about`) po obliku iz `5b`

| | |
|---|---|
| **Epik** | FE-3 · Ekrani klijenta |
| **Aplikacija** | `apps/client` |
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | `prototype/ui/screenshots/02-o-nama.png` · `prototype/ui/README.md` („Dva odstupanja od handoffa na `5b`") |

## Cilj
`/about` treba da ima oblik ekrana `5b`, a ne da ponavlja hero Početne.

## Zatečeno stanje
Nađeno u FE-504 (2026-09-23), web demo na 402 px, oba tenanta:

- `02-o-nama.png`: ime salona je **centrirano pri vrhu** heroja, ispod njega je podnaslov
  („brijačnica od 2014."), a CTA je **obrubljen verzal „REZERVIŠI"** preko cijele širine.
- `/about` danas crta hero Početne: ime dolje lijevo, oznaku „Danas zatvoreno" i „Zakaži termin".
  Sekcije ispod („O nama · Ko smo mi?", „Radno vrijeme") prate `5b`.

`prototype/ui/README.md` navodi dva **svjesna** odstupanja na `5b`: punu sedmicu radnog vremena i
sadržaj `5b` inline na Početnoj. Hero nije među njima, a README kaže da `/about` ostaje
„kao ruta i kao oblik iz handoffa".

## Definicija gotovog
- [ ] Hero na `/about` po `5b`: centrirano ime, podnaslov, obrubljen CTA u verzalu
      (verzal kroz `semanticsLabel`, FE-502)
- [ ] Podnaslov dolazi iz podataka salona ili iz `vertical.terms`, ne iz stringa u widgetu
- [ ] Oba tenanta viđena, 360 i 402 px
- [ ] Ili, ako je sadašnji oblik namjeran: zapisan kao treće svjesno odstupanje u
      `prototype/ui/README.md`, sa razlogom

## Zamke
- FE-301 je popravio skok CTA-a na `/about` (kostur 320 naspram heroja 420). Promjena heroja mora
  zadržati taj test.
