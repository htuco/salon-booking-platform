# Workflows — komande i dokazi

Sve komande se pokreću iz roota repoa osim gdje ne piše drugačije.

## Preduslovi

| Alat | Zašto | Napomena |
|---|---|---|
| Flutter (stable) + Dart SDK ≥ 3.13 | sve u `apps/` i `packages/` | CI koristi `subosito/flutter-action@v2`, kanal `stable` |
| JDK 17 | Android build | CI: `temurin` 17 |
| Node + npm | web prototip i lefthook | `npm i` |
| Supabase CLI | migracije i testovi | `brew install supabase/tap/supabase` |
| Deno | šest REST testova (izolacija, katalog, upsert, brisanje naloga, admin prijava) | `brew install deno`; na Windowsu `irm https://deno.land/install.ps1 \| iex` |
| Docker Desktop | lokalni Supabase stack | instaliran i radi — v. `./tool/test_supabase.sh` |
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

### Git identitet je zaključan

`pre-commit` zove `tool/check_git_identity.sh` i **odbija commit** ako `git config user.email` nije
na dozvoljenoj listi (`htuco04@gmail.com`, `dajiceniz@gmail.com`, bilo koja
`*@users.noreply.github.com`). Novi saradnik se dodaje u `DOZVOLJENI` u toj skripti, svjesno.

Postoji jer je commit `87f0aff` ušao sa firmskom adresom. Takav commit se poslije **ne može
obrisati, samo prepisati** — a to mijenja svaki SHA iza njega. Ako repo ikad ode javno, adresa
završi u arhivama (GH Archive, Software Heritage) koje vraćanje na private ne dotiče.

## Generatori

Task 33 dodaje `deno run --allow-env --allow-net supabase/tests/rest_employee_crud.ts` u
`tool/test_supabase.sh` i `Supabase tests` CI. Isti lokalni env kao ostali REST testovi;
skripta odbija nelokalni backend i čisti samo vlastite fixture redove.


```sh
dart run tool/gen_flavors.dart            # Gradle flavori, iOS xcconfig, tenants.g.dart
dart run tool/gen_flavors.dart --check    # padne ako je generisano zastarjelo (isto što radi CI)
tool/gen_ios_flavors.sh                   # Xcode konfiguracije + scheme po tenantu (macOS)
dart run tool/gen_placeholder_icons.dart  # privremene ikone; --force prepisuje postojeće
```

Redoslijed pri novom tenantu i sve zamke: `.claude/docs/tenant-factory.md`.

## Pokretanje jednog tenanta

```sh
tool/run_tenant.sh vitez           # barberstudiovitez u simulatoru, lokalni Supabase ako radi
tool/run_tenant.sh travnik         # beautystudiotravnik
tool/run_tenant.sh vitez demo      # lib/demo_main.dart — ekran bez backenda
tool/run_tenant.sh vitez -d chrome # sve iza flavora ide ravno flutteru
```

Argument je **nadimak ili puni flavor**, i razrješava se iz `tenants/`, ne iz tabele u skripti —
novi tenant radi bez izmjene skripte. `salonId` se čita iz `tenant.yaml`; demo UUID-evi se
razlikuju u zadnjoj cifri, pa prepisan iz glave daje pogrešan tenant koji izgleda ispravno dok se
ne pogleda ime salona u zaglavlju.

Ako lokalni Supabase radi, skripta proslijedi njegov URL i **anon** ključ. `SERVICE_ROLE_KEY` i
`SECRET_KEY` iz `supabase status -o env` se namjerno ne dodiruju — service role zaobilazi RLS i ne
smije postojati u klijentskom buildu. Bez backenda se app svejedno digne, ali ekrani ostanu na
kosturu; tada služi `demo`.

Na macOS-u skripta digne Simulator ako nijedan ne radi. Uređaj se bira sa `-d`, kao i inače.

### Hostovani Vitez demo

Javne runtime vrijednosti i lokalne putanje stoje u ignorisanom `.env.live`; predložak je
`.env.example`. DB lozinka služi samo CLI deployu i skripta je nikad ne prosljeđuje Flutteru.

```sh
cp .env.example .env.live
tool/run_live_demo.sh client -d <device-id>
tool/run_live_demo.sh admin -d <device-id>
```

`tool/run_live_demo.sh` namjerno podržava samo Vitez klijent i generički admin. Za push postavi
`FIREBASE_CLIENT_DEFINES_FILE` odnosno `FIREBASE_ADMIN_DEFINES_FILE` na privatni define JSON.
Prije live testa hostovani projekat mora imati migracije/seed, a za demo email signup **Confirm
email** mora biti isključen. Ne dodavati service-role ključ ni Supabase access token u `.env.live`.

Availability se ne osvježava pretplatom klijenta na sve termine — to bi zaobišlo svrhu RLS-a.
`availability_signals` nosi samo `salon_id` i nasumični `revision_id`; trigger ga promijeni nakon
svake availability-relevantne izmjene, a app zatim ponovo poziva `get_available_slots`.

## Pokretanje admin aplikacije

**Nema flavora ni `SALON_ID`** — admin je jedna generička app za sve salone, i salon dobija iz
članstva u `public.users` nakon prijave. Zato ni `run_tenant.sh` ne važi za njega:

```sh
cd apps/admin
eval "$(supabase status -o env)"     # NIKAD ne commituj ovaj izlaz
flutter run -d chrome \
  --dart-define=SUPABASE_URL="$API_URL" \
  --dart-define=SUPABASE_ANON_KEY="$ANON_KEY"
```

Prijava lokalno, iz `seed.sql` (task 23) — **samo lokalni demo, nikad produkcija**:

| email | salon |
|---|---|
| `admin@barberstudiovitez.test` | Barber Studio Vitez |
| `admin@beautystudiotravnik.test` | Beauty Studio Travnik |

Lozinka je `admin123456` za oba. Prijava drugim nalogom je i **najbrži dokaz izolacije**: isti
build, drugi vlasnik, nijedan tuđi termin.

Bez Supabase define-ova app se svejedno digne, ali prijava ne radi — `AdminEnv.hasSupabase` je
tada `false` i Supabase klijent se ne inicijalizuje. To je namjerno: pad prije `runApp` bi dao
bijelu stranicu umjesto ekrana koji kaže šta fali.

**Statički build za dokaz u browseru** (kad `flutter run` smeta, npr. zbog hot reloada tokom
snimanja):

```sh
flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
npx http-server apps/admin/build/web -p 5599 -a 127.0.0.1 -c-1
```

`-c-1` gasi keš. Bez njega server servira **stari bundle** nakon rebuilda, pa ispravka izgleda kao
da nije radila — provjeri `md5sum` posluženog `main.dart.js` naspram onog iz `build/web` prije nego
posumnjaš u kod. Obični `http-server` uz to nema SPA fallback, pa direktan `/login` vraća 404;
otvori root i pusti router da preusmjeri.

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

**Admin ima svoj, od taska 29** (`apps/admin/lib/demo_main.dart`). Njemu demo ulaz treba iz jačeg
razloga nego klijentu: admin ekran se **ne vidi bez prijave**, jer router pušta dalje tek kad
`currentStaffProvider` vrati `salon_admin`. Bez backenda se inače vidi samo login.

```sh
cd apps/admin
flutter run -d chrome -t lib/demo_main.dart        # nema --dart-define, admin nema SALON_ID
```

Nema tenant parametra jer admin nema flavor — jedna aplikacija za sve salone (ADR-0003).
Ljuska se mijenja na 840 px, pa se obje provjeravaju **jednim** buildom, mijenjanjem širine
prozora: 1440×900 daje sidebar, 402×874 donju navigaciju.

Za dokaz da filter iz adrese preživi refresh (`/appointments?status=pending`) treba SPA fallback —
v. sljedeći odjeljak; `python -m http.server` sam po sebi na toj putanji vraća 404.

### Web: provjera da deep link stvarno radi

Ruta koja radi u widget testu ne znači da radi u browseru. Dva su načina da tiho ne radi:
`initialLocation` u `GoRouter`-u i izostanak `usePathUrlStrategy()` — u oba slučaja URL u
adresnoj traci ostane tačan, a otvori se početna. Provjerava se nad **gotovim** artefaktom:

```sh
cd apps/client && flutter build web --dart-define=SALON_ID=<uuid>
# posluži build/web uz SPA fallback (sve nepoznato -> index.html), pa u browseru otvori
# /book/slot direktno i potvrdi da se vidi taj ekran, ne početna
python tool/serve_web_demo.py apps/client/build/web 4320
```

`tool/serve_web_demo.py` postoji zbog dvije stvari koje `python -m http.server` ne radi:
**SPA fallback** (bez njega `/appointments?status=pending` vraća 404, a upravo se tu provjerava
da filter preživi refresh) i **vezivanje na `0.0.0.0`**, pa se isti build otvori i sa telefona na
istoj mreži. Skripta ispiše obje adrese. Na Windowsu prvi pokušaj sa telefona zna pasti na
Firewall — port se mora dozvoliti.

Admin protiv **hostovanog** projekta se gradi sa vrijednostima iz ignorisanog `.env.live`:

```sh
set -a && source .env.live && set +a
cd apps/admin && flutter build web -t lib/main.dart --output=build/live-admin   --dart-define="SUPABASE_URL=$SUPABASE_URL" --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
python ../../tool/serve_web_demo.py build/live-admin 4320
```

Prijava je seed nalog: `admin@barberstudiovitez.test` / `admin123456` (v. `supabase/seed.sql`).
**Travnik admin na hostovanom projektu ne postoji** — `POST /auth/v1/token` vraća 400, pa se
„druga prijava, drugi salon" tamo još ne može odigrati.

### Screenshot bez playwrighta

Kad MCP playwright ne radi, snimak pravi instalirani Chrome:

```sh
chrome --headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=15000   --window-size=1440,900 --screenshot=out.png http://localhost:4320/
```

**Zamka:** Chrome ima minimalnu širinu prozora oko 500 px, pa `--window-size=402,874` daje
snimak u kojem sadržaj *izgleda* kao da izlazi van ekrana, a ne izlazi. Telefonska širina se
dobija skaliranjem: `--force-device-scale-factor=1.25 --window-size=503,1093` → CSS 402×874.

### `tool/build_tenant.sh` — jedina ulazna tačka u build

```sh
tool/build_tenant.sh <flavor> <apk|aab|ios> [debug|release]
BUILD_NUMBER=57 tool/build_tenant.sh barberstudiovitez aab release
```

Čita `salonId`, `versionName` i `versionCode` iz `tenants/<flavor>/tenant.yaml`, slaže
`--dart-define`-ove i ispisuje putanju artefakta. **CI poziva ovu skriptu**, ne svoju kopiju
`flutter build` komande — inače lokalni i CI build tiho odlutaju.

Okolina (sve opciono): `BUILD_NUMBER` nadjačava `versionCode`/`buildNumber` iz `tenant.yaml`
(koristi ga CI); `API_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID` i
`GOOGLE_IOS_CLIENT_ID` idu kao `--dart-define` ako su postavljeni.

**Google client ID se traži prvo po flavoru.** Skripta gleda `GOOGLE_WEB_CLIENT_ID_<FLAVOR>` (flavor
velikim slovima), pa tek onda zajednički `GOOGLE_WEB_CLIENT_ID`:

```sh
GOOGLE_WEB_CLIENT_ID_BARBERSTUDIOVITEZ="...apps.googleusercontent.com" \
GOOGLE_IOS_CLIENT_ID_BARBERSTUDIOVITEZ="...apps.googleusercontent.com" \
tool/build_tenant.sh barberstudiovitez apk debug
```

Razlog je `docs/06 §7.1`: jedan zajednički ID znači da korisnik u Google dijalogu vidi tuđe ime
salona. Skripta u zaglavlju builda ispisuje **da li** je ID stigao i iz koje varijable, ali nikad
samu vrijednost — build log je artefakt koji se čuva. Kad ID nedostaje, build prolazi i ispisuje
upozorenje: app bez Googlea i dalje ima Apple i email + lozinku, pa je login ekran bez jednog dugmeta
bolji od builda koji pada.

U CI-ju vrijednosti stoje u GitHub `vars` (client ID nije tajna, ali se mijenja po tenantu);
postavljanje: `tasks/sprint-2/12-konzole-checklist.md` §4.

> Release se trenutno potpisuje **debug ključem** iz Flutterovog šablona — AAB iz ovog lanca nije za
> store dok se ne postavi keystore (Sprint 3, v. `tasks/sprint-0/04-ci-pipeline.md`).

`melos run build:client` je stariji ulaz i očekuje `$TENANT`/`$SALON_ID`/`$API_URL` u okolini;
`melos run build:all` je namjerno još placeholder (`docs/04 §8.1`).

## Supabase

```sh
supabase start                 # traži Docker (Docker Desktop je instaliran)
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

### Email + lozinka lokalno

Demo faza ima isključen confirmation, pa lokalni signup odmah vraća sesiju i ne šalje email.
Apple i Google i dalje traže naloge i pravi uređaj.

```sh
eval "$(supabase status -o env)"
curl -s -X POST "$API_URL/auth/v1/signup" -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"demo1234"}'
curl -s -X POST "$API_URL/auth/v1/token?grant_type=password" -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"demo1234"}'
```

Lozinka mora proći isto javno pravilo kao UI: najmanje osam znakova, bar jedno slovo i jedna cifra.
Confirmation, SMTP i recovery namjerno nisu dio demo faze; za produkcijski tok prati task 27.

### Cijela suite jednom komandom

```sh
./tool/test_supabase.sh              # start + db reset + pgTAP + sest REST testova
./tool/test_supabase.sh --no-reset   # baza je već svježa
supabase stop                        # kad završiš
```

Zadnji pun prolaz (2026-09-14, task 23): **177 pgTAP testova** i **173 REST asercije** — 24
izolacija sa dva stvarna JWT-a, 57 javni katalog bez tokena, 20 upsert klijenta i rezervacija, 25
izolacija između salona sa tri JWT-a, 33 brisanje naloga kroz Edge Function, 14 **admin prijava
kroz GoTrue**. Traje oko dvije minute.

**Brojke u ovom odjeljku zastarijevaju tiho.** Do taska 23 su pisale „97 pgTAP i 95 REST asercija,
četiri REST testa", a skripta je u međuvremenu propustila dva testa koja su postojala u repou
(`rest_delete_account.ts` iz taska 17 i `rest_admin_login.ts`). Dodavanje testa ne djeluje kao
promjena koja dira ovaj dokument — provjeri `ls supabase/tests/*.ts` naspram `tool/test_supabase.sh`
kad god dodaješ REST test.

**Zamka koja košta pola sata:** `supabase start` nad postojećim volumeom diže bazu **iz backupa** i
migracije se ne primjenjuju. Testovi tada padnu na `relation "public.users" does not exist` i
izgleda kao da je šema pokvarena, a nije — samo je stara. `supabase db reset` je jedini način da se
dokaže da migracije i seed prolaze od nule. Skripta ga zato zove po defaultu.

**Druga zamka, iz istog gnijezda:** `supabase db reset` **ne učitava `config.toml`**. Promjena
auth podešavanja — confirmation, password policy, email templatei ili redirect URL-ovi — traži
`supabase stop` pa `supabase start`. Zato reset baze sam ne dokazuje novo auth ponašanje.

- **Napisana politika nije dokazana politika.** Dok suite nije prošla, u sažetku piše "napisano,
  nije pokrenuto", ne "radi".
- **Isto vrijedi za `core_api` repozitorije.** Da li upit stvarno prolazi kao `anon` i da li kolone
  koje traži postoje ne dokazuje unit test — lista kolona u `rest_public_catalog.ts` je kopija one
  iz repozitorija, pa promjena u `core_api` traži ponovni prolaz.
- **Izlaz `supabase status -o env` sadrži service role ključ.** Nikad u commit ni u sažetak.

## Web prototip

```sh
npm i && npm run dev     # Vite; otvori / za pregled svih ekrana
npm run build
```

Rute prate `docs/01 §12`; login ekran ima demo prekidače kroz query parametre
(`?screen=email`, `?screen=otp`, `?platform=android`).

## CI

CI radi u **dvije brzine**, jer jobovi nisu jednako skupi:

| Događaj | Šta se pokrene | Naplativo |
|---|---|---|
| **PR** | `Supabase tests` + Flutter job `analyze` | **~7 min** |
| **push u `main`** | sve, uključujući APK po tenantu i oba iOS builda | ~86 min |
| ručni `workflow_dispatch` | + `release-artifacts` (AAB) | — |

Na PR-u prolazi ono što štiti tuđi rad: **tenant izolacija** (jedino mjesto gdje greška curi tuđe
podatke) i analiza sa testovima. Skupo je bilo macOS — dvije iOS jobe nose 66 od 86 minuta punog
runa zbog množioca 10× — pa to ide tek na `main`.

Na `main`-u se dodaje ono što se lokalno **ne može** dobiti: dokaz iz čistog checkouta. Lokalni
build koristi postojeći `build/` i generisane `*.g.dart` koji su u `.gitignore`, pa ne dokazuje da
codegen radi na praznom klonu — tačno bug iz commita `e628237`.

Svakodnevno, prije nego išta ode na GitHub: `melos run analyze`, `melos run test`,
`./tool/test_supabase.sh`.

### Dokaz iz čistog checkouta, bez CI-ja

```sh
./tool/verify_clean.sh              # klon u temp + pub get + codegen + gen --check + analyze + test
./tool/verify_clean.sh --with-apk   # plus APK za oba tenanta (~15 min)
```

Klonira granu u temp folder, pa tamo pokrene cijeli lanac. Klon nosi **samo commitovane fajlove**,
pa hvata ono što lokalno pokretanje ne može: zaboravljen commit, codegen koji nije ožičen, drift
generisanog registra. Zadnji pun prolaz: **165 testova, 5 paketa, nula grešaka.**

> **Mora `flutter pub get`, ne `dart pub get`.** `apps/client` ima `generate: true` uz `l10n.yaml`,
> pa tek flutter varijanta stvori `lib/src/l10n/generated/`. Taj folder je u `.gitignore`, dakle na
> čistom klonu ga nema — sa `dart pub get` analiza padne na deset `Undefined name 'AppLocalizations'`
> grešaka kojih u repou nema. Isto vrijedi za `melos bootstrap`: paralelni resolve-ovi na čistom
> klonu znaju pasti na `Bad state: Attempting to send request on closed client`.

> **Zašto nema `pre-push` hooka.** Mjereno: codegen + analyze je 54 s, Supabase suite još ~2 min.
> Hook te dužine se zaobiđe sa `--no-verify` prvog dana, pa bi dao lažan osjećaj pokrivenosti.
> Provjera koja traje minutama pripada CI-ju, gdje ne blokira nikoga.

| Workflow | Okida se na | Dokazuje |
|---|---|---|
| `Flutter` (`.github/workflows/flutter-build.yml`) | **PR** (samo `analyze`) i **push u `main`** (sve) nad `apps/`, `packages/`, `tenants/`, `tool/`, `pubspec.yaml`, `analysis_options.yaml` | generisano je ažurno · **codegen** · format · analiza · testovi · tema po tenantu · APK po flavoru sa provjerom `applicationId` u artefaktu · iOS build sa provjerom `CFBundleIdentifier`, `CFBundleDisplayName` i ikone u gotovom bundleu |
| `Flutter` → job `release-artifacts` | **ručni trigger** (`workflow_dispatch`) | AAB za oba tenanta kroz `build_tenant.sh`, `versionCode` iz `github.run_number`, provjera `applicationId` i `versionCode` kroz `bundletool dump manifest`, artefakt se čuva 30 dana |
| `Supabase tests` (`.github/workflows/supabase-tests.yml`) | **PR i push u `main`** nad `supabase/migrations`, `seed.sql`, `tests/`, `config.toml`, **`packages/core_api/`** | migracije se primjenjuju iz nule · pgTAP · REST izolacija sa dva JWT-a · **javni katalog čitljiv bez prijave** (`rest_public_catalog.ts`) · **prijava seed admina kroz GoTrue** (`rest_admin_login.ts`) |

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
## Push provjere i konfiguracija

`tool/test_supabase.sh` sada uključuje `rest_push_devices.ts` i worker testove. Edge runtime mora
biti aktivan (`supabase functions serve`) za postojeći test brisanja naloga; ugašen runtime daje
503. Bez reseta lokalna baza može imati stari seed: `rest_admin_login.ts` tada može pasti na
demo nalogu, iako testovi koji prave vlastite korisnike prolaze. Ne proglašavati cijelu suite
zelenom u tom slučaju.

```sh
deno test supabase/functions/send-push/handler_test.ts
deno check --config supabase/functions/send-push/deno.json supabase/functions/send-push/index.ts
```

`Supabase tests` job prati i `supabase/functions/send-push/**` i provjerava worker te novi REST
test. Firebase i APNs tajne nisu potrebne za te testove. `FCM_SERVICE_ACCOUNT_JSON`,
`PUSH_WORKER_SECRET` i Vault konfiguracija potrebni su tek za stvarno slanje. Build config,
CI secret imena i dokaz na uređaju: `tasks/sprint-2/25-push-konfiguracija.md`.
