# Supabase implementation notes

Implemented schema and tests are not proof of execution. Run the commands below against a working local Supabase/Docker environment and record the actual output in root STATUS.md.

## Commands

```sh
supabase start
supabase db reset
supabase test db
# Export SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY
# from the LOCAL output of supabase status -o env (never commit those values).
deno run --allow-env --allow-net supabase/tests/rest_isolation.ts
```

The REST script refuses remote hosts, creates two real Auth users, logs in to receive two JWTs, creates both customers in both salons, checks context/identity isolation, and removes only its own UUID fixtures. The pgTAP test runs entirely inside a rollback transaction. Secrets are never printed by these tests.

## Schema/API contracts

- Public table names and fields are snake_case. Sve aplikacijske tabele imaju uključen RLS.
- Deterministic tenants: Barber Studio Vitez = 550e8400-e29b-41d4-a716-446655440000; Beauty Studio Travnik = 550e8400-e29b-41d4-a716-446655440001.
- Services IDs end in 1..4 (barber) and 5..8 (beauty), prefix 10000000-0000-4000-8000-. Employees end in 1..2 and 3..4, prefix 20000000-0000-4000-8000-.
- Staff JWTs require app_metadata.role = salon_admin and app_metadata.salon_id, PLUS a matching public.users row. A super_admin needs both its trusted claim and database membership. user_metadata is only display data.
- Each client request for private data requires x-salon-id. It is validated as an active salon and combined with the authenticated user's identity. This header chooses the current app context; it never grants ownership or admin rights.
- Public browsing of active salons, active services/employees, mappings, schedules and settings requires no login. Anonymous users have no write grants.
- `services` writes use `create_service`, `update_service` and `set_service_active`; authenticated
  has no direct insert/update/delete grant. Active services remain public catalog, while inactive
  rows are visible only to staff of their salon. Deactivation preserves appointments and employee
  mappings. Appointments snapshot service name, numeric price and duration at insert time so later
  price-list edits affect only future bookings.
- `availability_signals` is the only public Realtime availability signal: it exposes only
  `(salon_id, revision_id)` for an active salon. Triggers rotate the opaque UUID after changes to
  services, employees, mappings, schedules, appointments, blocked slots or booking settings; the
  client then re-runs `get_available_slots`. Appointment rows remain private.
- Admins read per-salon customers/appointments. Global auth_identities rows cannot be read by staff JWTs. No API lists salons for an identity.
- Supabase Auth insert/update automatically upserts auth_identities. Account deletion/anonymization and booking/customer RPCs belong to subsequent migrations.
- Composite tenant foreign keys prevent mixing an employee/service/customer/device from another salon, even when a tenant ID is present in a forged payload.
- Client appointment writes go through `public.book_appointment`: it re-validates the slot, assigns an employee, and raises `PT409` on conflict. Task 24 revoked direct admin insert/update. `ensure_customer` validates customer upsert; task 25 adds validated device registration/unregistration.
- `book_appointment` decides the new row's `status` from `salon_settings.booking_mode` (task 37). `manual` -> `pending` plus `pending_expires_at = now() + pending_expiry_hours`; `auto` -> `confirmed` with `pending_expires_at` null. A missing `salon_settings` row falls back to `manual`. An admin caller is always `confirmed` regardless of the setting, because a salon does not wait for its own answer. **`source` is independent of that**: a client booking stays `source = 'app'` in both modes, and only a salon-entered appointment is `'manual'` — the two columns answer different questions. Switching the mode never touches appointments that already exist.
- Appointment device_id is the UUID FK to devices.id; devices.device_id is the install identifier. appointments.auth_identity_id must match its referenced customer's identity.
- Working hours use ISO weekdays 1=Monday to 7=Sunday. date/start_time/end_time are salon-local wall times. timezone defaults to Europe/Sarajevo.
- salon_builds.build_status/build_url are runtime build tracking fields separate from actual store status. No store status is marked live by seed.
- Reviews are read-only for the client app: anon and authenticated hold `select` only, writes belong to staff via `staff_manage`. `public.salon_rating_summary` is a `security_invoker` view exposing average/total/histogram per salon; a salon without reviews has no row there, never a row of zeroes.
- Legal text lives in two tables (docs/adr/0009). `public.app_policies` has **no `salon_id`**: it holds the platform sections of the terms and the entire privacy policy, is readable by `anon`, and is writable only by `private.is_super_admin()`. `public.salon_policies` holds the salon-authored terms sections, is readable per active salon, and is CRUD-able by `private.is_admin(salon_id)`. `check (document = 'terms')` keeps the privacy policy platform-only. The displayed section number (`01..NN`) is **not stored** — it is the position in the merged, `sort_order`-ordered list, platform first on a tie. Bodies may carry `{minCancelHours}`, `{phone}`, `{email}` and `{appointmentSingular}`, which the client fills from live data; an unresolved placeholder is left visible on purpose.
- Gallery photos stay in `salons.gallery_urls` (jsonb array, array order is display order). There is no `gallery_photos` table — see docs/adr/0008.

## Assumptions where documentation is incomplete

- Password hashes are exclusively in Supabase auth.users; public.users has no redundant password_hash. Its id is the Auth user UUID.
- Both salons have the generic sample schedule from spec section 6.3: Mon–Fri 09:00–17:00, Sat 09:00–14:00, Sun closed. No street address, phone or social URL was invented.
- Every seeded employee can perform every service in their own demo salon.
- Barber palette is #C6A667 / #171717; beauty palette is #B76E79 / #FFF5F5. Both demo tenants use Pro so both Android/iOS factory paths are exercised. Branding copy is demo text.
- The vertical tables in the source lost checkmark glyphs. For MVP barber/beauty/generic: optional staff choice, prices and team on; recall off; gallery on for barber/beauty and off for generic.
- Additional notification statuses queued/sending/logged distinguish retry/dedup state and fake delivery from a real sent FCM message. Additional attempts/error/claimed_at fields support a recoverable scheduler.
- The initial schema stores pending_expires_at and buffer_minutes per appointment to let booking logic preserve expiry and buffer semantics even if salon defaults later change.
- Staff device ownership uses staff_user_id as well as the per-salon device row. Global Auth identities are not needed by admin push consumers.
## Osoblje (task 33)

- `create_employee(salon_id,name,role,bio,experience_years,service_ids,image_url)` i
  `update_employee(salon_id,employee_id,name,role,bio,experience_years,service_ids,image_url)`
  vraćaju jedan `employees` red. Profil i zamjena veza su jedna transakcija.
- `experience_years` je nullable (0–80 kada postoji), ime je obavezno (do 120 znakova),
  `service_ids=[]` uklanja sve veze; NULL lista i tuđi/nepostojeći ID-evi su odbijeni.
- `set_employee_active(salon_id,employee_id,is_active)` čuva termine, veze i radno vrijeme.
  Direktni INSERT/UPDATE/DELETE grantovi nad radnicima i vezama su oduzeti authenticated roli.
- `appointments.employee_name` čuva ime pri rezervaciji. Trigger ne vjeruje payload-u;
  `employee_id=null` daje NULL ime. Postojeće termine migracija popunjava trenutnim imenom.
- Raspored ostaje ponavljajući `working_hours`, radnikov red nadjačava salonski. Task 33
  prikazuje raspored; uređivanje radnog vremena i blokada je task 34 (v. ispod).

## Radno vrijeme, pauze i blokade (task 34)

- `set_working_hours(salon_id, days, employee_id=null)` prima **tačno sedam** `working_hours_input`
  zapisa `(day_of_week, start_time, end_time, break_start_time, break_end_time, is_closed)` i vraća
  snimljene redove. `employee_id=null` je salonski raspored; postavljen je radnikov, koji ga
  nadjačava po polju.
- **Sedam dana je obavezno jer engine čita odsustvo reda kao zatvoreno**, ne kao „nije podešeno".
  Odbijaju se i pogrešna dužina i sedmica sa duplikatom dana. Upis je upsert, pa ID-evi redova
  prežive izmjenu; zatvoren dan se snima bez pauze.
- `create_blocked_slot(salon_id, date, start_time, end_time, reason=null, employee_id=null)` i
  `delete_blocked_slot(salon_id, blocked_slot_id)`. Prazan razlog postaje NULL. Blokada bez radnika
  pogađa cijeli salon.
- `working_hours_conflicts(salon_id, employee_id, days)` i `blocked_slot_conflicts(salon_id, date,
  start_time, end_time, employee_id=null)` su `stable` funkcije **čitanja**: vraćaju buduće termine
  koji bi ispali iz novog rasporeda ili pali pod blokadu. Postojeći termin se **ne briše i ne
  pomjera** — pozivalac ih prikazuje prije upisa. Prva vraća i `reason`
  (`Dan je zatvoren` / `Van radnog vremena` / `Unutar pauze`), druga ne.
- `set_day_closed(salon_id, date, reason=null)` (task 42) blokira cijeli dan i **otkazuje** sve
  `pending`/`confirmed` termine tog dana kroz `cancel_appointment`; vraća broj otkazanih. `PT400` za
  prošli dan i za danas poslije najranijeg početka radnog vremena (zona salona).
  `day_closure_preview(salon_id, date)` vraća te termine u obliku `blocked_slot_conflicts`, sa istim guardom.
- Direktni INSERT/UPDATE/DELETE grantovi nad `working_hours` i `blocked_slots` su oduzeti
  `authenticated` roli; ostao je samo SELECT.

## Postavke lokacije (task 36)

- `update_salon_contact(salon_id, name, address, city, description='', phone=null, email=null,
  instagram_url=null, facebook_url=null)` vraća jedan `salons` red. Naziv i grad su obavezni
  (`PT400`); prazan string u opcionim poljima se snima kao NULL, adresa i opis kao prazan string
  jer su `not null` kolone.
- **Kolone su nabrojane u potpisu.** `status`, `plan`, `slug`, `vertical_pack_key`,
  `terminology_override`, boje i logo **nisu parametri** i ne mogu se promijeniti iz admina:
  branding dolazi iz `tenant.yaml` kroz generator, ostalo je platformsko.
- `update_salon_settings(salon_id, booking_mode, booking_granularity, buffer_minutes,
  slot_step_minutes, min_advance_booking_hours, max_advance_booking_days, min_cancel_hours,
  require_staff_choice, show_prices_in_app, allow_guest_booking)` vraća jedan `salon_settings` red.
  Validacija ponavlja `check` constrainte da greška stigne kao rečenica uz polje (`PT400`), a ne
  kao `23514` sa imenom constrainta. `PT404` kad salon nema red.
- **`timezone`, `language` i `auth_providers` nisu parametri.** Prvo dvoje mijenja značenje svih
  već upisanih `time` vrijednosti u `working_hours` i `appointments` — to je migracija podataka,
  ne postavka.
- Direktni INSERT/UPDATE/DELETE grantovi nad `salons` i `salon_settings` su oduzeti `authenticated`
  roli; `staff_manage` nad `salon_settings` je zamijenjena sa `staff_read` (`for select`), da
  politika ne tvrdi više nego što grant dopušta.
- **`salon_policies` namjerno nema `rpc`** — `staff_manage` daje CRUD uz grant, jer mimo postojećih
  `check` constrainta nema šta da se validira. **`app_policies` se iz admina ne dira** (ADR-0009).
- `min_cancel_hours` vrijedi **odmah**: `cancel_appointment` ga čita pri svakom pozivu, ne pamti ga
  pri rezervaciji.

## Push ugovor (task 25)

`register_device(salon, installation_uuid, secret, platform, fcm_token, staff)` vraća
`devices.id`. Tajna je nasumični niz od 64 hex znaka; hash je u `private.device_credentials`,
bez app grantova. Identitet/članstvo se izvode iz JWT-a. `unregister_device` uklanja token i
vezu uz istu tajnu. Anon registracija je RPC izuzetak, bez direktnog table write granta.

Termin smije referencirati samo uređaj vlastitog klijentskog identiteta. Trigger statusa puni
`notification_logs`; servisni claim preuzima najviše 100 redova uz `SKIP LOCKED` i ponovo
provjerava primaoca. Cron obrađuje red svake minute kroz Vault HMAC potpis; trajni ključ ne
stoji u transportnim tabelama. `sent` znači FCM prihvat, ne dokaz prikaza na telefonu.
`sending` i `failed` se ne ponavljaju automatski zbog mogućeg duplikata nakon timeouta.

Runbook: `tasks/sprint-2/25-push-konfiguracija.md`. Lista klijentskih obavijesti ostaje prazna;
ova promjena ne otvara `notification_logs` klijentima.
