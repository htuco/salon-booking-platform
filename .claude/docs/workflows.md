# Workflows — komande i dokazi

Sve komande se pokreću iz roota repoa osim gdje ne piše drugačije.

## Preduslovi

| Alat | Zašto | Napomena |
|---|---|---|
| Flutter (stable) + Dart SDK ≥ 3.13 | sve u `apps/` i `packages/` | CI koristi `subosito/flutter-action@v2`, kanal `stable` |
| JDK 17 | Android build | CI: `temurin` 17 |
| Node + npm | web prototip i lefthook | `npm i` |
| Supabase CLI | migracije i testovi | **traži Docker za `supabase start`** |
| Docker | lokalni Supabase stack | **nije instaliran na razvojnoj mašini** — v. niže |
| Xcode (macOS) | iOS flavori | `xcodeproj` gem dolazi sa CocoaPodsom |
| Android SDK + emulator | instalacija dva APK-a | system image API 36 x86_64 je verifikovan |

## Setup (jednom)

```sh
dart pub global activate melos
melos bootstrap          # flutter pub get kroz cijeli workspace
npm i && npx lefthook install   # pre-commit: dart format na staged Dart fajlove
```

## Svakodnevno

```sh
melos run analyze        # dart analyze u svim paketima
melos run format         # provjeri formatiranje (ne mijenja)
melos run format:fix     # formatiraj
melos run test           # flutter test u svakom paketu koji ima test/
```

`melos exec` ide **samo kroz pakete iz `workspace:` liste** u root `pubspec.yaml`. Paket koji nije
u listi tiho ispada iz svih ovih komandi.

## Generatori

```sh
dart run tool/gen_flavors.dart            # Gradle flavori, iOS xcconfig, tenants.g.dart
dart run tool/gen_flavors.dart --check    # padne ako je generisano zastarjelo (isto što radi CI)
tool/gen_ios_flavors.sh                   # Xcode konfiguracije + scheme po tenantu (macOS)
dart run tool/gen_placeholder_icons.dart  # privremene ikone; --force prepisuje postojeće
```

Redoslijed pri novom tenantu i sve zamke: `.claude/docs/tenant-factory.md`.

## Build

```sh
cd apps/client
flutter build apk   --debug --flavor barberstudiovitez --dart-define=SALON_ID=550e8400-e29b-41d4-a716-446655440000
flutter build ios   --debug --no-codesign --flavor barberstudiovitez --dart-define=SALON_ID=550e8400-e29b-41d4-a716-446655440000
```

Demo UUID-evi: Barber Studio Vitez `...440000`, Beauty Studio Travnik `...440001`.

**Bez `--dart-define=SALON_ID` app se builda ali ne nalazi svoj salon** — ekran kaže "Nedostaje
SALON_ID konfiguracija", tema padne na svijetlu, i tenant regresija se ne vidi. Isto važi za
testove teme.

`melos run build:client` postoji za AAB, ali očekuje `$TENANT`, `$SALON_ID` i `$API_URL` u okolini.
`melos run build:all` je namjerno još placeholder (`docs/04 §8.1`).

## Supabase

```sh
supabase start                 # traži Docker
supabase db reset              # primijeni sve migracije + seed.sql iz nule
supabase test db               # pgTAP, unutar rollback transakcije
supabase migration new <opis>  # novi migracioni fajl
```

REST test izolacije (traži da stack radi):

```sh
eval "$(supabase status -o env)"     # NIKAD ne commituj ovaj izlaz
export SUPABASE_URL="$API_URL" SUPABASE_ANON_KEY="$ANON_KEY" SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY"
deno run --allow-env --allow-net supabase/tests/rest_isolation.ts
```

Skripta odbija remote host, pravi dva stvarna Auth korisnika, uzima dva JWT-a i briše samo svoje
fixture.

### Docker ne postoji na razvojnoj mašini

`supabase start` lokalno ne radi. Zato:

- **Promjene u `supabase/` se dokazuju kroz CI workflow `Supabase tests`**, koji na svaki PR nad
  `supabase/migrations|seed.sql|tests|config.toml` pokrene cijeli stack, `supabase test db` i REST
  test, pa ugasi stack.
- **Napisana politika nije dokazana politika.** Dok taj job nije zelen, u sažetku piše "napisano,
  čeka CI", ne "radi".
- Ako instaliraš Docker Desktop, dopuni ovaj odjeljak i `tasks/README.md` — to je stanje koje se
  mijenja, ne trajna činjenica.

## Web prototip

```sh
npm i && npm run dev     # Vite; otvori / za pregled svih ekrana
npm run build
```

Rute prate `docs/01 §12`; login ekran ima demo prekidače kroz query parametre
(`?screen=email`, `?screen=otp`, `?platform=android`).

## CI

| Workflow | Okida se na | Dokazuje |
|---|---|---|
| `Flutter` (`.github/workflows/flutter-build.yml`) | `apps/`, `packages/`, `tenants/`, `tool/`, `pubspec.yaml`, `analysis_options.yaml` | generisano je ažurno · format · analiza · testovi · tema po tenantu · APK po flavoru sa provjerom `applicationId` u artefaktu · iOS build sa provjerom `CFBundleIdentifier`, `CFBundleDisplayName` i ikone u gotovom bundleu |
| `Supabase tests` (`.github/workflows/supabase-tests.yml`) | `supabase/migrations`, `seed.sql`, `tests/`, `config.toml` | migracije se primjenjuju iz nule · pgTAP · REST izolacija sa dva JWT-a |

Oba imaju `concurrency` sa `cancel-in-progress`, pa novi push otkazuje stari run iste grane.

Pregled i logovi: `gh run list --limit 5`, `gh run view <id> --log-failed`.

## Verifikacija promjene

Šta se u ovom repou računa kao dokaz — po tipu promjene, sa komandama i zamkama — stoji u skillu
`/verify` (`.claude/skills/verify/SKILL.md`). Kratka verzija: artefakt, a ne konfiguracija; oba
tenanta, a ne jedan; i eksplicitno reci šta **nije** provjereno.

## MCP serveri

`.mcp.json` u rootu definiše tri servera. Nijedan nije obavezan za rad — repo funkcioniše i bez
njih — ali svaki rješava po jedan stvaran problem ovog projekta:

| Server | Za šta | Traži |
|---|---|---|
| `supabase` | čitanje stvarne šeme i logova umjesto nagađanja iz migracija | `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF` |
| `context7` | aktuelna dokumentacija paketa (Flutter, Riverpod, `supabase_flutter`, Gradle) umjesto zastarjelog znanja | `CONTEXT7_API_KEY` |
| `playwright` | klikanje kroz web prototip u `src/` | — |

**Ključevi se ne pišu u `.mcp.json`** — u fajlu su `${...}` placeholderi koji se čitaju iz okoline.
Izvezi ih u shellu (ili u `.env` koji je već u `.gitignore`) prije pokretanja sesije.

Supabase server je namjerno `--read-only`: alat koji može pisati po bazi je alat koji će jednom
pisati po pogrešnoj bazi. Migracije idu kroz `supabase migration new`, ne kroz MCP.
