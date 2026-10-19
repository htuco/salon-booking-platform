-- Kasni sudar na `unique(salon_id, phone)` — task 66, pregled PR-a #136.
--
-- Prava trka traži dvije sesije: drugi upis zauzme broj **poslije** provjere „nijedan drugi
-- klijent ne nosi ovaj broj", a prije upisa. U jednoj sesiji se isti raspored glumi
-- `before` triggerom koji tačno tada ubaci telefonskog klijenta sa istim brojem. Trigger
-- postoji samo u ovoj transakciji.
--
-- Granice:
--   1. trigger popunjavanja (prijava) preživi kasni sudar: broj se preskače, ime ostaje;
--   2. `ensure_customer` (slanje termina) preživi kasni sudar: klijent nastaje bez broja;
--   3. `legal_versions()` je `stable`, ne `immutable`;
--   4. petlja popunjavanja ponovo provjerava vlasnika i prazan telefon: salonova ispravka broja
--      koja stigne dok petlja radi ostaje (revizija pregleda #136).
--
-- Bez `exception when unique_violation` iz `20261019120000` granice 1 i 2 padaju na
-- `lives_ok`.
begin;
set local search_path = public, extensions;
select no_plan();

-- ---------------------------------------------------------------------------
-- 3. `legal_versions()` — stable
-- ---------------------------------------------------------------------------
select is((select provolatile from pg_proc where oid = 'public.legal_versions()'::regprocedure),
  's'::"char", 'legal_versions je stable: verzija se mijenja migracijom');
select is((select (terms, privacy) from public.legal_versions()), (1, 1),
  'Vrijednost je ista kao prije');

-- ---------------------------------------------------------------------------
-- Upadica: telefonski klijent sa istim brojem, ubačen tačno prije upisa
-- ---------------------------------------------------------------------------
create function pg_temp.upadica() returns trigger language plpgsql as $$
begin
  insert into public.customers(salon_id, name, phone)
  values (new.salon_id, 'Upadica', new.phone);
  return new;
end $$;

insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('f7000000-0000-4000-8000-000000000001', 'kasni@trka66.invalid', '{"providers":["email"]}',
 '{"full_name":"Kasni Kasnić","terms_accepted":true}'),
('f7000000-0000-4000-8000-000000000002', 'novi@trka66.invalid', '{"providers":["email"]}',
 '{"full_name":"Novi Nović","phone":"+387 63 777 777","terms_accepted":true}');

-- ---------------------------------------------------------------------------
-- 1. Prijava: popunjavanje adresara preživi kasni sudar
-- ---------------------------------------------------------------------------
-- „Kasni" ima red u Vitezu bez telefona; broj dobija tek „Dopuni profil".
set local request.jwt.claims = '{"sub":"f7000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local role authenticated;
create temporary table kasni as
  select (public.ensure_customer('550e8400-e29b-41d4-a716-446655440000')).id as id;
reset role;

update public.customers set name = 'Klijent' where id = (select id from kasni);

create trigger upadica_update before update of phone on public.customers
for each row when (old.phone is null and new.phone is not null)
execute function pg_temp.upadica();

select lives_ok($$
  update public.auth_identities set phone = '+387 63 555 555'
  where supabase_user_id = 'f7000000-0000-4000-8000-000000000001'
$$, 'Kasni sudar na telefonu ne obara upis identiteta (a time ni prijavu)');
select is((select (name, phone) from public.customers where id = (select id from kasni)),
  ('Kasni Kasnić'::text, null::text),
  'Broj je preskočen kao kod vidljivog sudara, a ime je ipak popunjeno');
select is((select count(*)::int from public.customers where name = 'Upadica'), 0,
  'Pod-blok je vratio i upadicu — ništa polovično ne ostaje');

drop trigger upadica_update on public.customers;

-- ---------------------------------------------------------------------------
-- 2. Slanje termina: `ensure_customer` preživi kasni sudar
-- ---------------------------------------------------------------------------
create trigger upadica_insert before insert on public.customers
for each row when (new.auth_identity_id is not null and new.phone is not null)
execute function pg_temp.upadica();

set local request.jwt.claims = '{"sub":"f7000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local role authenticated;
select lives_ok($$ select public.ensure_customer('550e8400-e29b-41d4-a716-446655440000') $$,
  'Kasni sudar ne obara ensure_customer (a time ni slanje termina)');
reset role;

select is((select (c.name, c.phone) from public.customers c
    join public.auth_identities i on i.id = c.auth_identity_id
    where i.supabase_user_id = 'f7000000-0000-4000-8000-000000000002'
      and c.salon_id = '550e8400-e29b-41d4-a716-446655440000'),
  ('Novi Nović'::text, null::text),
  'Klijent nastaje sa imenom, bez broja koji je zauzet');

drop trigger upadica_insert on public.customers;

-- ---------------------------------------------------------------------------
-- 4. Salonova ispravka koja stigne usred petlje ostaje
-- ---------------------------------------------------------------------------
-- „Dvojni" ima red u Vitezu i u Beautyju, oba bez telefona. Kad petlja upiše broj u prvi red,
-- trigger glumi admina drugog salona koji tačno tada upiše svoju ispravku u drugi red. Petlja
-- je drugi red vidjela prazan (kursor), ali upis mora vidjeti stanje **sada**.
insert into auth.users(id, email, raw_app_meta_data, raw_user_meta_data) values
('f7000000-0000-4000-8000-000000000003', 'dvojni@trka66.invalid', '{"providers":["email"]}',
 '{"full_name":"Dvojni Dvojić","terms_accepted":true}');

set local request.jwt.claims = '{"sub":"f7000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
select public.ensure_customer('550e8400-e29b-41d4-a716-446655440000');
set local request.headers = '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440001"}';
select public.ensure_customer('550e8400-e29b-41d4-a716-446655440001');
reset role;

create function pg_temp.salon_ispravlja() returns trigger language plpgsql as $$
begin
  -- Bez rekurzije: ispravka upisuje drugi broj, a `when` triggera propušta samo broj identiteta.
  update public.customers set phone = '+387 66 000 000'
  where auth_identity_id = new.auth_identity_id and id <> new.id and phone is null;
  return null;
end $$;
create trigger salon_ispravlja after update of phone on public.customers
for each row when (new.phone = '+387 63 888 888')
execute function pg_temp.salon_ispravlja();

update public.auth_identities set phone = '+387 63 888 888'
where supabase_user_id = 'f7000000-0000-4000-8000-000000000003';

select is((select array_agg(c.phone order by c.phone) from public.customers c
    join public.auth_identities i on i.id = c.auth_identity_id
    where i.supabase_user_id = 'f7000000-0000-4000-8000-000000000003'),
  array['+387 63 888 888', '+387 66 000 000'],
  'Jedan red dobija broj identiteta, a salonova ispravka u drugom ostaje');

drop trigger salon_ispravlja on public.customers;

select * from finish();
rollback;
