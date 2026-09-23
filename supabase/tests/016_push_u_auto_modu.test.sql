-- Push obavijest o novoj rezervaciji u `auto` modu. Task 39.
--
-- Trigger `queue_appointment_push` je pisan u tasku 25, kad je `pending` bio jedini ishod
-- klijentske rezervacije. Task 37 je spojio `booking_mode`, pa je u `auto` modu termin
-- nastajao odmah kao `confirmed` — i grana `new.status <> 'pending'` je tiho odustajala.
-- Posljedica na hostovanom projektu: nula redova tipa `new_request` **ikad**, i nula redova
-- u `notification_logs` za 17 rezervacija iz aplikacije.
--
-- Ovaj fajl mjeri obje strane iste grane:
--   1. `manual` i dalje daje `new_request` — regresija koju popravka ne smije pojesti;
--   2. `auto` daje `new_booking`, i to **vlasnikovom** uredjaju;
--   3. klijentski uredjaj u `auto` modu ne dobija nista — odluka, ne previd (v. migracija);
--   4. rucni unos iz salona ne javlja salonu o njemu samom, ni u jednom modu.
--
-- Asercija iz sekcije 2 pada sa starim trigerom (0 umjesto 1), sto je i smisao: test koji
-- ostane zelen kad se popravka vrati unazad ne testira nista.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table fix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  'fb000000-0000-4000-8000-000000000011'::uuid as instalacija_klijenta,
  'fb000000-0000-4000-8000-000000000012'::uuid as instalacija_vlasnika,
  -- Izveden datum, ne fiksan: `max_advance_booking_days` je 30, pa bi fiksan datum jednog
  -- dana ispao van raspona i test bi pao iz pogresnog razloga (isto kao u `004`, `014`, `015`).
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak;
grant select on fix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fb000000-0000-4000-8000-000000000001', 'klijent@push39.invalid', '{"providers":["email"]}', '{}'),
('fb000000-0000-4000-8000-000000000002', 'vlasnik@push39.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('fb000000-0000-4000-8000-000000000002', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'vlasnik@push39.invalid', 'salon_admin');

-- Polazno stanje je asercija, ne pretpostavka: seed sa `auto` bi sekciju 1 ucinio
-- besmislenom umjesto crvenom.
select is((select booking_mode from public.salon_settings where salon_id = (select salon from fix)),
  'manual', 'Salon krece iz manual moda');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- Vlasnikov uredjaj. Bez njega grana `v_staff` bira nula redova i cijeli fajl bi bio zelen
-- iz pogresnog razloga — tacno stanje zatecno na hostovanom projektu.
set local request.jwt.claims = '{"sub":"fb000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table vlasnik_uredjaj as select public.register_device(
  (select salon from fix), (select instalacija_vlasnika from fix),
  repeat('c', 64), 'android', 'owner-token', true) as id;
reset role;
grant select on vlasnik_uredjaj to public;

-- Klijentski uredjaj i klijent.
set local request.jwt.claims = '{"sub":"fb000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table klijent_uredjaj as select public.register_device(
  (select salon from fix), (select instalacija_klijenta from fix),
  repeat('a', 64), 'android', 'client-token') as id;
create temporary table moj as select (public.ensure_customer((select salon from fix))).id as customer_id;
reset role;
grant select on klijent_uredjaj to public;
grant select on moj to public;

select isnt((select id from vlasnik_uredjaj), (select id from klijent_uredjaj),
  'Vlasnik i klijent su dva razlicita uredjaja');

-- ---------------------------------------------------------------------------
-- 1. `manual`: klijentska rezervacija javlja salonu `new_request`
-- ---------------------------------------------------------------------------
set local role authenticated;
create temporary table t_manual as select (public.book_appointment(
  (select salon from fix), (select customer_id from moj), (select usluga from fix),
  (select utorak from fix), '10:00', (select emir from fix), null,
  (select id from klijent_uredjaj))).id as id;
reset role;
grant select on t_manual to public;

select is((select status::text from public.appointments where id = (select id from t_manual)),
  'pending', 'Manual mod i dalje daje pending');
select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from t_manual) and type = 'new_request'
    and device_id = (select id from vlasnik_uredjaj)),
  1, 'Manual mod javlja salonu novi zahtjev');
select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from t_manual) and type = 'new_booking'),
  0, 'Zahtjev koji ceka odgovor nije rezervacija');

-- ---------------------------------------------------------------------------
-- 2. `auto`: klijentska rezervacija javlja salonu `new_booking`
-- ---------------------------------------------------------------------------
-- Mod se prebacuje istim `rpc`-om koji zove admin ekran, a ostale vrijednosti su prepisane
-- iz seeda: `update_salon_settings` prima cijeli skup, pa bi nabacane vrijednosti tiho
-- pomjerile korak ili prag i slotove ispod (isto kao u `015`).
set local request.jwt.claims = '{"sub":"fb000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select lives_ok($$
  select public.update_salon_settings(
    '550e8400-e29b-41d4-a716-446655440000', 'auto', 'exact_slot',
    5, 15, 2, 30, 3, false, true)
$$, 'Vlasnik prebacuje salon na automatsko potvrdjivanje');
reset role;

set local request.jwt.claims = '{"sub":"fb000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table t_auto as select (public.book_appointment(
  (select salon from fix), (select customer_id from moj), (select usluga from fix),
  (select utorak from fix), '12:00', (select emir from fix), null,
  (select id from klijent_uredjaj))).id as id;
reset role;
grant select on t_auto to public;

-- Bez ove asercije bi sekcija mogla biti zelena i da `booking_mode` uopste nije procitan:
-- `new_request` i `new_booking` se biraju bas po statusu koji je task 37 postavio.
select is((select status::text from public.appointments where id = (select id from t_auto)),
  'confirmed', 'Auto mod daje potvrdjen termin, kako ga je task 37 spojio');
select is((select source::text from public.appointments where id = (select id from t_auto)),
  'app', 'Automatski potvrdjena rezervacija i dalje nosi source=app');

select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from t_auto) and type = 'new_booking'
    and device_id = (select id from vlasnik_uredjaj)),
  1, 'Auto mod javlja salonu novu rezervaciju');
select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from t_auto) and type = 'new_request'),
  0, 'Potvrdjena rezervacija se salonu ne javlja kao zahtjev');

-- ---------------------------------------------------------------------------
-- 3. Klijent u `auto` modu ne dobija push — odluka, ne previd
-- ---------------------------------------------------------------------------
-- Tip `confirmed` se salje na *promjenu* statusa; u `auto` modu promjene nema, a klijent u
-- tom trenutku gleda ekran koji mu potvrdu vec pise. Ovaj red hvata i suprotan previd:
-- popravku koja bi salonsku obavijest poslala na sve uredjaje salona, ukljucujuci klijentske.
select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from t_auto)
    and device_id = (select id from klijent_uredjaj)),
  0, 'Klijentski uredjaj u auto modu ne dobija nista');
select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from t_auto)),
  1, 'Jedna rezervacija u auto modu daje tacno jedan red');

-- ---------------------------------------------------------------------------
-- 4. Negativan test: rucni unos ne javlja salonu o njemu samom
-- ---------------------------------------------------------------------------
-- `source` presudjuje prije statusa. Popravka koja bi taj uslov ispustila poslala bi
-- vlasniku push za svaki termin koji je sam upisao — i to bas u `auto` modu, gdje su i
-- rucni i klijentski termini `confirmed`.
set local request.jwt.claims = '{"sub":"fb000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
create temporary table t_rucni as select (public.book_appointment(
  (select salon from fix), (select customer_id from moj), (select usluga from fix),
  (select utorak from fix), '14:00', (select emir from fix))).id as id;
reset role;
grant select on t_rucni to public;

select is((select source::text from public.appointments where id = (select id from t_rucni)),
  'manual', 'Admin unos nosi source=manual');
select is((select count(*)::int from public.notification_logs
  where appointment_id = (select id from t_rucni)),
  0, 'Rucni unos ne javlja salonu o njemu samom');

select * from finish();
rollback;
