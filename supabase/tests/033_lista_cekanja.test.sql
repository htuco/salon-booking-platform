-- Lista cekanja. Task 68, ADR-0031.
--
-- Granice:
--   1. pun dan je samo dan koji radi a nema slobodnog vremena; neradni dan i dan sa slobodnim
--      vremenom nisu, i na njih se ne moze upisati;
--   2. upis ide samo kroz RPC, samo za prijavljenog klijenta u salonu iz `x-salon-id`;
--      tabela nema nijedan grant;
--   3. najvise tri aktivna upisa po klijentu, ponovljen upis je isti red;
--   4. klijent vidi i odjavljuje samo svoje upise, i samo u salonu iz headera;
--   5. salon vidi samo broj po danu, i samo svoj; radnik, klijent i drugi salon ne;
--   6. otkazivanje budi samo upise kojima se mjesto za njihovu uslugu i radnika stvarno
--      otvorilo, jednom po uredjaju dok ponuda ceka slanje, i samo uredjaje vlasnika upisa;
--   7. ponuda je u istoriji vlasnika bez tudjeg termina, a worker je salje;
--   8. termin iste usluge tog dana i brisanje naloga gase upis.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table fix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as salon_b,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  '20000000-0000-4000-8000-000000000002'::uuid as amar,
  -- Izvedeni datumi, ne fiksni: `max_advance_booking_days` je 30, a nedjelja je zatvorena.
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak,
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '9 days')::date as srijeda,
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '10 days')::date as cetvrtak,
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '11 days')::date as petak,
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '13 days')::date as nedjelja;
grant select on fix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fd000000-0000-4000-8000-000000000001', 'ana@cekanje68.invalid', '{"providers":["email"]}', '{}'),
('fd000000-0000-4000-8000-000000000002', 'bob@cekanje68.invalid', '{"providers":["email"]}', '{}'),
('fd000000-0000-4000-8000-000000000003', 'cira@cekanje68.invalid', '{"providers":["email"]}', '{}'),
('fd000000-0000-4000-8000-000000000004', 'vlasnik@cekanje68.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('fd000000-0000-4000-8000-000000000005', 'vlasnikb@cekanje68.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}', '{}'),
('fd000000-0000-4000-8000-000000000006', 'radnik@cekanje68.invalid',
 '{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role, employee_id) values
('fd000000-0000-4000-8000-000000000004', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'vlasnik@cekanje68.invalid', 'salon_admin', null),
('fd000000-0000-4000-8000-000000000005', '550e8400-e29b-41d4-a716-446655440001',
 'Vlasnik B', 'vlasnikb@cekanje68.invalid', 'salon_admin', null),
('fd000000-0000-4000-8000-000000000006', '550e8400-e29b-41d4-a716-446655440000',
 'Emir', 'radnik@cekanje68.invalid', 'employee', '20000000-0000-4000-8000-000000000001');

create temporary table jwt as select
  '{"sub":"fd000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}'::text as ana,
  '{"sub":"fd000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"providers":["email"]}}'::text as bob,
  '{"sub":"fd000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}'::text as cira,
  '{"sub":"fd000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}'::text as vlasnik,
  '{"sub":"fd000000-0000-4000-8000-000000000005","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}'::text as vlasnik_b,
  '{"sub":"fd000000-0000-4000-8000-000000000006","role":"authenticated","app_metadata":{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}'::text as radnik;
grant select on jwt to public;

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- Utorak: salon je blokiran do 16:00, pa za uslugu od 30 min (+5 bafer) ostaje 16:00–16:30
-- kod Emira i kod Amara. Bob zauzme 16:00 kod oba, i dan je pun.
insert into public.blocked_slots(salon_id, employee_id, date, start_time, end_time, reason)
select salon, null, utorak, '09:00', '16:00', 'test 68' from fix;

select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
create temporary table bob_tel as select public.register_device((select salon from fix),
  'fd000000-0000-4000-8000-0000000000b1', repeat('b', 64), 'android', 'bob-tel') as id;
create temporary table bob as select (public.ensure_customer((select salon from fix))).id as customer_id;
create temporary table bob_emir as select (public.book_appointment((select salon from fix),
  (select customer_id from bob), (select usluga from fix), (select utorak from fix), '16:00',
  (select emir from fix), null, (select id from bob_tel))).id as id;
create temporary table bob_amar as select (public.book_appointment((select salon from fix),
  (select customer_id from bob), (select usluga from fix), (select utorak from fix), '16:00',
  (select amar from fix), null, (select id from bob_tel))).id as id;
reset role;
grant select on bob_tel, bob, bob_emir, bob_amar to public;

select is((select count(*)::int from public.get_available_slots((select salon from fix),
  (select usluga from fix), (select utorak from fix))), 0, 'Polazno: utorak nema slobodnog vremena');

-- ---------------------------------------------------------------------------
-- 1. Pun dan
-- ---------------------------------------------------------------------------
set local role anon;
select is(public.waitlist_available((select salon from fix), (select usluga from fix),
  (select utorak from fix)), true, 'Anon: utorak je pun (radi, a nema slobodnog vremena)');
select is(public.waitlist_available((select salon from fix), (select usluga from fix),
  (select utorak from fix), (select emir from fix)), true, 'Utorak je pun i kod Emira');
select is(public.waitlist_available((select salon from fix), (select usluga from fix),
  (select srijeda from fix)), false, 'Srijeda ima slobodnog vremena, nije puna');
select is(public.waitlist_available((select salon from fix), (select usluga from fix),
  (select nedjelja from fix)), false, 'Nedjelja ne radi, nije puna');
select is(public.waitlist_available((select salon from fix), (select usluga from fix),
  (select utorak from fix) + 60), false, 'Dan van prozora rezervacije nije pun');
reset role;

-- ---------------------------------------------------------------------------
-- 2. Upis samo kroz RPC, samo klijent
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_tel as select public.register_device((select salon from fix),
  'fd000000-0000-4000-8000-0000000000a1', repeat('a', 64), 'android', 'ana-tel') as id;
create temporary table ana_tablet as select public.register_device((select salon from fix),
  'fd000000-0000-4000-8000-0000000000a2', repeat('c', 64), 'ios', 'ana-tablet') as id;
create temporary table ana_bilo_ko as select public.join_waitlist(
  (select usluga from fix), (select utorak from fix)) as id;
create temporary table ana_emir as select public.join_waitlist(
  (select usluga from fix), (select utorak from fix), (select emir from fix)) as id;
select is(public.join_waitlist((select usluga from fix), (select utorak from fix)),
  (select id from ana_bilo_ko), 'Ponovljen upis vraca isti red');
select throws_ok(format('select public.join_waitlist(%L, %L)',
  (select usluga from fix), (select srijeda from fix)), 'PT400', null,
  'Upis na dan sa slobodnim vremenom pada (PT400)');
select throws_ok(format('select public.join_waitlist(%L, %L)',
  (select usluga from fix), (select nedjelja from fix)), 'PT400', null,
  'Upis na neradni dan pada (PT400)');
select throws_ok('select * from public.waitlist_entries', '42501', null,
  'Klijent ne cita tabelu direktno (nema grant)');
select throws_ok(format(
  'insert into public.waitlist_entries(salon_id, auth_identity_id, service_id, date) values (%L, %L, %L, %L)',
  (select salon from fix), (select auth_identity_id from public.devices where id = (select id from ana_tel)),
  (select usluga from fix), (select srijeda from fix)), '42501', null,
  'Klijent ne pise tabelu direktno, ni za dan koji nije pun');
reset role;
grant select on ana_tel, ana_tablet, ana_bilo_ko, ana_emir to public;

select is((select count(*)::int from public.waitlist_entries w
  join public.auth_identities ai on ai.id = w.auth_identity_id
  where ai.supabase_user_id = 'fd000000-0000-4000-8000-000000000001'), 2,
  'Ana ima dva upisa: „Bilo ko" i kod Emira');

-- Bez headera, osoblje i anon ne upisuju.
set local request.headers = '{}';
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
select throws_ok(format('select public.join_waitlist(%L, %L)',
  (select usluga from fix), (select utorak from fix)), '42501', null, 'Bez x-salon-id: 42501');
reset role;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select throws_ok(format('select public.join_waitlist(%L, %L)',
  (select usluga from fix), (select utorak from fix)), '42501', null, 'Vlasnik salona ne upisuje: 42501');
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(format('select public.join_waitlist(%L, %L)',
  (select usluga from fix), (select utorak from fix)), '42501', null, 'Anon ne upisuje: 42501');
reset role;

-- ---------------------------------------------------------------------------
-- 3. Limit
-- ---------------------------------------------------------------------------
-- Cira vec ceka tri dana (upisi su ubaceni mimo RPC-a da test ne zavisi od tri puna dana).
-- Jedan prosli upis se ne broji.
select set_config('request.jwt.claims', (select cira from jwt), true);
set local role authenticated;
create temporary table cira_tel as select public.register_device((select salon from fix),
  'fd000000-0000-4000-8000-0000000000c1', repeat('d', 64), 'android', 'cira-tel') as id;
reset role;
grant select on cira_tel to public;
insert into public.waitlist_entries(salon_id, auth_identity_id, service_id, date)
select f.salon, ai.id, f.usluga, d
from fix f, public.auth_identities ai,
  unnest(array[f.srijeda, f.cetvrtak, f.petak, (now() at time zone 'Europe/Sarajevo')::date - 2]) d
where ai.supabase_user_id = 'fd000000-0000-4000-8000-000000000003';

select set_config('request.jwt.claims', (select cira from jwt), true);
set local role authenticated;
select throws_ok(format('select public.join_waitlist(%L, %L)',
  (select usluga from fix), (select utorak from fix)), 'PT429', null,
  'Cetvrti aktivan upis pada (PT429); prosli se ne broji');
select is((select count(*)::int from public.my_waitlist()), 3,
  'my_waitlist ne vraca prosli dan');
reset role;

-- ---------------------------------------------------------------------------
-- 4. Klijent vidi i odjavljuje samo svoje
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_lista as select * from public.my_waitlist();
reset role;
select is((select count(*)::int from ana_lista), 2, 'Ana vidi svoja dva upisa');
select is((select service_name from ana_lista where id = (select id from ana_emir)),
  'Muško šišanje', 'Upis nosi naziv usluge');
select is((select employee_name from ana_lista where id = (select id from ana_emir)),
  'Emir', 'Upis kod Emira nosi ime radnika');
select ok((select employee_name is null from ana_lista where id = (select id from ana_bilo_ko)),
  '„Bilo ko" nema radnika');

select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
select is((select count(*)::int from public.my_waitlist()), 0, 'Bob ne vidi Anine upise');
select lives_ok(format('select public.leave_waitlist(%L)', (select id from ana_bilo_ko)),
  'Bobova odjava tudjeg upisa ne baca gresku');
reset role;
select ok(exists(select 1 from public.waitlist_entries where id = (select id from ana_bilo_ko)),
  'Bobova odjava tudjeg upisa ga ne brise');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
select is((select count(*)::int from public.my_waitlist()), 0,
  'U drugom salonu Ana ne vidi upise prvog');
select lives_ok(format('select public.leave_waitlist(%L)', (select id from ana_bilo_ko)),
  'Odjava iz drugog salona ne baca gresku');
reset role;
select ok(exists(select 1 from public.waitlist_entries where id = (select id from ana_bilo_ko)),
  'Odjava sa headerom drugog salona ne brise upis');
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- ---------------------------------------------------------------------------
-- 5. Salon vidi samo broj
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select is((select waiting from public.waitlist_demand((select salon from fix),
  (select utorak from fix), (select petak from fix)) where date = (select utorak from fix)), 1,
  'Vlasnik vidi jednog klijenta na utorak (Ana sa dva upisa je jedan klijent)');
select is((select waiting from public.waitlist_demand((select salon from fix),
  (select utorak from fix), (select petak from fix)) where date = (select srijeda from fix)), 1,
  'Vlasnik vidi Ciru na srijedu');
select throws_ok('select * from public.waitlist_entries', '42501', null,
  'Vlasnik ne cita upise direktno');
select throws_ok(format('select * from public.waitlist_demand(%L, %L, %L)',
  (select salon from fix), (select utorak from fix), (select utorak from fix) + 90), 'PT400', null,
  'Raspon duzi od 63 dana pada');
reset role;

select set_config('request.jwt.claims', (select vlasnik_b from jwt), true);
set local role authenticated;
select throws_ok(format('select * from public.waitlist_demand(%L, %L, %L)',
  (select salon from fix), (select utorak from fix), (select petak from fix)), '42501', null,
  'Vlasnik drugog salona ne vidi potraznju: 42501');
reset role;
select set_config('request.jwt.claims', (select radnik from jwt), true);
set local role authenticated;
select throws_ok(format('select * from public.waitlist_demand(%L, %L, %L)',
  (select salon from fix), (select utorak from fix), (select petak from fix)), '42501', null,
  'Radnik ne vidi potraznju: 42501');
reset role;
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
select throws_ok(format('select * from public.waitlist_demand(%L, %L, %L)',
  (select salon from fix), (select utorak from fix), (select petak from fix)), '42501', null,
  'Klijent ne vidi potraznju: 42501');
reset role;

-- ---------------------------------------------------------------------------
-- 6. Otkazivanje budi samo one kojima se mjesto otvorilo
-- ---------------------------------------------------------------------------
-- Salon otkazuje Bobov termin kod Amara: otvara se 16:00 kod Amara. Anin „Bilo ko" ga moze
-- uzeti, a Anin upis kod Emira ne.
select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select public.cancel_appointment((select salon from fix), (select id from bob_amar));
reset role;

select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from ana_bilo_ko) and type = 'waitlist_offer'), 2,
  '„Bilo ko" dobija ponudu, na oba Anina uredjaja');
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from ana_emir)), 0,
  'Upis kod Emira ne dobija nista: kod Emira se nije oslobodilo');
select is((select count(*)::int from public.notification_logs
  where type = 'waitlist_offer' and device_id in ((select id from bob_tel), (select id from cira_tel))), 0,
  'Ponuda ide samo uredjajima vlasnika upisa');
select ok((select bool_and(appointment_id is null) from public.notification_logs
  where waitlist_entry_id is not null), 'Ponuda ne nosi oslobodjen (tudji) termin');

-- Drugo oslobadjanje istog dana dok prva ponuda ceka slanje: „Bilo ko" ne dobija drugu,
-- upis kod Emira dobija prvu.
select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
select public.cancel_appointment((select salon from fix), (select id from bob_emir));
reset role;
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from ana_bilo_ko)), 2,
  'Dok ponuda ceka slanje, nova se istom upisu ne dodaje');
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from ana_emir)), 2,
  'Klijentovo otkazivanje kod Emira budi upis kod Emira');

-- ---------------------------------------------------------------------------
-- 7. Istorija i worker
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_obavijesti as select * from public.my_notifications();
reset role;
select is((select count(*)::int from ana_obavijesti where type = 'waitlist_offer'), 2,
  'Ana vidi dvije ponude (po jednu za svaki upis), ne cetiri reda uredjaja');
select ok((select bool_and(appointment_id is null and start_time is null) from ana_obavijesti
  where type = 'waitlist_offer'), 'Ponuda u istoriji nema termin ni vrijeme');
select ok((select bool_and(date = (select utorak from fix) and service_name = 'Muško šišanje')
  from ana_obavijesti where type = 'waitlist_offer'), 'Ponuda nosi dan i uslugu upisa');

select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
select is((select count(*)::int from public.my_notifications() where type = 'waitlist_offer'), 0,
  'Bob ne vidi Anine ponude');
reset role;

select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
select ok(public.mark_notifications_read() >= 4, 'mark_notifications_read oznacava i ponude');
reset role;
select ok((select bool_and(read_at is not null) from public.notification_logs
  where waitlist_entry_id in ((select id from ana_bilo_ko), (select id from ana_emir))),
  'Sve Anine ponude su procitane');

set local role service_role;
create temporary table preuzeto as select * from public.claim_push_notifications(100);
reset role;
select is((select count(*)::int from preuzeto where type = 'waitlist_offer'), 4,
  'Worker preuzima sve cetiri ponude');
select ok((select bool_and(appointment_id is null) from preuzeto where type = 'waitlist_offer'),
  'Worker ne dobija termin uz ponudu');
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id is not null and error = 'recipient_unavailable'), 0,
  'Nijedna ponuda nije odbacena kao bez primaoca');

-- ---------------------------------------------------------------------------
-- 8. Upis se gasi
-- ---------------------------------------------------------------------------
-- Ana zakaze oslobodjeno mjesto kod Amara: oba njena upisa za tu uslugu i dan nestaju, sa
-- svojim ponudama.
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_kupac as select (public.ensure_customer((select salon from fix))).id as customer_id;
select lives_ok(format('select public.book_appointment(%L, %L, %L, %L, %L, %L, null, %L)',
  (select salon from fix), (select customer_id from ana_kupac), (select usluga from fix),
  (select utorak from fix), '16:00', (select amar from fix), (select id from ana_tel)),
  'Ana zakazuje oslobodjeno mjesto');
select is((select count(*)::int from public.my_waitlist()), 0,
  'Termin iste usluge tog dana gasi oba upisa');
reset role;
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id in ((select id from ana_bilo_ko), (select id from ana_emir))), 0,
  'Ponude ugasenih upisa nestaju sa njima');

select set_config('request.jwt.claims', (select cira from jwt), true);
set local role authenticated;
select public.delete_my_account();
reset role;
select is((select count(*)::int from public.waitlist_entries w
  join public.auth_identities ai on ai.id = w.auth_identity_id
  where ai.supabase_user_id = 'fd000000-0000-4000-8000-000000000003'), 0,
  'Brisanje naloga brise upise');

select * from finish();
rollback;
