-- Storage bucket po salonu. Task 48, ADR-0015.
--
-- Mjeri:
--   1. bucket postoji, javan je, i ogranicava tip (slika) i velicinu na samom bucketu;
--   2. vlasnik A upisuje, mijenja i brise u `A/...`, ali ne u `B/...`;
--   3. putanja bez salona ili sa nevaljanim prvim segmentom se odbija;
--   4. radnik salona A ne upisuje ni u A;
--   5. anon i klijent ne upisuju; anon ne lista objekte.
begin;
set local search_path = public, extensions;
select no_plan();
-- Storage API ovo postavlja prije brisanja; bez toga `storage.protect_delete` odbija i
-- dozvoljeno brisanje, pa test ne bi mjerio politiku.
set local storage.allow_delete_query = 'true';

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fb000000-0000-4000-8000-000000000001', 'vlasnik-a@t48.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('fb000000-0000-4000-8000-000000000002', 'vlasnik-b@t48.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}', '{}'),
('fb000000-0000-4000-8000-000000000003', 'radnik-a@t48.invalid',
 '{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role, employee_id) values
('fb000000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000', 'Vlasnik A', 'vlasnik-a@t48.invalid', 'salon_admin', null),
('fb000000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440001', 'Vlasnik B', 'vlasnik-b@t48.invalid', 'salon_admin', null),
('fb000000-0000-4000-8000-000000000003', '550e8400-e29b-41d4-a716-446655440000', 'Radnik A', 'radnik-a@t48.invalid', 'employee', '20000000-0000-4000-8000-000000000001');

-- Objekat salona B, upisan mimo RLS-a, da vlasnik A ima sta pokusati mijenjati i brisati.
insert into storage.objects(bucket_id, name, owner)
values ('salon-media', '550e8400-e29b-41d4-a716-446655440001/usluge/b.jpg', 'fb000000-0000-4000-8000-000000000002');

-- ---------------------------------------------------------------------------
-- 1. Bucket
-- ---------------------------------------------------------------------------
select is((select public from storage.buckets where id = 'salon-media'), true, 'Bucket je javan za citanje');
select is((select file_size_limit from storage.buckets where id = 'salon-media'), 5242880::bigint,
  'Bucket ogranicava velicinu na 5 MiB');
select set_eq($$ select unnest(allowed_mime_types) from storage.buckets where id = 'salon-media' $$,
  array['image/jpeg', 'image/png', 'image/webp'], 'Bucket prima samo slike');
select is(private.storage_salon_id('550e8400-e29b-41d4-a716-446655440000/usluge/a.jpg'),
  '550e8400-e29b-41d4-a716-446655440000'::uuid, 'Salon se cita iz prvog segmenta');
select is(private.storage_salon_id('nije-uuid/usluge/a.jpg'), null, 'Nevaljan prvi segment nije salon');
select is(private.storage_salon_id('550e8400-e29b-41d4-a716-446655440000/a.jpg'), null,
  'Putanja bez vrste nije salonska');

-- ---------------------------------------------------------------------------
-- 2. Vlasnik A
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fb000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;

select lives_ok($$ insert into storage.objects(bucket_id, name, owner)
  values ('salon-media', '550e8400-e29b-41d4-a716-446655440000/usluge/a.jpg', 'fb000000-0000-4000-8000-000000000001') $$,
  'Vlasnik A upisuje u svoj salon');
select is((select count(*)::int from storage.objects where bucket_id = 'salon-media'), 1,
  'Vlasnik A lista samo svoj objekat, ne objekat salona B');
select throws_ok($$ insert into storage.objects(bucket_id, name)
  values ('salon-media', '550e8400-e29b-41d4-a716-446655440001/usluge/podmetnuto.jpg') $$,
  '42501', null, 'Vlasnik A ne upisuje u salon B');
select throws_ok($$ insert into storage.objects(bucket_id, name)
  values ('salon-media', 'nije-uuid/usluge/x.jpg') $$,
  '42501', null, 'Putanja bez salona se odbija');
select throws_ok($$ insert into storage.objects(bucket_id, name)
  values ('salon-media', '550e8400-e29b-41d4-a716-446655440000/x.jpg') $$,
  '42501', null, 'Putanja bez vrste se odbija');
select throws_ok($$ update storage.objects set name = '550e8400-e29b-41d4-a716-446655440001/usluge/preseljeno.jpg'
  where name = '550e8400-e29b-41d4-a716-446655440000/usluge/a.jpg' $$,
  '42501', null, 'Vlasnik A ne seli svoj objekat u salon B');
-- SELECT politika vec sakriva objekat salona B, pa bi `update`/`delete` pogodili 0 redova i uz
-- oslabljenu politiku. Privremena siroka SELECT politika (samo u ovoj transakciji) cini da ovo
-- mjeri `using` politika za UPDATE i DELETE, a ne SELECT.
reset role;
create policy tmp_vidi_sve on storage.objects for select to authenticated using (bucket_id = 'salon-media');
set local role authenticated;
select is((select count(*)::int from storage.objects where name like '550e8400-e29b-41d4-a716-446655440001/%'), 1,
  'Uz privremenu SELECT politiku vlasnik A vidi objekat salona B');
-- Ispravna politika: 0 redova, bez greske. Oslabljen `using` pusti red do `with check`, koji baci
-- 42501 — pa i to obara ovu aserciju umjesto da prekine cijeli fajl.
select lives_ok($$ update storage.objects set metadata = '{"x":1}'
  where name like '550e8400-e29b-41d4-a716-446655440001/%' $$, 'Update nad objektom salona B ne pogadja nista');
select lives_ok($$ delete from storage.objects
  where name like '550e8400-e29b-41d4-a716-446655440001/%' $$, 'Delete nad objektom salona B ne baca gresku');
reset role;
drop policy tmp_vidi_sve on storage.objects;
select is((select metadata from storage.objects where name = '550e8400-e29b-41d4-a716-446655440001/usluge/b.jpg'), null,
  'Vlasnik A ne mijenja objekat salona B');
select is((select count(*)::int from storage.objects where name like '550e8400-e29b-41d4-a716-446655440001/%'), 1,
  'Vlasnik A ne brise objekat salona B');

set local request.jwt.claims = '{"sub":"fb000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select lives_ok($$ delete from storage.objects where name = '550e8400-e29b-41d4-a716-446655440000/usluge/a.jpg' $$,
  'Vlasnik A brise svoj objekat');
reset role;
select is((select count(*)::int from storage.objects where name like '550e8400-e29b-41d4-a716-446655440000/%'), 0,
  'Obrisan objekat salona A je stvarno nestao');

-- Podmetnut claim: token kaze salon B, a red u `users` kaze A — nema prava ni na jedan.
set local request.jwt.claims = '{"sub":"fb000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select throws_ok($$ insert into storage.objects(bucket_id, name)
  values ('salon-media', '550e8400-e29b-41d4-a716-446655440001/usluge/podmetnut-claim.jpg') $$,
  '42501', null, 'Claim za salon B bez reda u users ne daje upis u B');
reset role;

-- ---------------------------------------------------------------------------
-- 4. Radnik
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fb000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok($$ insert into storage.objects(bucket_id, name)
  values ('salon-media', '550e8400-e29b-41d4-a716-446655440000/radnici/ja.jpg') $$,
  '42501', null, 'Radnik ne upisuje ni u svoj salon');
select is((select count(*)::int from storage.objects where bucket_id = 'salon-media'), 0,
  'Radnik ne lista objekte');
reset role;

-- ---------------------------------------------------------------------------
-- 5. Anon i klijent
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"role":"anon"}';
set local role anon;
select throws_ok($$ insert into storage.objects(bucket_id, name)
  values ('salon-media', '550e8400-e29b-41d4-a716-446655440000/usluge/anon.jpg') $$,
  '42501', null, 'Anon ne upisuje');
select is((select count(*)::int from storage.objects where bucket_id = 'salon-media'), 0,
  'Anon ne lista objekte (javni URL ne ide kroz RLS)');
reset role;

-- Pravi klijent: nalog sa identitetom, salon A izabran kroz `x-salon-id`.
insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data, is_anonymous)
values ('fb000000-0000-4000-8000-0000000000cc', 'klijent@t48.invalid', '{"providers":["email"]}', '{}', false);
set local request.jwt.claims = '{"sub":"fb000000-0000-4000-8000-0000000000cc","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local role authenticated;
select ok(private.is_client(), 'Klijent je stvarno klijent (test ne prolazi zbog praznog naloga)');
select throws_ok($$ insert into storage.objects(bucket_id, name)
  values ('salon-media', '550e8400-e29b-41d4-a716-446655440000/usluge/klijent.jpg') $$,
  '42501', null, 'Klijent salona A ne upisuje u A');
select is((select count(*)::int from storage.objects where bucket_id = 'salon-media'), 0,
  'Klijent ne lista objekte');
reset role;

select * from finish();
rollback;
