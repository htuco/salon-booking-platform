-- Lista cekanja. Task 68, ADR-0031. Od taska 91 je upis raspon (`date_from`, `date_to`), a
-- `join_waitlist(usluga, radnik, od)` ga racuna; ovaj fajl i dalje dokazuje granice iz 68 na
-- rasponu od jednog dana (utorak je pun, srijeda slobodna). Raspon sam dokazuje
-- `036_lista_cekanja_raspon.test.sql`.
--
-- Granice:
--   1. pun dan je samo dan koji radi a nema slobodnog vremena; neradni dan i dan sa slobodnim
--      vremenom nisu, i na njih se ne moze upisati;
--   2. upis ide samo kroz RPC, samo za prijavljenog klijenta u salonu iz `x-salon-id`;
--      tabela nema nijedan grant;
--   3. najvise tri aktivna upisa po klijentu, ponovljen upis je isti red;
--   4. klijent vidi i odjavljuje samo svoje upise, i samo u salonu iz headera;
--   5. salon vidi samo broj po danu, i samo svoj; radnik, klijent i drugi salon ne;
--   6. otkazivanje budi samo upise kojima je bas ono otvorilo vrijeme (isti radnik,
--      preklapanje), samo u svom salonu, jednu ponudu po klijentu, i samo uredjaje vlasnika
--      upisa; salon redove ponuda ne vidi ni u logu;
--   7. ponuda je u istoriji vlasnika bez tudjeg termina, tudje „procitano" je ne dira, a
--      worker je salje;
--   8. potvrden termin iste usluge tog dana i brisanje naloga gase upis; zahtjev na cekanju i
--      odbijen zahtjev ne;
--   9. deaktivirana usluga ili radnik brisu upise koji ih traze.
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
create temporary table puni as select full_date from public.waitlist_full_dates(
  (select salon from fix), (select usluga from fix), (select utorak from fix), (select nedjelja from fix));
create temporary table puni_emir as select full_date from public.waitlist_full_dates(
  (select salon from fix), (select usluga from fix), (select utorak from fix), (select nedjelja from fix),
  (select emir from fix));
create temporary table puni_daleko as select full_date from public.waitlist_full_dates(
  (select salon from fix), (select usluga from fix), (select utorak from fix) + 60, (select utorak from fix) + 61);
reset role;
select ok((select utorak from fix) in (select full_date from puni),
  'Anon: utorak je pun (radi, a nema slobodnog vremena)');
select ok((select utorak from fix) in (select full_date from puni_emir), 'Utorak je pun i kod Emira');
select ok((select srijeda from fix) not in (select full_date from puni),
  'Srijeda ima slobodnog vremena, nije puna');
select ok((select nedjelja from fix) not in (select full_date from puni), 'Nedjelja ne radi, nije puna');
select is((select count(*)::int from puni_daleko), 0, 'Dan van prozora rezervacije nije pun');

-- ---------------------------------------------------------------------------
-- 2. Upis samo kroz RPC, samo klijent
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_tel as select public.register_device((select salon from fix),
  'fd000000-0000-4000-8000-0000000000a1', repeat('a', 64), 'android', 'ana-tel') as id;
create temporary table ana_tablet as select public.register_device((select salon from fix),
  'fd000000-0000-4000-8000-0000000000a2', repeat('c', 64), 'ios', 'ana-tablet') as id;
create temporary table ana_bilo_ko as select id from public.join_waitlist(
  (select usluga from fix), null, (select utorak from fix));
create temporary table ana_emir as select id from public.join_waitlist(
  (select usluga from fix), (select emir from fix), (select utorak from fix));
select is((select id from public.join_waitlist((select usluga from fix), null, (select utorak from fix))),
  (select id from ana_bilo_ko), 'Ponovljen upis vraca isti red');
-- Kod Amara, jer Ana vec ima upis „Bilo ko" za ovu uslugu, a isti kljuc vraca postojeci upis.
select throws_ok(format('select public.join_waitlist(%L, %L, %L)',
  (select usluga from fix), (select amar from fix), (select srijeda from fix)), 'PT400', null,
  'Upis na dan sa slobodnim vremenom pada (PT400)');
select throws_ok(format('select public.join_waitlist(%L, %L, %L)',
  (select usluga from fix), (select amar from fix), (select nedjelja from fix)), 'PT400', null,
  'Upis na neradni dan pada (PT400): raspon do slobodnog ponedjeljka nema punog dana');
select throws_ok('select * from public.waitlist_entries', '42501', null,
  'Klijent ne cita tabelu direktno (nema grant)');
select throws_ok(format(
  'insert into public.waitlist_entries(salon_id, auth_identity_id, service_id, date_from, date_to) values (%L, %L, %L, %L, %L)',
  (select salon from fix), (select auth_identity_id from public.devices where id = (select id from ana_tel)),
  (select usluga from fix), (select srijeda from fix), (select srijeda from fix)), '42501', null,
  'Klijent ne pise tabelu direktno, ni za dan koji nije pun');
reset role;
grant select on ana_tel, ana_tablet, ana_bilo_ko, ana_emir to public;
-- U testu oba upisa nastaju u istoj transakciji, pa dijele `created_at`. Ana se na „Bilo ko"
-- upisala minut ranije, kao sto bi i u aplikaciji (redoslijed bira upis koji dobija ponudu).
update public.waitlist_entries set created_at = created_at - interval '1 minute'
where id = (select id from ana_bilo_ko);

select is((select count(*)::int from public.waitlist_entries w
  join public.auth_identities ai on ai.id = w.auth_identity_id
  where ai.supabase_user_id = 'fd000000-0000-4000-8000-000000000001'), 2,
  'Ana ima dva upisa: „Bilo ko" i kod Emira');

-- Bez headera, osoblje i anon ne upisuju.
set local request.headers = '{}';
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
select throws_ok(format('select public.join_waitlist(%L, null, %L)',
  (select usluga from fix), (select utorak from fix)), '42501', null, 'Bez x-salon-id: 42501');
reset role;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select throws_ok(format('select public.join_waitlist(%L, null, %L)',
  (select usluga from fix), (select utorak from fix)), '42501', null, 'Vlasnik salona ne upisuje: 42501');
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(format('select public.join_waitlist(%L, null, %L)',
  (select usluga from fix), (select utorak from fix)), '42501', null, 'Anon ne upisuje: 42501');
reset role;

-- ---------------------------------------------------------------------------
-- 3. Limit
-- ---------------------------------------------------------------------------
-- Cira vec ima tri upisa (ubaceni su mimo RPC-a da test ne zavisi od tri puna dana), svaki za
-- drugu uslugu ili radnika: od taska 91 je isti kljuc jedan upis. Jedan istekao upis se ne broji.
select set_config('request.jwt.claims', (select cira from jwt), true);
set local role authenticated;
create temporary table cira_tel as select public.register_device((select salon from fix),
  'fd000000-0000-4000-8000-0000000000c1', repeat('d', 64), 'android', 'cira-tel') as id;
reset role;
grant select on cira_tel to public;
insert into public.waitlist_entries(salon_id, auth_identity_id, service_id, employee_id, date_from, date_to)
select f.salon, ai.id, v.usluga, v.radnik, v.dan, v.dan
from fix f, public.auth_identities ai, (values
  ('10000000-0000-4000-8000-000000000001'::uuid, '20000000-0000-4000-8000-000000000001'::uuid,
   (select srijeda from fix)),
  ('10000000-0000-4000-8000-000000000001'::uuid, '20000000-0000-4000-8000-000000000002'::uuid,
   (select cetvrtak from fix)),
  ('10000000-0000-4000-8000-000000000002'::uuid, null::uuid, (select petak from fix)),
  ('10000000-0000-4000-8000-000000000002'::uuid, '20000000-0000-4000-8000-000000000001'::uuid,
   (now() at time zone 'Europe/Sarajevo')::date - 2)
) v(usluga, radnik, dan)
where ai.supabase_user_id = 'fd000000-0000-4000-8000-000000000003';

select set_config('request.jwt.claims', (select cira from jwt), true);
set local role authenticated;
select throws_ok(format('select public.join_waitlist(%L, null, %L)',
  (select usluga from fix), (select utorak from fix)), 'PT429', null,
  'Cetvrti aktivan upis pada (PT429); istekao se ne broji');
select is((select count(*)::int from public.my_waitlist()), 3,
  'my_waitlist ne vraca istekao upis');
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
-- 6. Otkazivanje budi samo one kojima je bas ono otvorilo mjesto
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

-- Salon ne vidi redove ponuda ni u svom logu: `device_id` ponude bi ga preko
-- `appointments.device_id` doveo do imena i telefona onoga ko ceka.
select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select is((select count(*)::int from public.notification_logs where type = 'waitlist_offer'), 0,
  'Vlasnik salona ne vidi redove ponuda u logu');
select ok((select count(*)::int from public.notification_logs where appointment_id is not null) > 0,
  'Vlasnik i dalje vidi redove termina svog salona');
reset role;

-- Worker je prvu ponudu poslao prije sat vremena. Od sada istom upisu nova ponuda smije
-- nastati, ali samo kad je donese otkazivanje koje mu otvara vrijeme.
update public.notification_logs
set status = 'sent', sent_at = now() - interval '1 hour', created_at = now() - interval '1 hour'
where waitlist_entry_id is not null;

-- Nepovezana otkazivanja istog dana. Termini su ubaceni mimo RPC-a (dan je blokiran), kao
-- da su zakazani prije blokade:
--   * kod radnika koji ne radi tu uslugu, u isto vrijeme (16:00) — drugi radnik;
--   * kod Amara u 10:00, daleko od slobodnog 16:00 — vrijeme koje ne otvara mjesto.
insert into public.employees(id, salon_id, name)
select 'fd000000-0000-4000-8000-0000000000e3', salon, 'Treci' from fix;
insert into public.appointments(id, salon_id, service_id, employee_id, customer_id, customer_name,
  date, start_time, end_time, buffer_minutes, status, source)
select v.id, f.salon, f.usluga, v.emp, (select customer_id from bob), 'Walk-in', f.utorak,
  v.od, v.od + interval '30 minutes', 5, 'confirmed', 'manual'
from fix f, (values
  ('fd000000-0000-4000-8000-00000000aa01'::uuid, 'fd000000-0000-4000-8000-0000000000e3'::uuid, '16:00'::time),
  ('fd000000-0000-4000-8000-00000000aa02'::uuid, '20000000-0000-4000-8000-000000000002'::uuid, '10:00'::time)
) v(id, emp, od);

select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select public.cancel_appointment((select salon from fix), 'fd000000-0000-4000-8000-00000000aa01');
select public.cancel_appointment((select salon from fix), 'fd000000-0000-4000-8000-00000000aa02');
reset role;
select is((select count(*)::int from public.notification_logs where type = 'waitlist_offer'), 2,
  'Nepovezana otkazivanja istog dana (drugi radnik, vrijeme bez preklapanja) ne salju ponudu ponovo');

-- Cira ceka i u salonu B, isti utorak, a B u 10:00 ima slobodnog vremena. Termin bez radnika u
-- salonu A u 10:00 blokirao je svakog radnika u A; njegovo otkazivanje ne smije probuditi B.
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select set_config('request.jwt.claims', (select cira from jwt), true);
set local role authenticated;
create temporary table cira_tel_b as select public.register_device((select salon_b from fix),
  'fd000000-0000-4000-8000-0000000000c2', repeat('e', 64), 'android', 'cira-tel-b') as id;
reset role;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
grant select on cira_tel_b to public;
create temporary table cira_b as
select gen_random_uuid() as id, ai.id as identity
from public.auth_identities ai where ai.supabase_user_id = 'fd000000-0000-4000-8000-000000000003';
grant select on cira_b to public;
insert into public.waitlist_entries(id, salon_id, auth_identity_id, service_id, date_from, date_to)
select (select id from cira_b), f.salon_b, (select identity from cira_b),
  '10000000-0000-4000-8000-000000000005', f.utorak, f.utorak
from fix f;
select ok(exists(select 1 from public.get_available_slots((select salon_b from fix),
  '10000000-0000-4000-8000-000000000005', (select utorak from fix)) where start_time = '10:00'),
  'Polazno: salon B u utorak u 10:00 ima slobodno vrijeme');

insert into public.appointments(id, salon_id, service_id, employee_id, customer_id, customer_name,
  date, start_time, end_time, buffer_minutes, status, source)
select 'fd000000-0000-4000-8000-00000000aa03', f.salon, f.usluga, null, (select customer_id from bob),
  'Walk-in', f.utorak, '10:00', '10:30', 5, 'confirmed', 'manual'
from fix f;
select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select public.cancel_appointment((select salon from fix), 'fd000000-0000-4000-8000-00000000aa03');
reset role;
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from cira_b)), 0,
  'Otkazivanje u salonu A ne budi upis u salonu B');

-- Povezano otkazivanje: Bob otkazuje 16:00 kod Emira. Prva ponuda je poslana, pa ovo
-- oslobadjanje donosi novu. Oba Anina upisa mogu uzeti Emirovo vrijeme, a Ana dobija jednu
-- ponudu po uredjaju (najraniji upis, „Bilo ko"), ne dvije.
select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
select public.cancel_appointment((select salon from fix), (select id from bob_emir));
reset role;
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from ana_bilo_ko) and status = 'queued'), 2,
  'Povezano otkazivanje donosi novu ponudu, na oba Anina uredjaja');
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from ana_emir)), 0,
  'Jedna ponuda po klijentu: upis kod Emira je ne dobija uz „Bilo ko"');

-- Jos jedno povezano otkazivanje dok ta ponuda ceka slanje: nova se istom upisu ne dodaje.
insert into public.appointments(id, salon_id, service_id, employee_id, customer_id, customer_name,
  date, start_time, end_time, buffer_minutes, status, source)
select 'fd000000-0000-4000-8000-00000000aa04', f.salon, f.usluga, f.amar, (select customer_id from bob),
  'Walk-in', f.utorak, '16:00', '16:30', 5, 'confirmed', 'manual'
from fix f;
select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select public.cancel_appointment((select salon from fix), 'fd000000-0000-4000-8000-00000000aa04');
reset role;
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from ana_bilo_ko) and status = 'queued'), 2,
  'Dok ponuda ceka slanje, nova se istom upisu ne dodaje');

-- ---------------------------------------------------------------------------
-- 7. Istorija i worker
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_obavijesti as select * from public.my_notifications();
reset role;
select is((select count(*)::int from ana_obavijesti where type = 'waitlist_offer'), 2,
  'Ana vidi dvije ponude (dva oslobadjanja), ne cetiri reda uredjaja');
select ok((select bool_and(appointment_id is null and start_time is null) from ana_obavijesti
  where type = 'waitlist_offer'), 'Ponuda u istoriji nema termin ni vrijeme');
select ok((select bool_and(date = (select utorak from fix) and service_name = 'Muško šišanje')
  from ana_obavijesti where type = 'waitlist_offer'), 'Ponuda nosi dan i uslugu upisa');

select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
select is((select count(*)::int from public.my_notifications() where type = 'waitlist_offer'), 0,
  'Bob ne vidi Anine ponude');
-- Bob oznacava „procitano" prije Ane: grana ponuda trazi vlasnistvo upisa.
select public.mark_notifications_read();
reset role;
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from ana_bilo_ko) and read_at is null), 4,
  'Bobovo „procitano" ne dira Anine ponude');

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
select is((select count(*)::int from preuzeto where type = 'waitlist_offer'), 2,
  'Worker preuzima obje ponude koje cekaju slanje');
select ok((select bool_and(appointment_id is null) from preuzeto where type = 'waitlist_offer'),
  'Worker ne dobija termin uz ponudu');
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id is not null and error = 'recipient_unavailable'), 0,
  'Nijedna ponuda nije odbacena kao bez primaoca');

-- ---------------------------------------------------------------------------
-- 8. Upis se gasi tek potvrdenim terminom
-- ---------------------------------------------------------------------------
-- Salon radi u rucnom rezimu, pa Anin termin nastaje kao zahtjev (`pending`).
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_kupac as select (public.ensure_customer((select salon from fix))).id as customer_id;
create temporary table ana_zahtjev as select (public.book_appointment((select salon from fix),
  (select customer_id from ana_kupac), (select usluga from fix), (select utorak from fix), '16:00',
  (select amar from fix), null, (select id from ana_tel))).id as id;
select is((select count(*)::int from public.my_waitlist()), 2,
  'Zahtjev na cekanju ne gasi upis');
reset role;
grant select on ana_kupac, ana_zahtjev to public;
select is((select status::text from public.appointments where id = (select id from ana_zahtjev)),
  'pending', 'Polazno: Anin termin je zahtjev na cekanju');

select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select public.cancel_appointment((select salon from fix), (select id from ana_zahtjev), 'Odbijeno');
reset role;
select is((select count(*)::int from public.waitlist_entries
  where id in ((select id from ana_bilo_ko), (select id from ana_emir))), 2,
  'Odbijen zahtjev ostavlja oba upisa');

select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_termin as select (public.book_appointment((select salon from fix),
  (select customer_id from ana_kupac), (select usluga from fix), (select utorak from fix), '16:00',
  (select amar from fix), null, (select id from ana_tel))).id as id;
reset role;
grant select on ana_termin to public;
select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select public.set_appointment_status((select salon from fix), (select id from ana_termin),
  'confirmed', null);
reset role;
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
select is((select count(*)::int from public.my_waitlist()), 0,
  'Potvrda termina iste usluge tog dana gasi oba upisa');
reset role;
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id in ((select id from ana_bilo_ko), (select id from ana_emir))), 0,
  'Ponude ugasenih upisa nestaju sa njima');

-- Termin koji nastaje vec potvrden (auto rezim, rucni unos) gasi upis odmah. Cirin upis za
-- srijedu.
select set_config('request.jwt.claims', (select cira from jwt), true);
set local role authenticated;
create temporary table cira_kupac as select (public.ensure_customer((select salon from fix))).id as customer_id;
reset role;
insert into public.appointments(salon_id, service_id, employee_id, customer_id, auth_identity_id,
  customer_name, date, start_time, end_time, buffer_minutes, status, source)
select f.salon, f.usluga, f.emir, (select customer_id from cira_kupac), (select identity from cira_b),
  'Cira', f.srijeda, '12:00', '12:30', 5, 'confirmed', 'manual'
from fix f;
select is((select count(*)::int from public.waitlist_entries
  where auth_identity_id = (select identity from cira_b) and salon_id = (select salon from fix)
    and (select srijeda from fix) between date_from and date_to), 0,
  'Termin koji nastaje potvrden gasi upis');

select set_config('request.jwt.claims', (select cira from jwt), true);
set local role authenticated;
select public.delete_my_account();
reset role;
select is((select count(*)::int from public.waitlist_entries w
  join public.auth_identities ai on ai.id = w.auth_identity_id
  where ai.supabase_user_id = 'fd000000-0000-4000-8000-000000000003'), 0,
  'Brisanje naloga brise upise');

-- ---------------------------------------------------------------------------
-- 9. Deaktivirana usluga ili radnik
-- ---------------------------------------------------------------------------
-- Bob ceka u cetvrtak na tri nacina (mimo RPC-a, da test ne zavisi od punog dana): sisanje kod
-- Emira, sisanje kod bilo koga i bradu kod bilo koga.
create temporary table bob_upisi as
select gen_random_uuid() as id, v.oznaka, v.usluga, v.radnik
from (values
  ('emir', '10000000-0000-4000-8000-000000000001'::uuid, '20000000-0000-4000-8000-000000000001'::uuid),
  ('bilo_ko', '10000000-0000-4000-8000-000000000001'::uuid, null::uuid),
  ('brada', '10000000-0000-4000-8000-000000000002'::uuid, null::uuid)
) v(oznaka, usluga, radnik);
grant select on bob_upisi to public;
insert into public.waitlist_entries(id, salon_id, auth_identity_id, service_id, employee_id, date_from, date_to)
select b.id, f.salon, d.auth_identity_id, b.usluga, b.radnik, f.cetvrtak, f.cetvrtak
from bob_upisi b, fix f, public.devices d where d.id = (select id from bob_tel);

select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select public.set_employee_active((select salon from fix), (select emir from fix), false);
reset role;
select is((select array_agg(b.oznaka order by b.oznaka) from bob_upisi b
  join public.waitlist_entries w on w.id = b.id), array['bilo_ko', 'brada'],
  'Deaktiviran radnik brise upis kod njega; „Bilo ko" ostaje');

select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select public.set_service_active((select salon from fix), '10000000-0000-4000-8000-000000000002', false);
reset role;
select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
select is((select array_agg(service_name) from public.my_waitlist()), array['Muško šišanje'],
  'Deaktivirana usluga brise upis; my_waitlist i limit ga ne vide');
reset role;

select * from finish();
rollback;
