-- Pozivi za nalog osoblja. Task 45, ADR-0023.
--
-- Mjeri:
--   1. samo admin salona pravi poziv, i samo u svom salonu; klijent i anon ne mogu;
--   2. `super_admin` se pozivom ne dodjeljuje — ni kroz RPC, ni upisom mimo njega;
--   3. kod se cuva kao hash; admin drugog salona ne vidi tudje pozive;
--   4. prihvatanje je samo za service role, pravi `public.users` sa ulogom **iz poziva**,
--      i kod radi jednom; povucen i istekao poziv se ne prihvata;
--   5. uklanjanje: pristup prestaje (`is_admin` false), termini ostaju; sebe se ne uklanja.
begin;
set local search_path = public, extensions;
select no_plan();

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fe000000-0000-4000-8000-000000000001', 'vlasnik-a@poziv45.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('fe000000-0000-4000-8000-000000000002', 'vlasnik-b@poziv45.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}', '{}'),
('fe000000-0000-4000-8000-000000000003', 'klijent@poziv45.invalid', '{"providers":["email"]}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('fe000000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik A', 'vlasnik-a@poziv45.invalid', 'salon_admin'),
('fe000000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440001',
 'Vlasnik B', 'vlasnik-b@poziv45.invalid', 'salon_admin');

-- ---------------------------------------------------------------------------
-- 1–2. Ko pravi poziv
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;

create temporary table poziv as
select * from public.create_staff_invite('550e8400-e29b-41d4-a716-446655440000', 'salon_admin', 'Novi Vlasnik');
create temporary table poziv_radnik as
select * from public.create_staff_invite('550e8400-e29b-41d4-a716-446655440000', 'employee', 'Amar',
  '20000000-0000-4000-8000-000000000001');
select is((select length(code) from poziv), 10, 'Admin dobija kod od 10 znakova');
select ok((select expires_at from poziv) between now() + interval '6 days 23 hours' and now() + interval '7 days 1 minute',
  'Poziv istice za 7 dana');

select throws_ok($$ select * from public.create_staff_invite('550e8400-e29b-41d4-a716-446655440001', 'employee', 'X') $$,
  '42501', null, 'Admin A ne pravi poziv u salonu B');
select throws_ok($$ select * from public.create_staff_invite('550e8400-e29b-41d4-a716-446655440000', 'super_admin', 'X') $$,
  'PT400', null, 'super_admin se pozivom ne dodjeljuje');
select throws_ok($$ select * from public.create_staff_invite('550e8400-e29b-41d4-a716-446655440000', 'employee', 'X',
  '20000000-0000-4000-8000-000000000003') $$,
  '42501', null, 'Radnik drugog salona se ne moze vezati za poziv');
select throws_ok($$ select * from public.peek_staff_invite('X') $$,
  '42501', null, 'authenticated ne zove peek_staff_invite');
select throws_ok($$ select * from public.accept_staff_invite('X', gen_random_uuid(), 'x@x.x') $$,
  '42501', null, 'authenticated ne zove accept_staff_invite');
select throws_ok($$ insert into public.staff_invites(salon_id, role, name, code_hash, expires_at, created_by)
  values ('550e8400-e29b-41d4-a716-446655440000', 'salon_admin', 'X', 'h', now(), auth.uid()) $$,
  '42501', null, 'Direktan upis u staff_invites je zabranjen');
reset role;
grant select on poziv, poziv_radnik to public;

select throws_ok($$ insert into public.staff_invites(salon_id, role, name, code_hash, expires_at, created_by)
  values ('550e8400-e29b-41d4-a716-446655440000', 'super_admin', 'X', 'h2', now(), 'fe000000-0000-4000-8000-000000000001') $$,
  '23514', null, 'Ni upis mimo RPC-a ne moze nositi super_admin');

select is((select code_hash from public.staff_invites where id = (select invite_id from poziv)),
  encode(digest((select code from poziv), 'sha256'), 'hex'), 'Baza cuva hash koda');
select isnt((select code_hash from public.staff_invites where id = (select invite_id from poziv)),
  (select code from poziv), 'Baza ne cuva sam kod');

set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select throws_ok($$ select * from public.create_staff_invite('550e8400-e29b-41d4-a716-446655440000', 'employee', 'X') $$,
  '42501', null, 'Klijent ne pravi poziv');
select is((select count(*)::int from public.staff_invites), 0, 'Klijent ne vidi pozive');
reset role;

set local role anon;
select throws_ok($$ select * from public.create_staff_invite('550e8400-e29b-41d4-a716-446655440000', 'employee', 'X') $$,
  '42501', null, 'anon ne pravi poziv');
reset role;

-- ---------------------------------------------------------------------------
-- 3. Izolacija citanja
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select is((select count(*)::int from public.staff_invites), 0, 'Admin B ne vidi pozive salona A');
select throws_ok(format($$ select public.revoke_staff_invite('550e8400-e29b-41d4-a716-446655440000', %L) $$,
  (select invite_id from poziv)), '42501', null, 'Admin B ne povlaci poziv salona A');
reset role;

set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select is((select count(*)::int from public.staff_invites), 2, 'Admin A vidi svoja dva poziva');
reset role;

-- ---------------------------------------------------------------------------
-- 4. Prihvatanje — service role
-- ---------------------------------------------------------------------------
-- `auth.users` red u produkciji pravi Edge Function kroz admin API; ovdje ga pravi test.
insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fe000000-0000-4000-8000-000000000010', 'novi@poziv45.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');

set local role service_role;
select is((select role::text from public.peek_staff_invite(lower((select code from poziv)))),
  'salon_admin', 'peek vraca ulogu iz poziva, i kod ne zavisi od velikih slova');
select is((public.accept_staff_invite((select code from poziv), 'fe000000-0000-4000-8000-000000000010',
    ' Novi@Poziv45.invalid ')).role::text,
  'salon_admin', 'Prihvatanje pravi public.users sa ulogom iz poziva');
select throws_ok(format($$ select public.accept_staff_invite(%L, gen_random_uuid(), 'x@x.x') $$, (select code from poziv)),
  'PT404', null, 'Isti kod radi samo jednom');
select is((select count(*)::int from public.peek_staff_invite((select code from poziv))), 0,
  'Iskoristen poziv peek vise ne vidi');
reset role;

select is((select salon_id from public.users where id = 'fe000000-0000-4000-8000-000000000010'),
  '550e8400-e29b-41d4-a716-446655440000'::uuid, 'Novi nalog pripada salonu iz poziva');
select is((select email from public.users where id = 'fe000000-0000-4000-8000-000000000010'),
  'novi@poziv45.invalid', 'Email je normalizovan');

-- Novi vlasnik stvarno ima prava: `is_admin` trazi i JWT i red, oboje sada stoji.
set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select ok(private.is_admin('550e8400-e29b-41d4-a716-446655440000'), 'Prihvaceni vlasnik je admin salona');
reset role;

-- Lista osoblja: admin vidi svoj salon, admin drugog salona dobija 42501.
set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select ok(exists(select 1 from public.list_staff_users('550e8400-e29b-41d4-a716-446655440000')
  where id = 'fe000000-0000-4000-8000-000000000010'), 'Admin vidi novog clana u listi osoblja');
select is((select count(*)::int from public.users), 1,
  'Direktno citanje public.users i dalje vraca samo vlastiti red (prijava ostaje ispravna)');
select throws_ok($$ select * from public.list_staff_users('550e8400-e29b-41d4-a716-446655440001') $$,
  '42501', null, 'Admin A ne lista osoblje salona B');
reset role;

-- Povucen i istekao poziv.
set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select lives_ok(format($$ select public.revoke_staff_invite('550e8400-e29b-41d4-a716-446655440000', %L) $$,
  (select invite_id from poziv_radnik)), 'Admin povlaci poziv');
select throws_ok(format($$ select public.revoke_staff_invite('550e8400-e29b-41d4-a716-446655440000', %L) $$,
  (select invite_id from poziv)), 'PT404', null, 'Iskoristen poziv se ne povlaci');
create temporary table poziv_istekao as
select * from public.create_staff_invite('550e8400-e29b-41d4-a716-446655440000', 'employee', 'Emir');
reset role;
grant select on poziv_istekao to public;
update public.staff_invites set expires_at = now() - interval '1 minute'
where id = (select invite_id from poziv_istekao);

set local role service_role;
select throws_ok(format($$ select public.accept_staff_invite(%L, gen_random_uuid(), 'x@x.x') $$, (select code from poziv_radnik)),
  'PT404', null, 'Povucen poziv se ne prihvata');
select throws_ok(format($$ select public.accept_staff_invite(%L, gen_random_uuid(), 'x@x.x') $$, (select code from poziv_istekao)),
  'PT404', null, 'Istekao poziv se ne prihvata');
reset role;

-- ---------------------------------------------------------------------------
-- 5. Uklanjanje
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select throws_ok($$ select public.remove_staff_user('550e8400-e29b-41d4-a716-446655440000', 'fe000000-0000-4000-8000-000000000010') $$,
  '42501', null, 'Admin B ne uklanja osoblje salona A');
reset role;

set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok($$ select public.remove_staff_user('550e8400-e29b-41d4-a716-446655440000', 'fe000000-0000-4000-8000-000000000001') $$,
  'PT400', null, 'Vlasnik ne uklanja sebe');
select lives_ok($$ select public.remove_staff_user('550e8400-e29b-41d4-a716-446655440000', 'fe000000-0000-4000-8000-000000000010') $$,
  'Vlasnik uklanja drugog clana osoblja');
reset role;

set local request.jwt.claims = '{"sub":"fe000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select ok(not private.is_admin('550e8400-e29b-41d4-a716-446655440000'),
  'Uklonjen nalog sa istim JWT-om vise nije admin');
select is((select count(*)::int from public.staff_invites), 0, 'Uklonjen nalog ne vidi ni pozive');
reset role;
select is((select accepted_user_id from public.staff_invites where id = (select invite_id from poziv)),
  'fe000000-0000-4000-8000-000000000010'::uuid, 'Istorija poziva ostaje');

select * from finish();
rollback;
