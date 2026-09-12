-- Otkazivanje termina kroz validiranu funkciju. Task 16.
--
-- Treci i zadnji upis kojim klijentska app dira bazu, uz `book_appointment` i
-- `ensure_customer`. `update` sa klijenta ne postoji: `appointments` nema `update` grant za
-- `authenticated`, pa je ovo jedini put (`.claude/docs/security.md`).
--
-- **Rok se cita iz `salon_settings.min_cancel_hours`, ne iz konstante.** Pravilo je
-- salonovo i mijenja se bez novog builda; Dart ga prikazuje, baza ga primjenjuje. Dvije
-- implementacije istog pravila su dvije prilike da se raziđu — isti razlog zbog kojeg
-- availability ostaje iskljucivo u bazi (`docs/05 §4.1`).

create function public.cancel_appointment(
  p_salon_id uuid,
  p_appointment_id uuid,
  p_reason text default null
) returns public.appointments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.appointments%rowtype;
  v_customer public.customers%rowtype;
  v_settings public.salon_settings%rowtype;
  v_kontekst uuid;
  v_admin boolean;
  v_pocetak timestamptz;
begin
  select * into v_row
  from public.appointments a
  where a.salon_id = p_salon_id and a.id = p_appointment_id;

  -- Nepostojeci i tudji termin vracaju **istu** gresku, isto kao u `book_appointment`:
  -- razlika bi bila endpoint kojim se nabrajaju tudji termini.
  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  v_admin := private.is_admin(p_salon_id);

  if not v_admin then
    select * into v_customer
    from public.customers c
    where c.salon_id = p_salon_id and c.id = v_row.customer_id;

    -- **Kontekst se cita u varijablu i NULL se hvata prvi.** Zapis
    -- `not (... and p_salon_id = private.client_salon_id() and ...)` je rupa: bez
    -- headera je poredjenje NULL, a `true and NULL and true` je NULL, pa `not NULL`
    -- ne okine `if`. Guard se preskoci **bas kad je pozivalac stvarni vlasnik** — jer
    -- tek tada su svi ostali konjunkti TRUE i NULL prezivi. Za tudjeg klijenta guard
    -- radi, jer je `owns_identity` FALSE, a `NULL and FALSE` je FALSE.
    --
    -- Nije curenje, ali jeste rupa u pravilu koje `security.md` opisuje ("header uvijek
    -- ide uz provjeru vlasnistva"), i postane curenje prvi put kad neko promijeni
    -- redoslijed uslova. Nadjeno pgTAP testom, ne citanjem — v. task 16.
    v_kontekst := private.client_salon_id();

    if v_kontekst is null
       or p_salon_id is distinct from v_kontekst
       or not private.is_client()
       or not found
       or v_customer.auth_identity_id is null
       or not private.owns_identity(v_customer.auth_identity_id)
    then
      raise exception 'Nije dozvoljeno' using errcode = '42501';
    end if;
  end if;

  -- Vec zatvoren termin nije greska sistema nego ishod: dva uredjaja, dva tapa.
  -- Idempotentno vracanje istog reda znaci da drugi tap ne prikaze crvenu poruku.
  if v_row.status = 'cancelled' then
    return v_row;
  end if;

  if v_row.status in ('completed', 'no_show') then
    raise exception 'Termin je zavrsen i ne moze se otkazati'
      using errcode = 'PT409';
  end if;

  select * into v_settings from public.salon_settings s where s.salon_id = p_salon_id;

  -- **Rok vazi za klijenta, ne za salon.** Salon otkazuje kad mora (bolest, kvar), i to
  -- je druga vrsta dogadjaja — klijent dobije obavjestenje, ne zabranu.
  if not v_admin then
    -- Zidno vrijeme salona u timestamptz: datum i vrijeme su bez zone (v. LocalDate),
    -- pa se zona dodaje ovdje, iz postavki salona. Bez toga bi rok racunao u UTC-u i
    -- pomjerio se za sat-dva ovisno o ljetnom racunanju vremena.
    v_pocetak := (v_row.date + v_row.start_time) at time zone coalesce(v_settings.timezone, 'Europe/Sarajevo');

    if v_pocetak - now() < make_interval(hours => coalesce(v_settings.min_cancel_hours, 0)) then
      raise exception 'Rok za otkazivanje je prosao'
        using errcode = 'PT403',
              hint = 'Nazovite salon.';
    end if;
  end if;

  update public.appointments a
  set status = 'cancelled',
      -- **Ko je otkazao je podatak koji admin ekran i statistika trebaju** (task 24).
      -- `system` je istekao `pending` i pise ga scheduler, ne ova funkcija.
      cancelled_by = case when v_admin then 'salon' else 'customer' end::public.cancelled_by,
      cancel_reason = nullif(btrim(coalesce(p_reason, '')), ''),
      updated_at = now()
  where a.salon_id = p_salon_id and a.id = p_appointment_id
  returning * into v_row;

  return v_row;
end;
$$;

comment on function public.cancel_appointment(uuid, uuid, text) is
  'Otkazuje termin uz provjeru vlasnistva i roka iz salon_settings.min_cancel_hours. 42501 kad pozivalac nije vlasnik ni admin, PT403 kad je rok prosao (PostgREST -> HTTP 403), PT409 za zavrsen termin. Idempotentna za vec otkazan termin.';

-- ---------------------------------------------------------------------------
-- Grantovi
-- ---------------------------------------------------------------------------
-- `from public, anon`, ne samo `from public`: Supabase kroz `pg_default_acl` daje `execute`
-- direktno roli `anon` (v. `.claude/docs/security.md`, task 14).
revoke all on function public.cancel_appointment(uuid, uuid, text) from public, anon;
grant execute on function public.cancel_appointment(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Ista rupa u `book_appointment` (task 05)
-- ---------------------------------------------------------------------------
-- Guard je pisan istim obrascem i ima isto ponasanje: bez `x-salon-id` headera je
-- `p_salon_id = private.client_salon_id()` NULL, pa `not (...)` ne okine kad su svi
-- ostali konjunkti TRUE — a to je tacno slucaj u kojem je pozivalac **stvarni vlasnik**
-- tog `customers` reda.
--
-- **Nije curenje i nikad nije bilo**: za tudjeg klijenta je `private.owns_identity(...)`
-- FALSE, a `NULL and FALSE` je FALSE, pa guard radi. Provjereno pokretanjem: napadac bez
-- headera koji rezervise u ime tudjeg klijenta dobija `42501`.
--
-- Ali `security.md` tvrdi da header uvijek ide **uz** provjeru vlasnistva, a u ovoj grani
-- nije isao. Rupa koja ceka na promjenu redoslijeda uslova se ne ostavlja otvorenom zato
-- sto danas nije iskoristiva.
create or replace function public.book_appointment(
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
  v_kontekst uuid;
  v_row public.appointments%rowtype;
begin
  select * into v_customer
  from public.customers c
  where c.salon_id = p_salon_id and c.id = p_customer_id;

  -- Ista poruka za "ne postoji" i "nije tvoj": inace je ovo endpoint kojim se
  -- nabrajaju tudji klijenti.
  --
  -- **Kontekst se cita u varijablu i poredi sa `is distinct from`.** Sa golim `=` je
  -- poredjenje NULL kad header fali, `true and NULL and true` je NULL, i `not (...)`
  -- tada ne okine `if` — guard se preskoci bas kad je pozivalac **stvarni vlasnik**, jer
  -- su tek tada svi ostali konjunkti TRUE. Za tudjeg klijenta guard radi i bez ovoga,
  -- jer je `owns_identity` FALSE a `NULL and FALSE` je FALSE; to je i provjereno
  -- pokretanjem. Rupa koja danas nije iskoristiva se ne ostavlja otvorenom — v. task 16.
  v_kontekst := private.client_salon_id();

  if not found
     or not (
       private.is_admin(p_salon_id)
       or (
         private.is_client()
         and v_kontekst is not null
         and p_salon_id is not distinct from v_kontekst
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

revoke all on function public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid)
  from public, anon;
grant execute on function public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid)
  to authenticated;
