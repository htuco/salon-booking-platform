# FE-502 — Pristupačnost i kontrast

| | |
|---|---|
| **Epik** | FE-5 · Kvalitet i konzistentnost |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | [FE-101](FE-101-tokeni-boja.md), [FE-102](FE-102-tipografija-barlow.md) |
| **Blokira** | — |
| **Reference** | `packages/core_ui/test/contrast_test.dart` · `packages/core_ui/lib/src/theme/contrast.dart` |

## Cilj
Kontrast, dodirne površine i uvećan sistemski font ne lome nijedan ekran.

## Zatečeno stanje
Kontrast **već ima aparaturu i test**: `packages/core_ui/lib/src/theme/contrast.dart` nosi `readableOn`, a
`buildAppTheme` pomjera brand boju dok ne bude čitljiva na **obje** površine teme (pozadina ekrana
i kartica), računajući prema težem slučaju. `contrast_test.dart` to provjerava.

Ono što ne postoji: provjera dodirnih meta i ponašanja pri uvećanom sistemskom fontu.

## Definicija gotovog
- [ ] Tekst ≥ 4,5:1, naslovi ≥ 3:1 — dokazano testom, ne okom
- [ ] Sve dodirne mete ≥ 44 px, uključujući tabove i slotove
- [ ] Aplikacija podnosi sistemski font uvećan do 130 % bez presijecanja teksta
- [ ] Fokus je vidljiv na svim interaktivnim elementima (bitno za admin na webu)
- [ ] Uppercase je stil, ne `toUpperCase()` nad stringom — čitač ekrana čita slova umjesto riječi
- [ ] Postojeći `contrast_test` proširen na nove tokene, ne zaobiđen

## Zamke
- **Kontrast se ne mjeri na jednoj pozadini.** Ista boja nosi tekst i na pozadini ekrana i na
  kartici; `buildAppTheme` to već računa i tu logiku ne treba ponavljati u ekranu.
- Uvećan font najprije lomi ono što je „taman stalo" — a [FE-102](FE-102-tipografija-barlow.md) mijenja visinu svakog reda.
  Zato ovaj task ide poslije njega.
- Koralna na bijeloj je 3,05:1 (`prototype/admin/SPEC.md:104`) — zato tekst na koralu jeste `#2C2C2C`,
  a ne bijel. To je već izmjereno i ne preispituje se bez novog mjerenja.

## Status

Nije počet.
