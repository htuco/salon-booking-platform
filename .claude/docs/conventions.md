# Konvencije

Kako se piše kod u ovom repou. Pravilo iznad svih: **prati postojeći primjer prije apstraktnog
pravila.** Kad dodaješ nešto novo, prvo nađi najbliži postojeći komad i preslikaj njegov oblik.

## Uzori — kopiraj ove

Repo je još mlad, pa je lista kratka i namjerno pokazuje *dokazane* obrasce:

- **Generator koji piše u tuđi fajl** → `tool/gen_flavors.dart`. Piše samo između `BEGIN/END`
  markera, ima `--check` režim za CI, i validira ulaz prije nego išta dotakne.
- **Alat koji ne smije uništiti tuđi rad** → `tool/gen_placeholder_icons.dart`. Nikad ne prepisuje
  postojeći fajl bez `--force`, jer dizajnerska ikona ne smije nestati na sljedećem pokretanju.
- **Manipulacija strukturiranim fajlom** → `tool/gen_ios_flavors.rb`. `project.pbxproj` se mijenja
  kroz `xcodeproj` gem, nikad tekstualno; neispravan pbxproj ruši sve flavore odjednom, a greška se
  ne vidi dok se ne otvori Xcode.
- **Widget koji čita temu** → `apps/client/lib/main.dart`. Tijelo je **zaseban widget**, ne inline
  `Scaffold`: `Theme.of(context)` pozvan u `build` metodi koja postavlja `MaterialApp` vraća
  Flutterov default, pa bi tekst na tamnoj tenant temi bio nevidljiv.
- **CI provjera koja stvarno nešto dokazuje** → korak "Provjeri applicationId u APK-u" u
  `.github/workflows/flutter-build.yml`. Provjerava gotov artefakt (`aapt2 dump badging`), ne
  konfiguraciju iz koje je nastao.
- **Test koji hvata regresiju koju oko ne vidi** → `apps/client/test/tenant_theme_test.dart`,
  pokrenut sa `--dart-define=SALON_ID=...` za oba tenanta. Bez definea tema je svijetla i
  neusklađenost se ne vidi.
- **Model koji čita tuđi JSONB** → `packages/core_domain/lib/src/vertical/`. Nikad ne baca:
  ključ koji nedostaje i vrijednost pogrešnog tipa padaju na default, jer je app u storeu uvijek
  starija od baze. Uz to `packages/core_domain/test/vertical_test.dart` parsira **stvarni**
  `supabase/seed.sql` i pada ako se seed i model raziđu u ključevima.
- **Kod koji treba test, a zavisi od tuđeg builder lanca** → `verticalFromSalonRow` u
  `packages/core_api/`. Mapiranje je izdvojeno iz repozitorija da se testira bez lažiranja
  PostgREST-a: pravila su u mapiranju, `.from().select().eq()` je tuđi kod.
- **Repozitorij** → `packages/core_api/lib/src/catalog/salon_repository.dart`. Kolone nabrojane
  eksplicitno (nikad `select('*')`), poziv obavijen u `guard(...)` da iz njega izađe samo
  `ApiError`, mapiranje u izdvojenoj `@visibleForTesting` funkciji. Ostala četiri su ga preslikala.
- **Repozitorij koji piše u bazu** → `packages/core_api/lib/src/booking/booking_repository.dart`.
  Sve tri metode idu na `rpc`, nijedna na `from(...)`: upis mora proći kroz validiranu funkciju
  koja re-validira slot u istoj transakciji, a slobodni termini se ne mogu ni pročitati bez
  gledanja tuđih termina. Isti obrazac mapiranja kao kod čitajućih repozitorija — `guard(...)` i
  `@visibleForTesting` funkcija koju test gađa umjesto `.rpc(...)` lanca.
- **Stanje koje preživljava više ekrana** → `apps/client/lib/src/features/booking/`. Jedan
  `Notifier` za sva četiri koraka, `autoDispose` da izlazak iz flowa čisti izbor. Nosi samo
  identifikatore i vrijeme — **nikad listu slobodnih termina**: keširana lista znači da korisnik
  nakon povratka nazad bira iz zastarjelog spiska i dobije `409` na potvrdi. Pravila (šta se briše
  kad se izbor promijeni, kad je korak popunjen) su u `BookingFlowState`, pa se testiraju bez
  `pumpWidget`-a — isti razlog kao kod `SalonSchedule`.
- **Greška koju ekran može razlikovati** → `packages/core_api/lib/src/errors/`. `ApiError` je
  `sealed`, pa `switch` nad njim Dart provjerava na iscrpnost — novi tip obori build tamo gdje nije
  obrađen umjesto da padne u `default` i pojavi se kao pogrešna poruka u produkciji.
- **`ApiError.message` ne ide na ekran direktno.** To je poruka za log i zna nositi SQL kod ili
  ime tabele. Na ekran ide `error.displayMessage` (`error_mapper.dart`), koji propušta samo
  tekst pisan za čovjeka (mreža, konflikt, `raise … using errcode = 'PT…'`) i za ostalo vraća
  `null`. Ekran tada stavlja svoju opštu rečenicu. U adminu je to `porukaGreske(e, opsta:)`
  (`apps/admin/lib/src/core/poruka_greske.dart`), u klijentu tekst iz `.arb`-a po tipu greške.
- **Vrijednosni tip koji postoji da spriječi jednu grešku** → `LocalTime`/`LocalDate` u
  `packages/core_domain/lib/src/catalog/`. Baza drži zidno vrijeme salona bez zone; `DateTime` bi
  ga vezao za zonu uređaja i tiho pomjerio radno vrijeme. Tip nema konverziju u trenutak — namjerno.
- **Model sa vrijednošću koju baza može proširiti** → `AppointmentStatus`. Enum sa `unknown`
  fallbackom: `switch` ostaje iscrpan, a status dodan migracijom nakon zadnjeg store submissiona ne
  ruši listu termina. Isti razlog zbog kojeg je `Vertical.key` namjerno `String`.
- **Konfiguracija koja mora pasti glasno** → `apps/client/lib/src/core/env/app_env.dart`.
  Obavezan define baca sa imenom varijable u poruci; opcioni se degradira na fallback. Test
  (`app_env_test.dart`) se pokreće **sa** `--dart-define`, jer widget testovi ubacuju env kroz
  override i nikad ne pozovu pravi `fromDefines()` — zbog toga je prazna bijela stranica na
  webu prošla kroz cijelu zelenu suite.
- **Vrijednost koja se izvodi umjesto da se pogodi** → `onColorFor` u
  `packages/core_ui/lib/src/theme/contrast.dart`. `onPrimary` se bira poređenjem stvarnih WCAG
  odnosa, a ne pragom luminancije: zlatna `#C6A667` ima luminanciju 0.42, pa bi naivni prag stavio
  bijeli tekst i dao 2.6:1. Vlasnik salona bira boju sam i smije izabrati žutu — hardkodiran
  `onPrimary` je nečitljiva aplikacija kod jednog klijenta, koju niko iz tima nikad ne otvori.
- **Komponenta koja ne smije znati previše** → `packages/core_ui/lib/src/components/`. Prima gotove
  stringove ("45 min"), ne modele iz `core_domain` — zato isti paket služi i admin aplikaciji, a
  formatiranje ostaje u ekranu koji jedini zna jezik i vertikalu. Nijedna ne piše literal boju ni
  literal razmak.
- **Test koji mjeri proizvod, ne formulu** → `packages/core_ui/test/components_test.dart`. Renderuje
  isti ekran u **obje** teme i mjeri svaki `Text` prema njegovoj **stvarnoj** pozadini (badge i
  izabrani chip imaju svoju), sa stvarnim paletama oba demo tenanta. Tako je nađena roze cijena sa
  4.12:1: brand tekst je bio mjeren na `surface`, a kartica stoji na `surfaceContainer`.
- **Ruta koja mora imati URL** → `apps/client/lib/src/core/router/app_router.dart`. Rute su
  enum, ne slobodni stringovi; router test poredi skup putanja sa **prepisanom** listom iz
  `docs/01 §12`, a ne sa samim enumom (inače test potvrđuje da je enum jednak sam sebi).
- **Ekran** → `apps/client/lib/src/features/home/`. Prvi pravi ekran i šablon za ostale; tri
  pravila stoje u doc komentaru `home_screen.dart`. Podaci dolaze iz providera, nikad direktnim
  pozivom repozitorija. Tekst koji se razlikuje po vertikali ide kroz `vertical.terms`, ostatak
  kroz `.arb` — literal "Zakaži termin" u ekranu znači da stomatološka app zove pregled terminom,
  a to se ne vidi dok se ne otvori treći tenant. Tri stanja se pišu **prije** sretnog slučaja
  (skeleton, greška sa retryjem, sakrivena prazna sekcija); ekran napisan obrnutim redom dobije
  spinner preko bijele površine i to ostane.
- **Greška učitavanja, prazno stanje i osvježavanje** (FE-501). Greška je `LoadError`
  (`apps/client/lib/src/core/load_error.dart`) ili `AdminLoadError` u adminu: rečenica po tipu
  greške i „Pokušaj ponovo", koje radi `ref.invalidate` izvora. **Greška se nikad ne crta kao
  prazno stanje**: „nema slika" kad je upit pao je netačna tvrdnja. Prazno stanje ima svoju
  rečenicu po ekranu i relevantan CTA. Prazno zbog filtera nudi poništavanje filtera.
  Povlačenje za osvježavanje je `AppRefresh` (`core_ui`) ili `AdminRefresh`, nikad
  `RefreshIndicator(`. Admin guard `no_material_indicators_test.dart` to hvata.
- **Logika koja bi se sakrila u `build`** → `apps/client/lib/src/features/home/salon_schedule.dart`.
  Živi status "Otvoreno do 20:00" se računa iz `WorkingHour`-a u zasebnoj klasi koja prima `now`
  kao parametar, pa test može stajati u srijedu u 08:00 bez `pumpWidget`-a i bez čekanja srijede.
  Isti izračun u `build` metodi bi tražio podizanje cijele app-e za provjeru jednog `if`-a.

## Jezik

Bosanski: dokumentacija, komentari, commit poruke, PR opisi, imena taskova. Tehnički termini ostaju
engleski (flavor, migration, RLS, provider, slot). Identifikatori u kodu su engleski
(`salonId`, `TenantConfig`) — miješani identifikatori su gore od jednog jezika.

Dijakritika: dokumentacija i UI copy sa punom dijakritikom. Shell skripte i `.rb`/`.sh` komentari u
`tool/` su bez nje jer prolaze kroz alate sa nesigurnim encodingom — postojeći fajlovi to već rade,
prati ih.

## Komentari

Komentar objašnjava **zašto**, nikad šta. Postojeći repo drži visok standard tu i to je namjerno:
svaki netrivijalan komentar u `tool/`, CI-ju i migracijama nosi zamku koja je nekog već koštala sata.
Kad naiđeš na takvu zamku, zapiši je tu gdje se dešava — ne u commit poruku, koju niko neće naći.

## Dart / Flutter

- **Feature-first**: `lib/src/features/<feature>/`. Zajedničko ide u `packages/core_*`, ne u
  `lib/src/shared/`. Smjer zavisnosti: `core_ui`/`core_api` → `core_domain`, nikad obrnuto.
- **Lint** iz root `analysis_options.yaml`: `prefer_single_quotes`, `avoid_print`,
  `prefer_final_locals`, `unnecessary_lambdas` povrh `flutter_lints`. `avoid_print` znači da alat
  koji stvarno treba pisati na stdout (`tool/*.dart`) to radi sa `// ignore:` i obrazloženjem, a ne
  gašenjem pravila globalno.
- **Formatiranje**: `dart format` je izvor istine. Pre-commit hook (lefthook) ga pokreće na staged
  Dart fajlove; CI pada na `dart format --set-exit-if-changed`.
- **Paketi** (izbor je već donesen, `docs/07 §3`): `flutter_riverpod` + `riverpod_generator` za
  state i DI, `go_router` za rute, `supabase_flutter` za backend, `freezed` + `json_serializable`
  za modele, `mocktail` za testove, `intl` + `.arb` za jezik. Ne uvodi alternativu bez ADR-a.
- **Nema `get_it`** — Riverpod je i state i DI kontejner.
- **Nema `Navigator` imperativno** — web build klijent app-e mora imati prave URL-ove po ekranu.
- **`.order()` u `postgrest`-u sortira SILAZNO ako mu ne kažeš drugačije.** `ascending` je `false`
  po defaultu (`postgrest 2.9.1`, `postgrest_transform_builder.dart:104`), suprotno i od PostgREST-a
  i od SQL-a. Tri repozitorija u `core_api` su zbog toga mjesecima vraćala katalog obrnuto — radno
  vrijeme kao nedjelja→ponedjeljak — a nijedan test to nije uhvatio, jer se ovdje **namjerno ne
  testira builder lanac** (v. `catalog_repository_test.dart`), pa redoslijed ne dokazuje suita nego
  pokretanje. Piši smjer uvijek eksplicitno:

  ```dart
  .order('name', ascending: true)   // ne: .order('name')
  ```
- **String koji se razlikuje po vertikali ne smije biti u ekranu.** Ide kroz `Vertical.terms`,
  do kojeg se stiže sa `verticalOf(ref)` (`apps/client/lib/src/core/vertical_provider.dart`):

  ```dart
  final vertical = verticalOf(ref);
  Text(vertical.terms.bookCta)          // ne: Text('Zakaži termin')
  Text(vertical.terms.customerSingular) // ne: Text('Klijent')
  ```

  Isto vrijedi za grananje: nema `if (vertical.key == 'dental')` u ekranu, nego flag u
  `Vertical.features`. Jezik aplikacije (dugmad, greške) ide kroz `.arb`. To su dvije različite
  stvari i ne miješaju se — `.arb` prevodi "Otkaži" na engleski, `terms` bira između "Klijent" i
  "Pacijent" na istom jeziku.

## Supabase / SQL

- **Sve `snake_case`**, tabele u množini (`appointments`, `working_hours`).
- **Migracija po promjeni**, ime `<timestamp>_<opis>.sql` kroz `supabase migration new <opis>` —
  nikad ručno preimenovano, nikad izmijenjeno nakon što je pušteno.
- **Nikad `ALTER` direktno na produkciji.** Tok je lokalno → migracija → staging → produkcija.
- **Autorizacija ide kroz `private.*` helpere**, politika ih zove umjesto da prepisuje uslov.
  Svaka `security definer` funkcija ima `set search_path = ''` i potpuno kvalifikovane reference.
- **Nova tabela treba i grant i politiku i test.** Detalji i checklist: `.claude/docs/security.md`.
- **pgTAP test koji ne pada kad se politika ukloni ne testira ništa.** Piši negativan slučaj.

## Generisani fajlovi

**Dvije vrste, i u gitu se ponašaju suprotno.** Nijedna se ne edituje rukom.

| | Izlaz iz | U gitu? | Provjera |
|---|---|---|---|
| `tenants.g.dart`, Gradle blok, `*.xcconfig` | `tool/gen_*.dart` nad `tenants/*/tenant.yaml` | **da** | `dart run tool/gen_flavors.dart --check` |
| `*.freezed.dart`, `*.g.dart` u `packages/` | `build_runner` nad anotacijama u istom fajlu | **ne** | regeneriše se u CI-ju prije `analyze` |

Prvi su izlaz iz ulaza koji CI nema kako da reprodukuje bez generatora i koji build traži — zato su
u gitu i zato `--check` pada kad odlutaju (ADR-0002). Drugi nastaju determinstički iz anotacija u
istom fajlu, pa bi ih commitovanje pretvorilo u diff veći od ručno pisanog koda i u merge konflikte
koji se ionako rješavaju samo ponovnim generisanjem.

`.gitignore` to razdvaja eksplicitno: `*.g.dart` je ignorisan, a `apps/client/lib/src/generated/tenants.g.dart`
je izuzet iz ignorisanja. Ako dodaješ novi generator, odluči u koju kolonu ide **prije** prvog
commita.

Na svježem klonu `melos run codegen` mora proći prije `analyze` i `test` — inače analiza pada na
`part 'x.freezed.dart'` fajlovima kojih nema. Više: `.claude/docs/workflows.md`, a za flavor stranu
`.claude/docs/tenant-factory.md`.

## Testovi

- Widget/unit testovi stoje uz paket koji pokrivaju (`apps/*/test/`, `packages/*/test/`).
- SQL testovi u `supabase/tests/` — pgTAP unutar rollback transakcije, plus Deno REST skripta koja
  koristi dva stvarna JWT-a.
- **Nema E2E ni integration testa booking flowa.** Prolazna suite ne govori ništa o ekranu ni o
  upitu. Nikad ne tvrdi da je ekran verifikovan testovima — dokaz je pokretanje (`/verify`).
- Test koji traži `--dart-define` mora se tako i pokretati u CI-ju; test bez definea koji "prolazi"
  je test koji ne gleda pravu konfiguraciju.

## Dizajn (`prototype/ui/`)

Ekran se piše po `prototype/ui/SPEC.md`. Iz njega se uzima **oblik** — tipografska skala, spacing ritam,
radius 0, hairline granice umjesto sjenki, dodirne mete ≥44px, oblik komponenti — i taj oblik živi u
`core_ui`. **Boja se ne uzima**: hex u handoffu je paleta jednog brenda, a boja dolazi iz
`tenant.yaml` kroz `buildAppTheme()`. Tekst dolazi iz `vertical.terms`, ne iz stringa u widgetu.

Hardkodiran hex ili hardkodiran naziv usluge u ekranu prolazi test i prolazi pregled screenshota —
padne tek na drugom tenantu ili drugoj vertikali.

### Pristupačnost (FE-502)

- **Dodirna meta je ≥ 44 px, i u adminu.** Izmjeren piksel iz handoffa (36, 38, 42) je slabiji od
  donje granice: visina ide kroz `AppSize.touchTarget` / `AdminSize.touchTarget`, a vidljivi
  element koji je manji (prekidač, strelica) dobija veću nevidljivu metu oko sebe.
- **Tap bez fokusa je greška.** Goli `GestureDetector` tastatura ne dohvata. Za kontrolu se uzima
  `InkWell` ili Material dugme; za tap preko slike `AppTappable` iz `core_ui`, jer bi preklop
  `InkWell`-a završio ispod slike.
- **Verzal je stil, ne podatak.** String ostaje u normalnom obliku, `toUpperCase()` ide samo uz
  `semanticsLabel` (`AdminVerzal` to radi u jednom redu). Izuzetak — skraćenica, inicijal, tekst pod
  `ExcludeSemantics` — nosi `// verzal-ok: <razlog>`. Čuva ga `verzal_semantika_test.dart` u obje
  aplikacije.
- **Ikona bez teksta nosi labelu** (`Icon(..., semanticLabel:)`); `Tooltip` čitaču ne daje ime.
- **Novi ekran ulazi u mjerenje.** U adminu jedan poziv `pristupacnostEkrana` iz
  `test/support/pristupacnost.dart` u test fajlu ekrana (mete, labele, fokus, kontrast na obje
  širine, 130 % fonta); u klijentu ruta u `test/accessibility_test.dart`, gdje se kontrast mjeri
  na **svakom tenantu** iz registra.

## Web prototip (`prototype/wireframe/`)

Radix + Tailwind (shadcn stil), `lucide-react` kao jedini jezik ikona kroz cijeli sistem.
**Zamrznut** — referenca za flow i rute, ne za vizual i ne za komponente. Nema eslint/prettier
konfiguracije i neće je dobiti; hook se dodaje kad stigne pravi `web/` (Next.js konzola, `docs/07 §1`).

## Git

Grananje, commit poruke, PR konvencija i pravila o tome kad pitam a kad odlučim sam žive u
`.claude/docs/ai-interaction.md` — jedan izvor, da se ne raziđu. Ukratko: Conventional Commits sa
scopeom, naslov na bosanskom u imperativu, tijelo nosi *zašto* i *dokaz*, grana sa `main`, PR
protiv `main`, opis po `.github/pull_request_template.md`.
