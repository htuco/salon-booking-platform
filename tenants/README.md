# tenants/

Jedan folder po klijentu. `tenant.yaml` je **jedini fajl koji se piše po klijentu** —
sve ostalo (logo, cover, usluge, radnici, radno vrijeme, tekstovi) živi u backendu
i uređuje se kroz super admin konzolu.

Puna specifikacija polja: [docs/04 §3](../docs/04-flutter-tenant-factory.md#3-tenantyaml--jedini-fajl-koji-pišeš-po-klijentu).

## Novi klijent

```sh
cp -r tenants/_template tenants/<flavor>
# popuni tenant.yaml, pa:
dart run tool/gen_flavors.dart
```

Generator iz `tenant.yaml` pravi:

| Izlaz | Gdje |
|---|---|
| Android `productFlavors` | `apps/client/android/app/build.gradle.kts` (blok između `BEGIN/END GENERATED FLAVORS`) |
| `google-services.json` placeholder | `apps/client/android/app/src/<flavor>/` |
| iOS `xcconfig` | `apps/client/ios/flavors/<flavor>.xcconfig` |
| Dart registar | `apps/client/lib/src/generated/tenants.g.dart` |

Nijedan od tih fajlova se ne edituje ručno — sljedeće pokretanje ih prepisuje.
`dart run tool/gen_flavors.dart --check` pada ako su zastarjeli (koristi se u CI).

## Pravila koja generator provjerava

- **`flavor` mora biti isto kao ime foldera.** Gradle traži `src/<flavor>/`, pa
  neslaganje znači da `google-services.json` završi na putanji koju build ne gleda.
- **`flavor` mora biti `[a-z][a-z0-9]*`.** Crtice i donje crte nisu validan gradle
  identifikator — `create("barber-vitez")` ne kompajlira.
- **`salonId` mora biti UUID** i mora odgovarati redu u [`supabase/seed.sql`](../supabase/seed.sql).
  Ako ne odgovara, aplikacija se builda ali ne nalazi svoj salon.

## Build

```sh
flutter build apk --flavor <flavor> --dart-define=SALON_ID=<uuid>
```

`SALON_ID` je jedini `--dart-define` koji build prosljeđuje. Ime, vertikala i
fallback boje se traže u generisanom registru po tom UUID-u, pa se ne prosljeđuje
svako polje posebno.
