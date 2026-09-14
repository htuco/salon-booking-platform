# Task 07 — App plumbing: Riverpod, go_router, env i Supabase klijent

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [01 — skeleton](../sprint-0/01-repo-skeleton.md), [03 — flavor sistem](../sprint-0/03-flavor-system.md) |
| **Blokira** | svaki ekran u oba app-a — 08, 09, 10, 11 |
| **Reference** | [07 §3](../../docs/07-tech-architecture.md#3-flutter-paketi--konkretan-izbor) · [07 §8](../../docs/07-tech-architecture.md#8-ključne-odluke) |

## Cilj
`apps/client` i `apps/admin` prestaju biti prazni skeletoni: imaju state management, routing, konfiguraciju i inicijalizovan Supabase klijent. Nijedan ekran se ne piše prije ovoga, jer prvi ekran napisan bez routera i providera postaje šablon koji se kopira.

> Ovaj task nije u [01 §17](../../docs/01-mvp-spec.md#17-build-order) build orderu. Dodan je jer koraci 9–11 pretpostavljaju da app ima kičmu, a nijedan raniji task je ne postavlja.

## Definicija gotovog
- [x] `flutter_riverpod` (**bez** `riverpod_generator` — v. status blok) dodani u `apps/client` i `apps/admin`; `ProviderScope` obavija oba app-a
- [x] `go_router` konfigurisan u `lib/src/core/router/`; rute prate [01 §12](../../docs/01-mvp-spec.md#12-screens) (client: `/`, `/services`, `/book/*`, `/auth/login`, `/account`, `/appointments`; admin: `/login`, `/dashboard`, `/appointments`, `/calendar`, `/services`, `/employees`)
- [x] Web build klijent app-e daje **prave URL-ove po ekranu** — provjereno u browseru, ne pretpostavljeno
- [x] `lib/src/core/env/` čita `SALON_ID` (`String.fromEnvironment`) i Supabase URL/anon key; **nijedan ključ nije hardkodiran** — dolaze kroz `--dart-define`, a lokalno kroz `--dart-define-from-file`
- [x] `supabase_flutter` inicijalizovan jednom, u bootstrapu, i izložen kao Riverpod provider
- [x] Klijentski Supabase klijent šalje **`x-salon-id` header** na svaki zahtjev za privatne podatke (v. [ADR-0003](../../docs/adr/0003-x-salon-id-bira-kontekst-ne-daje-prava.md)); admin app ga ne šalje
- [x] `intl` + `flutter_localizations` podešeni, `lib/src/l10n/app_bs.arb` postoji sa bar pet stvarnih stringova i generiše se u build koraku
- [x] `main.dart` više ne drži placeholder ekran; `TenantConfig` iz `tenants.g.dart` se čita kroz provider, ne direktno u widgetu
- [x] `melos run analyze` i `melos run test` prolaze; postojeći `tenant_theme_test.dart` i dalje prolazi za oba tenanta

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

---

## Status (2026-09-11) — ✅ zatvoren

Oba app-a imaju kičmu: env, bootstrap, Supabase klijent, router i (klijent) lokalizacije.
Ekrani se i dalje ne pišu — sve rute imaju placeholder tijela, kako task i traži.

**Dokaz** — `melos run analyze` čist u svih 5 paketa, `dart format --set-exit-if-changed`
bez izmjena, `melos run test`: **44 testa PASS** (core_domain 13, client 21, core_api 5,
admin 4, core_ui 1). `app_env_test.dart` se dodatno pokreće sa
`--dart-define=SALON_ID=<uuid>` i prolazi.

Web dio je dokazan u **pravom Chromiumu** nad `flutter build web` artefaktom, ne u widget
testu: `/book/slot`, `/appointments/abc-123` i `/team` otvoreni direktno zadržavaju putanju
i prikazuju **svoj** ekran, a browser Back sa `/services` vraća na `/`.

**Dvije greške koje je našao samo browser**

Obje su prošle kroz zelenu test suite, i obje su izgledale ispravno na prvi pogled:

1. **Prazna bijela stranica.** `AppEnv.fromDefines()` je tražio i `SUPABASE_*` vrijednosti,
   pa je web build sa ispravnim `SALON_ID`-om bacao prije `runApp` — bez ijedne poruke.
   Widget testovi to nisu mogli uhvatiti jer svi ubacuju env kroz override i nikad ne pozovu
   pravi `fromDefines()`. Sad je obavezan samo `SALON_ID`; regresija je pokrivena
   `app_env_test.dart`-om, koji se pokreće sa stvarnim define-om.
2. **Deep link tiho nije radio.** `/book/slot` je otvarao početnu dok je URL i dalje pisao
   `/book/slot`. Dva nezavisna uzroka: `initialLocation` nadjačava URL iz adresne trake, i
   Flutter web bez `usePathUrlStrategy()` vraća `defaultRouteName == '/'`. Oba popravljena,
   oba pokrivena testom koji postavlja `defaultRouteNameTestValue`.

**Nusproizvod:** `tenant_theme_test.dart` više ne traži `--dart-define` i **ne skipuje se** —
env ulazi kroz `appEnvProvider`, pa test sam bira tenanta i pokriva **oba**, uključujući
tamnu temu gdje se neusklađenost jedino i vidi.

**Ostalo za sljedećeg**

- **`riverpod_generator` nije uveden**, iako ga DoD spominje. Providera je devet i svi su
  trivijalni; `build_runner` bi bio treći generator u repou (uz `gen_flavors` i `gen-l10n`)
  bez ijednog `.g.dart` fajla koji bi opravdao korak u buildu. Uvesti kad broj providera
  poraste — tada je to jedna izmjena, ne prepisivanje.
- **Supabase se diže, ali nije pozvan protiv pravog backenda.** Nema naloga, pa nema URL-a
  ni ključa; `x-salon-id` je dokazan kao **postavljen u `Supabase.initialize`**, ne kao
  primljen na serveru. Prvi pravi poziv ide uz task 08.
- **`.arb` ima šest stringova i lanac je dokazan** (obrisan `generated/`, build ga vratio),
  ali ih nijedan ekran još ne koristi — placeholderi ih nemaju gdje prikazati. Prvi stvarni
  `AppLocalizations.of(context)` poziv dolazi sa ekranima u tasku 10.
- **Admin nema `SALON_ID` ni `x-salon-id`** i to je namjerno (ADR-0003). Kad admin dobije
  prave upite, provjeri da nijedan ne zavisi od konteksta koji admin nema.
