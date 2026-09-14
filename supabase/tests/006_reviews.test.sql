-- Recenzije: ko sta vidi, i sta agregat odaje. Task 20.
--
-- Dvije stvari se ovdje dokazuju, i druga je vaznija:
--   1. `anon` vidi samo objavljene recenzije aktivnog salona;
--   2. **agregat postuje istu granicu.** Pogled `salon_rating_summary` sazima cijelu tabelu u
--      jedan red, pa je to najlaksi nacin da sakriven red iscuri kao broj. Seed zato drzi
--      sakrivenu jedinicu: ako politika ili `security_invoker` popuste, prosjek padne sa
--      4.8 na 4.7 i test to uhvati kao vrijednost, a ne kao broj redova.
begin;
set local search_path = public, extensions;
select no_plan();

-- Fixture: neaktivan salon sa objavljenom recenzijom. Objavljena je namjerno — dokazuje da
-- `is_published` sam po sebi nije dovoljan, nego da politika trazi i aktivan salon.
insert into public.salons(id,name,slug,city,status,vertical_pack_key) values
('550e8400-e29b-41d4-a716-446655440098','Neaktivni fixture','neaktivni-fixture','Vitez','inactive','barber');
insert into public.reviews(salon_id,author_name,rating,comment) values
('550e8400-e29b-41d4-a716-446655440098','Skriveni salon',5,'Recenzija salona koji nije aktivan.');

insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data) values
('a0000000-0000-4000-8000-000000000011','admin-a@reviews.invalid','{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}','{}'),
('a0000000-0000-4000-8000-000000000012','admin-b@reviews.invalid','{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}','{}'),
('a0000000-0000-4000-8000-000000000013','klijent@reviews.invalid','{"providers":["email"]}','{"name":"Klijent"}');
insert into public.users(id,salon_id,name,email,role) values
('a0000000-0000-4000-8000-000000000011','550e8400-e29b-41d4-a716-446655440000','Vlasnik A','admin-a@reviews.invalid','salon_admin'),
('a0000000-0000-4000-8000-000000000012','550e8400-e29b-41d4-a716-446655440001','Vlasnik B','admin-b@reviews.invalid','salon_admin');

-- ---------------------------------------------------------------------------
-- Struktura
-- ---------------------------------------------------------------------------
select ok(
  (select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='reviews'),
  'RLS je ukljucen na reviews');

-- Direktna straza nad opcijom pogleda. Ponasanje je pokriveno i asercijama nize, ali kad se
-- pogled jednom rekreira bez ove opcije, poruka "prosjek je 4.7" ne kaze zasto.
select ok(
  (select 'security_invoker=true' = any(c.reloptions)
   from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='salon_rating_summary'),
  'salon_rating_summary je security_invoker — inace zaobilazi RLS');

select throws_ok(
  $$insert into public.reviews(salon_id,author_name,rating) values('550e8400-e29b-41d4-a716-446655440000','Van opsega',6)$$,
  '23514', null, 'Ocjena iznad 5 je odbijena');
select throws_ok(
  $$insert into public.reviews(salon_id,author_name,rating) values('550e8400-e29b-41d4-a716-446655440000','   ',5)$$,
  '23514', null, 'Prazno ime autora je odbijeno');

-- ---------------------------------------------------------------------------
-- anon
-- ---------------------------------------------------------------------------
set local role anon;

select is((select count(*)::int from public.reviews),25,
  'Anon vidi 25 objavljenih recenzija aktivnog salona');
select is((select count(*)::int from public.reviews where not is_published),0,
  'Anon ne vidi nijednu sakrivenu recenziju');
select is((select count(*)::int from public.reviews where salon_id='550e8400-e29b-41d4-a716-446655440098'),0,
  'Anon ne vidi recenziju neaktivnog salona ni kad je objavljena');

-- Ovdje curenje postaje broj: sakrivena jedinica bi oborila prosjek na 4.7.
select is((select average from public.salon_rating_summary where salon_id='550e8400-e29b-41d4-a716-446655440000'),
  4.8::numeric, 'Prosjek za anon je 4.8 — sakrivena jedinica nije usla u agregat');
select is((select total from public.salon_rating_summary where salon_id='550e8400-e29b-41d4-a716-446655440000'),
  25, 'Agregat broji 25 ocjena, ne 26');
select results_eq(
  $$select count_5,count_4,count_3,count_2,count_1 from public.salon_rating_summary where salon_id='550e8400-e29b-41d4-a716-446655440000'$$,
  $$values (21,3,1,0,0)$$,
  'Histogram 5->1 je 21/3/1/0/0, kao na 13-recenzije.png');
select is((select count(*)::int from public.salon_rating_summary),1,
  'Agregat nema red za neaktivan salon ni za salon bez recenzija');

select throws_ok($$insert into public.reviews(salon_id,author_name,rating) values('550e8400-e29b-41d4-a716-446655440000','Napadac',5)$$,
  '42501','permission denied for table reviews','Anon ne moze upisati recenziju');
select throws_ok($$update public.reviews set rating=1$$,
  '42501','permission denied for table reviews','Anon ne moze mijenjati recenziju');
select throws_ok($$delete from public.reviews$$,
  '42501','permission denied for table reviews','Anon ne moze brisati recenziju');
reset role;

-- ---------------------------------------------------------------------------
-- Klijent — isti pogled kao anon, ne siri
-- ---------------------------------------------------------------------------
-- Prijavljen covjek nije privilegovan covjek. `x-salon-id` je namjerno postavljen na salon A:
-- header bira kontekst, ne daje prava (ADR-0003), i ne smije otkriti sakrivenu recenziju.
set local request.jwt.claims = '{"sub":"a0000000-0000-4000-8000-000000000013","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local role authenticated;
select is((select count(*)::int from public.reviews),25,'Klijent vidi isto sto i anon');
select is((select average from public.salon_rating_summary where salon_id='550e8400-e29b-41d4-a716-446655440000'),
  4.8::numeric,'Prijava ne mijenja prosjek');
select results_eq($$update public.reviews set rating=1 returning id$$,$$select null::uuid where false$$,
  'Klijentov update ne pogadja nijedan red');
reset role;

-- ---------------------------------------------------------------------------
-- Osoblje
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"a0000000-0000-4000-8000-000000000011","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
set local role authenticated;
select is((select count(*)::int from public.reviews),26,
  'Vlasnik A vidi i sakrivenu recenziju svog salona');
select is((select average from public.salon_rating_summary where salon_id='550e8400-e29b-41d4-a716-446655440000'),
  4.7::numeric,'Vlasnik A vidi prosjek sa sakrivenom — 4.7, ne 4.8');
select is((select count(*)::int from public.reviews where salon_id='550e8400-e29b-41d4-a716-446655440098'),0,
  'Vlasnik A ne vidi recenzije tudjeg salona ni kad je taj salon neaktivan');
select ok((select count(*) from public.reviews where is_published=false) = 1,
  'Sakrivena recenzija postoji i dostupna je svom salonu');
reset role;

set local request.jwt.claims = '{"sub":"a0000000-0000-4000-8000-000000000012","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select is((select count(*)::int from public.reviews where salon_id='550e8400-e29b-41d4-a716-446655440000'),25,
  'Vlasnik B nad salonom A pada na javnu politiku — 25, bez sakrivene');
select results_eq($$delete from public.reviews where salon_id='550e8400-e29b-41d4-a716-446655440000' returning id$$,
  $$select null::uuid where false$$,'Vlasnik B ne moze obrisati recenziju salona A');
reset role;

select * from finish();
rollback;
