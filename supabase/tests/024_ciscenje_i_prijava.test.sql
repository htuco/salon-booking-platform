-- Ciscenje bucketa i prijava sadrzaja. Task 51, ADR-0024.
--
-- Mjeri:
--   1. `media_orphans` vraca fajl bez reference, a ne vraca fajl sa referencom — ni kad je
--      referenca u neaktivnoj usluzi, u drugom salonu, u galeriji ili iza `?upit`;
--   2. upload mladji od 24h, putanja van `<salon>/<vrsta>/<fajl>`, UUID velikim slovima, `.`
--      segment i drugi bucket se nikad ne vracaju;
--   2a. nova referenca na `salon-media` mora pokazivati na postojeci objekat;
--   3. lista i preuzimanje prijava su samo za `service_role`;
--   4. prijavljuje samo pravi klijent, samo sliku iz galerije salona iz headera, jednom (i
--      nakon razrjesenja), najvise 10 puta dnevno;
--   5. salon (vlasnik, radnik) i klijent ne citaju prijave; `super_admin` cita i razrjesava.
begin;
set local search_path = public, extensions;
select no_plan();

-- A = Vitez, B = beauty iz seeda.
-- Polazno stanje: prazan bucket (lokalni stack moze imati objekte iz uzivo provjera).
set local storage.allow_delete_query = 'true';
delete from storage.objects where bucket_id = 'salon-media';

-- ---------------------------------------------------------------------------
-- 1–2. Siroce
-- ---------------------------------------------------------------------------
-- Stari objekti (25 sati), jedan od dva sata (forma jos otvorena) i jedan svjez. `owner` nije
-- bitan za listu.
insert into storage.objects(bucket_id, name, created_at) values
('salon-media', '550e8400-e29b-41d4-a716-446655440000/usluge/aktivna.jpg', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/usluge/neaktivna.jpg', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/radnici/emir.jpg', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/logo/l.png', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/cover/c.png', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/galerija/upit.jpg', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/galerija/zamijenjena.jpg', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/usluge/svjeza.jpg', now() - interval '5 minutes'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/cover/forma-otvorena.png', now() - interval '2 hours'),
('salon-media', '550E8400-E29B-41D4-A716-446655440000/usluge/velika-slova.jpg', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/usluge/./tacka.jpg', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/usluge/kosa-crta/', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440001/usluge/siroce.jpg', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440001/usluge/koristi-a.jpg', now() - interval '25 hours'),
('salon-media', 'nije-uuid/usluge/x.jpg', now() - interval '25 hours'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/bez-vrste.jpg', now() - interval '25 hours');
-- Isti oblik imena u drugom bucketu nije nas posao.
insert into storage.buckets(id, name, public) values ('t51-drugi', 't51-drugi', false);
insert into storage.objects(bucket_id, name, created_at) values
('t51-drugi', '550e8400-e29b-41d4-a716-446655440000/usluge/drugi-bucket.jpg', now() - interval '25 hours');

-- Reference. Host je proizvoljan — lista gleda putanju, ne host.
update public.services set image_url =
  'http://127.0.0.1:54321/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/usluge/aktivna.jpg'
where id = '10000000-0000-4000-8000-000000000001';
update public.services set is_active = false, image_url =
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/usluge/neaktivna.jpg'
where id = '10000000-0000-4000-8000-000000000002';
-- Salon A referencira objekat salona B. Rijetko, ali brisanje bi pokvarilo ekran salona A.
update public.services set image_url =
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440001/usluge/koristi-a.jpg'
where id = '10000000-0000-4000-8000-000000000003';
update public.employees set image_url =
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/radnici/emir.jpg'
where id = '20000000-0000-4000-8000-000000000001';
update public.salons set
  logo_url = 'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/logo/l.png',
  cover_image_url = 'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/cover/c.png',
  gallery_urls = jsonb_build_array(
    'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg',
    'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/upit.jpg?v=2',
    'https://images.unsplash.com/photo-vanjska?w=800')
where id = '550e8400-e29b-41d4-a716-446655440000';

select set_eq(
  $$ select salon_id::text || ' ' || name from public.media_orphans() $$,
  array[
    '550e8400-e29b-41d4-a716-446655440000 550e8400-e29b-41d4-a716-446655440000/galerija/zamijenjena.jpg',
    '550e8400-e29b-41d4-a716-446655440001 550e8400-e29b-41d4-a716-446655440001/usluge/siroce.jpg'
  ],
  'Siroce je samo fajl bez reference; referenca iz neaktivne usluge, drugog salona, galerije i URL-a sa upitom stiti fajl'
);
select ok(
  (select count(*) from public.media_orphans(interval '0 seconds')
   where name in ('550e8400-e29b-41d4-a716-446655440000/usluge/svjeza.jpg',
                  '550e8400-e29b-41d4-a716-446655440000/cover/forma-otvorena.png')) = 2,
  'Upload mladji od 24h je siroce tek kad prode prag — forma otvorena dva sata ga ne gubi'
);
select is(
  (select count(*)::int from public.media_orphans(interval '0 seconds')
   where name ilike '%velika-slova%' or name like '%/./%' or name like '%/'
      or name like '%drugi-bucket%'),
  0, 'UUID velikim slovima, `.` segment, zavrsna kosa crta i drugi bucket se ne vracaju — handler bi ih odbio i zauzeli bi listu'
);
select is(
  (select count(*)::int from public.media_orphans(interval '0 seconds')
   where name in ('nije-uuid/usluge/x.jpg', '550e8400-e29b-41d4-a716-446655440000/bez-vrste.jpg')),
  0, 'Putanja van <salon>/<vrsta>/<fajl> se nikad ne vraca'
);
select ok(
  (select bool_and(name like salon_id::text || '/%') from public.media_orphans(interval '0 seconds')),
  'Svaki red nosi salon iz prefiksa svoje putanje'
);

-- Zamjena slike usluge pretvara stari fajl u siroce.
update public.services set image_url =
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/usluge/svjeza.jpg'
where id = '10000000-0000-4000-8000-000000000001';
select ok(
  exists(select 1 from public.media_orphans()
         where name = '550e8400-e29b-41d4-a716-446655440000/usluge/aktivna.jpg'),
  'Zamijenjena slika usluge postaje siroce'
);
-- Uklanjanje slike iz galerije isto.
update public.salons set gallery_urls = '[]'::jsonb where id = '550e8400-e29b-41d4-a716-446655440000';
select ok(
  exists(select 1 from public.media_orphans()
         where name = '550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg'),
  'Slika uklonjena iz galerije postaje siroce'
);

-- ---------------------------------------------------------------------------
-- 2a. Referenca na obrisan objekat
-- ---------------------------------------------------------------------------
select throws_ok($$ update public.services set image_url =
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/usluge/obrisana.jpg'
  where id = '10000000-0000-4000-8000-000000000004' $$,
  'PT400', 'Slika više ne postoji — izaberite je ponovo',
  'Usluga ne snima sliku koju je sweep vec obrisao');
select throws_ok($$ update public.employees set image_url =
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/radnici/obrisana.jpg'
  where id = '20000000-0000-4000-8000-000000000002' $$,
  'PT400', null, 'Radnik ne snima obrisanu sliku');
select throws_ok($$ update public.salons set cover_image_url =
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/cover/obrisana.png'
  where id = '550e8400-e29b-41d4-a716-446655440000' $$,
  'PT400', null, 'Cover ne snima obrisanu sliku');
select throws_ok($$ update public.salons set gallery_urls = jsonb_build_array(
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/obrisana.jpg')
  where id = '550e8400-e29b-41d4-a716-446655440000' $$,
  'PT400', null, 'Galerija ne snima obrisanu sliku');
select lives_ok($$ update public.services set image_url =
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/cover/forma-otvorena.png'
  where id = '10000000-0000-4000-8000-000000000004' $$,
  'Postojeci objekat se snima');
select lives_ok($$ update public.services set image_url = 'https://images.unsplash.com/photo-x?w=800'
  where id = '10000000-0000-4000-8000-000000000004' $$,
  'Vanjski URL nije pitanje za bucket');

-- ---------------------------------------------------------------------------
-- 3. Grantovi
-- ---------------------------------------------------------------------------
select ok(not has_function_privilege('authenticated', 'public.media_orphans(interval, integer)', 'EXECUTE'),
  'Prijavljen korisnik ne lista siroce');
select ok(not has_function_privilege('anon', 'public.media_orphans(interval, integer)', 'EXECUTE'),
  'Anon ne lista siroce');
select ok(not has_function_privilege('authenticated', 'public.claim_content_reports(integer)', 'EXECUTE'),
  'Prijavljen korisnik ne preuzima prijave');
select ok(not has_function_privilege('authenticated', 'private.call_worker(text)', 'EXECUTE'),
  'Prijavljen korisnik ne okida workere');
select ok(not has_table_privilege('anon', 'public.content_reports', 'SELECT'),
  'Anon nema grant nad prijavama');
select ok(not has_function_privilege('anon', 'public.report_content(uuid, text, text)', 'EXECUTE'),
  'Anon ne prijavljuje');

-- ---------------------------------------------------------------------------
-- 4. Prijava
-- ---------------------------------------------------------------------------
update public.salons set gallery_urls = jsonb_build_array(
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg')
where id = '550e8400-e29b-41d4-a716-446655440000';

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data, is_anonymous) values
('fc000000-0000-4000-8000-000000000001', 'klijent@t51.invalid', '{"providers":["email"]}', '{}', false),
('fc000000-0000-4000-8000-000000000002', null, '{"providers":["anonymous"]}', '{}', true),
('fc000000-0000-4000-8000-000000000003', 'vlasnik-a@t51.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}', false),
('fc000000-0000-4000-8000-000000000004', 'platforma@t51.invalid', '{"role":"super_admin"}', '{}', false),
('fc000000-0000-4000-8000-000000000005', 'radnik-a@t51.invalid',
 '{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}', false),
('fc000000-0000-4000-8000-000000000006', 'lazna-platforma@t51.invalid', '{"role":"super_admin"}', '{}', false),
('fc000000-0000-4000-8000-000000000007', 'spam@t51.invalid', '{"providers":["email"]}', '{}', false);
insert into public.users(id, salon_id, name, email, role, employee_id) values
('fc000000-0000-4000-8000-000000000003', '550e8400-e29b-41d4-a716-446655440000', 'Vlasnik A', 'vlasnik-a@t51.invalid', 'salon_admin', null),
('fc000000-0000-4000-8000-000000000004', null, 'Platforma', 'platforma@t51.invalid', 'super_admin', null),
('fc000000-0000-4000-8000-000000000005', '550e8400-e29b-41d4-a716-446655440000', 'Radnik A', 'radnik-a@t51.invalid', 'employee', '20000000-0000-4000-8000-000000000001');

-- Klijent u salonu A.
set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local role authenticated;

create temporary table prva_prijava as
  select public.report_content('550e8400-e29b-41d4-a716-446655440000',
    'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg',
    '  Neprikladno  ') as id;
select isnt((select id from prva_prijava), null, 'Klijent prijavljuje sliku iz galerije salona');
select is(
  public.report_content('550e8400-e29b-41d4-a716-446655440000',
    'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg'),
  (select id from prva_prijava),
  'Ponovljena prijava iste slike vraca isti red'
);
select throws_ok($$ select public.report_content('550e8400-e29b-41d4-a716-446655440000',
  'https://evil.example/slika.jpg') $$,
  'PT400', 'Slika nije u galeriji salona', 'Proizvoljan URL se ne prijavljuje');
select throws_ok($$ select public.report_content('550e8400-e29b-41d4-a716-446655440000',
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg',
  repeat('x', 501)) $$,
  'PT400', 'Razlog je predug', 'Razlog preko 500 znakova se odbija');
select throws_ok($$ select public.report_content('550e8400-e29b-41d4-a716-446655440001',
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg') $$,
  '42501', 'Nije dozvoljeno', 'Klijent ne prijavljuje u salonu koji nije izabrao headerom');
select throws_ok($$ insert into public.content_reports(salon_id, image_url)
  values ('550e8400-e29b-41d4-a716-446655440000', 'https://x/y.jpg') $$,
  '42501', null, 'Klijent ne pise u tabelu prijava mimo RPC-a');
select is((select count(*)::int from public.content_reports), 0, 'Klijent ne cita prijave, ni svoju');

-- Klijent u salonu B ne prijavljuje sliku salona A, ni kad posalje id salona B.
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select throws_ok($$ select public.report_content('550e8400-e29b-41d4-a716-446655440001',
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg') $$,
  'PT400', 'Slika nije u galeriji salona', 'Slika salona A se ne prijavljuje kroz salon B');
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- Anonimna Auth sesija nije klijent.
set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000002","role":"authenticated","is_anonymous":true,"app_metadata":{"providers":["anonymous"]}}';
select throws_ok($$ select public.report_content('550e8400-e29b-41d4-a716-446655440000',
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg') $$,
  '42501', 'Nije dozvoljeno', 'Anonimna Auth sesija ne prijavljuje');

-- ---------------------------------------------------------------------------
-- 5. Ko cita prijave
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
select is((select count(*)::int from public.content_reports), 0, 'Vlasnik salona ne cita prijave svog sadrzaja');
select throws_ok($$ select public.report_content('550e8400-e29b-41d4-a716-446655440000',
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg') $$,
  '42501', 'Nije dozvoljeno', 'Vlasnik salona ne prijavljuje kao klijent');
update public.content_reports set status = 'dismissed';
reset role;
select is((select status from public.content_reports where id = (select id from prva_prijava)), 'open',
  'Vlasnik salona ne moze odbaciti prijavu');

set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000005","role":"authenticated","app_metadata":{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select is((select count(*)::int from public.content_reports), 0, 'Radnik ne cita prijave');
update public.content_reports set status = 'dismissed';
reset role;
select is((select status from public.content_reports where id = (select id from prva_prijava)), 'open',
  'Radnik ne moze odbaciti prijavu');
set local role authenticated;

-- JWT claim `super_admin` bez reda u `users` nije platforma.
set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000006","role":"authenticated","app_metadata":{"role":"super_admin"}}';
select is((select count(*)::int from public.content_reports), 0, 'Claim super_admin bez reda u users ne cita prijave');

set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"super_admin"}}';
select is((select count(*)::int from public.content_reports), 1, 'Platforma cita prijavu');
select is((select reason from public.content_reports), 'Neprikladno', 'Razlog je sacuvan bez razmaka');
select lives_ok($$ update public.content_reports set status = 'removed', resolved_at = now() $$,
  'Platforma razrjesava prijavu');
select throws_ok($$ update public.content_reports set image_url = 'https://x/drugo.jpg' $$,
  '42501', null, 'Ni platforma kroz API ne mijenja sta je prijavljeno');

-- Razrijesena prijava se ne obnavlja novim tapom istog klijenta.
set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
select is(
  public.report_content('550e8400-e29b-41d4-a716-446655440000',
    'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg'),
  (select id from prva_prijava),
  'Nakon razrjesenja ista prijava vraca isti red, ne novu poruku platformi'
);
reset role;
select is((select count(*)::int from public.content_reports), 1, 'I dalje je jedna prijava');

-- Dnevni limit: deset prijava u zadnja 24h, jedanaesta se odbija.
insert into public.content_reports(salon_id, image_url, reporter_user_id)
select '550e8400-e29b-41d4-a716-446655440000', 'https://x/spam-' || i || '.jpg', 'fc000000-0000-4000-8000-000000000007'
from generate_series(1, 10) i;
set local request.jwt.claims = '{"sub":"fc000000-0000-4000-8000-000000000007","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select throws_ok($$ select public.report_content('550e8400-e29b-41d4-a716-446655440000',
  'https://x.supabase.co/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/galerija/g1.jpg') $$,
  'PT429', 'Previše prijava u jednom danu', 'Jedanaesta prijava u danu se odbija');
reset role;
delete from public.content_reports where reporter_user_id = 'fc000000-0000-4000-8000-000000000007';

-- ---------------------------------------------------------------------------
-- Preuzimanje za webhook
-- ---------------------------------------------------------------------------
set local role service_role;
select is((select count(*)::int from public.claim_content_reports()), 1, 'Worker preuzima neobavijestenu prijavu');
select is((select count(*)::int from public.claim_content_reports()), 0, 'Preuzeta prijava se ne salje dvaput');
reset role;
select lives_ok($$ select private.dispatch_content_reports() $$,
  'Okidac bez Vault tajni ne pada');
select is((select count(*)::int from cron.job where jobname in ('cleanup-media', 'notify-content-reports')), 2,
  'Oba workera imaju cron');

select * from finish();
rollback;
