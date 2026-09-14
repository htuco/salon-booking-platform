-- Availability engine i rezervacija bez utrke. Task 05.
-- Sve se vrti u transakciji koja se na kraju ponistava.
begin;
set local search_path = public, extensions;
select no_plan();

-- Datum je izveden, ne fiksan: max_advance_booking_days je 30, pa bi fiksan
-- datum iz buducnosti jednog dana poceo vracati praznu listu i test bi "prosao"
-- iz pogresnog razloga.
create temporary table tfix as
select
  (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '7 days')::date as mon,
  '550e8400-e29b-41d4-a716-446655440000'::uuid as salon,
  '10000000-0000-4000-8000-000000000001'::uuid as svc30,   -- Musko sisanje, 30 min
  '20000000-0000-4000-8000-000000000001'::uuid as emir,
  '20000000-0000-4000-8000-000000000002'::uuid as amar;
-- Dio testova se izvrsava kao rola authenticated, a temp tabelu je napravio
-- superuser — bez granta ti pozivi padaju na pravima, ne na logici.
grant select on tfix to public;

insert into public.customers(id, salon_id, name)
values ('cc000000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000', 'Test Klijent');

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('aa000000-0000-4000-8000-000000000001', 'admin-a@avail.invalid',
 '{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}', '{}'),
('aa000000-0000-4000-8000-000000000002', 'klijent@avail.invalid', '{"providers":["email"]}', '{}');
insert into public.users(id, salon_id, name, email, role) values
('aa000000-0000-4000-8000-000000000001', '550e8400-e29b-41d4-a716-446655440000',
 'Vlasnik A', 'admin-a@avail.invalid', 'salon_admin');

-- ---------------------------------------------------------------------------
-- Osnovni raspored
-- ---------------------------------------------------------------------------
-- Pon 09:00-17:00, korak 15 min, usluga 30 min => 09:00..16:30 = 31 slot po
-- radniku, dva radnika = 62 reda.
select is(
  (select count(*)::int from public.get_available_slots(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix))),
  62, 'Ponedjeljak: 31 slot po radniku za oba radnika');

select is(
  (select count(distinct start_time)::int from public.get_available_slots(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix))),
  31, 'Razlicitih vremena je 31 — "bilo koji radnik" prikazuje toliko');

select is(
  (select count(*)::int from public.get_available_slots(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix), (select emir from tfix))),
  31, 'Filter po radniku vraca samo njegove slotove');

select is(
  (select count(*)::int from public.get_available_slots(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix) + 6)),
  0, 'Nedjelja je zatvorena — nema slotova');

-- **`mon - 14`, ne `mon - 7`.** `mon` je ponedjeljak **sljedece** sedmice, pa je `mon - 7`
-- ponedjeljak tekuce sedmice — a to je ponedjeljkom **danas**, ne proslost. Test je zato
-- padao svakog ponedjeljka (62 slota umjesto 0) i prolazio ostalih sest dana. Nadjeno
-- pokretanjem poslije ponoci; CI je blokiran, pa se nije imalo gdje drugo vidjeti.
--
-- `mon - 14` je ponedjeljak **prosle** sedmice: uvijek strogo u proslosti, i uvijek radni
-- dan. Drugi dio je vazan koliko i prvi — da je izabran nedjeljni datum, asercija bi
-- vracala 0 zato sto je salon zatvoren, a ne zato sto je datum prosao, i prolazila bi i nad
-- pokvarenom funkcijom.
select is(
  (select count(*)::int from public.get_available_slots(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix) - 14)),
  0, 'Proslost ne vraca slotove');

select is(
  (select count(*)::int from public.get_available_slots(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix) + 60)),
  0, 'Dalje od max_advance_booking_days nema slotova');

select is(
  (select count(*)::int from public.get_available_slots(
    (select salon from tfix), '00000000-0000-4000-8000-0000000000ff', (select mon from tfix))),
  0, 'Nepostojeca usluga ne vraca nista');

-- ---------------------------------------------------------------------------
-- Zauzeca
-- ---------------------------------------------------------------------------
-- Termin 10:00-10:30 uz buffer 5 zauzima [10:00, 10:35). Kandidat traje 35 min
-- (30 + buffer), pa se preklapa kad je pocetak > 09:25 i < 10:35:
-- 09:30, 09:45, 10:00, 10:15, 10:30 = pet kandidata. Prva verzija testa je
-- ocekivala cetiri jer je zaboravila da i kandidat nosi buffer unaprijed.
insert into public.appointments(
  salon_id, service_id, employee_id, customer_id, customer_name,
  date, start_time, end_time, buffer_minutes, status)
values (
  (select salon from tfix), (select svc30 from tfix), (select emir from tfix),
  'cc000000-0000-4000-8000-000000000001', 'Test Klijent',
  (select mon from tfix), '10:00', '10:30', 5, 'confirmed');

select is(
  (select count(*)::int from public.get_available_slots(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix), (select emir from tfix))),
  26, 'Potvrdjen termin uklanja 5 kandidata (kandidat i termin nose buffer)');

select is(
  (select count(*)::int from public.get_available_slots(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix), (select amar from tfix))),
  31, 'Termin jednog radnika ne dira drugog');

select ok(
  not exists (
    select 1 from public.get_available_slots(
      (select salon from tfix), (select svc30 from tfix), (select mon from tfix), (select emir from tfix))
    where start_time = '10:30'),
  '10:30 nije slobodno jer buffer prethodnog termina traje do 10:35');

update public.appointments set status = 'pending'
where date = (select mon from tfix) and employee_id = (select emir from tfix);
select is(
  (select count(*)::int from public.get_available_slots(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix), (select emir from tfix))),
  26, 'Pending blokira slot isto kao confirmed');

update public.appointments set status = 'cancelled'
where date = (select mon from tfix) and employee_id = (select emir from tfix);
select is(
  (select count(*)::int from public.get_available_slots(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix), (select emir from tfix))),
  31, 'Otkazan termin oslobadja slot');

delete from public.appointments where date = (select mon from tfix);

-- Blokada 12:00-13:00 uklanja pocetke 11:30..12:45 = 6 kandidata.
insert into public.blocked_slots(salon_id, employee_id, date, start_time, end_time, reason)
values ((select salon from tfix), (select emir from tfix), (select mon from tfix), '12:00', '13:00', 'pauza');
select is(
  (select count(*)::int from public.get_available_slots(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix), (select emir from tfix))),
  25, 'Blokada uklanja 6 kandidata');
delete from public.blocked_slots where date = (select mon from tfix);

-- Pauza u radnom vremenu salona vazi za oba radnika: 62 - 12 = 50.
update public.working_hours
set break_start_time = '12:00', break_end_time = '13:00'
where salon_id = (select salon from tfix)
  and employee_id is null
  and day_of_week = extract(isodow from (select mon from tfix))::int;
select is(
  (select count(*)::int from public.get_available_slots(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix))),
  50, 'Pauza uklanja iste kandidate kod oba radnika');
update public.working_hours
set break_start_time = null, break_end_time = null
where salon_id = (select salon from tfix) and employee_id is null;

-- min_advance_booking_hours: danasnji slotovi nikad nisu blizi od 2 sata.
select ok(
  not exists (
    select 1 from public.get_available_slots(
      (select salon from tfix), (select svc30 from tfix),
      (now() at time zone 'Europe/Sarajevo')::date) s
    where ((now() at time zone 'Europe/Sarajevo')::date + s.start_time) at time zone 'Europe/Sarajevo'
          < now() + interval '2 hours'),
  'Danas nema slota blizeg od min_advance_booking_hours');

-- ---------------------------------------------------------------------------
-- date_only vertikale
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from public.get_available_dates(
    (select salon from tfix), (select svc30 from tfix), (select mon from tfix), (select mon from tfix) + 6)),
  6, 'Sedmica daje 6 radnih dana — nedjelja otpada');

select ok(
  not exists (
    select 1 from public.get_available_dates(
      (select salon from tfix), (select svc30 from tfix), (select mon from tfix), (select mon from tfix) + 6)
    where extract(isodow from available_date) = 7),
  'get_available_dates ne vraca nedjelju');

-- ---------------------------------------------------------------------------
-- Rezervacija
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"aa000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local role authenticated;

-- **Pozivalac je ovdje `salon_admin`, pa je ishod `confirmed`, ne `pending`** (task 24).
-- `pending` znaci "salon jos nije odgovorio"; kad salon sam upisuje termin, odgovor je sam
-- upis. Do taska 24 je i admin dobijao `pending`, pa je termin cekao potvrdu od onoga ko ga
-- je vec potvrdio i istekao bi kroz `pending_expires_at`.
--
-- Klijentski `pending` drzi `004_cancel_appointment.test.sql`, gdje rezervise pravi klijent.
select is(
  (select status::text from public.book_appointment(
    '550e8400-e29b-41d4-a716-446655440000', 'cc000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001', (select mon from tfix), '11:00',
    '20000000-0000-4000-8000-000000000001')),
  'confirmed', 'Admin rezervacija nastaje kao confirmed — salon ne ceka potvrdu od sebe');

reset role;
select is(
  (select end_time from public.appointments where date = (select mon from tfix) and start_time = '11:00'),
  '11:30'::time, 'end_time je pocetak + trajanje usluge');
select is(
  (select buffer_minutes from public.appointments where date = (select mon from tfix) and start_time = '11:00'),
  5, 'Buffer se pamti na terminu, ne cita se naknadno iz postavki');
-- Rok isteka nosi samo `pending`. Admin termin je odmah `confirmed`, pa nema sta cekati —
-- ostavljen `pending_expires_at` bi znacio da ga scheduler iz taska 25 gleda kao kandidata
-- za istek. Da rok stvarno stoji na klijentskom terminu drzi `004_cancel_appointment`.
select ok(
  (select pending_expires_at is null from public.appointments
   where date = (select mon from tfix) and start_time = '11:00'),
  'Admin termin nema rok isteka — rok nosi samo pending');

set local role authenticated;
-- Isti slot, isti radnik: re-validacija ga vise ne nalazi u listi.
select throws_ok($$
  select public.book_appointment(
    '550e8400-e29b-41d4-a716-446655440000', 'cc000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    (select mon from tfix), '11:00', '20000000-0000-4000-8000-000000000001')
$$, 'PT409', 'Termin je upravo zauzet', 'Dvostruka rezervacija istog slota vraca PT409 (HTTP 409)');

-- Bez izabranog radnika server dodjeljuje slobodnog, umjesto da odbije.
select is(
  (select employee_id from public.book_appointment(
    '550e8400-e29b-41d4-a716-446655440000', 'cc000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001', (select mon from tfix), '11:00')),
  '20000000-0000-4000-8000-000000000002'::uuid,
  '"Bilo koji radnik" dobija drugog slobodnog, ne pada na zauzetom');

select throws_ok($$
  select public.book_appointment(
    '550e8400-e29b-41d4-a716-446655440000', 'cc000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001', (select mon from tfix), '20:00')
$$, 'PT409', 'Termin je upravo zauzet', 'Termin van radnog vremena se ne moze rezervisati');

select throws_ok($$
  select public.book_appointment(
    '550e8400-e29b-41d4-a716-446655440000', 'cc000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-0000000000ff', (select mon from tfix), '13:00')
$$, 'PT404', 'Usluga ne postoji ili nije aktivna', 'Nepostojeca usluga vraca PT404');

-- Klijent koji nije vlasnik tog customer reda ne smije rezervisati u njegovo ime.
set local request.jwt.claims = '{"sub":"aa000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"providers":["email"]}}';
select throws_ok($$
  select public.book_appointment(
    '550e8400-e29b-41d4-a716-446655440000', 'cc000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001', (select mon from tfix), '14:00')
$$, '42501', 'Nije dozvoljeno', 'Tudji klijent se ne moze rezervisati (403)');

reset role;

-- ---------------------------------------------------------------------------
-- Zastita od utrke na nivou baze
-- ---------------------------------------------------------------------------
-- Ovo je jedini test koji zaobilazi funkciju: dokazuje da ni direktan upis
-- (admin panel, migracija, ljudska greska) ne moze napraviti preklapanje.
select throws_ok($$
  insert into public.appointments(
    salon_id, service_id, employee_id, customer_id, customer_name,
    date, start_time, end_time, buffer_minutes, status)
  values (
    '550e8400-e29b-41d4-a716-446655440000', '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001', 'cc000000-0000-4000-8000-000000000001', 'Test Klijent',
    (select mon from tfix), '11:15', '11:45', 5, 'confirmed')
-- Cetiri argumenta: treci je poruka greske, a ne opis testa. Sa tri argumenta
-- pgTAP bi poredio opis sa Postgresovom porukom i test bi pao iako je kod
-- ispravan. NULL znaci "ne provjeravaj tekst poruke", jer je on Postgresov.
$$, '23P01', NULL, 'Direktan preklapajuci upis pada na exclusion constraintu');

select lives_ok($$
  insert into public.appointments(
    salon_id, service_id, employee_id, customer_id, customer_name,
    date, start_time, end_time, buffer_minutes, status)
  values (
    '550e8400-e29b-41d4-a716-446655440000', '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001', 'cc000000-0000-4000-8000-000000000001', 'Test Klijent',
    (select mon from tfix), '11:35', '12:05', 5, 'confirmed')
$$, 'Termin koji pocinje tacno nakon buffera prolazi');

select * from finish();
rollback;
