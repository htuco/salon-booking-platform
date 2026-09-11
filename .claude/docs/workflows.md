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
melos run codegen        # OBAVEZNO na svjezem klonu — v. ispod
npm i && npx lefthook install   # pre-commit: dart format na staged Dart fajlove
```

## Svakodnevno

```sh
melos run codegen        # freezed/json_serializable (*.freezed.dart, *.g.dart)
melos run analyze        # dart analyze u svim paketima
melos run format         # provjeri formatiranje (ne mijenja)
melos run format:fix     # formatiraj
melos run test           # flutter test u svakom paketu koji ima test/
```

`melos exec` ide **samo kroz pakete iz `workspace:` liste** u root `pubspec.yaml`. Paket koji nije
u listi tiho ispada iz svih ovih komandi.

**`tool/` nije paket, pa `melos run format` ne vidi njegove fajlove — a CI ih vidi.** Provjera u
CI-ju je `dart format --set-exit-if-changed $(git ls-files '*.dart')`, što obuhvata **svaki**
verzionisani Dart fajl, uključujući generatore. Zelen `melos run format:fix` lokalno zato ne znači
zelen CI. Kad diraš `tool/`, pokreni i:

```sh
dart format tool/
```

### Codegen: mora prije `analyze` i `test`

**Generisani kod nije u gitu.** `*.freezed.dart` i `*.g.dart` u `packages/` nastaju iz anotacija
(`@freezed`, `@JsonKey`) i `.gitignore` ih hvata — zato svjež klon pada na `analyze` sa
`Target of URI doesn't exist: 'salon.freezed.dart'` dok se `melos run codegen` ne pokrene jednom.

**Treba ga svaki korak koji kompajlira, ne samo analiza.** `flutter build` pada na isto, sa
`part 'x.freezed.dart': No such file or directory`. Zato ga zove svaki od četiri joba u
`flutter-build.yml`, a `tool/build_tenant.sh` ga pokrene sam prije builda — lokalni build i CI tako
ne mogu odlutati. (Ovo je greška koju je uhvatio tek CI: prvi pokušaj je dodao codegen samo u
`analyze` job, pa su oba iOS i oba Android builda pala.)

```sh
melos run codegen        # jednom, nakon klona i nakon svake izmjene modela
melos run codegen:watch  # regeneriše na svaku izmjenu — za rad na modelima
```

Skripta gađa samo pakete koji imaju `build_runner` (`--depends-on=build_runner`), danas
`core_domain`. Dodaš li codegen u drugi paket, dovoljno je dodati mu `build_runner` u
`dev_dependencies` — skripta ga pokupi sama.

Dvije zamke:

- **`--delete-conflicting-outputs` više ne postoji** u build_runner 2.9+. Komanda ga prihvati uz
  upozorenje i ignoriše; ne dodaji ga u nove skripte.
- **`tenants.g.dart` nije ovaj codegen.** On je izlaz iz `tool/gen_flavors.dart` nad `tenant.yaml`,
  jeste u gitu, i provjerava ga `--check`. `.gitignore` ga eksplicitno izuzima iz `*.g.dart`
  pravila. Razlika i obrazloženje: `.claude/docs/conventions.md` § Generisani fajlovi.

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
flutter build web   --dart-define=SALON_ID=550e8400-e29b-41d4-a716-446655440000
```

Demo UUID-evi: Barber Studio Vitez `...440000`, Beauty Studio Travnik `...440001`.

**Bez `--dart-define=SALON_ID` app pada na startu**, u `AppEnv.fromDefines()`, sa porukom koja
imenuje varijablu. To je namjerno: ranije se pogrešna konfiguracija vidjela tek kao tekst na
ekranu, na uređaju testera i danima kasnije. `SUPABASE_URL` i `SUPABASE_ANON_KEY` **nisu**
obavezni — bez njih se Supabase klijent ne diže i app radi na fallback podacima, što je ono
što `flutter run` bez backenda i web preview i trebaju.

Testovi teme više ne traže `--dart-define`: env ulazi kroz `appEnvProvider` override, pa
`tenant_theme_test` sam bira tenanta i pokriva oba. Jedini test koji ga i dalje traži je
`app_env_test.dart`, koji baš provjerava čitanje pravih define-ova.

### Ekran na ekranu, bez backenda

`main.dart` bez `SUPABASE_URL`-a diže app, ali provideri nemaju šta vratiti — ekran ostane na
kosturu. Za vizuelnu provjeru postoji drugi entry point koji iste providere puni podacima
prepisanim iz `supabase/seed.sql`:

```sh
cd apps/client
flutter run -d chrome -t lib/demo_main.dart --dart-define=SALON_ID=550e8400-e29b-41d4-a716-446655440000
```

Za screenshot dokaz se gradi statički build po tenantu i poslužuje lokalno:

```sh
flutter build web -t lib/demo_main.dart --dart-define=SALON_ID=<uuid> --output=build/demo-<flavor>
```

**Nije production put.** Store build ide isključivo kroz `lib/main.dart` i `tool/build_tenant.sh`;
`demo_main.dart` postoji da se ekran može pogledati na mašini bez Supabase pristupa. Podaci u
njemu vrijede tačno onoliko koliko odgovaraju seedu.

### Web: provjera da deep link stvarno radi

Ruta koja radi u widget testu ne znači da radi u browseru. Dva su načina da tiho ne radi:
`initialLocation` u `GoRouter`-u i izostanak `usePathUrlStrategy()` — u oba slučaja URL u
adresnoj traci ostane tačan, a otvori se početna. Provjerava se nad **gotovim** artefaktom:

```sh
cd apps/client && flutter build web --dart-define=SALON_ID=<uuid>
# posluži build/web uz SPA fallback (sve nepoznato -> index.html), pa u browseru otvori
# /book/slot direktno i potvrdi da se vidi taj ekran, ne početna
```

### `tool/build_tenant.sh` — jedina ulazna tačka u build

```sh
tool/build_tenant.sh <flavor> <apk|aab|ios> [debug|release]
BUILD_NUMBER=57 tool/build_tenant.sh barberstudiovitez aab release
```

Čita `salonId`, `versionName` i `versionCode` iz `tenants/<flavor>/tenant.yaml`, slaže
`--dart-define`-ove i ispisuje putanju artefakta. **CI poziva ovu skriptu**, ne svoju kopiju
`flutter build` komande — inače lokalni i CI build tiho odlutaju.

Okolina (sve opciono): `BUILD_NUMBER` nadjačava `versionCode`/`buildNumber` iz `tenant.yaml`
(koristi ga CI); `API_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` idu kao `--dart-define` ako su
postavljeni.

> Release se trenutno potpisuje **debug ključem** iz Flutterovog šablona — AAB iz ovog lanca nije za
> store dok se ne postavi keystore (Sprint 3, v. `tasks/04-ci-pipeline.md`).

`melos run build:client` je stariji ulaz i očekuje `$TENANT`/`$SALON_ID`/`$API_URL` u okolini;
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
  `supabase/migrations|seed.sql|tests|config.toml` (i nad `packages/core_api/`) pokrene cijeli
  stack, `supabase test db` i oba REST testa, pa ugasi stack.
- **Isto vrijedi za `core_api` repozitorije.** Da li upit stvarno prolazi kao `anon` i da li kolone
  koje traži postoje ne može se dokazati unit testom — mapiranje se testira lokalno, transport samo
  na CI-ju (`supabase/tests/rest_public_catalog.ts`). Zato je `packages/core_api/**` u okidačima tog
  workflowa: lista kolona u tom testu je kopija one iz repozitorija.
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
| `Flutter` (`.github/workflows/flutter-build.yml`) | `apps/`, `packages/`, `tenants/`, `tool/`, `pubspec.yaml`, `analysis_options.yaml` | generisano je ažurno · **codegen** · format · analiza · testovi · tema po tenantu · APK po flavoru sa provjerom `applicationId` u artefaktu · iOS build sa provjerom `CFBundleIdentifier`, `CFBundleDisplayName` i ikone u gotovom bundleu |
| `Flutter` → job `release-artifacts` | **ručni trigger** (`workflow_dispatch`) | AAB za oba tenanta kroz `build_tenant.sh`, `versionCode` iz `github.run_number`, provjera `applicationId` i `versionCode` kroz `bundletool dump manifest`, artefakt se čuva 30 dana |
| `Supabase tests` (`.github/workflows/supabase-tests.yml`) | `supabase/migrations`, `seed.sql`, `tests/`, `config.toml`, **`packages/core_api/`** | migracije se primjenjuju iz nule · pgTAP · REST izolacija sa dva JWT-a · **javni katalog čitljiv bez prijave** (`rest_public_catalog.ts`) |

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
| `playwright` | klikanje kroz web artefakte i `prototype/ui/screens-flat.html` | — |

Serveri su **odobreni u `.claude/settings.json`** (`enabledMcpjsonServers`), pa ih Claude Code ne
traži da potvrđuješ svaki put.

**Ključevi se ne pišu u `.mcp.json`** — u fajlu su `${...}` placeholderi koji se čitaju iz okoline
procesa u kojem je Claude Code pokrenut. Izvezi ih u `~/.zshrc` (ili u shellu prije pokretanja):

```sh
export SUPABASE_ACCESS_TOKEN=…    # Supabase → Account → Access Tokens
export SUPABASE_PROJECT_REF=…     # ref projekta iz URL-a dashboarda
export CONTEXT7_API_KEY=…
```

Bez tih varijabli `context7` i `supabase` se ne podignu; `playwright` radi bez ičega. Stanje
servera u sesiji provjeriš sa `/mcp`, izvan sesije sa `claude mcp list`.

Supabase server je namjerno `--read-only`: alat koji može pisati po bazi je alat koji će jednom
pisati po pogrešnoj bazi. Migracije idu kroz `supabase migration new`, ne kroz MCP.

## Šta hook ubaci na početku sesije

`.claude/settings.json` ima `SessionStart` hook koji u kontekst ubaci `tasks/CURRENT.md`,
`git status --short --branch` i zadnja tri commita — oko 1.200 tokena, tako da nova sesija zna gdje
se stalo bez ijednog `Read` poziva.

Provjera bez pokretanja nove sesije:

```sh
cmd=$(jq -r '.hooks.SessionStart[0].hooks[0].command' .claude/settings.json)
echo '{}' | CLAUDE_PROJECT_DIR="$PWD" bash -c "$cmd" | jq -r '.hookSpecificOutput.additionalContext'
```

Hookove pregledaš i gasiš kroz `/hooks`. Izmjena `.claude/settings.json` u sesiji koja je počela
prije nego je fajl postojao ne mora biti pokupljena — otvori `/hooks` jednom ili restartuj sesiju.
