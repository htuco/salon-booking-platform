-- Pisanje recenzija. Task 67.
--
-- Granice koje se ovdje dokazuju:
--   1. recenzija nastaje samo za **svoj zavrsen** termin, u salonu iz `x-salon-id`, i samo
--      jednom; ime autora daje baza;
--   2. salon recenziju sakriva i vraca, ali je **ne mijenja** — ni tekst ni ocjenu;
--   3. sakrivena recenzija ne ulazi u prosjek ni za koga, a klijent i dalje vidi svoju;
--   4. prijava recenzije ide platformi, ne salonu;
--   5. zavrsen termin javlja klijentu `review_request`;
--   6. brisanje naloga ostavlja ocjenu, a brise ime i tekst.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table fix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as salon_b,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak;
grant select on fix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fe670000-0000-4000-8000-000000000001', 'ana@rec67.invalid', '{"providers":["email"]}',
 '{"full_name":"Ana Anić Kovač"}'),
('fe670000-0000-4000-8000-000000000003', 'bob@rec67.invalid', '{"providers":["email"]}',
 '{"full_name":"Bob"}'),
('fe670000-0000-4000-8000-000000000002', 'vlasnik-a@rec67.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('fe670000-0000-4000-8000-000000000004', 'vlasnik-b@rec67.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('fe670000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik A', 'vlasnik-a@rec67.invalid', 'salon_admin'),
('fe670000-0000-4000-8000-000000000004', '550e8400-e29b-41d4-a716-446655440001',
 'Vlasnik B', 'vlasnik-b@rec67.invalid', 'salon_admin');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- Ana: uredjaj i dva termina u salonu A.
set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table ana_tel as select public.register_device((select salon from fix),
  'fe670000-0000-4000-8000-0000000000a1', repeat('a', 64), 'android', 'ana-tel') as id;
create temporary table ana as select (public.ensure_customer((select salon from fix))).id as customer_id;
create temporary table ana_t1 as select (public.book_appointment((select salon from fix),
  (select customer_id from ana), (select usluga from fix), (select utorak from fix), '09:00',
  (select emir from fix), null, (select id from ana_tel))).id as id;
create temporary table ana_t2 as select (public.book_appointment((select salon from fix),
  (select customer_id from ana), (select usluga from fix), (select utorak from fix), '10:00',
  (select emir from fix), null, (select id from ana_tel))).id as id;
reset role;
grant select on ana_tel, ana, ana_t1, ana_t2 to public;

-- Prvi termin je zavrsen, drugi samo potvrdjen.
update public.appointments set status = 'completed', pending_expires_at = null
where id = (select id from ana_t1);
update public.appointments set status = 'confirmed', pending_expires_at = null
where id = (select id from ana_t2);

-- ---------------------------------------------------------------------------
-- Push poslije termina
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from public.notification_logs
   where appointment_id = (select id from ana_t1) and type = 'review_request'
     and device_id = (select id from ana_tel)),
  1, 'Zavrsen termin javlja klijentu review_request na uredjaj termina');
select is(
  (select count(*)::int from public.notification_logs
   where appointment_id = (select id from ana_t2) and type = 'review_request'),
  0, 'Potvrdjen termin ne trazi ocjenu');

-- Status nazad pa ponovo zavrsen: i dalje jedna poruka.
update public.appointments set status = 'no_show' where id = (select id from ana_t1);
update public.appointments set status = 'completed' where id = (select id from ana_t1);
select is(
  (select count(*)::int from public.notification_logs
   where appointment_id = (select id from ana_t1) and type = 'review_request'),
  1, 'Ponovo zavrsen termin ne salje drugu molbu za ocjenu');

-- ---------------------------------------------------------------------------
-- Klijent pise
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;

select throws_ok(
  format($$select public.submit_review(%L, 5, 'Odlično')$$, (select id from ana_t2)),
  'PT400', null, 'Termin koji nije zavrsen ne moze se ocijeniti');
select throws_ok(
  format($$select public.submit_review(%L, 6)$$, (select id from ana_t1)),
  'PT400', 'Ocjena je od 1 do 5', 'Ocjena 6 je odbijena');
select throws_ok(
  format($$select public.submit_review(%L, 0)$$, (select id from ana_t1)),
  'PT400', 'Ocjena je od 1 do 5', 'Ocjena 0 je odbijena');
select throws_ok(
  format($$select public.submit_review(%L, 5, %L)$$, (select id from ana_t1), repeat('x', 1001)),
  'PT400', 'Tekst je predug', 'Tekst preko 1000 znakova je odbijen');
select throws_ok(
  $$insert into public.reviews(salon_id, author_name, rating) values ('550e8400-e29b-41d4-a716-446655440000', 'Ana', 5)$$,
  '42501', null, 'Klijent ne pise u tabelu direktno');

create temporary table ana_rec as
select public.submit_review((select id from ana_t1), 5, '  Odlično šišanje.  ') as id;
grant select on ana_rec to public;

select results_eq(
  format($$select author_name, rating, comment, appointment_id, is_published from public.reviews where id = %L$$,
    (select id from ana_rec)),
  format($$values ('Ana K.'::text, 5, 'Odlično šišanje.'::text, %L::uuid, true)$$, (select id from ana_t1)),
  'Recenzija nosi ime iz identiteta („Ana K."), ocjenu, ociscen tekst i termin');
select is(
  (select r.auth_identity_id from public.reviews r where r.id = (select id from ana_rec)),
  (select a.auth_identity_id from public.appointments a where a.id = (select id from ana_t1)),
  'Identitet recenzije je identitet termina');

select throws_ok(
  format($$select public.submit_review(%L, 1, 'Ipak ne')$$, (select id from ana_t1)),
  'PT409', null, 'Druga recenzija za isti termin pada');
select is(
  (select rating from public.reviews where id = (select id from ana_rec)), 5,
  'Prva recenzija nije prepisana');

-- Bez headera i sa tudjim salonom u headeru: ista greska.
set local request.headers = '{}';
select throws_ok(
  format($$select public.submit_review(%L, 4)$$, (select id from ana_t2)),
  '42501', null, 'Bez x-salon-id nema recenzije');
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select throws_ok(
  format($$select public.submit_review(%L, 4)$$, (select id from ana_t2)),
  '42501', null, 'Termin salona A se ne ocjenjuje iz konteksta salona B');
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
reset role;

-- Bob ne ocjenjuje Anin termin, ni kad je zavrsen.
update public.appointments set status = 'completed' where id = (select id from ana_t2);
set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select throws_ok(
  format($$select public.submit_review(%L, 1, 'Lose')$$, (select id from ana_t2)),
  '42501', null, 'Tudji zavrsen termin se ne ocjenjuje');
reset role;

-- Anon nema execute.
set local role anon;
select throws_ok(
  format($$select public.submit_review(%L, 5)$$, (select id from ana_t2)),
  '42501', null, 'Anon ne poziva submit_review');
reset role;

-- Osoblje nije klijent.
set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok(
  format($$select public.submit_review(%L, 5)$$, (select id from ana_t2)),
  '42501', null, 'Vlasnik ne pise recenziju svom salonu');

-- ---------------------------------------------------------------------------
-- Salon sakriva, ne mijenja
-- ---------------------------------------------------------------------------
select throws_ok(
  format($$update public.reviews set comment = 'Najbolji salon' where id = %L$$, (select id from ana_rec)),
  '42501', null, 'Vlasnik ne mijenja tekst recenzije');
select throws_ok(
  format($$delete from public.reviews where id = %L$$, (select id from ana_rec)),
  '42501', null, 'Vlasnik ne brise recenziju');
select throws_ok(
  $$insert into public.reviews(salon_id, author_name, rating) values ('550e8400-e29b-41d4-a716-446655440000', 'Lazni klijent', 5)$$,
  '42501', null, 'Vlasnik ne pise lazne recenzije');

select lives_ok(
  format($$select public.set_review_published(%L, false)$$, (select id from ana_rec)),
  'Vlasnik sakriva recenziju svog salona');
reset role;
select results_eq(
  format($$select is_published, comment, rating from public.reviews where id = %L$$, (select id from ana_rec)),
  $$values (false, 'Odlično šišanje.'::text, 5)$$,
  'Sakrivanje dira samo is_published');

set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select is(
  (select count(*)::int from public.reviews where id = (select id from ana_rec)), 1,
  'Vlasnik i dalje vidi sakrivenu recenziju');
-- Seed: 25 objavljenih (prosjek 4.8) + 1 sakrivena jedinica. Anina petica je sakrivena.
select is(
  (select average from public.salon_rating_summary where salon_id = (select salon from fix)),
  4.8::numeric, 'Vlasnik vidi javni prosjek — sakrivene ne ulaze');
reset role;

set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select throws_ok(
  format($$select public.set_review_published(%L, true)$$, (select id from ana_rec)),
  '42501', null, 'Vlasnik B ne vraca recenziju salona A');
select throws_ok(
  $$select public.set_review_published('00000000-0000-4000-8000-000000000000', true)$$,
  '42501', null, 'Nepostojeca recenzija daje istu gresku');
reset role;

set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select throws_ok(
  format($$select public.set_review_published(%L, true)$$, (select id from ana_rec)),
  '42501', null, 'Klijent ne vraca sakrivenu recenziju');
select is(
  (select count(*)::int from public.reviews where id = (select id from ana_rec)), 0,
  'Drugi klijent ne vidi tudju sakrivenu recenziju');
reset role;

-- Ana vidi svoju i kad je sakrivena — „Moji termini" po njoj zna da je termin ocijenjen.
set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select is(
  (select count(*)::int from public.reviews where id = (select id from ana_rec)), 1,
  'Klijent vidi svoju sakrivenu recenziju');
select is(
  (select average from public.salon_rating_summary where salon_id = (select salon from fix)),
  4.8::numeric, 'Svoja sakrivena recenzija ne ulazi ni u klijentov prosjek');
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select is(
  (select count(*)::int from public.reviews where id = (select id from ana_rec)), 0,
  'Iz konteksta salona B klijent ne vidi svoju sakrivenu recenziju salona A');
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
reset role;

set local role anon;
select is(
  (select count(*)::int from public.reviews where id = (select id from ana_rec)), 0,
  'Anon ne vidi sakrivenu recenziju');
reset role;

-- Vraceno: ulazi u prosjek. 25 x 4.8 = 120 + 5 = 125 / 26 = 4.807... -> 4.8; total je mjera.
set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select public.set_review_published((select id from ana_rec), true);
reset role;
set local role anon;
select is(
  (select total from public.salon_rating_summary where salon_id = (select salon from fix)),
  26, 'Vracena recenzija ulazi u javni broj ocjena');
reset role;

-- ---------------------------------------------------------------------------
-- Prijava recenzije
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table prijava as
select public.report_review((select id from ana_rec), 'Uvredljivo') as id;
select is(
  public.report_review((select id from ana_rec), 'Opet'), (select id from prijava),
  'Ponovljena prijava iste recenzije vraca postojeci id');
select is((select count(*)::int from public.content_reports), 0,
  'Klijent ne cita ni svoju prijavu');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select throws_ok(
  format($$select public.report_review(%L)$$, (select id from ana_rec)),
  'PT400', null, 'Recenzija salona A se ne prijavljuje iz konteksta salona B');
set local request.headers = '{}';
select throws_ok(
  format($$select public.report_review(%L)$$, (select id from ana_rec)),
  '42501', null, 'Bez x-salon-id nema prijave');
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
reset role;
grant select on prijava to public;

-- Sakrivena recenzija se ne prijavljuje: klijent je ne vidi.
update public.reviews set is_published = false where id = (select id from ana_rec);
set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select throws_ok(
  format($$select public.report_review(%L)$$, (select id from ana_rec)),
  'PT400', null, 'Sakrivena recenzija se ne prijavljuje');
reset role;
update public.reviews set is_published = true where id = (select id from ana_rec);

select results_eq(
  format($$select review_id, image_url, reason, salon_id from public.content_reports where id = %L$$,
    (select id from prijava)),
  format($$values (%L::uuid, null::text, 'Uvredljivo'::text, %L::uuid)$$,
    (select id from ana_rec), (select salon from fix)),
  'Prijava nosi recenziju, salon i razlog, bez slike');

set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select is((select count(*)::int from public.content_reports), 0,
  'Salon ne cita prijave svojih recenzija');
reset role;

select throws_ok(
  $$insert into public.content_reports(salon_id, reason) values ('550e8400-e29b-41d4-a716-446655440000', 'Nista')$$,
  '23514', null, 'Prijava mora nositi sliku ili recenziju');

set local role service_role;
select results_eq(
  $$select review_id, review_rating, review_comment, image_url from public.claim_content_reports(10)$$,
  format($$values (%L::uuid, 5, 'Odlično šišanje.'::text, null::text)$$, (select id from ana_rec)),
  'Worker preuzima prijavu sa ocjenom i tekstom recenzije');
reset role;

-- ---------------------------------------------------------------------------
-- Brisanje naloga
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"fe670000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select public.delete_my_account();
reset role;

select results_eq(
  format($$select author_name, comment, rating from public.reviews where id = %L$$, (select id from ana_rec)),
  $$values ('Bivši klijent'::text, null::text, 5)$$,
  'Brisanje naloga ostavlja ocjenu, a brise ime i tekst');

select * from finish();
rollback;
