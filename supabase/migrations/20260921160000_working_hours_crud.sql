-- Task 34: radno vrijeme, pauze i blokade prestaju biti podatak koji se mijenja samo u bazi.
--
-- Do sada je nad obje tabele stajao pun grant iz init migracije, pa je admin mogao pisati
-- direktno. Task 31 je to provjerio pozivom i ostavio odluku ovdje: „samo kroz rpc" je bila
-- konvencija, ne tvrdnja baze. Sada jeste tvrdnja — grant se oduzima, kao sto ga je task 24
-- oduzeo nad `appointments`, a task 33 nad `employees`.
revoke insert, update, delete on public.working_hours, public.blocked_slots
  from authenticated;

-- Sedmica se pise u cjelini, jedan red po danu.
--
-- Engine (`get_available_slots`) cita **odsustvo reda kao zatvoreno**, ne kao „nije
-- podeseno". Zato djelimican upis tiho zatvara dane koje ekran nije poslao, i zato ulaz
-- nije jedan dan nego svih sedam odjednom.
create type public.working_hours_input as (
  day_of_week integer,
  start_time time,
  end_time time,
  break_start_time time,
  break_end_time time,
  is_closed boolean
);

create function private.validate_working_hours(
  p_salon_id uuid, p_employee_id uuid, p_days public.working_hours_input[]
) returns void language plpgsql security definer set search_path = '' as $fn$
declare v_day public.working_hours_input;
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  -- Radnik iz drugog salona i nepostojeci radnik daju istu gresku: bez otkrivanja tudjeg osoblja.
  if p_employee_id is not null and not exists(
    select 1 from public.employees e where e.salon_id = p_salon_id and e.id = p_employee_id
  ) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_days is null or array_length(p_days, 1) is distinct from 7 then
    raise exception 'Sedmica mora imati tacno sedam dana' using errcode = 'PT400';
  end if;
  if exists(
    select 1 from unnest(p_days) d group by d.day_of_week having count(*) > 1
  ) or exists(
    select 1 from generate_series(1, 7) g
    where not exists(select 1 from unnest(p_days) d where d.day_of_week = g)
  ) then
    raise exception 'Svaki dan od 1 do 7 mora biti tacno jednom' using errcode = 'PT400';
  end if;

  foreach v_day in array p_days loop
    if v_day.is_closed is not true then
      if v_day.start_time is null or v_day.end_time is null then
        raise exception 'Otvoren dan mora imati pocetak i kraj' using errcode = 'PT400';
      end if;
      if v_day.end_time <= v_day.start_time then
        raise exception 'Kraj mora biti poslije pocetka' using errcode = 'PT400';
      end if;
      -- Pauza je ili cijela ili je nema; check constraint isto trazi, ali poruka odavde je citljiva.
      if (v_day.break_start_time is null) is distinct from (v_day.break_end_time is null) then
        raise exception 'Pauza mora imati i pocetak i kraj' using errcode = 'PT400';
      end if;
      if v_day.break_start_time is not null and not (
        v_day.break_start_time >= v_day.start_time
        and v_day.break_end_time <= v_day.end_time
        and v_day.break_end_time > v_day.break_start_time
      ) then
        raise exception 'Pauza mora biti unutar radnog vremena' using errcode = 'PT400';
      end if;
    end if;
  end loop;
end;
$fn$;
revoke all on function private.validate_working_hours(uuid, uuid, public.working_hours_input[])
  from public, anon, authenticated;

-- Termini koji ispadaju iz novog radnog vremena — **ne brisu se i ne pomjeraju**.
--
-- DoD taska to trazi izricito: admin ih mora vidjeti. Funkcija je `stable` i cita, pa je
-- ekran moze pozvati i **prije** snimanja, da upozorenje dodje prije posljedice.
create function public.working_hours_conflicts(
  p_salon_id uuid, p_employee_id uuid, p_days public.working_hours_input[]
) returns table (
  appointment_id uuid, date date, start_time time, end_time time,
  customer_name text, employee_name text, reason text
) language plpgsql stable security definer set search_path = '' as $fn$
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  return query
  with novo as (select * from unnest(p_days))
  select a.id, a.date, a.start_time, a.end_time, a.customer_name, a.employee_name,
    case
      when n.is_closed then 'Dan je zatvoren'
      when a.start_time < n.start_time or a.end_time > n.end_time then 'Van radnog vremena'
      else 'Unutar pauze'
    end
  from public.appointments a
  join novo n on n.day_of_week = extract(isodow from a.date)::int
  where a.salon_id = p_salon_id
    and a.status in ('pending', 'confirmed')
    -- Samo buducnost: proslost se ne ispravlja mijenjanjem rasporeda.
    and a.date >= current_date
    -- Salonski raspored mjeri sve termine; radnikov samo njegove.
    and (p_employee_id is null or a.employee_id = p_employee_id)
    and (
      n.is_closed
      or a.start_time < n.start_time
      or a.end_time > n.end_time
      or (n.break_start_time is not null
          and tsrange(a.date + a.start_time, a.date + a.end_time)
              && tsrange(a.date + n.break_start_time, a.date + n.break_end_time))
    )
  order by a.date, a.start_time;
end;
$fn$;

create function public.set_working_hours(
  p_salon_id uuid, p_days public.working_hours_input[], p_employee_id uuid default null
) returns setof public.working_hours language plpgsql security definer set search_path = '' as $fn$
begin
  perform private.validate_working_hours(p_salon_id, p_employee_id, p_days);
  -- Upsert, ne delete+insert: `unique nulls not distinct` drzi najvise jedan red po
  -- (salon, radnik, dan), pa ID-evi prezive izmjenu i strani kljucevi se ne trgaju.
  insert into public.working_hours(
    salon_id, employee_id, day_of_week, start_time, end_time,
    break_start_time, break_end_time, is_closed)
  select p_salon_id, p_employee_id, d.day_of_week,
    coalesce(d.start_time, '09:00'), coalesce(d.end_time, '17:00'),
    case when d.is_closed then null else d.break_start_time end,
    case when d.is_closed then null else d.break_end_time end,
    coalesce(d.is_closed, false)
  from unnest(p_days) d
  on conflict (salon_id, employee_id, day_of_week) do update set
    start_time = excluded.start_time, end_time = excluded.end_time,
    break_start_time = excluded.break_start_time,
    break_end_time = excluded.break_end_time, is_closed = excluded.is_closed;

  return query select * from public.working_hours w
    where w.salon_id = p_salon_id and w.employee_id is not distinct from p_employee_id
    order by w.day_of_week;
end;
$fn$;

-- Blokada: neradni dan salona i odsustvo radnika su isti podatak u `blocked_slots`.
create function public.create_blocked_slot(
  p_salon_id uuid, p_date date, p_start_time time, p_end_time time,
  p_reason text default null, p_employee_id uuid default null
) returns public.blocked_slots language plpgsql security definer set search_path = '' as $fn$
declare v_row public.blocked_slots%rowtype;
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_employee_id is not null and not exists(
    select 1 from public.employees e where e.salon_id = p_salon_id and e.id = p_employee_id
  ) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_date is null or p_start_time is null or p_end_time is null then
    raise exception 'Datum i vrijeme su obavezni' using errcode = 'PT400';
  end if;
  if p_end_time <= p_start_time then
    raise exception 'Kraj mora biti poslije pocetka' using errcode = 'PT400';
  end if;
  insert into public.blocked_slots(salon_id, employee_id, date, start_time, end_time, reason)
  values(p_salon_id, p_employee_id, p_date, p_start_time, p_end_time,
    nullif(btrim(p_reason), '')) returning * into v_row;
  -- Postojeci termin unutar blokade ostaje; vidi `blocked_slot_conflicts`.
  return v_row;
end;
$fn$;

create function public.delete_blocked_slot(p_salon_id uuid, p_blocked_slot_id uuid)
returns void language plpgsql security definer set search_path = '' as $fn$
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  delete from public.blocked_slots
  where salon_id = p_salon_id and id = p_blocked_slot_id;
  -- Tudja i nepostojeca blokada daju istu gresku.
  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
end;
$fn$;

-- Termini unutar blokade koja se tek dodaje — isti ugovor kao `working_hours_conflicts`.
create function public.blocked_slot_conflicts(
  p_salon_id uuid, p_date date, p_start_time time, p_end_time time,
  p_employee_id uuid default null
) returns table (
  appointment_id uuid, date date, start_time time, end_time time,
  customer_name text, employee_name text
) language plpgsql stable security definer set search_path = '' as $fn$
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  return query
  select a.id, a.date, a.start_time, a.end_time, a.customer_name, a.employee_name
  from public.appointments a
  where a.salon_id = p_salon_id
    and a.date = p_date
    and a.status in ('pending', 'confirmed')
    -- Blokada salona pogadja i termin bez radnika; blokada radnika samo njegov.
    and (p_employee_id is null or a.employee_id = p_employee_id)
    and tsrange(a.date + a.start_time, a.date + a.end_time)
        && tsrange(p_date + p_start_time, p_date + p_end_time)
  order by a.start_time;
end;
$fn$;

revoke all on function public.set_working_hours(uuid, public.working_hours_input[], uuid)
  from public, anon, authenticated;
revoke all on function public.working_hours_conflicts(uuid, uuid, public.working_hours_input[])
  from public, anon, authenticated;
revoke all on function public.create_blocked_slot(uuid, date, time, time, text, uuid)
  from public, anon, authenticated;
revoke all on function public.delete_blocked_slot(uuid, uuid) from public, anon, authenticated;
revoke all on function public.blocked_slot_conflicts(uuid, date, time, time, uuid)
  from public, anon, authenticated;
grant execute on function public.set_working_hours(uuid, public.working_hours_input[], uuid)
  to authenticated;
grant execute on function public.working_hours_conflicts(uuid, uuid, public.working_hours_input[])
  to authenticated;
grant execute on function public.create_blocked_slot(uuid, date, time, time, text, uuid)
  to authenticated;
grant execute on function public.delete_blocked_slot(uuid, uuid) to authenticated;
grant execute on function public.blocked_slot_conflicts(uuid, date, time, time, uuid)
  to authenticated;

comment on function public.set_working_hours(uuid, public.working_hours_input[], uuid) is
  'Sedmicni raspored salona (p_employee_id null) ili radnika, svih sedam dana odjednom. Postojeci termini se ne diraju — v. working_hours_conflicts.';
comment on function public.create_blocked_slot(uuid, date, time, time, text, uuid) is
  'Blokirano vrijeme salona ili radnika. Ne brise termine koji se s njom preklapaju — v. blocked_slot_conflicts.';
