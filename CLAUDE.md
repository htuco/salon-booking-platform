# CLAUDE.md

Salon Booking Platform — jedan Flutter codebase + jedan multi-tenant Supabase backend → N
brandiranih native aplikacija u storeovima. Novi klijent je novi flavor i config, ne novi projekat.

Ovaj fajl je **router**. Kratak je jer ulazi u svaki context window — detalji su u dokumentima
ispod, koji se čitaju po potrebi.

## Jezik

Repo se piše na **bosanskom** — dokumentacija, komentari u kodu, commit poruke, PR opisi.
Tehnički termini ostaju engleski (flavor, migration, RLS, provider). Piši isto.

## Mapa repoa

- `apps/client/` — Flutter, N flavora, brandiran po salonu. `apps/admin/` — Flutter, generička za sve salone.
- `packages/core_domain|core_api|core_ui/` — zajednički kod. Danas skeletoni.
- `supabase/` — migracije, seed, pgTAP + Deno testovi, Edge Functions. Izvor istine za šemu.
- `tenants/<flavor>/tenant.yaml` — jedini fajl koji se piše po klijentu.
- `tool/` — generatori (flavori, iOS konfiguracije, placeholder ikone).
- `src/` — React wireframe prototip. **Nije production kod** i ne postaje.
- `docs/` — proizvodna specifikacija (01–07). `tasks/` — raspisani taskovi Sprinta 0.

## Pročitaj prije nego što djeluješ

- **Bilo šta oko šeme, RLS-a, upita ili tenant izolacije** → `.claude/docs/security.md`. Ovo je jedini
  dio sistema gdje greška curi tuđe podatke; ne piši politiku ni upit napamet.
- **Struktura, slojevi, gdje šta živi, kako se stvari povezuju** → `.claude/docs/architecture.md`
- **Flavori, `tenant.yaml`, generatori, novi klijent, store build** → `.claude/docs/tenant-factory.md`
- **Kako se piše kod ovdje** → `.claude/docs/conventions.md`
- **Komande: pokretanje, testovi, generatori, CI, migracije** → `.claude/docs/workflows.md`
- **Domenski rječnik** (šta je "termin", "vertikala", "tenant", "flavor") → `CONTEXT.md`
- **Zašto je nešto odlučeno ovako** → `docs/adr/`, pa `docs/README.md` tabela odluka
- **Dokazivanje da promjena stvarno radi** → skill `/verify`
- **Predaja posla kolegi** → skill `/handoff`, i `docs/TEAM_HANDBOOK.md`

## Tvrda pravila

- **Generisane fajlove ne diraš rukom.** Gradle blok između `BEGIN/END GENERATED FLAVORS`,
  `apps/client/ios/flavors/*.xcconfig`, iOS build konfiguracije i scheme u `Runner.xcodeproj`, i
  `apps/client/lib/src/generated/tenants.g.dart` su izlaz iz `tenants/*/tenant.yaml`. Mijenja se
  `tenant.yaml`, pa se pokrene generator. CI pada na `dart run tool/gen_flavors.dart --check`.
- **Svaki upit i svaka politika su tenant-scoped.** Nema čitanja ni pisanja preko granice salona.
  `x-salon-id` header bira kontekst — nikad ne daje članstvo ni admin prava. Detalji: `security.md`.
- **Ne commituj tajne.** Izlaz `supabase status -o env`, service role ključ, pravi
  `google-services.json`, `.env`, iOS potpisni materijal. Generisani `google-services.json` u repou
  je placeholder i takav ostaje dok se ne uvede sigurno ubacivanje pravog u CI-ju.
- **Na razvojnoj mašini nema Dockera, pa `supabase start` ne radi lokalno.** Promjene u `supabase/`
  se dokazuju kroz CI workflow `Supabase tests`, ne lokalno. Ne tvrdi da RLS radi dok taj job nije
  zelen — napisana politika nije dokazana politika.
- **`src/` je wireframe prototip.** Služi za validaciju flowa i vizuala prije Dart koda. Ne dodaje
  se feature tamo u nadi da će "kasnije preći u proizvod" — proizvod je Flutter.
- **Testovi su uski.** Postoje widget/unit testovi (`apps/client/test/`, `packages/*/test/`) i
  SQL/REST testovi tenant izolacije. Nema E2E, nema integration testa booking flowa. Prolazna
  `melos run test` suite ne govori ništa o ekranu ni o upitu — to se dokazuje pokretanjem
  (`/verify`).
- **Novi Dart paket mora ručno u `workspace:` listu u root `pubspec.yaml`** — `workspace:` ne
  podržava globove, a paket koji nije u listi tiho ispada iz `melos` skripti i CI-ja.
- **Odluke iz tabele u `docs/README.md` se ne otvaraju ponovo bez novog podatka.** Ako imaš novi
  podatak, to je ADR (`docs/adr/`), ne usputna promjena koda.
- **Conventional Commits, poruka na bosanskom**, tijelo objašnjava *zašto* i šta je dokazano.
  Grana se otvara sa `main`, PR ide protiv `main`.

## Konvencije u jednoj slici

- Flutter: feature-first folderi (`lib/src/features/<feature>/`), zajedničko u `packages/core_*`.
- Riverpod za state i DI, `go_router` za rute, `freezed` za modele, `supabase_flutter` za backend.
- Supabase: `snake_case` u bazi, migracija po promjeni, `private.*` helperi za autorizaciju.
- `SALON_ID` je jedini `--dart-define` koji build prosljeđuje; ostalo se traži u generisanom registru.

## Drži ove dokumente u sinhronizaciji

Dokument vrijedi samo dok odgovara kodu. Kad promjena mijenja nešto što dokument opisuje, ažuriraj
ga **u istoj promjeni** — ne ostavljaj za kasnije. Ako ne znaš kako to formulisati, napiši najbolju
verziju i spomeni to u sažetku, umjesto da preskočiš.

| Promijenio si | Ažuriraj |
|---|---|
| Šemu, RLS politiku, `private.*` funkciju, grantove | `.claude/docs/security.md` (+ `supabase/IMPLEMENTATION.md` ako mijenja ugovor) |
| Strukturu foldera, slojeve, izbor paketa, tok podataka | `.claude/docs/architecture.md` |
| Generator, `tenant.yaml` polje, flavor pipeline, store korak | `.claude/docs/tenant-factory.md` + `tenants/README.md` |
| Obrazac pisanja koda, imenovanje, lint pravilo | `.claude/docs/conventions.md` |
| Komandu, CI job, env varijablu, način pokretanja | `.claude/docs/workflows.md` (+ `/verify` skill ako mijenja dokaz) |
| Domenski pojam ili njegovo značenje | `CONTEXT.md` |
| Odluku koja se ne može pročitati iz koda | novi ADR u `docs/adr/` |
| Status taska (gotovo / blokirano / ostalo za sljedećeg) | task fajl u `tasks/` **i** blok u `tasks/README.md` |

Dva pravila za pisanje ovih dokumenata:

- Referenciraj ih **običnom putanjom u backtickovima, nikad sa `@`**. `@` uvlači fajl u svaki
  context window i poništava čitanje-po-potrebi.
- **Opisuj oblik, ne inventar.** Nabrojane liste fajlova tiho zastarijevaju, jer dodavanje fajla ne
  djeluje kao promjena koja "mijenja ono što dokument opisuje". Imenuj svrhu foldera i dva-tri
  nosiva fajla; ostalo neka pokaže `ls`.

## Skills i agenti

| Skill | Za šta |
|---|---|
| `/task load\|start\|review\|verify\|complete` | Životni ciklus taska iz `tasks/` — grana, DoD, status blok, PR |
| `/verify` | Kako se u ovom repou stvarno dokazuje da promjena radi |
| `/handoff` | Predaja posla kolegi: šta je dokazano, šta je zamka, šta je sljedeći korak |
| `/new-tenant` | Novi klijent od `tenant.yaml` do zelenog CI-ja |
| `/cleanup` | Higijena: drift generisanog, mrtvi TODO, dokumenti van sinhronizacije |
| `/research` | Istraživanje koje proizvodi dokument, nikad kod |

Subagenti u `.claude/agents/`: `dart-reviewer`, `rls-auditor`, `duplication-scanner`,
`flutter-ui-reviewer`. Šablon za nove: `.claude/agent-templates/`.
