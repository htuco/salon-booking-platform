# Trenutni task: 05 — Availability engine na backendu + testovi

Puni task: [`tasks/05-availability-engine.md`](05-availability-engine.md) · Učitano: 2026-09-11 · Grana: `feat/availability-engine`

## Status

Gotov — CI zelen ([run 34542304820](https://github.com/htuco/salon-booking-platform/actions/runs/34542304820)), ceka merge PR-a #6

## Ciljevi

- [x] `public.get_available_slots(salon, usluga, datum, radnik?)` vraća slobodna vremena početka
- [x] Uzima u obzir radno vrijeme i pauze, `pending`/`confirmed` termine, blokade, `buffer_minutes`,
      `slot_step_minutes`, `min_advance_booking_hours`, `max_advance_booking_days`
- [x] `date_only` mod: `public.get_available_dates(...)` vraća datume, ne vremena
- [x] `public.book_appointment(...)` re-validira slot **u istoj transakciji** i vraća konflikt kao
      `409` kad je slot u međuvremenu zauzet
- [x] Zaštita od utrke na nivou baze — exclusion constraint, ne samo provjera prije upisa
- [x] pgTAP testovi: prazan raspored, pun dan, buffer koji se preklapa, blokada, pauza, granica
      `min_advance_booking_hours`, `date_only`, dvostruka rezervacija istog slota, autorizacija
- [x] Testovi prolaze na CI-ju (`Supabase tests`)
- [x] Nula availability logike u Dartu — provjereno pretragom

## Napomene

- **Ništa od ovoga još ne postoji** — `supabase/migrations/` ima samo `init_schema` i
  `auth_identity`; nema nijedne funkcije za dostupnost ni RPC-a za rezervaciju.
- **`btree_gist` je već instaliran** u `init_schema` (`extensions` shema) — postavljen upravo zbog
  exclusion constrainta, koji još nije napisan.
- Postavke po salonu su u `salon_settings` (`slot_step_minutes`, `buffer_minutes`,
  `min_advance_booking_hours`, `max_advance_booking_days`, `pending_expiry_hours`,
  `booking_granularity`, `require_staff_choice`, `timezone`).
- **Vremena su lokalna zidna vremena salona**, ne UTC; `working_hours.day_of_week` je ISO 1–7.
  Poređenje sa `now()` ide kroz `at time zone salon_settings.timezone`.
- **`security.md` navodi ovo kao otvorenu rupu**: klijentski upisi trebaju validiranu RPC funkciju,
  a bazna šema dozvoljava direktne admin izmjene termina bez provjere slota. Ovaj task je zatvara —
  `security.md` se ažurira u istoj promjeni.
- Bez Dockera lokalno, pa je dokaz CI job `Supabase tests`. Dok nije zelen: "napisano, čeka CI".

## Istorija

- **01 — Skeleton repozitorija** (2026-08) — melos workspace, `apps/client`, `apps/admin`, `packages/core_*`, `supabase init`. `melos bootstrap`/`analyze`/`test` prolaze.
- **02 — Supabase šema + RLS** (2026-09-10) — 15 tabela, RLS na svakoj, `private.*` autorizacioni helperi, seed sa dva demo salona i tri vertikale. Dokazano na CI-ju: 38 pgTAP testova + 24 REST asercije sa dva stvarna JWT-a.
- **03 — Flavor sistem** (2026-09-10) — Android i iOS flavori za dva demo tenanta, ikone po flavoru, generatori u `tool/`. Dokazano na artefaktima: `aapt2 dump badging`, oba APK-a na istom emulatoru istovremeno, `CFBundleIdentifier`/`CFBundleDisplayName`/ikona iz gotovog iOS bundlea.
- **04 — CI pipeline** (2026-09-10, 🟡) — `tool/build_tenant.sh` kao jedina ulazna tačka u build, `release-artifacts` job pravi AAB za oba tenanta na ručni trigger, `BUILD_NUMBER` iz CI-ja stiže do artefakta (`versionCode='42'` naspram `'1'`). Ostaju keystore i stvarne Supabase vrijednosti — oboje traži naloge.
