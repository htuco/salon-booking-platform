# Task 01 — Skeleton repozitorija

| | |
|---|---|
| **Status** | ✅ Odrađeno |
| **Procjena** | 0.5 dana |
| **Zavisi od** | ničega — prvi task |
| **Blokira** | sve ostale taskove |
| **Reference** | [07 §1](../../docs/07-tech-architecture.md#1-puna-struktura-repozitorija) · [04 §2](../../docs/04-flutter-tenant-factory.md#2-struktura-repozitorija) |

## Cilj
Prazan, ali ispravno strukturiran monorepo koji prolazi `melos bootstrap` i `dart analyze` bez greške — temelj na koji se kače svi ostali taskovi.

## Definicija gotovog
- [x] Root `pubspec.yaml` sa `workspace:` listom + `melos:` konfiguracijom, `melos bootstrap` prolazi bez greške — **ne** `melos.yaml` (v. napomena ispod)
- [x] `apps/client/` i `apps/admin/` postoje kao prazni Flutter projekti (`flutter create`, org `ba.nasadomena`)
- [x] `packages/core_domain/`, `packages/core_api/`, `packages/core_ui/` postoje kao prazni Dart/Flutter paketi
- [x] `analysis_options.yaml` u rootu (bazirano na `flutter_lints`), svaki paket ga uključuje sa `include: ../../analysis_options.yaml` — `melos run analyze` prolazi sa 0 nalaza u svih 5 paketa
- [x] `supabase/` inicijalizovan (`supabase init`) — `config.toml`, `migrations/`, `functions/{send-push,expire-pending,send-reminders,dental-recall}/`, `tests/`, `seed.sql`
- [ ] `supabase start` (lokalni Docker stack) — **nije verifikovano**, v. napomena ispod
- [x] `tenants/_template/` i `tool/` folderi postoje sa placeholder sadržajem
- [x] `lefthook.yml` sa pre-commit hookom koji pokreće `dart format --set-exit-if-changed` na dodirnute Dart fajlove; `npx lefthook install` + `npx lefthook validate` prolaze
- [x] `README.md` u rootu ažuriran — nova sekcija "Flutter monorepo (Sprint 0)" + struktura foldera

## Šta je stvarno pokrenuto i provjereno
Flutter SDK (stable), Dart, Melos i Supabase CLI su instalirani u ovoj sesiji da bi se skeleton stvarno generisao i verifikovao, ne samo hendkodirao:
- `flutter create` za `apps/client`, `apps/admin` i tri `packages/*` paketa
- `melos bootstrap` → **SUCCESS**, 5 paketa bootstrapovano
- `melos run analyze` → **No issues found!** u svih 5 paketa
- `melos run test` → **All tests passed!** (default `flutter_test` smoke testovi generisani sa `flutter create`)
- `melos run format` → sve formatirano, `--set-exit-if-changed` prolazi
- `supabase init` → uspješno, generisan `config.toml`
- `npx lefthook install` + `validate` → hook instaliran i validan

**`supabase start` nije pokrenut** — traži Docker daemon, koji nije dostupan u ovom sandboxu (`dockerd` postoji, ali se ne može podići zbog ograničenja okruženja). Provjeri ovo lokalno ili u CI-ju prije nego pređeš na task 02.

## ⚠️ Odstupanje od originalnog plana: Melos ≥7 ne koristi `melos.yaml`
Instalirana verzija (Melos 8.3.0) je od verzije 7 prešla na **Dart native pub workspaces** — standalone `melos.yaml` više ne postoji. Umjesto toga:
- Root **`pubspec.yaml`** ima `workspace:` listu paketa (bez globova — lista je eksplicitna, novi paket se mora ručno dodati) i `melos:` ključ sa skriptama
- Svaki paket u workspace-u ima `resolution: workspace` u svom `pubspec.yaml`
- `melos bootstrap` više ne generiše `pubspec_overrides.yaml` po paketu (to je bio mehanizam za ≤6.x) — samo pokreće `flutter pub get` u workspace-u

Ažurirano u [07 §6.1](../../docs/07-tech-architecture.md#61-melos-7--config-je-u-pubspecyaml-ne-u-melosyaml) i strukturnom dijagramu u [07 §1](../../docs/07-tech-architecture.md#1-puna-struktura-repozitorija). Ako se namjerno pinuje Melos ≤6.3.0 (stariji, poznatiji workflow sa `melos.yaml`), to je validna alternativa — ali trenutni skeleton prati aktuelnu (8.x) verziju.

## Koraci (kako je urađeno)
1. `flutter create --org ba.nasadomena --project-name client --platforms android,ios,web apps/client` (isto za `admin`)
2. `flutter create --org ba.nasadomena --template=package packages/core_domain` (isto za `core_api`, `core_ui`)
3. Root `pubspec.yaml` sa `workspace:` + `melos:` (ne `melos.yaml` — v. napomena gore), `resolution: workspace` dodan u svaki paket
4. Struktura foldera iz [07 §1](../../docs/07-tech-architecture.md#1-puna-struktura-repozitorija) kopirana u `apps/*/lib/src/{features,core,l10n}` i `packages/*/lib/src/*`, svaki prazan folder ima `.gitkeep` sa referencom na task koji ga popunjava
5. `supabase init` u rootu; `migrations/`, `tests/`, `functions/*` i `seed.sql` dodani ručno (CLI ih ne generiše)
6. `tenants/_template/tenant.yaml` (šablon iz [04 §3](../../docs/04-flutter-tenant-factory.md#3-tenantyaml--jedini-fajl-koji-pišeš-po-klijentu)) + `tool/.gitkeep`
7. `lefthook.yml` + `lefthook` kao `devDependency` u root `package.json` (dijeli se sa Node/Vite prototipom) + `npx lefthook install`
8. Root `README.md` ažuriran

## Napomena
Ovaj task **ne** uvodi state management, routing ni ijedan paket iz [07 §3](../../docs/07-tech-architecture.md#3-flutter-paketi--konkretan-izbor) — to dolazi tek u Sprint 1 kad se piše prvi ekran. Cilj ovdje je čista, verifikovana struktura, ne funkcionalnost.

## Sljedeći korak
[Task 02 — Supabase šema + RLS](02-supabase-schema-rls.md). Prije toga: provjeri `supabase start` lokalno (Docker) da potvrdiš da lokalni stack radi na tvojoj mašini.
