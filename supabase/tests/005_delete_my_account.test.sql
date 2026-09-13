-- Brisanje naloga. Task 17.
-- Sve se vrti u transakciji koja se na kraju ponistava.
begin;
set local search_path = public, extensions;
select no_plan();

-- Isti covjek u **dva** salona — to je cijela poenta ovog testa. Brisanje naloga je
-- odluka o osobi, ne o salonu, pa suite mora dokazati da anonimizacija stigne i u salon
-- koji nije bio u `x-salon-id` headeru kad je brisanje pokrenuto.
create temporary table dfix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon_a,   -- Barber Studio Vitez
  '550e8400-e29b-41d4-a716-446655440001'::uuid as salon_b,   -- Beauty Studio Travnik
  'cc000000-0000-4000-8000-000000000001'::uuid as klijent,
  'cc000000-0000-4000-8000-000000000002'::uuid as drugi,
  'cc000000-0000-4000-8000-000000000003'::uuid as admin;
grant select on dfix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('cc000000-0000-4000-8000-000000000001', 'brisem@delete.invalid',
 '{"providers":["email"]}', '{"full_name":"Emir Delic"}'),
('cc000000-0000-4000-8000-000000000002', 'ostajem@delete.invalid',
 '{"providers":["email"]}', '{"full_name":"Adna Ostajic"}'),
('cc000000-0000-4000-8000-000000000003', 'admin@delete.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('cc000000-0000-4000-8000-000000000003', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'admin@delete.invalid', 'salon_admin');

-- Klijentski redovi u oba salona, sa punim licnim podacima.
insert into public.customers(salon_id, auth_identity_id, name, phone, note, visit_count)
select (select salon_a from dfix),
       ai.id, 'Emir Delic', '+38761111111', 'Voli kratko sa strane', 7
from public.auth_identities ai where ai.supabase_user_id = (select klijent from dfix);

insert into public.customers(salon_id, auth_identity_id, name, phone, note, visit_count)
select (select salon_b from dfix),
       ai.id, 'Emir Delic', '+38761111111', 'Dolazi subotom', 2
from public.auth_identities ai where ai.supabase_user_id = (select klijent from dfix);

-- Tudji klijent u istom salonu — kontrola da anonimizacija ne prelije preko identiteta.
insert into public.customers(salon_id, auth_identity_id, name, phone, visit_count)
select (select salon_a from dfix), ai.id, 'Adna Ostajic', '+38762222222', 3
from public.auth_identities ai where ai.supabase_user_id = (select drugi from dfix);

-- Cetiri termina naseg covjeka: buduci potvrdjen, buduci pending, **prosli zavrseni**
-- (evidencija salona koja mora prezivjeti), i jedan u drugom salonu.
insert into public.appointments
  (salon_id, service_id, employee_id, customer_id, auth_identity_id,
   customer_name, customer_phone, customer_note, date, start_time, end_time, status)
select c.salon_id, '10000000-0000-4000-8000-000000000001',
       '20000000-0000-4000-8000-000000000001', c.id, c.auth_identity_id,
       'Emir Delic', '+38761111111', 'Voli kratko sa strane',
       current_date + 7, time '10:00', time '10:30', 'confirmed'
from public.customers c
where c.salon_id = (select salon_a from dfix) and c.name = 'Emir Delic';

insert into public.appointments
  (salon_id, service_id, employee_id, customer_id, auth_identity_id,
   customer_name, customer_phone, date, start_time, end_time, status)
select c.salon_id, '10000000-0000-4000-8000-000000000002',
       '20000000-0000-4000-8000-000000000001', c.id, c.auth_identity_id,
       'Emir Delic', '+38761111111',
       current_date + 9, time '12:00', time '12:20', 'pending'
from public.customers c
where c.salon_id = (select salon_a from dfix) and c.name = 'Emir Delic';

insert into public.appointments
  (salon_id, service_id, employee_id, customer_id, auth_identity_id,
   customer_name, customer_phone, date, start_time, end_time, status)
select c.salon_id, '10000000-0000-4000-8000-000000000004',
       '20000000-0000-4000-8000-000000000002', c.id, c.auth_identity_id,
       'Emir Delic', '+38761111111',
       current_date - 14, time '09:00', time '09:40', 'completed'
from public.customers c
where c.salon_id = (select salon_a from dfix) and c.name = 'Emir Delic';

insert into public.appointments
  (salon_id, service_id, employee_id, customer_id, auth_identity_id,
   customer_name, customer_phone, date, start_time, end_time, status)
select c.salon_id, '10000000-0000-4000-8000-000000000005',
       '20000000-0000-4000-8000-000000000003', c.id, c.auth_identity_id,
       'Emir Delic', '+38761111111',
       current_date + 5, time '11:00', time '11:45', 'confirmed'
from public.customers c
where c.salon_id = (select salon_b from dfix) and c.name = 'Emir Delic';

-- ---------------------------------------------------------------------------
-- anon i osoblje ne smiju nista
-- ---------------------------------------------------------------------------
set local role anon;
select throws_ok(
  $$select public.delete_my_account()$$,
  '42501', NULL,
  'anon nema execute grant — brisanje naloga trazi prijavu');
reset role;

-- Admin nije klijent: njegov nalog je salonov podatak i ne gasi ga ekran u app-i.
set local request.jwt.claims = '{"sub":"cc000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok(
  $$select public.delete_my_account()$$,
  '42501', NULL,
  'salon_admin ne brise nalog kroz klijentsku funkciju');
reset role;

-- ---------------------------------------------------------------------------
-- Brisanje ne trazi `x-salon-id`
-- ---------------------------------------------------------------------------
-- Header se namjerno **ne** postavlja. Da funkcija trazi kontekst salona, ovaj poziv bi
-- pao — a pao bi i na pravom uredjaju, jer brisanje nije vezano za jedan salon.
set local request.headers = '{}';
set local request.jwt.claims = '{"sub":"cc000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;

select lives_ok(
  $$select public.delete_my_account()$$,
  'Brisanje radi bez x-salon-id headera — nije salon-scoped operacija');
reset role;

-- ---------------------------------------------------------------------------
-- Sta je ostalo iza brisanja
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from public.customers c
     join public.auth_identities ai on ai.id = c.auth_identity_id
    where ai.supabase_user_id = (select klijent from dfix)
      and c.name = 'Obrisan klijent'),
  2,
  'Oba klijentska reda su anonimizirana — i u salonu koji nije bio u headeru');

select is(
  (select count(*)::int from public.customers where phone = '+38761111111'),
  0,
  'Telefon je obrisan svuda, ne zamijenjen konstantom');

select is(
  (select count(*)::int from public.customers where note is not null and name = 'Obrisan klijent'),
  0,
  'Biljeska je obrisana');

-- `visit_count` je salonova evidencija i **mora** prezivjeti brisanje naloga.
select is(
  (select sum(c.visit_count)::int from public.customers c
     join public.auth_identities ai on ai.id = c.auth_identity_id
    where ai.supabase_user_id = (select klijent from dfix)),
  9,
  'visit_count je netaknut — salonova evidencija nije korisnikov podatak');

-- Tudji klijent u istom salonu se ne smije ni dotaci.
select is(
  (select name from public.customers where phone = '+38762222222'),
  'Adna Ostajic',
  'Tudji klijent u istom salonu je netaknut');

-- ---------------------------------------------------------------------------
-- Licni podaci na samim terminima
-- ---------------------------------------------------------------------------
-- Bez ovoga je cijeli task pozoriste: `appointments` nosi ime i telefon kao zasebne
-- kolone, pa anonimizacija koja dira samo `customers` ostavlja puno ime u salonovoj listi.
select is(
  (select count(*)::int from public.appointments where customer_phone = '+38761111111'),
  0,
  'Telefon je obrisan i sa termina, ne samo sa customers reda');

select is(
  (select count(*)::int from public.appointments where customer_name = 'Emir Delic'),
  0,
  'Ime je obrisano i sa termina');

select is(
  (select count(*)::int from public.appointments where customer_name = 'Obrisan klijent'),
  4,
  'Sva cetiri termina su anonimizirana, u oba salona');

-- ---------------------------------------------------------------------------
-- Buduci termini se otkazuju, prosli ostaju
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from public.appointments
    where status = 'cancelled' and cancel_reason = 'Klijent je obrisao nalog'),
  3,
  'Tri buduca termina (oba salona, pending i confirmed) su otkazana');

select is(
  (select count(distinct cancelled_by::text)::int from public.appointments
    where cancel_reason = 'Klijent je obrisao nalog'),
  1,
  'cancelled_by je jedinstven za sve otkazane');

select is(
  (select distinct cancelled_by::text from public.appointments
    where cancel_reason = 'Klijent je obrisao nalog'),
  'customer',
  'cancelled_by je customer — covjek je to pokrenuo, nije scheduler');

-- Prosli zavrsen termin je salonova evidencija i **ne** smije postati otkazan.
select is(
  (select count(*)::int from public.appointments
    where status = 'completed' and date = current_date - 14),
  1,
  'Prosli zavrsen termin je ostao completed — evidencija salona prezivljava');

-- ---------------------------------------------------------------------------
-- Identitet
-- ---------------------------------------------------------------------------
select isnt(
  (select deleted_at from public.auth_identities where supabase_user_id = (select klijent from dfix)),
  null,
  'Identitet ima deleted_at');

select is(
  (select email from public.auth_identities where supabase_user_id = (select klijent from dfix)),
  null,
  'Mail je obrisan — obrisan nalog koji i dalje zna tvoj mail nije obrisan nalog');

select is(
  (select display_name from public.auth_identities where supabase_user_id = (select klijent from dfix)),
  null,
  'Ime je obrisano sa identiteta');

-- ---------------------------------------------------------------------------
-- Pristup je stvarno ugasen
-- ---------------------------------------------------------------------------
-- Ovo je DoD stavka taska: obrisan identitet vise ne cita svoje termine. Gate je usiven
-- od init migracije, ali "usiven" je tvrdnja dok je test ne pokrene.
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local request.jwt.claims = '{"sub":"cc000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;

select is(
  (select count(*)::int from public.appointments),
  0,
  'Obrisan identitet ne vidi nijedan svoj termin');

select is(
  (select count(*)::int from public.customers),
  0,
  'Obrisan identitet ne vidi svoj customers red');

select is(
  (select count(*)::int from public.auth_identities),
  0,
  'Obrisan identitet ne vidi ni sam sebe');

-- `ensure_customer` ne smije vratiti obrisani nalog u zivot.
select throws_ok(
  format($$select public.ensure_customer(%L)$$, (select salon_a from dfix)),
  '42501', NULL,
  'ensure_customer odbija obrisan identitet — nema uskrsnuca kroz rezervaciju');

-- Drugi poziv brisanja: identitet vise nije vidljiv funkciji, pa je ishod isti 42501.
select throws_ok(
  $$select public.delete_my_account()$$,
  '42501', NULL,
  'Drugo brisanje ne radi nista — nema sta da se brise');
reset role;

-- ---------------------------------------------------------------------------
-- Trigger ne uskrsava obrisani nalog
-- ---------------------------------------------------------------------------
-- Najzanimljiviji dio: bez `where deleted_at is null` u `sync_auth_identity` bi sljedeca
-- prijava istim mailom vratila nalog kroz `on conflict do update`. Update nad `auth.users`
-- je tacno ono sto prijava radi.
update auth.users
set last_sign_in_at = now(), raw_user_meta_data = '{"full_name":"Emir Delic"}'
where id = (select klijent from dfix);

select isnt(
  (select deleted_at from public.auth_identities where supabase_user_id = (select klijent from dfix)),
  null,
  'Nova prijava ne skida deleted_at — trigger ne uskrsava obrisani nalog');

select is(
  (select display_name from public.auth_identities where supabase_user_id = (select klijent from dfix)),
  null,
  'Nova prijava ne vraca ime na obrisani identitet');

-- ---------------------------------------------------------------------------
-- Klijent ne moze mimo funkcije
-- ---------------------------------------------------------------------------
-- Ako ovo ikad prodje, funkcija je ukras: bilo ko postavlja `deleted_at` kome hoce.
--
-- **Ovdje se baca, a ne filtrira tiho** — i to je razlika od onoga sto `security.md`
-- opisuje za `appointments` i `customers`. Tamo `authenticated` *ima* `update` grant pa ga
-- zaustavlja tek odsustvo politike, sto znaci nula pogodjenih redova i nikakvu gresku.
-- `auth_identities` ima samo `grant select` (init migracija) i samo `for select` politiku,
-- pa update pada na samom grantu. Jaca garancija, ali drugog oblika: asercija ide na
-- gresku, ne na ucinak. Napisano tek nakon pokretanja — prva verzija ovog testa je
-- ocekivala tihi filter i oborila cijeli fajl.
set local request.jwt.claims = '{"sub":"cc000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;

select throws_ok($$
  update public.auth_identities set deleted_at = now()
  where supabase_user_id = 'cc000000-0000-4000-8000-000000000001'
$$, '42501', NULL,
  'Klijent nema update grant na auth_identities — funkcija je jedini put');

reset role;

select is(
  (select deleted_at from public.auth_identities where supabase_user_id = (select drugi from dfix)),
  null,
  'Nalog drugog covjeka je i dalje ziv');

select * from finish();
rollback;
