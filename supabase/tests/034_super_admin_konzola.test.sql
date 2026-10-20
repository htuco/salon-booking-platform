-- Platformski RPC-ovi lokalne super admin konzole. Task 72, ADR-0032.
--
-- Mjeri:
--   1. `platform_*` zove samo service_role; anon, klijent, admin salona i super admin iz JWT-a ne;
--   2. novi salon nastaje u jednoj transakciji (salons + salon_builds + salon_settings iz pack-a),
--      a pogrešan ili zauzet unos ne ostavlja ništa;
--   3. status, boje i tema, store status mijenjaju samo svoje polje i samo postojeći salon;
--   4. poziv vlasnika: `salon_admin`, `created_by = null`, kod radi kroz postojeće prihvatanje,
--      a za neaktivan salon se ne pravi.
begin;
set local search_path = public, extensions;
select no_plan();

-- Super admin sa claimom **i** redom u `users`: najjači nalog koji aplikacija može imati.
insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fe720000-0000-4000-8000-000000000001', 'super@konzola72.invalid', '{"role":"super_admin"}', '{}'),
('fe720000-0000-4000-8000-000000000002', 'vlasnik@konzola72.invalid', '{}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('fe720000-0000-4000-8000-000000000001', null, 'Super', 'super@konzola72.invalid', 'super_admin');

-- ---------------------------------------------------------------------------
-- 1. Ko smije zvati
-- ---------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.platform_list_salons()', 'execute'),
  'anon nema execute na platform_list_salons');
select ok(not has_function_privilege('authenticated', 'public.platform_list_salons()', 'execute'),
  'authenticated nema execute na platform_list_salons');
select ok(not has_function_privilege('authenticated',
  'public.platform_create_salon(text,text,text,text,text,text,text,text,text,text,text,public.salon_plan)', 'execute'),
  'authenticated nema execute na platform_create_salon');
select ok(not has_function_privilege('authenticated', 'public.platform_set_salon_status(uuid,public.salon_status)', 'execute'),
  'authenticated nema execute na platform_set_salon_status');
select ok(not has_function_privilege('authenticated', 'public.platform_set_branding(uuid,text,text,text)', 'execute'),
  'authenticated nema execute na platform_set_branding');
select ok(not has_function_privilege('authenticated', 'public.platform_set_store_status(uuid,text,public.store_status)', 'execute'),
  'authenticated nema execute na platform_set_store_status');
select ok(not has_function_privilege('authenticated', 'public.platform_create_owner_invite(uuid,text)', 'execute'),
  'authenticated nema execute na platform_create_owner_invite');
select ok(not has_function_privilege('anon', 'public.platform_create_owner_invite(uuid,text)', 'execute'),
  'anon nema execute na platform_create_owner_invite');
select ok(has_function_privilege('service_role', 'public.platform_create_owner_invite(uuid,text)', 'execute'),
  'service_role ima execute na platform_create_owner_invite');

set local request.jwt.claims = '{"sub":"fe720000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"super_admin"}}';
set local role authenticated;
select ok(private.is_super_admin(), 'Fixture: nalog je pravi super admin');
select throws_ok($$ select public.platform_create_salon('X', 'x', 'Vitez', 'barber', null,
  '#111111', '#222222', 'x', 'ba.nasadomena.x', 'ba.nasadomena.x', 'X') $$,
  '42501', null, 'Super admin iz aplikacije ne pravi salon');
select throws_ok($$ select * from public.platform_list_salons() $$,
  '42501', null, 'Super admin iz aplikacije ne vidi platformsku listu');
select throws_ok($$ select * from public.platform_create_owner_invite('550e8400-e29b-41d4-a716-446655440000', 'X') $$,
  '42501', null, 'Super admin iz aplikacije ne pravi poziv vlasnika');
reset role;

set local request.jwt.claims = '{"sub":"11111111-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok($$ select public.platform_set_salon_status('550e8400-e29b-41d4-a716-446655440001', 'inactive') $$,
  '42501', null, 'Admin salona A ne gasi salon B');
select throws_ok($$ select public.platform_set_branding('550e8400-e29b-41d4-a716-446655440000', 'modern_barber', '#000000', '#FFFFFF') $$,
  '42501', null, 'Admin salona ni svoje boje ne mijenja kroz platformski RPC');
reset role;

set local role anon;
select throws_ok($$ select public.platform_set_store_status('550e8400-e29b-41d4-a716-446655440000', 'play', 'live') $$,
  '42501', null, 'anon ne mijenja store status');
reset role;

-- ---------------------------------------------------------------------------
-- 2. Novi salon
-- ---------------------------------------------------------------------------
set local role service_role;
create temporary table novi as
select public.platform_create_salon('Studio Zdravlje', 'studio-zdravlje', ' Zenica ', 'health', null,
  '#3a5a40', '#a3b18a', 'studiozdravlje', 'ba.nasadomena.studiozdravlje',
  'ba.nasadomena.studiozdravlje', 'Studio Zdravlje') as id;
reset role;

select is((select count(*)::int from public.salons where id = (select id from novi)), 1, 'Salon je upisan');
select is((select row(status::text, city, theme, primary_color, secondary_color, vertical_pack_key, plan::text)::text
  from public.salons where id = (select id from novi)),
  row('active', 'Zenica', 'clinical_calm', '#3A5A40', '#A3B18A', 'health', 'starter')::text,
  'Salon je aktivan, grad očišćen, tema iz pack-a, boje velikim slovima');
select is((select row(flavor, application_id, bundle_id, app_display_name, play_store_status::text, app_store_status::text)::text
  from public.salon_builds where salon_id = (select id from novi)),
  row('studiozdravlje', 'ba.nasadomena.studiozdravlje', 'ba.nasadomena.studiozdravlje', 'Studio Zdravlje', 'draft', 'draft')::text,
  'Build red nosi flavor, ID-eve i draft u oba storea');
select is((select row(slot_step_minutes, buffer_minutes, min_advance_booking_hours, max_advance_booking_days,
  pending_expiry_hours, min_cancel_hours)::text
  from public.salon_settings where salon_id = (select id from novi)),
  (select row(
    (default_settings->>'slotStepMinutes')::int, (default_settings->>'bufferMinutes')::int,
    (default_settings->>'minAdvanceBookingHours')::int, (default_settings->>'maxAdvanceBookingDays')::int,
    (default_settings->>'pendingExpiryHours')::int, (default_settings->>'minCancelHours')::int)::text
   from public.vertical_packs where key = 'health'),
  'Postavke salona su početne vrijednosti vertikale');
select is((select count(*)::int from public.availability_signals where salon_id = (select id from novi)), 1,
  'Novi salon ima availability signal (klijent ga može pratiti)');

set local role service_role;
select is((select row(name, flavor, admin_count, open_owner_invites)::text
  from public.platform_list_salons() where id = (select id from novi)),
  row('Studio Zdravlje'::text, 'studiozdravlje'::text, 0, 0)::text,
  'Lista pokazuje novi salon bez vlasnika i bez poziva');
select ok((select count(*) from public.platform_list_salons()) >= 3, 'Lista vidi sve salone, i demo');

select throws_ok($$ select public.platform_create_salon('X', 'novi-x', 'Vitez', 'barber', null,
  '#111111', '#222222', 'novi-x', 'ba.nasadomena.novix', 'ba.nasadomena.novix', 'X') $$,
  'PT400', null, 'Flavor sa crticom pada');
select throws_ok($$ select public.platform_create_salon('X', 'Novi X', 'Vitez', 'barber', null,
  '#111111', '#222222', 'novix', 'ba.nasadomena.novix', 'ba.nasadomena.novix', 'X') $$,
  'PT400', null, 'Slug sa razmakom i velikim slovom pada');
select throws_ok($$ select public.platform_create_salon('X', 'novi-x', 'Vitez', 'barber', null,
  'zlatna', '#222222', 'novix', 'ba.nasadomena.novix', 'ba.nasadomena.novix', 'X') $$,
  'PT400', null, 'Boja koja nije #RRGGBB pada');
select throws_ok($$ select public.platform_create_salon('X', 'novi-x', 'Vitez', 'barber', 'neon',
  '#111111', '#222222', 'novix', 'ba.nasadomena.novix', 'ba.nasadomena.novix', 'X') $$,
  'PT400', null, 'Nepoznata tema pada');
select throws_ok($$ select public.platform_create_salon('X', 'novi-x', 'Vitez', 'vet', null,
  '#111111', '#222222', 'novix', 'ba.nasadomena.novix', 'ba.nasadomena.novix', 'X') $$,
  'PT400', null, 'Nepoznata vertikala pada');
select throws_ok($$ select public.platform_create_salon('X', 'novi-x', 'Vitez', 'barber', null,
  '#111111', '#222222', 'novix', 'Ba.Nasadomena', 'ba.nasadomena.novix', 'X') $$,
  'PT400', null, 'Android ID sa velikim slovima i bez dva segmenta pada');
select throws_ok($$ select public.platform_create_salon('  ', 'novi-x', 'Vitez', 'barber', null,
  '#111111', '#222222', 'novix', 'ba.nasadomena.novix', 'ba.nasadomena.novix', 'X') $$,
  'PT400', null, 'Prazan naziv pada');
select throws_ok($$ select public.platform_create_salon('X', 'studio-zdravlje', 'Vitez', 'barber', null,
  '#111111', '#222222', 'novix', 'ba.nasadomena.novix', 'ba.nasadomena.novix', 'X') $$,
  'PT409', 'Slug je zauzet', 'Zauzet slug je PT409');
select throws_ok($$ select public.platform_create_salon('X', 'novi-x', 'Vitez', 'barber', null,
  '#111111', '#222222', 'studiozdravlje', 'ba.nasadomena.novix', 'ba.nasadomena.novix', 'X') $$,
  'PT409', 'Flavor je zauzet', 'Zauzet flavor je PT409');
select throws_ok($$ select public.platform_create_salon('X', 'novi-x', 'Vitez', 'barber', null,
  '#111111', '#222222', 'novix', 'ba.nasadomena.studiozdravlje', 'ba.nasadomena.novix', 'X') $$,
  'PT409', 'ID aplikacije je zauzet', 'Zauzet Android ID je PT409');
reset role;
select is((select count(*)::int from public.salons where slug = 'novi-x'), 0,
  'Nijedan odbijen unos nije ostavio salon');

-- ---------------------------------------------------------------------------
-- 3. Status, boje i tema, store
-- ---------------------------------------------------------------------------
set local role service_role;
select lives_ok($$ select public.platform_set_branding((select id from novi), 'warm_wellness', '#8a5a44', '#f2e8dc') $$,
  'Boje i tema se mijenjaju');
select throws_ok($$ select public.platform_set_branding((select id from novi), 'neon', '#8a5a44', '#f2e8dc') $$,
  'PT400', null, 'Nepoznata tema se ne upisuje');
select throws_ok($$ select public.platform_set_branding(gen_random_uuid(), 'warm_wellness', '#8a5a44', '#f2e8dc') $$,
  'PT404', null, 'Nepostojeći salon je PT404');
select lives_ok($$ select public.platform_set_store_status((select id from novi), 'play', 'in_review') $$,
  'Play status prelazi u in_review');
select throws_ok($$ select public.platform_set_store_status((select id from novi), 'huawei', 'live') $$,
  'PT400', null, 'Nepoznat store pada');
select throws_ok($$ select public.platform_set_store_status(gen_random_uuid(), 'app', 'live') $$,
  'PT404', null, 'Salon bez build reda je PT404');
reset role;
select is((select row(theme, primary_color, secondary_color)::text from public.salons where id = (select id from novi)),
  row('warm_wellness', '#8A5A44', '#F2E8DC')::text, 'Baza nosi nove boje i temu');
select is((select row(play_store_status::text, app_store_status::text)::text from public.salon_builds
  where salon_id = (select id from novi)), row('in_review', 'draft')::text, 'Play se promijenio, App Store nije');

set local role service_role;
select lives_ok($$ select public.platform_set_salon_status((select id from novi), 'inactive') $$, 'Salon se gasi');
select throws_ok($$ select * from public.platform_create_owner_invite((select id from novi), 'Vlasnik') $$,
  'PT409', 'Salon nije aktivan', 'Za neaktivan salon nema poziva');
reset role;
select ok(not private.salon_active((select id from novi)), 'Ugašen salon nije aktivan');
set local role anon;
select is((select count(*)::int from public.salons where slug = 'studio-zdravlje'), 0, 'anon ne vidi ugašen salon');
reset role;

set local role service_role;
select lives_ok($$ select public.platform_set_salon_status((select id from novi), 'active') $$, 'Salon se pali');
select throws_ok($$ select public.platform_set_salon_status(gen_random_uuid(), 'active') $$,
  'PT404', null, 'Nepostojeći salon se ne pali');

-- ---------------------------------------------------------------------------
-- 4. Poziv vlasnika
-- ---------------------------------------------------------------------------
create temporary table poziv as
select * from public.platform_create_owner_invite((select id from novi), ' Elma Hodžić ');
select throws_ok($$ select * from public.platform_create_owner_invite((select id from novi), ' ') $$,
  'PT400', null, 'Poziv bez imena pada');
select throws_ok($$ select * from public.platform_create_owner_invite(gen_random_uuid(), 'X') $$,
  'PT404', null, 'Poziv za nepostojeći salon pada');
select is((select length(code) from poziv), 10, 'Kod ima 10 znakova');
select is((select open_owner_invites from public.platform_list_salons() where id = (select id from novi)), 1,
  'Lista pokazuje otvoren poziv vlasnika');
select is((select row(role::text, name, created_by)::text from public.staff_invites where id = (select invite_id from poziv)),
  row('salon_admin', 'Elma Hodžić', null::uuid)::text, 'Poziv je salon_admin, ime očišćeno, created_by = platforma');
select is((select code_hash from public.staff_invites where id = (select invite_id from poziv)),
  encode(digest((select code from poziv), 'sha256'), 'hex'), 'Baza čuva hash koda, ne kod');
select is((select row(salon_id, role::text)::text from public.peek_staff_invite((select code from poziv))),
  (select row(id, 'salon_admin')::text from novi), 'Postojeći peek vidi poziv platforme');
select is((select row(salon_id, role::text)::text from public.accept_staff_invite((select code from poziv),
  'fe720000-0000-4000-8000-000000000002', 'Vlasnik@Konzola72.invalid')),
  (select row(id, 'salon_admin')::text from novi), 'Postojeće prihvatanje pravi vlasnika novog salona');
select is((select row(admin_count, open_owner_invites)::text from public.platform_list_salons() where id = (select id from novi)),
  row(1, 0)::text, 'Lista: jedan vlasnik, nijedan otvoren poziv');
reset role;

select * from finish();
rollback;
