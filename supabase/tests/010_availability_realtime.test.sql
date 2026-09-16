-- Javni Realtime signal osvježava availability bez curenja appointment podataka.
begin;
set local search_path = public, extensions;
select no_plan();

select ok(
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'availability_signals'
  ),
  'availability_signals je u Supabase Realtime publikaciji'
);

select columns_are(
  'public',
  'availability_signals',
  array['salon_id', 'revision_id'],
  'Signal nema termin, vrijeme, klijenta ni brojač prometa'
);

set local role anon;
select is(
  (select count(*)::int from public.availability_signals
   where salon_id = '550e8400-e29b-41d4-a716-446655440000'),
  1,
  'Anon može pročitati signal aktivnog salona'
);
select throws_ok(
  $$update public.availability_signals
    set revision_id = gen_random_uuid()
    where salon_id = '550e8400-e29b-41d4-a716-446655440000'$$,
  '42501',
  null,
  'Anon ne može lažirati availability signal'
);
reset role;

create temporary table signal_before as
select salon_id, revision_id
from public.availability_signals
where salon_id in (
  '550e8400-e29b-41d4-a716-446655440000',
  '550e8400-e29b-41d4-a716-446655440001'
);

insert into public.blocked_slots(
  salon_id, employee_id, date, start_time, end_time, reason
) values (
  '550e8400-e29b-41d4-a716-446655440000',
  null,
  current_date + 7,
  '12:00',
  '12:30',
  'Realtime test'
);

select isnt(
  (select revision_id from public.availability_signals
   where salon_id = '550e8400-e29b-41d4-a716-446655440000'),
  (select revision_id from signal_before
   where salon_id = '550e8400-e29b-41d4-a716-446655440000'),
  'Promjena blokade emituje novu reviziju za taj salon'
);

select is(
  (select revision_id from public.availability_signals
   where salon_id = '550e8400-e29b-41d4-a716-446655440001'),
  (select revision_id from signal_before
   where salon_id = '550e8400-e29b-41d4-a716-446655440001'),
  'Promjena jednog salona ne dira signal drugog salona'
);

select * from finish();
rollback;
