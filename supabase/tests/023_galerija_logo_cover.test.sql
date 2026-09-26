-- Galerija salona, logo i cover. Task 50.
--
-- Granice koje se ovdje dokazuju:
--   1. Pisanje ide samo kroz rpc; anon ga ne moze ni pozvati;
--   2. vlasnik mijenja samo svoj salon — tudji salon, radnik i klijent dobijaju `42501`, i to
--      uz `x-salon-id` tog salona (ADR-0003);
--   3. nova slika mora biti objekat **ovog** salona u folderu svoje vrste — tudji salon, drugi
--      folder, vanjski URL i putanja sa dodatnim segmentom se odbijaju;
--   4. galerija se ne pregazi tiho: zastarjeli `p_expected` daje `PT409` i ne upisuje nista.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table gfix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as drugi_salon,
  'http://127.0.0.1:54321/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/' as baza,
  'http://127.0.0.1:54321/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440001/' as tudja_baza;
grant select on gfix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('ca000000-0000-4000-8000-000000000001', 'admin-gal-a@invalid.test',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('ca000000-0000-4000-8000-000000000002', 'admin-gal-b@invalid.test',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}', '{}'),
('ca000000-0000-4000-8000-000000000003', 'radnik-gal@invalid.test',
 '{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role, employee_id) values
('ca000000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik A', 'admin-gal-a@invalid.test', 'salon_admin', null),
('ca000000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440001',
 'Vlasnik B', 'admin-gal-b@invalid.test', 'salon_admin', null),
('ca000000-0000-4000-8000-000000000003', '550e8400-e29b-41d4-a716-446655440000',
 'Radnik', 'radnik-gal@invalid.test', 'employee', '20000000-0000-4000-8000-000000000001');

-- Poznato polazno stanje — seed se moze mijenjati, test ne smije zavisiti od njega.
update public.salons set gallery_urls = '["https://images.test/seed-1.jpg","https://images.test/seed-2.jpg"]'::jsonb,
  logo_url = null, cover_image_url = 'https://images.test/seed-cover.jpg'
where id = '550e8400-e29b-41d4-a716-446655440000';
update public.salons set gallery_urls = '[]'::jsonb, logo_url = null, cover_image_url = null
where id = '550e8400-e29b-41d4-a716-446655440001';

-- ---------------------------------------------------------------------------
-- 1. Grantovi
-- ---------------------------------------------------------------------------
select ok(not has_table_privilege('authenticated', 'public.salons', 'UPDATE'),
  'Direktan update salona i dalje ne postoji');
select ok(not has_function_privilege('anon', 'public.set_salon_image(uuid, text, text)', 'EXECUTE'),
  'Anon ne mijenja logo ni cover');
select ok(not has_function_privilege('anon', 'public.set_salon_gallery(uuid, jsonb, jsonb)', 'EXECUTE'),
  'Anon ne mijenja galeriju');
select ok(has_function_privilege('authenticated', 'public.set_salon_gallery(uuid, jsonb, jsonb)', 'EXECUTE'),
  'Prijavljen korisnik moze pozvati galeriju (prava provjerava funkcija)');
select ok(not has_function_privilege('anon', 'private.is_salon_media_url(uuid, text, text)', 'EXECUTE'),
  'Anon ne zove helper');

-- ---------------------------------------------------------------------------
-- 2. Helper putanje
-- ---------------------------------------------------------------------------
select ok(private.is_salon_media_url((select salon from gfix), 'logo',
  (select baza from gfix) || 'logo/abc-123.png'), 'Svoj logo prolazi');
select ok(not private.is_salon_media_url((select salon from gfix), 'logo',
  (select tudja_baza from gfix) || 'logo/abc-123.png'), 'Tudji salon ne prolazi');
select ok(not private.is_salon_media_url((select salon from gfix), 'logo',
  (select baza from gfix) || 'cover/abc-123.png'), 'Drugi folder ne prolazi');
select ok(not private.is_salon_media_url((select salon from gfix), 'logo',
  (select baza from gfix) || 'logo/a/b.png'), 'Dodatni segment ne prolazi');
select ok(not private.is_salon_media_url((select salon from gfix), 'logo',
  (select baza from gfix) || 'logo/a.png?x=1'), 'Upit na kraju ne prolazi');
select ok(not private.is_salon_media_url((select salon from gfix), 'logo',
  (select baza from gfix) || 'logo/..'), 'Roditeljski folder ne prolazi');
select ok(not private.is_salon_media_url((select salon from gfix), 'logo',
  'https://zlo.test/storage/v1/object/public/salon-media/x/logo/a.png'), 'Pogresan salon u putanji ne prolazi');
select ok(not private.is_salon_media_url((select salon from gfix), 'logo',
  'https://images.test/a.png'), 'Vanjski URL ne prolazi');

-- ---------------------------------------------------------------------------
-- 3. Vlasnik mijenja svoj logo i cover
-- ---------------------------------------------------------------------------
-- `x-salon-id` je namjerno drugi salon: header bira kontekst, ne daje prava.
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
set local request.jwt.claims = '{"sub":"ca000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;

select lives_ok($$
  select public.set_salon_image((select salon from gfix), 'logo', (select baza from gfix) || 'logo/l1.png')
$$, 'Vlasnik postavlja logo');
select is((select logo_url from public.salons where id = (select salon from gfix)),
  (select baza from gfix) || 'logo/l1.png', 'Logo je upisan');
select is((select cover_image_url from public.salons where id = (select salon from gfix)),
  'https://images.test/seed-cover.jpg', 'Promjena loga ne dira cover');

select lives_ok($$
  select public.set_salon_image((select salon from gfix), 'cover', (select baza from gfix) || 'cover/c1.jpg')
$$, 'Vlasnik postavlja cover');
select is((select logo_url from public.salons where id = (select salon from gfix)),
  (select baza from gfix) || 'logo/l1.png', 'Promjena covera ne dira logo');

select lives_ok($$
  select public.set_salon_image((select salon from gfix), 'logo', '  ')
$$, 'Prazno brise logo');
select is((select logo_url from public.salons where id = (select salon from gfix)), null,
  'Obrisan logo je NULL');

select throws_ok($$
  select public.set_salon_image((select salon from gfix), 'cover', (select tudja_baza from gfix) || 'cover/c1.jpg')
$$, 'PT400', 'Slika mora biti iz galerije salona', 'Tudji objekat kao cover se odbija');
select throws_ok($$
  select public.set_salon_image((select salon from gfix), 'cover', (select baza from gfix) || 'logo/l1.png')
$$, 'PT400', 'Slika mora biti iz galerije salona', 'Logo objekat kao cover se odbija');
select throws_ok($$
  select public.set_salon_image((select salon from gfix), 'cover', 'https://zlo.test/c.jpg')
$$, 'PT400', 'Slika mora biti iz galerije salona', 'Vanjski URL kao cover se odbija');
select throws_ok($$
  select public.set_salon_image((select salon from gfix), 'gallery_urls', null)
$$, 'PT400', 'Nepoznata vrsta slike', 'Vrsta van logo/cover se odbija');
select is((select cover_image_url from public.salons where id = (select salon from gfix)),
  (select baza from gfix) || 'cover/c1.jpg', 'Odbijeni pozivi ne mijenjaju cover');

-- Tudji salon, iako vlasnik ima valjan URL tog salona.
select throws_ok($$
  select public.set_salon_image((select drugi_salon from gfix), 'logo', (select tudja_baza from gfix) || 'logo/l.png')
$$, '42501', 'Nije dozvoljeno', 'Vlasnik ne mijenja logo tudjeg salona');
select throws_ok($$
  select public.set_salon_gallery((select drugi_salon from gfix), '[]'::jsonb,
    jsonb_build_array((select tudja_baza from gfix) || 'galerija/g.jpg'))
$$, '42501', 'Nije dozvoljeno', 'Vlasnik ne mijenja galeriju tudjeg salona');

-- ---------------------------------------------------------------------------
-- 4. Galerija: dodaj, promijeni redoslijed, obrisi
-- ---------------------------------------------------------------------------
select lives_ok($$
  select public.set_salon_gallery((select salon from gfix),
    '["https://images.test/seed-1.jpg","https://images.test/seed-2.jpg"]'::jsonb,
    jsonb_build_array('https://images.test/seed-2.jpg', (select baza from gfix) || 'galerija/g1.jpg',
                      'https://images.test/seed-1.jpg'))
$$, 'Dodavanje i promjena redoslijeda u jednom potezu');
select is((select gallery_urls from public.salons where id = (select salon from gfix)),
  jsonb_build_array('https://images.test/seed-2.jpg', (select baza from gfix) || 'galerija/g1.jpg',
                    'https://images.test/seed-1.jpg'),
  'Redoslijed je redoslijed niza (ADR-0008)');

-- Zastarjeli niz: drugi tab je ucitao polazno stanje i sada pokusava snimiti.
select throws_ok($$
  select public.set_salon_gallery((select salon from gfix),
    '["https://images.test/seed-1.jpg","https://images.test/seed-2.jpg"]'::jsonb,
    '["https://images.test/seed-1.jpg"]'::jsonb)
$$, 'PT409', 'Galerija je u međuvremenu promijenjena', 'Zastarjeli p_expected daje konflikt');
select is(jsonb_array_length((select gallery_urls from public.salons where id = (select salon from gfix))), 3,
  'Konflikt ne upisuje nista');
select throws_ok($$
  select public.set_salon_gallery((select salon from gfix), null, '[]'::jsonb)
$$, 'PT409', 'Galerija je u međuvremenu promijenjena', 'Bez p_expected nema upisa naslijepo');

-- Nova slika mora biti iz svog foldera; obrisana zatečena se ne moze vratiti kao "zatečena".
select throws_ok($$
  select public.set_salon_gallery((select salon from gfix),
    (select gallery_urls from public.salons where id = (select salon from gfix)),
    (select gallery_urls from public.salons where id = (select salon from gfix))
      || jsonb_build_array('https://zlo.test/x.jpg'))
$$, 'PT400', 'Slika mora biti iz galerije salona', 'Vanjski URL u galeriji se odbija');
select throws_ok($$
  select public.set_salon_gallery((select salon from gfix),
    (select gallery_urls from public.salons where id = (select salon from gfix)),
    jsonb_build_array((select tudja_baza from gfix) || 'galerija/g.jpg'))
$$, 'PT400', 'Slika mora biti iz galerije salona', 'Tudja slika u galeriji se odbija');
select throws_ok($$
  select public.set_salon_gallery((select salon from gfix),
    (select gallery_urls from public.salons where id = (select salon from gfix)),
    jsonb_build_array((select baza from gfix) || 'cover/c1.jpg'))
$$, 'PT400', 'Slika mora biti iz galerije salona', 'Cover objekat nije slika galerije');
select throws_ok($$
  select public.set_salon_gallery((select salon from gfix),
    (select gallery_urls from public.salons where id = (select salon from gfix)),
    jsonb_build_array('https://images.test/seed-1.jpg', 'https://images.test/seed-1.jpg'))
$$, 'PT400', 'Ista slika je dvaput u galeriji', 'Duplikat se odbija');
select throws_ok($$
  select public.set_salon_gallery((select salon from gfix),
    (select gallery_urls from public.salons where id = (select salon from gfix)),
    '[1]'::jsonb)
$$, 'PT400', 'Galerija mora biti lista slika', 'Element koji nije string se odbija');
select throws_ok($$
  select public.set_salon_gallery((select salon from gfix),
    (select gallery_urls from public.salons where id = (select salon from gfix)),
    '{"a":1}'::jsonb)
$$, 'PT400', 'Galerija mora biti lista slika', 'Objekat umjesto niza se odbija');
select throws_ok($$
  select public.set_salon_gallery((select salon from gfix),
    (select gallery_urls from public.salons where id = (select salon from gfix)),
    (select jsonb_agg((select baza from gfix) || 'galerija/g' || i || '.jpg') from generate_series(1, 31) i))
$$, 'PT400', 'Galerija prima najviše 30 slika', 'Vise od 30 slika se odbija');

select lives_ok($$
  select public.set_salon_gallery((select salon from gfix),
    (select gallery_urls from public.salons where id = (select salon from gfix)),
    '[]'::jsonb)
$$, 'Brisanje svih slika prolazi');
select is((select gallery_urls from public.salons where id = (select salon from gfix)), '[]'::jsonb,
  'Prazna galerija je prazan niz');
select throws_ok($$
  select public.set_salon_gallery((select salon from gfix), '[]'::jsonb,
    '["https://images.test/seed-1.jpg"]'::jsonb)
$$, 'PT400', 'Slika mora biti iz galerije salona',
  'Obrisana vanjska slika se ne vraca kao zatečena');

-- ---------------------------------------------------------------------------
-- 5. Radnik i klijent ne pisu nista
-- ---------------------------------------------------------------------------
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local request.jwt.claims = '{"sub":"ca000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
select throws_ok($$
  select public.set_salon_image((select salon from gfix), 'logo', (select baza from gfix) || 'logo/r.png')
$$, '42501', 'Nije dozvoljeno', 'Radnik ne mijenja logo');
select throws_ok($$
  select public.set_salon_gallery((select salon from gfix), '[]'::jsonb, '[]'::jsonb)
$$, '42501', 'Nije dozvoljeno', 'Radnik ne mijenja galeriju');

-- Podmetnut claim `salon_admin` bez reda u `public.users`.
set local request.jwt.claims = '{"sub":"ca000000-0000-4000-8000-0000000000ff","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
select throws_ok($$
  select public.set_salon_image((select salon from gfix), 'logo', (select baza from gfix) || 'logo/r.png')
$$, '42501', 'Nije dozvoljeno', 'Claim bez reda u users ne mijenja logo');
select throws_ok($$
  select public.set_salon_gallery((select salon from gfix), '[]'::jsonb, '[]'::jsonb)
$$, '42501', 'Nije dozvoljeno', 'Claim bez reda u users ne mijenja galeriju');

reset role;
select is((select logo_url from public.salons where id = (select salon from gfix)), null,
  'Odbijeni pozivi nisu upisali logo');

select * from finish();
rollback;
