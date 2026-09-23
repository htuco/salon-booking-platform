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

- **`core_domain`** — entiteti (`Salon`, `Service`, `Appointment`, `Vertical`), vrijednosni tipovi
  i pravila. Bez Fluttera i bez mreže — to je i u `pubspec.yaml`-u: paket nema `flutter` zavisnost
  i testovi mu idu na `package:test`. Čim uđe `flutter`, sloj prestaje biti upotrebljiv iz čistog
  Dart konteksta i smjer zavisnosti se tiho obrne. `freezed_annotation` i `json_annotation` su
  čist Dart i to pravilo ne krše.
- **`core_api`** — Supabase repozitoriji, mapiranje grešaka, Riverpod provideri. Jedini sloj koji
  zna za HTTP i tabele. **Modeli nisu ovdje nego u `core_domain`** i nose `fromJson` — obrazloženje
  i odbačene opcije: [ADR-0006](../../docs/adr/0006-modeli-u-core-domain.md).
- **`core_ui`** — design system: tokeni, tema, komponente. Ne zna za repozitorije ni za modele —
  komponente primaju gotove stringove ("45 min", "25 KM"). Formatiranje zna ekran, koji jedini
  poznaje jezik i vertikalu.

  **`apps/admin` ga namjerno ne uvozi** (provjereno u tasku 23, kad je admin dobio prve ekrane).
  `core_ui` nosi oblik brandirane klijentske vitrine — serif naslovi, hairline granice, „← Početna"
  umjesto `AppBar`-a, tema po tenantu iz `tenant.yaml`. Admin je generička alatka za rad, jedan
  build za sve salone. Dijeljenje bi značilo da svaka promjena brendiranog oblika povlači admin
  ekran koji sa brendom nema veze.

  Od taska 28 admin ima **svoju** temu u `apps/admin/lib/src/core/theme/`, po handoffu u
  `prototype/admin/`. Zabrana uvoza više nije samo dogovor: `no_hardcoded_colors_test.dart` pada
  ako se `core_ui` pojavi u uvozu ili u `pubspec.yaml`-u admina.
- **`apps/*`** — feature-first folderi (`lib/src/features/<feature>/`) plus `lib/src/core/`
  (`env`, `router`, `theme`, u adminu i `navigation` i `widgets`) i `lib/src/l10n/`. Feature folder drži ekran, njegove privatne
  widgete u `widgets/` i logiku koja ne pripada ni domenu ni UI-ju — formatiranje cijene i
  vremena (zna jezik), izračun koji bi se inače sakrio u `build`. `features/home/` je prvi takav
  i uzor za ostale.

### Admin ljuska: jedna lista odredišta, dvije ljuske

Od taska 29 `apps/admin/lib/src/core/navigation/admin_destinations.dart` drži **jedinu** listu
navigacije. Iz nje se crta i tamni sidebar na desktopu i donja navigacija na telefonu; prelaz je u
`AdminScaffold` na `AdminBreakpoint.desktop` (840). Prve tri stavke su ćelije telefona, ostalih pet
su rep koji stoji iza „Još" (`/more`) — **rep iste liste, ne druga lista**, pa modul dodan u
navigaciju ne može ostati dostupan samo na jednoj širini.

Dvije posljedice koje se lako prekrše:

- **Svaki admin ekran stoji u `AdminScaffold`**, uključujući placeholder rute. Vlastiti `Scaffold`
  znači ekran bez navigacije, a otkad navigacija nudi i nenapisane module, to je slijepa ulica.
- **Ekran i dalje prosljeđuje `aktivna`**, ne čita rutu iz `GoRouterState`. Kad ekranu treba nešto
  iz adrese — kao filter statusa na `/appointments?status=pending` — čita ga **route builder** i
  predaje kao argument konstruktora. Tako ekran ostaje podiziv u widget testu bez pravog routera.

Ovo je folder navigacije, ne sloj: smije uvesti feature providere (brojač zahtjeva), isto kao što
router uvozi svaki feature ekran.

Poštuj smjer zavisnosti gore: `core_domain` ne smije uvesti `core_api`, a `core_ui` ne smije uvesti
nijedan repozitorij.

**Nijedan `freezed` model ne smije imati `List` polje.** `freezed` 3.2.5 za takvo polje generiše
`final` na **imenovanom** parametru konstruktora, što aktuelni Dart odbija (`extraneous_modifier`),
pa paket prestane da se kompajlira. Vrijedi za svaki oblik — sa `@Default`, bez njega, nullable.
Dok se generator ne podigne na 4.x, lista ide mimo modela: `salons.gallery_urls` zato čita
`SalonRepository.galleryUrls`, a ne polje na `Salon`-u.

### Tema je runtime podatak, ne konstanta

`buildAppTheme(primary, secondary, themeName)` u `core_ui/src/theme/theme_factory.dart` je **jedina**
funkcija koja pravi `ThemeData` **u klijentskoj app-i**. Boje su joj ulaz, jer ih vlasnik salona
mijenja iz admin aplikacije i promjena mora stići bez novog builda.

Admin je obrnut slučaj i ima **svoju** takvu funkciju, `buildAdminTheme()` u
`apps/admin/lib/src/core/theme/admin_theme.dart` (task 28). Prima samo `Brightness`: admin je jedan
build za sve salone, ali prati sistemski light/dark mode. Paleta je platformska, ne boja salona.
Klijent kontrast računa u runtime-u (`contrast.dart`), jer brand boju bira vlasnik; admin obje
fiksne varijante mjeri **u testu**.

Do boje se dolazi lancem, u `apps/client/lib/src/core/theme_provider.dart`:

```
salons.primary_color (backend)  →  TenantConfig iz tenants.g.dart  →  podrazumijevana paleta
```

Prva dva koraka su razlog zašto `tenant.yaml` uopšte nosi boje: `salonProvider` je `FutureProvider`,
pa je prvi frame uvijek bez odgovora. Da tema čeka mrežu, app bi se otvorila u Flutterovoj svijetloj
temi i tek onda skočila u tenant paletu — na tamnom barberu je to bijeli bljesak preko cijelog
ekrana. Zato se korak 1 uzima kroz `valueOrNull`, a koraci 2–3 su sinhroni.

Posljedica: boje u `tenant.yaml` moraju biti iste kao red u `salons`. Kad se raziđu, baza je u pravu,
ali korisnik vidi treptaj boje na startu.

**Kontrast se računa, ne pogađa.** `onPrimary` bira `onColorFor` poređenjem stvarnih WCAG odnosa, a
ne pragom luminancije — vlasnik smije izabrati žutu, a bijeli tekst na njoj je nečitljiv
(`docs/02 §14`). Statusne boje (potvrđeno/otkazano) namjerno stoje **van** `ColorScheme`-a, u
`ThemeExtension`-u, da se ne stope sa brand bojom salona koji izabere zelenu.

### Dva pravila koja `core_api` čuva

1. **Van paketa ne izlazi `Map`.** Repozitorij vraća model iz `core_domain` ili baca; sirovi red
   ne prelazi granicu.
2. **Van paketa ne izlazi `PostgrestException`.** Sve greške prolaze kroz `mapError` i izlaze kao
   `ApiError` — `sealed`, pa `switch` nad njim Dart provjerava na iscrpnost. Ekran razlikuje
   `NetworkError`, `NotFoundError`, `ConflictError`, `ServerError` i `MappingError`; booking flow
   bez te razlike ne zna da li ponuditi "pokušaj ponovo" ili osvježenu listu termina.

`ConflictError` je konflikt iz `book_appointment` i exclusion constraint
`appointments_no_overlap` (task 05). Stiže kao **`PT409`**, ne kao `409`: funkcija ga diže sa
`errcode = 'PT409'`, Postgres klasu `PT` prevodi u HTTP status iz zadnja tri znaka, pa je odgovor
`409` — ali `PostgrestException.code` nosi `PT409`. Isto vrijedi za `PT404` (usluga ne postoji ili
nije aktivna), koji je `NotFoundError`. `NotFoundError` namjerno pokriva i "red ne postoji" i "RLS
ga ne propušta" — razlika između to dvoje je curenje podatka o tuđem tenantu.

### Vremena nisu `DateTime`

`working_hours`, `blocked_slots` i `appointments` drže Postgresov `time` i `date` — **lokalno zidno
vrijeme salona**, bez zone. `core_domain` ih čita u `LocalTime` i `LocalDate`, koji namjerno nemaju
konverziju u trenutak: `DateTime.parse('09:00:00')` daje vrijeme po zoni **uređaja**, a jedan
`toUtc()` na tome pomjeri radno vrijeme salona za sat ili dva. Jedini `DateTime` u modelima je
`Appointment.pendingExpiresAt`, jer je `timestamptz` i jeste stvarni trenutak.

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

16 tabela u `public`, sve sa RLS-om, plus `private` shema sa autorizacionim helperima. Grupe:

- **Platforma:** `vertical_packs`, `salons`, `salon_builds`, `users`
- **Katalog salona:** `services`, `employees`, `employee_services`, `working_hours`, `salon_settings`
- **Ljudi i uređaji:** `auth_identities` (globalno), `customers` (per-salon), `devices`
- **Rad:** `appointments`, `blocked_slots`, `notification_logs`
- **Sadržaj salona:** `reviews` (+ pogled `salon_rating_summary`)

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

**Signal osvježava, ne donosi podatke.** `availability_signals` nosi samo `(salon_id, revision_id)`,
a trigger ga rotira na promjenu `services`, `employees`, `employee_services`, `working_hours`,
`appointments`, `blocked_slots` i `salon_settings`. Klijent na taj događaj **invalidira providere**
i ponovo čita tipizirani repozitorij; iz Realtime mape se nikad ne gradi drugi izvor istine.

Koje providere — to je lista koja se lako zaboravi proširiti. `SalonClientApp` na signal invalidira
`availableSlotsProvider`, `servicesProvider`, `employeesProvider`, `employeeServiceLinksProvider` i
**`salonSettingsProvider`** (task 36).
Do taska 32 je bio samo prvi, i to se nije vidjelo jer se katalog nije mogao mijenjati u radu:
`servicesProvider` nema `autoDispose`, pa je živio koliko i proces, a klijent je staru cijenu vidio
dok ne ubije aplikaciju. **Ista greška se ponovila sa postavkama**: trigger je `salon_settings`
pratio od taska 26, ali ih niko nije mogao promijeniti u radu dok task 36 nije napisao `/settings` —
pa bi klijent nudio otkazivanje po **starom** roku, a `cancel_appointment` vratio `PT403`.
**Novi provider koji čita nešto što trigger prati mora ući u ovu listu**, inače se ista greška
ponavlja tiho — drži je `apps/client/test/catalog_refresh_test.dart`.

`salonProvider` (kontakt podaci iz `salons`) **namjerno nije u listi**: trigger ne stoji nad
`salons`, pa bi invalidacija bila red koji se nikad ne izvrši. Ako promijenjen telefon ikad zatreba
odmah, dodaje se tabela u trigger, ne provider u ovu listu.

**Admin modul piše kroz `rpc`, uz jedan namjeran izuzetak.** `services`, `employees`,
`working_hours`, `blocked_slots`, `appointments`, `salons` i `salon_settings` imaju samo `select`
grant za `authenticated`; pisanje ide kroz `security definer` funkcije koje nose validaciju.
**`salon_policies` je izuzetak** — `staff_manage` daje CRUD uz grant, jer mimo `check` constrainta
koji već stoje nema šta da se validira, pa bi funkcija bila prosljeđivanje koje sakriva politiku.
`app_policies` se iz admina ne dira uopšte (ADR-0009). Zašto tako i čime je dokazano:
`.claude/docs/security.md`.

Autorizacija, grantovi i ono što još nije zatvoreno: `.claude/docs/security.md`.

## Edge Functions i cron

`supabase/functions/<ime>/index.ts`, Deno. `delete-account` i `send-push` imaju implementaciju;
podsjetnici i ostali planirani poslovi još su stubovi:

| Funkcija | Okidač | Šta radi |
|---|---|---|
| `send-push` | `pg_cron`, svake minute, kroz `private.dispatch_push` | FCM HTTP v1, preuzima i ažurira `notification_logs` |
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
- **Booking pravila vertikale su samo početna vrijednost** (task 44). Salon ih poslije mijenja u
  admin Postavkama, a to piše `salon_settings` — isti red koji baza provodi. Klijent zato čita
  `salonSettingsProvider` prvo i pada na `vertical.rules` samo dok postavke ne stignu
  (`bookingDateOnlyProvider`, `bookingRequiresStaffChoiceProvider`, `bookingMaxAdvanceDaysProvider`,
  `minCancelHoursProvider`). Cijene traže oba: `features.prices` vertikale **i**
  `show_prices_in_app` salona (`prikaziCijeneProvider`).

## Dizajn (`prototype/ui/`) i wireframe (`prototype/`)

**`prototype/ui/`** je vizuelni izvor istine: dizajnerski handoff sa 17 ekrana u punoj vjernosti,
finalnim copyjem na bosanskom i popisanim tokenima (`prototype/ui/SPEC.md`). Ekran u Flutteru se piše
po njemu.

Podjela pri prevođenju u kod je ono što ga čini upotrebljivim u white-label sistemu:
**oblik je platformski** (tipografska skala, spacing ritam, radius 0, hairline granice umjesto
sjenki, oblik komponenti) i živi u `core_ui`; **boja je po tenantu** i dolazi iz `tenant.yaml`
kroz `buildAppTheme()`; **tekst je po vertikali** i dolazi iz `vertical.terms`. Hex iz handoffa je
paleta jednog brenda, ne konstanta sistema.

**`prototype/`** je stariji React wireframe (Vite + Tailwind + Radix, rute u
`prototype/wireframe/src/app/routes.tsx` prate `docs/01 §12`) sa **svojim** toolchainom u istom folderu.
**Zamrznut je** — služio je da se flow vidi prije prvog Dart fajla, a tu ulogu je preuzeo
`prototype/ui/`. Ostaje referenca za flow i rute. Gdje se njih dvoje ne slažu, `prototype/ui/` je jači.

Root `package.json` drži samo `lefthook` (git hookovi za cijeli repo) i ne miješa se sa
toolchainom prototipa.

## Šta još ne postoji

Da ne tražiš uzalud: nema Next.js konzole, nema pravog FCM-a i nema nijednog **pravog ekrana** —
sve rute imaju placeholder tijela dok ih ne napišu taskovi 10 i 11.
Stanje po tasku: `tasks/sprint-<N>/README.md`, indeks u `tasks/README.md`.

Postoji od taska 06: `Vertical` u `core_domain` i `VerticalRepository` u `core_api`.
Od taska 07: `AppEnv`/`AdminEnv`, `bootstrapClient()`/`bootstrapAdmin()` sa `Supabase.initialize`,
`go_router` u oba app-a i `.arb` lokalizacije u klijentu.
Od taska 08: modeli javnog kataloga u `core_domain`, pet repozitorija i `ApiError` u `core_api`, i
svi Riverpod provideri — uključujući `supabaseClientProvider` i `verticalProvider`, koji su se iz
`apps/client` preselili u `core_api`. Aplikacija vezuje svoj `SALON_ID` kroz
`currentSalonIdProvider.overrideWith(...)`; bez tog override-a repozitorij baca
`UnimplementedError` na prvom pozivu.

Od taska 09: `core_ui` više nije skeleton — `buildAppTheme`, tokeni (razmaci, radijusi, trajanja,
statusne boje) i šest komponenti (`AppButton`, `ServiceCard`, `TimeSlotChip`, `StatusBadge`,
`EmptyState`, `SkeletonLoader`). Klijent temu uzima iz `appThemeProvider`-a; `main.dart` više nema
nijedan heks.

Od taska 11: `BookingRepository` u `core_api` — **prvi i jedini repozitorij koji piše u bazu**.
Sve tri metode su `rpc`, nijedna `from(...)`: slobodni termini se ne mogu pročitati (slot je
odsustvo termina, a `appointments` nema politiku za `anon`), a rezervacija mora re-validirati slot
u istoj transakciji. Uz njega `AvailableSlot` u `core_domain` i `BookingFlowState` u
`apps/client/lib/src/features/booking/` — jedan provider za sva četiri koraka, bez keširane liste
slotova.

Od taska 12: auth konfiguracija — `AuthConfig`, `AuthProvider`, `AuthPlatform` i `AuthSession` u
`core_domain`, `AuthRepository` ugovor i `authPlatformOf` u `core_api`, `authConfigProvider` i
`visibleAuthProvidersProvider` u klijentu. **Ugovor, ne implementacija** — implementaciju donosi
task 13.

Od taska 13: `SupabaseAuthRepository` i `CustomerRepository` u `core_api`, `features/auth/` u
klijentu (`LoginScreen` + `LoginController` sa tri faze: provideri → email → kod). Prijava je
**dio booking flowa, ne zaseban ekran** — handoff nema login ekran nego korak 4, pa `/auth/login`
nosi istu karticu „Čuvamo vam" i vraća korisnika na `?from=`.

Dvije posljedice koje se ne vide iz potpisa:

- **Login ekran mora sam držati `bookingFlowProvider`** (`ref.watch` na nivou ekrana). Provider je
  `autoDispose`; kad je jedini slušalac bio vidljivi widget, prelazak na unos emaila je brisao
  izbor i korisnik se vraćao na prazan korak 4. Isto vrijedi za svaki sljedeći ekran koji flow
  napusti pa se u njega vrati.
- **Iz `core_api` ne izlazi nijedan `AuthException`.** `mapError` ga razlaže na `AuthRejectedError`
  (pogrešan ili istekao kod), `RateLimitError` (čekanje) i `NetworkError` — razlika je ono što
  korisnik može uraditi, a `sealed ApiError` čini `switch` u ekranu iscrpnim.

Od taska 14: `public.ensure_customer` — **drugi i zadnji upis iz klijentske app-e**, uz
`book_appointment`. `CustomerRepository.ensureCustomer` ga zove, `currentCustomerIdProvider` ga
veže za sesiju. Identitet izvodi baza iz JWT-a; klijent šalje samo salon, koji se mora poklopiti
sa `x-salon-id` headerom (`.claude/docs/security.md`).

Od taska 16: `AppointmentRepository` u `core_api` — **prvi repozitorij nad `appointments`**, jer
klijent do auth rada nije mogao pročitati nijedan red. Čitanje je `from(...)` (ograničava ga RLS),
otkazivanje je `rpc` (`cancel_appointment`, treći i zadnji upis iz app-e). `AppDialog` u `core_ui`
je modal 5p; `features/appointments/` nosi ekran i razvrstavanje.

**Razvrstavanje na „predstojeće" i „prošle" je u aplikaciji, ne u upitu.** Granica je *sada*, koje
se pomjera između dva otvaranja ekrana, a upit koji bi vraćao samo buduće bi morao znati zonu
salona. Uz to zatvoren termin (`cancelled`, `completed`, `no_show`) ide u „prošle" bez obzira na
datum — korisnik na njega ne dolazi.

`bookingCustomerIdProvider` je zbog toga **`FutureProvider`, ne sinhroni snimak**. Kao snimak je
`null` značio dvije stvari — „nema klijenta" i „zahtjev je još u letu" — pa je korisnik koji
dodirne „Pošalji zahtjev" odmah nakon prijave dobijao grešku iako je red već nastao. Slanje sada
`await`-a taj isti poziv.

Lista providera je podatak iz `tenant.yaml` (`auth.providers`), koji kroz generator ulazi u
`tenants.g.dart`, pa kroz `AuthConfig.fromNames` do ekrana. Domen nosi **vlastiti** enum platforme
umjesto Flutterovog `TargetPlatform`, jer je `core_domain` čist Dart —
[ADR-0007](../../docs/adr/0007-authconfig-u-core-domain.md).

**Availability logika ostaje isključivo u bazi.** Dart ne filtrira slotove, ne sabira buffer i ne
računa trajanje; `BookingRepository` samo mapira gotov odgovor. Metoda koja bi primila listu
termina i vratila slobodna vremena ovdje ne postoji i neće — to je druga implementacija pravila
koja zastarijeva čim se pravilo promijeni u migraciji.

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

### Stablo ruta klijenta ima dva sprata

Od taska 18 `apps/client/lib/src/core/router/app_router.dart` dijeli sve rute na dvije vrste:

- **`StatefulShellRoute.indexedStack`** nosi pet grana donje navigacije — Usluge, Termini,
  **Početna** (u sredini), Obavijesti, Postavke. Okvir je `ClientShell` (`client_shell.dart`),
  koji drži `AppBottomNav` iz `core_ui`. Svaka grana ima **svoj `Navigator`**, pa tab pamti gdje
  je korisnik stao; ponovni tap na aktivnu ćeliju vraća granu na njen korijen
  (`goBranch(initialLocation: true)`).
- **Sve izvan shella** je pushed ekran **bez trake**, sa back headerom: cijeli `/book/*`,
  `/auth/login`, `/account`.

Pod-ekran koji po handoffu zadržava traku ide kao **podruta grane**, ne kao zasebna ruta —
`/about` i `/team` su djeca `/`, `/appointments/:id` je dijete `/appointments`.

Podjela je u putanjama, a ne u `if`-u unutar ekrana, iz jednog razloga: ekran koji sam odlučuje
hoće li nacrtati traku je ekran koji će jednom odlučiti pogrešno. Zamka je pri tome ista kao kod
`initialLocation` — `StatefulShellRoute` mijenja oblik stabla, pa deep link u granu mora ostati
dokazan (`router_test.dart`, `client_shell_test.dart`).

`x-salon-id` se postavlja **jednom**, na klijentu, a ne u repozitorijima: zaboravljen header ne
daje grešku nego prazan rezultat. Admin app ga ne šalje — v. `ADR-0003` i `.claude/docs/security.md`.

## Kako podaci stižu do ekrana

```
Postgres (RLS)  →  repozitorij  →  FutureProvider  →  ref.watch  →  widget
                   core_api         core_api          ekran
```

Ekran **nikad ne zove repozitorij**. `ref.watch(salonProvider)` je cijeli njegov pristup podacima;
repozitorij i `SupabaseClient` postoje ispod providera i ekran ne zna za njih. Test time dobija
jednu tačku presretanja — override providera — umjesto lažiranja PostgREST-a.

Tri pravila koja je uspostavio prvi ekran (`features/home/`, task 10):

- **Svaki izvor se čita zasebno i nijedan ne blokira ostale.** Salon koji se prikazao dok čeka
  listu usluga je upotrebljiv; ekran koji čeka sve odjednom je prazan onoliko dugo koliko traje
  najsporiji upit.
- **Tri stanja prije sretnog slučaja.** Skeleton (ne spinner), greška sa retryjem koji stvarno
  ponavlja upit (`ref.invalidate`), i sakrivena sekcija umjesto praznog naslova.
- **Sekcija se sakriva i kad njen upit padne**, ne samo kad je prazna. Ekran čija je glavna svrha
  dugme "Zakaži" ne smije pasti zato što katalog nije stigao.

Tekst ima dva izvora i granica je stroga: ono što se mijenja po vertikali ide kroz
`vertical.terms` (CTA, imena sekcija), a ono što je isto u svakoj kroz `.arb` (dani, greške,
dugmad). Literal u ekranu ne pripada nijednom.

**Sekcija koju crtaju dva ekrana živi izvan oba.** Priču salona, par fotografija, radno vrijeme i
kontakt nose i Početna (inline) i `/about` — `features/about/about_sections.dart` ih drži kao javne
widgete, a oba ekrana ih samo slažu. Kopija u drugom ekranu bi se razišla pri prvoj izmjeni, i
razlika bi se vidjela tek na onom ekranu koji niko nije otvorio.

**Vizuelni dokaz bez backenda**: `apps/client/lib/demo_main.dart` je alternativni entry point koji
puni iste providere podacima iz `supabase/seed.sql`. Nije production kod — store build ide kroz
`lib/main.dart` — ali dozvoljava da se ekran otvori i snimi na mašini bez Supabase pristupa
(`flutter run -d chrome -t lib/demo_main.dart --dart-define=SALON_ID=…`).

## Pravni tekst: dvije tabele, jedan ekran, tri sloja (task 21)

`features/legal/` nosi `/terms`, `/privacy` i `/about-app`. Prva dva su **jedan widget**
(`PolicyDocumentScreen`) sa `PolicyDocument` parametrom: razlikuju se samo naslovom i providerom,
a dvije kopije bi se razišle pri prvoj izmjeni — na ekranu na kojem se razlika ne primijeti dok je
neko ne pročita.

Slojevi su uobičajeni, ali podjela posla među njima nije očigledna:

- **`core_domain`** drži `PolicySection`, `PolicyDocument` i `applyPolicyPlaceholders`. Zamjena
  `{minCancelHours}` je čista funkcija nad stringom, pa se testira bez Fluttera i bez mreže.
- **`core_api`** ima `PolicyRepository` i `mergePolicySections`. Spajanje dvije tabele u jedan
  redoslijed živi ovdje, ne u ekranu: PostgREST ne radi `union`, pa su to dva paralelna upita čiji
  redoslijed dolaska ne smije odlučiti redoslijed sekcija.
- **`apps/client`** samo numeriše i crta. **Broj sekcije nije podatak** — to je pozicija u listi.

`policyPlaceholdersProvider` je namjerno **sinhron** `Provider` nad `valueOrNull` triju asinhronih
izvora (salon, postavke, vertikala). Da čeka `Future.wait`, pad jednog upita srušio bi cijeli
pravni ekran; ovako neriješen izvor ostavi placeholder vidljivim i dopuni tekst kad podatak stigne.
To je izuzetak od „svaki izvor se čita zasebno" samo naizgled — isto pravilo, primijenjeno na
provider koji sastavlja, a ne na ekran.

`/notifications` (`features/notifications/`) je **samo prazno stanje** dok task 25 ne donese
klijentsku politiku nad `notification_logs`. Ruta i ulaz iz trake već postoje, pa se tada mijenja
samo tijelo.


## Admin piše u bazu samo kroz `rpc` (task 24)

`StaffAppointmentRepository` je do taska 23 bio namjerno samo čitanje. Task 24 mu je dopisao akcije
i **sve su `rpc` pozivi** — ne zbog stila nego zato što drugog puta više nema: ista migracija je
oduzela `insert` i `update` grant roli `authenticated` nad `appointments`. Direktan
`from('appointments').update(...)` odatle vraća `42501`.

To je razlika u odnosu na `BookingRepository`, koji je bio „jedini repozitorij koji piše": sada
pišu dva, ali **oba samo kroz validirane funkcije**. Pravilo se time nije oslabilo nego učvrstilo —
prije je bilo konvencija koju je bilo dovoljno zaboraviti, sada je grant.

Tri funkcije koje pišu termin: `book_appointment` (nov termin, klijent i ručni admin unos),
`set_appointment_status` (`confirmed` / `completed` / `no_show`) i `cancel_appointment`
(`cancelled`, sa rokom koji obavezuje klijenta a ne salon). Detalji i granice:
`.claude/docs/security.md`.

### `Customer` model nastaje tek ovdje

Klijentska app do sada nije trebala ništa osim `customers.id`, pa `CustomerRepository` barata golim
`String`-om — i to je i dalje ispravno za njega. **Admin je prvi kome treba red, a ne ključ**: pri
ručnom unosu salon pretražuje svoj adresar po imenu i telefonu i vidi brojače posjeta.

`Customer.isWalkin` (`auth_identity_id == null`) razlikuje telefonskog klijenta od onog sa nalogom.
Isti čovjek u dva salona su **dva reda** sa odvojenim brojačima, i to je uslov izolacije, ne
nedostatak.

Task 35 mu je dodao i repozitorij: `StaffCustomerRepository` (`core_api/src/catalog/`) je admin
strana `customers`, odvojena od klijentskog `CustomerRepository`-ja iz istog razloga kao
`StaffAppointmentRepository` — klijentski se oslanja na `x-salon-id` iz `SALON_ID` flavora, a admin
app taj header nema i ne smije ga imati (ADR-0003).

**Taj repozitorij samo čita, iako grant dozvoljava pisanje.** To je jedini staff repozitorij kod
kojeg pravilo „samo kroz `rpc`" ne drži grant nego odluka: `customers` je zadržala `insert`/`update`
(task 24 ga je ostavio da salon ispravi ime), ali ručni unos ide kroz `upsert_walkin_customer`, koji
uz upis radi normalizaciju telefona i `on conflict do update`. Razlog stoji u `security.md`, jer je
ovo mjesto gdje bi sljedeća izmjena lako dopisala `insert`.

## Kalendar dana: podatak odvojen od crtanja (task 31)

`/calendar` je prvi admin ekran koji **ne prikazuje listu reda po red** nego dvodimenzionalan
raspored, pa mu je model izdvojen iz widgeta: `apps/admin/lib/src/features/calendar/calendar_day.dart`
je čista funkcija nad terminima, radnim vremenom i blokadama, bez ijednog `import`-a Fluttera u
svojoj logici. Isti razlog kao `dashboard_summary.dart`: blok na pogrešnom mjestu na osi izgleda
tačno kao blok na pravom.

**Jedan model, dva čitanja.** `izgradiDan()` daje osu i kolonu po radniku (desktop `3c`),
`redoviKolone()` jednu kolonu izravna u listu jednog radnika, `redoviDana()` cijeli dan u listu svih
(telefon `3l`). Spajanje pogleda „po radniku" i „po vremenu" je zamka koju je task 31 naslijedio od
availability enginea — `get_available_slots` vraća red po radniku, i svako miješanje daje ili
duplikate ili izgubljene termine.

**Vrijeme na osi je `int` minuta od ponoći.** Ne `DateTime` i ne `LocalTime`: osa je linija od 0 do
1440 i sve na njoj je oduzimanje. `DateTime` bi u tu aritmetiku uveo zonu i ljetno računanje vremena,
kojih u rasporedu salona nema.

**`BlockedSlot` i `BlockedSlotRepository` su nastali ovdje.** `public.blocked_slots` postoji od init
migracije, ali je do ovog taska bila čitana isključivo iz SQL-a (`get_available_slots`, admin
akcije). Klijentu blokada nije podatak nego odsustvo slota; adminu jeste, jer kalendar koji je ne
crta pokazuje prazninu tamo gdje je vlasnik svjesno zatvorio vrijeme. Repozitorij **samo čita**, i
razlog nije grant nego podjela poslova — v. doc klase.

### Admin ne smije koristiti `servicesProvider` ni `employeesProvider`

Ti provideri čitaju `currentSalonIdProvider`, koji klijentska app override-uje iz `SALON_ID`
flavora. **Admin app ga nema i ne smije ga imati** — jedna je za sve salone (ADR-0003), a
neoverride-ovan provider baca `UnimplementedError` tek pri otvaranju ekrana, ne pri kompajliranju.

Zato `apps/admin` ima svoje `adminServicesProvider`, `adminEmployeesProvider` i
`adminEmployeeLinksProvider`, koji salon uzimaju iz `adminSalonIdProvider` (tj. iz
`StaffMember.salonId`). Svaki sljedeći admin ekran koji treba katalog ide istim putem.
## Osoblje i historija (task 33)

`EmployeeRepository.forSalon` podrazumijevano čita aktivni katalog. Admin koristi
`includeInactive: true` pod postojećim RLS-om radi editora i historije, a izbor radnika za
novi termin dodatno isključuje neaktivne. `EmployeeActions` jednim RPC pozivom snima profil
i usluge i invalidira admin katalog/veze; status je zasebna potvrđena radnja.
Editor ne prihvata stare veze dok traje refresh. Smjene čita iz postojećeg provider-a
radnog vremena i `workingHoursFor`, bez računanja availability u ekranu.

`Appointment.employeeName` je snapshot, pa klijentska historija ne zavisi od aktivnog
kataloga. Admin kartica/detalj daje prednost snapshotu, uz fallback za stariji backend.
Router čita auth stanje kroz `ref.read`; `refreshListenable` ponavlja guard bez
rekonstrukcije routera i gubitka direktne adrese pri asinhronom učitavanju članstva.

## Push životni ciklus

`core_api/src/push/` drži registraciju instalacije i FCM životni ciklus, zajednički za oba app-a.
`DeviceRepository` čuva tajnu u secure storage i piše samo kroz RPC; `PushService` serijalizuje
token refresh, promjene sesije i odjavu. `bookingDeviceIdProvider` čeka registraciju i vraća
pravi `devices.id`. Podrazumijevano isključen `PUSH_ENABLED` čuva razvoj bez Firebase konfiguracije.

Firebase Core/Messaging su jedini Firebase pluginovi; Supabase i dalje radi autentikaciju.
App sluša typed tokove i navigira vlastitim routerom na `/appointments`. `opened` nosi samo salon
ID, `received` nosi `PushMessage` — salon, `notification_id` i tekst koji je backend poslao, bez
ličnih podataka.

Foreground prikaz je asimetričan po platformi i to je namjerno. iOS crta obavijest sam, jer
`PushService` uključi `setForegroundNotificationPresentationOptions`. Android to ne radi, pa
`ForegroundNotifications` (klijent) šalje poruku kroz MethodChannel `MainActivity`-ju, koji je
crta na kanalu `appointment_updates` — istom koji manifest daje FCM-u kao default, da korisnik
ima jednu sistemsku postavku. Zato `ForegroundNotifications.show` odmah izlazi na iOS-u; bez toga
bi se ista obavijest pojavila dvaput.
Client koristi build salon, admin članstvo. Worker uzima događaje iz baze i dobija kratkotrajni
Vault HMAC kroz cron, bez klijentskog pozivanja funkcije za slanje. Operativni ugovor:
`supabase/functions/send-push/README.md`.
