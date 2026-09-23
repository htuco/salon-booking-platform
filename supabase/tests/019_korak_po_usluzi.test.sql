-- Korak rezervacije po usluzi. Task 43, ADR-0014.
--
-- Mjeri:
--   1. usluga bez koraka koristi salonski — postojece ponasanje netaknuto;
--   2. korak usluge mijenja ponudjene pocetke, i nadjacava salonski u oba smjera;
--   3. `book_appointment` provodi isti ugovor — pocetak van koraka usluge je odbijen;
--   4. `create_service`/`update_service` primaju korak, odbijaju van raspona, a NULL vraca salonski.
begin;
set local search_path = public, extensions;
select no_plan();

create temporary table fix as
select
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '10000000-0000-4000-8000-000000000001'::uuid as usluga,   -- 30 min
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  -- Izveden datum, kao u `016`/`018`: utorak sljedece sedmice je u buducnosti i radni (09–17).
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date as utorak;
grant select on fix to public;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('fd000000-0000-4000-8000-000000000001', 'vlasnik@korak43.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('fd000000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik', 'vlasnik@korak43.invalid', 'salon_admin');
insert into public.customers(id, salon_id, name) values
('fd200000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000', 'Klijent 43');

create function pg_temp.pocetci() returns time[] language sql as $$
  select coalesce(array_agg(s.start_time order by s.start_time), '{}')
  from public.get_available_slots((select salon from fix), (select usluga from fix),
    (select utorak from fix), (select emir from fix)) s
$$;

-- Polazno stanje je asercija: seed sa drugim korakom bi sekciju 1 ucinio besmislenom.
select is((select slot_step_minutes from public.salon_settings where salon_id = (select salon from fix)),
  15, 'Salonski korak je 15');
select is((select slot_step_minutes from public.services where id = (select usluga from fix)),
  null, 'Postojeca usluga nema svoj korak nakon migracije');

-- ---------------------------------------------------------------------------
-- 1–2. Korak u ponudi slotova
-- ---------------------------------------------------------------------------
create temporary table salonski as select pg_temp.pocetci() as t;
select ok('09:15'::time = any((select t from salonski)::time[]), 'Bez koraka usluge nudi se 09:15 (salonski 15)');

update public.services set slot_step_minutes = 30 where id = (select usluga from fix);
create temporary table trideset as select pg_temp.pocetci() as t;
select ok(cardinality((select t from trideset)) < cardinality((select t from salonski)),
  'Korak 30 daje manje pocetaka od koraka 15');
select ok(not ('09:15'::time = any((select t from trideset)::time[])), 'Korak 30 ne nudi 09:15');
select ok('09:30'::time = any((select t from trideset)::time[]), 'Korak 30 nudi 09:30');
select is((select count(*)::int from unnest((select t from trideset)) x
    where extract(minute from x) not in (0, 30)),
  0, 'Svi pocetci su na punom ili pola sata');

-- Usluga nadjacava salon i kad je njen korak manji.
update public.salon_settings set slot_step_minutes = 30 where salon_id = (select salon from fix);
update public.services set slot_step_minutes = 15 where id = (select usluga from fix);
select ok('09:15'::time = any(pg_temp.pocetci()), 'Korak usluge 15 nadjacava salonski 30');

update public.services set slot_step_minutes = null where id = (select usluga from fix);
select ok(not ('09:15'::time = any(pg_temp.pocetci())), 'Prazan korak usluge = salonski (30)');
update public.salon_settings set slot_step_minutes = 15 where salon_id = (select salon from fix);

-- ---------------------------------------------------------------------------
-- 3. Rezervacija provodi isti ugovor
-- ---------------------------------------------------------------------------
update public.services set slot_step_minutes = 30 where id = (select usluga from fix);
set local request.jwt.claims = '{"sub":"fd000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;
select throws_ok(
  format($$ select public.book_appointment(%L, 'fd200000-0000-4000-8000-000000000001', %L, %L, '09:15', %L) $$,
    (select salon from fix), (select usluga from fix), (select utorak from fix), (select emir from fix)),
  'PT409', null, 'Pocetak van koraka usluge se ne moze rezervisati');
select lives_ok(
  format($$ select public.book_appointment(%L, 'fd200000-0000-4000-8000-000000000001', %L, %L, '09:30', %L) $$,
    (select salon from fix), (select usluga from fix), (select utorak from fix), (select emir from fix)),
  'Pocetak na koraku usluge prolazi');

-- ---------------------------------------------------------------------------
-- 4. Upis koraka kroz RPC
-- ---------------------------------------------------------------------------
select is((public.update_service((select salon from fix), (select usluga from fix),
    'Muško šišanje', '', 'Šišanje', 15, 30, null, 20)).slot_step_minutes,
  20, 'update_service upisuje korak');
select is((public.update_service((select salon from fix), (select usluga from fix),
    'Muško šišanje', '', 'Šišanje', 15, 30, null, null)).slot_step_minutes,
  null, 'update_service sa NULL vraca salonski korak');
select throws_ok(
  format($$ select public.update_service(%L, %L, 'x', '', '', 1, 30, null, 0) $$,
    (select salon from fix), (select usluga from fix)),
  'PT400', null, 'Korak 0 je odbijen');
select throws_ok(
  format($$ select public.create_service(%L, 'x', '', '', 1, 30, null, 121) $$, (select salon from fix)),
  'PT400', null, 'Korak 121 je odbijen');
select is((public.create_service((select salon from fix), 'Brada', '', 'Brada', 5, 15, null, 15)).slot_step_minutes,
  15, 'create_service upisuje korak');
reset role;

-- Anon ne dohvata upis ni nakon promjene potpisa.
set local role anon;
select throws_ok(
  format($$ select public.create_service(%L, 'x', '', '', 1, 30, null, 15) $$, (select salon from fix)),
  '42501', null, 'anon ne moze zvati create_service');
reset role;

select * from finish();
rollback;
