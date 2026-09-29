# Task 52 — Beauty tenant dotjeran

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [49](49-slike-usluga-i-radnika.md), [50](50-galerija-logo-cover.md) |
| **Blokira** | — |
| **Reference** | **`prototype/beauty/`** (handoff teme, 2026-09-27) · `docs/05` §3 · ADR-0018 · `tenants/beautystudiotravnik/tenant.yaml` · sprint-3 task 30 (🟡 drugi tenant) |

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
  za temu, ne za salon. **Handoff u `prototype/beauty/` traži Jost za sav tekst** — to je upravo
  taj slučaj: prvo ADR (ili odluka da beauty ostaje na DM Serif + Archivo), pa kod.
- Brand uloge (`primary`, `brandLine`, `brandInk`, `brandContainer`) se izvode iz jedne boje
  (`prototype/beauty/README.md`, algoritam). Sirova `#B76E79` kao `primary` pada AA sa bijelim
  tekstom (~3.8:1).
- Handoff skida blur sa modala — to dira `AppDialog` za sve teme, pa se odlučuje izričito.
- Generisane fajlove ne diraš rukom — `dart run tool/gen_flavors.dart`, pa `--check`.

## Status (2026-09-29)

U toku, [PR #120](https://github.com/htuco/salon-booking-platform/pull/120), grana
`feat/beauty-dotjeran`.

**Odlučeno:** [ADR-0025](../../docs/adr/0025-pismo-i-uloge-izbora-vezu-se-za-temu.md) — pismo i
uloge izbora su po temi; beauty dobija Jost i brand boju za izbor, barber ostaje isti, **blur
modala ostaje svima** (izbor vlasnika projekta, mimo handoffa).

**Urađeno u kodu:** paleta `elegant_beauty` iz handoffa, `BrandRoles.derive` (OKLCH; ruža daje
`#A7606B` / `#A25B66` kao handoff), `AppSelectionColors` u pet komponenti, Jost zapakovan uz OFL,
`kicker` iz teme, `googleReversedClientId: ''` u beauty `tenant.yaml`. Rod u terminologiji je
već bio isporučen kroz vertical pack `beauty` u seedu.

**Dokaz:** `Analiza, format i testovi` zelen na PR #120 — `No issues found!`, `gen_flavors
--check` prolazi, core_ui 119 (novi `theme_per_tema_test.dart`: pismo, skala, barber nepromijenjen,
sedam brandova drži pragove), client 397, admin 470. Format je provjeren i lokalno kroz
`dart:3.13` u Dockeru.

**Nije dokazano:** mašina nema Flutter (vlasnik ne želi instalaciju), pa ekran nije viđen. Snimci *prije* nisu napravljeni prije promjene — prave se iz
`main`-a na mašini sa Flutterom.

**Ostalo za sljedećeg:**
- Snimci prije (`git worktree add ../prije main`) i poslije, beauty uz barber, 402 širine
- Prave slike usluga, radnika i galerije u seedu — treba izvor fotografija (pravac u
  `prototype/beauty/Beauty Tema.dc.html` §6); prazno stanje okvira mora ostati dokazano negdje
- `admin@beautystudiotravnik.test` na hostovanom projektu (traži pristup projektu)
- Uživo na Android uređaju: ime, ikona, boje, zakazivanje, push salonu
