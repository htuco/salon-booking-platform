# Trenutni task: 29 — Responsive shell: desktop sidebar i mobilna navigacija

Puni task: [`tasks/sprint-3/29-responsive-shell.md`](sprint-3/29-responsive-shell.md)
**Nije počet** · Učitan: 2026-09-19

## Status

Nije počet. Zavisnost [28](sprint-3/28-admin-tema-i-tipografija.md) je spojena u `main` (`61da040`),
pa mjere ljuske već postoje kao tokeni i ne mjere se ponovo.

Danas `AdminScaffold` crta **istu ljusku na svakoj širini**: Material `AppBar` plus `NavigationBar`
sa **dvije** ćelije (Pregled, Termini). Nema breakpointa, nema sidebara, i dvije od četiri tražene
ćelije ne postoje.

## Ciljevi

- [ ] Breakpoint u `core/widgets/` — ispod njega donja navigacija, iznad sidebar; desktop se ne skalira
- [ ] Desktop grana: sidebar `AdminSize.sidebarWidth` (236), top bar `AdminSize.topBarHeight` (66),
      sadržaj na radnoj površini sa `AdminSpacing.gutterDesktop` (24)
- [ ] Mobilna grana: **četiri** ćelije — Danas · Kalendar · Zahtjevi · Još — i gutter
      `AdminSpacing.gutterMobile` (20)
- [ ] „Zahtjevi" dobije **svoju adresu**, jer danas nije ruta nego stanje providera (v. Napomene)
- [ ] „Još" (`3t`) sa ulazima u klijente, usluge, osoblje, radno vrijeme i postavke —
      `AdminRoute.clients` danas **ne postoji** i mora nastati bar kao placeholder
- [ ] Obje grane čitaju **istu listu ruta**; nema dva stabla ekrana
- [ ] `AdminScaffold` ostaje jedini nosilac navigacije, a `aktivna` se i dalje prosljeđuje iz ekrana
- [ ] Widget test nad **istim** ekranom na 1440×900 i 402×874

## Napomene

- **Zavisnost je namirena, ali 28 je i dalje 🟡.** Ostatak (dashboard i lista termina nisu viđeni na
  ekranu, jer nema Dockera ni `supabase` CLI-ja) ne blokira ovaj task — shell se dokazuje widget
  testovima na dvije širine, ne živim stackom.
- **`AdminScaffold` i `aktivna` već postoje i već su ispravni.** Peta DoD stavka nije posao nego
  zabrana regresije: komentar u `admin_scaffold.dart` već objašnjava zašto se ruta ne čita iz
  `GoRouterState`. Ovdje se ništa ne „popravlja" — samo se ne kvari.
- **„Zahtjevi" danas nije ruta nego stanje providera.** Dashboard kartica zove
  `postaviStatus(AppointmentStatus.pending)` i vodi na `/appointments`. Navigacijska ćelija koja
  radi isto puca na webu: refresh i „nazad" vrate nefiltriranu listu, a URL ne opisuje šta se vidi.
  Prije koda treba odluka — query parametar na `/appointments` ili zasebna ruta.
- **`AdminRoute` nema `clients`.** `3e`/`3o` piše task [35](sprint-3/35-klijenti-i-profil.md), ali
  DoD ovog taska traži ulaz u „Još". Ruta mora nastati sada kao placeholder, inače ćelija nema gdje
  da vodi. Ostalih pet (`calendar`, `services`, `employees`, `workingHours`, `settings`) već stoje
  kao placeholder rute.
- **Komentar u `_AdminNavigacija` treba prepisati, ne obrisati.** Danas tvrdi suprotno od koraka 3:
  „Ćelija koja vodi na placeholder je gora od ćelije koje nema." Task 29 tu odluku svjesno obrće —
  neka to i piše, inače sljedeći čitalac vidi samo da je pravilo nestalo.
- **Login i ručni unos imaju vlastiti `Scaffold`**, ne `AdminScaffold` — i tako treba da ostane:
  prijava nema navigaciju, a ručni unos je modalni tok.
- **Admin je i web build.** Router namjerno koristi `redirect`, ne `initialLocation`, da bookmark na
  `/employees` ne završi na loginu sa pogrešnim URL-om. Ljuska to ne smije pokvariti.
- **Boja ne dolazi iz `tenant.yaml`.** Admin nije brandiran — plava je identitet Salon OS-a. Ovo je
  obrnuto od pravila za `apps/client` i najlakše se prekrši navikom.
- **`gh` nije na PATH-u** — `export PATH="$PATH:/c/Program Files/GitHub CLI"`.
- Procjena iz task fajla (1–2 dana) ostaje; nalazi dodaju dvije rute i jednu odluku, ne novi sloj.

## Istorija

- **28 — Admin tema, tipografija i tokeni** (2026-09-19, 🟡) — `apps/admin/lib/src/core/theme/` je
  prestao biti `.gitkeep`: pet fajlova nose paletu, razmake, uglove, tipografiju i statusne tonove,
  a `main.dart` više ne gradi temu iz `ColorScheme.fromSeed`. Space Grotesk i JetBrains Mono su
  zapakovani u repo uz OFL. **Mjerenje canvasa je oborilo tri tvrdnje iz `SPEC.md`** i sve tri su
  zapisane nazad u `SPEC.md`: velika brojka i statusna pilula nisu mono, a sekundarni akcent
  `#5980A6` finalni canvas ne koristi nijednom. **Dva para iz handoffa padaju WCAG AA** i nisu
  prepisana doslovno — `#6B757B` na radnoj pozadini mjeri 4,35:1, oznaka „Završeno" 4,15:1; tekst
  je spušten na `#5B656B` (5,26:1), a `theme_contrast_test.dart` drži i tvrdnju da ti parovi
  **padaju**, da se vraćanje na handoff ne desi nečujno. Dokazano: **567 Dart testova** u pet
  paketa, od toga `admin` **70** (bilo 16), čista analiza, i login ekran u Chromiumu na 1440×900 i
  402×874. Ostaje 🟡 jer dashboard, lista termina i ručni unos **nisu viđeni na ekranu** — na ovoj
  mašini nema ni Dockera ni `supabase` CLI-ja, pa se lokalni stack ne može dići.
  [PR #49](https://github.com/htuco/salon-booking-platform/pull/49), spojen (`61da040`).

- **27 — Vitez live integracija i email + lozinka** (2026-09-16, 🟡) — klijentski OTP je zamijenjen
  stvarnim Supabase `signUp`/`signInWithPassword` tokom; Vitez klijent i admin slušaju
  RLS-ograničene promjene vlastitih termina, a javni `availability_signals` emituje samo nasumičnu
  reviziju salona, pa tuđa rezervacija osvježi slotove bez curenja appointment podataka. Live
  launcher čita javne ključeve iz ignorisanog `.env.live`. Dokazano lokalno: **261 pgTAP**, analiza
  i Flutter testovi u svih pet paketa.
  **Ostatak ne čeka kod nego tuđe naloge** i zato je task skinut sa aktivnog mjesta: hostovani
  projekat još traži potvrdu emaila i nema deployanu šemu (`supabase login` ili službeni connection
  string), Firebase CLI nema pristup projektu `hades-75751` (`403`), a Apple/Google traže potpisan
  fizički uređaj. Do tada email tok, availability i push **nisu dokazani na hostovanom projektu**.
  [PR #45](https://github.com/htuco/salon-booking-platform/pull/45), pa #46 i #47.

- **26 — Guest flow i Facebook iza flaga** (2026-09-19, ⛔ skinut) — Facebook login se ne
  implementira ([ADR-0011](../docs/adr/0011-facebook-login-se-ne-implementira.md)); kod je uklonjen,
  ne ostavljen iza flaga. Tok gosta nije odbačen, ali je ostao bez taska — `AuthConfig.allowGuest` i
  `AuthRepository.continueAsGuest` stoje u kodu, `continueAsGuest` baca grešku.
  [PR #48](https://github.com/htuco/salon-booking-platform/pull/48).

- **24 — Admin akcije nad terminima i ručni unos** (2026-09-15, ✅) — salon prvi put odgovara na
  zahtjev: potvrda, odbijanje, otkazivanje, `no_show` i ručni termin rade kroz RPC putanje umjesto
  direktnog `insert`/`update`. **Rupu iz `security.md` zatvara oduzimanje granta**, ne dodavanje
  funkcija: `authenticated` više nema `insert`/`update` nad `appointments`, pa su jedini pisci
  `book_appointment`, `set_appointment_status` i `cancel_appointment`. Ručni termin prolazi istu
  validaciju slota kao klijent, ali admin ima izuzetak za `min_advance_booking_hours` jer salon
  smije upisati klijenta koji stoji na vratima. Dokazano: **220 pgTAP**, **515 Dart testova** i
  browser na oba tenanta protiv žive baze; sve četiri akcije provjerene `psql` upitom. Ekran je
  našao duplirana vremena u ručnom unosu (`get_available_slots` vraća red po radniku), pa
  `distinctTimes` sada ima testove. Ostaje 🟡 nijedan Deno REST test jer `deno` nije instaliran, i
  admin nije pokrenut na mobilnom uređaju. [PR #42](https://github.com/htuco/salon-booking-platform/pull/42).

- **21 — Client: Obavijesti, „O aplikaciji" i pravni ekrani** (2026-09-14, ✅) — `/terms`,
  `/privacy` i `/about-app` rade iz prave baze na oba tenanta; `/notifications` je **namjerno samo
  prazno stanje** dok [25](sprint-2/25-push-notifikacije.md) ne da listu. **Tekst dolazi iz dvije
  tabele, ne iz `salons`** ([ADR-0009](../docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md)):
  handoff 5o ima šest sekcija, ali Zakazivanje, Cijene i „Vaši podaci" obavezuju **firmu** i iste su
  u svakoj brandiranoj app-i, dok Otkazivanje, Kašnjenje i Kontakt obavezuju **salon** — otud
  `app_policies` (bez `salon_id`) i `salon_policies` (`salon_id`). Jedna tabela sa nullable
  `salon_id` je odbijena: politika bi dobila NULL granu, a upravo je NULL u guardu pustio zahtjev
  bez `x-salon-id` headera u tasku 14; negativan test koji to drži je `salon_admin` nad
  `app_policies`. Sekcije se crtaju **dinamično `01..NN`**, bez šest zakucanih u kodu. **Handoff
  copy nije prepisan jer tvrdi neistinu** — „Vaši podaci" piše da čuvamo broj telefona, a app ga
  nikad ne traži; oba dokumenta su napisana nanovo, za App Privacy / Data Safety formulare.
  **Dvije greške koje je našao ekran, a testovi nisu mogli:** politika privatnosti je išla naopako
  (`PostgrestTransformBuilder.order` ima `ascending = false` kao **default** — „Kontakt" je bio `01`
  a „Ko obrađuje podatke" `09`; ista zamka je već bila zapisana u `service_repository.dart`), i
  „Zadnja izmjena: 14.09.2026**..**", jer `formatDate` već nosi tačku a `.arb` je dodavao još jednu.
  Prva se hvata samo protiv pravog PostgREST-a — unit test koji mapira red ne vidi redoslijed kojim
  redovi stižu, a ekran ne sortira; druga samo testom na cijeli string, ne na podniz. Dokazano:
  **176 pgTAP** (bilo 147), **123 REST asercije**, **460 Dart testova** (bilo 419); čista analiza u
  svih pet paketa. Uživo na iOS simulatoru — `/terms` numerisan `01..06` sa `3 h` i `030 711 000`
  **iz baze**, ne `2 sata` i `030 711 220` iz handoffa. Ostaje javni URL politike privatnosti
  (traži hosting) i „Ocijenite aplikaciju" neaktivan dok app nije u prodavnici.
  [PR #38](https://github.com/htuco/salon-booking-platform/pull/38).

- **23 — Admin: login, dashboard i lista termina** (2026-09-14, ✅) — `apps/admin` je prestao biti
  skelet od osam fajlova. Prijava ide kroz **zaseban `StaffRepository`**, ne kroz klijentski
  `AuthRepository`: u vrijeme isporuke klijent je koristio Apple, Google, OTP i gosta. ADR-0010
  dodaje password i klijentu, ali ugovori ostaju odvojeni jer `signIn` vraća `StaffMember`,
  ne samo sesiju, jer `private.is_admin()` traži **oba** uslova — claim u JWT-u i red u
  `public.users`; ko ima token a nema red prijavi se i ne vidi nijedan red, što na ekranu izgleda
  kao prazna baza a zapravo je pogrešno postavljen nalog. **Lista prije dashboarda**, kako task
  nalaže. Dokazano: **479 Dart testova** (bilo 462, `admin` 16 je nov), **177 pgTAP**, **šest Deno
  testova / 173 asercije**, i **uživo u browseru na oba tenanta** — ista aplikacija, prijava drugim
  vlasnikom pokazuje samo njegov salon. **Seed je dobio admine i termine:** nije imao nijednog
  `salon_admin`, pa se nije imalo čime prijaviti, a bez klijenata i termina se **izolacija ne može
  dokazati** — upit „A ne vidi B" vraća nulu i kad je RLS isključen. **Dvije zamke koje se ne vide
  u kodu:** nullable text kolone u `auth.users` moraju biti prazan string a ne `NULL` (GoTrue ih
  skenira u Go `string`, prijava puca sa `500`, a red izgleda ispravno u `psql` i cijela pgTAP suita
  prolazi — drži je novi `rest_admin_login.ts`), i `order()` u postgrest paketu podrazumijeva
  `descending`, pa je raspored dana išao unatraške; widget testovi to nisu mogli uhvatiti jer su im
  lažne liste već bile sortirane, vidjelo se **tek na ekranu**. Ostalo: admin **nije pokrenut na
  mobilnom uređaju**, dokaz je iz Chromea.

- **20 — Client: Galerija, lightbox i Recenzije** (2026-09-14, ✅) — `/gallery`, lightbox 5q i
  `/reviews` rade iz prave baze na oba tenanta. **`gallery_photos` nije nastao**
  ([ADR-0008](../docs/adr/0008-galerija-ostaje-u-salons-gallery-urls.md)): `salons.gallery_urls`
  stoji u init migraciji i već je bila spojena do Početne i `/about`, pa bi nova tabela bila drugi
  izvor istine za istu listu — migracija dira **samo `reviews`**. **Prosjek i histogram računa
  baza**, pogled `salon_rating_summary` sa `security_invoker = true`: PostgREST reže na
  `max_rows = 1000`, pa bi salon sa 1200 ocjena u Dartu dao tih i pogrešan prosjek, a bez te opcije
  pogled zaobilazi RLS tabele ispod. **Curenje je namjerno napravljeno vidljivim kao broj** — seed
  drži jednu sakrivenu jedinicu, pa je tačan prosjek 4,8 a procurio 4,7; test koji broji redove to
  ne bi uhvatio. `comment` je nullable jer većina ljudi da zvjezdice bez teksta, pa lista prikazuje
  samo redove sa tekstom a prosjek računa sve: 25 ocjena i četiri kartice **nije** nesklad.
  Dokazano: **147 pgTAP** (bilo 124), **43 REST asercije bez tokena** (bilo 33), **419 Dart testova**
  (bilo 372), sve provjereno da može pasti pa vraćeno; uživo u Chromiumu i na **iOS simulatoru**.
  **Dvije greške koje je našao ekran, a testovi nisu mogli:** zvjezdica se razlikovala samo bojom
  (Lucide nema punu — 2,4% razlike u svjetlini, a 3,5 se crtalo identično kao 4,0), i naslov je bio
  u `AppBar`-u umjesto „← Početna" plus serif u tijelu; zaglavlje je izvučeno u `core_ui` kao
  `BackHeader`, a **`/account` iz taska 17 je popravljen istim potezom**. **Prvi test za zvjezdicu
  je bio bezvrijedan** i to je ostavljeno zapisano — poredio je piksele i prolazio nad pokvarenom
  verzijom; sada mjeri *koliko*. Ostaje 🟡 **share ⤴ u lightboxu**.
  [PR #37](https://github.com/htuco/salon-booking-platform/pull/37).

- **17 — Client: Postavke, „Moj račun" i brisanje računa** (2026-09-14, ✅) — brisanje je
  **dvokoračno**: `delete_my_account()` pod korisnikovim tokenom, pa Edge Function
  `delete-account` sa `auth.admin.deleteUser` pod service role ključem, koji nikad ne smije u
  klijentsku app. Tim redom, jer bi obrnuto pad drugog koraka ostavio `customers` red sa punim
  imenom, a korisnikov token više ne bi postojao. **Nalaz bez kojeg je task bio pozorište:**
  `appointments` nosi `customer_name`, `customer_phone` i `customer_note` kao **vlastite kolone**,
  pa anonimizacija samo nad `customers` ostavlja puno ime u svakom terminu — `docs/06` §8.2 to
  traži doslovno, bio je propust u prenosu u task fajl. **Ovo je jedini upis u repou koji namjerno
  prelazi granicu salona:** isti čovjek je klijent u više salona, a brisanje naloga je odluka o
  osobi, pa se `x-salon-id` namjerno ne traži. **5k je ušao u task** jer `/account` bez njega nema
  ulaz iz aplikacije; komentar u routeru ga je pripisivao tasku 21, čiji DoD ga nema. Dokazano:
  **124 pgTAP testa** (bilo 97), **33 REST asercije** kroz pravu Edge Function, **372 Dart testa**
  (bilo 363), i cijeli tok odigran u Chromiumu protiv žive baze — nakon brisanja `deleted_at`
  upisan, mail i ime `NULL`, `supabase_user_id` pao na `NULL`, nula preostalih `auth.users` redova.
  Oba testa provjerena da **mogu pasti**. Usput nađena **tri zatečena testa koja su bila zelena
  samo u dijelu dana ili sedmice** (`004` poslije 09:30, `002` ponedjeljkom, `rest_public_catalog`
  otkad barber ima sve fotografije) — nijedan se nije vidio jer je CI blokiran. Ostaje 🟡 **Apple
  token revoke**, koji čeka Apple prijavu. [PR #34](https://github.com/htuco/salon-booking-platform/pull/34).


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
