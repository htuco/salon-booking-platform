-- Postavke lokacije: kontakt podaci i booking pravila iz admina. Task 36.
--
-- Tri granice se ovdje dokazuju:
--   1. Oba puta pisanja idu **samo kroz rpc** — direktan `update` nad `salons` i
--      `salon_settings` vise ne postoji ni kao grant;
--   2. **Vlasnik mijenja samo svoje.** Tudji salon i tudje postavke daju `42501`, i to sa
--      postavljenim `x-salon-id` tog salona — header bira kontekst, ne daje prava (ADR-0003);
--   3. **Platformska polja ostaju platformska.** `salon_admin` ne moze promijeniti boje,
--      `status`, `plan` ni `slug` kroz `update_salon_contact`, niti napisati red u
--      `app_policies` (ADR-0009) — zadnje je negativan test taska 21 koji ovaj task mora
--      ostaviti zelenim.
--
-- Uz to, zadnja sekcija dokazuje ono sto DoD trazi rijecima „promjena `min_cancel_hours`
-- odmah mijenja ponasanje klijentskog otkazivanja": isti termin, isti klijent, dva ishoda,
-- a izmedju njih **samo** poziv `update_salon_settings`.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table pfix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '550e8400-e29b-41d4-a716-446655440001'::uuid as drugi_salon,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  'cc000000-0000-4000-8000-000000000001'::uuid as admin,
  'cc000000-0000-4000-8000-000000000002'::uuid as tudji_admin,
  'cc000000-0000-4000-8000-000000000003'::uuid as klijent,
  -- Izveden datum, ne fiksan: `max_advance_booking_days` je 30, pa bi fiksan datum jednog
  -- dana ispao van raspona i test bi pao iz pogresnog razloga (isto kao u `004`).
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak;
grant select on pfix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('cc000000-0000-4000-8000-000000000001', 'admin-post-a@invalid.test',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('cc000000-0000-4000-8000-000000000002', 'admin-post-b@invalid.test',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}', '{}'),
('cc000000-0000-4000-8000-000000000003', 'klijent-post@invalid.test',
 '{"providers":["email"]}', '{}');
insert into public.users(id, salon_id, name, email, role) values
((select admin from pfix), (select salon from pfix),
 'Vlasnik A', 'admin-post-a@invalid.test', 'salon_admin'),
((select tudji_admin from pfix), (select drugi_salon from pfix),
 'Vlasnik B', 'admin-post-b@invalid.test', 'salon_admin');

-- ---------------------------------------------------------------------------
-- 1. Grant je granica: obje tabele se citaju, nijedna se ne pise direktno
-- ---------------------------------------------------------------------------
select bag_eq($$
  select privilege_type::text from information_schema.role_table_grants
  where grantee = 'authenticated' and table_name = 'salons'
$$, array['SELECT'], 'Salon se samo cita direktno');
select bag_eq($$
  select privilege_type::text from information_schema.role_table_grants
  where grantee = 'authenticated' and table_name = 'salon_settings'
$$, array['SELECT'], 'Postavke se samo citaju direktno');
select ok(not has_table_privilege('authenticated', 'public.salons', 'UPDATE'),
  'Direktan update salona je oduzet');
-- Ovaj grant je do ovog taska bio **ziv**, uz `staff_manage` politiku koja ga je pustala:
-- vlasnik je mogao zaobici validaciju i upisati vrijednost koju rpc ne bi primio.
select ok(not has_table_privilege('authenticated', 'public.salon_settings', 'UPDATE'),
  'Direktan update postavki je oduzet');
select ok(not has_function_privilege('anon',
  'public.update_salon_contact(uuid, text, text, text, text, text, text, text, text)', 'EXECUTE'),
  'Anon ne mijenja kontakt podatke');
select ok(not has_function_privilege('anon',
  'public.update_salon_settings(uuid, text, text, int, int, int, int, int, boolean, boolean)',
  'EXECUTE'),
  'Anon ne mijenja booking pravila');

-- Politika koja je pokrivala pisanje je suzena na citanje; da je ostala `for all`, tvrdila
-- bi vise nego sto grant dopusta.
select is((select count(*)::int from pg_policies
           where tablename = 'salon_settings' and policyname = 'staff_manage'), 0,
  'staff_manage nad postavkama vise ne postoji');
select is((select cmd from pg_policies
           where tablename = 'salon_settings' and policyname = 'staff_read'), 'SELECT',
  'Vlasnik postavke samo cita');

-- ---------------------------------------------------------------------------
-- 2. Vlasnik mijenja svoje kontakt podatke
-- ---------------------------------------------------------------------------
-- `x-salon-id` je namjerno postavljen na **drugi** salon kroz cijelu ovu sekciju: header
-- bira kontekst citanja, a na `rpc` koji trazi `private.is_admin(p_salon_id)` nema uticaja.
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
set local request.jwt.claims = '{"sub":"cc000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;

select lives_ok($$
  select public.update_salon_contact(
    (select salon from pfix), 'Barber Studio Vitez', 'Stjepana Radica 4', 'Vitez',
    'Brijacnica od 2014.', '030 711 220', 'info@barber.test',
    'https://instagram.com/barber', 'https://facebook.com/barber')
$$, 'Vlasnik mijenja kontakt podatke svog salona');

select is((select name from public.salons where id = (select salon from pfix)),
  'Barber Studio Vitez', 'Zatečeni naziv ostaje nepromijenjen');
select is((select city from public.salons where id = (select salon from pfix)),
  'Vitez', 'Grad je upisan');
select is((select phone from public.salons where id = (select salon from pfix)),
  '030 711 220', 'Telefon je upisan');
select is((select facebook_url from public.salons where id = (select salon from pfix)),
  'https://facebook.com/barber',
  'Facebook stranica je kontakt podatak i ostaje (ADR-0011)');

-- Prazan unos iz forme mora postati `null`, ne prazan string: dva stanja koja znace isto
-- su dva stanja koja ekran mora razlikovati bez razloga.
select lives_ok($$
  select public.update_salon_contact(
    (select salon from pfix), 'Barber Studio Vitez', '', 'Vitez', '', '  ', '', '', '')
$$, 'Prazna opciona polja prolaze');
select is((select phone from public.salons where id = (select salon from pfix)), null,
  'Prazan telefon je NULL, ne prazan string');
select is((select email from public.salons where id = (select salon from pfix)), null,
  'Prazan email je NULL');
select is((select address from public.salons where id = (select salon from pfix)), '',
  'Adresa je not null kolona i prazno se pise kao prazan string');

-- Naziv je build-time identitet aplikacije: RPC ga prima samo kao tvrdnju o zatečenoj
-- vrijednosti, a pokušaj promjene mora pasti prije upisa ostalih kontakt podataka.
select throws_ok($$
  select public.update_salon_contact((select salon from pfix), 'Drugi naziv', 'Ne smije se upisati', 'Vitez')
$$, 'PT400', 'Naziv aplikacije mijenja se kroz novi store build',
  'Promjena naziva se odbija u bazi');
select is((select name from public.salons where id = (select salon from pfix)),
  'Barber Studio Vitez', 'Odbijeni poziv ne mijenja naziv');
select isnt((select address from public.salons where id = (select salon from pfix)),
  'Ne smije se upisati', 'Odbijeni poziv ne mijenja ni ostale podatke');

-- Grad ostaje jedino obavezno promjenjivo polje.
select throws_ok($$
  select public.update_salon_contact((select salon from pfix), 'Barber Studio Vitez', 'Adresa', '  ')
$$, 'PT400', 'Grad je obavezan', 'Prazan grad se odbija');

-- ---------------------------------------------------------------------------
-- 3. Platformska polja ostaju platformska
-- ---------------------------------------------------------------------------
-- Boje, `status`, `plan`, `slug` i `vertical_pack_key` nisu parametri funkcije, pa ih
-- vlasnik ne moze dotaknuti ni kroz jedini put koji ima. Asercije stoje jer bi dodavanje
-- takvog parametra „usput" izgledalo kao prosirenje, a bilo bi otvaranje brandinga
-- (`tenant.yaml` je izvor istine) i naplate.
select is((select primary_color from public.salons where id = (select salon from pfix)),
  '#C6A667', 'Primarna boja se ne mijenja iz admina — dolazi iz tenant.yaml');
select is((select status from public.salons where id = (select salon from pfix)), 'active',
  'Status salona ostaje platformski');
select is((select plan from public.salons where id = (select salon from pfix)), 'pro',
  'Plan ostaje platformski');
select is((select slug from public.salons where id = (select salon from pfix)),
  'barberstudiovitez', 'Slug ostaje platformski');

-- **Negativan test taska 21 mora ostati zelen.** Zakazivanje, Cijene i „Vasi podaci"
-- obavezuju firmu pod cijim imenom app stoji u storeu (ADR-0009). Ako `super_manage` ikad
-- oslabi na `private.is_admin(...)`, oba reda ispod padnu.
select throws_ok($$
  insert into public.app_policies(document, sort_order, title, body)
  values ('terms', 98, 'Moje pravilo', 'Tekst salona.')
$$, '42501', null, 'Vlasnik ne moze dodati platformsku sekciju pravila');
select results_eq($$
  update public.app_policies set body = 'Tekst koji salon pise umjesto firme' returning id
$$, $$select null::uuid where false$$,
  'Vlasnik ne moze izmijeniti nijednu platformsku sekciju');

-- Salonske sekcije **jesu** njegove i ostaju direktan CRUD (v. migracija, zadnji komentar).
select lives_ok($$
  insert into public.salon_policies(salon_id, sort_order, title, body)
  values ((select salon from pfix), 71, 'Kasnjenje', 'Cekamo vas 10 minuta.')
$$, 'Vlasnik pise svoju sekciju pravila');

-- ---------------------------------------------------------------------------
-- 4. Booking pravila
-- ---------------------------------------------------------------------------
select lives_ok($$
  select public.update_salon_settings(
    (select salon from pfix), 'auto', 'exact_slot', 10, 30, 1, 60, 5, true, false)
$$, 'Vlasnik mijenja booking pravila svog salona');
select is((select booking_mode from public.salon_settings
           where salon_id = (select salon from pfix)), 'auto',
  'Nacin potvrde je upisan');
select is((select buffer_minutes from public.salon_settings
           where salon_id = (select salon from pfix)), 10, 'Buffer je upisan');
select is((select max_advance_booking_days from public.salon_settings
           where salon_id = (select salon from pfix)), 60,
  'Maksimum unaprijed je upisan');
-- Validacija: poruka uz polje koje je krivo, umjesto `23514` sa imenom constrainta.
select throws_ok($$
  select public.update_salon_settings(
    (select salon from pfix), 'poluautomatski', 'exact_slot', 5, 15, 2, 30, 3, false, true)
$$, 'PT400', 'Nepoznat nacin potvrde', 'Nepoznat booking_mode se odbija');
select throws_ok($$
  select public.update_salon_settings(
    (select salon from pfix), 'manual', 'kad_stigne', 5, 15, 2, 30, 3, false, true)
$$, 'PT400', 'Nepoznata granularnost', 'Nepoznata granularnost se odbija');
select throws_ok($$
  select public.update_salon_settings(
    (select salon from pfix), 'manual', 'exact_slot', 500, 15, 2, 30, 3, false, true)
$$, 'PT400', 'Pauza izmedju termina mora biti 0-120 minuta', 'Buffer van raspona se odbija');
select throws_ok($$
  select public.update_salon_settings(
    (select salon from pfix), 'manual', 'exact_slot', 5, 0, 2, 30, 3, false, true)
$$, 'PT400', 'Korak termina mora biti 1-120 minuta', 'Korak 0 se odbija');
select throws_ok($$
  select public.update_salon_settings(
    (select salon from pfix), 'manual', 'exact_slot', 5, 15, -1, 30, 3, false, true)
$$, 'PT400', 'Najraniji termin ne moze biti negativan', 'Negativan min_advance se odbija');
select throws_ok($$
  select public.update_salon_settings(
    (select salon from pfix), 'manual', 'exact_slot', 5, 15, 2, 0, 3, false, true)
$$, 'PT400', 'Kalendar mora biti otvoren bar jedan dan unaprijed', 'Nula dana unaprijed se odbija');
select throws_ok($$
  select public.update_salon_settings(
    (select salon from pfix), 'manual', 'exact_slot', 5, 15, 2, 30, -3, false, true)
$$, 'PT400', 'Rok otkazivanja ne moze biti negativan', 'Negativan rok otkazivanja se odbija');

-- Zona i jezik nisu parametri: promjena zone mijenja znacenje svih vec upisanih `time`
-- vrijednosti u `working_hours` i `appointments`, pa nije postavka nego migracija podataka.
select is((select timezone from public.salon_settings
           where salon_id = (select salon from pfix)), 'Europe/Sarajevo',
  'Vremenska zona se ne mijenja iz admina');

-- ---------------------------------------------------------------------------
-- 5. Tudji salon — ista greska za oba puta
-- ---------------------------------------------------------------------------
select throws_ok($$
  select public.update_salon_contact(
    (select drugi_salon from pfix), 'Preuzeto', 'Adresa', 'Travnik')
$$, '42501', 'Nije dozvoljeno', 'Vlasnik A ne mijenja kontakt salona B ni sa njegovim headerom');
select throws_ok($$
  select public.update_salon_settings(
    (select drugi_salon from pfix), 'auto', 'exact_slot', 5, 15, 2, 30, 0, false, true)
$$, '42501', 'Nije dozvoljeno', 'Vlasnik A ne mijenja postavke salona B');
select is((select min_cancel_hours from public.salon_settings
           where salon_id = (select drugi_salon from pfix)), 6,
  'Rok otkazivanja salona B je netaknut');
reset role;

-- Klijent nije admin nijednog salona: isti `42501`, bez razlike koja bi potvrdila da salon
-- postoji.
set local request.jwt.claims = '{"sub":"cc000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select throws_ok($$
  select public.update_salon_contact((select salon from pfix), 'Klijentov naziv', '', 'Vitez')
$$, '42501', 'Nije dozvoljeno', 'Klijent ne mijenja kontakt podatke salona');
select throws_ok($$
  select public.update_salon_settings(
    (select salon from pfix), 'auto', 'exact_slot', 5, 15, 2, 30, 0, false, true)
$$, '42501', 'Nije dozvoljeno', 'Klijent ne mijenja booking pravila');
reset role;

-- ---------------------------------------------------------------------------
-- 6. DoD: promjena `min_cancel_hours` odmah mijenja klijentsko otkazivanje
-- ---------------------------------------------------------------------------
-- Ovo je jedina sekcija koja ne provjerava dozvole nego **posljedicu**. Isti termin, isti
-- klijent, dva poziva `cancel_appointment` — a izmedju njih samo `update_salon_settings`.
-- Bez nje bi „promjena vrijedi odmah" bila tvrdnja o tome da nema kesa, a ne dokaz.
--
-- Termin se pravi **sutra u 10:00**, pa je do njega vise od 12 a manje od 48 sati bez
-- obzira kad se test pokrene.
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local request.jwt.claims = '{"sub":"cc000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table moj_klijent as
select (public.ensure_customer((select salon from pfix))).id as customer_id;
reset role;
grant select on moj_klijent to public;

-- Rok se vraca na razuman, jer ga je sekcija 4 ostavila na 5, i booking mod na `manual`.
set local role postgres;
update public.salon_settings set min_cancel_hours = 3, booking_mode = 'manual',
  max_advance_booking_days = 30, min_advance_booking_hours = 2
where salon_id = (select salon from pfix);
reset role;

set local role authenticated;
create temporary table termin as
select (public.book_appointment(
  (select salon from pfix), (select customer_id from moj_klijent), (select usluga from pfix),
  (select utorak from pfix), '10:00', (select emir from pfix))).id as id;
reset role;
grant select on termin to public;

-- Rok je 3 sata, termin je za osam dana: otkazivanje prolazi... ali ga ne izvrsavamo, jer
-- otkazan termin se vise ne moze otkazati drugacije. Umjesto toga se **prvo** rok podigne
-- iznad razmaka do termina, pa se dokaze da isti poziv sada pada.
set local request.jwt.claims = '{"sub":"cc000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select lives_ok($$
  select public.update_salon_settings(
    (select salon from pfix), 'manual', 'exact_slot', 5, 15, 2, 30, 720, false, true)
$$, 'Vlasnik podize rok otkazivanja na 30 dana');
reset role;

set local request.jwt.claims = '{"sub":"cc000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select throws_ok($$
  select public.cancel_appointment((select salon from pfix), (select id from termin))
$$, 'PT403', 'Rok za otkazivanje je prosao',
  'Novi rok vrijedi odmah: klijent vise ne moze otkazati termin koji je maloprije mogao');
reset role;

-- I nazad: vlasnik spusti rok, isti klijent i isti termin sada prolaze. Dokazuje da je rok
-- **citan iz postavki pri svakom pozivu**, a ne zapamcen pri rezervaciji.
set local request.jwt.claims = '{"sub":"cc000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select lives_ok($$
  select public.update_salon_settings(
    (select salon from pfix), 'manual', 'exact_slot', 5, 15, 2, 30, 1, false, true)
$$, 'Vlasnik spusta rok otkazivanja na jedan sat');
reset role;

set local request.jwt.claims = '{"sub":"cc000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select is(
  (select status::text from public.cancel_appointment(
    (select salon from pfix), (select id from termin))),
  'cancelled',
  'Spusten rok vrijedi odmah: isti termin se sada otkazuje');
reset role;

select * from finish();
rollback;
