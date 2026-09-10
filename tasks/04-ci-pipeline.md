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
- [x] CI provider izabran i podešen — **GitHub Actions, Codemagic se ne uvodi** ([ADR-0005](../docs/adr/0005-github-actions-umjesto-codemagica.md))
- [x] `tool/build_tenant.sh <flavor> <apk|aab|ios> [debug|release]` postoji i radi lokalno; CI ga poziva umjesto svoje kopije `flutter build` komande
- [x] CI workflow na push/PR: `gen_flavors --check`, `dart format`, `dart analyze`, testovi kroz melos, regresija teme po tenantu
- [x] CI workflow `release-artifacts` (ručni trigger) builduje **oba** tenanta u AAB, provjerava `applicationId` i `versionCode` kroz `bundletool dump manifest`, i uploaduje artefakte
- [~] Kanal za secrets postoji — `build_tenant.sh` čita `SUPABASE_URL`/`SUPABASE_ANON_KEY`/`API_URL` iz okoline, a workflow ih prosljeđuje iz `vars`/`secrets`. **Vrijednosti još nisu postavljene**, jer ih Sprint 0 nema ko koristiti; idu uz [task 07](sprint-1/07-app-plumbing.md)
- [x] `versionName` zajednički iz `tenant.yaml`, `versionCode` inkrementira CI kroz `BUILD_NUMBER` → `-PtenantVersionCode`; bez te varijable vrijedi vrijednost iz `tenant.yaml`

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

---

## Status (2026-09-10) — 🟡 dokazano osim potpisivanja i stvarnih ključeva

**Dokazano lokalno**, oba smjera override-a:

```
$ BUILD_NUMBER=42 tool/build_tenant.sh barberstudiovitez apk debug
$ aapt2 dump badging …app-barberstudiovitez-debug.apk | head -1
package: name='ba.nasadomena.barberstudiovitez' versionCode='42' versionName='1.0.0'

$ tool/build_tenant.sh beautystudiotravnik apk debug        # bez BUILD_NUMBER
package: name='ba.nasadomena.beautystudiotravnik' versionCode='1' versionName='1.0.0'

$ BUILD_NUMBER=42 tool/build_tenant.sh barberstudiovitez aab release
✓ Built build/app/outputs/bundle/barberstudiovitezRelease/app-barberstudiovitez-release.aab (44.1MB)
```

**Zamka koja je ovo blokirala:** generisani flavor blok je pisao `versionCode = 1` kao literal, a
flavor nadjačava `flutter.versionCode` — pa `--build-number` nikad nije stizao do APK-a. Generator
sada emituje `project.findProperty("tenantVersionCode") ?: <vrijednost iz tenant.yaml>`, a
`build_tenant.sh` prosljeđuje `-PtenantVersionCode`. Bez toga bi CI "inkrementirao" broj koji se
nigdje ne vidi.

**Ostalo za sljedećeg — oboje traži naloge, ne kod:**

1. **Android keystore + signing config.** Release se trenutno potpisuje debug ključem iz Flutterovog
   šablona, pa ovaj AAB **nije za store**. Keystore ide u GitHub secrets, `key.properties` se piše u
   CI-ju, `build.gradle.kts` dobija `signingConfig`. Sprint 3, uz prvi submission.
2. **Stvarne Supabase vrijednosti** u `vars.SUPABASE_URL` / `secrets.SUPABASE_ANON_KEY` /
   `vars.API_URL`. Kanal radi, vrijednosti fale. Postavljaju se kad app prvi put pozove backend
   ([task 07](sprint-1/07-app-plumbing.md)).

Store publikacija (`fastlane` ili ručni upload) nije dio ovog taska — v. [ADR-0005](../docs/adr/0005-github-actions-umjesto-codemagica.md).
