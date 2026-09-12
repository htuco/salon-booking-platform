# Task 11 — Client: booking flow (4 koraka + success)

| | |
|---|---|
| **Procjena** | 3–4 dana |
| **Zavisi od** | [05 — availability engine](../05-availability-engine.md), [10 — home](10-client-home-runtime-branding.md) |
| **Blokira** | Sprint 2 (auth se traži na kraju ovog flowa) |
| **Reference** | [01 §8](../../docs/01-mvp-spec.md#8-booking-rules) · [01 §9](../../docs/01-mvp-spec.md#9-core-user-flows) · [02](../../docs/02-user-flows-wireframes.md) · prototip `src/app/pages/BookingFlow.tsx` |

## Cilj
Klijent od izbora usluge do potvrđenog zahtjeva, bez prijave do zadnjeg koraka, i **bez ijedne linije availability logike u Dartu**.

## Definicija gotovog
- [ ] Četiri koraka po [01 §12](../../docs/01-mvp-spec.md#12-screens): `/book/service` → `/book/employee` → `/book/slot` → `/book/details`, pa `/book/success`
- [ ] Izbor radnika nudi i **"bilo koji"** kad `requireStaffChoice` nije uključen za vertikalu
- [ ] Slotovi dolaze **isključivo** iz backend availability funkcije (task 05). Nula filtriranja, sabiranja buffera ili računanja trajanja u aplikaciji — provjereno pretragom, ne pretpostavkom
- [ ] `bookingGranularity: date_only` podržan: klijent bira samo datum, salon dodjeljuje vrijeme ([05 §4](../../docs/05-vertical-packs.md))
- [ ] Stanje flowa živi u jednom Riverpod provideru; povratak nazad ne gubi izbor, a "restart" ga čisti
- [ ] Slanje ide kroz **validiranu RPC/Edge funkciju**, nikad direktan `insert` sa klijenta
- [ ] **`409 Conflict` je prvoklasno stanje**, ne generička greška: poruka "Ovaj termin je upravo zauzet. Izaberite drugi." i automatski povratak na osvježenu listu slotova
- [ ] Termin nastaje kao `pending`; success ekran to jasno kaže — zahtjev poslan, salon potvrđuje ([01 §18](../../docs/01-mvp-spec.md#18-ključne-odluke))
- [ ] Svi tekstovi kroz `vertical.terms.*` i `.arb`; success ekran koristi `flutter_animate`/`confetti` kao u prototipu
- [ ] Widget testovi: prelaz kroz korake, `409` putanja, `date_only` grana, prazan dan (nema slobodnih termina)

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
