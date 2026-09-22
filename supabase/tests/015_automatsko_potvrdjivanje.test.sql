-- Automatsko potvrdjivanje termina. Task 37.
--
-- Postavka `salon_settings.booking_mode` je do ovog taska postojala kroz cijeli stek i
-- nigdje se nije citala. Ovaj fajl dokazuje da je zica spojena, i to **s kraja na kraj**:
-- mod se ne prebacuje `update`-om nego pozivom `update_salon_settings` — iste funkcije koju
-- zove admin ekran — pa se odmah iza toga rezervise termin i gleda sta je nastalo.
--
-- Cetiri granice:
--   1. `manual` daje `pending` **sa** rokom, `auto` daje `confirmed` **bez** roka;
--   2. **`source` ostaje `app` u oba moda.** Automatski potvrdjen termin je i dalje stigao
--      iz aplikacije; da se `source` mijenjao zajedno sa statusom, salon bi u izvjestaju
--      izgubio razliku izmedju svoje rucne rezervacije i klijentove;
--   3. **admin unos ne zavisi od postavke** — `confirmed`/`manual` i u `manual` modu
--      (task 24: salon ne ceka potvrdu od sebe) i u `auto` modu;
--   4. **prebacivanje postavke ne dira postojece termine.** Ovo je negativan test koji bi
--      pao da je neko rijesio zadatak `update`-om nad zatecenim redovima umjesto granom u
--      `book_appointment`.
--
-- Na kraju stoji asercija nad `pg_proc`: zamka ovog taska je da `create or replace` sa
-- drugacijim potpisom nije zamjena nego **preopterecenje**, pa obje verzije ostanu u bazi
-- sa grantom i stari poziv tiho ode na staru.
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
  'ee000000-0000-4000-8000-000000000002'::uuid as admin,
  -- Izveden datum, ne fiksan: `max_advance_booking_days` je 30, pa bi fiksan datum jednog
  -- dana ispao van raspona i test bi pao iz pogresnog razloga (isto kao u `004` i `014`).
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak;
grant select on afix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('ee000000-0000-4000-8000-000000000001', 'klijent@auto.invalid', '{"providers":["email"]}', '{}'),
('ee000000-0000-4000-8000-000000000002', 'admin@auto.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('ee000000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'admin@auto.invalid', 'salon_admin');

-- Polazno stanje dolazi iz seeda i **nije** pretpostavka nego asercija: sve ispod mjeri
-- promjenu u odnosu na ovo, pa bi seed sa `auto` ucinio prvu sekciju besmislenom, a ne crvenom.
select is((select booking_mode from public.salon_settings where salon_id = (select salon from afix)),
  'manual', 'Salon krece iz manual moda, kako ga init migracija podrazumijeva');
select is((select pending_expiry_hours from public.salon_settings where salon_id = (select salon from afix)),
  12, 'Rok isteka je 12 sati — vrijednost koju asercije ispod porede');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table moj as
select (public.ensure_customer((select salon from afix))).id as customer_id;
reset role;
grant select on moj to public;

-- ---------------------------------------------------------------------------
-- 1. `manual`: klijent dobija `pending` sa rokom
-- ---------------------------------------------------------------------------
set local role authenticated;
create temporary table t_manual as
select public.book_appointment(
  (select salon from afix), (select customer_id from moj), (select usluga from afix),
  (select utorak from afix), '10:00', (select emir from afix)) as row;
reset role;
grant select on t_manual to public;

select is((select (row).status::text from t_manual), 'pending',
  'Manual mod: klijentska rezervacija ceka odgovor salona');
select is((select (row).source::text from t_manual), 'app',
  'Rezervacija iz aplikacije nosi source=app');
select ok((select (row).pending_expires_at is not null from t_manual),
  'Pending termin nosi rok isteka');
-- Rok se ne poredi na sekundu (`now()` u funkciji nije `now()` u asercji) nego se provjerava
-- da pada u sat oko `+12h`. Sira granica bi propustila rok racunat iz pogresne postavke.
select ok((select (row).pending_expires_at between now() + interval '11 hours 30 minutes'
                                              and now() + interval '12 hours 30 minutes'
           from t_manual),
  'Rok isteka dolazi iz pending_expiry_hours, ne iz konstante');

-- ---------------------------------------------------------------------------
-- 2. `manual`: admin unos je odmah potvrdjen (task 24 se ne smije pokvariti)
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table t_admin_manual as
select public.book_appointment(
  (select salon from afix), (select customer_id from moj), (select usluga from afix),
  (select utorak from afix), '12:00', (select emir from afix)) as row;
reset role;
grant select on t_admin_manual to public;

select is((select (row).status::text from t_admin_manual), 'confirmed',
  'Manual mod ne tjera salon da ceka potvrdu od sebe');
select is((select (row).source::text from t_admin_manual), 'manual',
  'Rucni unos nosi source=manual');
select ok((select (row).pending_expires_at is null from t_admin_manual),
  'Potvrdjen termin nema rok isteka');

-- ---------------------------------------------------------------------------
-- 3. Prebacivanje moda ide kroz `rpc` koji zove admin ekran
-- ---------------------------------------------------------------------------
-- Ostale vrijednosti su prepisane iz seeda: `update_salon_settings` prima cijeli skup, pa
-- bi nabacane vrijednosti tiho promijenile korak, pauzu ili prag i pomjerile slotove ispod.
set local role authenticated;
select lives_ok($$
  select public.update_salon_settings(
    '550e8400-e29b-41d4-a716-446655440000', 'auto', 'exact_slot',
    5, 15, 2, 30, 3, false, true, false)
$$, 'Vlasnik prebacuje salon na automatsko potvrdjivanje');
reset role;

select is((select booking_mode from public.salon_settings where salon_id = (select salon from afix)),
  'auto', 'Postavka je zapisana');
-- Mod je postavka **jednog** salona. Da je procitan iz prve zatecene vrste, ovo bi bio
-- jedini test koji bi to primijetio.
select is((select booking_mode from public.salon_settings where salon_id = (select drugi_salon from afix)),
  'manual', 'Drugi salon ostaje u svom modu');

-- ---------------------------------------------------------------------------
-- 4. Negativan test: postavka vrijedi unaprijed, ne unazad
-- ---------------------------------------------------------------------------
-- Termin iz sekcije 1 je nastao dok je salon bio `manual`. Vlasnik koji ukljuci automatsko
-- potvrdjivanje nije time odgovorio na zahtjeve koji vec cekaju — na njih se odgovara na
-- ekranu zahtjeva. Ova dva reda bi pala da je zadatak rijesen `update`-om nad zatecenim
-- terminima umjesto granom u `book_appointment`.
select is((select status::text from public.appointments where id = (select (row).id from t_manual)),
  'pending', 'Zatecen zahtjev i dalje ceka odgovor');
select is((select pending_expires_at from public.appointments where id = (select (row).id from t_manual)),
  (select (row).pending_expires_at from t_manual),
  'Zatecenom zahtjevu se ne mijenja ni rok');

-- ---------------------------------------------------------------------------
-- 5. `auto`: klijent dobija `confirmed` bez roka, ali i dalje `source = app`
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table t_auto as
select public.book_appointment(
  (select salon from afix), (select customer_id from moj), (select usluga from afix),
  (select utorak from afix), '11:00', (select emir from afix)) as row;
reset role;
grant select on t_auto to public;

select is((select (row).status::text from t_auto), 'confirmed',
  'Auto mod: klijentska rezervacija je potvrdjena odmah');
select ok((select (row).pending_expires_at is null from t_auto),
  'Potvrdjena rezervacija nema sta cekati, pa nema ni rok');
-- Ovo je asercija koja stiti podatak, ne ponasanje: status i `source` odgovaraju na dva
-- razlicita pitanja — da li salon ceka odgovor, i odakle je termin stigao.
select is((select (row).source::text from t_auto), 'app',
  'Auto mod ne pretvara klijentsku rezervaciju u rucni unos');

-- ---------------------------------------------------------------------------
-- 6. `auto`: admin unos ostaje rucni unos
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table t_admin_auto as
select public.book_appointment(
  (select salon from afix), (select customer_id from moj), (select usluga from afix),
  (select utorak from afix), '13:00', (select emir from afix)) as row;
reset role;
grant select on t_admin_auto to public;

select is((select (row).status::text from t_admin_auto), 'confirmed',
  'Admin unos u auto modu je potvrdjen, kao i prije');
select is((select (row).source::text from t_admin_auto), 'manual',
  'Admin unos u auto modu i dalje nosi source=manual');

-- ---------------------------------------------------------------------------
-- 7. Zamka: zamjena, ne preopterecenje
-- ---------------------------------------------------------------------------
-- Migracija ovog taska koristi `create or replace`. Sa drugacijim potpisom bi napravila
-- **drugu** funkciju istog imena; obje bi imale grant, a PostgREST bi stari poziv sa osam
-- argumenata i dalje slao na staru verziju — dakle na `manual` ponasanje, i nijedna asercija
-- iznad to ne bi vidjela, jer sve zovu funkciju direktno iz SQL-a sa istim argumentima.
select is((select count(*)::int from pg_proc p
           join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'book_appointment'), 1,
  'U bazi postoji tacno jedna book_appointment — zamjena, ne preopterecenje');
select ok(not has_function_privilege('anon',
  'public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid)', 'EXECUTE'),
  'Anon i dalje ne rezervise');
select ok(has_function_privilege('authenticated',
  'public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid)', 'EXECUTE'),
  'Prijavljeni klijent i dalje rezervise');

select * from finish();
rollback;
