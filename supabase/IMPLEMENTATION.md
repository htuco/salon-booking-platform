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

- Public table names and fields are snake_case. All 15 entities exist. Every table has RLS enabled.
- Deterministic tenants: Barber Studio Vitez = 550e8400-e29b-41d4-a716-446655440000; Beauty Studio Travnik = 550e8400-e29b-41d4-a716-446655440001.
- Services IDs end in 1..4 (barber) and 5..8 (beauty), prefix 10000000-0000-4000-8000-. Employees end in 1..2 and 3..4, prefix 20000000-0000-4000-8000-.
- Staff JWTs require app_metadata.role = salon_admin and app_metadata.salon_id, PLUS a matching public.users row. A super_admin needs both its trusted claim and database membership. user_metadata is only display data.
- Each client request for private data requires x-salon-id. It is validated as an active salon and combined with the authenticated user's identity. This header chooses the current app context; it never grants ownership or admin rights.
- Public browsing of active salons, active services/employees, mappings, schedules and settings requires no login. Anonymous users have no write grants.
- Admins read per-salon customers/appointments. Global auth_identities rows cannot be read by staff JWTs. No API lists salons for an identity.
- Supabase Auth insert/update automatically upserts auth_identities. Account deletion/anonymization and booking/customer RPCs belong to subsequent migrations.
- Composite tenant foreign keys prevent mixing an employee/service/customer/device from another salon, even when a tenant ID is present in a forged payload.
- Client appointment/customer writes and all device writes require validated RPC/Edge functions. The base schema allows direct admin appointment mutations; the availability migration must enforce slot validation and race safety before app usage.
- Appointment device_id is the UUID FK to devices.id; devices.device_id is the install identifier. appointments.auth_identity_id must match its referenced customer's identity.
- Working hours use ISO weekdays 1=Monday to 7=Sunday. date/start_time/end_time are salon-local wall times. timezone defaults to Europe/Sarajevo.
- salon_builds.build_status/build_url are runtime build tracking fields separate from actual store status. No store status is marked live by seed.

## Assumptions where documentation is incomplete

- Password hashes are exclusively in Supabase auth.users; public.users has no redundant password_hash. Its id is the Auth user UUID.
- Both salons have the generic sample schedule from spec section 6.3: Mon–Fri 09:00–17:00, Sat 09:00–14:00, Sun closed. No street address, phone or social URL was invented.
- Every seeded employee can perform every service in their own demo salon.
- Barber palette is #C6A667 / #171717; beauty palette is #B76E79 / #FFF5F5. Both demo tenants use Pro so both Android/iOS factory paths are exercised. Branding copy is demo text.
- The vertical tables in the source lost checkmark glyphs. For MVP barber/beauty/generic: optional staff choice, prices and team on; recall off; gallery on for barber/beauty and off for generic.
- Additional notification statuses queued/sending/logged distinguish retry/dedup state and fake delivery from a real sent FCM message. Additional attempts/error/claimed_at fields support a recoverable scheduler.
- The initial schema stores pending_expires_at and buffer_minutes per appointment to let booking logic preserve expiry and buffer semantics even if salon defaults later change.
- Staff device ownership uses staff_user_id as well as the per-salon device row. Global Auth identities are not needed by admin push consumers.
