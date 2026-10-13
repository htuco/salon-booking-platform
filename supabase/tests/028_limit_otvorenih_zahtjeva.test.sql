-- Limit otvorenih zahtjeva po klijentu. Task 65.
--
-- Granice:
--   1. dva `pending` prolaze, treci pada sa `PT429`;
--   2. potvrdjen termin se ne broji — oslobadja mjesto za novi zahtjev;
--   3. istekao `pending` (rok prosao, cistac jos nije prosao) se ne broji;
--   4. drugi salon ima svoj brojac;
--   5. admin unos nije ogranicen;
--   6. postavka salona mijenja granicu;
--   7. napomena preko 500 znakova pada sa `PT400`.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table fix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as drugi_salon,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  -- Izveden datum, ne fiksan: `max_advance_booking_days` je 30 (isto kao u `015`).
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak;
grant select on fix to public;

-- Usluga i radnik drugog salona iz seeda: bez njih sekcija 4 ne bi imala sta rezervisati.
create temporary table drugi as
select s.id as usluga, m.employee_id as radnik
from public.services s
join public.employee_services m on m.salon_id = s.salon_id and m.service_id = s.id
where s.salon_id = (select drugi_salon from fix) and s.is_active
order by s.id, m.employee_id limit 1;
grant select on drugi to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fd000000-0000-4000-8000-000000000001', 'klijent@limit65.invalid', '{"providers":["email"]}', '{}'),
('fd000000-0000-4000-8000-000000000002', 'vlasnik@limit65.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('fd000000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'vlasnik@limit65.invalid', 'salon_admin');

select is((select max_pending_per_customer from public.salon_settings
  where salon_id = (select salon from fix)), 2, 'Podrazumijevana granica je 2');
select is((select booking_mode from public.salon_settings where salon_id = (select salon from fix)),
  'manual', 'Salon je u manual modu, pa rezervacija daje pending');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local request.jwt.claims = '{"sub":"fd000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table moj as select (public.ensure_customer((select salon from fix))).id as customer_id;
create temporary table prvi as select (public.book_appointment((select salon from fix),
  (select customer_id from moj), (select usluga from fix), (select utorak from fix), '09:00',
  (select emir from fix))).id as id;
create temporary table drugi_zahtjev as select (public.book_appointment((select salon from fix),
  (select customer_id from moj), (select usluga from fix), (select utorak from fix), '10:00',
  (select emir from fix))).id as id;
reset role;
grant select on moj, prvi, drugi_zahtjev to public;

-- ---------------------------------------------------------------------------
-- 1. Treci pending pada
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.appointments
  where customer_id = (select customer_id from moj) and status = 'pending'),
  2, 'Dva zahtjeva prolaze');

set local role authenticated;
select throws_ok($$
  select public.book_appointment((select salon from fix), (select customer_id from moj),
    (select usluga from fix), (select utorak from fix), '11:00', (select emir from fix))
$$, 'PT429', 'Već imate zahtjeve koji čekaju potvrdu', 'Treci pending zahtjev pada sa PT429');
reset role;

-- ---------------------------------------------------------------------------
-- 2. Potvrdjen termin se ne broji
-- ---------------------------------------------------------------------------
update public.appointments set status = 'confirmed', pending_expires_at = null
where id = (select id from prvi);

set local role authenticated;
select lives_ok($$
  select public.book_appointment((select salon from fix), (select customer_id from moj),
    (select usluga from fix), (select utorak from fix), '11:00', (select emir from fix))
$$, 'Potvrdjen termin oslobadja mjesto za novi zahtjev');
select throws_ok($$
  select public.book_appointment((select salon from fix), (select customer_id from moj),
    (select usluga from fix), (select utorak from fix), '12:00', (select emir from fix))
$$, 'PT429', null, 'Sa dva pending zahtjeva opet pada');
reset role;

-- ---------------------------------------------------------------------------
-- 3. Istekao pending se ne broji
-- ---------------------------------------------------------------------------
update public.appointments set pending_expires_at = now() - interval '1 minute'
where id = (select id from drugi_zahtjev);

set local role authenticated;
select lives_ok($$
  select public.book_appointment((select salon from fix), (select customer_id from moj),
    (select usluga from fix), (select utorak from fix), '12:00', (select emir from fix))
$$, 'Zahtjev kojem je prosao rok ne drzi kvotu ni prije cistaca');
reset role;

-- ---------------------------------------------------------------------------
-- 4. Drugi salon ima svoj brojac
-- ---------------------------------------------------------------------------
select ok((select count(*) from drugi) = 1, 'Drugi salon iz seeda ima uslugu sa radnikom');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
set local role authenticated;
create temporary table moj_drugi as select (public.ensure_customer((select drugi_salon from fix))).id as customer_id;
select lives_ok($$
  select public.book_appointment((select drugi_salon from fix), (select customer_id from moj_drugi),
    (select usluga from drugi), (select utorak from fix), '10:00', (select radnik from drugi))
$$, 'Pun brojac u prvom salonu ne blokira drugi salon');
reset role;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- ---------------------------------------------------------------------------
-- 5. Admin unos nije ogranicen
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fd000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select lives_ok($$
  select public.book_appointment((select salon from fix), (select customer_id from moj),
    (select usluga from fix), (select utorak from fix), '14:00', (select emir from fix))
$$, 'Vlasnik upisuje termin klijentu koji ima pun brojac');
reset role;

-- ---------------------------------------------------------------------------
-- 6. Postavka mijenja granicu
-- ---------------------------------------------------------------------------
update public.salon_settings set max_pending_per_customer = 3
where salon_id = (select salon from fix);

set local request.jwt.claims = '{"sub":"fd000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select lives_ok($$
  select public.book_appointment((select salon from fix), (select customer_id from moj),
    (select usluga from fix), (select utorak from fix), '15:00', (select emir from fix))
$$, 'Salon sa granicom 3 prima treci zahtjev');

-- ---------------------------------------------------------------------------
-- 7. Napomena
-- ---------------------------------------------------------------------------
select throws_ok($$
  select public.book_appointment((select salon from fix), (select customer_id from moj),
    (select usluga from fix), (select utorak from fix), '16:00', (select emir from fix),
    repeat('x', 501))
$$, 'PT400', null, 'Napomena preko 500 znakova pada');
reset role;

select throws_ok($$
  update public.salon_settings set max_pending_per_customer = 0
  where salon_id = '550e8400-e29b-41d4-a716-446655440000'
$$, '23514', null, 'Granica 0 bi zakljucala salon — check je ne prima');

select * from finish();
rollback;
