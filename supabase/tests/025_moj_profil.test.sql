-- Moj profil. Task 61.
--
-- Granice koje se ovdje dokazuju:
--   1. nalog osoblja mijenja samo **svoj** red, i samo kroz rpc — direktan update ne prolazi, a
--      klijent, anon i podmetnut claim bez reda dobijaju `42501`;
--   2. profilna slika mora biti objekat **mog** salona u `profil/` sa mojim `uid` prefiksom —
--      tuđi uid, tuđi salon, drugi folder i dodatni segment se odbijaju;
--   3. prekidač upisuje profilnu sliku u povezanog radnika i vraća salonsku kad se ugasi;
--   4. radnik smije poslati u bucket samo svoju profilnu sliku;
--   5. sweep iz taska 51 ne briše sliku koju referencira samo `users`;
--   6. lična slika ne ostaje u katalogu kad se prekidač, veza ili nalog promijene (`rls-auditor`).
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table pfix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as drugi_salon,
  'cb000000-0000-4000-8000-000000000001'::uuid as vlasnik,
  'cb000000-0000-4000-8000-000000000002'::uuid as radnik,
  'cb000000-0000-4000-8000-000000000003'::uuid as vlasnik_b,
  'cb000000-0000-4000-8000-000000000004'::uuid as klijent,
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  '20000000-0000-4000-8000-000000000002'::uuid as amar,
  '20000000-0000-4000-8000-000000000003'::uuid as amina_b,
  'http://127.0.0.1:54321/storage/v1/object/public/salon-media/' as baza;
grant select on pfix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('cb000000-0000-4000-8000-000000000001', 'vlasnik-pr@invalid.test',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('cb000000-0000-4000-8000-000000000002', 'radnik-pr@invalid.test',
 '{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('cb000000-0000-4000-8000-000000000003', 'vlasnik-b-pr@invalid.test',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}', '{}'),
('cb000000-0000-4000-8000-000000000004', 'klijent-pr@invalid.test', '{}', '{}');
insert into public.users(id, salon_id, name, email, role, employee_id) values
('cb000000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'vlasnik-pr@invalid.test', 'salon_admin', null),
('cb000000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440000',
 'Radnik', 'radnik-pr@invalid.test', 'employee', '20000000-0000-4000-8000-000000000001'),
('cb000000-0000-4000-8000-000000000003', '550e8400-e29b-41d4-a716-446655440001',
 'Vlasnica B', 'vlasnik-b-pr@invalid.test', 'salon_admin', null);

-- Objekti iza URL-ova koje test snima: trigger iz taska 51 odbija referencu na nepostojeći.
insert into storage.objects(bucket_id, name) values
('salon-media', '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-a.jpg'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-b.jpg'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000001-a.jpg'),
('salon-media', '550e8400-e29b-41d4-a716-446655440000/radnici/salonska.jpg')
on conflict do nothing;

-- Poznato polazno stanje — seed se može mijenjati.
update public.employees set image_url = (select baza from pfix)
  || '550e8400-e29b-41d4-a716-446655440000/radnici/salonska.jpg'
where id = '20000000-0000-4000-8000-000000000001';

-- ---------------------------------------------------------------------------
-- 1. Grantovi
-- ---------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.update_my_profile(text, text)', 'EXECUTE'),
  'Anon ne mijenja profil');
select ok(not has_function_privilege('anon', 'public.set_my_photo(text)', 'EXECUTE'),
  'Anon ne mijenja profilnu sliku');
select ok(not has_function_privilege('anon', 'public.set_use_profile_photo(boolean)', 'EXECUTE'),
  'Anon ne dira prekidač');
select ok(not has_function_privilege('anon', 'public.link_my_employee(uuid)', 'EXECUTE'),
  'Anon ne veže radnika');
select ok(not has_function_privilege('authenticated', 'private.restore_salon_photo(uuid)', 'EXECUTE'),
  'Vraćanje salonske slike nije javno');
select ok(not has_function_privilege('anon', 'public.mark_password_changed()', 'EXECUTE'),
  'Anon ne javlja promjenu lozinke');
select ok(has_function_privilege('authenticated', 'public.set_my_photo(text)', 'EXECUTE'),
  'Prijavljen korisnik može pozvati rpc (prava provjerava funkcija)');

-- ---------------------------------------------------------------------------
-- 2. Helper putanje — prefiks dolazi iz `iss` claima, pa i ovo ide pod claimom
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"cb000000-0000-4000-8000-000000000002","role":"authenticated","iss":"http://127.0.0.1:54321/auth/v1","app_metadata":{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
select ok(not private.is_profile_media_url((select salon from pfix), (select radnik from pfix),
  'https://napadac.test/storage/v1/object/public/salon-media/550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-x1.jpg'),
  'Strani host sa ispravnom putanjom ne prolazi');
select ok(not private.is_profile_media_url((select salon from pfix), (select radnik from pfix),
  (select baza from pfix) || '550E8400-E29B-41D4-A716-446655440000/profil/cb000000-0000-4000-8000-000000000002-x1.jpg'),
  'Salon velikim slovima ne prolazi');
select ok(private.is_profile_media_url((select salon from pfix), (select radnik from pfix),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-x1.jpg'),
  'Svoja profilna slika prolazi');
select ok(not private.is_profile_media_url((select salon from pfix), (select radnik from pfix),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000001-x1.jpg'),
  'Tuđi uid ne prolazi');
select ok(not private.is_profile_media_url((select salon from pfix), (select radnik from pfix),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440001/profil/cb000000-0000-4000-8000-000000000002-x1.jpg'),
  'Tuđi salon ne prolazi');
select ok(not private.is_profile_media_url((select salon from pfix), (select radnik from pfix),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440000/radnici/cb000000-0000-4000-8000-000000000002-x1.jpg'),
  'Drugi folder ne prolazi');
select ok(not private.is_profile_media_url((select salon from pfix), (select radnik from pfix),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-x/y.jpg'),
  'Dodatni segment ne prolazi');
select ok(not private.is_profile_media_url((select salon from pfix), (select radnik from pfix),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002.jpg'),
  'Uid bez crtice i imena ne prolazi');

-- ---------------------------------------------------------------------------
-- 3. Radnik: lični podaci
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"cb000000-0000-4000-8000-000000000002","role":"authenticated","iss":"http://127.0.0.1:54321/auth/v1","app_metadata":{"role":"employee","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;

select lives_ok($$ select public.update_my_profile('  Emir Bešić ', '061 448 220') $$,
  'Radnik mijenja svoje ime i telefon');
select is((select name || '|' || phone from public.users), 'Emir Bešić|061 448 220',
  'Ime je obrezano, telefon upisan');
select throws_ok($$ select public.update_my_profile('', '061') $$, 'PT400', null,
  'Prazno ime se odbija');
select throws_ok($$ select public.update_my_profile('Emir', 'pozovi me') $$, 'PT400', null,
  'Telefon sa slovima se odbija');
select throws_ok($$ select public.update_my_profile('Emir', repeat('1', 31)) $$, 'PT400', null,
  'Telefon duži od 30 znakova se odbija');

-- Direktan update nema politiku: ni uloga, ni salon, ni veza se ne mijenjaju mimo rpc-a.
update public.users set role = 'salon_admin', name = 'Hak' where id = auth.uid();
select is((select role::text || '|' || name from public.users), 'employee|Emir Bešić',
  'Direktan update vlastitog reda ne mijenja ništa');

-- ---------------------------------------------------------------------------
-- 4. Radnik: profilna slika i prekidač
-- ---------------------------------------------------------------------------
select throws_ok($$ select public.set_use_profile_photo(true) $$, 'PT400', null,
  'Prekidač bez profilne slike se odbija');
select throws_ok($$ select public.set_my_photo((select baza from pfix)
  || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000001-a.jpg') $$,
  'PT400', null, 'Tuđa profilna slika iz istog salona se odbija');
select throws_ok($$ select public.set_my_photo('https://images.test/vanjska.jpg') $$,
  'PT400', null, 'Vanjski URL se odbija');
select throws_ok($$ select public.set_my_photo('https://napadac.test/storage/v1/object/public/salon-media/'
  || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-a.jpg') $$,
  'PT400', null, 'Strani host sa postojećim objektom se odbija');
select throws_ok($$ select public.set_my_photo((select baza from pfix)
  || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-nema.jpg') $$,
  'PT400', null, 'Nepostojeći objekat odbija trigger iz taska 51');

select lives_ok($$ select public.set_my_photo((select baza from pfix)
  || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-a.jpg') $$,
  'Svoja profilna slika se upisuje');
select is((select image_url from public.employees where id = (select emir from pfix)),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440000/radnici/salonska.jpg',
  'Dok je prekidač ugašen, salon zadržava svoju sliku');

select lives_ok($$ select public.set_use_profile_photo(true) $$, 'Prekidač se pali');
select is((select image_url from public.employees where id = (select emir from pfix)),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-a.jpg',
  'Upaljen prekidač: klijent vidi profilnu sliku');

select lives_ok($$ select public.set_my_photo((select baza from pfix)
  || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-b.jpg') $$,
  'Nova profilna slika');
select is((select image_url from public.employees where id = (select emir from pfix)),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-b.jpg',
  'Nova slika stiže u salon dok je prekidač upaljen');

select lives_ok($$ select public.set_use_profile_photo(false) $$, 'Prekidač se gasi');
select is((select image_url from public.employees where id = (select emir from pfix)),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440000/radnici/salonska.jpg',
  'Ugašen prekidač vraća salonsku sliku');

select lives_ok($$ select public.set_use_profile_photo(true) $$, 'Prekidač ponovo');
select lives_ok($$ select public.set_my_photo(null) $$, 'Uklanjanje profilne slike');
select is((select image_url from public.employees where id = (select emir from pfix)),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440000/radnici/salonska.jpg',
  'Uklonjena profilna slika vraća salonu njegovu');
select is((select use_profile_photo from public.users), false,
  'Uklonjena profilna slika gasi prekidač');

select throws_ok($$ select public.link_my_employee((select amar from pfix)) $$, '42501', null,
  'Radnik ne mijenja vezu sa radnikom');

-- Salonska slika koje više nema u bucketu ne smije blokirati gašenje prekidača.
select lives_ok($$ select public.set_my_photo((select baza from pfix)
  || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-a.jpg') $$,
  'Profilna slika ponovo');
select lives_ok($$ select public.set_use_profile_photo(true) $$, 'Prekidač ponovo');
reset role;
update public.users set salon_photo_url = (select baza from pfix)
  || '550e8400-e29b-41d4-a716-446655440000/radnici/obrisana.jpg'
where id = (select radnik from pfix);
set local role authenticated;
select lives_ok($$ select public.set_use_profile_photo(false) $$,
  'Gašenje radi i kad salonske slike više nema');
select is((select image_url from public.employees where id = (select emir from pfix)), null,
  'Nepostojeća salonska slika se ne vraća u katalog');

-- ---------------------------------------------------------------------------
-- 5. Storage: radnik šalje samo svoju profilnu sliku
-- ---------------------------------------------------------------------------
select lives_ok($$ insert into storage.objects(bucket_id, name) values ('salon-media',
  '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-nova.jpg') $$,
  'Radnik šalje svoju profilnu sliku');
select throws_ok($$ insert into storage.objects(bucket_id, name) values ('salon-media',
  '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000001-podmetnuto.jpg') $$,
  '42501', null, 'Radnik ne šalje pod tuđim uid-om');
select throws_ok($$ insert into storage.objects(bucket_id, name) values ('salon-media',
  '550e8400-e29b-41d4-a716-446655440001/profil/cb000000-0000-4000-8000-000000000002-x.jpg') $$,
  '42501', null, 'Radnik ne šalje u tuđi salon');
select throws_ok($$ insert into storage.objects(bucket_id, name) values ('salon-media',
  '550e8400-e29b-41d4-a716-446655440000/galerija/cb000000-0000-4000-8000-000000000002-x.jpg') $$,
  '42501', null, 'Radnik i dalje ne piše u galeriju');
select throws_ok($$ insert into storage.objects(bucket_id, name) values ('salon-media',
  '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-x/y.jpg') $$,
  '42501', null, 'Dodatni segment se odbija');
select throws_ok($$ insert into storage.objects(bucket_id, name) values ('salon-media',
  '550E8400-E29B-41D4-A716-446655440000/profil/cb000000-0000-4000-8000-000000000002-x.jpg') $$,
  '42501', null, 'Salon velikim slovima se odbija (sweep ga ne bi vidio)');
select throws_ok($$ insert into storage.objects(bucket_id, name) values ('salon-media',
  '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-x/') $$,
  '42501', null, 'Završna kosa crta se odbija');

-- Deaktiviran radnik: JWT i red ostaju, `is_staff` ga odbija.
reset role;
update public.employees set is_active = false where id = (select emir from pfix);
set local role authenticated;
select throws_ok($$ select public.update_my_profile('Emir', '') $$, '42501', null,
  'Deaktiviran radnik ne mijenja profil');
select throws_ok($$ select public.set_my_photo(null) $$, '42501', null,
  'Deaktiviran radnik ne mijenja sliku');
select throws_ok($$ select public.set_use_profile_photo(true) $$, '42501', null,
  'Deaktiviran radnik ne dira prekidač');
select throws_ok($$ insert into storage.objects(bucket_id, name) values ('salon-media',
  '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-d.jpg') $$,
  '42501', null, 'Deaktiviran radnik ne šalje u bucket');
reset role;
update public.employees set is_active = true where id = (select emir from pfix);
set local role authenticated;

-- ---------------------------------------------------------------------------
-- 6. Vlasnik: veza sa radnikom
-- ---------------------------------------------------------------------------
reset role;
set local request.jwt.claims = '{"sub":"cb000000-0000-4000-8000-000000000001","role":"authenticated","iss":"http://127.0.0.1:54321/auth/v1","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;

select throws_ok($$ select public.set_use_profile_photo(true) $$, 'PT400', null,
  'Vlasnik bez veze nema prekidač');
select throws_ok($$ select public.link_my_employee((select emir from pfix)) $$, 'PT409', null,
  'Radnik koji već ima nalog se ne može preuzeti');
select throws_ok($$ select public.link_my_employee((select amina_b from pfix)) $$, '42501', null,
  'Radnik tuđeg salona se odbija');
select lives_ok($$ select public.link_my_employee((select amar from pfix)) $$,
  'Vlasnik se veže za svog radnika');
select is((select employee_id from public.users), (select amar from pfix), 'Veza je upisana');
select lives_ok($$ select public.set_my_photo((select baza from pfix)
  || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000001-a.jpg') $$,
  'Vlasnik postavlja profilnu sliku');
create temporary table amar_prije on commit drop as
  select image_url from public.employees where id = (select amar from pfix);
select lives_ok($$ select public.set_use_profile_photo(true) $$, 'Vlasnik pali prekidač');
select is((select image_url from public.employees where id = (select amar from pfix)),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000001-a.jpg',
  'Amar nosi vlasnikovu sliku');
select lives_ok($$ select public.link_my_employee(null) $$, 'Vlasnik skida vezu sa upaljenim prekidačem');
select is((select image_url from public.employees where id = (select amar from pfix)),
  (select image_url from amar_prije), 'Skidanje veze vraća Amaru njegovu sliku');
select is((select use_profile_photo from public.users), false, 'Skidanje veze gasi prekidač');

-- ---------------------------------------------------------------------------
-- 7. Ko nije osoblje
-- ---------------------------------------------------------------------------
reset role;
-- Klijent: prijavljen, bez reda u `users`.
set local request.jwt.claims = '{"sub":"cb000000-0000-4000-8000-000000000004","role":"authenticated","iss":"http://127.0.0.1:54321/auth/v1","app_metadata":{}}';
set local role authenticated;
select throws_ok($$ select public.update_my_profile('Klijent', '') $$, '42501', null,
  'Klijent nema profil osoblja');
select throws_ok($$ select public.mark_password_changed() $$, '42501', null,
  'Klijent ne javlja promjenu lozinke');
select throws_ok($$ insert into storage.objects(bucket_id, name) values ('salon-media',
  '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000004-x.jpg') $$,
  '42501', null, 'Klijent ne šalje profilnu sliku');

reset role;
-- Podmetnut claim vlasnika salona A, a red u `users` je za salon B.
set local request.jwt.claims = '{"sub":"cb000000-0000-4000-8000-000000000003","role":"authenticated","iss":"http://127.0.0.1:54321/auth/v1","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok($$ select public.update_my_profile('Hak', '') $$, '42501', null,
  'Claim tuđeg salona bez reda ne prolazi');
select throws_ok($$ insert into storage.objects(bucket_id, name) values ('salon-media',
  '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000003-x.jpg') $$,
  '42501', null, 'Claim tuđeg salona ne šalje profilnu sliku');

-- ---------------------------------------------------------------------------
-- 7b. Uklonjen nalog ne ostavlja ličnu sliku u katalogu
-- ---------------------------------------------------------------------------
reset role;
update public.users set use_profile_photo = true, salon_photo_url = (select baza from pfix)
  || '550e8400-e29b-41d4-a716-446655440000/radnici/salonska.jpg'
where id = (select radnik from pfix);
update public.employees set image_url = (select baza from pfix)
  || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-a.jpg'
where id = (select emir from pfix);
delete from public.users where id = (select radnik from pfix);
select is((select image_url from public.employees where id = (select emir from pfix)),
  (select baza from pfix) || '550e8400-e29b-41d4-a716-446655440000/radnici/salonska.jpg',
  'Uklonjen radnik: salon dobija nazad svoju sliku');

-- ---------------------------------------------------------------------------
-- 8. Sweep ne briše ono što referencira samo `users`
-- ---------------------------------------------------------------------------
reset role;
update public.users set photo_url = (select baza from pfix)
  || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000001-a.jpg'
where id = (select vlasnik from pfix);
update public.users set salon_photo_url = (select baza from pfix)
  || '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-b.jpg'
where id = (select vlasnik from pfix);
set local role service_role;
select ok(not exists (select 1 from public.media_orphans(interval '-1 hour', 1000) o
  where o.name = '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000001-a.jpg'),
  'Profilna slika nije siroče');
select ok(not exists (select 1 from public.media_orphans(interval '-1 hour', 1000) o
  where o.name = '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-b.jpg'),
  'Sačuvana salonska slika nije siroče');
select ok(exists (select 1 from public.media_orphans(interval '-1 hour', 1000) o
  where o.name = '550e8400-e29b-41d4-a716-446655440000/profil/cb000000-0000-4000-8000-000000000002-nova.jpg'),
  'Nereferencirana profilna slika jeste siroče');

select * from finish();
rollback;
