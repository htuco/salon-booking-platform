# Trenutni task: 17 — Client: „Moj račun", postavke i brisanje računa

Puni task: [`tasks/sprint-2/17-moj-racun-i-brisanje.md`](sprint-2/17-moj-racun-i-brisanje.md) ·
**U toku** · Učitano: 2026-09-13 · Grana: `feat/moj-racun-i-brisanje`

## Status

U toku. Grana `feat/moj-racun-i-brisanje` otvorena sa svježeg `main`-a.

**Zavisnost 13 je 🟡, ali ne blokira.** Traži je task fajl, a 13 je otvoren samo zbog Apple i
Google prijave; email OTP radi i dokazan je uživo. Za „Moj račun" je to dovoljno — ekran treba
prijavljenog korisnika, ne određenog providera. **Jedan izuzetak: Apple token revoke** (`docs/06`
§8.2) se ne može ni napisati ni dokazati dok Apple prijave nema. To ide u 🟡, ne u „gotovo".

**Task 19 je mergeovan** ([PR #33](https://github.com/htuco/salon-booking-platform/pull/33)) —
ovo nije stacked grana. Jedan njegov commit (`e91c6b6`, osvježeni snimci i status blok) je ostao
van `main`-a jer je napisan nakon mergea; ide zasebnim PR-om, ne kroz ovaj task.

## Odluka na početku: 17 uzima i `/settings`

Donesena prije prve izmjene, jer mijenja doseg i procjenu. Detalji u Napomenama, „Rupa koju task
fajl ne vidi".

`/settings` (handoff 5k) **ulazi u ovaj task**. Bez njega `/account` nema ulaz iz aplikacije, a
ekran za brisanje naloga koji se ne može otvoriti ne prolazi Apple review — što je jedini razlog
zašto task postoji. Uz to 5k ionako nosi „odjavu" koju DoD traži.

**Procjena 1–2 dana iz task fajla time pada.** Task nosi RPC, Edge Function i dva ekrana.

## Ciljevi

- [ ] RPC za brisanje: soft-delete identiteta (`deleted_at`) + anonimizacija `customers` reda
- [ ] `auth.admin.deleteUser` kroz Edge Function — klijent nema service role ključ
- [ ] **Ekran `/settings` po `11-postavke.png`** (5k): profil, obavijesti, jezik, o aplikaciji,
      odjava, i red „Moj račun ›" — ovo je ulaz do `/account`
- [ ] Ekran `/account`: podaci identiteta i brisanje naloga
- [ ] Brisanje traži potvrdu koja **objašnjava šta ostaje**, ne samo „jeste li sigurni"
- [ ] Nakon brisanja app se vraća u javno stanje, bez zaostalog tokena
- [ ] Deno test: obrisan identitet više ne može čitati svoje termine
- [ ] Budući `confirmed` termini se otkazuju (push vlasniku je task 25)
- [ ] Ispravi komentar u `app_router.dart` uz `settings` — tvrdi da ekran pravi task 21, a ne pravi

## Napomene

### Šema je već napola uradila ovaj task

Ovo je nalaz koji mijenja procjenu. `auth_identities.deleted_at` **postoji od init migracije**
(task 02), i — što je važnije — **gate je već ušiven na svim mjestima**:

| Gdje | Šta radi |
|---|---|
| `private.owns_identity` | `... and deleted_at is null` |
| politika `own_identity` (`auth_identities`) | `... and deleted_at is null` |
| politika `own_customer` (`customers`) | kroz `owns_identity` |
| politika `own_appointments` (`appointments`) | kroz `owns_identity` |
| trigger `auth_identity` (`20260910090500`) | upsert samo `where deleted_at is null` |
| `public.ensure_customer` (task 14) | `ai.deleted_at is null` |

Posljedica: **sam upis `deleted_at` gasi pristup svemu.** DoD stavka „obrisan identitet više ne
može čitati svoje termine" bi trebala proći bez ijedne nove politike — ali to je **hipoteza dok
Deno test ne prođe**, a ne razlog da se test preskoči. Trigger je ovdje najzanimljiviji: bez
`where deleted_at is null` bi sljedeća prijava istim mailom uskrsnula obrisani nalog.

### Ugovor postoji, tijelo ne

`AuthRepository.deleteAccount()` je deklarisan od taska 12, a `SupabaseAuthRepository` ga baca kao
`ServerError` sa porukom koja pokazuje na ovaj task
(`supabase_auth_repository.dart:99`). Ekran ga smije zvati odmah — greška je već `ApiError`, ne
`UnimplementedError`, pa ne ruši ekran.

### Rupa koju task fajl ne vidi: `/account` nema ulaz

Isto što je task 19 našao za `/about`, i ovdje stoji. **Riješeno odlukom gore: 5k ulazi u 17.**

- Task fajl kaže „`/account` po handoffu **5k**". **5k je Postavke, ne Moj račun.** Router iz taska
  18 ih razdvaja: `settings('/settings', 'Postavke')` je ćelija trake i nosi 5k, a
  `account('/account', 'Moj račun')` je pushed ekran ispod njega.
- **`/settings` je `PlaceholderScreen`** i **nijedan task ga ne preuzima**. Provjereno, ne
  pretpostavljeno: komentar u `app_router.dart:226` tvrdi „Ekran pravi task 21", ali DoD taska 21
  nabraja samo `/notifications`, `/about-app` i `/terms` — Postavki nema. Komentar je pogrešan i
  ispravlja se u ovom tasku.
- Dok `/settings` ne postoji, `/account` je nedostupan iz aplikacije. Ekran za brisanje naloga koji
  se ne može otvoriti **ne prolazi Apple review** — a to je jedini razlog zašto ovaj task postoji.

### `auth.admin.deleteUser` traži Edge Function

`docs/06` §8.2 traži `auth.admin.deleteUser`, a to je admin API: radi samo sa service role ključem,
koji **nikad ne smije u klijentsku app**. Znači Edge Function. Obrazac već postoji —
`supabase/functions/` ima `expire-pending`, `send-push`, `send-reminders`, `dental-recall`.

Redoslijed koji ima smisla: **RPC prvi** (soft-delete + anonimizacija, `security definer`, identitet
iz tokena — obrazac je `ensure_customer`), pa Edge Function koja ga zove i tek onda briše
`auth.users` red. Obrnuto ostavlja siroče ako drugi korak padne.

### Šta se anonimizira, a šta ostaje

`customers` nosi `name text not null`, `phone`, `note`. Brisanje naloga **nije** brisanje podataka
salona — termin je i salonov zapis. Anonimizuju se `name`, `phone` i `note`; red, `visit_count`,
`no_show_count` i svi `appointments` ostaju.

Zamka: `name` je `not null`, pa anonimizacija mora upisati nešto (npr. „Obrisan klijent"), ne
`NULL`. I `unique(salon_id, phone)` znači da `phone` mora ići na `NULL`, a ne na neku konstantu —
druga anonimizacija u istom salonu bi pala na unique.

### Apple token revoke ostaje 🟡

`docs/06` §8.2 ga izričito traži. Apple prijava nije implementirana (task 12 🟡, traži pakete i
konzole), pa se revoke ne može ni napisati ni dokazati. Piše se kao nedokazano, sa pokazivačem na
[`12-konzole-checklist.md`](sprint-2/12-konzole-checklist.md).

### Procjena

Task fajl kaže 1–2 dana. **Ne stoji** — `/settings` je odlukom ušao u doseg, a Edge Function i
drugi ekran nisu bili u toj računici. Šema je dala više nego što task pretpostavlja (gate je
ušiven), ali to ne pokriva razliku.

## Istorija

- **19 — Client: „O nama" i „Usluge"** (2026-09-13, ✅) — `/services` je pun cjenovnik **grupisan po `category`**, sa zaglavljima samo kad ima šta da se grupiše: jedna kategorija (ili nijedna) daje ravnu listu, tačno kao `09-usluge.png`. Razvrstavanje radi čista funkcija `groupByCategory`, koja **ne sortira ponovo** — `ServiceRepository.forSalon` već vraća uzlazno, a drugo sortiranje bi bilo dva izvora istine za isti poredak. **`SPEC.md` 5b ne završava na `/about`:** prvi prolaz je ekran napisao po handoffu i ostavio ga iza reda „O nama ›" na dnu Početne, a pregled na simulatoru je pokazao šta to znači — priča, radno vrijeme i kontakt stoje jedan tap dalje, na ekranu kojem handoff **nijednim nacrtanim ekranom ne daje ulaz**. Sadržaj je zato inline na Početnoj (priča iznad cjenovnika, radno vrijeme i kontakt na dnu), `/about` ostaje kao ruta i oblik iz handoffa, a sekcije dijele obje strane kroz `about_sections.dart`. Time je zatvorena i rupa iz taska 18: radno vrijeme i kontakt su od njega bili nedostupni u cijeloj aplikaciji. **Radno vrijeme je puna sedmica, ne jedan red iz handoffa** — iz prave baze: subota do 14:00, nedjelja zatvoreno. **Kontakt je izašao iz uokvirene tabele i dobio ikone**; labela nije nestala nego je otišla u `Semantics`, jer ikona čitaču ekrana ne znači ništa. Dokazano: **363 testa PASS** (bilo 326), app dignuta na iOS simulatoru i **instalirana na pravi iPhone** protiv živog Supabasea preko LAN-a (Kong log: `salons`, `services?order=category.asc`, `employees`, `working_hours` — sve 200, `Dart/3.13 (dart:io)`). **Zamka koju je našao browser, a testovi nisu mogli:** foto par i Galerija su na Početnoj crtali iste dvije fotografije jedna ispod druge — obje sekcije ispravne, obje sa zelenim testom, vidi se tek kad stoje na istom ekranu. Ostalo otvoreno: `services` nema `sort_order` kolonu, tapovi na `tel:`/mape/Instagram nisu odigrani. [PR #33](https://github.com/htuco/salon-booking-platform/pull/33).

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
