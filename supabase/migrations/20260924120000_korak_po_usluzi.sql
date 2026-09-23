-- Task 43: korak rezervacije po usluzi (ADR-0014).
--
-- Brada traje 15 minuta, a salonski korak je 30: termin u 11:00 zavrsi u 11:15, a sljedeci
-- ponudjen pocetak je 11:30. Petnaest minuta vodi se kao slobodno, a niko ih ne moze uzeti.
--
-- `services.slot_step_minutes` je **nullable**: NULL znaci „salonski korak", pa migracija
-- ne mijenja ponasanje nijedne postojece usluge dok vlasnik korak ne upise. Raspon je isti
-- kao `salon_settings.slot_step_minutes` (1–120).
--
-- **Trajanje i korak nisu isto.** Trajanje puni termin, korak bira dozvoljene pocetke.
-- Usluga od 15 minuta sa korakom 30 je legitimna i namjerna. Snapshot termina (task 32)
-- korak ne nosi: korak utice na izbor pocetka, ne na ono sto je dogovoreno.
alter table public.services
  add column slot_step_minutes integer
  check (slot_step_minutes is null or slot_step_minutes between 1 and 120);

-- Jedino mjesto koje racuna korak. `book_appointment` re-validira pocetak kroz ovu funkciju,
-- pa ista promjena vazi i za klijentsku rezervaciju i za rucni admin unos. Tijelo je
-- prepisano iz `20260914150000_admin_akcije_nad_terminima.sql`; mijenja se samo `step`.
create or replace function public.get_available_slots(
  p_salon_id uuid,
  p_service_id uuid,
  p_date date,
  p_employee_id uuid default null,
  p_ignore_min_advance boolean default false
) returns table (start_time time, employee_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  with cfg as (
    select
      coalesce(sv.slot_step_minutes, st.slot_step_minutes) as step,
      st.buffer_minutes            as buf,
      -- Admin izuzetak nulira **samo** ovaj prag. Prosli slotovi i dalje otpadaju,
      -- jer donja granica ostaje `now()`.
      case when p_ignore_min_advance then 0 else st.min_advance_booking_hours end as min_adv,
      st.timezone                  as tz,
      sv.duration_minutes          as dur
    from public.salon_settings st
    join public.services sv
      on sv.salon_id = st.salon_id
     and sv.id = p_service_id
     and sv.is_active
    where st.salon_id = p_salon_id
      and private.salon_active(p_salon_id)
      and p_date >= (now() at time zone st.timezone)::date
      and p_date <= (now() at time zone st.timezone)::date + st.max_advance_booking_days
  ),
  staff as (
    select e.id as emp
    from public.employees e
    join public.employee_services es
      on es.salon_id = e.salon_id
     and es.employee_id = e.id
     and es.service_id = p_service_id
    where e.salon_id = p_salon_id
      and e.is_active
      and (p_employee_id is null or e.id = p_employee_id)
  ),
  win as (
    select
      staff.emp,
      coalesce(whe.start_time,       whs.start_time)       as win_start,
      coalesce(whe.end_time,         whs.end_time)         as win_end,
      coalesce(whe.break_start_time, whs.break_start_time) as br_start,
      coalesce(whe.break_end_time,   whs.break_end_time)   as br_end,
      coalesce(whe.is_closed,        whs.is_closed, true)  as closed
    from staff
    left join public.working_hours whe
      on whe.salon_id = p_salon_id
     and whe.employee_id = staff.emp
     and whe.day_of_week = extract(isodow from p_date)::int
    left join public.working_hours whs
      on whs.salon_id = p_salon_id
     and whs.employee_id is null
     and whs.day_of_week = extract(isodow from p_date)::int
  ),
  cand as (
    select
      w.emp,
      gs as slot_ts,
      tsrange(gs, gs + make_interval(mins => cfg.dur + cfg.buf)) as span
    from win w
    cross join cfg
    cross join lateral generate_series(
      p_date + w.win_start,
      p_date + w.win_end - make_interval(mins => cfg.dur),
      make_interval(mins => cfg.step)
    ) as gs
    where not w.closed
  )
  select c.slot_ts::time, c.emp
  from cand c
  cross join cfg
  where
    (c.slot_ts at time zone cfg.tz) >= now() + make_interval(hours => cfg.min_adv)
    and not exists (
      select 1
      from public.appointments a
      where a.salon_id = p_salon_id
        and a.date = p_date
        and a.status in ('pending', 'confirmed')
        and (a.employee_id = c.emp or a.employee_id is null)
        and tsrange(
              a.date + a.start_time,
              a.date + a.end_time + make_interval(mins => a.buffer_minutes)
            ) && c.span
    )
    and not exists (
      select 1
      from public.blocked_slots b
      where b.salon_id = p_salon_id
        and b.date = p_date
        and (b.employee_id = c.emp or b.employee_id is null)
        and tsrange(b.date + b.start_time, b.date + b.end_time) && c.span
    )
    and not exists (
      select 1
      from win w2
      where w2.emp = c.emp
        and w2.br_start is not null
        and tsrange(p_date + w2.br_start, p_date + w2.br_end) && c.span
    )
  order by 1, 2;
$$;

comment on function public.get_available_slots(uuid, uuid, date, uuid, boolean) is
  'Slobodna vremena pocetka za salon/uslugu/datum, opciono za jednog radnika. p_ignore_min_advance nulira samo min_advance_booking_hours (rucni admin unos) — radno vrijeme, pauze, blokade i preklapanje i dalje vaze.';

revoke all on function public.get_available_slots(uuid, uuid, date, uuid, boolean) from public, anon;
grant execute on function public.get_available_slots(uuid, uuid, date, uuid, boolean) to anon, authenticated;

-- Novi parametar mijenja potpis, a PostgREST bira funkciju po imenima argumenata: stara
-- verzija bi ostala dohvatljiva i tiho ignorisala korak. Zato `drop` pa `create`.
drop function public.create_service(uuid, text, text, text, numeric, integer, text);
drop function public.update_service(uuid, uuid, text, text, text, numeric, integer, text);

create function private.validate_service_step(p_step integer)
returns void language plpgsql immutable set search_path = '' as $fn$
begin
  if p_step is not null and p_step not between 1 and 120 then
    raise exception 'Korak mora biti između 1 i 120 minuta' using errcode = 'PT400';
  end if;
end;
$fn$;
revoke all on function private.validate_service_step(integer) from public, anon, authenticated;
create function public.create_service(
  p_salon_id uuid,
  p_name text,
  p_description text,
  p_category text,
  p_price numeric,
  p_duration_minutes integer,
  p_image_url text default null,
  p_slot_step_minutes integer default null
) returns public.services
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.services%rowtype;
begin
  if not private.is_admin(p_salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if nullif(btrim(p_name), '') is null then
    raise exception 'Naziv je obavezan' using errcode = 'PT400';
  end if;
  if p_price is null or p_price < 0 then
    raise exception 'Cijena mora biti nula ili veca' using errcode = 'PT400';
  end if;
  if p_duration_minutes is null or p_duration_minutes not between 1 and 1440 then
    raise exception 'Trajanje mora biti izmedju 1 i 1440 minuta' using errcode = 'PT400';
  end if;
  perform private.validate_service_step(p_slot_step_minutes);

  insert into public.services (
    salon_id, name, description, category, price, duration_minutes, image_url,
    slot_step_minutes
  ) values (
    p_salon_id,
    btrim(p_name),
    coalesce(btrim(p_description), ''),
    coalesce(btrim(p_category), ''),
    p_price,
    p_duration_minutes,
    nullif(btrim(p_image_url), ''),
    p_slot_step_minutes
  ) returning * into v_row;
  return v_row;
end;
$$;

create function public.update_service(
  p_salon_id uuid,
  p_service_id uuid,
  p_name text,
  p_description text,
  p_category text,
  p_price numeric,
  p_duration_minutes integer,
  p_image_url text default null,
  p_slot_step_minutes integer default null
) returns public.services
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.services%rowtype;
begin
  if not private.is_admin(p_salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if nullif(btrim(p_name), '') is null then
    raise exception 'Naziv je obavezan' using errcode = 'PT400';
  end if;
  if p_price is null or p_price < 0 then
    raise exception 'Cijena mora biti nula ili veca' using errcode = 'PT400';
  end if;
  if p_duration_minutes is null or p_duration_minutes not between 1 and 1440 then
    raise exception 'Trajanje mora biti izmedju 1 i 1440 minuta' using errcode = 'PT400';
  end if;
  perform private.validate_service_step(p_slot_step_minutes);

  update public.services s
  set name = btrim(p_name),
      description = coalesce(btrim(p_description), ''),
      category = coalesce(btrim(p_category), ''),
      price = p_price,
      duration_minutes = p_duration_minutes,
      image_url = nullif(btrim(p_image_url), ''),
      -- NULL je vrijednost, ne „ne diraj": prazno polje u editoru vraca salonski korak.
      slot_step_minutes = p_slot_step_minutes
  where s.salon_id = p_salon_id and s.id = p_service_id
  returning * into v_row;

  if not found then
    -- Ista greska za nepostojecu i tudju uslugu: RPC nije endpoint za nabrajanje ID-eva.
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  return v_row;
end;
$$;


revoke all on function public.create_service(uuid, text, text, text, numeric, integer, text, integer)
  from public, anon;
revoke all on function public.update_service(uuid, uuid, text, text, text, numeric, integer, text, integer)
  from public, anon;
grant execute on function public.create_service(uuid, text, text, text, numeric, integer, text, integer)
  to authenticated;
grant execute on function public.update_service(uuid, uuid, text, text, text, numeric, integer, text, integer)
  to authenticated;
