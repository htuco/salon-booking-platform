-- Task 68: lista cekanja (ADR-0031).
--
-- Klijent se na pun dan upisuje za uslugu (i opcionalno radnika). Kad se termin tog dana
-- oslobodi, svako ko je upisan, a kome se mjesto za njegovu uslugu stvarno otvorilo, dobija
-- push. Termin dobija ko prvi zakaze: upis ne drzi termin i ne daje prednost, pa
-- `book_appointment` ostaje jedina provjera.
--
-- Cetiri stvari koje ova migracija uvodi:
--
--   1. **`private.candidate_slots`** — tijelo `get_available_slots` sa jednim prekidacem vise:
--      racunaj i bez termina. „Pun dan" je dan na koji bi bilo slobodnog vremena da nema
--      nijednog termina, a nema ga. Bez toga bi neradni dan izgledao isto kao pun, jer oba
--      daju praznu listu. `get_available_slots` postaje omotac, pa je pravilo slotova i dalje
--      na jednom mjestu.
--   2. **`waitlist_entries`** bez ijednog granta za `anon` i `authenticated`. Sve ide kroz
--      RPC: upis, odjava, moji upisi, puni dani u rasponu, i broj po danu za salon.
--   3. **Obavijest vezana za upis, ne za termin.** `notification_logs` dobija
--      `waitlist_entry_id`, a red nosi tacno jedno od ta dva. Osloboden termin je termin
--      **drugog** klijenta i ne upisuje se u red upisanog, pa ga ne vide ni push ni
--      `my_notifications`.
--   4. **Dva triggera nad `appointments`**: otkazivanje budi listu, a novi termin istog
--      klijenta za isti dan i uslugu brise njegov upis.

alter type public.notification_type add value if not exists 'waitlist_offer';

-- ---------------------------------------------------------------------------
-- Slotovi: jedno pravilo, dva pitanja
-- ---------------------------------------------------------------------------
-- Tijelo je prepisano iz `20260924120000_korak_po_usluzi.sql`. Mijenja se samo uslov nad
-- `appointments`, koji `p_count_appointments = false` iskljucuje. Prosli slotovi,
-- `min_advance_booking_hours`, radno vrijeme, pauze i blokade vaze u oba slucaja: dan na koji
-- je radno vrijeme vec proslo nije pun nego gotov.
create function private.candidate_slots(
  p_salon_id uuid,
  p_service_id uuid,
  p_date date,
  p_employee_id uuid,
  p_ignore_min_advance boolean,
  p_count_appointments boolean
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
    and (p_count_appointments is not true or not exists (
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
    ))
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

revoke all on function private.candidate_slots(uuid, uuid, date, uuid, boolean, boolean)
  from public, anon, authenticated;

comment on function private.candidate_slots(uuid, uuid, date, uuid, boolean, boolean) is
  'Jedino mjesto koje racuna slotove. p_count_appointments = false daje slotove kao da nema nijednog termina (pun dan naspram neradnog, task 68). Bez app grantova; zovu je get_available_slots i funkcije liste cekanja.';

-- Isti potpis, isti grantovi, isto ponasanje. `create or replace` ovdje nije zamka iz
-- `security.md` (preopterecenje), jer se potpis ne mijenja.
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
  select s.start_time, s.employee_id
  from private.candidate_slots(
    p_salon_id, p_service_id, p_date, p_employee_id, p_ignore_min_advance, true
  ) s;
$$;

-- ---------------------------------------------------------------------------
-- Tabela
-- ---------------------------------------------------------------------------
-- Upis je po **identitetu**, ne po `customers` redu: klijent se smije upisati prije prvog
-- termina u salonu, a novi termin i brisanje naloga nose identitet. Salon je i dalje prva
-- kolona svakog kljuca, a usluga i radnik su vezani kompozitno (`security.md`, „Kompozitni
-- strani kljucevi") — upis salona A ne moze pokazivati na uslugu salona B.
create table public.waitlist_entries (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id),
  auth_identity_id uuid not null references public.auth_identities(id) on delete cascade,
  service_id uuid not null,
  employee_id uuid,
  date date not null,
  created_at timestamptz not null default now(),
  unique (salon_id, id),
  foreign key (salon_id, service_id) references public.services(salon_id, id),
  foreign key (salon_id, employee_id) references public.employees(salon_id, id),
  -- Isti dan, usluga i radnik dva puta su jedan upis; „Bilo ko" (NULL) takodje.
  constraint waitlist_entries_jedan_upis
    unique nulls not distinct (salon_id, auth_identity_id, service_id, employee_id, date)
);

create index waitlist_entries_dan_idx on public.waitlist_entries (salon_id, date);

comment on table public.waitlist_entries is
  'Lista cekanja (task 68, ADR-0031): klijent ceka da se na pun dan oslobodi mjesto za uslugu, opcionalno kod radnika. Nema app grantova; pise i cita se samo kroz RPC.';

-- **Nijedan grant za `anon` i `authenticated`.** Klijentu treba naziv usluge i radnika, a
-- salonu samo broj. Oboje daju funkcije, pa politika nad tabelom ne bi imala citaoca, a
-- bila bi jos jedna granica koju treba drzati.
alter table public.waitlist_entries enable row level security;
revoke all on public.waitlist_entries from anon, authenticated;
grant all on public.waitlist_entries to service_role;

-- ---------------------------------------------------------------------------
-- Obavijest vezana za upis
-- ---------------------------------------------------------------------------
-- `on delete cascade`: upis koji nestane (klijent zakazao, odjavio se ili obrisao nalog)
-- povlaci i ponudu koja jos ceka slanje. Push o mjestu na koje klijent vise ne ceka nije
-- obavijest nego smetnja.
alter table public.notification_logs
  alter column appointment_id drop not null,
  add column waitlist_entry_id uuid,
  add constraint notification_logs_upis_fk
    foreign key (salon_id, waitlist_entry_id)
    references public.waitlist_entries(salon_id, id) on delete cascade,
  add constraint notification_logs_termin_ili_upis
    check (num_nonnulls(appointment_id, waitlist_entry_id) = 1);

-- „Jednom po oslobadjanju": svaki termin se oslobodi najvise jednom (`cancelled` je konacan),
-- pa trigger dodaje jednu ponudu po oslobadjanju. Dva otkazivanja u istoj minuti ne prave
-- dvije poruke: dok prethodna ponuda istom upisu ceka slanje, nova se ne dodaje.
create unique index notification_logs_ponuda_ceka
  on public.notification_logs (waitlist_entry_id, device_id)
  where waitlist_entry_id is not null and status = 'queued';

-- ---------------------------------------------------------------------------
-- Pun dan
-- ---------------------------------------------------------------------------
create function private.waitlist_day_full(
  p_salon_id uuid, p_service_id uuid, p_date date, p_employee_id uuid
) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
      select 1 from private.candidate_slots(
        p_salon_id, p_service_id, p_date, p_employee_id, false, false)
    )
    and not exists (
      select 1 from private.candidate_slots(
        p_salon_id, p_service_id, p_date, p_employee_id, false, true)
    );
$$;
revoke all on function private.waitlist_day_full(uuid, uuid, date, uuid)
  from public, anon, authenticated;

-- Puni dani u rasponu. Klijent po ovome u kalendaru razlikuje pun dan (tapa se, nudi listu
-- cekanja) od neradnog (ne tapa se), kao sto `get_available_dates` daje slobodne. Javno kao
-- slotovi: izlaz je izvedena istina o danu, bez ijednog podatka o klijentu, a pregled termina
-- ne trazi prijavu (`docs/06` §1.1). Raspon je ogranicen na 62 dana iz istog razloga kao kod
-- `get_available_dates`.
create function public.waitlist_full_dates(
  p_salon_id uuid,
  p_service_id uuid,
  p_from date,
  p_to date,
  p_employee_id uuid default null
) returns table (full_date date)
language sql stable security definer set search_path = '' as $$
  select d::date
  from generate_series(p_from, least(p_to, p_from + 62), interval '1 day') d
  where private.waitlist_day_full(p_salon_id, p_service_id, d::date, p_employee_id)
  order by 1;
$$;

revoke all on function public.waitlist_full_dates(uuid, uuid, date, date, uuid) from public;
grant execute on function public.waitlist_full_dates(uuid, uuid, date, date, uuid) to anon, authenticated;

comment on function public.waitlist_full_dates(uuid, uuid, date, date, uuid) is
  'Puni dani u rasponu (najvise 63) za uslugu i opcionalno radnika: dan radi, a nema slobodnog vremena. Neradni dan, zatvoren radnik, blokiran dan, dan van prozora rezervacije i dan sa slobodnim vremenom se ne vracaju.';

-- ---------------------------------------------------------------------------
-- Klijent
-- ---------------------------------------------------------------------------
create function public.join_waitlist(
  p_service_id uuid,
  p_date date,
  p_employee_id uuid default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_salon uuid;
  v_identity uuid;
  v_today date;
  v_id uuid;
begin
  -- `NULL` se hvata prvi (`security.md`, zamka 1): bez headera je `client_salon_id()` NULL.
  v_salon := private.client_salon_id();
  if private.is_client() is not true or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Identitet iz tokena, nikad iz argumenta. `for update` zakljucava brojanje ispod: dva
  -- istovremena upisa istog klijenta ne prodju oba preko limita.
  select ai.id into v_identity
  from public.auth_identities ai
  where ai.supabase_user_id = auth.uid() and ai.deleted_at is null
  for update;
  if v_identity is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Ponovljen upis vraca isti red i ne broji se u limit: dva tapa nisu dva upisa.
  select w.id into v_id
  from public.waitlist_entries w
  where w.salon_id = v_salon and w.auth_identity_id = v_identity
    and w.service_id = p_service_id and w.date = p_date
    and w.employee_id is not distinct from p_employee_id;
  if v_id is not null then
    return v_id;
  end if;

  if p_service_id is null or p_date is null
     or private.waitlist_day_full(v_salon, p_service_id, p_date, p_employee_id) is not true then
    raise exception 'Na ovaj dan se ne možete upisati na listu čekanja' using errcode = 'PT400';
  end if;

  select (now() at time zone st.timezone)::date into v_today
  from public.salon_settings st where st.salon_id = v_salon;

  if (select count(*) from public.waitlist_entries w
      where w.salon_id = v_salon and w.auth_identity_id = v_identity
        and w.date >= v_today) >= 3 then
    raise exception 'Već čekate na tri dana. Odjavite jedan da biste se upisali na novi.'
      using errcode = 'PT429';
  end if;

  insert into public.waitlist_entries (salon_id, auth_identity_id, service_id, employee_id, date)
  values (v_salon, v_identity, p_service_id, p_employee_id, p_date)
  returning id into v_id;
  return v_id;
end $$;

revoke all on function public.join_waitlist(uuid, date, uuid) from public, anon;
grant execute on function public.join_waitlist(uuid, date, uuid) to authenticated;

comment on function public.join_waitlist(uuid, date, uuid) is
  'Klijent se u salonu iz x-salon-id upisuje na listu cekanja za pun dan, uslugu i opcionalno radnika. Idempotentno. PT400 kad dan nije pun (ima slobodnog vremena, ne radi, van prozora), PT429 za cetvrti aktivan upis, 42501 za osoblje, anon i bez konteksta.';

-- Tudji i nepostojeci upis se ponasaju isto: nista se ne brise i nema greske. Greska bi
-- odala da upis postoji, a ponovljena odjava (dva tapa, dva uredjaja) nije kvar.
create function public.leave_waitlist(p_entry_id uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_salon uuid;
begin
  v_salon := private.client_salon_id();
  if private.is_client() is not true or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  delete from public.waitlist_entries w
  where w.id = p_entry_id
    and w.salon_id = v_salon
    and private.owns_identity(w.auth_identity_id);
end $$;

revoke all on function public.leave_waitlist(uuid) from public, anon;
grant execute on function public.leave_waitlist(uuid) to authenticated;

comment on function public.leave_waitlist(uuid) is
  'Klijent se odjavljuje sa liste cekanja u salonu iz x-salon-id. Tudji i nepostojeci upis: bez efekta i bez greske. 42501 za osoblje, anon i bez konteksta.';

create function public.my_waitlist()
returns table (
  id uuid,
  service_id uuid,
  service_name text,
  employee_id uuid,
  employee_name text,
  date date,
  created_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
declare v_salon uuid;
begin
  v_salon := private.client_salon_id();
  if private.is_client() is not true or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Prosli dani se ne vracaju: upis vazi do kraja svog dana (ADR-0031).
  return query
  select w.id, w.service_id, sv.name, w.employee_id, e.name, w.date, w.created_at
  from public.waitlist_entries w
  join public.salon_settings st on st.salon_id = w.salon_id
  join public.services sv on sv.salon_id = w.salon_id and sv.id = w.service_id
  left join public.employees e on e.salon_id = w.salon_id and e.id = w.employee_id
  where w.salon_id = v_salon
    and private.owns_identity(w.auth_identity_id)
    and w.date >= (now() at time zone st.timezone)::date
  order by w.date, w.created_at;
end $$;

revoke all on function public.my_waitlist() from public, anon;
grant execute on function public.my_waitlist() to authenticated;

comment on function public.my_waitlist() is
  'Aktivni upisi pozivaoca na listu cekanja u salonu iz x-salon-id, od danas. 42501 za osoblje, anon i bez konteksta.';

-- ---------------------------------------------------------------------------
-- Salon: samo broj
-- ---------------------------------------------------------------------------
-- Potraznja po danu, bez imena i bez usluga (ADR-0031). Radnik je ne dobija: odluka „treba
-- li jos jedan radnik subotom" je vlasnikova.
create function public.waitlist_demand(p_salon_id uuid, p_from date, p_to date)
returns table (date date, waiting integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 62 then
    raise exception 'Neispravan raspon' using errcode = 'PT400';
  end if;

  return query
  select w.date, count(distinct w.auth_identity_id)::int
  from public.waitlist_entries w
  join public.salon_settings st on st.salon_id = w.salon_id
  where w.salon_id = p_salon_id
    and w.date between p_from and p_to
    and w.date >= (now() at time zone st.timezone)::date
  group by w.date
  order by w.date;
end $$;

revoke all on function public.waitlist_demand(uuid, date, date) from public, anon;
grant execute on function public.waitlist_demand(uuid, date, date) to authenticated;

comment on function public.waitlist_demand(uuid, date, date) is
  'Broj klijenata koji cekaju po danu (od danas), za admina salona. Najvise 63 dana. 42501 za ne-admina, PT400 za neispravan raspon.';

-- ---------------------------------------------------------------------------
-- Triggeri nad terminima
-- ---------------------------------------------------------------------------
-- Otkazivanje (salon, klijent, istek) budi listu. Svakom upisu tog dana se ponovo racuna
-- `candidate_slots` za njegovu uslugu i radnika: otkazana brada od 15 minuta ne otvara
-- mjesto za farbanje. `after` trigger vidi vlastito otkazivanje, pa je slot vec slobodan.
-- `set_day_closed` prvo upise blokadu, pa tek onda otkazuje, i zato zatvoren dan ne budi
-- nikoga.
create function private.queue_waitlist_offers() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notification_logs (salon_id, waitlist_entry_id, device_id, type)
  select w.salon_id, w.id, d.id, 'waitlist_offer'::public.notification_type
  from public.waitlist_entries w
  join public.devices d
    on d.salon_id = w.salon_id
   and d.staff_user_id is null
   and d.auth_identity_id = w.auth_identity_id
   and d.fcm_token is not null
  where w.salon_id = new.salon_id
    and w.date = new.date
    and exists (
      select 1 from private.candidate_slots(
        w.salon_id, w.service_id, w.date, w.employee_id, false, true)
    )
  on conflict (waitlist_entry_id, device_id)
    where waitlist_entry_id is not null and status = 'queued'
    do nothing;
  return new;
end $$;
revoke all on function private.queue_waitlist_offers() from public, anon, authenticated;

create trigger queue_waitlist_offers
  after update of status on public.appointments
  for each row
  when (new.status = 'cancelled' and old.status in ('pending', 'confirmed'))
  execute function private.queue_waitlist_offers();

-- Klijent koji zakaze istu uslugu tog dana vise ne ceka. Bez obzira na radnika: upis „kod
-- Emira" je ispunjen i terminom kod Amara, jer je klijent sam izabrao.
create function private.close_waitlist_entry() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.waitlist_entries w
  where w.salon_id = new.salon_id
    and w.auth_identity_id = new.auth_identity_id
    and w.service_id = new.service_id
    and w.date = new.date;
  return new;
end $$;
revoke all on function private.close_waitlist_entry() from public, anon, authenticated;

create trigger close_waitlist_entry
  after insert on public.appointments
  for each row
  when (new.auth_identity_id is not null and new.status in ('pending', 'confirmed'))
  execute function private.close_waitlist_entry();

-- Brisanje naloga gasi i upise. Trigger, a ne nova verzija `delete_my_account`, isto kao
-- recenzije (task 67): svaki put do `deleted_at` ima isti ishod.
create function private.delete_waitlist_of_identity() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.waitlist_entries w where w.auth_identity_id = new.id;
  return new;
end $$;
revoke all on function private.delete_waitlist_of_identity() from public, anon, authenticated;

create trigger delete_waitlist_of_identity
  after update of deleted_at on public.auth_identities
  for each row
  when (old.deleted_at is null and new.deleted_at is not null)
  execute function private.delete_waitlist_of_identity();

-- ---------------------------------------------------------------------------
-- Push i istorija obavijesti znaju za upis
-- ---------------------------------------------------------------------------
-- Ista provjera primaoca kao u tasku 25, sa jednom granom vise: red upisa trazi da je
-- uredjaj i dalje vlasnikov upisa. Termin se vise ne spaja obavezno (`left join`), jer red
-- ponude termin nema; bez toga bi svaka ponuda zavrsila kao `recipient_unavailable`.
create or replace function public.claim_push_notifications(p_limit int default 20)
returns table (id uuid, salon_id uuid, appointment_id uuid, type public.notification_type,
  fcm_token text, staff boolean)
language plpgsql security definer set search_path = '' as $$
begin
  update public.notification_logs n set status = 'logged', error = 'recipient_unavailable'
  where n.status = 'queued' and not exists (
    select 1 from public.devices d
    left join public.appointments a
      on a.id = n.appointment_id and a.salon_id = n.salon_id
    left join public.waitlist_entries w
      on w.id = n.waitlist_entry_id and w.salon_id = n.salon_id
    where d.id = n.device_id and d.salon_id = n.salon_id and d.fcm_token is not null
      and private.salon_active(d.salon_id)
      and (a.id is not null or w.id is not null)
      and (
        (d.staff_user_id is not null and a.id is not null and exists (select 1 from public.users u
          where u.id = d.staff_user_id and u.salon_id = d.salon_id and u.role = 'salon_admin'))
        or (d.staff_user_id is null
          and d.auth_identity_id = coalesce(a.auth_identity_id, w.auth_identity_id)
          and exists (select 1 from public.auth_identities i
            where i.id = d.auth_identity_id and i.deleted_at is null))
      )
  );
  return query with picked as (
    select n.id from public.notification_logs n where n.status = 'queued'
    order by n.created_at, n.id limit greatest(1, least(coalesce(p_limit, 20), 100))
    for update skip locked
  ), claimed as (
    update public.notification_logs n set status = 'sending', attempts = n.attempts + 1,
      claimed_at = now() from picked p where n.id = p.id returning n.*
  ) select n.id, n.salon_id, n.appointment_id, n.type, d.fcm_token,
    d.staff_user_id is not null from claimed n join public.devices d
      on d.id = n.device_id and d.salon_id = n.salon_id;
end $$;
revoke all on function public.claim_push_notifications(int) from public, anon, authenticated;
grant execute on function public.claim_push_notifications(int) to service_role;

-- Isti potpis kao u tasku 70. Ponuda je stavka bez termina: `appointment_id` i `start_time`
-- su NULL, a usluga, radnik i dan dolaze iz upisa. Upis koji je nestao nosi i svoju ponudu
-- (`on delete cascade`), pa istorija pokazuje samo ponude na koje klijent jos ceka.
create or replace function public.my_notifications(p_limit integer default 50)
returns table (
  appointment_id uuid,
  type text,
  created_at timestamptz,
  read boolean,
  service_name text,
  employee_name text,
  date date,
  start_time time
)
language plpgsql stable security definer set search_path = '' as $$
declare v_salon uuid;
begin
  v_salon := private.client_salon_id();
  if not private.is_client() or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  return query
  select d.appointment_id, d.type, d.created_at, d.read,
    d.service_name, d.employee_name, d.date, d.start_time
  from (
    select n.appointment_id, n.type::text as type,
      min(n.created_at) as created_at,
      bool_and(n.read_at is not null) as read,
      a.service_name, a.employee_name, a.date, a.start_time
    from public.notification_logs n
    join public.appointments a on a.salon_id = n.salon_id and a.id = n.appointment_id
    join public.devices dv on dv.salon_id = n.salon_id and dv.id = n.device_id
    where n.salon_id = v_salon
      and a.auth_identity_id is not null
      and private.owns_identity(a.auth_identity_id)
      and dv.staff_user_id is null
    group by n.appointment_id, n.type, a.service_name, a.employee_name, a.date, a.start_time
    union all
    -- Jedna stavka po ponudi, ne po upisu: dva oslobadjanja istog dana su dvije vijesti.
    -- Redovi jedne ponude na vise uredjaja nastaju u istoj transakciji, pa dijele `created_at`.
    select null::uuid, n.type::text,
      n.created_at,
      bool_and(n.read_at is not null),
      sv.name, e.name, w.date, null::time
    from public.notification_logs n
    join public.waitlist_entries w on w.salon_id = n.salon_id and w.id = n.waitlist_entry_id
    join public.services sv on sv.salon_id = w.salon_id and sv.id = w.service_id
    left join public.employees e on e.salon_id = w.salon_id and e.id = w.employee_id
    join public.devices dv on dv.salon_id = n.salon_id and dv.id = n.device_id
    where n.salon_id = v_salon
      and private.owns_identity(w.auth_identity_id)
      and dv.staff_user_id is null
    group by w.id, n.type, n.created_at, sv.name, e.name, w.date
  ) d
  order by d.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
end $$;

comment on function public.my_notifications(integer) is
  'Obavijesti klijenta u salonu iz x-salon-id: jedna stavka po (termin, tip) i po ponudi liste cekanja, najnovije prve, sa oznakom procitanog. Samo termini i upisi ciji je identitet pozivaoca i samo redovi poslani klijentskim uredjajima. Ponuda nema appointment_id ni start_time. 42501 za osoblje, anon i bez konteksta.';

create or replace function public.mark_notifications_read()
returns integer
language plpgsql security definer set search_path = '' as $$
declare v_salon uuid; v_count integer; v_upisi integer;
begin
  v_salon := private.client_salon_id();
  if not private.is_client() or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  update public.notification_logs n
  set read_at = now()
  from public.appointments a, public.devices dv
  where n.salon_id = v_salon and n.read_at is null
    and a.salon_id = n.salon_id and a.id = n.appointment_id
    and a.auth_identity_id is not null
    and private.owns_identity(a.auth_identity_id)
    and dv.salon_id = n.salon_id and dv.id = n.device_id
    and dv.staff_user_id is null;
  get diagnostics v_count = row_count;

  update public.notification_logs n
  set read_at = now()
  from public.waitlist_entries w, public.devices dv
  where n.salon_id = v_salon and n.read_at is null
    and w.salon_id = n.salon_id and w.id = n.waitlist_entry_id
    and private.owns_identity(w.auth_identity_id)
    and dv.salon_id = n.salon_id and dv.id = n.device_id
    and dv.staff_user_id is null;
  get diagnostics v_upisi = row_count;

  return v_count + v_upisi;
end $$;

comment on function public.mark_notifications_read() is
  'Oznacava procitanim sve obavijesti klijenta u salonu iz x-salon-id (isti skup kao my_notifications, i ponude liste cekanja). Vraca broj redova.';
