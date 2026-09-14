# Taskovi — Sprint 2: auth, admin, push i ostatak handoffa

Nastavak [Sprinta 1](../sprint-1/). Redoslijed prati [01 §17](../../docs/01-mvp-spec.md#17-build-order)
korake 12–24, uz tri dopune koje su nastale u Sprintu 1: šema nema kolone koje handoff traži
(task 22), a `prototype/ui/` ima deset ekrana koje niko nije raspisao (18–21).

| # | Task | Blokira | Procjena |
|---|---|---|---|
| [12](12-auth-provideri.md) 🟡 | Supabase Auth provideri + `AuthConfig` po flavoru ([konzole](12-konzole-checklist.md)) | 13, 14 | 2 dana |
| [13](13-client-login-ekran.md) 🟡 | Client: login na kraju booking flowa | 14, 16, 17 | 1–2 dana |
| [14](14-identitet-i-klijent-upsert.md) ✅ | Backend: `AuthIdentity` + `Customer` upsert | 15, 16, 23, 25 | 2 dana |
| [15](15-izolacija-klijent-u-dva-salona.md) ✅ | Dokaz izolacije: isti klijent u dva salona | prvi klijent | 1 dan |
| [16](16-moji-termini-i-otkazivanje.md) ✅ | Client: "Moji termini" + otkazivanje | 25 | 2 dana |
| [17](17-moj-racun-i-brisanje.md) ✅ | Client: **Postavke (5k)**, "Moj račun" + **brisanje računa** | store submission | 2–3 dana |
| [22](22-sema-slike-i-staz.md) ✅ | Šema: slike usluga, staž radnika | 18, 20 | 0.5 dana |
| [18](18-pocetna-i-tab-bar.md) ✅ | Client: Početna po handoffu + **bottom tab bar** | 19, 20, 21 | 2–3 dana |
| [19](19-o-nama-i-usluge.md) ✅ | Client: "O nama" i "Usluge" | — | 1–2 dana |
| [20](20-galerija-recenzije.md) 🟡 | Client: galerija, lightbox, recenzije | — | 2 dana |
| [21](21-obavijesti-i-pravni-ekrani.md) | Client: obavijesti, o aplikaciji, pravila | store submission | 1–2 dana |
| [23](23-admin-login-i-lista.md) | Admin: login, dashboard, lista termina | 24, 25 | 2–3 dana |
| [24](24-admin-akcije-nad-terminima.md) | Admin: potvrdi/odbij/otkaži + ručni termin | 25 | 2 dana |
| [25](25-push-notifikacije.md) | FCM, `Device` registracija, push scenariji | Sprint 3 | 2–3 dana |
| [26](26-gost-i-facebook.md) | Guest flow + Facebook iza flaga | — | 1–2 dana |

**Ukupno: ~23–30 radnih dana.**

## Redoslijed koji nije očigledan

- **12 → 13 → 14 je lanac i ide prvi.** Dok `Customer` upsert ne postoji, `book_appointment` nema
  `customerId` — booking flow iz [taska 11](../sprint-1/11-booking-flow.md) je napisan, ali
  **nijednom nije izvršen protiv prave baze**. Task 14 je jedini koji to zatvara.
- **15 odmah poslije 14, ne na kraju sprinta.** Izolacija se dokazuje dok je upsert svjež; kad se
  na njega naslone admin i push, ispravka je skuplja.
- **22 prije 18 i 20.** Pola dana migracije, a bez nje red usluge ima prazan okvir i Početna se
  piše dvaput.
- **18 prije 19–21.** Tab bar je jedina zajednička komponenta koju `SPEC.md` traži da se gradi
  prva; četiri ekrana ispod nje su lakša kad ona postoji.
- **23 → 24 → 25.** Push se okida na admin akcije; bez njih nema šta slati.
- **17 je uzeo `/settings` (5k), pa je narastao.** Handoff 5k je bio siroče: task fajl 17 ga
  pominje kao referencu ali gradi `/account`, a komentar u `app_router.dart` ga je pripisao tasku
  21 — čiji DoD nabraja samo `/notifications`, `/about-app` i `/terms`. Bez 5k `/account` nema ulaz
  iz aplikacije, a nedostupan ekran za brisanje pada na Apple reviewu. Zato 5k ide u 17, a procjena
  sa 1–2 raste na 2–3 dana. **21 time ne gubi ništa** — njegov DoD 5k nikad nije ni sadržao.

## Šta ovaj sprint zatvara iz prethodnih

| Otvoreno u | Šta | Zatvara |
|---|---|---|
| [11](../sprint-1/11-booking-flow.md) | `book(...)` nikad nije pozvan protiv prave baze | [14](14-identitet-i-klijent-upsert.md) |
| [11](../sprint-1/11-booking-flow.md) | `409` nije izazvan uživo | [14](14-identitet-i-klijent-upsert.md) |
| [11](../sprint-1/11-booking-flow.md) | ~~Usluge nemaju fotografiju, radnici staž~~ | ✅ [22](22-sema-slike-i-staz.md) |
| [11](../sprint-1/11-booking-flow.md) | ~~`book(...)` nikad nije pozvan protiv prave baze~~ | ✅ [14](14-identitet-i-klijent-upsert.md) |
| [11](../sprint-1/11-booking-flow.md) | ~~`409` nije izazvan uživo~~ | ✅ [14](14-identitet-i-klijent-upsert.md) |
| [11](../sprint-1/11-booking-flow.md) | Usluge nemaju fotografiju, radnici staž | [22](22-sema-slike-i-staz.md) |
| [11](../sprint-1/11-booking-flow.md) | Početna nije po handoffu | [18](18-pocetna-i-tab-bar.md) |
| [08](../sprint-1/08-core-api-repozitoriji.md) | ~~Nema `AppointmentRepository`~~ | ✅ [16](16-moji-termini-i-otkazivanje.md) |
| `security.md` | ~~`customers`~~ ✅ / `devices` upis bez validirane funkcije | ✅ [14](14-identitet-i-klijent-upsert.md), [25](25-push-notifikacije.md) |
| `security.md` | Admin `insert` nad `appointments` zaobilazi validaciju slota | [24](24-admin-akcije-nad-terminima.md) |

## Što **nije** u ovom sprintu

Namjerno, po [01 §17](../../docs/01-mvp-spec.md#17-build-order):

- **Admin CRUD nad uslugama, radnicima i radnim vremenom** — Sprint 3, korak 25.
- **Podsjetnici D-1 / H-3** — Sprint 3, traže scheduler i `NotificationLog` iz taska 25.
- **Super admin web konzola** i **store submission** — Sprint 3.
- **Dentalna vertikala** — Sprint 4, i tek nakon tri zadovoljna beauty klijenta.
- **Drugi dizajn za beauty i ostale vertikale.** Barber je 1:1 sa `prototype/ui/`; ostale vertikale
  dobijaju svoj handoff, koji još ne postoji.

## Status

> **12 — Auth provideri (🟡, 2026-09-12).** Kod je gotov i dokazan; blokiran je samo na tuđim
> konzolama. `AuthConfig`/`AuthProvider`/`AuthPlatform`/`AuthSession` u `core_domain`,
> `AuthRepository` ugovor u `core_api`, `auth:` blok u `tenant.yaml` sa validacijom u generatoru,
> Google client ID po flavoru kroz `build_tenant.sh`, redirect URL-ovi i OTP template u
> `supabase/config.toml`. **238 testova PASS** (bilo 215) i **email OTP odigran do kraja** na
> lokalnom stacku — mail nosi šestocifreni kod bez linka, `verify` vraća sesiju.
> Usput je prvi put dokazan i trigger iz taska 02: `auth_identities` dobija red na stvarnu prijavu,
> pa [task 14](14-identitet-i-klijent-upsert.md) nosi manje nego što naslov kaže.
> **Apple i Google nisu odigrani nijednom** — traže tvoje naloge i pravi uređaj; hodogram je
> [12-konzole-checklist.md](12-konzole-checklist.md). Detalji:
> [12-auth-provideri.md](12-auth-provideri.md#status-2026-09-12--🟡-kod-gotov-konzole-čekaju).

> **22 — Šema: fotografije usluga i staž radnika (✅, 2026-09-12).** `services.image_url` i
> `employees.experience_years`, obje nullable jer su prazan okvir i red bez staža **predviđena
> stanja** — salon bez fotografija mora raditi od prvog dana. Seed puni obje kolone i namjerno
> ostavlja po jedan red prazan. `anon` vidi nove kolone (tri nove asercije u
> `rest_public_catalog.ts`) — grantovi iz init migracije su tabelarni, pa nova kolona ulazi sama;
> da su bili kolonski, javni katalog bi tiho izgubio fotografije.
> Na ekranu, iz prave baze: „Barber · 9 godina" i „Barber · 4 godine" — oba bosanska plural oblika.
> **Zamka:** prvi snimak koraka 1 pokazao je četiri prazna okvira, jer se `images.demo.invalid` ne
> razrješava — red sa URL-om izgleda isto kao red bez njega. Dokaz je napravljen privremenim
> usmjeravanjem jednog reda na stvarnu sliku, pa vraćanjem; `seed.sql` nije mijenjan.
> Detalji: [22-sema-slike-i-staz.md](22-sema-slike-i-staz.md#status-2026-09-12--✅-zatvoren).
> **13 — Client: login ekran (🟡, 2026-09-12).** `/auth/login` ima pravo tijelo:
> `SupabaseAuthRepository` u `core_api`, `LoginScreen` sa tri faze (provideri → email → kod),
> `AppointmentHoldCard` izvučena iz koraka 4, `?from=` povratak provjeren naspram `ClientRoute`
> liste. **253 testa PASS** (bilo 238), i **email OTP odigran do kraja u browseru protiv živog
> stacka** — četiri prijave, četiri `auth_identities` reda, mail bez linka.
> Prolaz kroz browser je našao grešku koju testovi nisu mogli: prijava je brisala izbor iz flowa
> (`autoDispose` bez slušaoca u fazi unosa emaila), a sam test je držao vlastitu pretplatu pa bi
> prolazio i nad pokvarenom app-om. Oboje popravljeno i provjereno da test može pasti.
> **`customers` je i dalje 0** — `bookingCustomerIdProvider` vraća `null` jer reda nema, i to je
> tačno ono što [task 14](14-identitet-i-klijent-upsert.md) zatvara.
> **Apple i Google nisu odigrani**: traže pakete kojih nema u `pubspec.yaml` i konzole iz taska 12.
> Detalji: [13-client-login-ekran.md](13-client-login-ekran.md#status-2026-09-12--🟡-email-prijava-radi-i-dokazana-je-nativni-provideri-nisu).


> **14 — `AuthIdentity` + `Customer` upsert (✅, 2026-09-12).** `public.ensure_customer` je drugi i
> zadnji upis iz klijentske app-e, uz `book_appointment`: identitet izvodi iz tokena, salon mora
> doći iz `x-salon-id`, `on conflict do nothing` da ne prepiše ime koje je salon ispravio.
> **Termin je prvi put stvarno nastao iz aplikacije** (`pending`, 16.09. 10:00–10:40, Emir), a
> **`409` je izazvan uživo** — slot zauzet izvana, ekran vraćen na korak 3 sa osvježenom listom.
> Time padaju i dvije 🟡 stavke iz [taska 11](../sprint-1/11-booking-flow.md).
> Dokazano: **82 pgTAP testa** (bilo 66), **70 REST asercija** u tri Deno testa, **256 Dart testova**.
> Tri greške koje su našli testovi i browser, ne čitanje: `not (A and B)` je rupa kad `B` može biti
> `NULL` (zahtjev bez headera je prolazio kroz guard); `revoke ... from public` ne skida `execute`
> jer ga Supabase daje `anon`-u direktno kroz `pg_default_acl` (isti propust je stajao na
> `book_appointment` od taska 05); i „nema klijenta" naspram „još nije stigao" — sinhroni snimak
> `customerId`-a je davao grešku dok je upsert bio u letu.
> Detalji: [14-identitet-i-klijent-upsert.md](14-identitet-i-klijent-upsert.md#status-2026-09-12--✅-zatvoren).


> **15 — Izolacija klijenta između salona (✅, 2026-09-12).**
> `rest_cross_salon_isolation.ts` — **22 asercije, tri stvarna JWT-a**. Jedan čovjek se prijavi i
> rezerviše u oba demo salona; admin salona A ne dobija red salona B ni po `id`, ni po
> `auth_identity_id` (koji **zna**, jer stoji u njegovom vlastitom redu), ni kroz imenovani embed
> na `appointments`, ni kad `x-salon-id` postavi na salon B.
> **Provjereno da test može pasti**: dvije politike pokvarene na dva načina obaraju dvije različite
> asercije — `staff_manage` bez veze sa salonom reda („admin bilo gdje ⇒ admin svugdje") i
> `own_customer` bez `client_salon_id()`. Obje vraćene i provjerene naspram migracije.
> Usput nađeno: kompozitni FK-ovi čine embed dvosmislenim (`PGRST201`, HTTP **300**), pa REST
> testovi moraju tretirati `300` kao grešku — inače prođe kao uspjeh i test pukne kasnije.
> Puna suita: **82 pgTAP testa, 92 REST asercije**.
> Detalji: [15-izolacija-klijent-u-dva-salona.md](15-izolacija-klijent-u-dva-salona.md#status-2026-09-12--✅-zatvoren).


> **16 — „Moji termini" + otkazivanje (✅, 2026-09-12).** `/appointments` po handoffu 5h sa dva
> taba, `AppointmentRepository` (prvi repozitorij nad `appointments`), `AppDialog` u `core_ui` kao
> modal 5p. `cancel_appointment` uzima rok iz `salon_settings.min_cancel_hours` — **rok vrijedi za
> klijenta, ne za salon** — i pamti `cancelled_by`. Odigrano u browseru: prijava, rezervacija
> 22.09. u 13:00, otkazivanje kroz modal; `cancelled_by = customer` i **slot je odmah opet
> slobodan**, provjereno upitom. Dokazano: **97 pgTAP testova** (bilo 82), **276 Dart testova**
> (bilo 256).
> pgTAP je našao da ista NULL rupa iz taska 14 stoji i u `book_appointment` od taska 05 —
> **nije curenje i nikad nije bilo** (za tuđeg klijenta je `owns_identity` FALSE, a
> `NULL and FALSE` je FALSE, provjereno pokretanjem), ali je zatvorena; i da moj vlastiti test
> tvrdi pogrešno: direktan `update` sa klijenta ne baca `42501` nego pogodi nula redova.
> Detalji: [16-moji-termini-i-otkazivanje.md](16-moji-termini-i-otkazivanje.md#status-2026-09-12--✅-zatvoren).


## Dug koji nije task

Sitno, ali ne smije se izgubiti:

- **`tool/gen_ios_flavors.rb` gubi Flutterov `PreActions` blok.** `flutter run` ga sam vrati u
  generisanu scheme i time zaprlja radno stablo; `gen_flavors --check` tu razliku ne vidi.
  Nađeno u tasku 11, detalji u njegovom status bloku.
- **Zlatna brand boja naspram monohromnog handoffa.** Odluka odgođena — v. `tasks/CURRENT.md`.
- **iOS potpisivanje nije postavljeno.** Mašina nema nijedan razvojni certifikat
  (`security find-identity` → `0 valid identities found`), a `Runner.xcodeproj` nema
  `DEVELOPMENT_TEAM` — pa se na **fizički iPhone** ne može instalirati ništa, samo u simulator.
  Kad se Apple nalog prijavi u Xcode, Team ID ide kroz `tenant.yaml` i generator u `xcconfig`, ne
  ručno u `Runner.xcodeproj`. Otvoreno iz taska 04, zajedno sa Android keystoreom.

> **19 — Client: „O nama" i „Usluge" (✅, 2026-09-13).** `/services` je pun cjenovnik **grupisan po
> `category`**, a zaglavlja se crtaju samo kad ima šta da se grupiše — jedna kategorija (ili
> nijedna) daje ravnu listu, tačno kao `09-usluge.png`. Razvrstavanje radi čista funkcija
> `groupByCategory`, koja **ne sortira ponovo**: `ServiceRepository.forSalon` već vraća uzlazno, a
> drugo sortiranje bi bilo dva izvora istine za isti poredak.
> **`SPEC.md` 5b ne završava na `/about`.** Prvi prolaz je ekran napisao po handoffu i ostavio ga
> iza reda „O nama ›" na dnu Početne; u simulatoru se vidjelo šta to znači — priča, radno vrijeme i
> kontakt stoje jedan tap dalje, na ekranu kojem handoff **nijednim nacrtanim ekranom ne daje
> ulaz**. Sadržaj je zato inline na Početnoj, `/about` ostaje kao ruta i kao oblik iz handoffa, a
> sekcije dijele obje strane (`features/about/about_sections.dart`).
> Time je zatvorena i rupa iz taska 18: radno vrijeme i kontakt su od njega bili **nedostupni u
> cijeloj aplikaciji**, a `WorkingHoursCard`/`ContactCard` su stajali bez ijednog korisnika.
> **Radno vrijeme je puna sedmica, ne jedan red iz handoffa** — iz prave baze: subota do 14:00,
> nedjelja zatvoreno. Jedan red je tačan samo za salon koji svaki dan radi isto.
> Dokazano: **361 test PASS** (bilo 326), 35 novih; app dignuta na **iOS simulatoru** protiv živog
> Supabase stacka, i sva tri ekrana snimljena u Chromiumu uz referentne PNG-ove
> (`docs/screenshots/task-19-*`).
> **Zamka koju je našao browser, a testovi nisu mogli:** foto par i Galerija su na Početnoj crtali
> iste dvije fotografije jedna ispod druge — obje sekcije ispravne, obje sa zelenim testom, vidi se
> tek kad stoje na istom ekranu. Par je ostao samo na `/about`, koji mreže nema.
> Nakon pregleda na simulatoru priča je otišla **iznad cjenovnika** (odgovara na „gdje sam došao",
> pitanje koje ima samo prvi otvaralac), a kontakt je izašao iz uokvirene tabele i dobio **ikone**:
> labela „Adresa" pored „Stjepana Radića 12" ne kaže ništa što se već ne vidi, a jede pola širine
> reda. Labela nije nestala nego je otišla u `Semantics`, i test to mjeri.
> **Ostaje otvoreno, ali ne blokira:** `services` nema kolonu za ručni redoslijed (`sort_order`
> migracija, vlastiti task), tapovi na `tel:`, mape i Instagram traže pravi uređaj, a **instalacija
> na telefon je blokirana na Apple nalogu** — certifikat postoji u keychainu, ali Xcode nema
> prijavljen Apple ID pa ne izdaje provisioning profil.
> Detalji: [19-o-nama-i-usluge.md](19-o-nama-i-usluge.md#status-2026-09-13--✅-zatvoren).
