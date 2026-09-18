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
| Dart registar (uklj. `auth.providers`) | `apps/client/lib/src/generated/tenants.g.dart` |
| iOS entitlement (Sign in with Apple) | `apps/client/ios/flavors/<flavor>.entitlements` |

Nijedan od tih fajlova se ne edituje ručno — sljedeće pokretanje ih prepisuje.
`dart run tool/gen_flavors.dart --check` pada ako su zastarjeli (koristi se u CI).

Entitlement po flavoru uključuje i push te Keychain; Xcode generator čuva taj izbor iz
xcconfiga i postojeće Flutter scheme pre-actions. Firebase app konfiguracija je po flavoru i
platformi, izvan `tenant.yaml` i gita. `tool/firebase_defines.dart` je pretvara u privatni
`FIREBASE_DEFINES_FILE` za build. Hodogram: `tasks/sprint-2/25-push-konfiguracija.md`.

## Pravila koja generator provjerava

- **`flavor` mora biti isto kao ime foldera.** Gradle traži `src/<flavor>/`, pa
  neslaganje znači da `google-services.json` završi na putanji koju build ne gleda.
- **`flavor` mora biti `[a-z][a-z0-9]*`.** Crtice i donje crte nisu validan gradle
  identifikator — `create("barber-vitez")` ne kompajlira.
- **`salonId` mora biti UUID** i mora odgovarati redu u [`supabase/seed.sql`](../supabase/seed.sql).
  Ako ne odgovara, aplikacija se builda ali ne nalazi svoj salon.
- **`branding.primaryColor` i `branding.secondaryColor` moraju biti `#RRGGBB`**, i moraju biti iste
  kao `salons.primary_color`/`secondary_color` u bazi. To su fallback boje dok backend ne odgovori —
  kad se raziđu, baza je u pravu, ali korisnik vidi treptaj boje pri startu.
- **`branding.theme`** je `modern_barber` (tamna), `elegant_beauty` (svijetla) ili `clinical_calm`;
  bira svjetlinu i neutralnu paletu. Nepoznato ime pada na `modern_barber` umjesto da sruši app.
- **`auth.providers` prima samo `apple`, `google`, `email`**, i svaka vrijednost mora
  biti `true` ili `false`. `facebook` je bio četvrti i **namjerno ga više nema**
  ([ADR-0011](../docs/adr/0011-facebook-login-se-ne-implementira.md)) — tenant koji ga zadrži
  obara generator. Nepoznat ključ ili vrijednost tipa `"da"` **obore generisanje** — tipfeler
  u konfiguraciji se tako vidi u CI-ju, a ne kao login ekran bez dugmeta kod korisnika. Tenant bez
  `auth:` bloka dobija Apple, Google i email.
- **`apple: true` na Androidu se ignoriše, ne pada.** Filtriranje po platformi radi `AuthConfig`
  ([ADR-0007](../docs/adr/0007-authconfig-u-core-domain.md)), pa ista lista vrijedi za oba builda.

## Build

```sh
tool/build_tenant.sh <flavor> apk release
```

`SALON_ID` je jedini `--dart-define` koji opisuje **tenanta**: ime, vertikala, fallback boje i lista
auth providera se traže u generisanom registru po tom UUID-u, pa se ne prosljeđuje svako polje
posebno.

Uz njega idu define-ovi koji opisuju **okruženje**, i oni nikad nisu u repou:
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `API_URL`, te `GOOGLE_WEB_CLIENT_ID` i `GOOGLE_IOS_CLIENT_ID`.
Google client ID je **po flavoru** — skripta traži prvo `GOOGLE_WEB_CLIENT_ID_<FLAVOR>`, pa tek onda
zajednički. Detalji i hodogram kroz konzole:
[`tasks/sprint-2/12-konzole-checklist.md`](../tasks/sprint-2/12-konzole-checklist.md).
