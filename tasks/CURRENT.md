# Trenutni task: 06 — `VerticalPack` + `Vertical` klasa u `core_domain`

Puni task: [`tasks/06-vertical-pack.md`](06-vertical-pack.md) · Učitano: 2026-09-11 · Grana: `feat/vertical-pack`

## Status

U toku

## Ciljevi

- [ ] `Vertical`, `VerticalTerms`, `BookingRules`, `VerticalFeatures` u `core_domain`, bez Fluttera
      i bez mreže — parsiraju se iz istog JSONB oblika koji već stoji u bazi
- [ ] `core_domain` prestaje biti Flutter paket (skida `flutter` zavisnost i `Calculator`
      placeholder) — arhitektura ga izričito traži čist
- [ ] `terminologyOverride` sa salona se sloji **preko** vertikalnog default-a, ključ po ključ
- [ ] `VerticalRepository` u `core_api` čita `vertical_packs` + `salons` po `salonId` i vraća
      `Vertical` iz `core_domain`
- [ ] Riverpod `verticalProvider` izlaže trenutni `Vertical` cijelom stablu u `apps/client`
- [ ] Placeholder ekran koji čita `vertical.terms.*` umjesto literala — dokaz da lanac
      baza → repo → provider → widget stvarno radi
- [ ] Test: promjena `appointmentSingular` mijenja tekst na ekranu bez rebuilda app-a
- [ ] Konvencija zapisana tamo gdje je pisac koda vidi (`core_domain` top-level dokumentacija +
      `.claude/docs/conventions.md`)

## Napomene

- **DB polovina taska je već isporučena u tasku 02** — ne piše se ponovo. `public.vertical_packs`
  (`key`, `display_name`, `terminology`, `default_settings`, `default_theme`, `default_services`,
  `feature_flags`, `required_consents`) postoji u `20260910090000_init_schema.sql`, a
  `salons.vertical_pack_key` i `salons.terminology_override` isto. `seed.sql` već ima **tri**
  reda: `barber`, `beauty` i `generic`. Zato DoD stavke 2, 3 i 7 iz task fajla stoje već ispunjene —
  ostaje Dart strana.
- **Seed je uži od specifikacije, namjerno.** `docs/05 §3` tabelira pet vertikala (`dental`,
  `health` uključivo), a `key` check constraint ih sve dozvoljava — ali seed ima tri. MVP traži
  `barber` i `beauty`; `dental` se ne dodaje u ovom tasku jer nosi recall, kartoteku i pristanke
  (`05 §6`, `§7`), što je zaseban task, ne usputni seed red.
- **`core_domain` danas ima `flutter` u `dependencies`** (ostatak `flutter create --template=package`
  skeletona) i `Calculator` klasu. `.claude/docs/architecture.md` traži sloj "bez Fluttera i bez
  mreže", pa se paket u ovom tasku prevodi na čist Dart. Test se onda piše sa `package:test`, ne
  `flutter_test` — inače zavisnost na Flutter ulazi na mala vrata.
- **Terminologija je već na bosanskom u seedu** i nosi dijakritiku. Dart strana je samo prenosi;
  ne prevodi i ne normalizuje.
- **Rod je dio proizvoda, ne detalj** (`05 §3`) — beauty salon je "Klijentica", ne "Klijent".
  Zato override mora ići **po ključu**, ne zamjenom cijelog objekta: salon koji mijenja samo
  `customerSingular` ne smije izgubiti ostatak vertikalne terminologije.
- **Nepoznat ključ vertikale ne smije srušiti app.** `key` u bazi dozvoljava pet vrijednosti, a app
  u storeu je starija od baze — parsiranje ide na `generic` default uz zadržavanje nepoznatog
  ključa, ne na exception.
- `flutter_riverpod` i `supabase_flutter` još **nisu** u nijednom `pubspec.yaml`-u — ovaj task ih
  prvi uvodi. Izbor je već donesen (`docs/07 §3`), pa nije ADR.
- Novi paket ne nastaje, ali ako nastane — mora ručno u `workspace:` listu u root `pubspec.yaml`.
- Dokaz je `melos run analyze` + `melos run test`, ne pokretanje app-a: ovo je logika i widget test,
  a ne ekran koji se gleda. Booking ekran koji ovo stvarno koristi je task 11.

## Istorija

- **01 — Skeleton repozitorija** (2026-08) — melos workspace, `apps/client`, `apps/admin`, `packages/core_*`, `supabase init`. `melos bootstrap`/`analyze`/`test` prolaze.
- **02 — Supabase šema + RLS** (2026-09-10) — 15 tabela, RLS na svakoj, `private.*` autorizacioni helperi, seed sa dva demo salona i tri vertikale. Dokazano na CI-ju: 38 pgTAP testova + 24 REST asercije sa dva stvarna JWT-a.
- **03 — Flavor sistem** (2026-09-10) — Android i iOS flavori za dva demo tenanta, ikone po flavoru, generatori u `tool/`. Dokazano na artefaktima: `aapt2 dump badging`, oba APK-a na istom emulatoru istovremeno, `CFBundleIdentifier`/`CFBundleDisplayName`/ikona iz gotovog iOS bundlea.
- **04 — CI pipeline** (2026-09-10, 🟡) — `tool/build_tenant.sh` kao jedina ulazna tačka u build, `release-artifacts` job pravi AAB za oba tenanta na ručni trigger, `BUILD_NUMBER` iz CI-ja stiže do artefakta (`versionCode='42'` naspram `'1'`). Ostaju keystore i stvarne Supabase vrijednosti — oboje traži naloge.
- **05 — Availability engine** (2026-09-11) — `get_available_slots`, `get_available_dates`, `book_appointment`, exclusion constraint `appointments_no_overlap`. Dokazano na CI-ju ([run 34542304820](https://github.com/htuco/salon-booking-platform/actions/runs/34542304820)): 66 pgTAP testova PASS. Availability logika je isključivo u bazi — nula u Dartu.
