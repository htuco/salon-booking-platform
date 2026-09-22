# FE-101 — Paleta kao dizajn tokeni

| | |
|---|---|
| **Epik** | FE-1 · Temelji i dizajn tokeni |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | ADR o koralnoj na klijentu (v. [README](README.md)) |
| **Blokira** | FE-3xx, FE-4xx |
| **Reference** | `apps/admin/lib/src/core/theme/admin_colors.dart` · `packages/core_ui/lib/src/theme/theme_factory.dart` · `prototype/admin/SPEC.md` |

## Cilj
Handoff traži da boje odu u tokene i da koralna bude akcent. **Veći dio toga već postoji** — ovaj
task zatvara ostatak i, što je važnije, sprječava da se koralna upiše na mjesto gdje je ne smije biti.

## Zatečeno stanje
Ne ono što task iz handoffa pretpostavlja:

- Boje **jesu** centralizovane. Od 135 `Color(0x…)` u repou, 129 stoji u tri token fajla:
  `apps/admin/lib/src/core/theme/admin_colors.dart` (76), `packages/core_ui/lib/src/theme/app_theme.dart`
  (33) i `packages/core_ui/lib/src/tokens/status_colors.dart` (20).
- Kriterij „nema hex vrijednosti izvan token fajla" **već je test koji pada**:
  `apps/admin/test/no_hardcoded_colors_test.dart` čita izvor svakog admin ekrana i prijavljuje
  `Color(0x`, `Color.fromARGB` i `Colors.*`. Klijent takav test nema.
- Koralna `#EE6C4D` je specificirana i implementirana kao akcent **admina**
  (`prototype/admin/SPEC.md:82`, tekst na koralu `#2C2C2C`).
- Van tokena su ostala dva mjesta: `packages/core_ui/lib/src/components/app_dialog.dart` i
  `packages/core_ui/lib/core_ui.dart`.

## Definicija gotovog
- [ ] Dva preostala hex-a u `core_ui` idu u tokene ili dobiju napisan izuzetak
- [ ] Klijent dobija svoj ekvivalent `no_hardcoded_colors_test` — danas ga nema, pa pravilo
      „boja dolazi iz `tenant.yaml`" ništa ne provodi osim pregleda
- [ ] Koralna ostaje **admin** akcent; klijentska brand boja i dalje dolazi iz `tenant.yaml`
      kroz `buildAppTheme()`
- [ ] Kontrast teksta na koralnoj ≥ 4,5:1 dokazan testom, ne okom (`packages/core_ui/test/contrast_test.dart`
      već ima aparaturu)
- [ ] Dark/light varijante klijenta ostaju van obima — zapisano kao dug, ne prećutano

## Zamke
- **Ovo je task u kojem je najlakše slomiti multi-tenant.** `primary` u klijentu nije boja nego
  vrijednost po salonu; koralna kao globalni `primary` prolazi analizu, prolazi testove i vidi se
  tek kad se pokrene drugi flavor.
- `Colors.transparent` je jedini izuzetak koji admin test već priznaje — nije boja nego odsustvo
  boje, i tema njime gasi Material `surfaceTint`.
- Token fajl nije mjesto za „skoro istu" boju. Dvije nijanse iste uloge su znak da uloga fali.

## Status

Nije počet.
