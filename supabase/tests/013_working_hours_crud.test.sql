-- Admin CRUD nad radnim vremenom, pauzama i blokadama. Task 34.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table wfix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as drugi_salon,
  '20000000-0000-4000-8000-000000000001'::uuid as radnik,
  '20000000-0000-4000-8000-000000000002'::uuid as radnik2,
  -- Radnik drugog salona: isti test i za `set_working_hours` i za blokadu.
  '20000000-0000-4000-8000-000000000003'::uuid as tudji_radnik,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  'ee000000-0000-4000-8000-000000000042'::uuid as admin,
  'ee000000-0000-4000-8000-000000000043'::uuid as tudji_admin,
  'ee000000-0000-4000-8000-000000000044'::uuid as customer,
  -- Utorak sljedece sedmice: uvijek u buducnosti, uvijek isti ISO dan (2).
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak;
grant select on wfix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('ee000000-0000-4000-8000-000000000042', 'admin-rv-a@invalid.test',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('ee000000-0000-4000-8000-000000000043', 'admin-rv-b@invalid.test',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
((select admin from wfix), (select salon from wfix), 'Admin A', 'admin-rv-a@invalid.test', 'salon_admin'),
((select tudji_admin from wfix), (select drugi_salon from wfix), 'Admin B', 'admin-rv-b@invalid.test', 'salon_admin');
insert into public.customers(id, salon_id, name)
values ((select customer from wfix), (select salon from wfix), 'Test klijent RV');

-- Puna sedmica, otvoreno 09–17, kao pomocna vrijednost za vise testova.
create temporary table sedmica as
select array_agg((g, '09:00', '17:00', null, null, false)::public.working_hours_input order by g)
  as dani
from generate_series(1, 7) g;
grant select on sedmica to public;

-- ---------------------------------------------------------------------------
-- 1. Grant je granica: tabele se citaju, ali se vise ne pisu direktno
-- ---------------------------------------------------------------------------
select bag_eq($$
  select privilege_type::text from information_schema.role_table_grants
  where grantee = 'authenticated' and table_name = 'working_hours'
$$, array['SELECT'], 'Radno vrijeme se samo cita direktno');
select bag_eq($$
  select privilege_type::text from information_schema.role_table_grants
  where grantee = 'authenticated' and table_name = 'blocked_slots'
$$, array['SELECT'], 'Blokade se samo citaju direktno');
-- Task 31 je ovo provjerio pozivom i nasao da upis prolazi; od ovog taska ne prolazi.
select ok(not has_table_privilege('authenticated', 'public.blocked_slots', 'INSERT'),
  'Direktan insert blokade je oduzet');
select ok(not has_table_privilege('authenticated', 'public.working_hours', 'UPDATE'),
  'Direktan update radnog vremena je oduzet');
select ok(not has_function_privilege('anon',
  'public.set_working_hours(uuid, public.working_hours_input[], uuid)', 'EXECUTE'),
  'Anon ne pise radno vrijeme');
select ok(not has_function_privilege('anon',
  'public.create_blocked_slot(uuid, date, time, time, text, uuid)', 'EXECUTE'),
  'Anon ne pise blokade');

-- ---------------------------------------------------------------------------
-- 2. Sedmica se pise u cjelini
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000042","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;

select throws_ok($$select set_working_hours((select salon from wfix), null)$$,
  'PT400', null, 'NULL sedmica je odbijena');
select throws_ok($$
  select set_working_hours((select salon from wfix),
    array[(1,'09:00','17:00',null,null,false)]::working_hours_input[])
$$, 'PT400', null, 'Nepotpuna sedmica je odbijena');
-- Sest dana + duplikat: duzina je 7, ali jedan ISO dan nedostaje. Provjera po duzini
-- sama ovo pusta, pa zato postoji i provjera pokrivenosti.
select throws_ok($$
  select set_working_hours((select salon from wfix),
    (select array_agg((case when g = 7 then 1 else g end,'09:00','17:00',null,null,false)::working_hours_input)
     from generate_series(1,7) g))
$$, 'PT400', null, 'Duplikat dana uz tacnu duzinu je odbijen');
select throws_ok($$
  select set_working_hours((select salon from wfix),
    (select array_agg((g,'17:00','09:00',null,null,false)::working_hours_input) from generate_series(1,7) g))
$$, 'PT400', null, 'Kraj prije pocetka je odbijen');
select throws_ok($$
  select set_working_hours((select salon from wfix),
    (select array_agg((g,'09:00','17:00','08:00','08:30',false)::working_hours_input) from generate_series(1,7) g))
$$, 'PT400', null, 'Pauza van radnog vremena je odbijena');
select throws_ok($$
  select set_working_hours((select salon from wfix),
    (select array_agg((g,'09:00','17:00','12:00',null,false)::working_hours_input) from generate_series(1,7) g))
$$, 'PT400', null, 'Polovicna pauza je odbijena');

select lives_ok($$select set_working_hours((select salon from wfix), (select dani from sedmica))$$,
  'Admin pise sedmicni raspored salona');
select is(
  (select count(*)::int from working_hours
   where salon_id = (select salon from wfix) and employee_id is null), 7,
  'Sedam salonskih redova, ni jedan vise');

-- Upsert, ne delete+insert: ID reda prezivi izmjenu.
create temporary table prije as
  select id, day_of_week from working_hours
  where salon_id = (select salon from wfix) and employee_id is null;
grant select on prije to public;
select lives_ok($$
  select set_working_hours((select salon from wfix),
    (select array_agg((g, '08:00', '20:00', '13:00', '14:00', g = 7)::working_hours_input order by g)
     from generate_series(1,7) g))
$$, 'Ponovni upis mijenja isti raspored');
select results_eq(
  'select id, day_of_week from prije order by day_of_week',
  $$select id, day_of_week from working_hours
    where salon_id = (select salon from wfix) and employee_id is null order by day_of_week$$,
  'Upsert cuva ID-eve, ne pravi nove redove');
select is((select start_time from working_hours
  where salon_id = (select salon from wfix) and employee_id is null and day_of_week = 1),
  '08:00'::time, 'Nova vrijednost je zapisana');
-- Zatvoren dan ne nosi pauzu: engine je ne cita, a ostavljena bi bila neistina u redu.
select is((select break_start_time from working_hours
  where salon_id = (select salon from wfix) and employee_id is null and day_of_week = 7),
  null::time, 'Zatvoren dan nema pauzu');
select ok((select is_closed from working_hours
  where salon_id = (select salon from wfix) and employee_id is null and day_of_week = 7),
  'Nedjelja je zatvorena');

-- Radnikov raspored je zaseban sloj, ne zamjena za salonski.
select lives_ok($$
  select set_working_hours((select salon from wfix), (select dani from sedmica), (select radnik from wfix))
$$, 'Admin pise raspored radnika');
select is((select count(*)::int from working_hours where salon_id = (select salon from wfix)), 14,
  'Radnikov raspored ne brise salonski');
select throws_ok($$
  select set_working_hours((select salon from wfix), (select dani from sedmica),
    (select tudji_radnik from wfix))
$$, '42501', null, 'Radnik drugog salona je odbijen');
reset role;

-- ---------------------------------------------------------------------------
-- 3. Tudji salon: ni pisanje ni citanje konflikata
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000043","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select throws_ok($$select set_working_hours((select salon from wfix), (select dani from sedmica))$$,
  '42501', null, 'Tudji admin ne pise radno vrijeme');
select throws_ok($$
  select create_blocked_slot((select salon from wfix), (select utorak from wfix), '09:00', '10:00')
$$, '42501', null, 'Tudji admin ne pise blokadu');
select throws_ok($$
  select * from working_hours_conflicts((select salon from wfix), null, (select dani from sedmica))
$$, '42501', null, 'Tudji admin ne cita konflikte');
select throws_ok($$
  select * from blocked_slot_conflicts((select salon from wfix), (select utorak from wfix), '09:00', '10:00')
$$, '42501', null, 'Tudji admin ne cita konflikte blokade');
-- Admin B nad **svojim** salonom, ali sa nasim radnikom: prolazi `is_admin`, pada na radniku.
-- Bez ove asercije provjera radnika u `*_conflicts` ne bi imala sta da je drzi.
select throws_ok($$
  select * from blocked_slot_conflicts((select drugi_salon from wfix), (select utorak from wfix),
    '09:00', '10:00', (select radnik from wfix))
$$, '42501', null, 'Radnik tudjeg salona je odbijen i u citanju konflikata blokade');
select throws_ok($$
  select * from working_hours_conflicts((select drugi_salon from wfix), (select radnik from wfix),
    (select dani from sedmica))
$$, '42501', null, 'Radnik tudjeg salona je odbijen i u citanju konflikata rasporeda');
reset role;

-- ---------------------------------------------------------------------------
-- 4. Postojeci termin se ne brise tiho — admin ga vidi
-- ---------------------------------------------------------------------------
insert into public.appointments(
  salon_id, service_id, employee_id, customer_id, customer_name,
  date, start_time, end_time, status)
select w.salon, w.usluga, w.radnik, w.customer, 'Test klijent RV',
  w.utorak, '18:00', '18:30', 'confirmed'
from wfix w;

-- Claim se postavlja ponovo: odjeljak 3 ga je prebacio na tudjeg admina.
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000042","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
-- Sedmica 09–17 izbacuje termin u 18:00 iz radnog vremena.
select is(
  (select count(*)::int from working_hours_conflicts(
    (select salon from wfix), null, (select dani from sedmica))), 1,
  'Termin van novog radnog vremena je prijavljen');
select is(
  (select reason from working_hours_conflicts(
    (select salon from wfix), null, (select dani from sedmica))), 'Van radnog vremena',
  'Razlog imenuje sta je termin prekrsilo');
-- Prijava je citanje: sam poziv ne smije nista promijeniti.
select is((select count(*)::int from appointments where salon_id = (select salon from wfix)
  and date = (select utorak from wfix)), 1, 'Provjera konflikata ne brise termin');

select lives_ok($$select set_working_hours((select salon from wfix), (select dani from sedmica))$$,
  'Snimanje prolazi i kad termin ispada van radnog vremena');
select is((select count(*)::int from appointments where salon_id = (select salon from wfix)
  and date = (select utorak from wfix) and status = 'confirmed'), 1,
  'Termin van novog radnog vremena ostaje, ne brise se tiho');

-- Pauza preko termina: drugi razlog, isti ugovor.
select is(
  (select reason from working_hours_conflicts((select salon from wfix), null,
    (select array_agg((g,'09:00','20:00','18:00','19:00',false)::working_hours_input order by g)
     from generate_series(1,7) g))), 'Unutar pauze',
  'Termin unutar pauze je prijavljen kao pauza');
-- Zatvorena sedmica prijavljuje **svaki** buduci termin salona, ne samo fixture iz ovog
-- fajla: seed nosi svoje. Zato se poredi sa stvarnim brojem buducih termina, a ne sa
-- konstantom — konstanta bi pukla sljedeci put kad seed dobije jedan red vise.
select is(
  (select count(*)::int from working_hours_conflicts((select salon from wfix), null,
    (select array_agg((g,'09:00','17:00',null,null,true)::working_hours_input order by g)
     from generate_series(1,7) g))),
  (select count(*)::int from appointments where salon_id = (select salon from wfix)
    and status in ('pending','confirmed') and date >= current_date),
  'Zatvorena sedmica prijavljuje svaki buduci termin');
-- Raspored radnika mjeri samo njegove termine.
select is(
  (select count(*)::int from working_hours_conflicts(
    (select salon from wfix), (select radnik2 from wfix), (select dani from sedmica))), 0,
  'Raspored drugog radnika ne prijavljuje tudji termin');
-- Tudji radnik sada pada na guard, a ne tiho vraca praznu listu. Razlika je bitna: prazna
-- lista se ne razlikuje od „nema konflikata", pa bi maknut `salon_id` predikat prosao nezapazeno.
select throws_ok($$
  select * from working_hours_conflicts((select salon from wfix), (select tudji_radnik from wfix),
    (select dani from sedmica))
$$, '42501', null, 'Radnik drugog salona je odbijen, ne vraca praznu listu');
select throws_ok($$
  select * from blocked_slot_conflicts((select salon from wfix), (select utorak from wfix),
    '09:00', '23:00', (select tudji_radnik from wfix))
$$, '42501', null, 'Radnik drugog salona je odbijen i kod blokade');
reset role;

-- `salon_id` predikat u `*_conflicts` mora stvarno filtrirati, ne samo `employee_id`.
-- Termin salona B u isto vrijeme: admin A ga ne smije vidjeti ni sa svojim `p_salon_id`.
insert into public.customers(id, salon_id, name)
values ('cc000000-0000-4000-8000-000000000034', (select drugi_salon from wfix), 'Klijent B');
insert into public.appointments(
  salon_id, service_id, employee_id, customer_id, customer_name,
  date, start_time, end_time, status)
select w.drugi_salon, '10000000-0000-4000-8000-000000000005', w.tudji_radnik,
  'cc000000-0000-4000-8000-000000000034', 'Klijent B', w.utorak, '18:00', '18:30', 'confirmed'
from wfix w;
set local role authenticated;
select is_empty($$
  select * from blocked_slot_conflicts((select salon from wfix), (select utorak from wfix),
    '17:00', '19:00')
  where customer_name = 'Klijent B'
$$, 'Termin drugog salona ne izlazi kroz konflikte blokade');
select is_empty($$
  select * from working_hours_conflicts((select salon from wfix), null, (select dani from sedmica))
  where customer_name = 'Klijent B'
$$, 'Termin drugog salona ne izlazi kroz konflikte rasporeda');
reset role;

-- Proslost se ne prijavljuje: raspored se mijenja unaprijed.
insert into public.appointments(
  salon_id, service_id, employee_id, customer_id, customer_name,
  date, start_time, end_time, status)
select w.salon, w.usluga, w.radnik, w.customer, 'Test klijent RV',
  current_date - 7, '18:00', '18:30', 'confirmed'
from wfix w;
set local role authenticated;
select is(
  (select count(*)::int from working_hours_conflicts(
    (select salon from wfix), null, (select dani from sedmica))), 1,
  'Prosli termin se ne prijavljuje');
reset role;

-- ---------------------------------------------------------------------------
-- 5. Blokade: neradni dan salona i odsustvo radnika
-- ---------------------------------------------------------------------------
set local role authenticated;
select throws_ok($$
  select create_blocked_slot((select salon from wfix), (select utorak from wfix), '10:00', '10:00')
$$, 'PT400', null, 'Blokada bez trajanja je odbijena');
select throws_ok($$
  select create_blocked_slot((select salon from wfix), null, '10:00', '11:00')
$$, 'PT400', null, 'Blokada bez datuma je odbijena');
select throws_ok($$
  select create_blocked_slot((select salon from wfix), (select utorak from wfix), '10:00', '11:00',
    null, (select tudji_radnik from wfix))
$$, '42501', null, 'Blokada nad tudjim radnikom je odbijena');

create temporary table blokada as
  select * from public.create_blocked_slot((select salon from wfix), (select utorak from wfix),
    '12:00', '13:00', '  Inventura  ');
grant select on blokada to public;
select is((select reason from blokada), 'Inventura', 'Razlog je normalizovan');
select is((select employee_id from blokada), null::uuid, 'Blokada bez radnika je salonska');
select lives_ok($$
  select create_blocked_slot((select salon from wfix), (select utorak from wfix), '14:00', '15:00',
    '', (select radnik from wfix))
$$, 'Blokada radnika je dozvoljena');
select is((select reason from blocked_slots where salon_id = (select salon from wfix)
  and start_time = '14:00'), null::text, 'Prazan razlog postaje NULL');

-- Blokada oduzima slotove, i to je jedini dokaz da je zaista ulaz u availability.
select is_empty($$
  select * from get_available_slots((select salon from wfix), (select usluga from wfix),
    (select utorak from wfix), (select radnik from wfix))
  where start_time >= '12:00' and start_time < '13:00'
$$, 'Blokada salona uklanja slotove iz availabilityja');

-- Termin unutar blokade se prijavljuje, a ne brise.
select is(
  (select count(*)::int from blocked_slot_conflicts((select salon from wfix),
    (select utorak from wfix), '17:30', '19:00')), 1,
  'Termin unutar nove blokade je prijavljen');
select is(
  (select count(*)::int from blocked_slot_conflicts((select salon from wfix),
    (select utorak from wfix), '17:30', '19:00', (select radnik2 from wfix))), 0,
  'Blokada drugog radnika ne prijavljuje tudji termin');
select lives_ok($$
  select create_blocked_slot((select salon from wfix), (select utorak from wfix), '17:30', '19:00')
$$, 'Blokada preko postojeceg termina je dozvoljena');
select is((select count(*)::int from appointments where salon_id = (select salon from wfix)
  and date = (select utorak from wfix) and status = 'confirmed'), 1,
  'Blokada ne brise termin ispod sebe');

select throws_ok($$
  select delete_blocked_slot((select salon from wfix), '00000000-0000-4000-8000-000000000000')
$$, '42501', null, 'Nepostojeca blokada daje istu gresku kao tudja');
select lives_ok($$select delete_blocked_slot((select salon from wfix), (select id from blokada))$$,
  'Admin brise svoju blokadu');
select is((select count(*)::int from blocked_slots where id = (select id from blokada)), 0,
  'Blokada je stvarno obrisana');
reset role;

-- Tudji admin ne brise nasu blokadu.
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000043","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select throws_ok($$
  select delete_blocked_slot((select drugi_salon from wfix),
    (select id from blocked_slots where salon_id = (select salon from wfix) limit 1))
$$, '42501', null, 'Tudja blokada se ne brise ni sa svojim salon_id-om');
reset role;

select * from finish();
rollback;
