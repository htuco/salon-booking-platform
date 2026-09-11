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
- **Ekran ne uvozi `supabase_flutter`.** Jedini izuzetak je `lib/src/core/env/bootstrap.dart`, koji
  poziva `Supabase.initialize`. Sve ostalo ide kroz repozitorij i provider iz `core_api`
  (`servicesProvider`, `salonProvider`, …). Ekran koji uveze Supabase zaobišao je sloj grešaka i
  prvi put kad upit padne pokazaće sirovi `PostgrestException`.
- **Greška se hvata kao `ApiError`, nikad kao `PostgrestException`.** `ApiError` je `sealed`, pa
  `switch` nad njim mora pokriti `NetworkError`, `NotFoundError`, `ConflictError`, `ServerError` i
  `MappingError` — tek ta razlika daje ekranu da zna nudi li "pokušaj ponovo" ili osvježenu listu.
- **`currentSalonIdProvider` mora biti override-ovan** u `ProviderScope`-u (`coreApiOverrides` u
  `lib/src/core/vertical_provider.dart`). `core_api` ne zna za `--dart-define`; bez override-a
  svaki repozitorij baca `UnimplementedError` na prvom pozivu.
- **Vremena iz baze su `LocalTime`/`LocalDate`, ne `DateTime`.** To su zidna vremena salona bez
  zone; `DateTime` bi ih vezao za zonu uređaja i pomjerio radno vrijeme.
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
