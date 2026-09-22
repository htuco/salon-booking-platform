# FE-104 — Ikone: jedan set, jedna debljina linije

| | |
|---|---|
| **Epik** | FE-1 · Temelji i dizajn tokeni |
| **Aplikacija** | `apps/client` (admin ostaje na Materialu) |
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | ~~ADR o setu ikona~~ — **pao**, [ADR-0017](../../docs/adr/0017-lucide-je-set-ikona-klijenta-material-ostaje-u-adminu.md) |
| **Blokira** | — |
| **Reference** | `prototype/ui/SPEC.md:51` · `packages/core_ui/lib/src/components/` |

## Cilj
Jedna debljina poteza i svedene veličine u **klijentskoj** aplikaciji. Set je odabran:
Lucide u klijentu i `core_ui`-ju, Material ostaje u adminu (ADR-0017).

## Zatečeno stanje

**Ovaj odjeljak je 2026-09-22 ispravljen — ranija verzija je bila netačna i po njoj je task
izgledao mnogo veći nego što jeste.**

Ranije je pisalo „116 upotreba `Icons.*`" i da „za Lucide ne postoji ništa u `pubspec.yaml`
nijedne aplikacije". Izmjereno stanje:

- `lucide_icons_flutter: ^3.1.19` **je** u `apps/client/pubspec.yaml:68` i
  `packages/core_ui/pubspec.yaml:20`; uvezen u 12 fajlova klijenta i četiri `core_ui` komponente.
- Material `Icons.*` je **61, sve u `apps/admin`** — admin se po
  ADR-0017 **ne prevodi**, pa to nije dug ovog taska.
- **Zamka u brojanju:** Lucide svoju klasu zove `LucideIcons`, a taj identifikator se
  **završava** na `Icons`. Zato naivni `grep "Icons\."` u klijentu daje 34 pogotka i hvata
  `LucideIcons.scissors` kao da je Material. Pouzdan izraz traži negative lookbehind:
  `grep -P "(?<!Lucide)\bIcons\."` — i tada klijent daje **četiri**.
- **Stvarni Material ostatak u klijentu su četiri upotrebe dvije ikone**, prepoznatljive po
  `snake_case` imenu:
  - `Icons.cloud_off_outlined` — `about_screen.dart:57`, `home_screen.dart:470`,
    `services_screen.dart:91`
  - `Icons.inbox_outlined` — `services_screen.dart:80`
- `uses-material-design: true` stoji u **oba** `pubspec.yaml`-a.

## Definicija gotovog
- [x] ADR bira nosioca — [ADR-0017](../../docs/adr/0017-lucide-je-set-ikona-klijenta-material-ostaje-u-adminu.md): pub paket `lucide_icons_flutter`
- [x] Četiri preostale Material upotrebe u klijentu zamijenjene Lucide ekvivalentom
      (`cloudOff`, `inbox`) — guard test drži pravilo
- [x] Nema ispunjenih ikona u klijentskom UI-u — Lucide je cijeli linijski, provjereno da nema
      nijedne `*Filled`/`*Solid` varijante
- [x] Veličine su **tokeni po ulozi** (`iconInline` 18, `iconAction` 22, `iconEmptyState` 48,
      `navIcon` 23), ne generička 16/20/24 skala — obrazloženje u statusu ispod
- [x] Ikona nasljeđuje boju iz teme; tri mjesta je postavljaju eksplicitno, ali **iz tokena**
      (`status.danger`, `scheme.surface`, `scheme.onSurfaceVariant`), nijedno iz hexa
- [x] `uses-material-design: true` **ostaje u oba** — admin po ADR-0017 crta Material ikone, a
      klijent ga treba za Material komponente. Ovo je izmjena u odnosu na raniju verziju taska.

## Zamke
- **`Icons` je dvosmislen identifikator.** Lucide i Material obje klase zovu `Icons`, i u fajlu
  koji uvozi oba pobjeđuje zadnji import. Ime u `camelCase` je Lucide, u `snake_case` Material —
  to je jedini pouzdan način da se razlikuju grepom.
- **Lucide nema punu zvjezdicu** — set je cijeli linijski. `StarRating` je zato crtana površina, ne
  ikona; razlog je zapisan u `packages/core_ui/lib/src/components/star_rating.dart:11` i ne
  vraća se na ikonu.
- Ikona u `IconData` polju modela znači da set nije zamjenjiv bez dodirivanja modela.
- Tree-shaking ikona radi samo za konstantne `IconData`. Set koji ikonu bira po stringu u
  runtime-u isključi shaking i tiho naduva bundle.
## Status

**Gotovo, dokazano.** Grana `feat/fe-104-ikone-jedna-debljina`.

Urađeno:

- Četiri preostale Material upotrebe zamijenjene Lucideom: `LucideIcons.cloudOff` ×3
  (`about_screen`, `home_screen`, `services_screen`) i `LucideIcons.inbox` ×1
  (`services_screen`). **Klijent i `core_ui` sada nemaju nijednu Material ikonu.**
- **Veličine ikona su tokeni, ne brojevi u ekranu.** `AppSize.iconInline` (18),
  `iconAction` (22), `iconEmptyState` (48), uz postojeći `navIcon` (23) iz
  `prototype/ui/SPEC.md:51`. Sedam mjesta prevedeno na njih.
- **Guard test** `apps/client/test/icon_set_test.dart` — skenira izvor i pada ako Material
  ikona uđe u klijenta ili `core_ui`. Provjereno da stvarno pada: privremeno vraćena
  `Icons.inbox_outlined` je prijavljena uz fajl i broj reda.

**304 testa PASS** (bilo 303), `dart analyze apps/client packages` čist, `dart format` bez
promjena.

### Odstupanje od prvobitnog DoD-a, sa razlogom

- **Veličine nisu svedene na 16/20/24.** Ta skala nije iz handoffa — `prototype/ui/SPEC.md`
  propisuje **samo 23** za donju navigaciju. Zatečene 18/22/48 su konzistentne **po ulozi**
  (inline u redu teksta / dodirna meta / prazno stanje), pa su te uloge imenovane kao tokeni
  umjesto da se svedu na generičku skalu. Svođenje bi bilo vizuelna promjena na desetak
  ekrana bez ijednog izvora koji je traži.
- **`uses-material-design: true` ostaje u oba `pubspec.yaml`-a.** Prvobitni DoD ga je htio
  preispitati „ako Material ikone odu". One su otišle iz klijenta, ali admin ih po
  [ADR-0017](../../docs/adr/0017-lucide-je-set-ikona-klijenta-material-ostaje-u-adminu.md)
  zadržava (61 upotreba), a klijentu zastavica treba za Material komponente.
