# FE-301 — Početna i „O nama"

| | |
|---|---|
| **Epik** | FE-3 · Klijentski ekrani |
| **Aplikacija** | `apps/client` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | [FE-101](FE-101-tokeni-boja.md), [FE-102](FE-102-tipografija-barlow.md) |
| **Blokira** | — |
| **Reference** | `apps/client/lib/src/features/home/` · `apps/client/lib/src/features/about/` · `prototype/ui/screenshots/01-pocetna.png`, `02-o-nama.png` |

## Cilj
Početna (hero, primarni CTA, najave) i „O nama" po handoffu.

## Zatečeno stanje
Oba ekrana **postoje** (`features/home/`, `features/about/`) — ovo je redizajn, ne izgradnja.
Referentni canvasi su `prototype/ui/screenshots/01-pocetna.png` i `02-o-nama.png`; to su isti fajlovi
koje handoff zove `design_handoff_salon_booking/screenshots/`, samo pod putanjom ovog repoa.

`prototype/ui/README.md` upozorava da su **svih 45 slotova za fotografije placeholderi** — hero
površina se zato gradi tako da dolazak prave slike ne pomjeri ništa ispod nje.

## Definicija gotovog
- [ ] Primarni CTA je jedini naglašeni element na ekranu
- [ ] Hero se učitava sa placeholderom, bez pomjeranja sadržaja kad slika stigne
- [ ] Tekst dolazi iz `vertical.terms`, ne iz canvasa — „Majstori" je barber terminologija
- [ ] Boja naglaska dolazi iz `tenant.yaml`, ne iz handoff hex-a
- [ ] Postojeći testovi ekrana prepisani, ne obrisani

## Zamke
- **Iz handoffa se uzima oblik, ne boja i ne tekst** (`CLAUDE.md`, tvrdo pravilo). Hardkodiran hex
  ili naziv usluge prolazi pregled screenshota i pada tek na drugom tenantu.
- `home_screen_test.dart` danas očekuje `CircularProgressIndicator` — usklađuje se sa
  [FE-205](FE-205-ukidanje-default-flutter-indikatora.md), pa se ta dva taska ne rade paralelno nad istim fajlom.

## Status

Nije počet.
