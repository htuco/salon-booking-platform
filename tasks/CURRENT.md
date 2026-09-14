# Trenutni task: 21 — Client: Obavijesti, „O aplikaciji" i „Pravila korištenja"

Puni task: [`tasks/sprint-2/21-obavijesti-i-pravni-ekrani.md`](sprint-2/21-obavijesti-i-pravni-ekrani.md)
**U toku** · Učitano: 2026-09-14 · Grana: `feat/pravila-i-o-aplikaciji`

## Status

U toku. Zavisnost [18](sprint-2/18-pocetna-i-tab-bar.md) je ✅, i sve tri rute već postoje —
ali kao placeholderi.

**Task nije jedna cjelina.** Dva ekrana su odblokirana i otključavaju store submission; treći
(`/notifications`) nema odakle povući podatke dok ne postoji [25](sprint-2/25-push-notifikacije.md).

**Odluke donesene 2026-09-14:** dvije tabele, dinamične sekcije, legal tekst piše samo platforma.
Tekst pravila i politike privatnosti piše se **nanovo**, po stvarnom inventaru podataka.
Oblik i obrazloženja su u Napomenama — traži svoj ADR.

## Ciljevi

### Pravila — šema i podaci

- [x] **Odluka o obliku** — dvije tabele, legal tekst samo platformski (v. Napomene)
- [ ] ADR: zašto dvije tabele a ne jsonb na `salon_settings`, i zašto salon ne piše legal tekst
- [ ] Migracija: `app_policies` (bez `salon_id`) i `salon_policies` (`salon_id`), obje sa
      `sort_order`, RLS, taksativnim grantom i **negativnim** testom
- [ ] Seed: **novonapisana** pravila i politika privatnosti, razdvojena na legal i salonska
      (handoff copy se **ne prepisuje** — v. Napomene)
- [ ] Repozitorij + provideri u `core_api`

### Ekrani

- [ ] `/terms` po 5o: dinamična lista, numerisana `01..NN` redom kojim sekcije stignu
- [ ] `/about-app` po 5n: verzija iz `package_info_plus`, monogram iz inicijala, „Kako radi" u tri
      koraka, kontakt redovi iz `salons`
- [ ] `/about-app` pravni redovi: „Pravila korištenja" → `/terms`; „Politika privatnosti" →
      `/privacy`; **„Ocijenite aplikaciju" ostaje vidljiv ali neaktivan** dok app nije u
      prodavnici; „Prijavite problem" → mail developeru
- [ ] `/privacy` — politika privatnosti, pisana za **App Privacy i Data Safety** formulare
- [ ] `package_info_plus` u `apps/client/pubspec.yaml` — danas ga nema
- [ ] Oba su pod-ekrani: `BackHeader` sa labelom „Postavke", serif naslov u tijelu
- [ ] Testovi + dokaz na simulatoru, oba tenanta

### Odlučeno: `/notifications` ide sad, kao prazno stanje

- [ ] `/notifications` po 5j — **samo prazno stanje**, sa iskrenim tekstom da obavijesti stižu kad
      salon potvrdi termin. Lista dolazi sa [25](sprint-2/25-push-notifikacije.md).

## Napomene

### Šta stvarno postoji danas

Sve tri rute su u `ClientRoute` i vode na `PlaceholderScreen`
([app_router.dart:120, 196, 201](../apps/client/lib/src/core/router/app_router.dart)). Rute su
namjerno napravljene prije ekrana, još u tasku 18: ćelija trake i red Postavki koji ne vode nigdje
su gori od placeholdera. Znači: **ništa od sadržaja nije napisano**, ali ulazi postoje i ne treba
ih praviti.

`package_info_plus` **nije** u `pubspec.yaml`. DoD ga traži izričito („verzija se čita iz
`package_info_plus`, ne iz konstante koja zastari").

### Pravila: dvije vrste, dinamične sekcije

Odlučeno 2026-09-14. Handoff 5o ima šest sekcija, ali **nisu sve iste vrste**:

| Sekcija | Čija je |
|---|---|
| Zakazivanje, Cijene, Vaši podaci | **platforma** — obavezuje firmu, ista u svakoj brandiranoj app-i |
| Otkazivanje, Kašnjenje, Kontakt | **salon** — mijenja se po tenantu |

Otud dvije tabele, a ne jedna sa `salon_id IS NULL`:

- **`app_policies`** — bez `salon_id`, kao `vertical_packs`. `anon` čita, piše samo super admin.
- **`salon_policies`** — `salon_id`, `anon` čita za aktivan salon, `salon_admin` CRUD nad svojim.

Obje nose `sort_order`, naslov i tijelo, pa se sekcije **dodaju dinamično**: ekran crta `01..NN`
redom kojim stignu, bez šest zakucanih sekcija u kodu.

**Jedna tabela sa nullable `salon_id` je odbijena**: politika bi dobila NULL granu, a `security.md`
već bilježi da je upravo NULL u guardu pustio zahtjev bez `x-salon-id` headera (task 14).

**Salon ne smije mijenjati legal tekst.** Tekst o obradi podataka obavezuje firmu, ne salon; app u
storeu koja tvrdi nešto svoje o podacima je izlaganje koje se ne kontroliše.

### Handoff copy se ne prepisuje — tvrdi neistinu

Sekcija „Vaši podaci" na `15-pravila-koristenja.png` piše *„Čuvamo ime, **broj telefona** i
historiju termina"*. **Klijentska app nikad ne traži telefon:** `ensure_customer` upisuje samo ime,
booking ekran nema polje, a `docs/01` to vodi kao donesenu odluku („Broj telefona se ne traži od
klijenta — push zamjenjuje poziv i SMS"). Prepisan handoff bi lagao u prvoj rečenici pravno
obavezujuće sekcije.

Zato se tekst piše **nanovo, po stvarnom inventaru**, a ne po generičkom templateu — template tvrdi
kolačiće, plaćanja i lokaciju, čega ovdje nema, i to je ista greška u drugom obliku.

Stvarno prikupljeno, provjereno u šemi i u kodu:

| Podatak | Odakle | Gdje |
|---|---|---|
| Email | Apple / Google / email OTP | `auth_identities.email` |
| Ime | display name providera, salon može ispraviti | `customers.name` |
| Historija termina | usluga, radnik, datum, status | `appointments` |
| Napomena uz termin | korisnik upisuje, opciono | `appointments.customer_note` |
| Push token | **tek sa taskom 25** | `devices` |

Bez telefona, lokacije, plaćanja i analitike trećih strana. `customers.phone` i
`appointments.customer_phone` **postoje**, ali ih puni salon iz admina, ne klijent — politika to
mora razlikovati.

**Ovo nije pravni savjet.** Tekst je napisan da bude tačan naspram koda i upotrebljiv za store
formulare; prije submissiona ga mora pogledati neko ko za to odgovara, posebno oko GDPR-a.

### Zamka koju ovaj oblik ne rješava sam: brojevi se razilaze

Handoff piše „najkasnije **2 sata** prije početka", a to je `salon_settings.min_cancel_hours` —
barber ima **3**, beauty **6**. Task 16 je napravio `cancel_appointment`, koji taj rok čita iz
postavki i **stvarno ga provodi**. Ako sekcija bude slobodan tekst, salon promijeni rok u
postavkama a pravila i dalje pišu staru cifru — aplikacija tada laže korisniku na pravno
obavezujućem ekranu.

Prijedlog (nije odlučeno): tijelo sekcije podržava **placeholdere** koje ekran popunjava iz živih
podataka — `{minCancelHours}`, `{phone}`, `{email}`, `{appointmentSingular}`. Isti razlog vrijedi i
za kontakt: handoff ima `030 711 220`, seed `030 711 000` — dva izvora za isti podatak već se
razilaze.

**Još nije riješeno:** „više od 10 minuta" (kašnjenje) i „tri nedolaska u šest mjeseci" nemaju
kolonu. `customers.no_show_count` postoji, ali prag nigdje nije zapisan ni provođen. Ili dobijaju
polja u `salon_settings`, ili se sekcije pišu bez brojeva.

### `/notifications` nema izvor podataka — zato ide kao prazno stanje

Korak 2 u task fajlu kaže doslovno: *„Obavijesti nakon taska 25, da imaju šta prikazati."*
Task 25 nije počet. Uz to, provjereno u šemi:

- `notification_logs` postoji, ali politika `staff_notification_logs` je
  `using(private.is_admin(salon_id))` — **klijent tu ne vidi nijedan red**. Nema klijentske
  politike, pa ekran nema server-side izvor.
- Zamka iz task fajla nudi izlaz: *„Lista obavijesti bez servera je lokalna historija pusheva —
  reci to u praznom stanju, ne glumi server koji ne postoji."* Ali lokalna historija pusheva
  pretpostavlja da pushevi postoje, a to je opet task 25.

**Odlučeno: ide sad, kao prazno stanje.** Ćelija trake već postoji i vodi na razvojni placeholder,
što je gore od iskrenog praznog ekrana. Tekst kaže šta korisnik može očekivati („obavijesti stižu
kad salon potvrdi termin"), ne glumi server koji ne postoji. Lista i nepročitano stanje dolaze sa
taskom 25, i tada se mijenja **samo tijelo**, ne ruta ni ulaz.

### Pravni redovi na `/about-app` — stanje svakog

- **„Pravila korištenja"** → `/terms`, ruta postoji.
- **„Politika privatnosti"** → `/privacy`, **nova ruta u ovom tasku**. Tekst ide u `app_policies`
  kao zaseban dokument, pa isti izvor kasnije servira i javna stranica iz Sprinta 3 (`docs/01`
  korak 29 traži javni URL — ekran u app-i ga **ne zamjenjuje**).
- **„Ocijenite aplikaciju"** → **red stoji, ali je neaktivan** (odluka 2026-09-14). Traži App
  Store / Play ID, a aplikacije nisu objavljene. Crta se u `disabled` stanju iz `SPEC.md`
  (45% prozirnosti) i **ne prima tap** — prazan tap je gori od reda koji vidljivo čeka. Ispod
  stoji kratko objašnjenje da se aktivira nakon objave. Kad app ode u prodavnicu, mijenja se
  samo `storeListingUrl` u `tenant.yaml`, ne ekran.
- **„Prijavite problem"** → mail **developeru**, ne salonu. Adresa još nije data — dok je nema,
  stoji kao konstanta koju treba popuniti.

### Odluke koje sam uzeo sam (2026-09-14) — za pregled

Hamza je rekao „uradi kako god pa ću pregledati". Skupljeno na jedno mjesto, da pregled bude kratak:

| Šta | Odluka | Zašto |
|---|---|---|
| Brojevi u tekstu pravila | tijelo sekcije podržava **placeholdere** (`{minCancelHours}`, `{phone}`, `{email}`, `{appointmentSingular}`), ekran ih puni iz živih podataka | slobodan tekst bi odlutao od onoga što `cancel_appointment` stvarno provodi |
| Kašnjenje i nedolasci | **bez novih kolona**; sekcije se pišu bez brojeva | ništa u kodu te pragove ne provodi — kolona koju niko ne čita je kolona koja laže |
| Monogram na `/about-app` | inicijali imena salona, kao tekst | `SPEC.md` §Assets izričito kaže da nije asset |
| Podnaslov i kontakt redovi | iz `salons` (opis, telefon, adresa, Instagram) | sve već postoji, nema novog polja |
| Footer | `© <godina> <ime salona>` + „Napravljeno u Bosni i Hercegovini" | naziv pravnog lica nije dat; kad stigne, mijenja se jedan string |
| „Prijavite problem" | konstanta `supportEmail`, prazna dok ne stigne adresa | ne pretpostavljam tuđi mail; red se sakriva dok je prazna |
| Jezik pravila | bosanski, isti kao ostatak app-e | `.arb` nema drugi jezik, a pravila su vezana za BiH tržište |
| Dužina | kratke sekcije, kao handoff — ne zid teksta | pravila koja niko ne pročita ne štite nikoga |

**Ono što ostaje na tebi:** naziv pravnog lica, `supportEmail`, i pravni pregled teksta prije
submissiona. Ništa od toga ne blokira rad — sve su to stringovi na jednom mjestu.

### Politika privatnosti nije samo ovaj ekran

`docs/01` (§605, §617, korak 29) traži **javnu URL politiku privatnosti po tenantu**, koju servira
Next.js iz Sprinta 3. Ekran u app-i je **ne zamjenjuje** — to piše i u Zamkama task fajla. Ako se
očekuje da ovaj task otključa submission u cijelosti, ne otključava: otključava samo svoj dio.

### Sitnice iz handoffa

- **`SPEC.md` §Assets:** *„No logo asset yet; the »BV« monogram in 5n is a text placeholder."*
  Dakle monogram na `/about-app` je tekst, ne slika — ne traži asset po tenantu.
- Oba ekrana su pushed iz Postavki, pa nose `BackHeader` sa labelom **„Postavke"**, ne „Početna"
  (obrazac iz taska 20; `AppBar` je greška — v. `prototype/ui/README.md`).

### Procjena

1–2 dana iz task fajla je bilo za tri ekrana bez šeme. **Sad je veće:** pravila donose migraciju,
seed, RLS sa negativnim testom, repozitorij i ADR. Računaj **2–3 dana** za `/terms` + `/about-app`
sa pravilima. `/notifications` je sada u obimu, ali samo kao prazno stanje — to je sat vremena,
ne dan. `/privacy` je nova ruta koju task fajl ne spominje; tekst je pisan, ne prepisan, pa
računaj i vrijeme za to.

## Istorija

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
