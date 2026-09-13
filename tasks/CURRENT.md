# Trenutni task: 19 — Client: „O nama" i „Usluge"

Puni task: [`tasks/sprint-2/19-o-nama-i-usluge.md`](sprint-2/19-o-nama-i-usluge.md) ·
**U toku** · Učitano: 2026-09-13 · Pokrenuto: 2026-09-13

## Status

U toku. Grana `feat/o-nama-i-usluge`, otvorena sa svježeg `main`-a.

**Zavisnost 18 je zatvorena.** [PR #29](https://github.com/htuco/salon-booking-platform/pull/29) je
mergeovan 2026-09-13, pa `/about` i `/services` postoje na `main`-u kao `PlaceholderScreen`. Blok
koji je ovdje stajao — „18 nije mergeovan, kreni sa njegove grane" — bio je zastario i obrisan je.

**Prije nego što se piše `/services`, treba mergeovati
[PR #30](https://github.com/htuco/salon-booking-platform/pull/30).** Popravka sortiranja
(`.order(ascending: true)`) je izvađena u svoj PR i **nije u ovoj grani**. Dok ne uđe, katalog
stiže silazno i grupisanje po kategoriji će izgledati slomljeno bez razloga — tačno zamka koju su
Napomene ispod predviđale. Kad #30 uđe: `git rebase origin/main`.

**Tenant Studio Maestro je u stashu**, ne u grani: `git stash list` → „tenant Studio Maestro —
cijeli flavor, assets, seed i assets/ podrška u heroju (čeka svoj PR)". Tu je i jedina stvar koja
`assets/…` fotografije pušta u hero. Ne primjenjuj ga u ovoj grani; ima svoj PR.

Ovaj task **ne blokira nikoga**, ali nosi rupu koju je 18 napravio — v. Ciljevi.

## Ciljevi

- [ ] `/services` po `09-usluge.png`: pun cjenovnik, **grupisan po `category`**, tap vodi pravo u
      booking sa preselektovanom uslugom
- [ ] `/about` po `02-o-nama.png`: priča salona, par fotografija, radno vrijeme, kontakt, mreže
- [ ] **Vratiti radno vrijeme i kontakt u aplikaciju** — danas ih nema nigdje (v. Napomene)
- [ ] Oba ekrana rade bez prijave
- [ ] Screenshot uz oba referentna PNG-a

## Napomene

### Rupa koju je ostavio task 18 — ovo je pravi razlog zašto 19 ide sljedeći

Task 18 je **skinuo radno vrijeme i kontakt sa Početne**, jer ih `SPEC.md` 5b drži na „O nama".
Taj ekran ne postoji, pa su ta dva podatka **trenutno nedostupna u cijeloj aplikaciji** — salon
nema gdje pokazati kad radi ni gdje se nalazi. To nije stilska zaostavština nego regresija koju je
18 svjesno uveo uz obećanje da je 19 zatvara.

Ako 19 kasni, jeftina zakrpa je vratiti jednu sekciju na Početnu; skuplja je pustiti da stoji.

### Šta već postoji, a šta je obrisano

**Postoji i čeka:**

- **Rute su tu.** `/services` je ćelija tab bara (Usluge aktivna), `/about` je podruta Početne
  (`SPEC.md` 5b: „tab bar, Početna active"). Oba su danas `PlaceholderScreen`.
- **`working_hours_card.dart` i `contact_card.dart`** su netaknuti — ali su **bez ijednog
  korisnika** otkad ih je 18 skinuo sa Početne. Analizator ne viče jer su javni widgeti.
- **`SalonSchedule`** (`features/home/salon_schedule.dart`) računa sedmicu i živi status.
- **`SelectableRow`** je tačan oblik reda cjenovnika (76 px foto, naziv, trajanje, cijena u serifu).
- **`?serviceId=` preselekcija je već podržana** u routeru od taska 11 — `/services` samo treba
  `context.go('/book/service?serviceId=…')`.
- **Svi `.arb` stringovi**: `dayMonday`…`daySunday`, `dayMondayFriday`, `workingHours`, `contact`,
  `location`, `call`, `openInMaps`, `instagram`, `facebook`, `closed`.

**Obrisano i mora se pisati ponovo:** logika sekcija je bila u `home_screen.dart` i otišla je sa
prepisom — koji kontakt red se crta, `vertical.features.socialLinks` gating, mapiranje broja dana u
ime, grupisanje „Ponedjeljak – Petak". Widgeti su ostali, **pamet nije**.

### Grupisanje po kategoriji — zamka koju task fajl spominje, plus jedna koju ne

Task kaže: kategorija je **slobodan tekst, ne enum** — salon je mijenja iz admina, pa sortiranje
mora podnijeti praznu i nepoznatu vrijednost.

Ono što task ne kaže, a našlo se pri pravljenju tenanta Studio Maestro:

- **`.order()` u `postgrest`-u podrazumijeva SILAZNO.** Tri repozitorija su ga zvala bez
  `ascending:`, pa je katalog stizao naopako. Popravljeno u
  [PR #30](https://github.com/htuco/salon-booking-platform/pull/30) — dokazano protiv živog stacka
  (radno vrijeme je vraćalo `[7,6,5,4,3,2,1]`). **Nije u ovoj grani dok se #30 ne mergeuje.**
- **Ni ispravan redoslijed nije dobar redoslijed** — sada i izmjereno. Uzlazno po kategoriji pa
  imenu, Studio Maestro počinje sa „Brada · Brijanje britvom", „Brada · Oblikovanje brade" i
  „Njega · Pranje i styling"; salon bi u izlog htio „Šišanje". **`services` nema kolonu za ručni
  redoslijed.** Za `/services` je to podnošljivo (vidi se cijela lista), ali je isti podatak
  presudan na Početnoj, koja pokazuje samo tri. Ako se rješava, to je `sort_order` migracija.

### Fotografije za „par fotografija" na `/about`

`02-o-nama.png` traži par slika. Podaci postoje: `salonGalleryProvider` (task 18) čita
`salons.gallery_urls`. Oba demo salona ga imaju prazan, pa se sekcija **sakriva** — isto pravilo
kao na Početnoj. Studio Maestro ima dvije slike, pa se na njemu i vidi.

### Procjena

Task kaže 1–2 dana i to stoji. `/services` je kraći i prvi (dokazuje grupisanje); `/about` je
uglavnom sastavljanje komponenti koje već postoje.

## Istorija

- **22 — Šema: fotografije usluga i staž radnika** (2026-09-12, ✅) — `services.image_url` i `employees.experience_years`, obje nullable jer su prazan okvir i red bez staža **predviđena stanja**: salon bez fotografija mora raditi od prvog dana. Seed puni obje kolone i namjerno ostavlja po jedan red prazan (Brada bez slike, Lejla bez staža), da se to stanje vidi u demou a ne tek kod prvog klijenta. Korak 1 prosljeđuje `imageUrl`, korak 2 spaja titulu i staž kroz ICU plural — iz prave baze: „Barber · 9 godina" i „Barber · 4 godine", oba bosanska oblika tačna. Dokazano: **29 asercija javnog kataloga bez tokena** (bilo 26; grantovi su tabelarni pa nova kolona ulazi sama, ali to se ne vidi iz migracije — vidi se iz poziva bez tokena), 66 pgTAP testova, 242 Dart testa. **Zamka koju je našao browser:** prvi snimak koraka 1 je pokazao četiri prazna okvira, jer se `images.demo.invalid` ne razrješava — red sa URL-om izgleda isto kao red bez njega, pa taj snimak ne dokazuje ništa. Dokaz je napravljen privremenim usmjeravanjem jednog reda na sliku koja stvarno postoji, pa vraćanjem; `seed.sql` nije mijenjan.

- **16 — Client: „Moji termini" + otkazivanje** (2026-09-12, ✅) — `/appointments` po handoffu 5h: dva taba, kartica sa statusom, otkazivanje kroz modal 5p (`AppDialog` u `core_ui` — blur, scrim, destruktivna akcija gore). `AppointmentRepository` postoji prvi put, jer klijent do auth rada nije mogao pročitati nijedan `appointments` red. `cancel_appointment` uzima rok iz `salon_settings.min_cancel_hours` i pamti `cancelled_by`; **rok vrijedi za klijenta, ne za salon** — salon otkazuje kad mora. Odigrano u browseru protiv živog stacka: prijava, rezervacija 22.09. u 13:00, otkazivanje; `cancelled_by = customer`, termin prešao u „Prošle", i **slot odmah opet slobodan** — provjereno `get_available_slots` upitom, ne pretpostavkom. Dokazano: **97 pgTAP testova** (bilo 82), **276 Dart testova** (bilo 256), 12 novih widget testova. pgTAP je usput našao da ista NULL rupa iz taska 14 stoji i u `book_appointment` od taska 05 — **nije curenje i nikad nije bilo**, jer je `owns_identity` FALSE za tuđeg klijenta a `NULL and FALSE` je FALSE (provjereno pokretanjem), ali je zatvorena kroz `create or replace` nad doslovnim tijelom iz taska 05. I da je moj vlastiti test tvrdio pogrešno: direktan `update` sa klijenta ne baca `42501` nego RLS pogodi nula redova, što u Postgresu nije greška.

- **15 — Dokaz izolacije: isti klijent u dva salona** (2026-09-12, ✅) — `rest_cross_salon_isolation.ts`, **22 asercije i tri stvarna JWT-a**: jedan čovjek se prijavi i rezerviše u oba demo salona, pa se mjeri šta ko vidi. Admin salona A ne dobija red salona B ni po `id`, ni po `auth_identity_id` — koji **zna**, jer stoji u njegovom vlastitom redu — ni kroz imenovani embed na `appointments`, ni kad `x-salon-id` postavi na salon B. **Provjereno da test može pasti**: `staff_manage` bez veze sa salonom reda („admin bilo gdje ⇒ admin svugdje") obori aserciju o admin pogledu, `own_customer` bez `client_salon_id()` obori aserciju o klijentu; obje vraćene i provjerene naspram migracije kroz `pg_policy`. Usput nađeno da kompozitni FK-ovi čine embed dvosmislenim (`PGRST201`, HTTP **300**), pa REST testovi moraju tretirati `300` kao grešku — inače prođe kao uspjeh i test pukne kasnije, na mjestu koje ne govori šta je stvarno vraćeno. Puna suita: **82 pgTAP testa, 92 REST asercije**.

- **14 — `AuthIdentity` + `Customer` upsert** (2026-09-12, ✅) — `public.ensure_customer` je drugi i zadnji upis iz klijentske app-e, uz `book_appointment`: identitet izvodi iz tokena (nikad iz argumenta), salon mora doći iz `x-salon-id`, `on conflict do nothing` da drugi poziv ne prepiše ime koje je salon ispravio. **Termin je prvi put stvarno nastao iz aplikacije** — `pending`, 16.09. 10:00–10:40, Emir, Fade — i **`409` je izazvan uživo**: slot zauzet izvana, ekran vraćen na korak 3 sa osvježenom listom u kojoj je zauzeti prozor nestao. Time padaju dvije 🟡 stavke iz [taska 11](sprint-1/11-booking-flow.md). Dokazano: **82 pgTAP testa** (bilo 66), **70 REST asercija** u tri Deno testa, **256 Dart testova**. Tri greške koje testovi i browser nađu a čitanje ne: `not (A and B)` je rupa kad `B` može biti `NULL` — zahtjev bez `x-salon-id` headera je prolazio kroz guard; `revoke ... from public` ne skida `execute` jer ga Supabase daje `anon`-u direktno kroz `pg_default_acl`, i isti propust je stajao na `book_appointment` od taska 05; i sinhroni snimak `customerId`-a je davao grešku dok je upsert bio u letu, jer `null` nije razlikovao „nema klijenta" od „još nije stigao". Zamka zapisana u `workflows.md`: **`supabase db reset` ne učitava `config.toml`**, pa auth template ostaje stari i OTP mail stigne kao engleski magic link.

- **13 — Client: login ekran na kraju booking flowa** (2026-09-12, 🟡) — `/auth/login` dobio pravo tijelo: `SupabaseAuthRepository` u `core_api` (email OTP kroz `signInWithOtp`/`verifyOTP`), `CustomerRepository` koji čita `customers` pod `own_customer`, `AuthRejectedError`/`RateLimitError` da pogrešan kod više ne izlazi kao „nešto je pošlo naopako", `LoginScreen` sa tri faze i `?from=` povratkom koji se provjerava naspram `ClientRoute` liste (inače open redirect na webu). Dokazano: **253 testa PASS** (bilo 238) i **email OTP odigran do kraja u Chromiumu protiv živog Supabase stacka** — četiri prijave, četiri `auth_identities` reda, mail sa šest cifara i bez ijednog linka. **Browser je našao dvije greške koje testovi nisu**: prijava je brisala izbor iz flowa (`bookingFlowProvider` je `autoDispose`, a kartica „Čuvamo vam" — jedini slušalac — crta se samo u fazi izbora providera), i sam test je držao vlastitu pretplatu pa bi prolazio i nad pokvarenom app-om; oboje popravljeno, uz provjeru da test sada **može** pasti. **Ostaje 🟡**: Apple i Google traže pakete kojih nema u `pubspec.yaml` i konzole iz [taska 12](sprint-2/12-konzole-checklist.md), a `customers` je i dalje 0 — red pravi [task 14](sprint-2/14-identitet-i-klijent-upsert.md).

- **12 — Supabase Auth provideri + `AuthConfig` po flavoru** (2026-09-12, 🟡) — `AuthProvider`/`AuthPlatform`/`AuthConfig`/`AuthSession` u `core_domain` ([ADR-0007](../docs/adr/0007-authconfig-u-core-domain.md): vlastiti enum platforme, jer je `core_domain` čist Dart), `AuthRepository` ugovor u `core_api`, `auth:` blok u `tenant.yaml` sa validacijom u generatoru, Google client ID po flavoru kroz `build_tenant.sh`, redirect URL-ovi i OTP template u `supabase/config.toml`. Dokazano: **238 testova PASS** (bilo 215) i **email OTP odigran do kraja** na lokalnom stacku — kod bez linka u mailu, `verify` vraća sesiju, `auth_identities` dobija red (time je prvi put dokazan i trigger iz taska 02). **Ostaje 🟡**: Apple i Google prijava nisu odigrane nijednom — traže tuđe konzole i pravi uređaj, hodogram je [`12-konzole-checklist.md`](sprint-2/12-konzole-checklist.md).

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
