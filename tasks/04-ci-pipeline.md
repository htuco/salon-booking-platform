# Task 04 — CI pipeline: jedna komanda do artefakta

| | |
|---|---|
| **Procjena** | 1 dan |
| **Zavisi od** | [03 — flavor sistem](03-flavor-system.md) |
| **Blokira** | prvi pravi build koji ide dalje od lokalne mašine |
| **Reference** | [04 §7–8](../docs/04-flutter-tenant-factory.md#7-automatizacija--šta-mora-biti-skriptovano) · [07 §6](../docs/07-tech-architecture.md#6-monorepo-alati-i-konvencije) |

## Cilj
Nijedan build ne izlazi sa lokalne mašine od ovog trenutka nadalje — pravilo iz [04 §8.1](../docs/04-flutter-tenant-factory.md#81-pravila-koja-se-ne-pregovaraju) postavljeno dok je build još prazan, ne kasnije kad ima 20 tenanata.

## Definicija gotovog
- [ ] CI provider izabran i podešen (Codemagic preporuka za Flutter matrix, [04 §8](../docs/04-flutter-tenant-factory.md#8-cicd)) — GitHub Actions za `supabase/` testove ([02](02-supabase-schema-rls.md)) i eventualno `web/`
- [ ] `tool/build_tenant.sh <tenant> <platform> <mode>` postoji i radi lokalno kao referenca za CI skriptu ([04 §7.1](../docs/04-flutter-tenant-factory.md#71-jedna-komanda))
- [ ] CI workflow koji na push/PR pokreće: `melos run analyze`, `melos run test`, `dart tool/gen_flavors.dart`
- [ ] CI workflow (ručni trigger ili na tag) koji builduje **oba** demo tenanta iz [03](03-flavor-system.md) i producira artefakte (AAB/APK) — dokaz da CI matrix po tenantu radi
- [ ] Secrets (API ključevi, Supabase URL) idu kroz CI environment groups, ne kroz commitovan fajl
- [ ] `versionName` je zajednički (`--dart-define` ili `pubspec.yaml`), `versionCode`/`buildNumber` je po tenantu i inkrementira ga CI, ne ručno editovanje

## Koraci
1. Izaberi provider (Codemagic ili GitHub Actions + fastlane — obje opcije su opisane u [04 §8](../docs/04-flutter-tenant-factory.md#8-cicd))
2. Napiši `codemagic.yaml` (ili `.github/workflows/build-client.yml`) sa workflow-om koji poziva `tool/build_tenant.sh`
3. Podesi environment groups za API ključeve (Supabase anon key, `API_URL`) — nikad hardkodirano u skripti
4. Dodaj analyze/test korak koji se pokreće na svaki PR (brz feedback prije buildovanja)
5. Dodaj matrix/manuelni trigger koji builduje oba demo tenanta i čuva artefakte
6. Testiraj: napravi PR, potvrdi da CI prolazi; ručno trigeruj build za oba tenanta, skini artefakte i instaliraj ih
7. Dodaj GH Actions workflow koji pokreće `supabase test db` na PR-ove koji diraju `supabase/migrations/**` (nastavak taska 02)
8. Commit: "ci: pipeline za analyze/test/build po tenantu"

## Napomena
Ovaj task **ne** uključuje store submission (Play Console / App Store Connect upload) — to je Sprint 3 ([01 §17](../docs/01-mvp-spec.md#17-build-order)). Cilj ovdje je isključivo da artefakt izlazi iz CI-ja, reproducibilno, bez tvoje lokalne mašine u lancu.
