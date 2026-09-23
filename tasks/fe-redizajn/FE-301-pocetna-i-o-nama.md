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
- [x] Primarni CTA je jedini naglašeni element na ekranu
- [x] Hero se učitava sa placeholderom, bez pomjeranja sadržaja kad slika stigne
- [x] Tekst dolazi iz `vertical.terms`, ne iz canvasa — „Majstori" je barber terminologija
- [x] Boja naglaska dolazi iz `tenant.yaml`, ne iz handoff hex-a
- [x] Postojeći testovi ekrana prepisani, ne obrisani

## Zamke
- **Iz handoffa se uzima oblik, ne boja i ne tekst** (`CLAUDE.md`, tvrdo pravilo). Hardkodiran hex
  ili naziv usluge prolazi pregled screenshota i pada tek na drugom tenantu.
- `home_screen_test.dart` danas očekuje `CircularProgressIndicator` — usklađuje se sa
  [FE-205](FE-205-ukidanje-default-flutter-indikatora.md), pa se ta dva taska ne rade paralelno nad istim fajlom.

## Status

**Gotovo, dokazano.** Grana `feat/fe-301-pocetna-i-o-nama`.

### Ekrani su već bili po handoffu — posao je bio jedan stvaran kvar

Oba ekrana su redizajnirana još u taskovima 18–20: hero, CTA, Cjenovnik, tim, Galerija,
Recenzije, „O nama" sa pričom, radnim vremenom i kontaktom. Četiri od pet DoD stavki su
stajale prije prve izmjene:

- **CTA je jedini naglašen** — „Prikaži svih N" i CTA na `/about` su `outline`.
- **Tekst iz `vertical.terms`** — CTA (`bookCta`), naslov tima (`staffPlural`) i
  naslov bez cijena (`servicePlural`); drži ih postojeći test „naslovi sekcija i CTA
  dolaze iz vertical.terms".
- **Boja iz tenanta** — grep `0x…`/`Color(`/`Colors.` u `home/` i `about/` ne vraća ništa.
- **Testovi ekrana** — zadržani i dopunjeni, nijedan obrisan.

### Šta je popravljeno: hero je skakao pri učitavanju

Kostur je crtao hero od **320** i razmak `xl` ispod njega; pravi hero je **420** bez
razmaka. CTA je zato poskočio **78 px** nadolje tačno kad salon stigne — na obje rute.
`HomeHero.visinaSlike` je sada javna konstanta i oba kostura je koriste; razmak je uklonjen.

Usput: `_statusTekst` je bio prepisan u oba ekrana — sada je jedan `salonStatusLabel`
uz `HomeHero`.

### Dokaz

- Dva nova testa (`home_screen_test`, `about_screen_test`) mjere **vrh** CTA-a u kosturu
  i nakon učitavanja. Sabotaža (vraćen razmak) daje `Expected 442.0, Actual 420.0`.
- Klijent **252 testa PASS**, `flutter analyze` čist.
- Demo web build na 402×874: raspored prati `01-pocetna.png`, CTA u boji tenanta.
  Sam skok se u demou **ne vidi** — provideri su stubovani i podaci stižu odmah — zato
  je pokriven testom, ne tvrdnjom.
