-- Task 41: zakazivanje trazi pravi nalog; Supabase anonymous Auth nije nalog.
begin;
set local search_path = public, extensions;
select no_plan();

select hasnt_column(
  'public', 'salon_settings', 'allow_guest_booking',
  'Guest flag je uklonjen iz salonskih postavki, ne samo zakucan na false'
);

select is(
  (
    select count(*)::int
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'update_salon_settings'
  ),
  1,
  'Postoji tacno jedan update_salon_settings — stari potpis nije ostao kao overload'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.update_salon_settings(uuid, text, text, int, int, int, int, int, boolean, boolean)',
    'EXECUTE'
  ),
  'Admin aplikacija ima execute nad novim potpisom postavki'
);

insert into auth.users(
  id, email, raw_app_meta_data, raw_user_meta_data, is_anonymous
) values
(
  'f1000000-0000-4000-8000-000000000001', null,
  '{"providers":["anonymous"]}', '{}', true
),
(
  'f1000000-0000-4000-8000-000000000002', 'pravi-klijent@task41.invalid',
  '{"providers":["email"]}', '{}', false
);

set local request.jwt.claims =
  '{"sub":"f1000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":true,"app_metadata":{"providers":["anonymous"]}}';
set local request.headers =
  '{"x-salon-id":"550e8400-e29b-41d4-a716-446655440000"}';
set local role authenticated;

select is(private.is_client(), false,
  'Supabase anonymous Auth sesija nije klijentski nalog');
select throws_ok($$
  select public.ensure_customer('550e8400-e29b-41d4-a716-446655440000')
$$, '42501', 'Nije dozvoljeno',
  'Anonimna Auth sesija ne moze ni napraviti customers red');

reset role;

-- Fixtura namjerno pravi customers red servisnim putem: tako dokazujemo da
-- `book_appointment` odbija i zateceni anonimni identitet, a ne samo da prethodni korak
-- nije uspio napraviti red.
insert into public.customers(id, salon_id, auth_identity_id, name)
select
  'f1000000-0000-4000-8000-000000000011',
  '550e8400-e29b-41d4-a716-446655440000',
  ai.id,
  'Anonimni test'
from public.auth_identities ai
where ai.supabase_user_id = 'f1000000-0000-4000-8000-000000000001';

set local role authenticated;
select throws_ok($$
  select public.book_appointment(
    '550e8400-e29b-41d4-a716-446655440000',
    'f1000000-0000-4000-8000-000000000011',
    '10000000-0000-4000-8000-000000000001',
    (date_trunc('week', (now() at time zone 'Europe/Sarajevo')) + interval '8 days')::date,
    '15:00',
    '20000000-0000-4000-8000-000000000001'
  )
$$, '42501', 'Nije dozvoljeno',
  'Anonimna Auth sesija ne moze rezervisati ni sa zatecenim customers redom');
reset role;

select is(
  (
    select count(*)::int
    from public.appointments
    where customer_id = 'f1000000-0000-4000-8000-000000000011'
  ),
  0,
  'Odbijeni anonimni poziv nije napravio termin'
);

set local request.jwt.claims =
  '{"sub":"f1000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"providers":["email"]}}';
set local role authenticated;
select is(private.is_client(), true,
  'Email nalog i dalje prolazi centralni klijentski guard');
reset role;

select * from finish();
rollback;
