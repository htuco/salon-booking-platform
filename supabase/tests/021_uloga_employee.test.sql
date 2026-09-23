-- Uloga `employee` i suzena izolacija. Task 46, ADR-0013.
--
-- Mjeri:
--   1. radnik A1 vidi **samo svoje** termine: ne radnika A2, ne termin bez radnika, ne salon B;
--   2. blokade: salonske i svoje da, tudje odsustvo ne;
--   3. `set_appointment_status` i `cancel_appointment` rade samo nad njegovim terminom;
--   4. cjenovnik, osoblje, radno vrijeme, postavke, klijenti i pozivi su mu nula za pisanje
--      (i klijenti/pozivi za citanje);
--   5. token bez reda, token za drugi salon i nalog bez veze na `employees` nemaju nista;
--   6. poziv za radnika mora nositi radnika, i to radnika bez naloga;
--   7. regresija: admin i dalje vidi sve termine salona.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table fix as select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as salon_b,
  '20000000-0000-4000-8000-000000000001'::uuid as e1,
  '20000000-0000-4000-8000-000000000002'::uuid as e2,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as dan;
grant select on fix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fa000000-0000-4000-8000-000000000001', 'radnik-a1@e46.invalid',
 '{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('fa000000-0000-4000-8000-000000000002', 'radnik-a2@e46.invalid',
 '{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('fa000000-0000-4000-8000-000000000003', 'vlasnik@e46.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('fa000000-0000-4000-8000-000000000004', 'bez-reda@e46.invalid',
 '{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role, employee_id) values
('fa000000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000', 'Radnik A1', 'radnik-a1@e46.invalid', 'employee', '20000000-0000-4000-8000-000000000001'),
('fa000000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440000', 'Radnik A2', 'radnik-a2@e46.invalid', 'employee', '20000000-0000-4000-8000-000000000002'),
('fa000000-0000-4000-8000-000000000003', '550e8400-e29b-41d4-a716-446655440000', 'Vlasnik', 'vlasnik@e46.invalid', 'salon_admin', null);

insert into public.customers(id, salon_id, name) values
('fa200000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000', 'Klijent A'),
('fa200000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440001', 'Klijent B');

insert into public.appointments(id, salon_id, service_id, employee_id, customer_id, customer_name, date, start_time, end_time, status)
select v.id, (select salon from fix), (select usluga from fix), v.emp,
  'fa200000-0000-4000-8000-000000000001', v.ime, (select dan from fix), v.od, v.od + interval '30 minutes', 'pending'
from (values
  ('fa400000-0000-4000-8000-000000000001'::uuid, '20000000-0000-4000-8000-000000000001'::uuid, '09:00'::time, 'Za A1'),
  ('fa400000-0000-4000-8000-000000000002'::uuid, '20000000-0000-4000-8000-000000000002'::uuid, '10:00'::time, 'Za A2'),
  ('fa400000-0000-4000-8000-000000000003'::uuid, null::uuid, '11:00'::time, 'Bez radnika'),
  ('fa400000-0000-4000-8000-000000000004'::uuid, '20000000-0000-4000-8000-000000000001'::uuid, '12:00'::time, 'Za A1 drugi')
) as v(id, emp, od, ime);
insert into public.appointments(id, salon_id, service_id, employee_id, customer_id, customer_name, date, start_time, end_time, status)
values ('fa400000-0000-4000-8000-000000000009', '550e8400-e29b-41d4-a716-446655440001',
  '10000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000003',
  'fa200000-0000-4000-8000-000000000002', 'Salon B', (select dan from fix), '10:00', '10:45', 'pending');

insert into public.blocked_slots(salon_id, employee_id, date, start_time, end_time, reason) values
('550e8400-e29b-41d4-a716-446655440000', null, (select dan from fix) + 1, '09:00', '10:00', 'salon'),
('550e8400-e29b-41d4-a716-446655440000', '20000000-0000-4000-8000-000000000001', (select dan from fix) + 1, '11:00', '12:00', 'A1'),
('550e8400-e29b-41d4-a716-446655440000', '20000000-0000-4000-8000-000000000002', (select dan from fix) + 1, '13:00', '14:00', 'A2');

-- ---------------------------------------------------------------------------
-- 1–2. Radnik A1 cita samo svoje
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;

select ok(private.is_employee('550e8400-e29b-41d4-a716-446655440000'), 'A1 je radnik salona A');
select ok(not private.is_admin('550e8400-e29b-41d4-a716-446655440000'), 'A1 nije admin');
select ok(not private.is_employee('550e8400-e29b-41d4-a716-446655440001'), 'A1 nije radnik salona B');
select set_eq($$ select customer_name from public.appointments $$,
  array['Za A1', 'Za A1 drugi'], 'A1 vidi tacno svoja dva termina');
select is((select count(*)::int from public.appointments where id = 'fa400000-0000-4000-8000-000000000002'),
  0, 'A1 ne vidi termin radnika A2');
select is((select count(*)::int from public.appointments where employee_id is null),
  0, 'A1 ne vidi termin bez radnika');
select is((select count(*)::int from public.appointments where salon_id = (select salon_b from fix)),
  0, 'A1 ne vidi salon B');
select set_eq($$ select reason from public.blocked_slots $$,
  array['salon', 'A1'], 'A1 vidi salonsku i svoju blokadu, ne tudju');

-- ---------------------------------------------------------------------------
-- 3. RPC nad terminom
-- ---------------------------------------------------------------------------
select is((public.set_appointment_status((select salon from fix), 'fa400000-0000-4000-8000-000000000001', 'confirmed')).status::text,
  'confirmed', 'A1 potvrdjuje svoj termin');
select throws_ok($$ select public.set_appointment_status('550e8400-e29b-41d4-a716-446655440000', 'fa400000-0000-4000-8000-000000000002', 'confirmed') $$,
  '42501', null, 'A1 ne potvrdjuje termin radnika A2');
select throws_ok($$ select public.set_appointment_status('550e8400-e29b-41d4-a716-446655440000', 'fa400000-0000-4000-8000-000000000003', 'confirmed') $$,
  '42501', null, 'A1 ne potvrdjuje termin bez radnika');
select throws_ok($$ select public.set_appointment_status('550e8400-e29b-41d4-a716-446655440001', 'fa400000-0000-4000-8000-000000000009', 'confirmed') $$,
  '42501', null, 'A1 ne dira salon B');
select is((public.cancel_appointment((select salon from fix), 'fa400000-0000-4000-8000-000000000004', 'Bolestan')).cancelled_by::text,
  'salon', 'A1 otkazuje svoj termin kao salon');
select throws_ok($$ select public.cancel_appointment('550e8400-e29b-41d4-a716-446655440000', 'fa400000-0000-4000-8000-000000000002', 'x') $$,
  '42501', null, 'A1 ne otkazuje termin radnika A2');
select throws_ok($$ select public.cancel_appointment('550e8400-e29b-41d4-a716-446655440000', 'fa400000-0000-4000-8000-000000000003', 'x') $$,
  '42501', null, 'A1 ne otkazuje termin bez radnika');
select throws_ok($$ select public.cancel_appointment('550e8400-e29b-41d4-a716-446655440001', 'fa400000-0000-4000-8000-000000000009', 'x') $$,
  '42501', null, 'A1 ne otkazuje termin salona B');
select throws_ok($$ select public.cancel_appointment('550e8400-e29b-41d4-a716-446655440000', 'fa400000-0000-4000-8000-0000000000ff', 'x') $$,
  '42501', null, 'Nepostojeci termin kroz cancel daje istu gresku kao tudji');
select throws_ok($$ select public.set_appointment_status('550e8400-e29b-41d4-a716-446655440000', 'fa400000-0000-4000-8000-0000000000ff', 'confirmed') $$,
  '42501', null, 'Nepostojeci termin kroz set_appointment_status daje istu gresku kao tudji');
select throws_ok($$ update public.appointments set status = 'cancelled' where id = 'fa400000-0000-4000-8000-000000000001' $$,
  '42501', null, 'A1 ne pise termin direktno');

-- ---------------------------------------------------------------------------
-- 4. Sve ostalo mu je zatvoreno
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.customers), 0, 'A1 ne cita klijente');
select is((select count(*)::int from public.staff_invites), 0, 'A1 ne cita pozive');
select throws_ok($$ select public.create_service('550e8400-e29b-41d4-a716-446655440000', 'X', '', '', 1, 30) $$,
  '42501', null, 'A1 ne mijenja cjenovnik');
select throws_ok($$ select public.update_service('550e8400-e29b-41d4-a716-446655440000', '10000000-0000-4000-8000-000000000001', 'X', '', '', 1, 30) $$,
  '42501', null, 'A1 ne mijenja uslugu');
select throws_ok($$ select * from public.create_staff_invite('550e8400-e29b-41d4-a716-446655440000', 'salon_admin', 'X') $$,
  '42501', null, 'A1 ne poziva osoblje');
select throws_ok($$ select * from public.list_staff_users('550e8400-e29b-41d4-a716-446655440000') $$,
  '42501', null, 'A1 ne lista osoblje');
select throws_ok($$ select public.create_blocked_slot('550e8400-e29b-41d4-a716-446655440000', current_date + 3, '09:00', '10:00') $$,
  '42501', null, 'A1 ne pravi blokade');
select throws_ok($$ select public.set_day_closed('550e8400-e29b-41d4-a716-446655440000', current_date + 3, 'x') $$,
  '42501', null, 'A1 ne zatvara dan');
select is((select count(*)::int from public.salon_settings where salon_id = (select salon from fix)),
  1, 'Postavke cita kao i svaki posjetilac aktivnog salona (public_active)');
reset role;

select is((select name from public.services where id = '10000000-0000-4000-8000-000000000001'),
  'Muško šišanje', 'Cjenovnik je netaknut');

-- ---------------------------------------------------------------------------
-- Deaktiviran radnik gubi pristup odmah (nalaz `rls-auditor`, task 46). Nalog i JWT ostaju.
update public.employees set is_active = false where id = '20000000-0000-4000-8000-000000000001';
set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select ok(not private.is_employee('550e8400-e29b-41d4-a716-446655440000'), 'Deaktiviran radnik nije radnik');
select is((select count(*)::int from public.appointments), 0, 'Deaktiviran radnik ne vidi svoje termine');
select is((select count(*)::int from public.blocked_slots), 0, 'ni blokade');
select throws_ok($$ select public.set_appointment_status('550e8400-e29b-41d4-a716-446655440000', 'fa400000-0000-4000-8000-000000000001', 'completed') $$,
  '42501', null, 'Deaktiviran radnik ne mijenja svoj termin');
select throws_ok($$ select public.cancel_appointment('550e8400-e29b-41d4-a716-446655440000', 'fa400000-0000-4000-8000-000000000001', 'x') $$,
  '42501', null, 'Deaktiviran radnik ne otkazuje svoj termin');
reset role;
update public.employees set is_active = true where id = '20000000-0000-4000-8000-000000000001';

-- 5. Tokeni bez pokrica
-- ---------------------------------------------------------------------------
-- JWT kaze `employee`, a reda u `public.users` nema.
set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select is((select count(*)::int from public.appointments), 0, 'Token radnika bez reda ne vidi nijedan termin');
reset role;

-- Pravi radnik A1, ali token tvrdi salon B.
set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select is((select count(*)::int from public.appointments), 0, 'A1 sa tokenom za salon B ne vidi nista');
reset role;

-- Radnik A1, ali token kaze `salon_admin`: uloga iz tokena bez reda ne otvara admin.
set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select ok(not private.is_admin('550e8400-e29b-41d4-a716-446655440000'), 'Podmetnut salon_admin claim ne daje admin');
select is((select count(*)::int from public.appointments), 0, 'ni termine');
reset role;

-- Nalog radnika bez veze (zaostao iz taska 45) nema prava. Red se pravi zaobilazeci `check`
-- koji je `not valid` samo za stare redove, pa ga ovdje simuliramo privremenim gasenjem.
alter table public.users drop constraint users_employee_required;
insert into public.users(id, salon_id, name, email, role, employee_id) values
('fa000000-0000-4000-8000-000000000004', '550e8400-e29b-41d4-a716-446655440000', 'Bez veze', 'bez-reda@e46.invalid', 'employee', null);
set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select ok(not private.is_employee('550e8400-e29b-41d4-a716-446655440000'), 'Radnik bez veze nije radnik');
select is((select count(*)::int from public.appointments), 0, 'Radnik bez veze ne vidi termine');
reset role;
delete from public.users where id = 'fa000000-0000-4000-8000-000000000004';
alter table public.users add constraint users_employee_required
  check (role <> 'employee' or employee_id is not null) not valid;

select throws_ok($$ insert into public.users(id, salon_id, name, email, role)
  values ('fa000000-0000-4000-8000-000000000004', '550e8400-e29b-41d4-a716-446655440000', 'X', 'x@x.x', 'employee') $$,
  '23514', null, 'Novi nalog radnika bez veze se ne moze upisati');
select throws_ok($$ insert into public.users(id, salon_id, name, email, role, employee_id)
  values ('fa000000-0000-4000-8000-000000000004', '550e8400-e29b-41d4-a716-446655440000', 'X', 'x@x.x', 'employee',
    '20000000-0000-4000-8000-000000000001') $$,
  '23505', null, 'Jedan radnik, jedan nalog');

-- ---------------------------------------------------------------------------
-- 6–7. Poziv i admin
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok($$ select * from public.create_staff_invite('550e8400-e29b-41d4-a716-446655440000', 'employee', 'X') $$,
  'PT400', 'Izaberite radnika za koga je poziv', 'Poziv za radnika bez radnika je odbijen');
select throws_ok($$ select * from public.create_staff_invite('550e8400-e29b-41d4-a716-446655440000', 'employee', 'X',
  '20000000-0000-4000-8000-000000000001') $$,
  'PT400', 'Ovaj radnik vec ima nalog', 'Radnik koji vec ima nalog se ne poziva ponovo');
select is((select count(*)::int from public.appointments where salon_id = (select salon from fix) and id::text like 'fa4%'),
  4, 'Admin i dalje vidi sva cetiri termina salona, i onaj bez radnika');
reset role;

-- Poziv za radnika nosi vezu do naloga.
insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fa000000-0000-4000-8000-000000000005', 'novi@e46.invalid',
 '{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
delete from public.users where id = 'fa000000-0000-4000-8000-000000000002';
set local request.jwt.claims = '{"sub":"fa000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table poziv as select * from public.create_staff_invite(
  '550e8400-e29b-41d4-a716-446655440000', 'employee', 'Novi A2', '20000000-0000-4000-8000-000000000002');
reset role;
grant select on poziv to public;
set local role service_role;
select is((public.accept_staff_invite((select code from poziv), 'fa000000-0000-4000-8000-000000000005', 'novi@e46.invalid')).employee_id,
  '20000000-0000-4000-8000-000000000002'::uuid, 'Prihvacen poziv veze nalog za radnika iz poziva');
reset role;

select * from finish();
rollback;
