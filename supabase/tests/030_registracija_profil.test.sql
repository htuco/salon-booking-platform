-- Registracija sa imenom, telefonom i uslovima. Task 66.
--
-- Granice:
--   1. registracija kroz metapodatke upise ime, telefon i prihvatanje vazece verzije;
--      pokvaren telefon ne obara registraciju nego ostaje prazan;
--   2. prijava (UPDATE nad `auth.users`) ne prihvata uslove umjesto korisnika;
--   3. identitet popunjava adresar **svakog** svog salona i termine, ali samo „Klijent" i
--      prazan telefon — salonova ispravka ostaje;
--   4. telefon koji salon vec ima na drugom klijentu se preskace (unique po salonu);
--   5. tudji identitet se ne dira — popunjavanje ide samo kroz vlastiti identitet;
--   6. `complete_my_profile` odbija neispravan unos i ne-klijenta;
--   7. brisanje naloga brise i telefon.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table fix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as vitez,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as beauty,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  '20000000-0000-4000-8000-000000000001'::uuid as emir;
grant select on fix to public;

-- ---------------------------------------------------------------------------
-- 1. Registracija kroz metapodatke
-- ---------------------------------------------------------------------------
select is((select (terms, privacy) from public.legal_versions()), (1, 1),
  'Vazeca verzija uslova je 1/1');
select ok(has_function_privilege('anon', 'public.legal_versions()', 'execute'),
  'Verziju uslova vidi i neprijavljen korisnik');

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('f6000000-0000-4000-8000-000000000001', 'ana@reg66.invalid', '{"providers":["email"]}',
 '{"full_name":"Ana Anić","phone":"+387 62 123 456","terms_accepted":true}'),
('f6000000-0000-4000-8000-000000000002', 'bez@reg66.invalid', '{"providers":["email"]}',
 '{"phone":"nije-broj"}'),
('f6000000-0000-4000-8000-000000000003', 'kolega@reg66.invalid', '{"providers":["email"]}', '{}'),
('f6000000-0000-4000-8000-000000000004', 'adnan@reg66.invalid', '{"providers":["email"]}',
 '{"full_name":"Adnan App","phone":"+38761111111","terms_accepted":true}'),
('f6000000-0000-4000-8000-000000000009', 'vlasnik@reg66.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('f6000000-0000-4000-8000-000000000009', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'vlasnik@reg66.invalid', 'salon_admin');

select is((select (display_name, phone, terms_version, privacy_version, terms_accepted_at is not null)
    from public.auth_identities where supabase_user_id = 'f6000000-0000-4000-8000-000000000001'),
  ('Ana Anić'::text, '+387 62 123 456'::text, 1, 1, true),
  'Registracija upise ime, telefon onako kako je napisan i prihvatanje vazece verzije');
select is((select (phone, terms_version) from public.auth_identities
    where supabase_user_id = 'f6000000-0000-4000-8000-000000000002'),
  (null::text, null::int),
  'Pokvaren telefon ostaje prazan, a registracija bez checkboxa ne biljezi prihvatanje');

-- ---------------------------------------------------------------------------
-- 2. Prijava ne prihvata uslove umjesto korisnika
-- ---------------------------------------------------------------------------
-- Glumi novu verziju: Ana je prihvatila staru (0), a metapodatak `terms_accepted` jos stoji.
update public.auth_identities set terms_version = 0
where supabase_user_id = 'f6000000-0000-4000-8000-000000000001';
update auth.users set last_sign_in_at = now()
where id = 'f6000000-0000-4000-8000-000000000001';
select is((select terms_version from public.auth_identities
    where supabase_user_id = 'f6000000-0000-4000-8000-000000000001'),
  0, 'Prijava sa starim metapodatkom ne prihvata novu verziju');

set local request.jwt.claims = '{"sub":"f6000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select is((select (has_name, has_phone, terms_current) from public.client_profile_status()),
  (true, true, false), 'Status kaze da fali samo nova verzija uslova');
select lives_ok($$ select public.complete_my_profile(null, true) $$,
  'Ponovno prihvatanje kroz Dopuni profil, bez ponovnog unosa telefona');
select is((select phone from public.auth_identities
    where supabase_user_id = 'f6000000-0000-4000-8000-000000000001'),
  '+387 62 123 456', 'Prazan telefon zadrzava postojeci');
select is((select terms_current from public.client_profile_status()), true,
  'Poslije prihvatanja je verzija vazeca');
reset role;

-- ---------------------------------------------------------------------------
-- 3. Popunjavanje adresara u svakom salonu, ali samo „Klijent" i prazno
-- ---------------------------------------------------------------------------
-- „bez" (identitet 2) nema ni ime ni telefon: u oba salona nastaje „Klijent" bez broja.
set local request.jwt.claims = '{"sub":"f6000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local role authenticated;
create temporary table bez_vitez as
  select (public.ensure_customer((select vitez from fix))).id as id;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
create temporary table bez_beauty as
  select (public.ensure_customer((select beauty from fix))).id as id;
reset role;
grant select on bez_vitez, bez_beauty to public;

select is((select (name, phone) from public.customers where id = (select id from bez_vitez)),
  ('Klijent'::text, null::text), 'Polazno: bez imena je „Klijent" bez broja');

-- Termin zakazan dok je bio „Klijent" (upis kroz superusera, kao u `027`).
create temporary table bez_termin as
with novi as (
  insert into public.appointments(salon_id, service_id, employee_id, customer_id, auth_identity_id,
    customer_name, date, start_time, end_time, status, source)
  select f.vitez, f.usluga, f.emir, c.id, c.auth_identity_id, c.name,
    (now() at time zone 'Europe/Sarajevo')::date + 20, '16:00', '16:30', 'confirmed', 'app'
  from fix f, public.customers c where c.id = (select id from bez_vitez)
  returning id)
select id from novi;
grant select on bez_termin to public;

-- „kolega" (identitet 3) je drugi klijent istog salona — ne smije dobiti nista od identiteta 2.
set local request.jwt.claims = '{"sub":"f6000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local role authenticated;
create temporary table kolega_vitez as
  select (public.ensure_customer((select vitez from fix))).id as id;
reset role;
grant select on kolega_vitez to public;

set local request.jwt.claims = '{"sub":"f6000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select lives_ok($$ select public.complete_my_profile('061 222 333', true, 'Berin Begić') $$,
  'Dopuni profil sa imenom i telefonom');
reset role;

select is((select (name, phone) from public.customers where id = (select id from bez_vitez)),
  ('Berin Begić'::text, '061 222 333'::text), 'Vitez: „Klijent" dobija ime i telefon');
select is((select (name, phone) from public.customers where id = (select id from bez_beauty)),
  ('Berin Begić'::text, '061 222 333'::text), 'Beauty: isti identitet, isto popunjavanje');
select is((select (customer_name, customer_phone) from public.appointments
    where id = (select id from bez_termin)),
  ('Berin Begić'::text, '061 222 333'::text), 'Termin zakazan kao „Klijent" dobija ime i telefon');
select is((select (name, phone) from public.customers where id = (select id from kolega_vitez)),
  ('Klijent'::text, null::text), 'Drugi klijent istog salona ostaje netaknut');

-- Salon ispravi ime; identitet ga poslije ne prepisuje.
update public.customers set name = 'Berin (ispravio salon)' where id = (select id from bez_vitez);
update auth.users set raw_user_meta_data = '{"full_name":"Berin Novo"}'
where id = 'f6000000-0000-4000-8000-000000000002';
select is((select name from public.customers where id = (select id from bez_vitez)),
  'Berin (ispravio salon)', 'Salonova ispravka imena ostaje');
select is((select name from public.customers where id = (select id from bez_beauty)),
  'Berin Begić', 'Popunjeno ime se ne prepisuje ni u drugom salonu');

-- ---------------------------------------------------------------------------
-- 4. Telefon koji salon vec ima na drugom klijentu
-- ---------------------------------------------------------------------------
-- Seed: telefonski klijent „Adnan Music" u Vitezu ima +387 61 111 111. Adnan iz app-e upisuje
-- isti broj drugacije napisan.
set local request.jwt.claims = '{"sub":"f6000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local role authenticated;
select is((public.ensure_customer((select vitez from fix))).phone, null,
  'Vitez: broj koji salon vec ima na telefonskom klijentu se preskace');
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select is((public.ensure_customer((select beauty from fix))).phone, '+38761111111',
  'Beauty: isti broj tamo niko nema, pa ga red dobija');
select is((public.ensure_customer((select beauty from fix))).name, 'Adnan App',
  'Novi red dobija ime identiteta');
reset role;
select is((select count(*)::int from public.customers
    where salon_id = (select vitez from fix) and phone = '+387 61 111 111'),
  1, 'Telefonski klijent u Vitezu ostaje jedini sa tim brojem');

-- ---------------------------------------------------------------------------
-- 5. Dopuni profil: unos i uloge
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"f6000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select throws_ok($$ select public.complete_my_profile('abc', true, 'Kolega') $$, 'PT400',
  'Unesite ispravan broj telefona', 'Neispravan telefon je PT400');
select throws_ok($$ select public.complete_my_profile(null, true, 'Kolega') $$, 'PT400',
  'Unesite ispravan broj telefona', 'Bez telefona i bez postojeceg je PT400');
select throws_ok($$ select public.complete_my_profile('061 444 555', false, 'Kolega') $$, 'PT400',
  'Prihvatite Uslove korištenja i Politiku privatnosti', 'Bez checkboxa je PT400');
select throws_ok($$ select public.complete_my_profile('061 444 555', true) $$, 'PT400',
  'Unesite ime i prezime', 'Identitet bez imena mora dobiti ime');
reset role;

set local request.jwt.claims = '{"sub":"f6000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok($$ select public.complete_my_profile('061 444 555', true, 'Vlasnik') $$, '42501',
  null, 'Osoblje nema klijentski profil');
select throws_ok($$ select * from public.client_profile_status() $$, '42501',
  null, 'Osoblje nema status klijentskog profila');
reset role;

select ok(not has_function_privilege('anon', 'public.complete_my_profile(text, boolean, text)', 'execute'),
  'Anon ne moze dopuniti profil');
select ok(not has_function_privilege('anon', 'public.client_profile_status()', 'execute'),
  'Anon nema status profila');
select ok(not has_function_privilege('authenticated', 'private.fill_customers_from_identity(uuid)', 'execute'),
  'Popunjavanje adresara se ne moze pozvati direktno');

-- ---------------------------------------------------------------------------
-- 6. Brisanje naloga brise i telefon
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"f6000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select lives_ok($$ select public.delete_my_account() $$, 'Ana brise nalog');
reset role;
select is((select phone from public.auth_identities
    where supabase_user_id = 'f6000000-0000-4000-8000-000000000001'),
  null, 'Obrisan identitet nema telefon');

select * from finish();
rollback;
