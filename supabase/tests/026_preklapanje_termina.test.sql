-- Preklapanje termina između dva klijenta — pitanje vlasnika proizvoda prije prve prezentacije:
-- „ako zakažem termin od pola sata, može li neko drugi rezervisati u mom terminu?"
--
-- `002_availability` to već dokazuje direktnim upisom i brojem slotova, na salonu sa dva
-- radnika. Ovdje je isti odgovor kroz **`book_appointment`**, kao što ga zove klijentska app,
-- na salonu sa **jednim** radnikom (Authentic, Jasko) — tu „bilo ko od nas" nema kome drugom
-- dati termin, i tu bi rupa bila najskuplja.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table pfix as
select
  'd11aa07e-4611-4fae-bf99-6439ef10bd16'::uuid as salon,
  '10000000-0000-4000-8000-000000000201'::uuid as sisanje,    -- 30 min
  '10000000-0000-4000-8000-000000000209'::uuid as paket,      -- Šišanje + brada, 50 min
  '20000000-0000-4000-8000-000000000201'::uuid as jasko,
  -- Utorak sljedeće sedmice: uvijek radni dan (09–16), uvijek u rasponu od 30 dana.
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as dan;
grant select on pfix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('ee000000-0000-4000-8000-000000000001', 'prvi@preklapanje.invalid',  '{"providers":["email"]}', '{}'),
('ee000000-0000-4000-8000-000000000002', 'drugi@preklapanje.invalid', '{"providers":["email"]}', '{}');

-- Dva klijenta, svaki svojim JWT-om i svojim `customers` redom — kao dva telefona.
set local request.headers = '{"x-salon-id":"d11aa07e-4611-4fae-bf99-6439ef10bd16"}';
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table prvi as
select (public.ensure_customer((select salon from pfix))).id as customer_id;
reset role;
grant select on prvi to public;

set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table drugi as
select (public.ensure_customer((select salon from pfix))).id as customer_id;
reset role;
grant select on drugi to public;

-- Prvi klijent: šišanje 10:00–10:30, „bilo ko od nas".
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
create temporary table moj as
select * from public.book_appointment(
  (select salon from pfix), (select customer_id from prvi), (select sisanje from pfix),
  (select dan from pfix), '10:00');
reset role;
grant select on moj to public;

select is((select employee_id from moj), (select jasko from pfix),
  '„Bilo ko od nas" sa jednim radnikom dobija Jaska');
select is((select status::text from moj), 'pending',
  'Salon u manual modu: termin čeka potvrdu — i takav već drži slot');

-- ---------------------------------------------------------------------------
-- Drugi klijent pokušava ući u isti termin
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"ee000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;

select throws_ok($$
  select public.book_appointment(
    'd11aa07e-4611-4fae-bf99-6439ef10bd16', (select customer_id from drugi),
    '10000000-0000-4000-8000-000000000201', (select dan from pfix), '10:00')
$$, 'PT409', 'Termin je upravo zauzet',
  'Isti početak, „bilo ko od nas": jedini radnik je zauzet — 409');

select throws_ok($$
  select public.book_appointment(
    'd11aa07e-4611-4fae-bf99-6439ef10bd16', (select customer_id from drugi),
    '10000000-0000-4000-8000-000000000201', (select dan from pfix), '10:15',
    '20000000-0000-4000-8000-000000000201')
$$, 'PT409', 'Termin je upravo zauzet',
  'Početak usred tuđeg termina (10:15 u 10:00–10:30) — 409');

select throws_ok($$
  select public.book_appointment(
    'd11aa07e-4611-4fae-bf99-6439ef10bd16', (select customer_id from drugi),
    '10000000-0000-4000-8000-000000000201', (select dan from pfix), '09:45',
    '20000000-0000-4000-8000-000000000201')
$$, 'PT409', 'Termin je upravo zauzet',
  'Termin koji bi završio usred tuđeg (09:45–10:15) — 409');

select throws_ok($$
  select public.book_appointment(
    'd11aa07e-4611-4fae-bf99-6439ef10bd16', (select customer_id from drugi),
    '10000000-0000-4000-8000-000000000209', (select dan from pfix), '09:15',
    '20000000-0000-4000-8000-000000000201')
$$, 'PT409', 'Termin je upravo zauzet',
  'Duža usluga koja prekriva tuđi termin (50 min od 09:15) — 409');

select throws_ok($$
  select public.book_appointment(
    'd11aa07e-4611-4fae-bf99-6439ef10bd16', (select customer_id from drugi),
    '10000000-0000-4000-8000-000000000201', (select dan from pfix), '10:30',
    '20000000-0000-4000-8000-000000000201')
$$, 'PT409', 'Termin je upravo zauzet',
  'Odmah po kraju (10:30) ne prolazi — 5 min buffera poslije termina je njegovo');

-- Lista koju app prikazuje drugom klijentu: nijedno vrijeme koje bi se preklopilo.
select is(
  (select array_agg(start_time order by start_time)::text from public.get_available_slots(
     (select salon from pfix), (select sisanje from pfix), (select dan from pfix))
   where start_time between '09:00' and '11:00'),
  '{09:00:00,09:15:00,10:45:00,11:00:00}',
  'Slobodno je samo ono što ne dira 10:00–10:35: 09:30–10:30 nema u listi');

select lives_ok($$
  select public.book_appointment(
    'd11aa07e-4611-4fae-bf99-6439ef10bd16', (select customer_id from drugi),
    '10000000-0000-4000-8000-000000000201', (select dan from pfix), '10:45')
$$, 'Prvi slobodan termin poslije buffera (10:45) prolazi');

reset role;

select is(
  (select count(*)::int from public.appointments
   where salon_id = (select salon from pfix) and date = (select dan from pfix)
     and status in ('pending', 'confirmed')),
  2, 'U danu su tačno dva termina — nijedan odbijeni pokušaj nije ostavio red');

select * from finish();
rollback;
