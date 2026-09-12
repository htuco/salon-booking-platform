# Trenutni task: 12 — Supabase Auth provideri + `AuthConfig` po flavoru

Puni task: [`tasks/sprint-2/12-auth-provideri.md`](sprint-2/12-auth-provideri.md) · **U toku** ·
Učitano: 2026-09-12 · Grana: `feat/auth-provideri`, PR [#20](https://github.com/htuco/salon-booking-platform/pull/20)

## Status

Prvi task Sprinta 2 i početak lanca **12 → 13 → 14** koji zatvara ono što task 11 nije mogao:
`book_appointment` traži `customerId`, a klijent ne postoji dok nema prijave.

Zavisnost ([07 — app plumbing](sprint-1/07-app-plumbing.md)) je ✅: `bootstrap()` diže
`Supabase.initialize`, `AppEnv` čita define-ove, `build_tenant.sh` već prosljeđuje
`SUPABASE_URL`/`SUPABASE_ANON_KEY`/`API_URL`.

## Ciljevi

Kod je gotov i dokazan. **Ostalo je samo ono što traži tuđe konzole** — v.
[`12-konzole-checklist.md`](sprint-2/12-konzole-checklist.md).

- [ ] Provideri uključeni u Supabase konzoli: **Apple, Google, Email OTP** (bez lozinke)
      — čeka tebe, checklist §3
- [ ] Google/Apple client ID-evi upisani u Supabase i u GitHub `vars` — checklist §1, §2, §4
- [x] `AuthProvider` enum + `AuthConfig` sa filtriranjem po platformi — **odlučeno: `core_domain`
      sa vlastitim `AuthPlatform` enumom**, [ADR-0007](../docs/adr/0007-authconfig-u-core-domain.md)
- [x] `AuthRepository` ugovor u `core_api` po [`docs/06 §6.3`](../docs/06-auth-login-flow.md) —
      nijedan Supabase tip ne prelazi granicu; vraća `AuthSession`, greške su `ApiError`
- [x] Google client ID **po flavoru** kao `--dart-define` kroz `build_tenant.sh`, uz postojeća tri
- [x] Redirect URL po flavoru (`ba.nasadomena.<flavor>://login-callback`) — u `config.toml`,
      dokazano u pokrenutom stacku; u konzoli hostovanog projekta ostaje tebi
- [x] `supabase/config.toml` — lokalni auth podešen tako da `supabase start` može testirati OTP
- [x] Unit test: na iOS-u lista sadrži Apple, na Androidu ne
- [x] Nijedna tajna u repou — client ID ide u GitHub `vars`, secret u `secrets`

**Dokazano:** 238 testova PASS (bilo 215), generator pada na pokvarenom `auth.providers`,
`build_tenant.sh` u sve tri grane, i **email OTP odigran do kraja** na lokalnom stacku — kod bez
linka u mailu, `verify` vraća sesiju, `auth_identities` dobija red. Puni dokaz:
[status blok taska 12](sprint-2/12-auth-provideri.md).

**Nije dokazano:** Apple i Google prijava — traže tuđe naloge i **pravi uređaj**, ne mogu se odigrati
ni lokalno ni u simulatoru. `SupabaseAuthRepository` je [task 13](sprint-2/13-client-login-ekran.md);
ovdje je samo ugovor.

## Napomene

**Potvrđeno 2026-09-12:** trigger iz taska 02 **radi** — prva stvarna prijava (email OTP na lokalnom
stacku) je upisala red u `public.auth_identities` sa `providers = {email}` i `last_login_at`. Za
[task 14](sprint-2/14-identitet-i-klijent-upsert.md) stvarno preostaje samo `customers` upsert.

**Dio posla je već u repou, iz taska 02.** `supabase/migrations/20260910090500_auth_identity.sql`
ima trigger `private.sync_auth_identity()` nad `auth.users` koji **već radi upsert u
`auth_identities`** — providere, email, `is_anonymous`, `last_login_at`. To znači da je polovina
onoga što [task 14](sprint-2/14-identitet-i-klijent-upsert.md) nosi u naslovu već gotova; tamo
stvarno preostaje samo `customers` upsert. Provjeriti prije nego se 14 otvori.

**Odlučeno (2026-09-12): `AuthConfig` ide u `core_domain` sa vlastitim enumom platforme.**
Obrazloženje i odbačene opcije: [ADR-0007](../docs/adr/0007-authconfig-u-core-domain.md).
`docs/06 §6.2` je ispravljen u istoj promjeni. Originalni tekst dileme ostaje ispod, jer objašnjava
zašto DoD taska i `docs/06` nisu govorili isto.

**`docs/06 §6.2` skica se ne može kompajlirati kako je napisana.** Stavlja `AuthConfig` u
`core_domain` i filtrira po `TargetPlatform` — ali `core_domain` je od [taska 06](06-vertical-pack.md)
**čist Dart** (`freezed_annotation`, `json_annotation`, `meta`; bez Fluttera), a `TargetPlatform`
je Flutterov tip. Dvije izlazne opcije:

1. `AuthConfig` ostaje u `core_domain`, ali prima **vlastiti enum platforme**; mapiranje
   `TargetPlatform → AuthPlatform` radi sloj iznad. Čuva sloj, košta jedan mali tip.
2. `AuthConfig` seli u `core_api` (ima Flutter). Brže, ali konfiguracija prelazi u sloj koji je do
   sada bio samo transport.

Preporuka je (1) — isti razlog zbog kojeg je `core_domain` uopšte preveden na čist Dart. Bilo koja
se bira, **`docs/06` se ispravlja u istoj promjeni**, jer je danas netačan.

**`AuthRepository` ugovor iz `docs/06 §6.3` je širi od ovog taska** — nosi i `continueAsGuest`
([task 26](sprint-2/26-gost-i-facebook.md)) i `deleteAccount`
([task 17](sprint-2/17-moj-racun-i-brisanje.md)). Ovdje se piše **ugovor**, a implementiraju samo
metode koje 12 i 13 trebaju; ostalo baca `UnimplementedError` sa imenom taska koji ga zatvara.

**Native, ne web-view OAuth** (`docs/06 §6.1`): `signInWithIdToken` uzima nativni ID token od
Applea/Googlea. Web-view flow radi, ali Apple ga ne voli i izgleda jeftino.

**Apple je obavezan na iOS-u** čim postoji ijedan drugi social provider — bez njega App Review
odbija build po pravilu 4.8 (`docs/06 §7.2`).

**Tajne.** `SUPABASE_URL` i `SUPABASE_ANON_KEY` i dalje nisu postavljeni ni lokalno ni u CI-ju
(otvoreno od [taska 04](04-ci-pipeline.md)). Ovaj task dodaje još jednu vrijednost tog tipa —
Google client ID — pa je to trenutak da se kanal za tajne konačno postavi, a ne zaobiđe.

**CI ne može ništa potvrditi** dok naplata na `htuco` nalogu blokira workflowove; dokaz ide lokalno
(`./tool/verify_clean.sh`, `./tool/test_supabase.sh`).

**Procjena ostaje 2 dana**, ali **zavisi od tuđih konzola** — Apple Developer i Google Cloud nalozi
nisu u mojim rukama. Dio DoD-a neće moći biti dokazan bez tebe.

## Istorija

- **11 — Client: booking flow** (2026-09-12, 🟡) — pet ekrana pod `/book/*`, dva prolaza: prvi po tekstu iz `SPEC.md`, drugi **po slikama iz `prototype/ui/`**. Prototip je usput oborio tri odluke: korak 3 je mjesečni kalendar (ne traka datuma, `DateStrip` obrisan), korak 4 je ekran prijave (ne sažetak sa napomenom), success nema konfete. Uz to **odluka da je barber 1:1 sa handoffom** — paleta prepisana znak po znak, copy doslovan, Lucide ikone, pakovani DM Serif Display + Archivo; ostale vertikale dobijaju svoj dizajn. Tokeni promijenjeni **sistemski** (`AppRadius.none` je jedina vrijednost). Dokazano: 215 testova PASS, svih pet ekrana u Chromiumu na 402×874 za oba tenanta, korak 1 i guard na iOS simulatoru ([PR #19](https://github.com/htuco/salon-booking-platform/pull/19)). Slike su našle dvije greške koje testovi nisu mogli: korak 2 je u demou prikazivao grešku (`employeeServiceLinksProvider` bez override-a), a beauty success prazan red (demo termin sa barberovim `serviceId`). **Ostaje 🟡**: `book(...)` nikad nije pozvan protiv prave baze i `409` nije izazvan uživo — oboje traži `Customer` upsert, delegirano u [task 14](sprint-2/14-identitet-i-klijent-upsert.md); fotografije usluga u [22](sprint-2/22-sema-slike-i-staz.md), Početna po handoffu u [18](sprint-2/18-pocetna-i-tab-bar.md).
- **01 — Skeleton repozitorija** (2026-08) — melos workspace, `apps/client`, `apps/admin`, `packages/core_*`, `supabase init`. `melos bootstrap`/`analyze`/`test` prolaze.
- **02 — Supabase šema + RLS** (2026-09-10) — 15 tabela, RLS na svakoj, `private.*` autorizacioni helperi, seed sa dva demo salona i tri vertikale. Dokazano na CI-ju: 38 pgTAP testova + 24 REST asercije sa dva stvarna JWT-a.
- **03 — Flavor sistem** (2026-09-10) — Android i iOS flavori za dva demo tenanta, ikone po flavoru, generatori u `tool/`. Dokazano na artefaktima: `aapt2 dump badging`, oba APK-a na istom emulatoru istovremeno, `CFBundleIdentifier`/`CFBundleDisplayName`/ikona iz gotovog iOS bundlea.
- **04 — CI pipeline** (2026-09-10, 🟡) — `tool/build_tenant.sh` kao jedina ulazna tačka u build, `release-artifacts` job pravi AAB za oba tenanta na ručni trigger, `BUILD_NUMBER` iz CI-ja stiže do artefakta (`versionCode='42'` naspram `'1'`). Ostaju keystore i stvarne Supabase vrijednosti — oboje traži naloge.
- **05 — Availability engine** (2026-09-11) — `get_available_slots`, `get_available_dates`, `book_appointment`, exclusion constraint `appointments_no_overlap`. Dokazano na CI-ju ([run 34542304820](https://github.com/htuco/salon-booking-platform/actions/runs/34542304820)): 66 pgTAP testova PASS. Availability logika je isključivo u bazi — nula u Dartu.
- **06 — VerticalPack** (2026-09-11) — `Vertical`/`VerticalTerms`/`BookingRules`/`VerticalFeatures` u `core_domain` (preveden na čist Dart), `VerticalRepository` u `core_api`, `verticalProvider` u `apps/client`; ekran uzima tekst iz `vertical.terms`. Dokazano na CI-ju ([run 34544339115](https://github.com/htuco/salon-booking-platform/actions/runs/34544339115)) i lokalno: 32 testa PASS, uključujući promjenu terminologije bez rebuilda app-e i parsiranje stvarnog `seed.sql`; uz testove prolaze i oba Android APK-a i oba iOS builda. **Sprint 0 je time gotov.**
- **07 — App plumbing** (2026-09-11) — `AppEnv`/`AdminEnv`, `bootstrap()` sa `Supabase.initialize` i `x-salon-id` headerom, `go_router` u oba app-a po 01 §12, `.arb` lokalizacije. Dokazano: 44 testa PASS plus deep link u pravom Chromiumu nad web artefaktom. Browser je našao dvije greške koje je test suite propustila — praznu bijelu stranicu (env je tražio `SUPABASE_*`) i deep link koji tiho ne radi (`initialLocation` + `usePathUrlStrategy`); obje pokrivene testom.
- **08 — `core_api` modeli i repozitoriji** (2026-09-11) — sedam modela u `core_domain` (odluka: [ADR-0006](../docs/adr/0006-modeli-u-core-domain.md)), pet repozitorija i `sealed ApiError` u `core_api`, svi Riverpod provideri; `supabaseClientProvider` prešao iz app-a u `core_api`. Codegen (`freezed`/`json_serializable`) ulazi prvi put, generisani fajlovi **nisu** u gitu. Dokazano na CI-ju ([Flutter 34620424824](https://github.com/htuco/salon-booking-platform/actions/runs/34620424824), [Supabase tests 34619433879](https://github.com/htuco/salon-booking-platform/actions/runs/34619433879)): 97 testova plus 26 REST asercija **bez korisničkog tokena** — javni katalog stvarno radi prije prijave. CI je uhvatio grešku koju lokalna suita nije: codegen treba svakom jobu koji kompajlira, ne samo `analyze`-u.
- **09 — `core_ui` theme factory** (2026-09-11) — `buildAppTheme` kao jedina funkcija koja pravi `ThemeData`, tokeni (razmaci, radijusi, trajanja, statusne boje kao `ThemeExtension`), šest komponenti, i fallback lanac `salons.primary_color → tenant.yaml → default` u `appThemeProvider`-u; `main.dart` više nema nijedan heks. Generator nosi branding boje u `tenants.g.dart` kao ARGB i validira `#RRGGBB` pri generisanju. Dokazano na CI-ju ([Flutter 34630719984](https://github.com/htuco/salon-booking-platform/actions/runs/34630719984)): **140 testova**, oba APK-a, oba iOS builda. `onPrimary` se bira poređenjem WCAG odnosa, ne pragom luminancije — zlatna `#C6A667` (luminancija 0.42) bi sa naivnim pragom dobila bijeli tekst i 2.6:1. Test u obje teme je našao roze cijenu sa 4.12:1: brand tekst je bio mjeren na `surface`, a kartica stoji na `surfaceContainer`. **Ništa nije pokrenuto na uređaju** — to prvi put traži task 10.
- **10 — Client home sa runtime brandingom** (2026-09-11) — `/` je prvi pravi ekran: hero, usluge, tim, radno vrijeme, kontakt i sticky CTA, sve iz `core_ui` komponenti i isključivo iz providera. **Prvi dokaz slikom**: isti web build, dva `SALON_ID`-a, razlika u imenu, bojama (zlatna tamna naspram roze svijetle) i terminologiji ("Zakaži termin" naspram "Rezerviši termin") — `docs/screenshots/task-10-home-*.png`. Dokazano na CI-ju ([run 34637330417](https://github.com/htuco/salon-booking-platform/actions/runs/34637330417)): 165 testova PASS (bilo 140), čista analiza, oba Android APK-a i oba iOS builda. Screenshot je našao grešku koju nijedan test nije mogao: živi status je bio `StatusBadge(tone: info)`, a statusne boje su brand-neutralne, pa je plava mrlja stajala preko oba brenda — sada ide u `primaryContainer`. Kontrast test je usput ispravljen na dva mjesta gdje je mjerio pogrešne parove (tekst na obojenoj površini, CTA usred Material prelaza — 2.13:1 na dugmetu koje je 8.07:1). **Ništa nije pokrenuto na uređaju i nijedan podatak nije došao sa stvarnog backenda** — `demo_main.dart` ih nosi prepisane iz `seed.sql`.
