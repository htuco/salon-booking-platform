# Task 28 — Admin tema, tipografija i tokeni

| | |
|---|---|
| **Procjena** | 1 dan |
| **Zavisi od** | [23](../sprint-2/23-admin-login-i-lista.md) |
| **Blokira** | 29, 30 — i svaki naredni ekran |
| **Reference** | [`prototype/admin/SPEC.md`](../../prototype/admin/SPEC.md) · [`prototype/admin/README.md`](../../prototype/admin/README.md) |

## Cilj
Jedno mjesto sa bojama, tipografijom, razmacima i radiusom admina. Dok ga nema, svaki sljedeći
ekran prepisuje hex iz handoffa i nema ga gdje promijeniti.

## Definicija gotovog
- [ ] `apps/admin/lib/src/core/theme/` nosi tokene iz `SPEC.md` — danas ima samo `.gitkeep`
- [ ] **Space Grotesk** (400/500/600/700) i **JetBrains Mono** (400/500/600) su **lokalno
      zapakovani**, ne sa Google Fonts: izgled admina ne smije zavisiti od mreže
- [ ] JetBrains Mono nosi datume, vrijeme, brojčane metrike i statusne oznake; Space Grotesk sve
      ostalo
- [ ] `main.dart` više ne gradi temu iz `ColorScheme.fromSeed(Color(0xFF171717))`
- [ ] Nijedan admin ekran nema hardkodiran hex — provjereno `grep`-om, ne pogledom
- [ ] Test koji pada ako boja procuri nazad u ekran

## Koraci
1. Tokeni i `ThemeData` u `core/theme/`, po tabeli iz `SPEC.md`
2. Fontovi u `assets/fonts/` + `pubspec.yaml`
3. Postojeća četiri ekrana prelaze na temu, bez promjene ponašanja
4. Commit: `feat(admin): centralizuj temu, tipografiju i tokene`

## Zamke
- **Admin nema `core_ui`.** `core_ui` je klijentska tema koja boju uzima iz `tenant.yaml`. Admin je
  jedan build za sve salone i njegova plava je identitet Salon OS-a. Uvoz `core_ui` u admin prolazi
  analizu, prolazi test, i vidi se tek kad dva salona otvore istu aplikaciju.
- **Radius je `6px`, ne `0`.** Klijentska app ima radius 0 iz `prototype/ui/`; to je drugi proizvod
  i drugi handoff. Prepisivanje navike iz `core_ui` je ovdje greška.
- Statusna oznaka mora nositi **tekst**, ne samo boju (`SPEC.md`, „Raspored i komponente").

## Status

Nije počet.
