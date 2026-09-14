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
-- Termin mora biti **unutar** `min_cancel_hours`, da bi klijentu rok istekao.
--
-- **Pomjera se rok, ne termin.** Dvije prethodne verzije su pomjerale termin prema `now()`
-- i obje su mjerile doba dana u kojem je test pokrenut, a ne kod:
--
--   1. prva je pomjerala samo `date` na danas i racunala na to da je 10:00 proslo — pa je
--      prolazila popodne, a padala poslije ponoci;
--   2. druga je pomjerala `date` i `start_time` na `now() + 1 sat`, ali je **`end_time`
--      ostavila na 10:30**. Poslije 09:30 je `start_time` presao `end_time` i upis je
--      padao na `check(end_time > start_time)` — ne kao neuspjela asercija nego kao greska
--      koja obori cijeli fajl. Test je tako bio zelen samo ujutro, a to se nije vidjelo jer
--      ga poslije taska 16 niko nije pokrenuo uvece (CI je blokiran).
--
-- Treca verzija ne dira termin uopste. Termin ostaje tamo gdje ga je `book_appointment`
-- napravio — na `utorak` u 10:00, sa ispravnim `end_time` — a mijenja se **postavka**. To
-- je usput blize onome sto test tvrdi da mjeri: da rok dolazi iz `salon_settings`, a ne iz
-- konstante u kodu. Godina dana pokriva svaki `utorak` koji `kfix` moze izabrati.
update public.salon_settings set min_cancel_hours = 8760
where salon_id = (select salon from kfix);

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
-- Rok nazad na vrijednost iz seeda: t2 se otkazuje **u roku**, pa bi ga godisnji rok
-- odbio iz pogresnog razloga i asercija ispod bi mjerila postavku umjesto srecnog puta.
--
-- Ide **prije** `set local role authenticated`: `salon_settings` nema klijentsku `for
-- update` politiku, pa bi pod tom rolom RLS filtrirao sve redove i update bi pogodio nula
-- redova — bez greske (v. `security.md`). Rok bi ostao godisnji, t2 bi pao, i uzrok bi
-- izgledao kao kvar u `cancel_appointment`.
update public.salon_settings set min_cancel_hours = 3
where salon_id = (select salon from kfix);

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
-- **Do taska 24 je ovaj `update` prolazio bez greske i pogadjao nula redova.** `authenticated`
-- je imao `update` grant, a zaustavljalo ga je samo odsustvo klijentske `for update` politike:
-- RLS filtrira sve redove, a nula pogodjenih redova nije greska u Postgresu.
--
-- Task 24 je **oduzeo `insert` i `update` grant** na `appointments`, jer je isti taj grant
-- adminu dozvoljavao da zaobidje `book_appointment` i upise termin van radnog vremena
-- (`security.md`, "Sta jos nije zatvoreno"). Klijent je time dobio i drugu bravu: sada puca
-- na grantu, prije nego se RLS uopste pita.
--
-- Asercija je zato prepisana sa ucinka na izuzetak. Stara tvrdnja nije bila pogresna — bila
-- je tacna za stanje prije taska 24, i ostaje zapisana ovdje jer objasnjava **zasto** su dvije
-- brave, a ne jedna.
select throws_ok($$
  update public.appointments set status = 'cancelled' where id = (select id from t3)
$$, '42501', NULL,
  'Direktan update baca — insert/update grant je oduzet u tasku 24');

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
