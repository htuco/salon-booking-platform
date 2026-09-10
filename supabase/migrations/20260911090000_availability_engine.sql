-- Availability engine + rezervacija bez utrke. Task 05.
--
-- Dostupnost je jedini dio sistema koji mora biti tacan; ostalo je CRUD.
-- Zivi na backendu jer verzije na telefonima kasne mjesecima, pa je pogresna
-- availability logika u aplikaciji bug koji se ne moze hotfixati (01 §8.1).

-- ---------------------------------------------------------------------------
-- 1. Zastita od utrke na nivou baze
-- ---------------------------------------------------------------------------
-- Provjera prije upisa ne pomaze kad dva zahtjeva stignu istovremeno: oba vide
-- slobodan slot, oba upisu. Exclusion constraint je jedina odbrana koja to
-- stvarno sprjecava, i zato je btree_gist instaliran jos u init_schema.
--
-- Zauzeti interval termina je [pocetak, kraj + vlastiti buffer). Buffer se
-- racuna samo unaprijed jer bi na obje strane duplirao razmak izmedju dva
-- susjedna termina. Availability racuna kandidata istom formulom — da se ne
-- desi da lista ponudi slot koji constraint odbije.
alter table public.appointments
  add constraint appointments_no_overlap exclude using gist (
    -- Opclass je imenovan eksplicitno: btree_gist je instaliran u shemu
    -- "extensions", pa oslanjanje na search_path znaci da migracija prolazi ili
    -- pada zavisno od toga kako je pokrenuta.
    salon_id extensions.gist_uuid_ops with =,
    employee_id extensions.gist_uuid_ops with =,
    tsrange(
      date + start_time,
      date + end_time + make_interval(mins => buffer_minutes)
    ) with &&
  ) where (employee_id is not null and status in ('pending', 'confirmed'));

comment on constraint appointments_no_overlap on public.appointments is
  'Dva aktivna termina istog radnika se ne mogu preklopiti, ukljucujuci buffer. Termin bez radnika nije pokriven — v. get_available_slots.';

-- ---------------------------------------------------------------------------
-- 2. Dostupnost
-- ---------------------------------------------------------------------------
-- security definer jer cita appointments i blocked_slots, koje anon ne smije
-- vidjeti. Izlaz su samo izvedena slobodna vremena, nijedan podatak o klijentu.
create function public.get_available_slots(
  p_salon_id uuid,
  p_service_id uuid,
  p_date date,
  p_employee_id uuid default null
) returns table (start_time time, employee_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  with cfg as (
    select
      st.slot_step_minutes         as step,
      st.buffer_minutes            as buf,
      st.min_advance_booking_hours as min_adv,
      st.timezone                  as tz,
      sv.duration_minutes          as dur
    from public.salon_settings st
    join public.services sv
      on sv.salon_id = st.salon_id
     and sv.id = p_service_id
     and sv.is_active
    where st.salon_id = p_salon_id
      and private.salon_active(p_salon_id)
      -- Proslost i predaleka buducnost otpadaju prije nego se ista racuna.
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
    -- Radnik ima svoje radno vrijeme ako postoji; inace vazi salonski red
    -- (employee_id is null). Nema nijednog reda za taj dan = zatvoreno.
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
    -- Kandidat mora stati u radno vrijeme svojim trajanjem; buffer smije
    -- prijeci u zatvaranje, jer poslije zadnjeg termina niko ne ceka.
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
    -- Ne prikazuj slot blizi od min_advance_booking_hours (ni onaj u proslosti).
    (c.slot_ts at time zone cfg.tz) >= now() + make_interval(hours => cfg.min_adv)
    and not exists (
      select 1
      from public.appointments a
      where a.salon_id = p_salon_id
        and a.date = p_date
        and a.status in ('pending', 'confirmed')
        -- Termin bez dodijeljenog radnika zauzima cijeli salon. Konzervativno
        -- namjerno: takav red moze nastati samo rucnim admin unosom, a
        -- alternativa je da ne blokira nikoga i da se preko njega rezervise.
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

comment on function public.get_available_slots(uuid, uuid, date, uuid) is
  'Slobodna vremena pocetka za salon/uslugu/datum, opciono za jednog radnika. Jedan red po (vrijeme, radnik) — za "bilo koji" radnik klijent prikazuje razlicita vremena.';

-- date_only vertikale (dentalna, 05 §4) biraju datum, ne vrijeme.
create function public.get_available_dates(
  p_salon_id uuid,
  p_service_id uuid,
  p_from date,
  p_to date,
  p_employee_id uuid default null
) returns table (available_date date)
language sql
stable
security definer
set search_path = ''
as $$
  -- Raspon je ogranicen na 90 dana: bez toga jedan poziv moze pokrenuti
  -- racunanje slotova za godine unaprijed.
  select d::date
  from generate_series(p_from, least(p_to, p_from + 90), interval '1 day') d
  where exists (
    select 1
    from public.get_available_slots(p_salon_id, p_service_id, d::date, p_employee_id)
  )
  order by 1;
$$;

comment on function public.get_available_dates(uuid, uuid, date, date, uuid) is
  'Datumi u rasponu koji imaju bar jedan slobodan slot. Za booking_granularity = date_only.';

-- ---------------------------------------------------------------------------
-- 3. Rezervacija
-- ---------------------------------------------------------------------------
-- Jedini put kojim termin nastaje iz aplikacije. Autorizacija je eksplicitna
-- jer security definer zaobilazi RLS.
create function public.book_appointment(
  p_salon_id uuid,
  p_customer_id uuid,
  p_service_id uuid,
  p_date date,
  p_start_time time,
  p_employee_id uuid default null,
  p_note text default null,
  p_device_id uuid default null
) returns public.appointments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer public.customers%rowtype;
  v_settings public.salon_settings%rowtype;
  v_duration int;
  v_employee uuid;
  v_row public.appointments%rowtype;
begin
  select * into v_customer
  from public.customers c
  where c.salon_id = p_salon_id and c.id = p_customer_id;

  -- Ista poruka za "ne postoji" i "nije tvoj": inace je ovo endpoint kojim se
  -- nabrajaju tudji klijenti.
  if not found
     or not (
       private.is_admin(p_salon_id)
       or (
         private.is_client()
         and p_salon_id = private.client_salon_id()
         and v_customer.auth_identity_id is not null
         and private.owns_identity(v_customer.auth_identity_id)
       )
     )
  then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  select * into v_settings from public.salon_settings s where s.salon_id = p_salon_id;

  select sv.duration_minutes into v_duration
  from public.services sv
  where sv.salon_id = p_salon_id and sv.id = p_service_id and sv.is_active;

  if v_duration is null then
    raise exception 'Usluga ne postoji ili nije aktivna' using errcode = 'PT404';
  end if;

  -- Re-validacija u istoj transakciji. Izmedju citanja liste i ovog poziva
  -- prodje dovoljno vremena da neko drugi uzme slot (01 §8.1).
  -- Kad radnik nije izabran, server ga dodjeljuje: red bez radnika ne bi bio
  -- pokriven exclusion constraintom.
  select s.employee_id into v_employee
  from public.get_available_slots(p_salon_id, p_service_id, p_date, p_employee_id) s
  where s.start_time = p_start_time
  order by s.employee_id
  limit 1;

  if v_employee is null then
    raise exception 'Termin je upravo zauzet' using
      errcode = 'PT409',
      hint = 'Osvjezi listu slobodnih termina i izaberi drugi.';
  end if;

  insert into public.appointments (
    salon_id, service_id, employee_id, customer_id, auth_identity_id, device_id,
    customer_name, customer_phone, customer_note,
    date, start_time, end_time, buffer_minutes,
    status, source, pending_expires_at
  ) values (
    p_salon_id, p_service_id, v_employee, v_customer.id, v_customer.auth_identity_id, p_device_id,
    v_customer.name, v_customer.phone, p_note,
    p_date, p_start_time, p_start_time + make_interval(mins => v_duration),
    -- Buffer se pamti na terminu: kasnija promjena salonske postavke ne smije
    -- retroaktivno pomjerati vec dogovorene termine.
    v_settings.buffer_minutes,
    'pending',
    -- CASE sa dva literala je text, a kolona je enum — bez eksplicitnog
    -- kasta INSERT pada na tipu.
    (case when private.is_admin(p_salon_id) then 'manual' else 'app' end)::public.appointment_source,
    now() + make_interval(hours => v_settings.pending_expiry_hours)
  )
  returning * into v_row;

  return v_row;
exception
  -- Utrka koju je uhvatio constraint, a ne provjera iznad.
  when exclusion_violation then
    raise exception 'Termin je upravo zauzet' using
      errcode = 'PT409',
      hint = 'Osvjezi listu slobodnih termina i izaberi drugi.';
end;
$$;

comment on function public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid) is
  'Kreira pending termin uz re-validaciju slota. PT409 kad je slot zauzet (PostgREST -> HTTP 409), 42501 kad pozivalac nije admin salona ni vlasnik klijenta.';

-- ---------------------------------------------------------------------------
-- 4. Grantovi
-- ---------------------------------------------------------------------------
-- Pregled slobodnih termina ne trazi prijavu (06 §1.1); rezervacija trazi.
revoke all on function public.get_available_slots(uuid, uuid, date, uuid) from public;
revoke all on function public.get_available_dates(uuid, uuid, date, date, uuid) from public;
revoke all on function public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid) from public;

grant execute on function public.get_available_slots(uuid, uuid, date, uuid) to anon, authenticated;
grant execute on function public.get_available_dates(uuid, uuid, date, date, uuid) to anon, authenticated;
grant execute on function public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid) to authenticated;
