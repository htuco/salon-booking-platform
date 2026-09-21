# Trenutni task

## Status

U toku — task 36, **Postavke lokacije** (2026-09-21). Kod je napisan i dokazan lokalno;
[PR #59](https://github.com/htuco/salon-booking-platform/pull/59) je otvoren kao draft na commitu
`ce76081` i **čeka CI**. Dokazi, sabotaže i ograničenja:
[task 36](sprint-3/36-postavke-lokacije.md).

Task 35 je spojen u `main` (PR #58, merge `20f686b`).

## Ciljevi

Preostalo do zatvaranja:

- [ ] **Oba CI joba zelena** na `ce76081` — `Supabase tests` sada vrti i `rest_working_hours.ts`
      (vraćen u CI) i novi `rest_postavke_lokacije.ts`, pa je ovo prvi put da ta dva idu iz
      čistog checkouta.
- [ ] **Ekran otvoren uživo.** Sve ostalo je dokazano, ovo nije: `./tool/run_tenant.sh`, prijava
      kao `admin@barberstudiovitez.test` / `admin123456`, pa `/settings` na obje širine i
      poređenje sa canvasom `3i`.
- [ ] Skinuti draft sa PR-a i spojiti.

## Napomene

- **Sabotažu pokretati samo unutar transakcije testa.** `create or replace` kroz `psql -f` nad
  fajlom bez `begin;` ostane komitovan u lokalnoj bazi; sljedeći REST test je zbog toga prijavio
  cross-tenant pisanje kojeg u migraciji nema. `npx supabase db reset` čisti.
- `supabase` CLI na ovoj mašini ide kroz **`npx supabase`**, a `deno` je u
  `~/.deno/bin` i nije na `PATH`-u — `tool/test_supabase.sh` pretpostavlja oba na `PATH`-u, pa se
  komande za sada pokreću ručno.
- Poslije 36 sprint 3 nema više nezatvorenih taskova sa kodom; ostaju 🟡 stavke 28 i 30, koje čekaju
  dokaz na ekranu, ne kod.

## Istorija

- **35 — Klijenti i profil** (2026-09-21) — `/clients` je prestao biti placeholder: desktop `3e` je
  adresar sa profilom uz listu, telefon `3o` isti redovi kao kartice, profil preko liste. Pretraga
  po imenu i telefonu, kartice „Svi · Redovni · Neaktivni · Nedolasci", profil sa `visit_count`,
  `no_show_count`, istorijom i bilješkom. **Redoslijed „test prije ekrana" je promijenio šta se
  testira**: `rest_cross_salon_isolation.ts` je već dokazivao četiri od pet puteva iz DoD-a, pa mu
  nije trebao još jedan opšti test nego **puteve koje uvodi baš ovaj ekran** — pretragu po uzorku i
  **obrnuti** embed `customers → appointments`; oba su neugodna na isti način, jer se ne traži tuđi
  red nego se šalje uzorak, pa curenje ne bi izgledalo kao napad nego kao klijent koji se pojavio
  niotkuda (27 → **42 asercije**). **Migracije nema, i to je nalaz a ne propust**: `staff_manage`
  nad `customers` stoji od init migracije, a tabela je **zadržala** `insert`/`update` grant, za
  razliku od `appointments` (24), `employees` (33) i `working_hours` (34) — zato je ovo jedini
  staff repozitorij kod kojeg „samo kroz `rpc`" ne drži grant nego odluka, i to je upisano u
  `security.md` i `architecture.md`, jer je baš tu sljedeća izmjena najbliža tome da dopiše
  `insert`. **Pretraga je prvo mjesto u repou gdje korisnikov tekst ulazi u PostgREST izraz** —
  `or=(...)` razdvaja zarezom, a `%` i `_` su `like` džokeri, pa se `,()"` uklanjaju i `%_\` brišu;
  potpuno očišćen unos daje uzorak koji **ne pogađa ništa**, ne `*%*` koji pogađa sve. **Četiri
  stanja koja bi pala na `!`** imaju svoj test: anonimiziran red (task 17), telefonski klijent bez
  `auth_identity_id`, klijent bez `last_visit_at` i termin bez `employee_name` — svako dobija riječ
  umjesto crtice. **„Nema podatka" se ne crta kao nula**: „Potrošeno" broji samo `completed`, jer
  otkazan termin nije prihod, i izostaje kad nijedan ne nosi cijenu. Dokazano: **42 asercije** kroz
  tri stvarna JWT-a uz **tri sabotaže**, svih **devet** REST suita (236 asercija), **385 pgTAP
  PASS**, `melos run test` 786 testova u pet paketa (admin **268**, bilo 247), čista analiza i
  format; sabotaža Flutter testa (uklonjen `completed` guard) daje 60 umjesto 45. **Revizija
  (`rls-auditor`) je potvrdila da nijedan upit ne prelazi granicu** i da izraz nije iskoristiv za
  injection, ali je našla da je asercija nad `or` izrazom prolazila **iz pogrešnog razloga**:
  `ensure_customer` ne upisuje `phone`, pa je red salona B imao `NULL`, a `NULL ilike ...` je
  `NULL` — grana po telefonu nije mogla pogoditi ništa ni bez RLS-a; popravljen fixture i dodan `"`
  u sanitizaciju; **oba CI joba su bila zelena i prije te popravke**, što je i poenta nalaza.
  **Oba joba su zelena i na `c3a12cf`**, zadnjem commitu grane. **Ostalo: ekran nije viđen uživo**
  ni na webu ni na uređaju, profil nema svoju adresu (`/clients/<id>` ne radi iz bookmarka, isti
  dug kao `/calendar` za dan), a četiri stvari iz canvasa `3e` namjerno nisu nacrtane, sa razlogom
  u `prototype/admin/SPEC.md`.


- **31 — Kalendar dana** (2026-09-20, ✅) — `/calendar` je prestao biti placeholder: desktop `3c`
  je mreža sa kolonom po radniku nad satnom osom, telefon `3l` ista stvar kao lista po vremenu.
  **Jedan model, dva čitanja** — `calendar_day.dart` je čista funkcija nad terminima, radnim
  vremenom i blokadama, jer blok na pogrešnom mjestu na osi izgleda tačno kao blok na pravom;
  miješanje pogleda „po radniku" i „po vremenu" je zamka koju kalendar nasljeđuje od availability
  enginea. Vrijeme je svugdje `int` minuta od ponoći, ne `DateTime`. **`blocked_slots` je prvi put
  dobila Dart repozitorij** — tabela postoji od init migracije, ali je do sada čitana isključivo iz
  SQL-a; bez nje se „blokade se vide" ne može ispuniti, i to je jedino odstupanje od DoD-a, koji je
  tražio čitanje bez novog upita (termini i jesu, kroz postojeći `forDay`). Repozitorij **samo
  čita**; pisanje je task 34. **Ispravljena netačna tvrdnja** koju je prvi prolaz umalo ostavio u
  repou: grantovi nad `blocked_slots` **dozvoljavaju** direktan upis, za razliku od `appointments`
  gdje ih je task 24 oduzeo — provjereno pozivom, ne čitanjem migracije, i upisano u
  `security.md`. Četiri odluke koje se ne vide iz koda: osa se razvlači preko svega što dan sadrži
  (termin van smjene ne smije nestati), zatvoren dan se ne čita iz `start_time`/`end_time` (default
  `09:00–17:00` stoji i u `is_closed` redu), termin bez radnika dobija kolonu „Bez radnika", i
  preklapanje ide u trake (otkazan termin ostaje u listi, pa novi legitimno stoji preko njega).
  **Tri greške našao ekran, ne testovi:** kvadratići u legendi su uzimali `foreground` umjesto
  `background` pa je „Otkazano" bio nevidljiv; tekst u 40-minutnom bloku se rezao po dnu, jer je
  padding biran po minutama a ne po pikselima; i „Slobodno" se protezalo preko zatvaranja salona.
  Dokazano: **716 testova** u pet paketa (`admin` **219**, od toga 62 nova), čista analiza i format,
  četiri sabotaže koje potvrđuju da testovi mogu pasti, i **prava prijava** protiv hostovanog
  projekta u kojoj klik na blok otvara pravi detalj termina. Ostalo: `/calendar` ne nosi dan u
  adresi, blokade nemaju seed red, a deep link na **bilo koju** admin rutu poslije osvježavanja pada
  na `/dashboard` — nađeno uživo i **nije od ovog taska**.
  [PR #53](https://github.com/htuco/salon-booking-platform/pull/53).

- **30 — Postojeći ekrani na handoff** (2026-09-20, 🟡) — prijava, „Danas", zahtjevi, lista termina
  i **detalj termina** su dobili izgled iz `prototype/admin/`. `/appointments/:id` je bio placeholder
  iako ruta stoji u enumu i u `docs/01 §12`; sada čita jedan termin iz baze
  (`StaffAppointmentRepository.byId`, nov) umjesto iz liste — ista adresa mora raditi iz bookmarka i,
  sutra, iz push obavijesti. Ljuska je zatvorila tri stvari koje joj je 29 ostavio: breadcrumb
  `Vitez / Danas` (ime salona iz novog `adminSalonProvider`-a, jer `StaffMember` nosi samo `salonId`),
  akcije desktop top bara, i naslov „Danas" umjesto „Pregled". **Dvanaest stvari iz canvasa namjerno
  nije nacrtano**, sa razlogom i taskom povratka — tabela je u `prototype/admin/SPEC.md`; brojke na
  prijavi („6 lokacija · 19 majstora · 84 termina") nisu demo sadržaj nego **tuđi podaci** koje
  `salon_admin` po RLS-u ne smije vidjeti. **Četiri greške je našao ekran, a testovi nisu mogli:**
  brojanje po `status.blocksSlot` (pokazivalo 5 od 6 termina), „3 3 termina" u zauzetosti,
  telefonsko dugme širine svog teksta nasred ekrana, i desktop prijava sa dva logotipa — sve četiri
  sada mjeri test nad cijelim redom ili širinom. **Uređaj je našao petu:** ćelija „Zahtjevi" je
  nosila crvenu tačku i kad zahtjeva nema, jer Material prazan `Badge.label` iscrta kao tačku; na
  webu se nije vidjelo jer demo uvijek ima zahtjeve. **Prava prijava je odigrana i time pada dug iz
  28 i 29** — seed nalog na hostovanom projektu postoji, tok je snimljen na Android emulatoru
  (`docs/screenshots/task-30-admin-uredjaj-*.png`). Dokazano: **642 testa** (admin **145**, bilo 85),
  čista analiza i format, svih pet prikaza uživo na 1440 i 402. **Ostalo:**
  `admin@beautystudiotravnik.test` na hostovanom projektu ne postoji (`400` na prijavi), pa „ista
  app, druga prijava, nijedan tuđi termin" ostaje nedokazano uživo — izolacija stoji na pgTAP-u i
  Deno testovima; fizički uređaj i iOS nisu dirani.
  [PR #52](https://github.com/htuco/salon-booking-platform/pull/52), spojen (`305c1ba`).

- **29 — Responsive shell: desktop sidebar i mobilna navigacija** (2026-09-19, ✅) — `AdminScaffold`
  na 1440 crta tamni sidebar od 236 px i top bar od 66, na 402 četiri ćelije; prelaz na **840**, jer
  canvas taj broj ne daje a `SPEC.md` kaže da tablet „nije posebno nacrtan". Obje ljuske čitaju
  **jednu** listu (`kAdminDestinations`): prve tri su ćelije telefona, ostalih pet rep iza „Još", pa
  modul dodan u navigaciju ne može ostati dostupan samo na jednoj širini. **Mjerenje canvasa je
  oborilo token iz taska 28** — `gutterDesktop` je bio 24, a `padding:28px` stoji u svih sedam
  desktop prikaza u opsegu dok se `padding:24px` ne javlja nijednom. **Handoff nema ćeliju
  „Termini"**, pa „Zahtjevi" vode na `/appointments?status=pending` a ne na vlastitu rutu: zasebna
  ruta bi punu listu ostavila bez ijednog ulaza iz navigacije. Time je popravljena i web greška —
  kartica na dashboardu je mijenjala stanje providera pa navigirala, pa su refresh i „nazad"
  vraćali nefiltriranu listu. Dodane `/clients` i `/more` i upisane u `docs/01 §12`, a ranija odluka
  „ćelija koja vodi na placeholder je gora od ćelije koje nema" je **svjesno obrnuta** i tako
  zapisana. **Greška koju je našao browser, a testovi nisu mogli:** `AdminPlaceholderScreen` je imao
  vlastiti `Scaffold`, pa je `/clients` otvoren iz „Još" bio slijepa ulica bez ikakve navigacije —
  widget test to ne vidi jer diže jedan ekran, a ovo je svojstvo prelaza između dva. **Usput
  ispravljen i jedan bezvrijedan test:** provjera guttera je poredila token sam sa sobom i prolazila
  nad pogrešnom vrijednošću. Dokazano: **85 admin testova** (bilo 70), **582 ukupno**, čista analiza,
  svaki novi test provjeren da **može pasti** (osam prolaza), CI zelen, i obje ljuske uživo u
  Chromiumu uključujući refresh na `?status=pending` — `docs/screenshots/task-29-admin-*.png`.
  Ostaje 🟡 samo dokaz sa **pravom prijavom**: snimci su iz novog `apps/admin/lib/demo_main.dart`,
  jer nema Dockera ni `supabase` CLI-ja; hostovani projekat iz `.env.live` sada ima šemu, ali nije
  bilo naloga. [PR #51](https://github.com/htuco/salon-booking-platform/pull/51), spojen (`88c1605`).

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

- **32 — Usluge i cjenovnik (2026-09-21, završeno)** — PR #54 spojen u main. RPC CRUD, oduzeti direktni grantovi i snapshot usluge na terminima. Flutter i Supabase CI zeleni na c3762f7. Preostale dorade evidentirane u sprint-3/README.md: Deno REST testovi, run skripte i demo/format cijene.

- **33 — Osoblje i smjene (2026-09-21)** — RPC CRUD, atomske veze usluga, deaktivacija i snapshot imena; desktop/mobilni editor i redovni raspored. 328 pgTAP, 19 REST i Flutter suite PASS; oba CI joba zelena na `8a40a97`, PR #55 spojen u `main` (`d4c54c3`). Native/hostovani deploy nisu urađeni. Sljedeći task 34.
- **34 — Radno vrijeme, pauze i blokade** (2026-09-21) — `/working-hours` je prestao biti placeholder: sedam dana sa vremenima i pauzom, prekidač za neradni dan, i lista budućih blokada sa uređivačem koji bira cijeli salon ili jednog radnika. **Zatvorena posljednja rupa u „samo kroz `rpc`"**: init migracija je nad `working_hours` i `blocked_slots` davala pun grant, pa je pravilo bilo konvencija a ne tvrdnja baze — task 31 je to provjerio pozivom i odluku izričito ostavio ovdje. Sada je oduzet, kao nad `appointments` (24) i `employees` (33). **Sedmica se piše u cjelini, i to nije stil ugovora** — `get_available_slots` čita **odsustvo reda kao zatvoreno**, ne kao „nije podešeno", pa bi slanje samo izmijenjenih dana tiho zatvorilo ostale; ulaz je zato tačno sedam dana uz provjeru da je svaki ISO dan prisutan tačno jednom, jer sama provjera dužine propušta šest dana plus duplikat. **Postojeći termin se ne briše tiho**: dvije `stable` funkcije čitanja vraćaju termine koji bi ispali van novog vremena ili pali pod blokadu, ekran ih pokazuje **prije** upisa, a odluka ostaje vlasniku. Dokazano: **379 pgTAP PASS** (51 nov) i **15 REST provjera** kroz stvarni JWT — skraćeno radno vrijeme, pauza, zatvoren dan i blokada svaki put mijenjaju ono što klijent dobije iz `get_available_slots`, a direktan `insert` vraća `401/403`; puna Flutter suita (admin 247) i čista analiza/format. Widget testovi su usput našli **dva stvarna preliva na telefonu** (106 px i 70 px) u redu dana i redu pauze, oba ispravljena u `3s` rasporedu. Ostalo: radnikov sedmični raspored nema ekran (RPC ga prima, pgTAP pokriva), `/calendar/block` je i dalje placeholder ruta ali više ne čeka `rpc`, „Pravila zakazivanja" iz `3h` su task 36. [PR #57](https://github.com/htuco/salon-booking-platform/pull/57) otvoren, čeka spajanje.
