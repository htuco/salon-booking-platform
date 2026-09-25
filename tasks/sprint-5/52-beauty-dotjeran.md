# Task 52 — Beauty tenant dotjeran

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [49](49-slike-usluga-i-radnika.md), [50](50-galerija-logo-cover.md) |
| **Blokira** | — |
| **Reference** | `docs/05` §3 · ADR-0018 · `tenants/beautystudiotravnik/tenant.yaml` · sprint-3 task 30 (🟡 drugi tenant) |

## Cilj
`beautystudiotravnik` izgleda kao pravi beauty salon i stoji uživo na hostovanom projektu, kao i barber.

## Definicija gotovog
- [ ] Svježi snimci beauty flavora prije promjene (zadnji u `docs/screenshots/` su od 13.09., prije FE-5xx)
- [ ] Paleta `elegant_beauty` dotjerana u `core_ui` — **tema, ne salon**: svaki beauty salon je dobija
- [ ] Rod u terminologiji: „Klijentica", „Stilistica" gdje salon to traži (`terminologyOverride`)
- [ ] Prave slike usluga, radnika i galerije u seedu umjesto praznih kvadrata
- [ ] Admin nalog `admin@beautystudiotravnik.test` na hostovanom projektu (ostatak taska 30)
- [ ] `googleReversedClientId` u `tenant.yaml` (prazno dok konzola ne da ID), generator pokrenut
- [ ] Uživo: beauty build na Android uređaju — ime, ikona, boje, zakazivanje, push salonu
- [ ] Snimci poslije, uz barber za poređenje

## Zamke
- **Hex ne ide u ekran.** Boja ide kroz `tenant.yaml` i `buildAppTheme()`; hardkodiran hex se vidi
  tek na trećem salonu.
- Tipografija ostaje ista (ADR-0019). Ako se ipak traži drugo pismo za beauty, to je ADR i veže se
  za temu, ne za salon.
- Generisane fajlove ne diraš rukom — `dart run tool/gen_flavors.dart`, pa `--check`.

## Status
Nije počet.
