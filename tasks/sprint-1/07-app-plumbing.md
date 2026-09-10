# Task 07 — App plumbing: Riverpod, go_router, env i Supabase klijent

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [01 — skeleton](../01-repo-skeleton.md), [03 — flavor sistem](../03-flavor-system.md) |
| **Blokira** | svaki ekran u oba app-a — 08, 09, 10, 11 |
| **Reference** | [07 §3](../../docs/07-tech-architecture.md#3-flutter-paketi--konkretan-izbor) · [07 §8](../../docs/07-tech-architecture.md#8-ključne-odluke) |

## Cilj
`apps/client` i `apps/admin` prestaju biti prazni skeletoni: imaju state management, routing, konfiguraciju i inicijalizovan Supabase klijent. Nijedan ekran se ne piše prije ovoga, jer prvi ekran napisan bez routera i providera postaje šablon koji se kopira.

> Ovaj task nije u [01 §17](../../docs/01-mvp-spec.md#17-build-order) build orderu. Dodan je jer koraci 9–11 pretpostavljaju da app ima kičmu, a nijedan raniji task je ne postavlja.

## Definicija gotovog
- [ ] `flutter_riverpod` + `riverpod_generator` dodani u `apps/client` i `apps/admin`; `ProviderScope` obavija oba app-a
- [ ] `go_router` konfigurisan u `lib/src/core/router/`; rute prate [01 §12](../../docs/01-mvp-spec.md#12-screens) (client: `/`, `/services`, `/book/*`, `/auth/login`, `/account`, `/appointments`; admin: `/login`, `/dashboard`, `/appointments`, `/calendar`, `/services`, `/employees`)
- [ ] Web build klijent app-e daje **prave URL-ove po ekranu** — provjereno u browseru, ne pretpostavljeno
- [ ] `lib/src/core/env/` čita `SALON_ID` (`String.fromEnvironment`) i Supabase URL/anon key; **nijedan ključ nije hardkodiran** — dolaze kroz `--dart-define`, a lokalno kroz `--dart-define-from-file`
- [ ] `supabase_flutter` inicijalizovan jednom, u bootstrapu, i izložen kao Riverpod provider
- [ ] Klijentski Supabase klijent šalje **`x-salon-id` header** na svaki zahtjev za privatne podatke (v. [ADR-0003](../../docs/adr/0003-x-salon-id-bira-kontekst-ne-daje-prava.md)); admin app ga ne šalje
- [ ] `intl` + `flutter_localizations` podešeni, `lib/src/l10n/app_bs.arb` postoji sa bar pet stvarnih stringova i generiše se u build koraku
- [ ] `main.dart` više ne drži placeholder ekran; `TenantConfig` iz `tenants.g.dart` se čita kroz provider, ne direktno u widgetu
- [ ] `melos run analyze` i `melos run test` prolaze; postojeći `tenant_theme_test.dart` i dalje prolazi za oba tenanta

## Koraci
1. Dodaj pakete u oba app-a i uvedi `ProviderScope` + `bootstrap()` funkciju koja radi async inicijalizaciju prije `runApp`
2. `core/env/app_env.dart` — jedno mjesto koje čita sve `--dart-define` vrijednosti i pada glasno ako `SALON_ID` fali (danas se to vidi tek kao tekst na ekranu)
3. `core/router/app_router.dart` — `GoRouter` sa rutama iz §12, plus `errorBuilder`. Admin dobija svoj router
4. Supabase klijent provider; za client app postavi globalni header `x-salon-id` iz `AppEnv.salonId`
5. `.arb` skeleton + `flutter gen-l10n` u build koraku; jedan string kroz `AppLocalizations` da dokažeš lanac
6. Prebaci `tenants.g.dart` čitanje iza `tenantProvider`
7. Commit: `feat(apps): plumbing — riverpod, go_router, env, supabase klijent`

## Zamke
- **`x-salon-id` nije sigurnosna mjera**, nego izbor konteksta. Ne piši kod koji se oslanja na to da header sam po sebi nešto štiti — RLS to radi ([security.md](../../.claude/docs/security.md)).
- Supabase anon key **jeste** javan po dizajnu, ali URL i key ipak idu kroz `--dart-define`, ne u git: mijenjaju se po okruženju (dev/staging/prod).
- Web build je razlog zašto je `go_router` obavezan. Ako prvi ekran ode kroz `Navigator.push`, web verzija nema URL i to se otkriva kasno.
