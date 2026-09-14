-- Admin akcije nad terminima + rucni unos. Task 24.
--
-- Salon prvi put odgovara na zahtjev. Do ovoga je termin ostajao `pending` dok ne istekne,
-- jer je `StaffAppointmentRepository` (task 23) bio namjerno samo citanje.
--
-- **Ova migracija zatvara rupu koju `.claude/docs/security.md` vodi kao otvorenu**: direktan
-- admin `insert`/`update` nad `appointments` zaobilazi validaciju slota. Exclusion constraint
-- hvata preklapanje, ali radno vrijeme, blokade i `min_advance_booking_hours` ne provjerava
-- niko na tom putu. Zato rupa nije zatvorena samo dodavanjem funkcija nego i **oduzimanjem
-- `insert`/`update` granta** na kraju fajla — funkcija koju niko ne mora zvati nije zastita.

-- ---------------------------------------------------------------------------
-- 1. Availability sa admin izuzetkom
-- ---------------------------------------------------------------------------
-- Salon upisuje klijenta koji stoji na vratima, i to je legitiman slucaj koji
-- `min_advance_booking_hours` (2 h) zabranjuje. Izuzetak je **samo taj prag** — radno
-- vrijeme, pauze, blokade i preklapanje ostaju i za admina.
--
-- Isti oblik pravila vec postoji u `cancel_appointment`: rok vazi za klijenta, ne za salon.
-- Prag je pravilo prema klijentu ("ne rezervisi mi pet minuta prije"), ne fizicko
-- ogranicenje salona.
--
-- **Stara cetveroargumentna verzija se ispusta, ne ostavlja.** `create or replace` sa novim
-- parametrom pravi **preopterecenje**, ne zamjenu: obje verzije bi ostale u bazi, obje sa
-- grantom, a PostgREST bira po imenima argumenata iz tijela zahtjeva. Poziv bez
-- `p_ignore_min_advance` bi i dalje isao na staru funkciju — onu koja ne zna za admin
-- izuzetak — pa bi rucni unos tiho radio po starom pravilu. Ispustanje mora ici **prije**
-- `create`, jer `book_appointment` zavisi od potpisa.
drop function if exists public.get_available_slots(uuid, uuid, date, uuid);

-- Parametar, ne grana po `private.is_admin()` unutar funkcije: funkcija je `stable` i zove
-- je i klijentski ekran: tiha promjena ponasanja po pozivaocu bi znacila da ista lista
-- izgleda drukcije adminu i klijentu **bez ijednog traga u pozivu**. Pozivalac trazi izuzetak
-- eksplicitno, a `book_appointment` ga daje samo adminu (v. dolje).
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
      st.slot_step_minutes         as step,
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

-- ---------------------------------------------------------------------------
-- 2. Rucni unos ide kroz `book_appointment`, ne kroz `insert`
-- ---------------------------------------------------------------------------
-- Funkcija je vec primala admina i vec je pisala `source = 'manual'` (task 05) — mijenja se
-- samo to da admin dobija izuzetak od `min_advance_booking_hours`, kroz novi peti argument
-- `get_available_slots`.
--
-- **Klijent izuzetak ne moze dobiti ni greskom**: `p_ignore_min_advance` nije argument ove
-- funkcije nego izvedena vrijednost iz `private.is_admin(p_salon_id)`. Da je argument,
-- klijentska app bi ga mogla poslati i zaobici prag koji joj salon postavlja.
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
  v_admin boolean;
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
  v_admin := private.is_admin(p_salon_id);

  if not found
     or not (
       v_admin
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
  --
  -- Peti argument je `v_admin`, ne parametar funkcije: v. komentar iznad.
  select s.employee_id into v_employee
  from public.get_available_slots(p_salon_id, p_service_id, p_date, p_employee_id, v_admin) s
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
    -- **Rucni termin je odmah `confirmed`, ne `pending`.** `pending` znaci "salon jos nije
    -- odgovorio"; kad salon sam upisuje termin, odgovor je sam upis. Ostavljen `pending`
    -- bi cekao potvrdu od onoga ko ga je vec potvrdio, i istekao bi kroz
    -- `pending_expires_at`.
    (case when v_admin then 'confirmed' else 'pending' end)::public.appointment_status,
    -- CASE sa dva literala je text, a kolona je enum — bez eksplicitnog
    -- kasta INSERT pada na tipu.
    (case when v_admin then 'manual' else 'app' end)::public.appointment_source,
    -- Rok isteka nosi samo `pending`: potvrdjen termin nema sta cekati.
    case when v_admin then null
         else now() + make_interval(hours => v_settings.pending_expiry_hours) end
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
  'Kreira termin uz re-validaciju slota. Klijent dobija pending/app, admin confirmed/manual uz izuzetak od min_advance_booking_hours. PT409 kad je slot zauzet (PostgREST -> HTTP 409), 42501 kad pozivalac nije admin salona ni vlasnik klijenta.';

revoke all on function public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid)
  from public, anon;
grant execute on function public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Telefonski klijent — `public.upsert_walkin_customer`
-- ---------------------------------------------------------------------------
-- `ensure_customer` (task 14) je namjerno iskljucio osoblje: identitet tamo dolazi iz
-- tokena, a telefonski klijent nema token. Ovo je drugi tok sa drugom validacijom, kako
-- `security.md` i najavljuje.
--
-- `auth_identity_id` ostaje `null` — to je sustinska razlika, ne propust: covjek koji je
-- salon nazvao telefonom nema nalog. Ako se kasnije prijavi u aplikaciji, `ensure_customer`
-- pravi **zaseban** red, jer po telefonu ne moze dokazati da je to on. Spajanje ta dva reda
-- je odluka koju donosi salon iz admin ekrana, ne baza pogadjanjem po broju telefona.
create function public.upsert_walkin_customer(
  p_salon_id uuid,
  p_name text,
  p_phone text default null,
  p_note text default null
) returns public.customers
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.customers%rowtype;
  v_name text;
  v_phone text;
begin
  -- Samo admin salona. Klijent nema sta traziti ovdje: `ensure_customer` je njegov put,
  -- i on izvodi identitet iz tokena umjesto da ga prima kao argument.
  if not private.is_admin(p_salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  v_name  := nullif(btrim(coalesce(p_name, '')), '');
  v_phone := nullif(btrim(coalesce(p_phone, '')), '');

  if v_name is null then
    raise exception 'Ime je obavezno' using errcode = 'PT400';
  end if;

  -- Broj telefona je jedini podatak po kojem se telefonski klijent moze prepoznati pri
  -- sljedecem pozivu, pa je `unique(salon_id, phone)` ono sto sprjecava duplikat. Bez
  -- broja duplikat se ne moze sprijeciti i svaki poziv pravi nov red — to je prihvaceno,
  -- jer je alternativa spajanje po imenu, a dva Emira nisu isti covjek.
  if v_phone is not null then
    select * into v_row
    from public.customers c
    where c.salon_id = p_salon_id and c.phone = v_phone;

    if found then
      -- `do update` ovdje, za razliku od `ensure_customer`: tamo bi drugi poziv prepisao
      -- ime koje je salon ispravio, a **ovdje ispravku pise sam salon**.
      update public.customers c
      set name = v_name,
          note = coalesce(nullif(btrim(coalesce(p_note, '')), ''), c.note)
      where c.salon_id = p_salon_id and c.id = v_row.id
      returning * into v_row;
      return v_row;
    end if;
  end if;

  insert into public.customers (salon_id, auth_identity_id, name, phone, note)
  values (p_salon_id, null, v_name, v_phone, nullif(btrim(coalesce(p_note, '')), ''))
  returning * into v_row;

  return v_row;
end;
$$;

comment on function public.upsert_walkin_customer(uuid, text, text, text) is
  'Telefonski klijent bez naloga (auth_identity_id ostaje null). Samo admin salona; 42501 inace, PT400 za prazno ime. Postojeci red se prepoznaje po broju telefona i azurira.';

revoke all on function public.upsert_walkin_customer(uuid, text, text, text) from public, anon;
grant execute on function public.upsert_walkin_customer(uuid, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Akcije nad terminom — `public.set_appointment_status`
-- ---------------------------------------------------------------------------
-- Jedna funkcija za sve cetiri akcije, ne cetiri funkcije: provjera vlasnistva, dozvoljeni
-- prelazi i idempotencija su im **isti**, a cetiri kopije istog guarda su cetiri prilike da
-- se raziđu. Razlika medju akcijama je samo ciljni status, i to je argument.
--
-- Otkazivanje od strane salona **ostaje u `cancel_appointment`** (task 16), koji vec zna za
-- `cancelled_by = 'salon'` i za to da rok ne obavezuje salon. Ova funkcija zato odbija
-- `cancelled` i uputi na njega — dvije funkcije koje pisu isti status bi znacile dva mjesta
-- na kojima se pravilo o roku moze razici.
create function public.set_appointment_status(
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
  if not private.is_admin(p_salon_id) then
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
  'Admin akcije nad terminom: confirmed, completed, no_show. Otkazivanje ide kroz cancel_appointment (PT400). 42501 kad pozivalac nije admin salona, PT409 za otkazan termin. Idempotentna. Puni no_show_count i visit_count.';

revoke all on function public.set_appointment_status(uuid, uuid, public.appointment_status, text) from public, anon;
grant execute on function public.set_appointment_status(uuid, uuid, public.appointment_status, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Zatvaranje rupe: `appointments` se vise ne pise direktno
-- ---------------------------------------------------------------------------
-- **Ovo je dio koji rupu stvarno zatvara.** Sve iznad su funkcije koje admin *moze* zvati;
-- dok `insert`/`update` grant stoji, admin ekran (ili bilo koji token sa `salon_admin`
-- claimom) moze ih zaobici jednim PostgREST pozivom i upisati termin u nedjelju u 3 ujutro.
-- Funkcija koju niko ne mora zvati nije zastita nego konvencija.
--
-- `staff_manage` politika (`for all`) ostaje: ona brani **tudji salon** i to i dalje radi.
-- Ono sto se oduzima je grant, dakle sam put upisa. Politika bez granta je neaktivna za
-- `insert`/`update`, ali ostaje tacna za `select` i `delete`.
--
-- `delete` **ostaje**: greskom unesen termin salon mora moci obrisati, a brisanje ne moze
-- proizvesti nevalidan raspored — samo ga isprazniti.
revoke insert, update on public.appointments from authenticated;

comment on table public.appointments is
  'Termini. Upis i izmjena statusa iskljucivo kroz book_appointment / set_appointment_status / cancel_appointment — insert i update grant su oduzeti roli authenticated (task 24), jer direktan upis zaobilazi radno vrijeme, blokade i min_advance_booking_hours.';

-- `customers` ostaje sa `insert`/`update` grantom: admin ispravlja ime i biljezi napomenu
-- iz ekrana, a nijedna od tih izmjena ne moze proizvesti nevalidan raspored. Rupa koju ovaj
-- task zatvara je o **terminima**, ne o klijentima.
