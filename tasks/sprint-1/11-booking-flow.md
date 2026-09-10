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
