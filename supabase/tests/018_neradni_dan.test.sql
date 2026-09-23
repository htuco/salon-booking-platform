-- Neradni dan: zakljucana proslost i kaskadno otkazivanje. Task 42.
--
-- Mjeri:
--   1. granicu zakljucavanja kroz `private.assert_day_closable` sa zadatim `p_now`
--      (prosli dan, danas prije i poslije otvaranja, dan zatvoren po rasporedu);
--   2. da ne-admin i admin drugog salona dobijaju 42501;
--   3. da `set_day_closed` otkazuje tacno `pending` i `confirmed`, sa `cancelled_by='salon'`
--      i razlogom, a `completed` i vec `cancelled` ne dira;
--   4. da klijentski uredjaj dobija red u `notification_logs` za svaki otkazan termin;
--   5. da termin drugog salona istog dana ostaje netaknut;
--   6. da dan postaje blokiran i da ponovljen poziv ne pravi drugu blokadu.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table fix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as tudji_salon,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  -- Izveden datum: utorak sljedece sedmice je uvijek u buducnosti i uvijek radni (09–17).
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak;
grant select on fix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fc000000-0000-4000-8000-000000000001', 'vlasnik@neradni42.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('fc000000-0000-4000-8000-000000000002', 'vlasnik-b@neradni42.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}', '{}'),
('fc000000-0000-4000-8000-000000000003', 'klijent@neradni42.invalid', '{"providers":["email"]}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('fc000000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik A', 'vlasnik@neradni42.invalid', 'salon_admin'),
('fc000000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440001',
 'Vlasnik B', 'vlasnik-b@neradni42.invalid', 'salon_admin');
update public.auth_identities set id = 'fc100000-0000-4000-8000-000000000003'
where supabase_user_id = 'fc000000-0000-4000-8000-000000000003';

insert into public.customers(id, salon_id, auth_identity_id, name) values
('fc200000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000',
 'fc100000-0000-4000-8000-000000000003', 'Klijent 42'),
('fc200000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440001',
 'fc100000-0000-4000-8000-000000000003', 'Klijent 42');
insert into public.devices(id, salon_id, device_id, fcm_token, platform, auth_identity_id) values
('fc300000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000',
 'instalacija-42', 'klijent-token', 'android', 'fc100000-0000-4000-8000-000000000003');

insert into public.appointments(id, salon_id, service_id, employee_id, customer_id,
  auth_identity_id, device_id, customer_name, date, start_time, end_time, status)
select v.id, (select salon from fix), (select usluga from fix), (select emir from fix),
  'fc200000-0000-4000-8000-000000000001', 'fc100000-0000-4000-8000-000000000003',
  'fc300000-0000-4000-8000-000000000001', 'Klijent 42', (select utorak from fix),
  v.od, v.od + interval '30 minutes', v.status::public.appointment_status
from (values
  ('fc400000-0000-4000-8000-000000000001'::uuid, '09:00'::time, 'pending'),
  ('fc400000-0000-4000-8000-000000000002'::uuid, '10:00'::time, 'confirmed'),
  ('fc400000-0000-4000-8000-000000000003'::uuid, '11:00'::time, 'confirmed'),
  ('fc400000-0000-4000-8000-000000000004'::uuid, '12:00'::time, 'completed'),
  ('fc400000-0000-4000-8000-000000000005'::uuid, '13:00'::time, 'cancelled')
) as v(id, od, status);

insert into public.appointments(id, salon_id, service_id, employee_id, customer_id,
  auth_identity_id, customer_name, date, start_time, end_time, status)
values ('fc400000-0000-4000-8000-000000000009', '550e8400-e29b-41d4-a716-446655440001',
  '10000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000003',
  'fc200000-0000-4000-8000-000000000002', 'fc100000-0000-4000-8000-000000000003',
  'Klijent 42', (select utorak from fix), '10:00', '10:45', 'confirmed');

-- ---------------------------------------------------------------------------
-- 1. Granica zakljucavanja
-- ---------------------------------------------------------------------------
select throws_ok(
  format($$ select private.assert_day_closable(%L, %L, %L) $$,
    (select salon from fix), (select utorak from fix),
    ((select utorak from fix) + 1 + time '08:00') at time zone 'Europe/Sarajevo'),
  'PT400', null, 'Prosli dan je zakljucan');

select lives_ok(
  format($$ select private.assert_day_closable(%L, %L, %L) $$,
    (select salon from fix), (select utorak from fix),
    ((select utorak from fix) + time '08:59') at time zone 'Europe/Sarajevo'),
  'Danas prije otvaranja je prihvacen');

select throws_ok(
  format($$ select private.assert_day_closable(%L, %L, %L) $$,
    (select salon from fix), (select utorak from fix),
    ((select utorak from fix) + time '09:00') at time zone 'Europe/Sarajevo'),
  'PT400', null, 'Danas u trenutku otvaranja je odbijen');

-- Granica je u zoni salona: 08:30 UTC je 10:30 u Sarajevu ljeti, odnosno 09:30 zimi —
-- u oba slucaja poslije otvaranja, iako je u UTC-u „prije 9".
select throws_ok(
  format($$ select private.assert_day_closable(%L, %L, %L) $$,
    (select salon from fix), (select utorak from fix),
    ((select utorak from fix) + time '08:30') at time zone 'UTC'),
  'PT400', null, 'Granica se racuna u zoni salona, ne u UTC-u');

-- Najraniji pocetak radnika pomjera granicu naprijed.
insert into public.working_hours(salon_id, employee_id, day_of_week, start_time, end_time)
values ((select salon from fix), (select emir from fix),
  extract(isodow from (select utorak from fix))::int, '07:00', '15:00')
on conflict (salon_id, employee_id, day_of_week) do update set start_time = '07:00', is_closed = false;
select throws_ok(
  format($$ select private.assert_day_closable(%L, %L, %L) $$,
    (select salon from fix), (select utorak from fix),
    ((select utorak from fix) + time '08:00') at time zone 'Europe/Sarajevo'),
  'PT400', null, 'Radnik koji pocinje u 7 zakljucava dan od 7');

-- Nedjelja je po seedu zatvorena: nema otvaranja, pa nema ni granice unutar dana.
select lives_ok(
  format($$ select private.assert_day_closable(%L, %L, %L) $$,
    (select salon from fix), (select utorak from fix) + 5,
    ((select utorak from fix) + 5 + time '15:00') at time zone 'Europe/Sarajevo'),
  'Dan zatvoren po rasporedu nema granicu otvaranja');

-- ---------------------------------------------------------------------------
-- 2. Autorizacija
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select throws_ok(
  format($$ select public.set_day_closed(%L, %L, 'x') $$, (select salon from fix), (select utorak from fix)),
  '42501', null, 'Klijent ne proglasava neradni dan');
select throws_ok(
  format($$ select * from public.day_closure_preview(%L, %L) $$, (select salon from fix), (select utorak from fix)),
  '42501', null, 'Klijent ne vidi pregled otkazivanja');
reset role;

set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select throws_ok(
  format($$ select public.set_day_closed(%L, %L, 'x') $$, (select salon from fix), (select utorak from fix)),
  '42501', null, 'Admin drugog salona ne zatvara tudji dan');
reset role;

-- ---------------------------------------------------------------------------
-- 3–6. Kaskada
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;

select is((select count(*)::int from public.day_closure_preview(
    (select salon from fix), (select utorak from fix))),
  3, 'Pregled prije potvrde pokazuje tri ziva termina');

select throws_ok(
  format($$ select public.set_day_closed(%L, %L, 'x') $$,
    (select salon from fix), (now() at time zone 'Europe/Sarajevo')::date - 1),
  'PT400', null, 'RPC odbija jucerasnji dan');

select is(public.set_day_closed((select salon from fix), (select utorak from fix), 'Bajram'),
  3, 'Otkazana su tacno tri termina');
select is(public.set_day_closed((select salon from fix), (select utorak from fix), 'Bajram'),
  0, 'Ponovljen poziv nema sta otkazati');
reset role;

select is((select array_agg(status::text || '/' || coalesce(cancelled_by::text, '-') order by start_time)
    from public.appointments where salon_id = (select salon from fix) and date = (select utorak from fix)
      and id::text like 'fc4%'),
  array['cancelled/salon', 'cancelled/salon', 'cancelled/salon', 'completed/-', 'cancelled/-'],
  'pending i confirmed otkazani od salona; completed i vec otkazan netaknuti');
select is((select count(*)::int from public.appointments
    where id in ('fc400000-0000-4000-8000-000000000001', 'fc400000-0000-4000-8000-000000000002',
                 'fc400000-0000-4000-8000-000000000003') and cancel_reason = 'Bajram'),
  3, 'Razlog je upisan na svaki otkazan termin');

select is((select count(distinct appointment_id)::int from public.notification_logs
    where device_id = 'fc300000-0000-4000-8000-000000000001'
      and appointment_id in ('fc400000-0000-4000-8000-000000000001',
        'fc400000-0000-4000-8000-000000000002', 'fc400000-0000-4000-8000-000000000003')),
  3, 'Klijentski uredjaj ima obavijest za svaki otkazan termin');

select is((select status::text from public.appointments where id = 'fc400000-0000-4000-8000-000000000009'),
  'confirmed', 'Termin drugog salona istog dana je netaknut');

select is((select count(*)::int from public.blocked_slots
    where salon_id = (select salon from fix) and date = (select utorak from fix) and employee_id is null),
  1, 'Dan je blokiran jednom, i ponovljen poziv ne pravi drugu blokadu');
select is((select count(*)::int from public.blocked_slots
    where salon_id = (select tudji_salon from fix) and date = (select utorak from fix)),
  0, 'Tudji salon nije blokiran');

select * from finish();
rollback;
