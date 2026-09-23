# FE-504 — QA prolaz kroz sve ekrane

| | |
|---|---|
| **Epik** | FE-5 · Kvalitet i konzistentnost |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | svi ostali FE taskovi |
| **Blokira** | — |
| **Reference** | `prototype/ui/screenshots/` (17 klijentskih) · `prototype/adminv2/export/` (21 admin) · `.claude/skills/verify/` |

## Cilj
Poređenje implementacije sa izvozima dizajna, ekran po ekran.

## Zatečeno stanje
Ekrana je **38, ne 21**: 17 klijentskih u `prototype/ui/screenshots/` i 21 admin prikaz u
`prototype/adminv2/export/` (10 desktop + 11 telefon). Handoff broji samo admin stranu.

Ovo je jedini task epika čiji je dokaz **pokretanje**, ne test. Repo za to ima recept
(`.claude/skills/verify/`) i traži ga izričito: prolazna `melos run test` suite ne govori ništa o
ekranu.

## Definicija gotovog
- [ ] Svih 38 prikaza prođeno po checklisti: tipografija, razmaci, boje, stanja, tranzicije
- [ ] Provjereno na malom telefonu (360 px) i tabletu, plus 1440 i 2560 px za admin
- [ ] Tranzicija iz [FE-201](FE-201-zamjena-default-tranzicije.md) provjerena na **oba** OS-a, na uređaju
- [ ] Provjereno sa uključenim *Reduce Motion* i uvećanim sistemskim fontom
- [x] Svako odstupanje zapisano kao **zaseban task**, ne popravljeno usput
- [x] Rezultat prolaza stoji u status bloku: šta je prošlo, šta nije, i gdje su otvoreni taskovi

## Zamke
- **Ad-hoc popravka tokom QA prolaza poništava prolaz.** Ekran popravljen usred liste nije viđen u
  stanju u kojem je ostatak; zato DoD traži zasebne taskove.
- Screenshot poređenje na drugom tenantu je drugi test: boja i tekst se **moraju** razlikovati.
  Prolaz koji traži pixel-identičnost sa canvasom bi dokazao da je multi-tenant pokvaren.
- Klijent se pokreće preko `tool/run_tenant.sh <flavor>`, ne golim `flutter run` — bez `--flavor` i
  `SALON_ID` aplikacija pada na startu.

## Status

**🟡 Prvi prolaz, na webu.** Grana `docs/fe-504-qa-prolaz`, samo dokumenti. Nijedan ekran nije
diran — odstupanja su zasebni taskovi, kako DoD traži.

### Na kojem stanju

`main` + FE-502 (#94) + FE-503 (#95), spojeni **lokalno** u privremeni worktree, jer QA mora vidjeti
stanje poslije oba. Pri tome je nađena zamka u spajanju (`--theirs` vraća `buttonHeight = 36`) i
riješena na grani FE-503. Na spojenom stanju: admin 392, klijent 309, `core_ui` 104 testova PASS.

Demo web buildovi (`flutter build web --release -t lib/demo_main.dart`): klijent za **oba tenanta**
(`SALON_ID` …000 i …001), admin jedan. Snimci kroz Playwright:

- klijent: 14 ruta × 2 tenanta × **402 i 360 px** (56 snimaka), 12 parova uz
  `prototype/ui/screenshots/`;
- admin: 11 ruta × **1440, 2560, 768 i 402 px** (44 snimka), 9 parova uz
  `prototype/adminv2/export/`.

Snimci nisu u repou (slike, 100+ fajlova). Ponavljaju se istim komandama.

### Šta je prošlo

- **Klijent, po handoffu:** Početna, korak 1, Usluge, Obavijesti (prazno stanje), O aplikaciji.
  Beauty tenant nosi svoju boju i terminologiju („Rezerviši termin", „Kosa/Boja"). To je
  **tražena razlika**, ne odstupanje.
- **360 px:** nijedan red se ne presijeca. Naslovi i nazivi usluga prelaze u dva reda.
- **Admin 1440:** Pregled (`3b`), Kalendar (`3c`), Usluge (`3f`) i Osoblje (`3g`) blizu izvoza.
  Sidebar i dugmad su viši zbog FE-502 (44 px) — svjesno.
- **Admin 2560:** fluidan, bez fiksne kolone (FE-406). **402:** donja navigacija, kartice, dan u
  kalendaru.
- **Stanja greške** (FE-501) su viđena usput, na svakom ekranu kojem demo ne daje podatke: mirna
  poruka i „Pokušaj ponovo", nigdje „prazno".

### Šta nije prošlo — otvoreni taskovi

| Nalaz | Task |
|---|---|
| Klijent `/appointments` i `/settings` se u demou **sruše** (siva površina); `/gallery`, `/reviews`, `/terms`, `/privacy` pokazuju grešku; admin `/clients`, `/working-hours`, `/settings` isto. Uzrok je demo ulaz, ne produkcija, ali **devet prikaza QA ne može vidjeti** | [FE-505](FE-505-demo-ulazi-pune-sve-ekrane.md) |
| `/about` crta hero Početne, a ne `5b` (centrirano ime, podnaslov, „REZERVIŠI") | [FE-506](FE-506-o-nama-po-5b.md) |

### Šta nije provjereno

- **Tranzicija FE-201 na oba OS-a, na uređaju** — nema uređaja ni macOS-a u ovoj sesiji.
- **Reduce Motion i 130 % fonta viđeni okom** — dokazano samo testovima (FE-205 i FE-502), ne
  pokretanjem.
- **Tablet klijenta** (768+) nije snimljen. Admin na 768 crta telefonski raspored, razvučen, kako
  FE-406 određuje pojasevima. Dobro ili ne, to je dizajnerska odluka, ne greška.
- **Booking koraci 2–4, „Zahtjev poslan", modal otkazivanja i lightbox** (`04`–`07`, `16`, `17`)
  traže interakciju kroz flow. Kroz Canvas render Playwright ih ne klikće pouzdano, pa nisu viđeni.
  Admin `3a`, `3k`–`3u` gledani samo na telefonskoj širini, bez para uz izvoz.

**Sljedeći korak:** FE-505, pa ponoviti ovaj prolaz. Uz njega uređaj za FE-201.

### Dopuna poslije FE-505 (2026-09-23)

Devet prikaza koje demo nije punio viđeno je na webu, na oba tenanta. Ekrani prate handoff.
Među njima su Moji termini (`08`), Postavke (`11`), Galerija (`12`), Recenzije (`13`) i Pravila
(`15`), plus admin `3e`, `3h` i `3i`. **FE-505 je time zatvoren**; FE-504 ostaje 🟡 samo zbog
stavki koje traže uređaj ili interakciju kroz flow (v. „Šta nije provjereno" iznad).
