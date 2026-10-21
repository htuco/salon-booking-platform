-- Lista cekanja sa rasponom. Task 91, ADR-0031 (dopuna 2026-10-21).
--
-- Polazno stanje (salon A, „Muško šišanje"):
--   * od danas (T) do dana prije P sve je blokirano — dani bez slobodnog vremena, ali ne puni;
--   * P..P+4 (ponedjeljak–petak, za dvije sedmice) su puni: blokada do 16:00 i termin u 16:00 kod
--     Emira i kod Amara;
--   * P+5 (subota) je prvi slobodan dan; kod Amara je blokirano sve od P+5 do kraja prozora.
--
-- Granice:
--   1. raspon racuna baza: od izabranog dana (ili danas) do dana prije prvog slobodnog, ili do
--      kraja prozora; slobodan prvi dan, raspon bez punog dana, dan van prozora i `date_only`
--      salon se odbijaju; ponovljen upis vraca postojeci, granica se ne pomjera;
--   2. limit tri, a raspon je jedan upis;
--   3. `my_waitlist` vraca raspon bez proslih dana i bez isteklih upisa;
--   4. `waitlist_demand` broji upis na svaki dan raspona, po identitetu;
--   5. otkazivanje u rasponu budi i ponuda pamti dan; prije i poslije raspona, nepovezano,
--      prosli dan i drugi salon ne bude;
--   6. potvrden termin bilo koji dan u rasponu gasi upis; `pending` i granicni dan ne gase;
--   7. istekao upis nestaje sa ponudama i ne blokira novi upis;
--   8. tenant izolacija: Bob, drugi salon, anon, radnik, vlasnik drugog salona;
--   9. sema: nema kolone `date`, ponuda mora imati dan, cron postoji.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table fix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as salon_b,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  '10000000-0000-4000-8000-000000000003'::uuid as paket,
  '10000000-0000-4000-8000-000000000005'::uuid as usluga_b,
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  '20000000-0000-4000-8000-000000000002'::uuid as amar,
  (now() at time zone 'Europe/Sarajevo')::date as t,
  -- Ponedjeljak za dvije sedmice: T+8..T+14, pa je i P+5 daleko od `min_advance_booking_hours`,
  -- a T+30 (kraj prozora) iza svega.
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '14 days')::date as p;
grant select on fix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fe910000-0000-4000-8000-000000000001', 'ana@raspon91.invalid', '{"providers":["email"]}', '{}'),
('fe910000-0000-4000-8000-000000000002', 'bob@raspon91.invalid', '{"providers":["email"]}', '{}'),
('fe910000-0000-4000-8000-000000000003', 'cira@raspon91.invalid', '{"providers":["email"]}', '{}'),
('fe910000-0000-4000-8000-000000000004', 'dino@raspon91.invalid', '{"providers":["email"]}', '{}'),
('fe910000-0000-4000-8000-000000000005', 'vlasnik@raspon91.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('fe910000-0000-4000-8000-000000000006', 'vlasnikb@raspon91.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}', '{}'),
('fe910000-0000-4000-8000-000000000007', 'radnik@raspon91.invalid',
 '{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role, employee_id) values
('fe910000-0000-4000-8000-000000000005', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'vlasnik@raspon91.invalid', 'salon_admin', null),
('fe910000-0000-4000-8000-000000000006', '550e8400-e29b-41d4-a716-446655440001',
 'Vlasnik B', 'vlasnikb@raspon91.invalid', 'salon_admin', null),
('fe910000-0000-4000-8000-000000000007', '550e8400-e29b-41d4-a716-446655440000',
 'Emir', 'radnik@raspon91.invalid', 'employee', '20000000-0000-4000-8000-000000000001');

create temporary table jwt as select
  '{"sub":"fe910000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}'::text as ana,
  '{"sub":"fe910000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"providers":["email"]}}'::text as bob,
  '{"sub":"fe910000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}'::text as cira,
  '{"sub":"fe910000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"providers":["email"]}}'::text as dino,
  '{"sub":"fe910000-0000-4000-8000-000000000005","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}'::text as vlasnik,
  '{"sub":"fe910000-0000-4000-8000-000000000006","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}'::text as vlasnik_b,
  '{"sub":"fe910000-0000-4000-8000-000000000007","role":"authenticated","app_metadata":{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}'::text as radnik;
grant select on jwt to public;

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- ---------------------------------------------------------------------------
-- Polazno stanje
-- ---------------------------------------------------------------------------
insert into public.blocked_slots(salon_id, employee_id, date, start_time, end_time, reason)
select f.salon, null, d::date, '00:00', '23:59', 'test 91: bez slobodnog'
from fix f, generate_series(f.t, f.p - 1, interval '1 day') d;
insert into public.blocked_slots(salon_id, employee_id, date, start_time, end_time, reason)
select f.salon, null, d::date, '09:00', '16:00', 'test 91: pun dan'
from fix f, generate_series(f.p, f.p + 4, interval '1 day') d;
insert into public.blocked_slots(salon_id, employee_id, date, start_time, end_time, reason)
select f.salon, f.amar, d::date, '00:00', '23:59', 'test 91: Amar odsutan'
from fix f, generate_series(f.p + 5, f.t + 30, interval '1 day') d;

-- Svaki klijent ima uredjaj sa push tokenom, i kupca u salonu A.
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_tel as select public.register_device((select salon from fix),
  'fe910000-0000-4000-8000-0000000000a1', repeat('a', 64), 'android', 'ana-tel') as id;
create temporary table ana_kupac as select (public.ensure_customer((select salon from fix))).id as id;
reset role;
select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
create temporary table bob_kupac as select (public.ensure_customer((select salon from fix))).id as id;
reset role;
select set_config('request.jwt.claims', (select cira from jwt), true);
set local role authenticated;
create temporary table cira_tel as select public.register_device((select salon from fix),
  'fe910000-0000-4000-8000-0000000000c1', repeat('c', 64), 'android', 'cira-tel') as id;
reset role;
select set_config('request.jwt.claims', (select dino from jwt), true);
set local role authenticated;
create temporary table dino_tel as select public.register_device((select salon from fix),
  'fe910000-0000-4000-8000-0000000000d1', repeat('d', 64), 'android', 'dino-tel') as id;
create temporary table dino_kupac as select (public.ensure_customer((select salon from fix))).id as id;
reset role;
grant select on ana_tel, ana_kupac, bob_kupac, cira_tel, dino_tel, dino_kupac to public;

create temporary table ident as
select
  (select id from public.auth_identities where supabase_user_id = 'fe910000-0000-4000-8000-000000000001') as ana,
  (select id from public.auth_identities where supabase_user_id = 'fe910000-0000-4000-8000-000000000002') as bob,
  (select id from public.auth_identities where supabase_user_id = 'fe910000-0000-4000-8000-000000000003') as cira,
  (select id from public.auth_identities where supabase_user_id = 'fe910000-0000-4000-8000-000000000004') as dino;
grant select on ident to public;

-- Termini koji pune P..P+4: u 16:00 kod Emira i kod Amara, mimo RPC-a (dan je blokiran do 16:00).
create temporary table puni as
select gen_random_uuid() as id, d::date as dan, e.emp
from fix f, generate_series(f.p, f.p + 4, interval '1 day') d,
  (values ('20000000-0000-4000-8000-000000000001'::uuid), ('20000000-0000-4000-8000-000000000002'::uuid)) e(emp);
grant select on puni to public;
insert into public.appointments(id, salon_id, service_id, employee_id, customer_id, customer_name,
  date, start_time, end_time, buffer_minutes, status, source)
select pt.id, f.salon, f.usluga, pt.emp, (select id from bob_kupac), 'Walk-in', pt.dan,
  '16:00', '16:30', 5, 'confirmed', 'manual'
from puni pt, fix f;

select is((select min(available_date) from public.get_available_dates((select salon from fix),
  (select usluga from fix), (select t from fix), (select t from fix) + 30)),
  (select p from fix) + 5, 'Polazno: prvi slobodan dan je P+5');
select is((select count(*)::int from public.get_available_dates((select salon from fix),
  (select usluga from fix), (select t from fix), (select t from fix) + 30, (select amar from fix))), 0,
  'Polazno: kod Amara nema slobodnog dana u prozoru');

-- ---------------------------------------------------------------------------
-- 1. Raspon racuna baza
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_bilo_ko as select * from public.join_waitlist((select usluga from fix));
create temporary table ana_emir as select * from public.join_waitlist(
  (select usluga from fix), (select emir from fix), (select p from fix) + 2);
create temporary table ana_amar as select * from public.join_waitlist(
  (select usluga from fix), (select amar from fix), (select p from fix));
create temporary table ana_ponovo as select * from public.join_waitlist(
  (select usluga from fix), null, (select p from fix) + 3);
reset role;
grant select on ana_bilo_ko, ana_emir, ana_amar, ana_ponovo to public;
-- U testu svi upisi nastaju u istoj transakciji i dijele `created_at`. Ana se upisivala redom
-- kao u aplikaciji, a redoslijed bira upis koji dobija ponudu (najraniji).
update public.waitlist_entries w set created_at = w.created_at - v.pomak
from (values ((select id from ana_bilo_ko), interval '3 minutes'),
             ((select id from ana_emir), interval '2 minutes'),
             ((select id from ana_amar), interval '1 minute')) v(id, pomak)
where w.id = v.id;

select is((select (date_from, date_to)::text from ana_bilo_ko),
  ((select t from fix), (select p from fix) + 4)::text,
  'Bez dana: raspon od danas do dana prije prvog slobodnog (P+4)');
select is((select (date_from, date_to)::text from ana_emir),
  ((select p from fix) + 2, (select p from fix) + 4)::text,
  'Od izabranog dana (P+2) do dana prije prvog slobodnog kod Emira');
select is((select (date_from, date_to)::text from ana_amar),
  ((select p from fix), (select t from fix) + 30)::text,
  'Kod Amara nema slobodnog u prozoru: raspon do kraja prozora (T+30)');
select is((select (id, date_from, date_to)::text from ana_ponovo),
  (select (id, date_from, date_to)::text from ana_bilo_ko),
  'Ponovljen upis vraca postojeci, sa istim rasponom: ni pocetak ni granica se ne pomjeraju');
select is((select count(*)::int from public.waitlist_entries where auth_identity_id = (select ana from ident)), 3,
  'Ana ima tri upisa; raspon od 20+ dana je jedan upis');

select set_config('request.jwt.claims', (select dino from jwt), true);
set local role authenticated;
create temporary table dino_emir as select * from public.join_waitlist(
  (select usluga from fix), (select emir from fix), (select p from fix) + 3);
reset role;
grant select on dino_emir to public;
select is((select (date_from, date_to)::text from dino_emir),
  ((select p from fix) + 3, (select p from fix) + 4)::text, 'Dino ceka kod Emira od P+3 do P+4');

select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
select throws_ok(format('select * from public.join_waitlist(%L, null, %L)',
  (select usluga from fix), (select p from fix) + 5), 'PT400',
  'Na ovaj dan ima slobodnog vremena. Zakažite ga umjesto liste čekanja.',
  'Prvi dan ima slobodnog vremena: upis odbijen (PT400), sa rečenicom koja kaže da se zakazuje');
select throws_ok(format('select * from public.join_waitlist(%L, null, %L)',
  (select usluga from fix), (select p from fix) + 6), 'PT400', null,
  'Raspon bez punog dana (zatvorena nedjelja pred slobodnim ponedjeljkom) odbijen (PT400)');
select throws_ok(format('select * from public.join_waitlist(%L, null, %L)',
  (select usluga from fix), (select t from fix) - 1), 'PT400', null, 'Prosli dan odbijen (PT400)');
select throws_ok(format('select * from public.join_waitlist(%L, null, %L)',
  (select usluga from fix), (select t from fix) + 31), 'PT400', null, 'Dan van prozora odbijen (PT400)');
reset role;

-- Salon koji zakazuje samo dan nema listu cekanja ni u bazi (task 68 ju je skrivao samo u app).
update public.salon_settings set booking_granularity = 'date_only' where salon_id = (select salon from fix);
select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
select throws_ok(format('select * from public.join_waitlist(%L, null, %L)',
  (select usluga from fix), (select p from fix)), 'PT400', null, '`date_only` salon: upis odbijen (PT400)');
reset role;
update public.salon_settings set booking_granularity = 'exact_slot' where salon_id = (select salon from fix);

-- ---------------------------------------------------------------------------
-- 2. Limit
-- ---------------------------------------------------------------------------
-- Paket (45 min) je pun P..P+4 kao i sisanje, pa bi bez limita prosao.
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
select throws_ok(format('select * from public.join_waitlist(%L, null, %L)',
  (select paket from fix), (select p from fix)), 'PT429', null, 'Cetvrti upis pada (PT429)');
reset role;

-- ---------------------------------------------------------------------------
-- 3. my_waitlist: raspon, bez proslih dana, bez isteklih
-- ---------------------------------------------------------------------------
-- Cira: upis koji je poceo prekjuce (prosli dani otpadaju) i upis koji je istekao juce.
create temporary table cira_upisi as
select gen_random_uuid() as id, v.oznaka, v.usluga, v.od, v.do_dana
from fix f, (values
  ('traje', '10000000-0000-4000-8000-000000000001'::uuid, (select t from fix) - 2, (select p from fix) + 4),
  ('istekao', '10000000-0000-4000-8000-000000000002'::uuid, (select t from fix) - 3, (select t from fix) - 1)
) v(oznaka, usluga, od, do_dana);
grant select on cira_upisi to public;
insert into public.waitlist_entries(id, salon_id, auth_identity_id, service_id, date_from, date_to)
select c.id, f.salon, (select cira from ident), c.usluga, c.od, c.do_dana from cira_upisi c, fix f;

select set_config('request.jwt.claims', (select cira from jwt), true);
set local role authenticated;
create temporary table cira_lista as select * from public.my_waitlist();
reset role;
select is((select count(*)::int from cira_lista), 1, 'my_waitlist ne vraca istekao upis');
select is((select (date_from, date_to)::text from cira_lista),
  ((select t from fix), (select p from fix) + 4)::text, 'Prosli dani otpadaju sa pocetka raspona');

select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_lista as select * from public.my_waitlist();
reset role;
select is((select (date_from, date_to)::text from ana_lista where id = (select id from ana_bilo_ko)),
  ((select t from fix), (select p from fix) + 4)::text, 'my_waitlist vraca raspon upisa');
select is((select employee_name from ana_lista where id = (select id from ana_emir)), 'Emir',
  'Upis nosi ime radnika');

-- ---------------------------------------------------------------------------
-- 4. Salon vidi broj po danu
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
create temporary table potraznja as select * from public.waitlist_demand(
  (select salon from fix), (select t from fix) - 1, (select p from fix) + 6);
reset role;
select ok(not exists (select 1 from potraznja where date < (select t from fix)),
  'Prosli dani se ne broje, ni istekao upis');
select is((select waiting from potraznja where date = (select t from fix)), 2,
  'Danas: Ana i Cira (upis se broji i na dan koji nije pun)');
select is((select waiting from potraznja where date = (select p from fix)), 2,
  'P: Ana sa dva upisa je jedan klijent, plus Cira');
select is((select waiting from potraznja where date = (select p from fix) + 3), 3,
  'P+3: Ana, Cira i Dino');
select is((select waiting from potraznja where date = (select p from fix) + 5), 1,
  'P+5: samo Anin upis kod Amara, koji ide do kraja prozora');

-- ---------------------------------------------------------------------------
-- 5. Otkazivanje u rasponu budi, ponuda pamti dan
-- ---------------------------------------------------------------------------
-- Cira ceka i u salonu B, na P+2, gdje ima slobodnog vremena u 10:00.
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select set_config('request.jwt.claims', (select cira from jwt), true);
set local role authenticated;
create temporary table cira_tel_b as select public.register_device((select salon_b from fix),
  'fe910000-0000-4000-8000-0000000000c2', repeat('e', 64), 'android', 'cira-tel-b') as id;
reset role;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
grant select on cira_tel_b to public;
create temporary table cira_b as select gen_random_uuid() as id;
grant select on cira_b to public;
insert into public.waitlist_entries(id, salon_id, auth_identity_id, service_id, date_from, date_to)
select (select id from cira_b), f.salon_b, (select cira from ident), f.usluga_b, f.p + 2, f.p + 2 from fix f;

-- Nepovezana otkazivanja, mimo RPC-a ubaceni termini:
--   * P+1 u 10:00 kod Amara — vrijeme pod blokadom, ne otvara nista;
--   * P+2 u 10:00 bez radnika — u A pod blokadom, u B bi otvorilo 10:00 da okidac ne gleda salon;
--   * P+5 u 10:00 kod Emira — poslije svakog raspona osim Aninog kod Amara;
--   * juce u 10:00 kod Emira — Cirin upis pokriva juce, ali prosli dan se ne nudi.
insert into public.appointments(id, salon_id, service_id, employee_id, customer_id, customer_name,
  date, start_time, end_time, buffer_minutes, status, source)
select v.id, f.salon, f.usluga, v.emp, (select id from bob_kupac), 'Walk-in', v.dan,
  '10:00', '10:30', 5, 'confirmed', 'manual'
from fix f, (values
  ('fe910000-0000-4000-8000-00000000aa01'::uuid, '20000000-0000-4000-8000-000000000002'::uuid, (select p from fix) + 1),
  ('fe910000-0000-4000-8000-00000000aa02'::uuid, null::uuid, (select p from fix) + 2),
  ('fe910000-0000-4000-8000-00000000aa03'::uuid, '20000000-0000-4000-8000-000000000001'::uuid, (select p from fix) + 5),
  ('fe910000-0000-4000-8000-00000000aa04'::uuid, '20000000-0000-4000-8000-000000000001'::uuid, (select t from fix) - 1)
) v(id, emp, dan);

select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select public.cancel_appointment((select salon from fix), 'fe910000-0000-4000-8000-00000000aa01');
select public.cancel_appointment((select salon from fix), 'fe910000-0000-4000-8000-00000000aa02');
select public.cancel_appointment((select salon from fix), 'fe910000-0000-4000-8000-00000000aa03');
reset role;
-- Prosli termin `cancel_appointment` ne otkazuje; istek (task 64) i salon bi ga ovako zatvorili.
update public.appointments set status = 'cancelled', cancelled_by = 'system'
where id = 'fe910000-0000-4000-8000-00000000aa04';

select is((select count(*)::int from public.notification_logs where type = 'waitlist_offer'), 0,
  'Nepovezano otkazivanje, otkazivanje poslije raspona, prosli dan i otkazivanje u drugom salonu ne bude nikoga');

-- Emir u 16:00 na P+2: Ana („Bilo ko" od danas i „kod Emira" od P+2) i Cira cekaju; Dino ceka
-- tek od P+3.
select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select public.cancel_appointment((select salon from fix),
  (select id from puni where dan = (select p from fix) + 2 and emp = (select emir from fix)));
reset role;

select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from ana_bilo_ko) and waitlist_offer_date = (select p from fix) + 2), 1,
  'Otkazivanje na P+2 budi Anin „Bilo ko" (raspon od danas), sa danom P+2');
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id in ((select id from ana_emir), (select id from ana_amar))), 0,
  'Jedna ponuda po klijentu: Anin upis kod Emira je ne dobija uz „Bilo ko", a kod Amara se nije oslobodilo');
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from cira_upisi where oznaka = 'traje')), 1,
  'Cira, koja ceka u istom rasponu, dobija istu ponudu');
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from dino_emir)), 0,
  'Dinov raspon pocinje P+3: otkazivanje prije raspona ga ne budi');
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from cira_b)), 0, 'Upis u salonu B se ne budi');

-- Worker je poslao ponude. Emir u 16:00 na P+3 budi i Dina.
update public.notification_logs set status = 'sent', sent_at = now() where type = 'waitlist_offer';
select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select public.cancel_appointment((select salon from fix),
  (select id from puni where dan = (select p from fix) + 3 and emp = (select emir from fix)));
reset role;
select is((select waitlist_offer_date from public.notification_logs
  where waitlist_entry_id = (select id from dino_emir)), (select p from fix) + 3,
  'Otkazivanje u Dinovom rasponu ga budi, sa danom P+3');

select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_obavijesti as select * from public.my_notifications();
reset role;
select is((select array_agg(date order by date) from ana_obavijesti where type = 'waitlist_offer'),
  array[(select p from fix) + 2, (select p from fix) + 3],
  'Ana u istoriji vidi dvije ponude, svaku sa danom koji se oslobodio');

-- Ista Ana u aplikaciji salona B ne vidi ponude iz A: `my_notifications` drzi salon iz headera.
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
select is((select count(*)::int from public.my_notifications() where type = 'waitlist_offer'), 0,
  'Ana sa headerom salona B ne vidi svoje ponude iz salona A');
reset role;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- Vlasnik salona A ne vidi redove ponuda ni u svom logu (`staff_notification_logs`), ni sad kad
-- red nosi i dan ponude.
select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select is((select count(*)::int from public.notification_logs where waitlist_entry_id is not null), 0,
  'Vlasnik salona A ne vidi redove ponuda svog salona');
reset role;

-- ---------------------------------------------------------------------------
-- 6. Gasenje
-- ---------------------------------------------------------------------------
-- Dino zakaze prvi slobodan termin (P+5, granica). Upis ostaje: ceka da se oslobodi ranije.
insert into public.appointments(salon_id, service_id, employee_id, customer_id, auth_identity_id,
  customer_name, date, start_time, end_time, buffer_minutes, status, source)
select f.salon, f.usluga, f.emir, (select id from dino_kupac), (select dino from ident),
  'Dino', f.p + 5, '11:00', '11:30', 5, 'confirmed', 'manual'
from fix f;
select ok(exists (select 1 from public.waitlist_entries where id = (select id from dino_emir)),
  'Potvrden termin na granicni dan (prvi slobodan) ne gasi upis');

-- Ana zakaze P+2 u 16:00 (rucni rezim: zahtjev), pa ga salon potvrdi.
select set_config('request.jwt.claims', (select ana from jwt), true);
set local role authenticated;
create temporary table ana_termin as select (public.book_appointment((select salon from fix),
  (select id from ana_kupac), (select usluga from fix), (select p from fix) + 2, '16:00',
  (select emir from fix), null, (select id from ana_tel))).id as id;
reset role;
grant select on ana_termin to public;
select is((select count(*)::int from public.waitlist_entries where auth_identity_id = (select ana from ident)), 3,
  'Zahtjev na cekanju (pending) ne gasi upis');

select set_config('request.jwt.claims', (select vlasnik from jwt), true);
set local role authenticated;
select public.set_appointment_status((select salon from fix), (select id from ana_termin), 'confirmed', null);
reset role;
select is((select count(*)::int from public.waitlist_entries where auth_identity_id = (select ana from ident)), 0,
  'Potvrden termin na P+2 gasi sva tri Anina upisa te usluge kojima je P+2 u rasponu (i kad im ne pocinje tog dana)');
select is((select count(*)::int from public.notification_logs where waitlist_entry_id = (select id from ana_bilo_ko)), 0,
  'Ponude ugasenog upisa nestaju sa njim');

-- Dino dobije potvrden termin na P+3 (oslobodjen kod Emira): u rasponu je, upis nestaje.
insert into public.appointments(salon_id, service_id, employee_id, customer_id, auth_identity_id,
  customer_name, date, start_time, end_time, buffer_minutes, status, source)
select f.salon, f.usluga, f.emir, (select id from dino_kupac), (select dino from ident),
  'Dino', f.p + 3, '16:00', '16:30', 5, 'confirmed', 'manual'
from fix f;
select ok(not exists (select 1 from public.waitlist_entries where id = (select id from dino_emir)),
  'Potvrden termin u rasponu gasi upis');

-- ---------------------------------------------------------------------------
-- 7. Istek
-- ---------------------------------------------------------------------------
-- Istekao upis drzi kljuc dok ga cron ne obrise; novi upis za isti kljuc ga ne smije cekati.
insert into public.waitlist_entries(id, salon_id, auth_identity_id, service_id, employee_id, date_from, date_to)
select 'fe910000-0000-4000-8000-00000000bb01', f.salon, (select bob from ident), f.usluga, f.emir, f.t - 3, f.t - 1
from fix f;
-- Bob ima istekao upis i u salonu B: `join_waitlist` u A brise samo njegove istekle upise u A.
insert into public.waitlist_entries(id, salon_id, auth_identity_id, service_id, date_from, date_to)
select 'fe910000-0000-4000-8000-00000000bb02', f.salon_b, (select bob from ident), f.usluga_b, f.t - 3, f.t - 1
from fix f;
select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
create temporary table bob_emir as select * from public.join_waitlist(
  (select usluga from fix), (select emir from fix), (select p from fix));
reset role;
grant select on bob_emir to public;
select ok((select id <> 'fe910000-0000-4000-8000-00000000bb01' and date_from = (select p from fix)
  and date_to = (select p from fix) + 4 from bob_emir),
  'Istekao upis istog kljuca ne blokira novi: novi red, novi raspon');
select ok(exists (select 1 from public.waitlist_entries where id = (select id from cira_upisi where oznaka = 'istekao')),
  'join_waitlist ne brise tudji istekao upis');
select ok(exists (select 1 from public.waitlist_entries where id = 'fe910000-0000-4000-8000-00000000bb02'),
  'join_waitlist u salonu A ne brise isteklog upisa istog klijenta u salonu B');

-- Cirin istekao upis ima i staru ponudu; prolaz ih brise oba, a upis koji traje ostaje.
insert into public.notification_logs(salon_id, waitlist_entry_id, device_id, type, waitlist_offer_date, status)
select f.salon, (select id from cira_upisi where oznaka = 'istekao'), (select id from cira_tel),
  'waitlist_offer', f.t - 2, 'sent'
from fix f;
select ok(private.expire_waitlist() >= 1, 'expire_waitlist javlja koliko je obrisao');
select ok(not exists (select 1 from public.waitlist_entries where id = (select id from cira_upisi where oznaka = 'istekao')),
  'Istekao upis nestaje');
select is((select count(*)::int from public.notification_logs
  where waitlist_entry_id = (select id from cira_upisi where oznaka = 'istekao')), 0,
  'Sa isteklim upisom nestaje i njegova ponuda');
select ok(exists (select 1 from public.waitlist_entries where id = (select id from cira_upisi where oznaka = 'traje')),
  'Upis koji je poceo u proslosti, a traje, ostaje');
select ok(exists (select 1 from cron.job where jobname = 'expire-waitlist' and command like '%private.expire_waitlist()%'),
  'Cron `expire-waitlist` postoji');

-- ---------------------------------------------------------------------------
-- 8. Tenant izolacija
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', (select dino from jwt), true);
set local role authenticated;
select is((select count(*)::int from public.my_waitlist()), 0, 'Dino ne vidi tudje upise (svoj je ugasen)');
reset role;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
select is((select count(*)::int from public.my_waitlist()), 0, 'Bob u salonu B ne vidi svoj upis iz A');
reset role;
select set_config('request.jwt.claims', (select cira from jwt), true);
set local role authenticated;
select is((select array_agg(id) from public.my_waitlist()), array[(select id from cira_b)],
  'Cira u salonu B vidi samo upis iz B');
reset role;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(format('select * from public.join_waitlist(%L)', (select usluga from fix)), '42501', null,
  'Anon ne upisuje: 42501');
reset role;
select set_config('request.jwt.claims', (select radnik from jwt), true);
set local role authenticated;
select throws_ok(format('select * from public.join_waitlist(%L)', (select usluga from fix)), '42501', null,
  'Radnik ne upisuje: 42501');
select throws_ok(format('select * from public.waitlist_demand(%L, %L, %L)',
  (select salon from fix), (select p from fix), (select p from fix) + 6), '42501', null,
  'Radnik ne vidi potraznju: 42501');
reset role;
select set_config('request.jwt.claims', (select vlasnik_b from jwt), true);
set local role authenticated;
select throws_ok(format('select * from public.waitlist_demand(%L, %L, %L)',
  (select salon from fix), (select p from fix), (select p from fix) + 6), '42501', null,
  'Vlasnik salona B ne vidi potraznju salona A: 42501');
select throws_ok(format('select * from public.join_waitlist(%L)', (select usluga from fix)), '42501', null,
  'Vlasnik salona B ne upisuje: 42501');
reset role;
select set_config('request.jwt.claims', (select bob from jwt), true);
set local role authenticated;
select throws_ok('select * from public.waitlist_entries', '42501', null, 'Klijent ne cita tabelu direktno');
reset role;

-- ---------------------------------------------------------------------------
-- 9. Sema i grantovi
-- ---------------------------------------------------------------------------
-- `drop` + `create` vraca default privilegije (EXECUTE za anon); granica je `revoke`. Test koji
-- samo zove funkciju kao anon ne razlikuje grant od tijela, pa se grant provjerava direktno.
select ok(not has_function_privilege('anon', 'public.join_waitlist(uuid, uuid, date)', 'execute'),
  'anon nema EXECUTE na join_waitlist');
select ok(has_function_privilege('authenticated', 'public.join_waitlist(uuid, uuid, date)', 'execute'),
  'authenticated ima EXECUTE na join_waitlist');
select ok(not has_function_privilege('anon', 'public.my_waitlist()', 'execute'),
  'anon nema EXECUTE na my_waitlist');
select ok(has_function_privilege('authenticated', 'public.my_waitlist()', 'execute'),
  'authenticated ima EXECUTE na my_waitlist');
select ok(not has_function_privilege('authenticated', 'private.expire_waitlist()', 'execute')
  and not has_function_privilege('anon', 'private.expire_waitlist()', 'execute'),
  'expire_waitlist brise preko svih salona: nema EXECUTE za authenticated ni anon');
select hasnt_column('public', 'waitlist_entries', 'date', 'Upis vise nema jedan dan');
select col_not_null('public', 'waitlist_entries', 'date_from', 'date_from je obavezan');
select col_not_null('public', 'waitlist_entries', 'date_to', 'date_to je obavezan');
select throws_ok(format(
  'insert into public.waitlist_entries(salon_id, auth_identity_id, service_id, date_from, date_to) values (%L, %L, %L, %L, %L)',
  (select salon from fix), (select dino from ident), (select usluga from fix), (select p from fix) + 1, (select p from fix)),
  '23514', null, 'Raspon ne smije zavrsiti prije pocetka');
select throws_ok(format(
  'insert into public.notification_logs(salon_id, waitlist_entry_id, device_id, type) values (%L, %L, %L, %L)',
  (select salon from fix), (select id from cira_upisi where oznaka = 'traje'), (select id from cira_tel), 'waitlist_offer'),
  '23514', null, 'Ponuda bez dana ne prolazi');

select * from finish();
rollback;
