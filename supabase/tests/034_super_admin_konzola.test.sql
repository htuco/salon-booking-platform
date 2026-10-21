-- Platformski RPC-ovi lokalne super admin konzole. Task 72, ADR-0032.
--
-- Mjeri:
--   1. `platform_*` zove samo service_role; anon, klijent, admin salona i super admin iz JWT-a ne;
--   2. novi salon nastaje u jednoj transakciji (salons + salon_builds + salon_settings iz pack-a),
--      a pogrešan ili zauzet unos ne ostavlja ništa;
--   3. status, boje i tema, store status mijenjaju samo svoje polje i samo postojeći salon;
--   4. poziv vlasnika: `salon_admin`, `created_by = null`, kod radi kroz postojeće prihvatanje,
--      a za neaktivan salon se ne pravi; novi poziv platforme povlači prethodni, a povučen kod
--      više ne radi;
--   5. UUID po okruženju: `p_id` daje salonu UUID iz `tenant.yaml`-a, zauzet UUID je PT409;
--   6. rezervisan flavor (`test*`, `lint`...) i kontrolni znakovi u nazivu, gradu i imenu
--      aplikacije ne prolaze, ni kroz `update_salon_contact`.
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
  'public.platform_create_salon(text,text,text,text,text,text,text,text,text,text,text,public.salon_plan,uuid)', 'execute'),
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
select ok(not has_function_privilege('authenticated', 'public.platform_revoke_owner_invite(uuid,uuid)', 'execute'),
  'authenticated nema execute na platform_revoke_owner_invite');
select ok(not has_function_privilege('anon', 'public.platform_revoke_owner_invite(uuid,uuid)', 'execute'),
  'anon nema execute na platform_revoke_owner_invite');
select ok(has_function_privilege('service_role', 'public.platform_revoke_owner_invite(uuid,uuid)', 'execute'),
  'service_role ima execute na platform_revoke_owner_invite');

-- Katalog, ne lista: hvata i svaku buduću `platform_*` funkciju kojoj neko zaboravi revoke.
-- Broj drži da test ne prođe prazan (preimenovana šema, pogrešan filter).
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname like 'platform\_%'), 8,
  'Tačno osam public.platform_* funkcija');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname like 'platform\_%'
    and (has_function_privilege('anon', p.oid, 'execute')
      or has_function_privilege('authenticated', p.oid, 'execute'))), 0,
  'Nijedna platform_* funkcija nema execute za anon ni authenticated');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname like 'platform\_%'
    and has_function_privilege('service_role', p.oid, 'execute')), 8,
  'service_role ima execute na svih osam');

-- Pomoćne funkcije: generator koda se ne zove iz aplikacije.
select ok(not has_function_privilege('authenticated', 'private.new_invite_code()', 'execute'),
  'authenticated nema execute na private.new_invite_code');
select ok(not has_function_privilege('anon', 'private.new_invite_code()', 'execute'),
  'anon nema execute na private.new_invite_code');
-- `create or replace` u ovoj migraciji ne smije promijeniti ko zove `create_staff_invite`.
select ok(has_function_privilege('authenticated', 'public.create_staff_invite(uuid,public.staff_role,text,uuid)', 'execute'),
  'create_staff_invite i dalje zove authenticated (admin salona)');
select ok(not has_function_privilege('anon', 'public.create_staff_invite(uuid,public.staff_role,text,uuid)', 'execute'),
  'create_staff_invite i dalje ne zove anon');

set local request.jwt.claims = '{"sub":"fe720000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"super_admin"}}';
set local role authenticated;
select ok(private.is_super_admin(), 'Fixture: nalog je pravi super admin');
select throws_ok($$ select public.platform_create_salon('X', 'x', 'Vitez', 'barber', null,
  '#111111', '#222222', 'x', 'ba.nasadomena.x', 'ba.nasadomena.x', 'X') $$,
  '42501', null, 'Super admin iz aplikacije ne pravi salon');
select throws_ok($$ select * from public.platform_list_salons() $$,
  '42501', null, 'Super admin iz aplikacije ne vidi platformsku listu');
select throws_ok($$ select * from public.platform_create_owner_invite('550e8400-e29b-41d4-a716-446655440000', 'X') $$,
  '42501', null, 'Super admin iz aplikacije ne pravi poziv vlasnika kroz platform_create_owner_invite');
-- **Poznata rupa, ne zatvara se u tasku 72** (security.md §„Šta još nije zatvoreno"):
-- `create_staff_invite` provjerava `private.is_admin`, a on počinje sa `is_super_admin()`.
-- Kad se rupa zatvori, ova asercija pada i mijenja se u `throws_ok`.
select lives_ok($$ select * from public.create_staff_invite('550e8400-e29b-41d4-a716-446655440000', 'salon_admin', 'X') $$,
  'Poznata rupa: super admin iz aplikacije pravi poziv vlasnika kroz create_staff_invite');
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

-- Rezervisan flavor: `[a-z][a-z0-9]*` ga pušta, a Gradle ruši sync svih tenanata.
set local role service_role;
select throws_ok($$ select public.platform_create_salon('Test Salon', 'test-salon', 'Vitez', 'barber', null,
  '#111111', '#222222', 'testsalon', 'ba.nasadomena.testsalon', 'ba.nasadomena.testsalon', 'Test Salon') $$,
  'PT400', null, 'Flavor koji počinje sa test pada');
select throws_ok($$ select public.platform_create_salon('Lint', 'lint', 'Vitez', 'barber', null,
  '#111111', '#222222', 'lint', 'ba.nasadomena.lint', 'ba.nasadomena.lint', 'Lint') $$,
  'PT400', null, 'Flavor lint pada');
select throws_ok($$ select public.platform_create_salon('Release', 'release', 'Vitez', 'barber', null,
  '#111111', '#222222', 'release', 'ba.nasadomena.release', 'ba.nasadomena.release', 'Release') $$,
  'PT400', null, 'Flavor sa imenom build tipa pada');
reset role;
select ok(not private.is_reserved_flavor('kontest') and not private.is_reserved_flavor('tefter'),
  'test usred ili samo te na početku nije rezervisano');

-- Kontrolni znakovi: naziv i grad idu u komentar `tenant.yaml`-a, prelom bi ubacio ključ.
set local role service_role;
select throws_ok($$ select public.platform_create_salon(E'X\nprimaryColor: "#000000"', 'novi-x', 'Vitez', 'barber', null,
  '#111111', '#222222', 'novix', 'ba.nasadomena.novix', 'ba.nasadomena.novix', 'X') $$,
  'PT400', null, 'Prelom reda u nazivu pada');
select throws_ok($$ select public.platform_create_salon('X', 'novi-x', E'Vitez\ttheme: x', 'barber', null,
  '#111111', '#222222', 'novix', 'ba.nasadomena.novix', 'ba.nasadomena.novix', 'X') $$,
  'PT400', null, 'Tab u gradu pada');
select throws_ok($$ select public.platform_create_salon('X', 'novi-x', 'Vitez', 'barber', null,
  '#111111', '#222222', 'novix', 'ba.nasadomena.novix', 'ba.nasadomena.novix', E'X\rY') $$,
  'PT400', null, 'CR u imenu aplikacije pada');
reset role;

-- ---------------------------------------------------------------------------
-- 5. UUID po okruženju (`p_id`)
-- ---------------------------------------------------------------------------
set local role service_role;
select is(public.platform_create_salon('Sa Fajla', 'sa-fajla', 'Mostar', 'barber', null,
  '#111111', '#222222', 'safajla', 'ba.nasadomena.safajla', 'ba.nasadomena.safajla', 'Sa Fajla',
  'starter', 'fe720000-0000-4000-8000-0000000000aa'),
  'fe720000-0000-4000-8000-0000000000aa'::uuid, 'Dat UUID je UUID salona');
select throws_ok($$ select public.platform_create_salon('Drugi', 'drugi-salon', 'Mostar', 'barber', null,
  '#111111', '#222222', 'drugisalon', 'ba.nasadomena.drugisalon', 'ba.nasadomena.drugisalon', 'Drugi',
  'starter', '550e8400-e29b-41d4-a716-446655440000') $$,
  'PT409', 'Salon sa ovim UUID-om već postoji u ovoj bazi', 'Zauzet UUID je PT409');
select throws_ok($$ select public.platform_create_salon('Drugi', 'drugi-salon', 'Mostar', 'barber', null,
  '#111111', '#222222', 'drugisalon', 'ba.nasadomena.drugisalon', 'ba.nasadomena.drugisalon', 'Drugi',
  'starter', '00000000-0000-0000-0000-000000000000') $$,
  'PT400', null, 'UUID iz šablona pada');
reset role;
select is((select row(s.slug, b.flavor)::text from public.salons s join public.salon_builds b on b.salon_id = s.id
  where s.id = 'fe720000-0000-4000-8000-0000000000aa'), row('sa-fajla', 'safajla')::text,
  'Salon sa datim UUID-om ima i build red');
select is((select count(*)::int from public.salons where slug = 'drugi-salon'), 0,
  'Odbijen UUID nije ostavio salon');

-- Grad iz Melure: ista zabrana kroz `update_salon_contact`.
insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fe720000-0000-4000-8000-000000000003', 'vlasnik-a@konzola72.invalid',
  '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('fe720000-0000-4000-8000-000000000003', '550e8400-e29b-41d4-a716-446655440000', 'Vlasnik A',
  'vlasnik-a@konzola72.invalid', 'salon_admin');
set local request.jwt.claims = '{"sub":"fe720000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok($$ select public.update_salon_contact('550e8400-e29b-41d4-a716-446655440000',
  (select name from public.salons where id = '550e8400-e29b-41d4-a716-446655440000'), 'Adresa', E'Vitez\n# x') $$,
  'PT400', null, 'Vlasnik ne upisuje prelom reda u grad');
select lives_ok($$ select public.update_salon_contact('550e8400-e29b-41d4-a716-446655440000',
  (select name from public.salons where id = '550e8400-e29b-41d4-a716-446655440000'), 'Adresa', ' Vitez ') $$,
  'Običan grad i dalje prolazi');
reset role;

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
-- Poziv koji je napravio salon (`created_by` nije null): poziv platforme ga ne povlači.
reset role;
insert into public.staff_invites(id, salon_id, role, name, code_hash, expires_at, created_by)
values ('fe720000-0000-4000-8000-0000000000b1', (select id from novi), 'salon_admin', 'Salonski',
  'fe72-salonski-hash', now() + interval '7 days', 'fe720000-0000-4000-8000-000000000001');
set local role service_role;

-- Poziv platforme drugog salona: pozivi za `novi` ga ne smiju povući ni pokazati u svom redu.
create temporary table tudji as
select * from public.platform_create_owner_invite('550e8400-e29b-41d4-a716-446655440000', 'Vlasnik A');
create temporary table prvi as
select * from public.platform_create_owner_invite((select id from novi), 'Prvi');
create temporary table drugi as
select * from public.platform_create_owner_invite((select id from novi), 'Drugi');
select is((select count(*)::int from public.peek_staff_invite((select code from tudji))), 1,
  'Poziv platforme drugog salona ostaje otvoren');
select is((select platform_invite_id from public.platform_list_salons()
  where id = '550e8400-e29b-41d4-a716-446655440000'),
  (select invite_id from tudji), 'Lista pokazuje poziv drugog salona u njegovom redu');
select is((select count(*)::int from public.peek_staff_invite((select code from prvi))), 0,
  'Novi poziv platforme povlači prethodni: stari kod više ne radi');
select is((select count(*)::int from public.peek_staff_invite((select code from drugi))), 1,
  'Novi kod radi');
select is((select platform_invite_id from public.platform_list_salons() where id = (select id from novi)),
  (select invite_id from drugi), 'Lista pokazuje zadnji poziv platforme');
reset role;
select ok((select revoked_at is null from public.staff_invites where id = 'fe720000-0000-4000-8000-0000000000b1'),
  'Poziv koji je napravio salon ostaje otvoren');
set local role service_role;

select throws_ok($$ select public.platform_revoke_owner_invite((select id from novi), 'fe720000-0000-4000-8000-0000000000b1') $$,
  'PT404', null, 'Platforma ne povlači poziv koji je napravio salon');
select throws_ok($$ select public.platform_revoke_owner_invite('550e8400-e29b-41d4-a716-446655440000', (select invite_id from drugi)) $$,
  'PT404', null, 'Poziv se ne povlači preko tuđeg salona');
select lives_ok($$ select public.platform_revoke_owner_invite((select id from novi), (select invite_id from drugi)) $$,
  'Poziv platforme se povlači');
select is((select count(*)::int from public.peek_staff_invite((select code from drugi))), 0,
  'Povučen kod više ne radi');
select throws_ok($$ select public.platform_revoke_owner_invite((select id from novi), (select invite_id from drugi)) $$,
  'PT404', null, 'Već povučen poziv je PT404');
select is((select platform_invite_id from public.platform_list_salons() where id = (select id from novi)),
  null::uuid, 'Lista više ne pokazuje poziv platforme');
select throws_ok($$ select * from public.platform_create_owner_invite((select id from novi), E'Elma\nX') $$,
  'PT400', null, 'Prelom reda u imenu vlasnika pada');
reset role;
-- Salonski poziv se čisti, da brojač ispod mjeri samo poziv platforme.
update public.staff_invites set revoked_at = now() where id = 'fe720000-0000-4000-8000-0000000000b1';
set local role service_role;

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
