-- Upsert klijenta kroz validiranu funkciju. Task 14.
-- Sve se vrti u transakciji koja se na kraju ponistava.
begin;
set local search_path = public, extensions;
select no_plan();

-- Dva salona iz seeda: isti covjek u oba mora dobiti dva odvojena `customers` reda.
create temporary table cfix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon_a,   -- Barber Studio Vitez
  '550e8400-e29b-41d4-a716-446655440001'::uuid as salon_b,   -- Beauty Studio Travnik
  'bb000000-0000-4000-8000-000000000001'::uuid as klijent,
  'bb000000-0000-4000-8000-000000000002'::uuid as drugi,
  'bb000000-0000-4000-8000-000000000003'::uuid as admin;
grant select on cfix to public;

-- `auth.users` insert okida trigger iz taska 02, koji pravi `auth_identities` red.
-- Time se usput dokazuje i taj trigger, na putu kojim stvarno prolazi prijava.
insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('bb000000-0000-4000-8000-000000000001', 'klijent@upsert.invalid',
 '{"providers":["email"]}', '{"full_name":"Amina Hodzic"}'),
('bb000000-0000-4000-8000-000000000002', 'drugi@upsert.invalid',
 '{"providers":["email"]}', '{}'),
('bb000000-0000-4000-8000-000000000003', 'admin@upsert.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('bb000000-0000-4000-8000-000000000003', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'admin@upsert.invalid', 'salon_admin');

select isnt(
  (select id from public.auth_identities where supabase_user_id = (select klijent from cfix)),
  null,
  'Trigger iz taska 02 je napravio auth_identities red na insert u auth.users');

-- ---------------------------------------------------------------------------
-- Srecan put
-- ---------------------------------------------------------------------------
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local request.jwt.claims = '{"sub":"bb000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;

select is(
  (select name from public.ensure_customer((select salon_a from cfix))),
  'Amina Hodzic',
  'Ime dolazi iz display_name-a koji je trigger prenio iz raw_user_meta_data');

select is(
  (select salon_id from public.ensure_customer((select salon_a from cfix))),
  (select salon_a from cfix),
  'Klijent nastaje u salonu iz x-salon-id headera');

-- ---------------------------------------------------------------------------
-- Idempotentnost
-- ---------------------------------------------------------------------------
-- Prijava se desava svaki put kad korisnik otvori app-u; drugi poziv ne smije napraviti
-- drugog klijenta, inace bi "Moji termini" s vremenom pokazivali samo zadnju sesiju.
select is(
  (select public.ensure_customer((select salon_a from cfix))).id,
  (select public.ensure_customer((select salon_a from cfix))).id,
  'Dva poziva vracaju isti red — upsert je idempotentan');

reset role;
select is(
  (select count(*)::int from public.customers c
   where c.salon_id = (select salon_a from cfix)
     and c.auth_identity_id = (select id from public.auth_identities
                               where supabase_user_id = (select klijent from cfix))),
  1,
  'Nakon vise poziva postoji tacno jedan red');

-- Salon je u medjuvremenu ispravio ime u svom adresaru.
update public.customers set name = 'Amina H. (stalna musterija)'
where salon_id = (select salon_a from cfix)
  and auth_identity_id = (select id from public.auth_identities
                          where supabase_user_id = (select klijent from cfix));

set local role authenticated;
select is(
  (select name from public.ensure_customer((select salon_a from cfix), 'Amina Hodzic')),
  'Amina H. (stalna musterija)',
  'Ponovni poziv ne prepisuje ime koje je salon ispravio');

-- ---------------------------------------------------------------------------
-- Izolacija: isti covjek, dva salona
-- ---------------------------------------------------------------------------
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';

select isnt(
  (select public.ensure_customer((select salon_b from cfix))).id,
  (select c.id from public.customers c
   where c.salon_id = (select salon_a from cfix)
     and c.auth_identity_id = (select id from public.auth_identities
                               where supabase_user_id = (select klijent from cfix))),
  'Isti nalog u drugom salonu dobija drugi customers red, ne dijeli postojeci');

reset role;
select is(
  (select count(*)::int from public.customers c
   where c.auth_identity_id = (select id from public.auth_identities
                               where supabase_user_id = (select klijent from cfix))),
  2,
  'Jedan identitet, dva salona, dva reda — `docs/06 §4`');

-- ---------------------------------------------------------------------------
-- Odbijanja
-- ---------------------------------------------------------------------------
set local role authenticated;

-- Header kaze salon B, argument salon A: pozivalac pokusava napraviti sebe klijentom
-- salona za koji nema kontekst. Ovo je jedina odbrana — argument sam po sebi ne dokazuje nista.
select throws_ok(
  format($$select public.ensure_customer(%L)$$, (select salon_a from cfix)),
  '42501', 'Nije dozvoljeno',
  'Salon iz argumenta koji se ne poklapa sa x-salon-id headerom je odbijen');

set local request.headers = '{}';
select throws_ok(
  format($$select public.ensure_customer(%L)$$, (select salon_a from cfix)),
  '42501', 'Nije dozvoljeno',
  'Bez x-salon-id headera nema konteksta, pa nema ni klijenta');

set local request.headers = '{"x-salon-id":"ovo-nije-uuid"}';
select throws_ok(
  format($$select public.ensure_customer(%L)$$, (select salon_a from cfix)),
  '42501', 'Nije dozvoljeno',
  'Pokvaren header ne otvara globalni doseg');

-- Osoblje ide drugim tokom (Sprint 3) i ovdje nema sta traziti: admin grana bi mogla
-- napraviti red vezan za tudji identitet.
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local request.jwt.claims = '{"sub":"bb000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
select throws_ok(
  format($$select public.ensure_customer(%L)$$, (select salon_a from cfix)),
  '42501', 'Nije dozvoljeno',
  'Admin salona ne pravi klijenta ovom funkcijom');

-- ---------------------------------------------------------------------------
-- Ime kad ga provider ne da
-- ---------------------------------------------------------------------------
-- Email OTP i Apple private relay cesto ne daju nikakvo ime, a `customers.name` je
-- `not null` — bez fallbacka bi prva prijava takvog korisnika pala.
set local request.jwt.claims = '{"sub":"bb000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"providers":["email"]}}';
select is(
  (select name from public.ensure_customer((select salon_a from cfix))),
  'Klijent',
  'Korisnik bez imena kod providera dobija neutralan fallback, ne gresku');

select is(
  (select name from public.ensure_customer((select salon_a from cfix), '  Emir K.  ')),
  'Klijent',
  'Ime iz argumenta ne prepisuje vec postojeci red');

-- ---------------------------------------------------------------------------
-- Direktan upis i dalje ne postoji
-- ---------------------------------------------------------------------------
-- Ako ovo ikad prodje, funkcija je postala ukras: klijent moze upisati sta hoce.
select throws_ok($$
  insert into public.customers(salon_id, auth_identity_id, name)
  values ('550e8400-e29b-41d4-a716-446655440000', null, 'Ubaceno mimo funkcije')
$$, '42501', NULL, 'Klijent nema insert grant na customers — funkcija je jedini put');

reset role;

-- ---------------------------------------------------------------------------
-- anon ne smije nista
-- ---------------------------------------------------------------------------
set local role anon;
select throws_ok(
  format($$select public.ensure_customer(%L)$$, (select salon_a from cfix)),
  '42501', NULL,
  'anon nema execute grant — rezervacija trazi prijavu');
reset role;

select * from finish();
rollback;
