-- Admin CRUD nad uslugama i historijski snapshot termina. Task 32.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table sfix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as drugi_salon,
  '20000000-0000-4000-8000-000000000001'::uuid as radnik,
  'ee000000-0000-4000-8000-000000000032'::uuid as admin,
  'ee000000-0000-4000-8000-000000000033'::uuid as tudji_admin,
  'ee000000-0000-4000-8000-000000000034'::uuid as customer,
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak,
  -- Srijeda sljedece sedmice: drugi termin ne smije dijeliti dan sa prvim, v. odjeljak 3.
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '9 days')::date as srijeda;
grant select on sfix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('ee000000-0000-4000-8000-000000000032', 'admin-usluge-a@invalid.test',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('ee000000-0000-4000-8000-000000000033', 'admin-usluge-b@invalid.test',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
((select admin from sfix), (select salon from sfix), 'Admin A', 'admin-usluge-a@invalid.test', 'salon_admin'),
((select tudji_admin from sfix), (select drugi_salon from sfix), 'Admin B', 'admin-usluge-b@invalid.test', 'salon_admin');
insert into public.customers(id, salon_id, name)
values ((select customer from sfix), (select salon from sfix), 'Test klijent');

-- ---------------------------------------------------------------------------
-- 1. Grant je granica: tabela se cita, ali se ne pise direktno
-- ---------------------------------------------------------------------------
select bag_eq($$
  select privilege_type::text from information_schema.role_table_grants
  where grantee = 'authenticated' and table_name = 'services'
$$, $$ values ('SELECT') $$,
  'authenticated nad services ima samo SELECT; svi upisi idu kroz RPC');

set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000032","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok(
  $$insert into public.services(salon_id,name,price,duration_minutes)
    values ('550e8400-e29b-41d4-a716-446655440000','Zaobilazak',1,10)$$,
  '42501', null, 'Admin ne moze zaobici create_service direktnim insertom');
select throws_ok(
  $$update public.services set price=1
    where id='10000000-0000-4000-8000-000000000001'$$,
  '42501', null, 'Admin ne moze zaobici update_service direktnim updateom');
select throws_ok(
  $$delete from public.services
    where id='10000000-0000-4000-8000-000000000004'$$,
  '42501', null, 'Fizicko brisanje nije aplikacijska operacija');

create temporary table nova as
select (public.create_service(
  (select salon from sfix), '  Test usluga  ', 'Opis', 'Test', 12.50, 30, null
)).*;
reset role;
grant select on nova to public;

select is((select name from nova), 'Test usluga', 'Create normalizuje naziv');
select is((select price from nova), 12.50::numeric, 'Cijena ostaje numeric, ne float');

-- Link je potreban da availability moze ponuditi radnika za novu uslugu.
insert into public.employee_services(salon_id, employee_id, service_id)
select salon, radnik, id from sfix cross join nova;

-- ---------------------------------------------------------------------------
-- 2. Tenant granica: aktivno je javni katalog, neaktivno i mutacije nisu
-- ---------------------------------------------------------------------------
-- Aktivna usluga je namjerno citljiva i anon-u (`public_active`); tvrdnja da admin B ne
-- moze procitati aktivni red bila bi suprotna javnom katalogu. Granica je neaktivni red.
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000033","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select throws_ok(
  format($$select public.update_service(%L,%L,'Tudje','', '',10,30,null)$$,
    (select salon from sfix), (select id from nova)),
  '42501', 'Nije dozvoljeno', 'Admin B ne mijenja uslugu salona A ni sa poznatim ID-em');
select throws_ok(
  format($$select public.set_service_active(%L,%L,false)$$,
    (select salon from sfix), (select id from nova)),
  '42501', 'Nije dozvoljeno', 'Admin B ne deaktivira uslugu salona A');
reset role;

set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000034","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select throws_ok(
  format($$select public.create_service(%L,'Klijent pise','','',10,30,null)$$,
    (select salon from sfix)),
  '42501', 'Nije dozvoljeno', 'Klijent ne kreira uslugu');
reset role;

-- ---------------------------------------------------------------------------
-- 3. Postojeci termin cuva staru cijenu/trajanje, novi uzima novo
-- ---------------------------------------------------------------------------
-- **Dijagnostika ide prije bookinga, ne poslije.** Prvi prolaz na CI-ju je pao ovdje, na
-- `Termin je upravo zauzet`, a tvrdnja koja bi rekla zasto je stajala iza `book_appointment`
-- i nikad se nije izvrsila. Prazan spisak slotova stigne u RPC kao NULL `p_start_time` i
-- javi se istom porukom kao stvarno zauzet termin — dvije razlicite stvari, jedan tekst.
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000032","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table prvi_slot as
select start_time
from public.get_available_slots(
  (select salon from sfix), (select id from nova), (select utorak from sfix),
  (select radnik from sfix), true)
order by start_time limit 1;
reset role;
grant select on prvi_slot to public;

select diag('utorak = ' || (select utorak from sfix)
  || ', slotova = ' || (select count(*) from prvi_slot)
  || ', prvi = ' || coalesce((select start_time from prvi_slot)::text, 'NULL'));
select isnt_empty('select start_time from prvi_slot',
  'Nova usluga od 30 minuta ima bar jedan slobodan slot u utorak');

set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000032","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table prvi as
select (public.book_appointment(
  (select salon from sfix), (select customer from sfix), (select id from nova),
  (select utorak from sfix), (select start_time from prvi_slot), (select radnik from sfix)
)).*;
reset role;
grant select on prvi to public;

select is((select service_price from prvi), 12.50::numeric,
  'Prvi termin snapshotuje cijenu iz trenutka rezervacije');
select is((select service_duration_minutes from prvi), 30,
  'Prvi termin snapshotuje trajanje iz trenutka rezervacije');

set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000032","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select is(
  (public.update_service((select salon from sfix), (select id from nova),
    'Nova cijena', 'Opis 2', 'Test', 20.00, 60, null)).duration_minutes,
  60, 'Izmjena vraca novu vrijednost');
reset role;

select is((select service_price from public.appointments where id=(select id from prvi)),
  12.50::numeric, 'Promjena cjenovnika ne prepisuje cijenu postojeceg termina');
select is((select service_duration_minutes from public.appointments where id=(select id from prvi)),
  30, 'Promjena cjenovnika ne prepisuje trajanje postojeceg termina');
select is(
  (select extract(epoch from (end_time-start_time))::integer/60
   from public.appointments where id=(select id from prvi)),
  30, 'Promjena trajanja ne pomjera vec dogovoreni kraj termina');

-- **Drugi termin ide u srijedu, ne u isti utorak.** Prvi termin je zauzeo prvi slot dana
-- i sa bufferom drzi okolinu; kad usluga naraste sa 30 na 60 minuta, "prvi slobodan slot
-- istog dana" postaje pitanje rasporeda, a ne onoga sto ovaj blok dokazuje. Test je zbog
-- toga pao na CI-ju u prvom prolazu (`Termin je upravo zauzet`). Ono sto se ovdje tvrdi je
-- da **novi** termin uzima **novu** cijenu i trajanje, i to ne trazi isti dan.
-- Srijeda je radna: seed daje 09:00-17:00 za sve dane osim nedjelje.
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000032","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table drugi_slot as
select start_time
from public.get_available_slots(
  (select salon from sfix), (select id from nova), (select srijeda from sfix),
  (select radnik from sfix), true)
order by start_time limit 1;
reset role;
grant select on drugi_slot to public;

-- Bez ove tvrdnje prazan spisak slotova stize do `book_appointment` kao NULL i javi se kao
-- "Termin je upravo zauzet" — poruka koja gleda u pogresnu stranu.
select isnt_empty('select start_time from drugi_slot',
  'Za izmijenjenu uslugu od 60 minuta postoji bar jedan slobodan slot');

set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000032","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table drugi as
select (public.book_appointment(
  (select salon from sfix), (select customer from sfix), (select id from nova),
  (select srijeda from sfix), (select start_time from drugi_slot), (select radnik from sfix)
)).*;
reset role;
grant select on drugi to public;

select is((select service_price from drugi), 20.00::numeric,
  'Novi termin uzima novu cijenu');
select is((select service_duration_minutes from drugi), 60,
  'Novi termin i availability uzimaju novo trajanje');
select is((select extract(epoch from (end_time-start_time))::integer/60 from drugi), 60,
  'Novi termin zauzima 60 minuta po izmijenjenom cjenovniku');

-- ---------------------------------------------------------------------------
-- 4. Deaktivacija je delete semantika bez gubitka historije
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000032","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select is(
  (public.set_service_active((select salon from sfix), (select id from nova), false)).is_active,
  false, 'Usluga se deaktivira umjesto brisanja');
reset role;

select is((select count(*)::integer from public.appointments where service_id=(select id from nova)),
  2, 'Deaktivacija cuva postojece termine');
select is((select count(*)::integer from public.employee_services where service_id=(select id from nova)),
  1, 'Deaktivacija cuva veze radnik-usluga za mogucu ponovnu aktivaciju');

set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000033","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select is_empty(
  format($$select id from public.services where id=%L$$, (select id from nova)),
  'Admin B ne vidi neaktivnu uslugu salona A');
reset role;

select * from finish();
rollback;
