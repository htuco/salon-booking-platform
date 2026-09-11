# Taskovi — Sprint 0

Raspisani taskovi za [Sprint 0 iz 01 §17](../docs/01-mvp-spec.md#17-build-order), poredani po redoslijedu izvršavanja (ne po prioritetu feature-a — po tome šta blokira šta). Svaki task ima svoj `.md` fajl sa ciljem, definicijom gotovog i koracima.

**Zašto ovim redom:** taskovi 1–4 dokazuju da native multi-tenant model uopšte radi (flavor sistem, RLS izolacija, CI) prije nego što se piše ijedan pravi ekran. Taskovi 5–6 su srce proizvoda (availability, vertikale) i moraju postojati prije UI-ja jer je svaka kasnija promjena u njima prepisivanje svih ekrana. Detaljno obrazloženje reda: [01 §17](../docs/01-mvp-spec.md#17-build-order).

| # | Task | Blokira | Procjena |
|---|---|---|---|
| [01](01-repo-skeleton.md) ✅ | Skeleton repozitorija (melos, apps, packages, supabase/) | sve ostalo | 0.5 dana |
| [02](02-supabase-schema-rls.md) ✅ | Supabase šema + RLS + policy testovi | task 03, 05 | 1–2 dana |
| [03](03-flavor-system.md) ✅ | Flavor sistem — dokaz na 2 demo tenanta | task 04 | 2–3 dana |
| [04](04-ci-pipeline.md) 🟡 | CI pipeline — jedna komanda do artefakta | prvi pravi build | 1 dan |
| [05](05-availability-engine.md) ✅ | Availability engine na backendu + testovi | booking UI | 2–3 dana |
| [06](06-vertical-pack.md) ✅ | `VerticalPack` + `Vertical` klasa u `core_domain` | svaki ekran sa tekstom | 2–3 dana |

**Ukupno: ~9–12 radnih dana.** Tek nakon ovoga ima smisla početi `core_ui` theme factory i prvi booking ekran.

> **Task 01 je odrađen** — skeleton je generisan i verifikovan (`melos bootstrap`/`analyze`/`test` prolaze). Prije nego kreneš na task 02, pokreni `supabase start` lokalno da potvrdiš Docker stack — to nije bilo moguće verifikovati u sandboxu bez Docker daemona. Detalji u [01-repo-skeleton.md](01-repo-skeleton.md).

> **Task 02 je odrađen i verifikovan** — migracije, RLS, seed, pgTAP i Deno REST test prolaze na CI-ju
> ([run 34417077084](https://github.com/htuco/salon-booking-platform/actions/runs/34417077084)): 38 pgTAP testova PASS,
> 24 REST asercije sa dva stvarna JWT-a. Tenant izolacija je dokazana protiv žive baze, ne samo napisana.
> Workflow ponavlja dokaz na PR-u i na push u `main` nad `supabase/`.
>
> Od 12.09.2026. `supabase/` promjene se dokazuju **lokalno** kroz `./tool/test_supabase.sh`
> (Docker Desktop je instaliran). CI ponavlja isti dokaz na push u `main`, iz čistog checkouta.


> **Task 03 je zatvoren** (✅) — Android i iOS flavori dokazani na artefaktima, ikone po flavoru rade.
> `aapt2 dump badging` potvrđuje različit `applicationId` i label; oba APK-a instalirana na isti
> emulator (API 36, x86_64) istovremeno; iOS bundle nosi tačan `CFBundleIdentifier`,
> `CFBundleDisplayName` i `AppIcon-<flavor>`. CI to ponavlja na svaki PR.
>
> Zamke koje su nas koštale (AGP 9 gasi `resValues`, `buildSettings` nadjačava xcconfig, pogrešno
> ime postavke za ikonu, hardkodiran `CFBundleDisplayName`, xcconfig bez Flutterovog
> `Generated.xcconfig`) su zapisane u [03-flavor-system.md](03-flavor-system.md#status-2026-09-10)
> i u [`.claude/docs/tenant-factory.md`](../.claude/docs/tenant-factory.md).

> **Task 04 je 🟡 — sve osim potpisivanja i stvarnih ključeva.** `tool/build_tenant.sh` je jedina
> ulazna tačka u build (CI ga poziva, ne svoju kopiju `flutter build`), job `release-artifacts` na
> ručni trigger pravi AAB za oba tenanta i provjerava `applicationId` i `versionCode` u gotovom
> bundleu, a `BUILD_NUMBER` iz CI-ja stvarno stiže do artefakta — dokazano sa `versionCode='42'`
> naspram `'1'` bez te varijable.
>
> Ostaju dvije stavke koje traže naloge, ne kod: **Android keystore** (release se sad potpisuje
> debug ključem, pa AAB nije za store) i **stvarne Supabase vrijednosti** u GitHub `vars`/`secrets`.
> Prvo je Sprint 3, drugo ide uz [task 07](sprint-1/07-app-plumbing.md). Izbor CI providera je
> zapisan u [ADR-0005](../docs/adr/0005-github-actions-umjesto-codemagica.md).

> **Task 05 je zatvoren** (✅) — `get_available_slots`, `get_available_dates`, `book_appointment` i
> exclusion constraint `appointments_no_overlap`. Dokazano na CI-ju:
> [run 34542304820](https://github.com/htuco/salon-booking-platform/actions/runs/34542304820),
> 66 pgTAP testova PASS (38 postojećih + 28 novih) plus REST izolacija.
>
> Availability i booking pravila su sada **isključivo u bazi**. Kad se piše booking UI
> ([task 11](sprint-1/11-booking-flow.md)), aplikacija prikazuje listu koju dobije i obrađuje
> `409` — nijedan slot se ne računa u Dartu.

> **Task 06 je zatvoren** (✅) — **Sprint 0 je time gotov.** Terminologija, booking pravila i
> feature flagovi po vertikali su config koji se čita u runtime-u: `Vertical` u `core_domain`,
> `VerticalRepository` u `core_api`, `verticalProvider` u `apps/client`. Placeholder ekran uzima
> CTA iz `vertical.terms`, ne iz literala.
>
> Dokazano na CI-ju ([run 34544339115](https://github.com/htuco/salon-booking-platform/actions/runs/34544339115)
> — uz analizu i testove prolaze i oba Android APK-a i oba iOS builda) i lokalno:
> `melos run analyze` (5/5 paketa čisto), `dart format --set-exit-if-changed`
> (0 changed), `melos run test` — **32 testa PASS**. Ključni test mijenja terminologiju na istoj
> instanci app-e i pokazuje da je mehanizam runtime, ne compile-time; drugi parsira **stvarni**
> `supabase/seed.sql` i pada ako seed i Dart model odu u različitim smjerovima.
>
> **DB polovina je bila gotova još u tasku 02** — `vertical_packs`, `salons.vertical_pack_key` i
> `salons.terminology_override` su postojali i bili dokazani; ovaj task je dodao samo Dart stranu.
> `core_domain` je uz to preveden na čist Dart, jer je kao Flutter paket kršio sloj koji
> `.claude/docs/architecture.md` opisuje.
>
> Ostaje za Sprint 1: ekran čita **živu** bazu tek kad `Supabase.initialize` uđe u
> [task 07](sprint-1/07-app-plumbing.md) — lanac je dokazan do repozitorija, ne kroz mrežu.
> `dental`/`health` vertikale i mehanički lint protiv literala u ekranu su svjesno odgođeni;
> detalji u [06-vertical-pack.md](06-vertical-pack.md#status-2026-09-11--✅-zatvoren).

## Kako koristiti ovaj folder

- **[`CURRENT.md`](CURRENT.md) je aktivni task** — jedan u svakom trenutku. Vodi ga skill `/task`
  (`load` ga puni, `start` mijenja status, `complete` ga prazni i dopisuje u `## Istorija`).
  Puni task fajl i repo su iznad njega; kad se raziđu, `CURRENT.md` se ispravlja.
- Čekiraj DoD stavke u svakom task fajlu kako napreduješ.
- Ne otvaraj task 05/06 dok 01–04 nisu gotovi — zavisnosti nisu formalnost, availability engine testovi trebaju stvarnu šemu (02), a CI (04) treba flavor sistem (03) da ima šta da builda.
- Sprint 1 je raspisan u [`sprint-1/`](sprint-1/) (taskovi 07–11: plumbing, `core_api`, `core_ui`,
  home ekran, booking flow). Ne dopisuj ih ovdje — ovaj fajl ostaje indeks Sprinta 0.
- Taskovi se pišu **jedan sprint unaprijed**. Sprint 2 (auth, admin, push) ima redoslijed u
  [01 §17](../docs/01-mvp-spec.md#17-build-order), ali se raspisuje tek kad Sprint 1 bude gotov —
  specifikacija napisana tri sprinta ranije zastari prije nego što je iko otvori.
