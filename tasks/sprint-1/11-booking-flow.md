# Task 11 — Client: booking flow (4 koraka + success)

| | |
|---|---|
| **Procjena** | 3–4 dana |
| **Zavisi od** | [05 — availability engine](../05-availability-engine.md), [10 — home](10-client-home-runtime-branding.md) |
| **Blokira** | Sprint 2 (auth se traži na kraju ovog flowa) |
| **Reference** | [01 §8](../../docs/01-mvp-spec.md#8-booking-rules) · [01 §9](../../docs/01-mvp-spec.md#9-core-user-flows) · [02](../../docs/02-user-flows-wireframes.md) · [`prototype/ui/SPEC.md`](../../prototype/ui/SPEC.md) ekrani 5c–5g · prototip `prototype/wireframe/src/app/pages/BookingFlow.tsx` |

## Cilj
Klijent od izbora usluge do potvrđenog zahtjeva, bez prijave do zadnjeg koraka, i **bez ijedne linije availability logike u Dartu**.

## Definicija gotovog
- [x] Četiri koraka po [01 §12](../../docs/01-mvp-spec.md#12-screens): `/book/service` → `/book/employee` → `/book/slot` → `/book/details`, pa `/book/success`
- [x] Izbor radnika nudi i **"bilo koji"** kad `requireStaffChoice` nije uključen za vertikalu
- [x] Slotovi dolaze **isključivo** iz backend availability funkcije (task 05). Nula filtriranja, sabiranja buffera ili računanja trajanja u aplikaciji — provjereno pretragom, ne pretpostavkom
- [x] `bookingGranularity: date_only` podržan: klijent bira samo datum, salon dodjeljuje vrijeme ([05 §4](../../docs/05-vertical-packs.md))
- [x] Stanje flowa živi u jednom Riverpod provideru; povratak nazad ne gubi izbor, a "restart" ga čisti
- [~] Slanje ide kroz **validiranu RPC/Edge funkciju**, nikad direktan `insert` sa klijenta — put je takav u kodu i pokriven testom, ali `book_appointment` nije nijednom pozvan protiv prave baze
- [~] **`409 Conflict` je prvoklasno stanje**, ne generička greška: poruka "Ovaj termin je upravo zauzet. Izaberite drugi." i automatski povratak na osvježenu listu slotova — dokazano testom ekrana, **nije izazvano uživo** (korak 4 iz Koraka)
- [x] Termin nastaje kao `pending`; success ekran to jasno kaže — zahtjev poslan, salon potvrđuje ([01 §18](../../docs/01-mvp-spec.md#18-ključne-odluke))
- [x] Svi tekstovi kroz `vertical.terms.*` i `.arb`; success ekran koristi `flutter_animate`/`confetti` kao u prototipu
- [x] Widget testovi: prelaz kroz korake, `409` putanja, `date_only` grana, prazan dan (nema slobodnih termina)

## Koraci
1. Router + provider stanja flowa prije prvog ekrana — inače svaki korak nosi svoje parametre kroz konstruktor i četvrti postane neodrživ
2. Ekran po ekran, svaki sa prazno/greška/učitavanje stanjima
3. Poziv availability funkcije kroz `core_api` repozitorij; slot lista se osvježava pri povratku na korak
4. Slanje + `409` putanja; namjerno izazovi konflikt (dva zahtjeva na isti slot) i dokaži ponašanje
5. Success ekran + povratak na home
6. Commit: `feat(client): booking flow sa 409 handlingom`

## Zamke
- **Login se traži tek na kraju** ([06 §1.1](../../docs/06-auth-login-flow.md)); do tada je sve javno. Ne ubacuj guard na `/book/*` — to je odluka koja se ne otvara.
- **Broj telefona se ne traži.** Ako se pojavi polje za telefon u koraku "podaci", to je greška u razumijevanju flowa ([06 §3.1](../../docs/06-auth-login-flow.md)).
- Iskušenje ovog taska je "privremeno" filtrirati slotove u Dartu da bi se brže vidio rezultat. To je tačno ono što [task 05](../05-availability-engine.md) postoji da spriječi.
- Auth dolazi u Sprintu 2; do tada zadnji korak radi sa guest putanjom ili mock identitetom, ali **struktura poziva mora biti ista** kao kad auth stigne.

---

## Status — djelimično (ne-UI sloj gotov)

Urađen je **sloj ispod ekrana**; četiri ekrana i success ekran nisu dio ove promjene i task
ostaje otvoren. Grana `feat/booking-repozitorij-availability`.

### Šta je gotovo

- **`BookingRepository`** (`packages/core_api/lib/src/booking/`) — prvi repozitorij koji piše
  u bazu. `availableSlots`, `availableDates`, `book`; sve tri na `rpc`, nijedna na `from(...)`.
- **`AvailableSlot`** u `core_domain`, sa `distinctTimes`/`employeesAt` za "bilo koji radnik" —
  funkcija tada vrati isto vrijeme po svakom slobodnom radniku, pa bi bez svođenja korisnik
  vidio "09:00" dvaput.
- **`BookingFlowState` + `BookingFlowNotifier`** (`apps/client/lib/src/features/booking/`) —
  jedan `autoDispose` provider za sva četiri koraka, sa pravilima brisanja izbora.
- **`availableSlotsProvider` / `availableDatesProvider`** kao `family`, sa tipiziranim ključem.
- **Ispravljeno mapiranje konflikta** — v. Dokazano.

### Dokazano

Lokalno: **205 testova PASS** (bilo 165), `melos run analyze` čist. 40 novih testova.
**Na CI-ju još nije potvrđeno**, kao ni na uređaju.

DoD stavka "nula availability logike u Dartu" provjerena **pretragom**, ne pretpostavkom:
`grep` za `buffer_minutes|duration_minutes|slotStep|minAdvance` po `core_api/lib` i
`client/lib` vraća samo čitanje kolona i formatiranje za prikaz ("45 min") — nijedan izračun.

**Nađena greška koju bi ekran otkrio tek u produkciji:** `book_appointment` diže konflikt sa
`errcode = 'PT409'`, a `mapError` je mapirao samo `409`, `23P01` i `23505`. Postgres klasu `PT`
prevodi u HTTP status iz zadnja tri znaka, pa je **odgovor** 409 — ali `PostgrestException.code`
zadržava `PT409`. Konflikt bi zato ispao `ServerError`: korisnik na zauzet termin dobije
"nešto nije u redu" umjesto osvježene liste, a `switch` nad `sealed ApiError` ne bi ništa
prijavio jer je `ConflictError` obrađen — samo se nikad ne bi desio. Isto za `PT404`.

### Odluke

- **Stanje flowa ne nosi listu slotova.** Samo identifikatori i vrijeme — to je sve što
  `book_appointment` traži. Keširana lista bi značila da korisnik nakon povratka nazad bira iz
  zastarjelog spiska i dobije `409` na potvrdi, tj. tačno ono što flow postoji da izbjegne.
- **`employeeChosen` je odvojen od `employeeId != null`.** "Bilo koji radnik" je legitiman
  izbor sa `null` radnikom; uslov nad `employeeId` bi zaključao korisnika na drugom koraku svaki
  put kad `requireStaffChoice` nije uključen.
- **Promjena usluge briše radnika i termin** (`clearFrom`). Druga usluga ima drugo trajanje i
  moguće druge radnike, pa zadržan slot preživi do potvrde i tamo padne kao `409` koji izgleda
  kao utrka, a zapravo je naša greška.
- **`autoDispose`** da izlazak iz `/book/*` čisti flow — inače prošli pokušaj dočeka korisnika
  sa datumom koji je u međuvremenu prošao.

### Ostalo za sljedećeg

- **Sva četiri ekrana i success ekran.** Router i dalje vodi na `PlaceholderScreen`.
- **Komponente `DateStrip` i `StepProgressBar`** u `core_ui` — i dalje ne postoje.
- **`flutter_animate`/`confetti`** nisu dodani u `pubspec.yaml`.
- **`book(...)` nije nijednom stvarno pozvan.** Testovi gađaju mapiranje odgovora, ne mrežu; RPC
  poziv je dokazan samo pgTAP-om iz taska 05. Prvi stvarni poziv traži Supabase vrijednosti i
  prijavljenog korisnika — `book_appointment` je grantovan samo roli `authenticated`, a auth
  dolazi tek u Sprintu 2.
- **`409` putanja nije izazvana uživo.** Korak 4 iz Koraka ("namjerno izazovi konflikt, dva
  zahtjeva na isti slot") ostaje neodrađen — dokazano je samo da se `PT409` mapira u
  `ConflictError`, ne i da ekran na njega osvježi listu.
- **`customerId` još nema odakle doći.** `book(...)` ga traži kao parametar, a upis u `customers`
  nema validiranu funkciju (v. "Šta još nije zatvoreno" u `security.md`).

### CI je blokiran (nije zbog koda)

Oba workflowa (`Flutter`, `Supabase tests`) padaju **prije nego što išta pokrenu**, za 5–6
sekundi, sa porukom GitHub Actionsa:

> The job was not started because recent account payments have failed or your spending limit
> needs to be increased.

Nije posljedica ove promjene: run na `main`-u u 19:36 pao je isto, a zadnji zeleni run je u 19:23
(task 10). Rerun odmah ponovo pada. Odblokira se u **Billing & plans** na `htuco` nalogu, pa
`gh run rerun` na PR-u [#12](https://github.com/htuco/salon-booking-platform/pull/12).

Dok to ne prođe, za ovu granu **ne postoji CI dokaz** — vrijedi samo lokalnih 205 testova.

---

## Status — UI sloj (2026-09-12)

Grana `feat/booking-flow-ekrani`, PR [#18](https://github.com/htuco/salon-booking-platform/pull/18).
Nastavak na ne-UI sloj ispod (PR #17).

### Šta je gotovo

- **Pet ekrana** u `apps/client/lib/src/features/booking/`: `service`, `employee`, `slot`,
  `details`, `success`, uz `BookingStepScaffold` kao zajedničku kičmu (nazad, "Korak N od 4",
  traka napretka, CTA). Router više ne vodi `/book/*` na `PlaceholderScreen`.
- **`BookingSubmitNotifier`** — slanje, mapiranje ishoda i invalidacija liste nakon konflikta.
- **`DateStrip` i `StepProgressBar`** u `core_ui`, dodani u postojeći `_DemoEkran` pa prolaze
  iste provjere kontrasta i dodirne mete u obje palete kao i ostale komponente.
- **`BookingFlowState.withoutStartTime()`** — jedina izmjena ne-UI sloja; trebala je za `409`.

### Dokazano

Lokalno: `melos run analyze` čisto (5/5 paketa), `dart format --set-exit-if-changed` 0 promjena,
`dart run tool/gen_flavors.dart --check` ažurno, **`melos run test` — 215 testova PASS** (bilo 205).
`./tool/verify_clean.sh` prolazi **iz čistog klona** — dokaz koji je ranije davao CI job.

Osam novih widget testova: prelaz kroz korake, guard na deep linku, preselekcija iz `?serviceId=`,
prazan dan, `date_only` grana, `409` putanja i success ekran.

**Vizuelni dokaz u pravom Chromiumu**, oba tenanta, `demo_main.dart` web build —
[`docs/screenshots/task-11-*`](../../docs/screenshots/):

| Šta se vidi | Barber (zlatna tamna) | Beauty (roze svijetla) |
|---|---|---|
| Korak 1, preselektovana usluga | `task-11-korak1-usluga-barber.png` | `task-11-korak1-usluga-beauty.png` |
| Korak 2, "Bilo ko od nas" prvi | `task-11-korak2-radnik-barber.png` | — |
| Korak 3, traka datuma + slotovi | `task-11-korak3-termin-barber.png` | `task-11-korak3-termin-beauty.png` |
| Korak 4, sažetak | `task-11-korak4-sazetak-barber.png` | `task-11-korak4-sazetak-beauty.png` |
| Success, "Na čekanju" | `task-11-success-barber.png` | `task-11-success-beauty.png` |

**Pokrenuto i na iOS simulatoru** (iPhone 17, iOS 26.3) iz flavor builda
`ba.nasadomena.barberstudiovitez`: home i prvi korak flowa se iscrtavaju u brand temi, sa ikonom
flavora na springboardu — `task-11-ios-sim-home-barber.png`, `task-11-ios-sim-korak1-barber.png`.
Time pada stavka "ništa nije pokrenuto na uređaju ni emulatoru", otvorena od taska 09.

Browser je potvrdio četiri stvari koje widget test ne može: **preselekcija iz `?serviceId=` stvarno
radi** (kartica je označena bez drugog tapa), **nedjelja je u traci prigušena i ne prima tap**,
**`distinctTimes` radi** (demo vraća dva radnika po vremenu, mreža pokazuje svaki termin jednom), i
**terminologija se mijenja po vertikali** — "Usluga/Barber" naspram "Tretman/Stilistica" na istom
kodu.

**Screenshot je našao grešku koju je zelena suita propustila** — treći put u ovom projektu, nakon
taskova 07 i 10. Korak 2 je u demo buildu prikazivao "Lista trenutno nije dostupna" umjesto
radnika: `demo_main.dart` nije override-ovao `employeeServiceLinksProvider`, pa je provider
posegnuo za `Supabase.instance`. Widget testovi su ga override-ovali i ništa nisu prijavili.

### Odluke

- **Guard je u ekranu, ne `go_router` redirect.** Redirect bi morao čitati `autoDispose` stanje pri
  svakoj promjeni rute i vraćati korisnika usred navigacije. Deep link na `/book/slot` bez izabrane
  usluge zato prikaže prazno stanje sa izlazom na prvi nepopunjen korak.
- **Korak 4 nema polja za telefon, iako ga `prototype/ui/SPEC.md` 5f crta.** `docs/06 §3.1` je
  izričit da se telefon ne traži nigdje. Gdje se SPEC i docs ne slažu oko *flowa*, docs je jači;
  SPEC ostaje izvor istine za oblik. Ako se ovo mijenja, to je ADR, ne izmjena koda.
- **CTA bez identiteta vodi na prijavu, ne šalje.** `bookingCustomerIdProvider` je danas uvijek
  `null` u pravoj app-i — `book_appointment` traži postojećeg klijenta, a upsert klijenta dolazi
  sa auth radom (Sprint 2). Struktura poziva je već ista.
- **`409` zadržava dan, briše samo vrijeme.** `clearFrom(BookingStep.slot)` bi oborio i datum i
  napomenu, a zauzeto je vrijeme — ne dan.

### Ostalo za sljedećeg

- **`book(...)` i dalje nije nijednom pozvan protiv prave baze.** Testovi gađaju mock repozitorij;
  RPC je dokazan samo pgTAP-om iz taska 05. Traži Supabase vrijednosti i prijavljenog korisnika.
- **`409` nije izazvan uživo** — dva stvarna zahtjeva na isti slot. Dokazano je ponašanje ekrana na
  `ConflictError`, ne da ga baza digne u utrci.
- **Kroz flow se na simulatoru nije kliktalo.** App je pokrenut i ekrani se iscrtavaju, ali
  automatizacija tapova nad Simulatorom traži accessibility dozvolu za terminal, koju dajem samo ja
  ručno. Prelaz kroz korake je dokazan u Chromiumu i widget testovima. Na **fizičkom uređaju** nije
  pokrenuto ništa.
- **Generator iOS schema gubi Flutterov `PreActions` blok.** `Runner.xcscheme` (Flutterov, nije
  generisan) ima "Run Prepare Flutter Framework Script"; generisani `barberstudiovitez.xcscheme` i
  `beautystudiotravnik.xcscheme` ga nemaju, pa ga `flutter run` sam ubaci i time zaprlja radno
  stablo. Vratio sam izmjenu — generisani fajl se ne edituje rukom — ali drift se vraća pri svakom
  `flutter run` na svježem klonu. **Popravka je u `tool/gen_ios_flavors.rb`**: neka prenese
  `PreActions` iz `Runner.xcscheme`. Usput: `gen_flavors --check` ovu razliku **ne vidi**, pa je
  i to rupa u provjeri. Nađeno pokretanjem na simulatoru, nije dio ovog taska.

- **`AppTextField` iz `docs/02 §16` i dalje ne postoji**; napomena u koraku 4 je goli `TextField`.
  Kandidat za prvi sljedeći ekran koji ima unos.
- **Konfete na svijetloj paleti su jedva vidljive** (roze na bijelom). Kozmetika, ne greška.
- **CI ne može potvrditi ništa od ovoga** dok naplata na `htuco` nalogu blokira workflowove.
