-- Otkazivanje termina kroz validiranu funkciju. Task 16.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table kfix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  'dd000000-0000-4000-8000-000000000001'::uuid as klijent,
  'dd000000-0000-4000-8000-000000000002'::uuid as tudji,
  'dd000000-0000-4000-8000-000000000003'::uuid as admin,
  -- Datum je izveden, ne fiksan: `max_advance_booking_days` je 30, pa bi fiksan datum
  -- jednog dana ispao izvan raspona i test bi pao iz pogresnog razloga.
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak;
grant select on kfix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('dd000000-0000-4000-8000-000000000001', 'klijent@cancel.invalid', '{"providers":["email"]}', '{}'),
('dd000000-0000-4000-8000-000000000002', 'tudji@cancel.invalid',   '{"providers":["email"]}', '{}'),
('dd000000-0000-4000-8000-000000000003', 'admin@cancel.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('dd000000-0000-4000-8000-000000000003', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'admin@cancel.invalid', 'salon_admin');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local request.jwt.claims = '{"sub":"dd000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;

create temporary table moj as
select (public.ensure_customer((select salon from kfix))).id as customer_id;
reset role;
grant select on moj to public;

set local role authenticated;
create temporary table t1 as
select (public.book_appointment(
  (select salon from kfix), (select customer_id from moj), (select usluga from kfix),
  (select utorak from kfix), '10:00', (select emir from kfix))).id as id;
reset role;
grant select on t1 to public;

-- ---------------------------------------------------------------------------
-- Odbijanja idu prije srecnog puta: kad bi isle poslije, termin bi vec bio
-- otkazan i svaka od njih bi "prosla" iz pogresnog razloga.
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"dd000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"providers":["email"]}}';
select throws_ok(
  format($$select public.cancel_appointment(%L, %L)$$, (select salon from kfix), (select id from t1)),
  '42501', 'Nije dozvoljeno',
  'Tudji termin se ne moze otkazati');

select throws_ok(
  format($$select public.cancel_appointment(%L, '00000000-0000-4000-8000-0000000000ff')$$, (select salon from kfix)),
  '42501', 'Nije dozvoljeno',
  'Nepostojeci termin vraca istu gresku kao tudji — nema nabrajanja');

-- Vlasnik, ali bez konteksta salona.
set local request.jwt.claims = '{"sub":"dd000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local request.headers = '{}';
select throws_ok(
  format($$select public.cancel_appointment(%L, %L)$$, (select salon from kfix), (select id from t1)),
  '42501', 'Nije dozvoljeno',
  'Bez x-salon-id headera nema konteksta ni za vlasnika termina');

set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';

-- ---------------------------------------------------------------------------
-- Rok iz postavki, ne iz konstante
-- ---------------------------------------------------------------------------
reset role;
-- Termin je za manje od `min_cancel_hours` sati (seed: 3).
--
-- **Vrijeme se izvodi iz `now()`, ne iz kalendara.** Prva verzija je samo pomjerala datum na
-- danas i oslanjala se na to da je 10:00 vec proslo — pa je prolazila popodne, a padala
-- poslije ponoci, kad je 10:00 opet devet sati u buducnosti. Test je tako mjerio doba dana
-- u kojem je pokrenut, a ne kod. Sat iza `now()` je unutar roka u svakom trenutku, i
-- prelazak ponoci nosi datum sa sobom.
update public.appointments set
  date = ((now() at time zone 'Europe/Sarajevo') + interval '1 hour')::date,
  start_time = ((now() at time zone 'Europe/Sarajevo') + interval '1 hour')::time
where id = (select id from t1);

set local role authenticated;
select throws_ok(
  format($$select public.cancel_appointment(%L, %L)$$, (select salon from kfix), (select id from t1)),
  'PT403', 'Rok za otkazivanje je prosao',
  'Klijent ne moze otkazati nakon min_cancel_hours');

-- **Rok vazi za klijenta, ne za salon.** Salon otkazuje kad mora.
set local request.jwt.claims = '{"sub":"dd000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
select is(
  (select status::text from public.cancel_appointment(
    (select salon from kfix), (select id from t1), 'Radnik je bolestan')),
  'cancelled',
  'Salon moze otkazati i nakon roka');

reset role;
select is(
  (select cancelled_by::text from public.appointments where id = (select id from t1)),
  'salon',
  'cancelled_by kaze ko je otkazao — admin ekran i statistika zavise od toga');
select is(
  (select cancel_reason from public.appointments where id = (select id from t1)),
  'Radnik je bolestan',
  'Razlog se pamti');

-- ---------------------------------------------------------------------------
-- Srecan put i idempotentnost
-- ---------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"dd000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';

create temporary table t2 as
select (public.book_appointment(
  (select salon from kfix), (select customer_id from moj), (select usluga from kfix),
  (select utorak from kfix), '12:00', (select emir from kfix))).id as id;
reset role;
grant select on t2 to public;

set local role authenticated;
select is(
  (select status::text from public.cancel_appointment((select salon from kfix), (select id from t2))),
  'cancelled', 'Klijent otkazuje svoj termin u roku');

reset role;
select is(
  (select cancelled_by::text from public.appointments where id = (select id from t2)),
  'customer', 'cancelled_by je customer kad otkazuje klijent');

-- Dva uredjaja, dva tapa: drugi ne smije dati crvenu poruku.
set local role authenticated;
select is(
  (select status::text from public.cancel_appointment((select salon from kfix), (select id from t2))),
  'cancelled', 'Ponovno otkazivanje je idempotentno, ne greska');

-- ---------------------------------------------------------------------------
-- Otkazan slot se oslobadja
-- ---------------------------------------------------------------------------
-- Ovo je jedini test koji dokazuje da otkazivanje ima efekta **izvan** svog reda:
-- `get_available_slots` racuna `pending` i `confirmed` kao zauzeto, pa otkazan termin
-- mora vratiti svoje vrijeme u ponudu.
select ok(
  exists(select 1 from public.get_available_slots(
    (select salon from kfix), (select usluga from kfix), (select utorak from kfix),
    (select emir from kfix)) where start_time = '12:00'),
  'Otkazan slot se odmah vraca u listu slobodnih');

-- ---------------------------------------------------------------------------
-- Zavrsen termin
-- ---------------------------------------------------------------------------
reset role;
create temporary table t3 as
select (public.book_appointment(
  (select salon from kfix), (select customer_id from moj), (select usluga from kfix),
  (select utorak from kfix), '14:00', (select emir from kfix))).id as id
from (select set_config('request.jwt.claims',
  '{"sub":"dd000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}', true)) s;
grant select on t3 to public;
update public.appointments set status = 'completed' where id = (select id from t3);

set local role authenticated;
select throws_ok(
  format($$select public.cancel_appointment(%L, %L)$$, (select salon from kfix), (select id from t3)),
  'PT409', 'Termin je zavrsen i ne moze se otkazati',
  'Zavrsen termin se ne otkazuje');

-- ---------------------------------------------------------------------------
-- Direktan update i anon
-- ---------------------------------------------------------------------------
-- **`update` sa klijenta ne baca — ne radi nista.** `authenticated` ima `update` grant na
-- `appointments`, ali nijedna klijentska politika nije `for update`, pa RLS filtrira sve
-- redove i `update` pogodi nula redova. Nula redova **nije greska** u Postgresu.
--
-- Asercija je zato na ucinku, ne na izuzetku. Test koji je ocekivao 42501 je pao, i to
-- je bio ispravan nalaz: tvrdnja je bila pogresna, ne kod. (`insert` bi bacio, jer ga
-- hvata `with check` politike `staff_manage`.)
select lives_ok($$
  update public.appointments set status = 'cancelled' where id = (select id from t3)
$$, 'Direktan update ne baca — RLS ga pretvori u nula pogodjenih redova');

reset role;
select is(
  (select status::text from public.appointments where id = (select id from t3)),
  'completed',
  'Red je ostao netaknut — klijent ga nije mogao promijeniti mimo funkcije');
set local role authenticated;

reset role;
set local role anon;
select throws_ok(
  format($$select public.cancel_appointment(%L, %L)$$, (select salon from kfix), (select id from t3)),
  '42501', NULL, 'anon nema execute grant');
reset role;

select * from finish();
rollback;
