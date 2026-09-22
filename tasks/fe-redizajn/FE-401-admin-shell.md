# FE-401 — Admin ljuska i Melura branding

| | |
|---|---|
| **Epik** | FE-4 · Admin panel |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | ✅ [ADR-0016](../../docs/adr/0016-adminv2-je-vizuelni-izvor-istine-za-admin.md) — riješen, task odblokiran |
| **Blokira** | FE-402…FE-405 |
| **Reference** | `apps/admin/lib/src/core/widgets/admin_scaffold.dart` · `apps/admin/lib/src/core/navigation/admin_destinations.dart` · `prototype/adminv2/export/` |

## Cilj
Sidebar sa Melura wordmarkom, oznakom uloge i navigacijom po novom handoffu.

## Zatečeno stanje
Ljuska **postoji i nije trivijalna** — `AdminScaffold` već rješava ono što handoff traži kao novo:

- Jedan route model, dvije ljuske: sidebar iznad `AdminBreakpoint.desktop = 840`, donja navigacija
  ispod. Obje čitaju `kAdminDestinations`; nema ekrana koji postoji samo na jednoj širini.
- Prag 840 je **odabran sa obrazloženjem** (Material `expanded`), jer canvas crta samo 1440 i 402.
- `AdminShell.jeDesktop` / `gutterOf` su statičke metode nad `MediaQuery` **namjerno**: ekran gradi
  tijelo prije nego ga ljuska primi, pa bi `InheritedWidget` uvijek vratio telefonske vrijednosti.

Za preimenovanje: „Salon OS" stoji na **dva mjesta u UI-u** — `admin_scaffold.dart:157` i
`login_screen.dart:505` (uz znak `SO` u kvadratu) — i u **tri asercije** u
`admin_shell_test.dart` i `login_screen_test.dart`. Stringa `salonos.ba` u kodu nema.

## Definicija gotovog
- [ ] Wordmark **Melura** i logo placeholder u sidebaru i na prijavi
- [ ] Znak `SO` zamijenjen; nijedan „Salon OS" string ne ostaje u UI-u
- [ ] Tri testa koja traže „Salon OS" prepisana na novo ime, ne obrisana
- [ ] Navigacija u velikim slovima, aktivna stavka sa lijevom oznakom u koralnoj
- [ ] Oznaka uloge ispod imena korisnika
- [ ] Sidebar se i dalje sklapa ispod praga — postojeće ponašanje ostaje dokazano istim testom
- [x] `prototype/CLAUDE.md` dopunjen: šta je `adminv2/` i koji handoff je jači — urađeno uz
      [ADR-0016](../../docs/adr/0016-adminv2-je-vizuelni-izvor-istine-za-admin.md), prije ovog
      taska, jer je blokiralo svih pet preostalih FE-4xx
- [ ] `admin/SPEC.md` ispravljen na dva mjesta koja ADR-0016 imenuje kao zastarjela: ime
      proizvoda (`SPEC.md:1`) i raspodjela akcenta (`SPEC.md:81–82`)

## Zamke
- **Koralna ovdje je ispravna** (admin je jedan platformski build za sve salone); ista boja u
  klijentu nije. Ne prenositi je kroz `core_ui`.
- Prag 840 nije iz canvasa i ima zapisan razlog. Ako novi handoff traži drugi, mijenja se i taj
  komentar, inače sljedeći čitalac nađe dva obrazloženja.
- Preimenovanje proizvoda dira i `docs/`; ime se ne mijenja samo u UI-u.

## Status

Nije počet.
