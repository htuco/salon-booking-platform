-- Task 46: uloga `employee` i suzena izolacija (ADR-0013).
--
-- Radnik se prijavi u istu admin aplikaciju i vidi **samo svoje** termine. Ovo je jedino
-- mjesto u sprintu gdje greska curi tudje podatke, pa je promjena namjerno **aditivna**:
--
--   * `private.is_admin()` se ne dira i i dalje znaci pun pristup salonu. Svaka postojeca
--     `staff_manage` politika zato ostaje admin-only; radnik ne dobija nista od njih.
--   * radnik dobija **nove, uske** politike i jednu novu kapiju za RPC-eve,
--     `private.can_manage_appointment()`.
--
-- Pregled politika pisanih na „osoblje = admin" (sve kroz `is_admin`): `services`,
-- `employees`, `employee_services`, `working_hours`, `salon_settings`, `customers`,
-- `appointments`, `blocked_slots`, `reviews`, `salon_policies`, `staff_invites`, `salons`
-- (`staff_salons`), `salon_builds`, `devices` (`own_staff_devices`), `notification_logs`.
-- Nijedna ne prima radnika i nijedna se ne siri. Cjenovnik, osoblje, radno vrijeme i
-- postavke radnik cita kroz `public_active` kao i svaki posjetilac aktivnog salona —
-- **pisanje mu je nula**. Isto vazi za RPC-eve pisanja (`create_service`, `set_working_hours`,
-- `update_salon_settings`, `create_staff_invite`, ...): svi traze `is_admin`.
--
-- **Termin bez radnika (`employee_id is null`) vidi samo admin.** Radnik bi inace vidio
-- klijente koji nisu njegovi. Dodjela termina radniku je posao admina; termin ne nestaje
-- ni iz jednog pogleda, jer ga admin i dalje vidi.

-- ---------------------------------------------------------------------------
-- Nalog radnika je vezan za red u `employees`
-- ---------------------------------------------------------------------------
alter table public.users add column employee_id uuid;
alter table public.users
  add constraint users_employee_fk foreign key (salon_id, employee_id)
    references public.employees(salon_id, id),
  add constraint users_employee_unique unique (salon_id, employee_id);
-- `not valid`: nalog radnika napravljen pozivom iz taska 45 nema vezu, a ovaj constraint ga
-- ne smije srusiti pri migraciji. Takav nalog nema prava (`is_employee` trazi vezu); vlasnik
-- ga uklanja i poziva ponovo. Novi i izmijenjeni redovi se provjeravaju odmah.
alter table public.users
  add constraint users_employee_required
    check (role <> 'employee' or employee_id is not null) not valid;

-- Poziv za radnika mora reci **koji** je radnik. Pozivi bez toga koji jos cekaju se povlace:
-- prihvaceni bi pravili nalog bez prava.
update public.staff_invites set revoked_at = now()
where role = 'employee' and employee_id is null
  and accepted_at is null and revoked_at is null;
alter table public.staff_invites
  add constraint staff_invites_employee_required
    check (role <> 'employee' or employee_id is not null
           or accepted_at is not null or revoked_at is not null);

-- ---------------------------------------------------------------------------
-- Kapije
-- ---------------------------------------------------------------------------
-- Isti obrazac kao `is_admin`: claim iz JWT-a **i** red u `public.users`, sad i sa vezom na
-- `employees`. Uloga u tokenu sama po sebi ne znaci nista.
create function private.is_employee(p_salon uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(auth.jwt()->'app_metadata'->>'role' = 'employee', false)
    and coalesce(auth.jwt()->'app_metadata'->>'salon_id' = p_salon::text, false)
    and exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'employee'
        and u.salon_id = p_salon and u.employee_id is not null
    );
$$;

create function private.current_employee_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select u.employee_id from public.users u
  where u.id = auth.uid() and u.role = 'employee'
    and coalesce(auth.jwt()->'app_metadata'->>'role' = 'employee', false)
    and coalesce(auth.jwt()->'app_metadata'->>'salon_id' = u.salon_id::text, false);
$$;

-- Admin salona, ili radnik **kojem termin pripada**. Termin bez radnika nije ciji.
create function private.can_manage_appointment(p_salon uuid, p_appointment uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_admin(p_salon) or (
    private.is_employee(p_salon) and exists (
      select 1 from public.appointments a
      where a.salon_id = p_salon and a.id = p_appointment
        and a.employee_id is not null
        and a.employee_id = private.current_employee_id()
    )
  );
$$;

revoke all on function private.is_employee(uuid) from public, anon;
revoke all on function private.current_employee_id() from public, anon;
revoke all on function private.can_manage_appointment(uuid, uuid) from public, anon;
grant execute on function private.is_employee(uuid), private.current_employee_id(),
  private.can_manage_appointment(uuid, uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Politike za radnika — samo citanje, samo svoje
-- ---------------------------------------------------------------------------
create policy employee_own on public.appointments
  for select to authenticated
  using (private.is_employee(salon_id) and employee_id is not null
         and employee_id = private.current_employee_id());

-- Blokade salona i njegove vlastite — kalendar ih crta. Tudje odsustvo nije njegovo.
create policy employee_blocks on public.blocked_slots
  for select to authenticated
  using (private.is_employee(salon_id)
         and (employee_id is null or employee_id = private.current_employee_id()));

-- ---------------------------------------------------------------------------
-- Pozivi nose radnika
-- ---------------------------------------------------------------------------
create or replace function public.accept_staff_invite(p_code text, p_user_id uuid, p_email text)
returns public.users
language plpgsql security definer set search_path = '' as $fn$
declare
  v_poziv public.staff_invites%rowtype;
  v_red public.users%rowtype;
begin
  select * into v_poziv from public.staff_invites i
  where i.code_hash = encode(extensions.digest(upper(btrim(p_code)), 'sha256'), 'hex')
    and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()
  for update;
  if not found then
    raise exception 'Poziv ne postoji, istekao je ili je vec iskoristen' using errcode = 'PT404';
  end if;

  -- Veza na `employees` ide samo za radnika; vlasnik je vlasnik cijelog salona.
  insert into public.users(id, salon_id, name, email, role, employee_id)
  values (p_user_id, v_poziv.salon_id, v_poziv.name, lower(btrim(p_email)), v_poziv.role,
    case when v_poziv.role = 'employee' then v_poziv.employee_id end)
  returning * into v_red;

  update public.staff_invites set accepted_at = now(), accepted_user_id = p_user_id
  where id = v_poziv.id;

  return v_red;
end;
$fn$;
revoke all on function public.accept_staff_invite(text, uuid, text) from public, anon, authenticated;
grant execute on function public.accept_staff_invite(text, uuid, text) to service_role;

-- ---------------------------------------------------------------------------
-- RPC-evi nad terminom prihvataju radnika — samo za njegov termin
-- ---------------------------------------------------------------------------
-- Tijela su prepisana iz `20260914150000_admin_akcije_nad_terminima.sql` i
-- `20260912140000_cancel_appointment.sql`; mijenja se **samo** kapija.
create or replace function public.set_appointment_status(
  p_salon_id uuid,
  p_appointment_id uuid,
  p_status public.appointment_status,
  p_reason text default null
) returns public.appointments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.appointments%rowtype;
begin
  -- Admin **svog** salona. `private.is_admin` trazi i claim iz JWT-a i red u `public.users`,
  -- pa token bez clanstva ne prolazi (v. `security.md`).
  if not private.can_manage_appointment(p_salon_id, p_appointment_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Otkazivanje ima svoju funkciju, koja nosi rok i `cancelled_by`.
  if p_status = 'cancelled' then
    raise exception 'Otkazivanje ide kroz cancel_appointment'
      using errcode = 'PT400',
            hint = 'public.cancel_appointment(salon, termin, razlog)';
  end if;

  if p_status not in ('confirmed', 'completed', 'no_show') then
    raise exception 'Nepodrzan status' using errcode = 'PT400';
  end if;

  select * into v_row
  from public.appointments a
  where a.salon_id = p_salon_id and a.id = p_appointment_id;

  -- Nepostojeci i tudji termin vracaju **istu** gresku, isto kao u `book_appointment` i
  -- `cancel_appointment`: razlika bi bila endpoint kojim se nabrajaju tudji termini.
  -- Guard iznad vec drzi tudji salon, ali red iz drugog salona bi ovdje ispao "ne postoji"
  -- i bez toga — zato je ista poruka, ne druga.
  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Idempotentno, istim obrazloženjem kao `cancel_appointment`: dva uredjaja, dva tapa.
  if v_row.status = p_status then
    return v_row;
  end if;

  -- Otkazan termin se ne vraca u zivot potvrdom. Slot je u medjuvremenu mogao biti prodat,
  -- a `appointments_no_overlap` pokriva samo `pending`/`confirmed` — potvrda otkazanog
  -- termina bi mogla napraviti preklapanje koje constraint nikad nije vidio.
  if v_row.status = 'cancelled' then
    raise exception 'Otkazan termin se ne moze mijenjati'
      using errcode = 'PT409',
            hint = 'Napravite nov termin.';
  end if;

  update public.appointments a
  set status = p_status,
      -- **`cancel_reason` nosi obrazlozenje svake akcije, ne samo otkazivanja.** Kolona je
      -- imenovana po prvom slucaju; odbijanje ("radnik na bolovanju") i no-show ("nije se
      -- pojavio") su isti podatak — zasto termin nije odrzan. Nova kolona za istu stvar bi
      -- znacila dva mjesta koja admin ekran mora citati.
      cancel_reason = coalesce(nullif(btrim(coalesce(p_reason, '')), ''), a.cancel_reason),
      -- Ko je donio odluku. `no_show` je odluka salona kao i potvrda: klijent se nije
      -- pojavio, ali je salon taj koji to biljezi.
      cancelled_by = case
        when p_status = 'no_show' then 'salon'::public.cancelled_by
        else a.cancelled_by
      end,
      -- **Rok isteka se skida cim termin nije vise `pending`.** Ostavljen `pending_expires_at`
      -- bi znacio da scheduler iz taska 25 gleda potvrdjen termin kao kandidata za istek.
      pending_expires_at = case when p_status = 'confirmed' then null else a.pending_expires_at end,
      updated_at = now()
  where a.salon_id = p_salon_id and a.id = p_appointment_id
  returning * into v_row;

  -- **Nedolasci se broje ovdje, a cita ih Sprint 3.** `customers.no_show_count` postoji od
  -- init seme, ali do sada ga niko nije pisao. Prag ("tri nedolaska u sest mjeseci") namjerno
  -- **nije** ovdje: on je pravilo vertikale (`vertical.features.noShowTracking`) i trazi
  -- vlastitu odluku. Brojac se puni sada da statistika ne pocne od nule kad ekran dodje.
  if p_status = 'no_show' then
    update public.customers c
    set no_show_count = c.no_show_count + 1
    where c.salon_id = p_salon_id and c.id = v_row.customer_id;
  end if;

  -- Potvrdjen i odrzan termin su posjete. `visit_count` je do sada takodje bio mrtva kolona.
  if p_status = 'completed' then
    update public.customers c
    set visit_count = c.visit_count + 1,
        last_visit_at = now()
    where c.salon_id = p_salon_id and c.id = v_row.customer_id;
  end if;

  -- Mjesto gdje task 25 upisuje `notification_logs` red (potvrda i odbijanje su push
  -- dogadjaji). Namjerno prazno: push u ovom tasku ne postoji, ali funkcija ne treba
  -- prepravku kad dodje — samo dopunu ovdje.

  return v_row;
end;
$$;

comment on function public.set_appointment_status(uuid, uuid, public.appointment_status, text) is
  'Akcije osoblja nad terminom (admin, ili radnik za svoj termin): confirmed, completed, no_show. Otkazivanje ide kroz cancel_appointment (PT400). 42501 kad pozivalac nije admin salona, PT409 za otkazan termin. Idempotentna. Puni no_show_count i visit_count.';

revoke all on function public.set_appointment_status(uuid, uuid, public.appointment_status, text) from public, anon;
grant execute on function public.set_appointment_status(uuid, uuid, public.appointment_status, text) to authenticated;


create or replace function public.cancel_appointment(
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

  -- Task 46: radnik za svoj termin otkazuje kao salon, bez klijentskog roka.
  v_admin := private.can_manage_appointment(p_salon_id, p_appointment_id);

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

-- Poziv za radnika mora imati radnika, i to radnika koji jos nema nalog.
create or replace function public.create_staff_invite(
  p_salon_id uuid,
  p_role public.staff_role,
  p_name text,
  p_employee_id uuid default null
) returns table (invite_id uuid, code text, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $fn$
declare
  -- 10 znakova iz abecede bez 0/O/1/I/L: kod se prepisuje sa telefona. 31^10 ≈ 8e14.
  v_abeceda constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_kod text := '';
  v_bajtovi bytea := extensions.gen_random_bytes(10);
  v_id uuid;
  v_istice timestamptz := now() + interval '7 days';
begin
  if not private.is_admin(p_salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_role is null or p_role not in ('salon_admin', 'employee') then
    raise exception 'Uloga mora biti vlasnik ili radnik' using errcode = 'PT400';
  end if;
  if nullif(btrim(p_name), '') is null then
    raise exception 'Ime je obavezno' using errcode = 'PT400';
  end if;
  if p_employee_id is not null and not exists (
    select 1 from public.employees e where e.salon_id = p_salon_id and e.id = p_employee_id
  ) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_role = 'employee' and p_employee_id is null then
    raise exception 'Izaberite radnika za koga je poziv' using errcode = 'PT400';
  end if;
  if p_employee_id is not null and exists (
    select 1 from public.users u where u.salon_id = p_salon_id and u.employee_id = p_employee_id
  ) then
    raise exception 'Ovaj radnik vec ima nalog' using errcode = 'PT400';
  end if;

  for i in 0..9 loop
    v_kod := v_kod || substr(v_abeceda, (get_byte(v_bajtovi, i) % length(v_abeceda)) + 1, 1);
  end loop;

  insert into public.staff_invites(salon_id, role, name, employee_id, code_hash, expires_at, created_by)
  values (p_salon_id, p_role, btrim(p_name), p_employee_id,
    encode(extensions.digest(v_kod, 'sha256'), 'hex'), v_istice, auth.uid())
  returning id into v_id;

  return query select v_id, v_kod, v_istice;
end;
$fn$;
