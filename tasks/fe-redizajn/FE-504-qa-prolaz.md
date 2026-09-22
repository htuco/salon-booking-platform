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
- [ ] Svako odstupanje zapisano kao **zaseban task**, ne popravljeno usput
- [ ] Rezultat prolaza stoji u status bloku: šta je prošlo, šta nije, i gdje su otvoreni taskovi

## Zamke
- **Ad-hoc popravka tokom QA prolaza poništava prolaz.** Ekran popravljen usred liste nije viđen u
  stanju u kojem je ostatak; zato DoD traži zasebne taskove.
- Screenshot poređenje na drugom tenantu je drugi test: boja i tekst se **moraju** razlikovati.
  Prolaz koji traži pixel-identičnost sa canvasom bi dokazao da je multi-tenant pokvaren.
- Klijent se pokreće preko `tool/run_tenant.sh <flavor>`, ne golim `flutter run` — bez `--flavor` i
  `SALON_ID` aplikacija pada na startu.

## Status

Nije počet.
