-- Istek neodgovorenih zahtjeva. Task 64.
--
-- `private.expire_pending()` zatvara `pending` termin kojem je prosao rok ili pocetak. Granice:
--   1. neistekao zahtjev ostaje `pending` — bez ovoga bi `update ... where status = 'pending'`
--      bez uslova roka bio zelen;
--   2. istekao postaje `cancelled` / `system` / `isteklo`, a klijent dobija **jedan** push
--      tipa `expired` (ne `rejected` — salon nije rekao ne);
--   3. potvrdjen termin se ne dira ni kad mu je ostao stari rok;
--   4. zahtjev ciji je pocetak prosao prije roka se zatvara na pocetak;
--   5. drugi prolaz ne radi nista i ne salje drugi push;
--   6. oslobodjen slot se vraca u `get_available_slots` — to je cijela svrha taska;
--   7. cron postoji, a klijent funkciju ne moze pozvati.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table fix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  'fc000000-0000-4000-8000-000000000011'::uuid as instalacija_klijenta,
  'fc000000-0000-4000-8000-000000000012'::uuid as instalacija_vlasnika,
  -- Izveden datum, ne fiksan: `max_advance_booking_days` je 30 (isto kao u `015` i `016`).
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak;
grant select on fix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fc000000-0000-4000-8000-000000000001', 'klijent@istek64.invalid', '{"providers":["email"]}', '{}'),
('fc000000-0000-4000-8000-000000000002', 'vlasnik@istek64.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('fc000000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'vlasnik@istek64.invalid', 'salon_admin');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- Vlasnikov uredjaj postoji da bi asercija „salon ne dobija push" imala koga da propusti.
set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table vlasnik_uredjaj as select public.register_device(
  (select salon from fix), (select instalacija_vlasnika from fix),
  repeat('c', 64), 'android', 'owner-token', true) as id;
reset role;
grant select on vlasnik_uredjaj to public;

set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table klijent_uredjaj as select public.register_device(
  (select salon from fix), (select instalacija_klijenta from fix),
  repeat('a', 64), 'android', 'client-token') as id;
create temporary table moj as select (public.ensure_customer((select salon from fix))).id as customer_id;
create temporary table t_zahtjev as select (public.book_appointment(
  (select salon from fix), (select customer_id from moj), (select usluga from fix),
  (select utorak from fix), '10:00', (select emir from fix), null,
  (select id from klijent_uredjaj))).id as id;
create temporary table t_potvrdjen as select (public.book_appointment(
  (select salon from fix), (select customer_id from moj), (select usluga from fix),
  (select utorak from fix), '12:00', (select emir from fix), null,
  (select id from klijent_uredjaj))).id as id;
reset role;
grant select on klijent_uredjaj, moj, t_zahtjev, t_potvrdjen to public;

-- Seed moze nositi `pending` redove sa proslim rokom. Prvi prolaz ih pocisti, pa brojevi
-- ispod mjere samo ono sto je ovaj fajl napravio.
select private.expire_pending();

-- ---------------------------------------------------------------------------
-- 1. Neistekao zahtjev ostaje `pending`
-- ---------------------------------------------------------------------------
select is((select status::text from public.appointments where id = (select id from t_zahtjev)),
  'pending', 'Polazno: klijentska rezervacija u manual modu je zahtjev');
select is(private.expire_pending(), 0, 'Zahtjev sa rokom u buducnosti se ne zatvara');
select is((select status::text from public.appointments where id = (select id from t_zahtjev)),
  'pending', 'Neistekao zahtjev je i dalje pending');
select ok(not exists(select 1 from public.get_available_slots((select salon from fix),
    (select usluga from fix), (select utorak from fix), (select emir from fix))
  where start_time = '10:00'), 'Zahtjev koji ceka drzi slot');

-- ---------------------------------------------------------------------------
-- 2. Istekao zahtjev se zatvara i klijent dobija jedan push
-- ---------------------------------------------------------------------------
-- Potvrdjen termin sa starim rokom u proslosti: ako ga cistac dira, sekcija 3 pada.
update public.appointments set status = 'confirmed', pending_expires_at = now() - interval '1 hour'
where id = (select id from t_potvrdjen);
update public.appointments set pending_expires_at = now() - interval '1 minute'
where id = (select id from t_zahtjev);

select is(private.expire_pending(), 1, 'Zatvoren je tacno jedan istekli zahtjev');
select is((select (status::text, cancelled_by::text, cancel_reason)
    from public.appointments where id = (select id from t_zahtjev)),
  ('cancelled'::text, 'system'::text, 'isteklo'::text),
  'Isteklo je cancelled, cancelled_by=system, cancel_reason=isteklo');
select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from t_zahtjev) and type = 'expired'
    and device_id = (select id from klijent_uredjaj)),
  1, 'Klijent dobija push o isteku');
select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from t_zahtjev) and type in ('rejected', 'cancelled')),
  0, 'Istek se ne salje kao odbijanje ni otkazivanje');
select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from t_zahtjev) and device_id = (select id from vlasnik_uredjaj)
    and type = 'expired'),
  0, 'Salon ne dobija push o isteku svog zahtjeva');

-- ---------------------------------------------------------------------------
-- 3. Potvrdjen termin se ne dira
-- ---------------------------------------------------------------------------
select is((select status::text from public.appointments where id = (select id from t_potvrdjen)),
  'confirmed', 'Potvrdjen termin sa proslim rokom ostaje potvrdjen');

-- ---------------------------------------------------------------------------
-- 4. Drugi prolaz ne radi nista
-- ---------------------------------------------------------------------------
select is(private.expire_pending(), 0, 'Drugi prolaz ne nalazi nista');
select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from t_zahtjev) and type = 'expired'),
  1, 'Drugi prolaz ne salje drugi push');

-- ---------------------------------------------------------------------------
-- 5. Oslobodjen slot se vraca
-- ---------------------------------------------------------------------------
select ok(exists(select 1 from public.get_available_slots((select salon from fix),
    (select usluga from fix), (select utorak from fix), (select emir from fix))
  where start_time = '10:00'), 'Istekli zahtjev vise ne drzi slot');

-- ---------------------------------------------------------------------------
-- 6. Pocetak prije roka: zatvara se na pocetak termina
-- ---------------------------------------------------------------------------
-- Upis kroz superusera: `book_appointment` ne prima proslost, a ovo je stanje koje nastaje
-- kad zahtjev za termin za dva sata ceka 12-satni rok. Datum je jucer u zoni salona.
create temporary table t_pocetak as
with novi as (
  insert into public.appointments(salon_id, service_id, employee_id, customer_id, auth_identity_id,
    device_id, customer_name, date, start_time, end_time, status, source, pending_expires_at)
  select f.salon, f.usluga, f.emir, m.customer_id, c.auth_identity_id, k.id, 'Klijent',
    (now() at time zone 'Europe/Sarajevo')::date - 1, '10:00', '10:30', 'pending', 'app',
    now() + interval '10 hours'
  from fix f, moj m, klijent_uredjaj k, public.customers c where c.id = m.customer_id
  returning id)
select id from novi;
grant select on t_pocetak to public;

select is(private.expire_pending(), 1, 'Zahtjev ciji je pocetak prosao se zatvara i prije roka');
select is((select cancelled_by::text from public.appointments where id = (select id from t_pocetak)),
  'system', 'Zatvorio ga je sistem');

-- ---------------------------------------------------------------------------
-- 7. Cron i grantovi
-- ---------------------------------------------------------------------------
select is((select schedule from cron.job where jobname = 'expire-pending'), '*/5 * * * *',
  'Cron zove cistac svakih 5 minuta');
select ok(not has_function_privilege('authenticated', 'private.expire_pending()', 'execute'),
  'Klijent i osoblje ne mogu sami zatvarati tudje zahtjeve');
select ok(not has_function_privilege('anon', 'private.expire_pending()', 'execute'),
  'Anon ne moze pozvati cistac');

select * from finish();
rollback;
