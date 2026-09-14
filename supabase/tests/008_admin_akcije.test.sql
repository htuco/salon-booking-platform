-- Admin akcije nad terminima + rucni unos. Task 24.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table afix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as drugi_salon,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  'ee000000-0000-4000-8000-000000000001'::uuid as klijent,
  'ee000000-0000-4000-8000-000000000003'::uuid as admin,
  'ee000000-0000-4000-8000-000000000004'::uuid as tudji_admin,
  -- Datum je izveden, ne fiksan: `max_advance_booking_days` je 30, pa bi fiksan datum
  -- jednog dana ispao izvan raspona i test bi pao iz pogresnog razloga.
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak,
  -- Nedjelja je u seedu zatvorena (`is_closed` za `day_of_week = 7`) — nosi negativan
  -- test koji task trazi.
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '13 days')::date as nedjelja;
grant select on afix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('ee000000-0000-4000-8000-000000000001', 'klijent@akcije.invalid', '{"providers":["email"]}', '{}'),
('ee000000-0000-4000-8000-000000000003', 'admin@akcije.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('ee000000-0000-4000-8000-000000000004', 'tudji@akcije.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('ee000000-0000-4000-8000-000000000003', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik A', 'admin@akcije.invalid', 'salon_admin'),
('ee000000-0000-4000-8000-000000000004', '550e8400-e29b-41d4-a716-446655440001',
 'Vlasnik B', 'tudji@akcije.invalid', 'salon_admin');

-- Klijentski termin, da akcije imaju nad cim raditi.
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table moj as
select (public.ensure_customer((select salon from afix))).id as customer_id;
reset role;
grant select on moj to public;

set local role authenticated;
create temporary table a1 as
select (public.book_appointment(
  (select salon from afix), (select customer_id from moj), (select usluga from afix),
  (select utorak from afix), '10:00', (select emir from afix))).id as id;
reset role;
grant select on a1 to public;

select is(
  (select status::text from public.appointments where id = (select id from a1)),
  'pending', 'Klijentski termin nastaje kao pending');

-- ---------------------------------------------------------------------------
-- 1. Grant je oduzet — ovo je ono sto rupu stvarno zatvara
-- ---------------------------------------------------------------------------
-- Dok `insert`/`update` grant stoji, sve validirane funkcije su konvencija a ne zastita:
-- admin ih zaobidje jednim PostgREST pozivom.
select is_empty($$
  select privilege_type from information_schema.role_table_grants
  where grantee = 'authenticated' and table_name = 'appointments'
    and privilege_type in ('INSERT', 'UPDATE')
$$, 'authenticated nema insert ni update grant na appointments');

select bag_eq($$
  select privilege_type::text from information_schema.role_table_grants
  where grantee = 'authenticated' and table_name = 'appointments'
$$, $$ values ('SELECT'), ('DELETE') $$,
  'Ostaju samo select i delete — greskom unesen termin se mora moci obrisati');

-- Admin pokusava direktan upis, kako bi ga zaobilazak izgledao.
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok(
  format($$update public.appointments set status = 'confirmed' where id = %L$$, (select id from a1)),
  '42501', NULL,
  'Direktan update baca i adminu — grant je oduzet, ne samo politika');

select throws_ok(
  format($$insert into public.appointments
    (salon_id, service_id, employee_id, customer_id, customer_name, date, start_time, end_time)
    values (%L, %L, %L, %L, 'Zaobilazak', %L, '03:00', '03:40')$$,
    (select salon from afix), (select usluga from afix), (select emir from afix),
    (select customer_id from moj), (select nedjelja from afix)),
  '42501', NULL,
  'Direktan insert u nedjelju u 3 ujutro baca — put upisa vise ne postoji');
reset role;

-- ---------------------------------------------------------------------------
-- 2. Odbijanja idu prije srecnog puta
-- ---------------------------------------------------------------------------
-- Kad bi isle poslije, termin bi vec bio u ciljnom statusu i svaka od njih bi "prosla"
-- iz pogresnog razloga — idempotencija bi vratila red bez greske.
set local role authenticated;
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
select throws_ok(
  format($$select public.set_appointment_status(%L, %L, 'confirmed')$$,
    (select salon from afix), (select id from a1)),
  '42501', 'Nije dozvoljeno',
  'Klijent ne moze potvrditi svoj termin — potvrda je odluka salona');

-- Admin **drugog** salona. Claim je stvaran i red u `public.users` postoji; jedino sto ne
-- valja je salon. Ovo je asercija koja pada ako `is_admin` prestane porediti salon.
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
select throws_ok(
  format($$select public.set_appointment_status(%L, %L, 'confirmed')$$,
    (select salon from afix), (select id from a1)),
  '42501', 'Nije dozvoljeno',
  'Admin salona B ne dira termin salona A');

set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
select throws_ok(
  format($$select public.set_appointment_status(%L, '00000000-0000-4000-8000-0000000000ff', 'confirmed')$$,
    (select salon from afix)),
  '42501', 'Nije dozvoljeno',
  'Nepostojeci termin vraca istu gresku kao tudji — nema nabrajanja');

select throws_ok(
  format($$select public.set_appointment_status(%L, %L, 'cancelled')$$,
    (select salon from afix), (select id from a1)),
  'PT400', 'Otkazivanje ide kroz cancel_appointment',
  'Otkazivanje ima svoju funkciju — rok i cancelled_by zive tamo');

select throws_ok(
  format($$select public.set_appointment_status(%L, %L, 'pending')$$,
    (select salon from afix), (select id from a1)),
  'PT400', 'Nepodrzan status',
  'Vracanje u pending nije akcija — salon je vec odgovorio');
reset role;

-- ---------------------------------------------------------------------------
-- 3. Cetiri akcije
-- ---------------------------------------------------------------------------
set local role authenticated;

-- potvrdi
select is(
  (public.set_appointment_status((select salon from afix), (select id from a1), 'confirmed')).status::text,
  'confirmed', 'Potvrdi: pending -> confirmed');

select is(
  (select pending_expires_at from public.appointments where id = (select id from a1)),
  NULL, 'Potvrda skida rok isteka — scheduler ga vise ne gleda');

-- idempotencija
select is(
  (public.set_appointment_status((select salon from afix), (select id from a1), 'confirmed')).status::text,
  'confirmed', 'Dva tapa na potvrdi nisu greska — idempotentno');

-- odbij (= otkazivanje od strane salona, kroz cancel_appointment)
reset role;
set local role authenticated;
create temporary table a2 as
select (public.book_appointment(
  (select salon from afix), (select customer_id from moj), (select usluga from afix),
  (select utorak from afix), '11:00', (select emir from afix))).id as id
from (select set_config('request.jwt.claims',
  '{"sub":"ee000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}', true)) s;
reset role;
grant select on a2 to public;

set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select is(
  (public.cancel_appointment((select salon from afix), (select id from a2), 'Radnik na bolovanju')).status::text,
  'cancelled', 'Odbij: termin je otkazan');

reset role;
select is(
  (select cancelled_by::text from public.appointments where id = (select id from a2)),
  'salon', 'cancelled_by je salon, ne customer — odluku je donio salon');
select is(
  (select cancel_reason from public.appointments where id = (select id from a2)),
  'Radnik na bolovanju', 'cancel_reason je zapisan');

set local role authenticated;
select throws_ok(
  format($$select public.set_appointment_status(%L, %L, 'confirmed')$$,
    (select salon from afix), (select id from a2)),
  'PT409', 'Otkazan termin se ne moze mijenjati',
  'Otkazan termin se ne vraca u zivot — slot je mogao biti prodat');
reset role;

-- no-show i completed, sa brojacima
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table a3 as
select (public.book_appointment(
  (select salon from afix), (select customer_id from moj), (select usluga from afix),
  (select utorak from afix), '12:00', (select emir from afix))).id as id;
reset role;
grant select on a3 to public;

create temporary table prije as
select no_show_count as ns, visit_count as vc
from public.customers where id = (select customer_id from moj);
grant select on prije to public;

set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select is(
  (public.set_appointment_status((select salon from afix), (select id from a3), 'no_show', 'Nije se pojavio')).status::text,
  'no_show', 'No-show: termin je oznacen');
reset role;

-- **Brojac dobija pisca sada, citaoca u Sprintu 3.** Prag ("tri nedolaska u sest mjeseci")
-- namjerno nije provodjen — on je pravilo vertikale i trazi vlastitu odluku. Ali da se ne
-- pise sada, statistika bi u Sprintu 3 krenula od nule i nedolasci iz ovog perioda bi bili
-- nepovratno izgubljeni.
select is(
  (select no_show_count from public.customers where id = (select customer_id from moj)),
  (select ns from prije) + 1,
  'no_show dize customers.no_show_count');

select is(
  (select cancelled_by::text from public.appointments where id = (select id from a3)),
  'salon', 'no_show biljezi salon kao onoga ko je odlucio');
select is(
  (select cancel_reason from public.appointments where id = (select id from a3)),
  'Nije se pojavio',
  'cancel_reason nosi obrazlozenje i za no-show, ne samo za otkazivanje');

set local role authenticated;
create temporary table a4 as
select (public.book_appointment(
  (select salon from afix), (select customer_id from moj), (select usluga from afix),
  (select utorak from afix), '13:00', (select emir from afix))).id as id
from (select set_config('request.jwt.claims',
  '{"sub":"ee000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}', true)) s;
reset role;
grant select on a4 to public;

set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select is(
  (public.set_appointment_status((select salon from afix), (select id from a4), 'completed')).status::text,
  'completed', 'Odrzan: termin je zavrsen');
reset role;
select is(
  (select visit_count from public.customers where id = (select customer_id from moj)),
  (select vc from prije) + 1,
  'completed dize customers.visit_count');

-- ---------------------------------------------------------------------------
-- 4. Rucni unos — telefonski klijent
-- ---------------------------------------------------------------------------
set local role authenticated;
select throws_ok(
  format($$select public.upsert_walkin_customer(%L, 'Bez imena forsirano', NULL)$$,
    (select drugi_salon from afix)),
  '42501', 'Nije dozvoljeno',
  'Admin salona A ne pravi klijenta u salonu B');

select throws_ok(
  format($$select public.upsert_walkin_customer(%L, '   ')$$, (select salon from afix)),
  'PT400', 'Ime je obavezno',
  'Prazno ime (i sam razmak) je odbijeno');

create temporary table walkin as
select (public.upsert_walkin_customer(
  (select salon from afix), 'Telefonski Mujo', '061 000 111', 'Zvao u 9h')).id as id;
reset role;
grant select on walkin to public;

-- **`auth_identity_id` ostaje `null` i to je sustina, ne propust.** Covjek koji je nazvao
-- telefonom nema nalog; red koji bi ga vezao za tudji identitet bio bi laz.
select is(
  (select auth_identity_id from public.customers where id = (select id from walkin)),
  NULL, 'Telefonski klijent nema auth_identity_id');

select is(
  (select salon_id from public.customers where id = (select id from walkin)),
  (select salon from afix), 'Telefonski klijent pripada salonu iz argumenta');

-- Drugi poziv sa istim brojem ne pravi duplikat.
set local role authenticated;
select is(
  (public.upsert_walkin_customer((select salon from afix), 'Mujo Mujic', '061 000 111')).id,
  (select id from walkin),
  'Isti broj telefona pogadja postojeci red umjesto da pravi duplikat');
reset role;
select is(
  (select name from public.customers where id = (select id from walkin)),
  'Mujo Mujic',
  'Ime se azurira — ispravku pise sam salon, za razliku od ensure_customer');

-- ---------------------------------------------------------------------------
-- 5. Rucni termin prolazi **istu** validaciju slota kao klijentski
-- ---------------------------------------------------------------------------
-- Ovo je asercija zbog koje task postoji. `security.md` je rupu vodio ovako: "admin moze
-- upisati termin u nedjelju u 3 ujutro, i baza ga nece zaustaviti".
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;

select throws_ok(
  format($$select public.book_appointment(%L, %L, %L, %L, '03:00', %L)$$,
    (select salon from afix), (select id from walkin), (select usluga from afix),
    (select nedjelja from afix), (select emir from afix)),
  'PT409', 'Termin je upravo zauzet',
  'Rucni termin u nedjelju u 3 ujutro je odbijen — nedjelja je zatvorena');

select throws_ok(
  format($$select public.book_appointment(%L, %L, %L, %L, '03:00', %L)$$,
    (select salon from afix), (select id from walkin), (select usluga from afix),
    (select utorak from afix), (select emir from afix)),
  'PT409', 'Termin je upravo zauzet',
  'Rucni termin u 3 ujutro radnim danom je odbijen — van radnog vremena');

-- Vec zauzet slot: `a1` stoji u 10:00 i potvrdjen je.
select throws_ok(
  format($$select public.book_appointment(%L, %L, %L, %L, '10:00', %L)$$,
    (select salon from afix), (select id from walkin), (select usluga from afix),
    (select utorak from afix), (select emir from afix)),
  'PT409', 'Termin je upravo zauzet',
  'Rucni termin preko zauzetog slota je odbijen');

-- ---------------------------------------------------------------------------
-- 6. Admin izuzetak vazi **samo** za min_advance_booking_hours
-- ---------------------------------------------------------------------------
-- Salon upisuje klijenta koji stoji na vratima. Prag je pravilo prema klijentu
-- ("ne rezervisi mi pet minuta prije"), ne fizicko ogranicenje salona — isti oblik kao
-- `min_cancel_hours`, koji takodje vazi za klijenta a ne za salon.
--
-- **Mjeri se razlika izmedju dva poziva nad istim danom, ne postojanje konkretnog sata.**
-- Prvi pokusaj ovog testa je trazio slot "za pola sata" i pao je u 18:13, jer salon radi do
-- 17:00 — pao bi popodne a prolazio ujutro, i to bez veze sa pragom koji testira. Isti rod
-- greske koji je task 17 nasao kod tri zatecena testa (zeleni samo u dijelu dana ili sedmice).
reset role;
create temporary table danas as
select (now() at time zone 'Europe/Sarajevo')::date as dan;
grant select on danas to public;

-- Dana kad je salon zatvoren ili je radno vrijeme proslo, obje liste su prazne i razlika
-- ne postoji — tada ovaj par asercija ne bi dokazivao nista. Zato se broji **koliko** je
-- slotova odsjeceno pragom, i tvrdi se odnos koji vazi u oba slucaja.
create temporary table praguj as
select
  (select count(*) from public.get_available_slots(
     (select salon from afix), (select usluga from afix), (select dan from danas),
     (select emir from afix), true)) as sa_izuzetkom,
  (select count(*) from public.get_available_slots(
     (select salon from afix), (select usluga from afix), (select dan from danas),
     (select emir from afix), false)) as bez_izuzetka;
grant select on praguj to public;

select ok(
  (select sa_izuzetkom >= bez_izuzetka from praguj),
  'Izuzetak nikad ne smanjuje listu slobodnih slotova');

-- Sutra u podne je uvijek dalje od 2 h, pa prag nista ne odsijeca i liste **moraju** biti
-- jednake. Ovo hvata suprotnu gresku: izuzetak koji otvara nesto sto nije prag.
create temporary table sutra as
select ((now() at time zone 'Europe/Sarajevo') + interval '1 day')::date as dan;
grant select on sutra to public;

select is(
  (select count(*) from public.get_available_slots(
     (select salon from afix), (select usluga from afix), (select dan from sutra),
     (select emir from afix), true)),
  (select count(*) from public.get_available_slots(
     (select salon from afix), (select usluga from afix), (select dan from sutra),
     (select emir from afix), false)),
  'Za sutra su liste identicne — prag tamo nista ne odsijeca, pa izuzetak nema sta otvoriti');

-- **Direktan dokaz da prag stvarno stoji za klijenta.** Slot koji pocinje za manje od 2 h
-- se konstruise nad danom u kojem salon radi, pa se trazi u obje liste. Kad takvog slota
-- danas nema (popodne, zatvoreno), asercija se preskace kroz `skip` umjesto da laze.
create temporary table blizu as
select s.start_time
from public.get_available_slots(
  (select salon from afix), (select usluga from afix), (select dan from danas),
  (select emir from afix), true) s
where ((select dan from danas) + s.start_time) at time zone 'Europe/Sarajevo'
      < now() + interval '2 hours'
order by s.start_time
limit 1;
grant select on blizu to public;

select case when (select count(*) from blizu) = 0
  then skip('Danas nema slota blizeg od 2 h — salon je zatvoren ili je radno vrijeme proslo', 1)
  else is_empty(
    format($$select 1 from public.get_available_slots(%L, %L, %L, %L, false)
             where start_time = %L$$,
      (select salon from afix), (select usluga from afix), (select dan from danas),
      (select emir from afix), (select start_time from blizu)),
    'Slot blizi od 2 h vidi admin, a klijent ne — prag vazi samo za klijenta')
  end;

-- **Izuzetak ne otvara nista drugo.** Nedjelja ostaje zatvorena i sa `true`.
select is_empty(
  format($$select 1 from public.get_available_slots(%L, %L, %L, %L, true)$$,
    (select salon from afix), (select usluga from afix),
    (select nedjelja from afix), (select emir from afix)),
  'Izuzetak ne otvara zatvoren dan — radno vrijeme i dalje vazi');

-- ---------------------------------------------------------------------------
-- 7. Rucni termin je odmah confirmed i nosi source = manual
-- ---------------------------------------------------------------------------
set local role authenticated;
create temporary table a5 as
select (public.book_appointment(
  (select salon from afix), (select id from walkin), (select usluga from afix),
  (select utorak from afix), '15:00', (select emir from afix), 'Telefonom')).id as id;
reset role;
grant select on a5 to public;

select is(
  (select status::text from public.appointments where id = (select id from a5)),
  'confirmed',
  'Rucni termin je odmah confirmed — salon ne ceka potvrdu od sebe');

select is(
  (select source::text from public.appointments where id = (select id from a5)),
  'manual', 'Rucni termin nosi source = manual');

select is(
  (select pending_expires_at from public.appointments where id = (select id from a5)),
  NULL, 'Rucni termin nema rok isteka — nema sta cekati');

select is(
  (select customer_name from public.appointments where id = (select id from a5)),
  'Mujo Mujic', 'Ime telefonskog klijenta je preslikano na termin');

select is(
  (select auth_identity_id from public.appointments where id = (select id from a5)),
  NULL, 'Rucni termin nema auth_identity_id — klijent nema nalog');

-- ---------------------------------------------------------------------------
-- 8. anon nema nista
-- ---------------------------------------------------------------------------
set local role anon;
select throws_ok(
  format($$select public.set_appointment_status(%L, %L, 'confirmed')$$,
    (select salon from afix), (select id from a1)),
  '42501', NULL, 'anon nema execute grant na set_appointment_status');
select throws_ok(
  format($$select public.upsert_walkin_customer(%L, 'Niko')$$, (select salon from afix)),
  '42501', NULL, 'anon nema execute grant na upsert_walkin_customer');
reset role;

select * from finish();
rollback;
