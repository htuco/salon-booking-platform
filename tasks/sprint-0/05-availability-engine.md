# Task 05 — Availability engine na backendu + testovi

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [02 — schema + RLS](02-supabase-schema-rls.md) |
| **Blokira** | svaki booking ekran u Sprint 1 |
| **Reference** | [01 §8](../../docs/01-mvp-spec.md#8-booking-rules) · [01 §16.1](../../docs/01-mvp-spec.md#161-odluka-supabase-ne-firebase-) |

## Cilj
Logika "koji su slobodni termini" postoji **na backendu**, testirana, prije nego što se napiše ijedan piksel booking flow-a. Ovo je srce proizvoda — [01 §16.1](../../docs/01-mvp-spec.md#161-odluka-supabase-ne-firebase-) kaže da je ovo "odlučujući argument" za cijeli izbor Supabase-a nad Firebase-om, pa logika ne smije nikad procuriti u Flutter kod.

## Definicija gotovog
- [x] Postgres funkcija (ili Edge Function) `get_available_slots(salon_id, service_id, employee_id?, date)` vraća listu slobodnih termina
- [x] Uzima u obzir: `WorkingHour` (radno vrijeme + pauze), postojeće `Appointment` zapise (`pending`, `confirmed` blokiraju slot; `cancelled` ne), `BlockedSlot`, `bufferMinutes` i `slotStepMinutes` iz `SalonSettings`
- [x] Podržava oba moda iz `SalonSettings.bookingGranularity`: `exact_slot` (klijent bira tačan termin) i `date_only` (klijent bira samo datum, salon dodijeli vrijeme — [05 vertical-packs §4](../../docs/05-vertical-packs.md))
- [x] Poštuje `minAdvanceBookingHours` i `maxAdvanceBookingDays`
- [x] `POST /appointments` radi **re-validaciju slota** na serverskoj strani prije upisa (race condition zaštita — dva klijenta ne mogu zauzeti isti slot), vraća `409 Conflict` ako je slot zauzet u međuvremenu
- [x] Unit testovi (pgTAP ili Deno) pokrivaju: prazan raspored, potpuno zauzet dan, preklapajući buffer, blocked slot, granica `minAdvanceBookingHours`, `date_only` mod
- [x] Testovi prolaze u CI-ju (nastavak CI koraka iz [04](04-ci-pipeline.md))
- [x] Nula availability logike postoji igdje u Flutter kodu — provjereno code review-om, ne pretpostavkom

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
Ako se ovo piše dok se paralelno pravi Flutter ekran, prirodno je "privremeno" staviti dio logike u Dart (npr. filtriranje slotova u klijentu) da bi se brže vidio rezultat na ekranu — a to "privremeno" ostaje. [01 §8.1](../../docs/01-mvp-spec.md#8-booking-rules) je eksplicitna odluka da availability logika nikad ne smije biti u app-u; ovaj task postoji da se ta odluka ispoštuje od prvog reda koda, ne popravi nakon prvog buga sa duplim rezervacijama.

---

## Status (2026-09-11) — ✅ zatvoren

Migracija `20260911090000_availability_engine.sql` + `supabase/tests/002_availability.test.sql`.
Dokaz je bio CI, jer lokalno tada nije bilo Dockera *(od 12.09.2026. radi lokalno: `./tool/test_supabase.sh`)*:
[run 34542304820](https://github.com/htuco/salon-booking-platform/actions/runs/34542304820) —
`All tests successful. Files=2, Tests=66, Result: PASS` (38 postojećih + 28 novih), plus REST
izolacija sa dva stvarna JWT-a.

**Šta je isporučeno**

| | |
|---|---|
| `get_available_slots(salon, usluga, datum, radnik?)` | radno vrijeme po radniku uz fallback na salonski red, pauze, `pending`/`confirmed`, blokade, buffer, korak, `min/max_advance` |
| `get_available_dates(...)` | datumi sa bar jednim slotom, za `date_only` vertikale; raspon ograničen na 90 dana |
| `book_appointment(...)` | eksplicitna autorizacija, re-validacija slota u istoj transakciji, dodjela radnika kad nije izabran, `PT409` → HTTP 409 |
| `appointments_no_overlap` | exclusion constraint — utrku ne rješava provjera prije upisa |

**Tri stvari koje je CI našao, a lokalno se ne bi vidjele**

1. `case when … then 'manual' else 'app' end` se tipizira kao `text`, a kolona je enum
   `appointment_source` — svaki poziv je padao na `INSERT`-u. Treba eksplicitan kast.
2. Očekivani broj slobodnih slotova je bio pogrešan u testu, ne u kodu: termin 10:00–10:30 sa
   bufferom 5 zauzima `[10:00, 10:35)`, a **i kandidat nosi buffer** (35 min), pa otpada pet
   početaka (09:30–10:30), ne četiri.
3. `throws_ok` sa tri argumenta poredi **poruku greške**, ne opis testa — test constrainta je
   padao iako constraint radi. Četvrti argument je opis; `NULL` na mjestu poruke znači "ne
   provjeravaj tekst".

**Ostalo za sljedećeg**

- Ponašanje pod stvarnom konkurencijom (dva paralelna poziva) nije mjereno — dokazana je garancija
  constrainta na sekvencijalnom upisu.
- Vremenske zone testirane samo za `Europe/Sarajevo` (jedina vrijednost u seedu).
- Dart strana (repozitorij nad ovim funkcijama) je [task 08](../sprint-1/08-core-api-repozitoriji.md).
- Upis `customers` i `devices` i dalje nema validiranu funkciju — v. `.claude/docs/security.md`.
