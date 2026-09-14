-- Pravila i politika privatnosti: ko sta cita i, vaznije, ko sta **smije napisati**. Task 21.
--
-- Dvije granice se ovdje dokazuju, i druga je cijeli razlog zasto tabele dvije:
--   1. `anon` cita pravila **bez prijave** (prijava je zadnji korak flowa), ali samo za aktivan
--      salon;
--   2. **`salon_admin` ne moze pisati po `app_policies`.** Tu stoji tekst o obradi licnih
--      podataka, koji obavezuje firmu pod cijim imenom app stoji u storeu. Kad bi tenant mogao
--      mijenjati tu recenicu, firma bi odgovarala za tvrdnju koju ne vidi. Politika koja to
--      drzi je `super_manage`; asercije nize padaju ako se oslabi na `private.is_admin(...)`.
--
-- Obrazlozenje oblika: `docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md`.
begin;
set local search_path = public, extensions;
select no_plan();

-- Fixture: neaktivan salon sa svojom sekcijom pravila. Sekcija je uredna i potpuna namjerno —
-- dokazuje da je ono sto je krije `private.salon_active(...)`, a ne nedostatak sadrzaja.
insert into public.salons(id,name,slug,city,status,vertical_pack_key) values
('550e8400-e29b-41d4-a716-446655440097','Neaktivni pravila','neaktivni-pravila','Vitez','inactive','barber');
insert into public.salon_policies(salon_id,sort_order,title,body) values
('550e8400-e29b-41d4-a716-446655440097',20,'Otkazivanje','Sekcija salona koji nije aktivan.');

insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data) values
('a0000000-0000-4000-8000-000000000021','admin-a@pravila.invalid','{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}','{}'),
('a0000000-0000-4000-8000-000000000022','admin-b@pravila.invalid','{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}','{}'),
('a0000000-0000-4000-8000-000000000023','klijent@pravila.invalid','{"providers":["email"]}','{"name":"Klijent"}');
insert into public.users(id,salon_id,name,email,role) values
('a0000000-0000-4000-8000-000000000021','550e8400-e29b-41d4-a716-446655440000','Vlasnik A','admin-a@pravila.invalid','salon_admin'),
('a0000000-0000-4000-8000-000000000022','550e8400-e29b-41d4-a716-446655440001','Vlasnik B','admin-b@pravila.invalid','salon_admin');

-- ---------------------------------------------------------------------------
-- Struktura
-- ---------------------------------------------------------------------------
select ok(
  (select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='app_policies'),
  'RLS je ukljucen na app_policies');
select ok(
  (select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname='salon_policies'),
  'RLS je ukljucen na salon_policies');

-- `app_policies` je namjeran izuzetak od pravila „svaka nova tabela nosi `salon_id`". Straza
-- stoji da se kolona ne doda usput — dodana bi tiho pretvorila platformski tekst u tenantski.
select hasnt_column('public','app_policies','salon_id',
  'app_policies namjerno nema salon_id — platformski tekst je isti u svakoj brandiranoj app-i');

-- Politika privatnosti je u cijelosti platformska. `check` to provodi u bazi; komentar ne bi.
select throws_ok(
  $$insert into public.salon_policies(salon_id,document,sort_order,title,body)
    values('550e8400-e29b-41d4-a716-446655440000','privacy',99,'Svoja privatnost','Tekst.')$$,
  '23514', null, 'Salon ne moze imati sekciju politike privatnosti');

select throws_ok(
  $$insert into public.app_policies(document,sort_order,title,body) values('terms',10,'Duplikat','Tekst.')$$,
  '23505', null, 'Dvije platformske sekcije na istoj poziciji su odbijene');
select throws_ok(
  $$insert into public.app_policies(document,sort_order,title,body) values('terms',99,'   ','Tekst.')$$,
  '23514', null, 'Prazan naslov sekcije je odbijen');
select throws_ok(
  $$insert into public.app_policies(document,sort_order,title,body) values('terms',99,'Naslov','   ')$$,
  '23514', null, 'Prazno tijelo sekcije je odbijeno');
select throws_ok(
  $$insert into public.app_policies(document,sort_order,title,body) values('terms',0,'Naslov','Tekst.')$$,
  '23514', null, 'sort_order 0 je odbijen — numeracija na ekranu krece od 1');

-- „Zadnja izmjena" na `/terms` je `max(updated_at)`. Bez triggera bi kolona zauvijek pisala
-- datum unosa, a ekran tvrdio da se pravila nikad nisu mijenjala.
select ok(
  (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
   where c.relname in ('app_policies','salon_policies') and t.tgname='touch_updated_at') = 2,
  'Obje tabele imaju touch_updated_at trigger');

-- ---------------------------------------------------------------------------
-- anon — pravila se citaju prije prijave
-- ---------------------------------------------------------------------------
set local role anon;

select is((select count(*)::int from public.app_policies where document='terms'),3,
  'Anon vidi tri platformske sekcije pravila');
select is((select count(*)::int from public.app_policies where document='privacy'),9,
  'Anon vidi devet sekcija politike privatnosti');
select is((select count(*)::int from public.salon_policies),5,
  'Anon vidi salonske sekcije oba aktivna salona (3 + 2), i nijednu vise');
select is((select count(*)::int from public.salon_policies
           where salon_id='550e8400-e29b-41d4-a716-446655440097'),0,
  'Anon ne vidi sekciju neaktivnog salona');

-- Spojena lista koju ekran numerise `01..06` za barbera: platformske 10/40/50 i salonske
-- 20/30/60 se isprepliću upravo kako handoff crta.
select results_eq(
  $$select title from (
      select sort_order,title from public.app_policies where document='terms'
      union all
      select sort_order,title from public.salon_policies
       where salon_id='550e8400-e29b-41d4-a716-446655440000'
    ) s order by sort_order$$,
  $$values ('Zakazivanje'),('Otkazivanje'),('Kašnjenje'),('Cijene'),('Vaši podaci'),('Kontakt')$$,
  'Spojene sekcije barbera idu redom sa 15-pravila-koristenja.png');

-- Beauty nema „Kontakt" jer u seedu nema ni telefon ni mail. Ekran mora podnijeti kraci
-- dokument — to je uredno stanje, ne greska.
select is((select count(*)::int from public.salon_policies
           where salon_id='550e8400-e29b-41d4-a716-446655440001'),2,
  'Beauty ima dvije salonske sekcije — ekran radi i sa nepotpunim setom');

select throws_ok($$insert into public.app_policies(document,sort_order,title,body) values('terms',99,'Napadac','Tekst.')$$,
  '42501','permission denied for table app_policies','Anon ne moze pisati platformska pravila');
select throws_ok($$update public.app_policies set body='Izmijenjeno'$$,
  '42501','permission denied for table app_policies','Anon ne moze mijenjati platformska pravila');
select throws_ok($$delete from public.salon_policies$$,
  '42501','permission denied for table salon_policies','Anon ne moze brisati salonske sekcije');
reset role;

-- ---------------------------------------------------------------------------
-- Klijent — prijava ne daje nista preko anon-a
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"a0000000-0000-4000-8000-000000000023","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local role authenticated;

select is((select count(*)::int from public.salon_policies),5,'Klijent vidi isto sto i anon');
select throws_ok(
  $$insert into public.salon_policies(salon_id,sort_order,title,body)
    values('550e8400-e29b-41d4-a716-446655440000',80,'Moja pravila','Tekst klijenta.')$$,
  '42501', null, 'Klijent ne moze dodati sekciju pravila');
-- `authenticated` **ima** update grant, pa ga ne zaustavlja grant nego odsustvo politike: RLS
-- filtrira sve redove i update pogodi nula. Nula redova nije greska u Postgresu, pa asercija
-- ide na ucinak — v. `.claude/docs/security.md`, „update sa klijenta ne baca".
select results_eq($$update public.app_policies set body='Izmijenjeno' returning id$$,
  $$select null::uuid where false$$,
  'Klijentov update nad platformskim pravilima ne pogadja nijedan red');
reset role;

-- ---------------------------------------------------------------------------
-- Vlasnik salona — svoje da, tudje ne, platformsko nikako
-- ---------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"a0000000-0000-4000-8000-000000000021","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440000"}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
set local role authenticated;

select lives_ok(
  $$insert into public.salon_policies(salon_id,sort_order,title,body)
    values('550e8400-e29b-41d4-a716-446655440000',70,'Poklon bonovi','Bonovi vrijede godinu dana.')$$,
  'Vlasnik A moze dodati svoju sekciju pravila');
select results_eq(
  $$update public.salon_policies set body='Izmijenjeno' where salon_id='550e8400-e29b-41d4-a716-446655440000' and sort_order=70 returning sort_order$$,
  $$values (70)$$,
  'Vlasnik A moze mijenjati svoju sekciju');

-- **Ovo je negativan test zbog kojeg tabele i jesu dvije.** Ako `super_manage` ikad postane
-- `private.is_admin(...)`, oba reda ispod prestanu vaziti i tenant moze prepisati tekst o
-- obradi podataka koji obavezuje firmu.
select throws_ok(
  $$insert into public.app_policies(document,sort_order,title,body) values('terms',99,'Moje pravilo','Tekst salona.')$$,
  '42501', null, 'Vlasnik salona ne moze dodati platformsku sekciju');
select results_eq(
  $$update public.app_policies set body='Tekst koji salon pise umjesto firme' returning id$$,
  $$select null::uuid where false$$,
  'Vlasnik salona ne moze izmijeniti nijednu platformsku sekciju');
select results_eq(
  $$delete from public.app_policies where document='privacy' returning id$$,
  $$select null::uuid where false$$,
  'Vlasnik salona ne moze obrisati politiku privatnosti');

-- `x-salon-id` je namjerno postavljen na salon B: header bira kontekst, ne daje prava (ADR-0003).
select results_eq(
  $$update public.salon_policies set body='Tudje' where salon_id='550e8400-e29b-41d4-a716-446655440001' returning id$$,
  $$select null::uuid where false$$,
  'Vlasnik A ne moze mijenjati sekcije salona B ni sa njegovim headerom');
select is((select count(*)::int from public.salon_policies
           where salon_id='550e8400-e29b-41d4-a716-446655440097'),0,
  'Vlasnik A ne vidi sekcije neaktivnog tudjeg salona');
reset role;

set local request.jwt.claims = '{"sub":"a0000000-0000-4000-8000-000000000022","role":"authenticated","app_metadata":{"role":"salon_admin","salon_id":"550e8400-e29b-41d4-a716-446655440001"}}';
set local role authenticated;
select results_eq(
  $$delete from public.salon_policies where salon_id='550e8400-e29b-41d4-a716-446655440000' returning id$$,
  $$select null::uuid where false$$,
  'Vlasnik B ne moze obrisati sekciju salona A');
reset role;

select * from finish();
rollback;
