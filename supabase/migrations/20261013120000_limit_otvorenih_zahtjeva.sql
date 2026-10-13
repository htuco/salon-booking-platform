-- Task 65: limit otvorenih zahtjeva po klijentu.
--
-- Zastita od spama bez 2FA (ADR-0029): jedan racun ne smije moci zatrpati salon zahtjevima.
-- Do ovog taska `book_appointment` nije imao nikakav limit — klijent je mogao poslati
-- pedeset `pending` zahtjeva i zauzeti cijelu sedmicu jednog radnika dok ih salon ne odbije
-- jedan po jedan.
--
-- **Broje se samo `pending` koji jos vrijede** (rok nije prosao). Potvrdjeni, otkazani i
-- zavrseni termini nisu spam: stalni klijent sa pet potvrdjenih termina unaprijed mora moci
-- poslati novi zahtjev. Istekli `pending` se ne broji ni prije nego sto ga cistac iz taska
-- 64 zatvori, pa klijent ne ceka do pet minuta na cron.
--
-- **Brojac je po salonu**: `customers` je red po (salon, identitet), pa `customer_id` vec
-- nosi salon. Zahtjev u jednom salonu ne smanjuje kvotu u drugom.
--
-- **Admin i `auto` mod nisu ograniceni.** Salon ne spamuje sam sebe, a u `auto` modu
-- klijentska rezervacija nastaje kao `confirmed` — `pending` iz nje ne nastaje, pa ga nema
-- ni sta brojati.
--
-- **Utrka:** dva istovremena poziva bi oba procitala `count = 1` i oba upisala. Red klijenta
-- se zato zakljucava (`for update`) prije brojanja, pa drugi poziv ceka prvi i broji poslije
-- njega.
--
-- **Potpis je nepromijenjen** (v. task 37): drugaciji potpis bi bio preopterecenje, ne zamjena.

alter table public.salon_settings
  add column max_pending_per_customer int not null default 2
    check (max_pending_per_customer between 1 and 20);

comment on column public.salon_settings.max_pending_per_customer is
  'Najvise pending zahtjeva koji jos vrijede po klijentu u ovom salonu (task 65). Admin unos i auto mod se ne broje.';

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
  -- Automatski potvrdjeno je disjunkcija dva nezavisna razloga: pozivalac je salon,
  -- ili je salon postavkom rekao da klijentske rezervacije ne cekaju odgovor. Racuna se
  -- jednom, jer ista odluka nosi i `status` i `pending_expires_at` — dva izraza koja se
  -- racunaju odvojeno se razidju cim se jedan promijeni.
  --
  -- `coalesce` jer salon bez reda u `salon_settings` ostavlja `v_settings` prazan: bez
  -- njega je uslov NULL, `case` padne u `else`, i podrazumijevano ponasanje bi ispalo
  -- tacno slucajno, a ne namjerno.
  v_auto boolean;
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

  v_auto := v_admin or coalesce(v_settings.booking_mode, 'manual') = 'auto';

  -- Napomena ide klijentu i salonu kao tekst; bez granice je ovo polje za neograniceno
  -- smece u bazi. Klijentska app napomenu danas ne salje, pa granica stiti od direktnog
  -- poziva RPC-a.
  if char_length(p_note) > 500 then
    raise exception 'Napomena je preduga (najviše 500 znakova)' using errcode = 'PT400';
  end if;

  if not v_auto then
    perform 1 from public.customers c
    where c.salon_id = p_salon_id and c.id = p_customer_id
    for update;

    if (select count(*) from public.appointments a
        where a.salon_id = p_salon_id and a.customer_id = p_customer_id
          and a.status = 'pending'
          and (a.pending_expires_at is null or a.pending_expires_at > now()))
       >= coalesce(v_settings.max_pending_per_customer, 2)
    then
      raise exception 'Već imate zahtjeve koji čekaju potvrdu' using
        errcode = 'PT429',
        hint = 'Sačekajte odgovor salona ili otkažite jedan od zahtjeva.';
    end if;
  end if;

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
    -- `pending_expires_at`. Isto vrijedi za klijentsku rezervaciju u `auto` modu: odgovor
    -- je unaprijed dat postavkom.
    (case when v_auto then 'confirmed' else 'pending' end)::public.appointment_status,
    -- CASE sa dva literala je text, a kolona je enum — bez eksplicitnog
    -- kasta INSERT pada na tipu.
    (case when v_admin then 'manual' else 'app' end)::public.appointment_source,
    -- Rok isteka nosi samo `pending`: potvrdjen termin nema sta cekati. Rok upisan uz
    -- `confirmed` je podatak koji laze — cistac isteklih `pending` termina jos nije napisan
    -- (`appointments_pending_expiry_idx` ga ceka), pa bi ga zatekao kao vec postojece polje
    -- i imao razlog da mu vjeruje.
    case when v_auto then null
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

revoke all on function public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid)
  from public, anon;
grant execute on function public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid)
  to authenticated;

comment on function public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid) is
  'Kreira termin uz re-validaciju slota. Admin dobija confirmed/manual uz izuzetak od min_advance_booking_hours. Klijent dobija source=app, a status po salon_settings.booking_mode: manual -> pending sa pending_expires_at, auto -> confirmed bez roka. Klijent u manual modu moze imati najvise max_pending_per_customer pending zahtjeva koji vrijede (PT429). Napomena najvise 500 znakova (PT400). PT409 kad je slot zauzet, 42501 kad pozivalac nije admin salona ni vlasnik klijenta.';
