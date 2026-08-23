# Task 01 — Skeleton repozitorija

| | |
|---|---|
| **Procjena** | 0.5 dana |
| **Zavisi od** | ničega — prvi task |
| **Blokira** | sve ostale taskove |
| **Reference** | [07 §1](../docs/07-tech-architecture.md#1-puna-struktura-repozitorija) · [04 §2](../docs/04-flutter-tenant-factory.md#2-struktura-repozitorija) |

## Cilj
Prazan, ali ispravno strukturiran monorepo koji prolazi `melos bootstrap` i `flutter analyze` bez greške — temelj na koji se kače svi ostali taskovi.

## Definicija gotovog
- [ ] `melos.yaml` u rootu, `melos bootstrap` prolazi bez greške
- [ ] `apps/client/` i `apps/admin/` postoje kao prazni Flutter projekti (`flutter create`)
- [ ] `packages/core_domain/`, `packages/core_api/`, `packages/core_ui/` postoje kao prazni Dart/Flutter paketi
- [ ] `analysis_options.yaml` u rootu (bazirano na `flutter_lints`), primijenjen kroz sve pakete
- [ ] `supabase/` inicijalizovan (`supabase init`), lokalni Docker stack se pokreće (`supabase start`)
- [ ] `tenants/` i `tool/` folderi postoje (prazni, sa `.gitkeep` ili placeholder fajlom)
- [ ] `lefthook.yml` postoji sa pre-commit hookom koji pokreće `dart format --set-exit-if-changed` na dodirnute Dart fajlove
- [ ] `README.md` u rootu ažuriran da opisuje novu strukturu (ne samo React prototip)

## Koraci
1. `flutter create apps/client` i `flutter create apps/admin` (org identifier po [04 §3](../docs/04-flutter-tenant-factory.md#3-tenantyaml--jedini-fajl-koji-pišeš-po-klijentu) šablonu, npr. `ba.nasadomena`)
2. `flutter create --template=package packages/core_domain packages/core_api packages/core_ui`
3. Napiši `melos.yaml` sa `packages: [apps/*, packages/*]` i osnovnim skriptama (`analyze`, `test`, `format`)
4. Kopiraj strukturu foldera iz [07 §1](../docs/07-tech-architecture.md#1-puna-struktura-repozitorija) unutar `apps/*/lib/src/{features,core,l10n}` i `packages/*/lib/src/*` — prazni folderi sa `.gitkeep` su OK za sada
5. `supabase init` u rootu, provjeri da `supabase start` diže lokalni Postgres bez greške
6. Postavi `lefthook.yml` (v. [07 §6](../docs/07-tech-architecture.md#6-monorepo-alati-i-konvencije)) i `lefthook install`
7. Commit: "chore: repo skeleton — melos, apps, packages, supabase init"

## Napomena
Ovaj task **ne** uvodi state management, routing ni ijedan paket iz [07 §3](../docs/07-tech-architecture.md#3-flutter-paketi--konkretan-izbor) — to dolazi tek u Sprint 1 kad se piše prvi ekran. Cilj ovdje je čista struktura, ne funkcionalnost.
