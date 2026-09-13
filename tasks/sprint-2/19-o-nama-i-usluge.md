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
- [x] `/about` po `02-o-nama.png`: priča, par fotografija, radno vrijeme, kontakt, društvene mreže
- [x] `/services` po `09-usluge.png`: pun cjenovnik, **tap vodi direktno u booking** sa
      preselektovanom uslugom (`?serviceId=`, već podržano)
- [x] Usluge grupisane po `category` — polje postoji u modelu i nikad nije iskorišteno
- [x] Oba ekrana rade bez prijave
- [x] Screenshot uz referentne PNG-ove

## Koraci
1. `/services` prvo — kraći je i dokazuje grupisanje po kategoriji
2. `/about` koristi `salon.description`, radno vrijeme i kontakt iz taska 10
3. Commit: `feat(client): o nama i cjenovnik`

## Zamke
- **Kategorija je slobodan tekst, ne enum** — salon je mijenja iz admina; sortiranje mora
  podnijeti praznu i nepoznatu vrijednost.
- `vertical.features.socialLinks` gasi sekciju mreža; ordinacija ih nema.

## Status (2026-09-13) — ✅ zatvoren

Oba ekrana su napisana, dokazana protiv **živog Supabase stacka** i vidljiva u iOS simulatoru.

> **`SPEC.md` 5b ne završava na `/about`.** Prvi prolaz je ekran napisao po handoffu i ostavio ga
> iza reda „O nama ›" na dnu Početne. U simulatoru se vidjelo šta to znači: priča salona, radno
> vrijeme i kontakt stoje jedan tap dalje, na ekranu kojem handoff nijednim nacrtanim ekranom ne
> daje ulaz. Sadržaj je zato **inline na Početnoj**, a `/about` ostaje kao ruta i kao oblik iz
> handoffa. Sekcije dijele obje strane kroz `features/about/about_sections.dart`.

### Šta je napravljeno

- **`/services`** (`features/services/`) — pun cjenovnik grupisan po `category`. Zaglavlja se
  crtaju **samo kad ima šta da se grupiše**: jedna kategorija (ili nijedna) daje ravnu listu,
  tačno kao `09-usluge.png`. Tap vodi u `/book/service?serviceId=`.
- **`groupByCategory`** — čista funkcija izvan widgeta. Podnosi praznu kategoriju, razmake u
  unosu i nepoznato ime; **ne sortira ponovo**, jer `ServiceRepository.forSalon` već vraća uzlazno
  po kategoriji pa po imenu (drugo sortiranje = dva izvora istine za isti poredak).
- **`/about`** (`features/about/`) — hero, outline CTA, priča, foto par, radno vrijeme, kontakt.
- **`about_sections.dart`** — četiri javne sekcije koje slažu **oba** ekrana.
- **`ContactRow`** je prešao sa „ikona + tekst + chevron" na **labela → vrijednost**, kako ga
  `02-o-nama.png` i crta. Stari oblik je bio iz taska 10, kad kontakt još nije imao svoj ekran.
- **Osam novih `.arb` ključeva**; nijedan literal koji se mijenja po vertikali nije u ekranu
  (naslov `/services` je `terms.servicePlural`, CTA je `terms.bookCta`).

### Rupa koju je ostavio task 18 — zatvorena

Radno vrijeme i kontakt su od taska 18 bili **nedostupni u cijeloj aplikaciji**: skinuti sa
Početne jer ih `SPEC.md` drži na 5b, a 5b nije postojao. `WorkingHoursCard` i `ContactCard` su sve
to vrijeme stajali bez ijednog korisnika. Sada su opet na Početnoj, inline, i pokriveni testom koji
to i imenuje.

### Dva svjesna odstupanja od handoffa

1. **Radno vrijeme je puna sedmica, ne jedan red.** `02-o-nama.png` ga svodi na „09:00 – 20:00",
   što je tačno samo za salon koji svaki dan radi isto. Iz prave baze: demo barber radi subotom do
   **14:00** i nedjeljom **ne radi** — jedan red bi lagao, i to bi se otkrilo pred zatvorenim
   vratima.
2. **Sadržaj 5b je na Početnoj** — v. blok na vrhu. **Foto par je izuzetak i ostaje samo na
   `/about`:** uzima prve dvije slike iz iste `gallery_urls` liste koju Galerija na Početnoj već
   crta u mreži, pa bi tamo bile iste dvije fotografije dvaput.

### Dokaz

**`melos format` / `melos analyze` / `melos test` — SUCCESS, 361 test PASS** (bilo 326):

```
[core_domain]: 00:00 +58: All tests passed!
[core_api]:    00:00 +67: All tests passed!
[core_ui]:     00:03 +55: All tests passed!
[admin]:       00:02  +4: All tests passed!
[client]:      00:14 +177 ~1: All tests passed!
```

Od 35 novih testova u `client`-u: 9 na `groupByCategory`, 11 na `/services`, 14 na `/about`,
plus dva na Početnoj („O nama" je na njoj; foto para na njoj nema).

**Živi stack, iOS simulator** (iPhone 17, flavor `barberstudiovitez`, `SUPABASE_URL=127.0.0.1:54321`):
app se builda, diže i čita pravi katalog — `docs/screenshots/task-19-ios-sim-pocetna-barber.png`.

**Živi stack, Chromium 402 px**, uz referentne PNG-ove:

| Snimak | Šta dokazuje |
|---|---|
| `task-19-pocetna-o-nama-barber.png` | Početna od heroja do kontakta; „O nama" inline, bez foto para |
| `task-19-usluge-barber.png` | `/services` grupisan: **Brada · Paketi · Šišanje**, uzlazno, Usluge tab aktivan |
| `task-19-o-nama-barber.png` | `/about` uz `02-o-nama.png`; Početna tab aktivan, kako 5b i traži |

**Zamka koju je našao browser, a testovi nisu mogli:** foto par i Galerija su na Početnoj crtali
iste dvije fotografije jedna ispod druge. Obje sekcije su same za sebe ispravne i obje su imale
zelen test — vidi se tek kad stoje na istom ekranu.

### Ostalo za sljedećeg

- **`services` nema kolonu za ručni redoslijed.** Uzlazno po kategoriji pa imenu je predvidivo, ne
  dobro: na `/services` je podnošljivo (vidi se cijela lista), na Početnoj nije, jer pokazuje tri.
  Ako se rješava, to je `sort_order` migracija i vlastiti task.
- **Tapovi na kontakt redove nisu odigrani.** `tel:`, mape i Instagram traže pravi uređaj;
  `launchUrl` je pozvan iz `_otvori`, ali nijednom nije otvorio aplikaciju. Greška se guta
  namjerno — v. doc komentar.
