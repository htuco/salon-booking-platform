-- Istorija obavijesti klijenta. Task 70.
--
-- `my_notifications` je jedina klijentska putanja do `notification_logs`. Granice:
--   1. klijent vidi obavijest o svom terminu, jednom iako je poslana na dva uredjaja;
--   2. drugi klijent istog salona ne vidi nista od prvog;
--   3. red poslan osoblju o klijentovom terminu (otkazivanje od klijenta) nije klijentova
--      obavijest;
--   4. drugi salon u `x-salon-id` ne vidi obavijesti prvog;
--   5. osoblje i anon dobijaju 42501;
--   6. `mark_notifications_read` oznacava samo svoje, i istorija ostaje i kad se uredjaj
--      odjavi.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table fix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak;
grant select on fix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fe000000-0000-4000-8000-000000000001', 'ana@obav70.invalid', '{"providers":["email"]}', '{}'),
('fe000000-0000-4000-8000-000000000003', 'bob@obav70.invalid', '{"providers":["email"]}', '{}'),
('fe000000-0000-4000-8000-000000000002', 'vlasnik@obav70.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('fe000000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'vlasnik@obav70.invalid', 'salon_admin');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- Vlasnikov uredjaj: prima `new_request` i `cancelled` od klijenta.
set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table vlasnik_uredjaj as select public.register_device((select salon from fix),
  'fe000000-0000-4000-8000-0000000000a2', repeat('c', 64), 'android', 'owner-token', true) as id;
reset role;

-- Ana: dva uredjaja, dva termina.
set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table ana_tel as select public.register_device((select salon from fix),
  'fe000000-0000-4000-8000-0000000000a1', repeat('a', 64), 'android', 'ana-tel') as id;
create temporary table ana_tablet as select public.register_device((select salon from fix),
  'fe000000-0000-4000-8000-0000000000a3', repeat('b', 64), 'ios', 'ana-tablet') as id;
create temporary table ana as select (public.ensure_customer((select salon from fix))).id as customer_id;
create temporary table ana_t1 as select (public.book_appointment((select salon from fix),
  (select customer_id from ana), (select usluga from fix), (select utorak from fix), '09:00',
  (select emir from fix), null, (select id from ana_tel))).id as id;
create temporary table ana_t2 as select (public.book_appointment((select salon from fix),
  (select customer_id from ana), (select usluga from fix), (select utorak from fix), '10:00',
  (select emir from fix), null, (select id from ana_tel))).id as id;
-- Ana sama otkazuje drugi termin: salon dobija `cancelled`, Ana ne dobija nista.
select public.cancel_appointment((select salon from fix), (select id from ana_t2));
reset role;
grant select on vlasnik_uredjaj, ana_tel, ana_tablet, ana, ana_t1, ana_t2 to public;

-- Bob: jedan uredjaj, jedan termin.
set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table bob_tel as select public.register_device((select salon from fix),
  'fe000000-0000-4000-8000-0000000000b1', repeat('d', 64), 'android', 'bob-tel') as id;
create temporary table bob as select (public.ensure_customer((select salon from fix))).id as customer_id;
create temporary table bob_t as select (public.book_appointment((select salon from fix),
  (select customer_id from bob), (select usluga from fix), (select utorak from fix), '11:00',
  (select emir from fix), null, (select id from bob_tel))).id as id;
reset role;
grant select on bob_tel, bob, bob_t to public;

-- Salon potvrdjuje oba preostala termina: trigger pise `confirmed` na uredjaj termina.
update public.appointments set status = 'confirmed', pending_expires_at = null
where id in ((select id from ana_t1), (select id from bob_t));
-- Ista potvrda i na Anin tablet — oblik koji nastaje kad klijent ima dva uredjaja.
insert into public.notification_logs(salon_id, appointment_id, device_id, type)
values ((select salon from fix), (select id from ana_t1), (select id from ana_tablet), 'confirmed');

select ok((select count(*) from public.notification_logs
  where appointment_id = (select id from ana_t2) and type = 'cancelled'
    and device_id = (select id from vlasnik_uredjaj)) = 1,
  'Polazno: salon ima red o Aninom otkazivanju');

-- ---------------------------------------------------------------------------
-- 1–3. Ana vidi svoju potvrdu jednom, i nista od Boba ni od salona
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table ana_lista as select * from public.my_notifications();
reset role;
grant select on ana_lista to public;

select is((select count(*)::int from ana_lista), 1,
  'Ana vidi tacno jednu obavijest: potvrdu, jednom iako je stigla na dva uredjaja');
select is((select type from ana_lista), 'confirmed', 'To je potvrda');
select is((select appointment_id from ana_lista), (select id from ana_t1), 'O njenom terminu');
select ok((select service_name is not null and start_time = '09:00' from ana_lista),
  'Stavka nosi uslugu i vrijeme termina');
select ok(not (select read from ana_lista), 'Nova obavijest je neprocitana');
select ok(not exists(select 1 from ana_lista where appointment_id = (select id from bob_t)),
  'Ana ne vidi Bobovu potvrdu');
select ok(not exists(select 1 from ana_lista where appointment_id = (select id from ana_t2)),
  'Red poslan salonu o Aninom otkazivanju nije Anina obavijest');

-- ---------------------------------------------------------------------------
-- 4. Drugi salon u kontekstu
-- ---------------------------------------------------------------------------
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
set local role authenticated;
select is((select count(*)::int from public.my_notifications()), 0,
  'U kontekstu drugog salona Ana ne vidi obavijesti prvog');
reset role;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- ---------------------------------------------------------------------------
-- 5. Osoblje i anon
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok($$ select * from public.my_notifications() $$, '42501', null,
  'Osoblje nema klijentsku istoriju');
select throws_ok($$ select public.mark_notifications_read() $$, '42501', null,
  'Osoblje ne oznacava tudje obavijesti');
reset role;
set local role anon;
select throws_ok($$ select * from public.my_notifications() $$, '42501', null,
  'Anon nema execute');
reset role;

-- ---------------------------------------------------------------------------
-- 6. Procitano i odjava uredjaja
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select is(public.mark_notifications_read(), 2, 'Ana oznacava oba reda svoje potvrde');
select ok((select read from public.my_notifications() limit 1), 'Potvrda je sada procitana');
reset role;

select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from bob_t) and read_at is not null), 0,
  'Bobova obavijest je ostala neprocitana');
select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from ana_t2) and read_at is not null), 0,
  'Salonov red o Aninom otkazivanju nije diran');

-- Odjava brise identitet sa uredjaja; istorija ide preko termina i ostaje.
update public.devices set auth_identity_id = null
where id in ((select id from ana_tel), (select id from ana_tablet));
set local role authenticated;
select is((select count(*)::int from public.my_notifications()), 1,
  'Istorija ostaje i kad se uredjaj odjavi');
reset role;

select * from finish();
rollback;
