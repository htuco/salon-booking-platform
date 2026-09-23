# FE-503 — Čišćenje legacy stilova

| | |
|---|---|
| **Epik** | FE-5 · Kvalitet i konzistentnost |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 1 dan |
| **Zavisi od** | FE-1xx, FE-3xx, FE-4xx |
| **Blokira** | — |
| **Reference** | `apps/admin/test/no_hardcoded_colors_test.dart` · `.claude/skills/cleanup/` |

## Cilj
Poslije migracije ekrana ne ostaje mrtav stilski sloj.

## Zatečeno stanje
Ovo je zadnji task epika po redoslijedu i **ne smije početi prije** nego što su ekrani prevedeni —
inače briše ono što još nije zamijenjeno. Konkretni kandidati nastaju tek tokom epika:

- stara pisma (Space Grotesk, JetBrains Mono, DM Serif Display, Archivo) i njihove OFL licence,
  ako [FE-102](FE-102-tipografija-barlow.md) prođe;
- `uses-material-design: true` i Material icon font, ako [FE-104](FE-104-ikone.md) prođe;
- zaobljene varijante komponenti i `borderRadius` koji nije `zero` ([FE-103](FE-103-skala-razmaka.md)).

## Definicija gotovog
- [ ] Nema neiskorištenih pisama, boja ni widgeta — boje i widgeti čisti; **Barlow Bold ostaje** (ADR-0020), v. status
- [x] Grep provjere čiste: `Color(0x` van tokena, `fontFamily:` u ekranu, `borderRadius` koji nije `zero`
- [ ] Veličina bundla **nije porasla** u odnosu na stanje prije epika — izmjereno, sa brojem u status bloku
- [x] `no_hardcoded_colors_test` prošireni ekvivalent postoji i za klijenta

## Zamke
- **Font se ne briše iz `pubspec.yaml` dok grep nad `lib/` nije čist.** Flutter ne prijavi
  nedostajuću porodicu kao grešku nego tiho supstituiše sistemskim pismom — i to se vidi tek na uređaju.
- Mjerenje bundla prije i poslije mora biti isti build tip na istoj platformi, inače broj ne znači ništa.

## Status

**🟡 Djelimično — očišćeno ono što je bilo mrtvo; dvije stavke čekaju odluku, ne kod.**
Grana `chore/fe-503-legacy-stilovi`.

### Uklonjeno

- **`AdminColors`** — drugi primjerak svijetle admin palete sa statičnim konstantama. Aplikacija
  ga nije čitala nigdje; koristili su ga samo testovi. **Već se bio razišao** sa `AdminPalette`:
  `sidebarText` i `sidebarRaised` su u njemu ostali svijetli od prije FE-401, pa su testovi
  koji su ga čitali potvrđivali boje kojih na ekranu nema. Testovi sada čitaju
  `AdminPalette.light`.
- **`AdminSize.topBarButtonHeight`** — nula upotreba.
- **`SkeletonLoader.radius`** — zaobljena varijanta kostura. Svaki poziv je slao `0`; parametar
  je nudio zaobljenje u sistemu koji ga nema (FE-103).

### Grep provjere — čiste

- `Color(0x` van token fajlova: nijedan (van `contrast.dart`, `demo_main.dart` i generisanog
  registra — izuzeci iz FE-101).
- `fontFamily:` u ekranu: nijedan; pismo postavljaju samo tema i `tokens/typography.dart`.
- `borderRadius` koji nije nula u klijentu i `core_ui`: nijedan poslije `SkeletonLoader`-a.
- Klasa widgeta bez ijedne reference: nijedna. Tokeni bez upotrebe: samo gore uklonjeni.
- Klijentski `no_hardcoded_colors_test` postoji od FE-101.

### Bundle — izmjereno, **porastao je**

`flutter build web --release`, obje aplikacije, isti stroj. „Prije" je `b751704` (epik raspisan,
nijedna linija FE koda), „poslije" je ova grana.

| | prije | poslije | razlika |
|---|---|---|---|
| klijent `build/web` | 46 683 647 B | 46 706 878 B | **+23 KB** (+0,05 %) |
| klijent `main.dart.js` | 3 679 397 B | 3 702 631 B | +23 KB |
| klijent pisma | 735 176 B | 735 176 B | 0 |
| admin `build/web` | 43 209 811 B | 43 451 507 B | **+242 KB** (+0,56 %) |
| admin `main.dart.js` | 3 470 751 B | 3 610 772 B | +140 KB |
| admin pisma | 323 884 B | 424 172 B | **+100 KB** |

Klijentski rast je samo kod (FE-2xx/3xx/5xx: tranzicije, lightbox, stanja). Kod admina je
**trećina rasta pismo**: ADR-0020 je zamijenio Space Grotesk + JetBrains Mono sa četiri
statična reza Barlowa.

### Ostalo za odluku, ne za kod

- **Barlow Bold (108 KB) se ne koristi nigdje** — nijedan stil admina ne traži `w700`. Bez njega
  bi pisma admina bila **316 KB, manje nego prije epika**. Ali ADR-0020 izričito propisuje
  400–700, a `theme_tokens_test` to provjerava; odluka iz ADR-a se ne mijenja usput. Ako vlasnik
  to želi, to je kratak ADR uz ovaj broj, pa brisanje fajla i reda u `pubspec.yaml`.
- **Rast JS koda** DoD ne razdvaja od stilskog sloja. Stilskog mrtvog koda više nema; ostatak
  rasta je funkcionalnost epika i ne smanjuje se čišćenjem.
- **`uses-material-design: true` u klijentu ostaje.** Klijent nema nijednu Material ikonu
  (FE-104), ali Material widgeti ih koriste iznutra, a release build ionako izbacuje
  neiskorištene glifove iz fonta ikona. Ušteda je zanemariva, a rizik je prazan kvadrat
  umjesto ikone.

### Dokaz

Grana je spojena sa FE-502 (PR #94), pa se **spaja poslije njega**. Konflikt je riješen ovdje:
brisanje `AdminColors`/`topBarButtonHeight` pobjeđuje, a FE-502 vrijednosti (`destructive`,
`buttonHeight = touchTarget`) ostaju. **Ne rješavati ga sa `--theirs`**: to vrati
`buttonHeight = 36`, pa FE-502 testovi mete padnu, kako se u QA prolazu i desilo.

Admin 392, klijent 309, `core_ui` 104 testova PASS na spojenom stanju, analiza čista.
