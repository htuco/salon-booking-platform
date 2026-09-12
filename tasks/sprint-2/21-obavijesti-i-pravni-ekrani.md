# Task 21 — Client: Obavijesti, "O aplikaciji" i "Pravila korištenja"

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [18](18-pocetna-i-tab-bar.md) |
| **Blokira** | store submission (pravila su obavezna) |
| **Reference** | `prototype/ui/screenshots/10-obavijesti.png`, `14-o-aplikaciji.png`, `15-pravila-koristenja.png` |

## Cilj
Zadnja tri ekrana iz handoffa. Dva su formalnost bez koje submission pada, jedan je mjesto gdje
push notifikacije slijeću.

## Definicija gotovog
- [ ] `/notifications` po 5j: potvrde, podsjetnici, objave salona; nepročitano se razlikuje
- [ ] `/about-app` po 5n: verzija, "Kako radi" u tri koraka, pravni redovi
- [ ] `/terms` po 5o: šest numerisanih sekcija (zakazivanje, otkazivanje, kašnjenje, cijene,
      podaci, kontakt)
- [ ] Tekst pravila dolazi **po tenantu** (`salons` kolona ili `settings`), ne kao literal u app-i
- [ ] Verzija se čita iz `package_info_plus`, ne iz konstante koja zastari

## Koraci
1. Pravila i "O aplikaciji" prvo — statični su i otključavaju submission
2. Obavijesti nakon taska 25, da imaju šta prikazati
3. Commit: `feat(client): obavijesti i pravni ekrani`

## Zamke
- **Politika privatnosti je po tenantu i mora imati javni URL** ([01 §17](../../docs/01-mvp-spec.md#17-build-order)
  korak 29). Ekran u app-i je ne zamjenjuje.
- Lista obavijesti bez servera je lokalna historija pusheva — reci to u praznom stanju, ne glumi
  server koji ne postoji.
