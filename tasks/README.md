# Taskovi — Sprint 0

Raspisani taskovi za [Sprint 0 iz 01 §17](../docs/01-mvp-spec.md#17-build-order), poredani po redoslijedu izvršavanja (ne po prioritetu feature-a — po tome šta blokira šta). Svaki task ima svoj `.md` fajl sa ciljem, definicijom gotovog i koracima.

**Zašto ovim redom:** taskovi 1–4 dokazuju da native multi-tenant model uopšte radi (flavor sistem, RLS izolacija, CI) prije nego što se piše ijedan pravi ekran. Taskovi 5–6 su srce proizvoda (availability, vertikale) i moraju postojati prije UI-ja jer je svaka kasnija promjena u njima prepisivanje svih ekrana. Detaljno obrazloženje reda: [01 §17](../docs/01-mvp-spec.md#17-build-order).

| # | Task | Blokira | Procjena |
|---|---|---|---|
| [01](01-repo-skeleton.md) ✅ | Skeleton repozitorija (melos, apps, packages, supabase/) | sve ostalo | 0.5 dana |
| [02](02-supabase-schema-rls.md) ✅ | Supabase šema + RLS + policy testovi | task 03, 05 | 1–2 dana |
| [03](03-flavor-system.md) | Flavor sistem — dokaz na 2 demo tenanta | task 04 | 2–3 dana |
| [04](04-ci-pipeline.md) | CI pipeline — jedna komanda do artefakta | prvi pravi build | 1 dan |
| [05](05-availability-engine.md) | Availability engine na backendu + testovi | booking UI | 2–3 dana |
| [06](06-vertical-pack.md) | `VerticalPack` + `Vertical` klasa u `core_domain` | svaki ekran sa tekstom | 2–3 dana |

**Ukupno: ~9–12 radnih dana.** Tek nakon ovoga ima smisla početi `core_ui` theme factory i prvi booking ekran.

> **Task 01 je odrađen** — skeleton je generisan i verifikovan (`melos bootstrap`/`analyze`/`test` prolaze). Prije nego kreneš na task 02, pokreni `supabase start` lokalno da potvrdiš Docker stack — to nije bilo moguće verifikovati u sandboxu bez Docker daemona. Detalji u [01-repo-skeleton.md](01-repo-skeleton.md).

> **Task 02 je odrađen i verifikovan** — migracije, RLS, seed, pgTAP i Deno REST test prolaze na CI-ju
> ([run 34417077084](https://github.com/htuco/salon-booking-platform/actions/runs/34417077084)): 38 pgTAP testova PASS,
> 24 REST asercije sa dva stvarna JWT-a. Tenant izolacija je dokazana protiv žive baze, ne samo napisana.
> Workflow ponavlja dokaz na svaki PR nad `supabase/`.
>
> Na razvojnoj mašini nema Dockera, pa `supabase start` ne radi lokalno — dok se ne instalira Docker Desktop,
> `supabase/` promjene se dokazuju kroz CI, ne lokalno.

## Kako koristiti ovaj folder

- Čekiraj DoD stavke u svakom task fajlu kako napreduješ.
- Ne otvaraj task 05/06 dok 01–04 nisu gotovi — zavisnosti nisu formalnost, availability engine testovi trebaju stvarnu šemu (02), a CI (04) treba flavor sistem (03) da ima šta da builda.
- Kad je Sprint 0 gotov, sljedeći taskovi (Sprint 1: booking flow, `core_api`, `core_ui`) idu u novi fajl `07-sprint-1.md` ili novi folder `tasks/sprint-1/` — ne dopisuj ih ovdje.
