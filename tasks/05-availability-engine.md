# Task 05 — Availability engine na backendu + testovi

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [02 — schema + RLS](02-supabase-schema-rls.md) |
| **Blokira** | svaki booking ekran u Sprint 1 |
| **Reference** | [01 §8](../docs/01-mvp-spec.md#8-booking-rules) · [01 §16.1](../docs/01-mvp-spec.md#161-odluka-supabase-ne-firebase-) |

## Cilj
Logika "koji su slobodni termini" postoji **na backendu**, testirana, prije nego što se napiše ijedan piksel booking flow-a. Ovo je srce proizvoda — [01 §16.1](../docs/01-mvp-spec.md#161-odluka-supabase-ne-firebase-) kaže da je ovo "odlučujući argument" za cijeli izbor Supabase-a nad Firebase-om, pa logika ne smije nikad procuriti u Flutter kod.

## Definicija gotovog
- [ ] Postgres funkcija (ili Edge Function) `get_available_slots(salon_id, service_id, employee_id?, date)` vraća listu slobodnih termina
- [ ] Uzima u obzir: `WorkingHour` (radno vrijeme + pauze), postojeće `Appointment` zapise (`pending`, `confirmed` blokiraju slot; `cancelled` ne), `BlockedSlot`, `bufferMinutes` i `slotStepMinutes` iz `SalonSettings`
- [ ] Podržava oba moda iz `SalonSettings.bookingGranularity`: `exact_slot` (klijent bira tačan termin) i `date_only` (klijent bira samo datum, salon dodijeli vrijeme — [05 vertical-packs §4](../docs/05-vertical-packs.md))
- [ ] Poštuje `minAdvanceBookingHours` i `maxAdvanceBookingDays`
- [ ] `POST /appointments` radi **re-validaciju slota** na serverskoj strani prije upisa (race condition zaštita — dva klijenta ne mogu zauzeti isti slot), vraća `409 Conflict` ako je slot zauzet u međuvremenu
- [ ] Unit testovi (pgTAP ili Deno) pokrivaju: prazan raspored, potpuno zauzet dan, preklapajući buffer, blocked slot, granica `minAdvanceBookingHours`, `date_only` mod
- [ ] Testovi prolaze u CI-ju (nastavak CI koraka iz [04](04-ci-pipeline.md))
- [ ] Nula availability logike postoji igdje u Flutter kodu — provjereno code review-om, ne pretpostavkom

## Koraci
1. Napiši SQL funkciju koja za dati salon/uslugu/radnika/datum vraća sve moguće slotove na osnovu `WorkingHour`
2. Oduzmi zauzete intervale: `Appointment` (status `pending`/`confirmed`) + `BlockedSlot`, sa `bufferMinutes` primijenjenim prije/poslije svakog
3. Primijeni `slotStepMinutes` (granularnost prikaza — npr. slotovi na svakih 15 min čak i ako je usluga 45 min)
4. Primijeni `minAdvanceBookingHours` (npr. ne prikazuj slotove unutar 2h od sada) i `maxAdvanceBookingDays`
5. Grana za `bookingGranularity = date_only`: vrati samo dostupne datume, ne vremena
6. Napiši `POST /appointments` Edge Function ili RPC koji re-poziva availability provjeru unutar iste transakcije prije `INSERT`-a, sa exclusion constraintom ili `SELECT ... FOR UPDATE` da spriječi race condition
7. Napiši testove za sve slučajeve iz DoD liste
8. Commit: "feat(db): availability engine + conflict-safe booking + tests"

## Zašto prije UI-ja, ne usput
Ako se ovo piše dok se paralelno pravi Flutter ekran, prirodno je "privremeno" staviti dio logike u Dart (npr. filtriranje slotova u klijentu) da bi se brže vidio rezultat na ekranu — a to "privremeno" ostaje. [01 §8.1](../docs/01-mvp-spec.md#8-booking-rules) je eksplicitna odluka da availability logika nikad ne smije biti u app-u; ovaj task postoji da se ta odluka ispoštuje od prvog reda koda, ne popravi nakon prvog buga sa duplim rezervacijama.
