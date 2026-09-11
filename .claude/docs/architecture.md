# Arhitektura

Kako je sistem složen i gdje šta živi. Proizvodna specifikacija je u `docs/01`–`docs/07` i ostaje
izvor istine za *šta* se gradi; ovaj dokument opisuje *kako je repo složen danas* i šta iz toga
slijedi za svaku promjenu.

## Sistem u jednoj rečenici

Jedan Flutter codebase proizvodi N brandiranih klijentskih aplikacija i jednu generičku admin
aplikaciju; svi govore sa jednim Supabase projektom u kojem RLS drži salone razdvojene; Firebase
postoji isključivo za FCM push.

**Ključna asimetrija:** klijentska app je brandirana do detalja, admin app je generička za sve
salone. Vlasnik ne mari kako mu izgleda admin — mari kako izgleda ono što njegov klijent vidi.
Zato flavor sistem postoji samo u `apps/client`.

## Slojevi

```
apps/client   (N flavora)        apps/admin  (jedna)        Next.js konzola (još ne postoji)
      └──────────────┬───────────────────┘                          │
                packages/core_ui                                    │
                packages/core_api   ← jedini sloj koji zna za mrežu  │
                packages/core_domain                                │
                             └──────────── Supabase ────────────────┘
                                    Postgres + RLS · Auth · Storage · Edge · pg_cron
                                                  │
                                            Firebase FCM (samo push)
```

- **`core_domain`** — entiteti, `Vertical`, formatiranje. Bez Fluttera i bez mreže — to je i u
  `pubspec.yaml`-u: paket nema `flutter` zavisnost i testovi mu idu na `package:test`. Čim uđe
  `flutter`, sloj prestaje biti upotrebljiv iz čistog Dart konteksta i smjer zavisnosti se tiho
  obrne.
- **`core_api`** — Supabase repozitoriji, modeli, greške. Jedini sloj koji zna za HTTP i tabele.
- **`core_ui`** — design system: tokeni, tema, komponente. Ne zna za repozitorije.
- **`apps/*`** — feature-first folderi (`lib/src/features/<feature>/`) plus `lib/src/core/`
  (`env`, `router`, `theme`) i `lib/src/l10n/`.

Danas su svi `core_*` prazni skeletoni, a `apps/*` imaju samo placeholder ekran — Sprint 0 dokazuje
infrastrukturu, a ne piše ekrane. Kad pišeš prvi pravi kod, poštuj smjer zavisnosti gore:
`core_domain` ne smije uvesti `core_api`, a `core_ui` ne smije uvesti nijedan repozitorij.

## Flutter monorepo

Dart native pub workspace (SDK `^3.13.0`) sa Melosom 7. Melos ≥7 **nema** `melos.yaml` ni
`pubspec_overrides.yaml` — sve je u root `pubspec.yaml`: `workspace:` lista paketa i `melos:` ključ
sa skriptama.

`workspace:` **ne podržava globove**, pa je lista eksplicitna. Novi paket u `apps/` ili `packages/`
mora se dodati ručno — inače ga `melos exec` preskoči, i ni analiza ni testovi ga ne pokrivaju, a
ništa ne pada.

Lint je jedan: root `analysis_options.yaml` koji svaki paket uključuje relativnom putanjom
`../../analysis_options.yaml` (svi su na istoj dubini). `analyzer: exclude` **ostaje po paketu** —
`android/`, `ios/`, `web/` postoje samo u `apps/*`.

## Kako tenant stiže do aplikacije

```
tenants/<flavor>/tenant.yaml
        │  dart run tool/gen_flavors.dart
        ├─→ Gradle productFlavors        (apps/client/android/app/build.gradle.kts, između markera)
        ├─→ google-services.json         (placeholder, po flavoru)
        ├─→ iOS xcconfig                 (apps/client/ios/flavors/<flavor>.xcconfig)
        └─→ Dart registar                (apps/client/lib/src/generated/tenants.g.dart)
                │  tool/gen_ios_flavors.sh
                └─→ Xcode konfiguracije Debug/Profile/Release-<flavor> + scheme

flutter build --flavor <flavor> --dart-define=SALON_ID=<uuid>
        └─→ main.dart čita SALON_ID → kTenants[salonId] → ime, vertikala, fallback boje
```

`SALON_ID` je jedini `--dart-define`. Sve ostalo se traži u registru po tom UUID-u, pa dodavanje
polja u `tenant.yaml` ne mijenja build komandu. Puni detalji, zamke i store korak:
`.claude/docs/tenant-factory.md`.

Runtime izvor istine je **backend** — vrijednosti iz `tenant.yaml` su fallback dostupan prije prvog
odgovora, da nema bijelog flasha.

## Supabase

15 tabela u `public`, sve sa RLS-om, plus `private` shema sa autorizacionim helperima. Grupe:

- **Platforma:** `vertical_packs`, `salons`, `salon_builds`, `users`
- **Katalog salona:** `services`, `employees`, `employee_services`, `working_hours`, `salon_settings`
- **Ljudi i uređaji:** `auth_identities` (globalno), `customers` (per-salon), `devices`
- **Rad:** `appointments`, `blocked_slots`, `notification_logs`

Dvije stvari koje se lako previde:

- **Identitet je dvoslojan.** `auth_identities` je jedna osoba na platformi i sinhronizuje se
  triggerom sa `auth.users`; `customers` je ta osoba **u jednom salonu**. Per-salon je namjerno —
  salon ne smije vidjeti da klijent ide i kod konkurencije.
- **`devices.device_id` nije `appointments.device_id`.** Prvo je instalacioni identifikator,
  drugo je FK na `devices.id`. Zamjena mjesta prolazi tipove i tiho slomi push.

Vrijeme: `working_hours` koristi ISO dane 1=ponedjeljak…7=nedjelja, a `date`/`start_time`/`end_time`
su **lokalno zidno vrijeme salona** (`timezone` default `Europe/Sarajevo`), ne UTC.

`appointments` je u `supabase_realtime` publikaciji; Realtime poštuje SELECT RLS, pa klijent kroz
socket dobija tačno ono što bi dobio i kroz REST.

Autorizacija, grantovi i ono što još nije zatvoreno: `.claude/docs/security.md`.

## Edge Functions i cron

`supabase/functions/<ime>/index.ts`, Deno. Danas su to README stubovi:

| Funkcija | Okidač | Šta radi |
|---|---|---|
| `send-push` | poziv iz druge funkcije/trigera | FCM HTTP v1, piše `notification_logs` |
| `expire-pending` | `pg_cron`, ~15 min | `pending` stariji od `pendingExpiryHours` → `cancelled` |
| `send-reminders` | `pg_cron`, dnevno + po satu | D-1 i H-3 podsjetnici, provjerava log prije slanja |
| `dental-recall` | `pg_cron`, sedmično | recall za dentalnu vertikalu |

`pg_cron` raspored se registruje **u migraciji**, ne rukom u dashboardu — inače nije reproducibilan
između okruženja.

## Dostupnost je backend logika

Availability algoritam (`docs/01 §8.1`) živi na backendu i **nikad u aplikaciji**. Aplikacija
prikazuje listu koju dobije. Razlog je operativan, ne estetski: verzije na telefonima kasne
mjesecima, pa je pogrešna availability logika u app-u bug koji se ne može hotfixati.

Backend **ponovo validira** slot pri kreiranju termina — između čitanja liste i slanja zahtjeva
prođe dovoljno vremena da neko drugi uzme isti slot. Odgovor je `409`, a app kaže "termin je
upravo zauzet".

Konkretno, u `20260911090000_availability_engine.sql`:

| Funkcija | Za šta |
|---|---|
| `get_available_slots(salon, usluga, datum, radnik?)` | slobodna vremena početka, jedan red po (vrijeme, radnik) |
| `get_available_dates(salon, usluga, od, do, radnik?)` | datumi sa bar jednim slotom — za `date_only` vertikale |
| `book_appointment(...)` | kreira `pending` termin uz re-validaciju; `PT409` → HTTP 409 |

Uz njih ide exclusion constraint `appointments_no_overlap`: dva aktivna termina istog radnika se
ne mogu preklopiti ni kad zahtjevi stignu istovremeno. Provjera prije upisa i constraint koriste
**istu formulu** za zauzeti interval (`[početak, kraj + buffer)`) — inače bi lista nudila slot koji
constraint odbija.

## Vertikale

Vertikala je red u bazi i config, **nikad grana u kodu**. Nosi terminologiju, default booking
pravila, feature flagove, temu i tražene pristanke. Pravilo bez izuzetka: nijedan string koji se
razlikuje po vertikali ne smije stajati u `.dart` fajlu ekrana — takav string se ne može promijeniti
bez store submissiona. Detalji i tabela terminologije: `docs/05-vertical-packs.md`.

Put od baze do ekrana:

```
vertical_packs + salons.terminology_override   (jedan upit, embed po FK-u)
        │  VerticalRepository            packages/core_api
        │  verticalProvider              apps/client/lib/src/core/
        ▼  verticalOf(ref)               → Vertical, nikad null
Text(vertical.terms.bookCta)
```

Dvije odluke koje se ne vide iz potpisa:

- **Override se sloji po ključu**, ne zamjenom objekta. Salon koji mijenja samo
  `customerSingular` ("Klijentica") mora zadržati ostatak vertikalne terminologije.
- **Parsiranje nikad ne baca.** Nepoznat `key`, ključ koji nedostaje i vrijednost pogrešnog tipa
  padaju na generic default, jer je app u storeu uvijek starija od baze — vertikala dodana
  migracijom ne smije srušiti ekran.

## Web prototip (`src/`)

React + Vite + Tailwind + Radix, rute u `src/app/routes.tsx` prate `docs/01 §12`. Svrha mu je da se
flow i vizual vide prije prvog Dart fajla. **Nije production kod**; kad ekran pređe u Flutter,
prototip ostaje kao referenca, ne kao druga implementacija koju treba održavati.

Poznata mrtva težina koju treba ukloniti (`docs/07 §2`): `@mui/*` i `@emotion/*` su u
`package.json` bez ijednog importa u `src/`.

## Šta još ne postoji

Da ne tražiš uzalud: nema Next.js konzole, nema teme u `core_ui`, nema pravog FCM-a i nema
nijednog **pravog ekrana** — sve rute imaju placeholder tijela dok ih ne napišu taskovi 10 i 11.
Stanje po tasku: `tasks/README.md`.

Postoji od taska 06: `VerticalRepository` u `core_api`, `verticalProvider` u `apps/client`.
Od taska 07: `AppEnv`/`AdminEnv`, `bootstrapClient()`/`bootstrapAdmin()` sa `Supabase.initialize`,
`go_router` u oba app-a i `.arb` lokalizacije u klijentu.

## Kičma aplikacije

```
main()
  └─ bootstrapClient()          apps/client/lib/src/core/env/
       ├─ usePathUrlStrategy()  bez ovoga web deep link tiho ne radi
       ├─ AppEnv.fromDefines()  pada samo na SALON_ID; SUPABASE_* su opcioni
       └─ Supabase.initialize(headers: {'x-salon-id': …})
  └─ ProviderScope(overrides: [appEnvProvider.overrideWithValue(env)])
       └─ MaterialApp.router(routerConfig: appRouterProvider)
```

Tri odluke koje se ne vide iz potpisa:

- **`AppEnv` ulazi kroz override, ne kroz globalnu varijablu.** Test tako podiže app sa svojim
  okruženjem, bez `--dart-define`-a i bez mreže; zato `tenant_theme_test` više ne traži define
  i pokriva oba tenanta umjesto da se skipuje.
- **Obavezan je samo `SALON_ID`.** Bez Supabase vrijednosti klijent se ne diže i app radi na
  fallbacku — to je ono što `flutter run` bez backenda i web preview trebaju. Dok su bile
  obavezne, web build je padao prije `runApp` i davao praznu bijelu stranicu bez poruke.
- **Nema `initialLocation`.** Na webu nadjačava URL iz adresne trake, pa deep link tiho ne radi
  dok URL izgleda ispravno. Admin umjesto njega ima redirect sa `/` na `/login`.

`x-salon-id` se postavlja **jednom**, na klijentu, a ne u repozitorijima: zaboravljen header ne
daje grešku nego prazan rezultat. Admin app ga ne šalje — v. `ADR-0003` i `.claude/docs/security.md`.
