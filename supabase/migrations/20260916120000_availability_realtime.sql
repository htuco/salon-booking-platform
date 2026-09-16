-- Javni Realtime signal za availability bez izlaganja termina. Klijent ne smije
-- pretplatiti sve `appointments` redove: RLS mu ispravno pokazuje samo vlastite, pa
-- tuđa rezervacija ne bi osvježila listu slobodnih termina. Ova tabela emituje samo
-- neprozirnu reviziju salona; nakon događaja app ponovo poziva availability RPC.

create table public.availability_signals (
  salon_id uuid primary key references public.salons(id) on delete cascade,
  revision_id uuid not null default gen_random_uuid()
);

alter table public.availability_signals enable row level security;
revoke all on public.availability_signals from anon, authenticated;
grant all on public.availability_signals to service_role;
grant select on public.availability_signals to anon, authenticated;

create policy public_active on public.availability_signals
for select to anon, authenticated
using (private.salon_active(salon_id));

comment on table public.availability_signals is
  'Javni bezlični Realtime signal: promjena revision_id znači ponovo pozovi get_available_slots. Ne sadrži termin, klijenta, vrijeme ni ukupan broj promjena.';

create function private.bump_availability_signal() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new_salon uuid;
  v_old_salon uuid;
begin
  if tg_op <> 'DELETE' then
    v_new_salon := new.salon_id;
  end if;
  if tg_op <> 'INSERT' then
    v_old_salon := old.salon_id;
  end if;

  if v_new_salon is not null then
    insert into public.availability_signals(salon_id, revision_id)
    values (v_new_salon, gen_random_uuid())
    on conflict (salon_id) do update
      set revision_id = excluded.revision_id;
  end if;

  -- Salon se normalno ne mijenja, ali trigger ne smije ostaviti stari tenant bez
  -- signala ako platformska/admin migracija ipak premjesti red.
  if v_old_salon is not null and v_old_salon is distinct from v_new_salon then
    insert into public.availability_signals(salon_id, revision_id)
    values (v_old_salon, gen_random_uuid())
    on conflict (salon_id) do update
      set revision_id = excluded.revision_id;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.bump_availability_signal() from public;

do $$
declare
  t text;
begin
  foreach t in array array[
    'services',
    'employees',
    'employee_services',
    'working_hours',
    'appointments',
    'blocked_slots',
    'salon_settings'
  ] loop
    execute format(
      'create trigger availability_signal after insert or update or delete on public.%I '
      'for each row execute function private.bump_availability_signal()',
      t
    );
  end loop;
end;
$$;

-- Postojeći projekat može već imati salone prije ove migracije. Novi seed dobija red
-- čim ubaci prvi availability-relevantan podatak, ali ovaj insert pokriva i prazne salone.
insert into public.availability_signals(salon_id)
select id from public.salons
on conflict (salon_id) do nothing;

alter publication supabase_realtime add table public.availability_signals;
