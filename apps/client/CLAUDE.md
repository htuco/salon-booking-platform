# apps/client/ — Flutter, N flavora

Brandirana klijentska aplikacija. Jedan codebase, N tenanata. Root pravila važe — v. `../../CLAUDE.md`.

## Generisano se ne edituje

`lib/src/generated/tenants.g.dart`, gradle blok između `BEGIN/END GENERATED FLAVORS`,
`ios/flavors/*.xcconfig`, iOS konfiguracije i scheme u `Runner.xcodeproj`, i
`flutter_launcher_icons-*.yaml` su izlaz iz `tenants/*/tenant.yaml`. Mijenja se `tenant.yaml`, pa
`dart run tool/gen_flavors.dart`. CI pada na `--check`. Detalji i zamke:
`../../.claude/docs/tenant-factory.md`.

## Pravila specifična za ovu app

- **`SALON_ID` je jedini `--dart-define`** koji build prosljeđuje; ostalo se traži u generisanom
  registru po tom UUID-u. Bez njega app se builda i ne nađe svoj salon.
- **Nijedan string koji se razlikuje po vertikali ne smije stajati u `.dart` fajlu ekrana** — ide
  kroz `Vertical.terms`. Takav string se ne može promijeniti bez store submissiona. Jezik
  aplikacije (dugmad, greške) ide kroz `.arb` — to su dvije različite stvari.
- **Nijedna boja se ne piše kao literal.** Tema dolazi iz backenda, sa fallbackom iz `tenant.yaml`.
- **Nula availability i booking logike u Dartu.** Backend računa slobodne termine i ponovo validira
  slot pri kreiranju; app prikazuje listu koju dobije i obrađuje `409`.
- **`Theme.of(context)` u `build` metodi koja sama postavlja `MaterialApp` vraća Flutterov default**,
  ne tenant temu — tijelo mora biti zaseban widget. Ta greška je već napravljena jednom
  (`a53a429`), i `test/tenant_theme_test.dart` postoji zbog nje.
- Testovi teme se pokreću **sa `--dart-define=SALON_ID` za oba demo tenanta**; bez definea tema je
  svijetla i neusklađenost se ne vidi.

## Build i dokaz

```sh
tool/build_tenant.sh <flavor> <apk|aab|ios> [debug|release]
```

Provjerava se **artefakt**, ne konfiguracija: `aapt2 dump badging` za Android, `PlistBuddy` nad
`Info.plist` za iOS. Recepti: `../../.claude/skills/verify/SKILL.md`.
