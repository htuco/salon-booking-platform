-- Task 42: neradni dan salona — zakljucana proslost i kaskadno otkazivanje.
--
-- Vlasnik prijavi neradni dan (bajram, sahrana, kvar), svi zivi termini tog dana se otkazu,
-- a klijent dobije obavijest. Do sada je blokada (`create_blocked_slot`, task 34) samo
-- zatvarala slotove i **namjerno ostavljala** postojece termine — vlasnik ih je morao
-- otkazivati jedan po jedan, a proslost se mogla blokirati bez ikakve granice.
--
-- **Pravilo zakljucavanja.** Prosli dan se ne proglasava neradnim: izvjestaj o prometu mora
-- ostati tacan. Danas je otvoren **dok salon ne otvori** — granica je najraniji pocetak
-- radnog vremena tog dana (salonski ili bilo kojeg radnika), u zoni salona, ne u zoni
-- servera. Dan bez radnog vremena (zatvoren po rasporedu) nema granicu i ostaje otvoren.
--
-- **Otkazivanje ide kroz `cancel_appointment`**, ne kroz `set_appointment_status` (koji
-- otkazivanje odbija sa PT400) i ne kroz direktan `update`. Tako `cancelled_by = 'salon'`,
-- `cancel_reason` i trigger `queue_appointment_push` ostaju na jednom mjestu. Zamka iz task
-- fajla koja kaze suprotno je netacna — v. status blok taska 42.
--
-- **Obavijest je red po uredjaju** (`notification_logs.device_id not null`). Klijent bez
-- registrovanog uredjaja ne dobija red; to je postojeci ugovor push-a, ne propust ovog
-- taska (odluka vlasnika proizvoda 2026-09-23, varijanta b).

-- `PT400`, ne `PT409`: `error_mapper.dart` svaki PT409 prevodi u „Termin je u medjuvremenu
-- zauzet", a vlasnik treba procitati zasto dan ne moze zatvoriti.
--
-- Guard je odvojen od RPC-a i prima `p_now`, da pgTAP moze dokazati obje strane granice
-- „danas prije/poslije otvaranja" — `now()` je u transakciji testa zamrznut.
create function private.assert_day_closable(p_salon_id uuid, p_date date, p_now timestamptz)
returns void language plpgsql stable security definer set search_path = '' as $fn$
declare
  v_tz text;
  v_lokalno timestamp;
  v_otvara time;
begin
  if p_date is null then
    raise exception 'Datum je obavezan' using errcode = 'PT400';
  end if;

  select coalesce(s.timezone, 'Europe/Sarajevo') into v_tz
  from public.salon_settings s where s.salon_id = p_salon_id;
  v_lokalno := p_now at time zone coalesce(v_tz, 'Europe/Sarajevo');

  if p_date < v_lokalno::date then
    raise exception 'Prosli dan je zakljucan i ne moze se proglasiti neradnim'
      using errcode = 'PT400';
  end if;

  if p_date = v_lokalno::date then
    select min(w.start_time) into v_otvara
    from public.working_hours w
    where w.salon_id = p_salon_id
      and w.day_of_week = extract(isodow from p_date)::int
      and not w.is_closed;

    if v_otvara is not null and v_lokalno::time >= v_otvara then
      raise exception 'Salon je danas vec otvorio; neradni dan se prijavljuje prije otvaranja'
        using errcode = 'PT400',
              hint = 'Termine danas otkazite pojedinacno.';
    end if;
  end if;
end;
$fn$;
revoke all on function private.assert_day_closable(uuid, date, timestamptz)
  from public, anon, authenticated;

-- Pregled prije potvrde: koji termini ce biti otkazani. Isti guard kao upis, da ekran ne
-- ponudi potvrdu koju ce RPC odbiti.
create function public.day_closure_preview(p_salon_id uuid, p_date date)
returns table (
  appointment_id uuid, date date, start_time time, end_time time,
  customer_name text, employee_name text
) language plpgsql stable security definer set search_path = '' as $fn$
begin
  perform private.assert_salon_access(p_salon_id);
  perform private.assert_day_closable(p_salon_id, p_date, now());
  return query
  select a.id, a.date, a.start_time, a.end_time, a.customer_name, a.employee_name
  from public.appointments a
  where a.salon_id = p_salon_id and a.date = p_date
    and a.status in ('pending', 'confirmed')
  order by a.start_time;
end;
$fn$;

-- Vraca broj otkazanih termina. Blokada cijelog dana nastaje u istoj transakciji, pa novi
-- termin ne moze uletjeti izmedju otkazivanja i zatvaranja.
create function public.set_day_closed(p_salon_id uuid, p_date date, p_reason text default null)
returns integer language plpgsql security definer set search_path = '' as $fn$
declare
  v_razlog text := nullif(btrim(coalesce(p_reason, '')), '');
  v_id uuid;
  v_broj integer := 0;
begin
  perform private.assert_salon_access(p_salon_id);
  perform private.assert_day_closable(p_salon_id, p_date, now());

  insert into public.blocked_slots(salon_id, employee_id, date, start_time, end_time, reason)
  select p_salon_id, null, p_date, '00:00', '23:59:59', coalesce(v_razlog, 'Neradni dan')
  -- Ponovljen poziv (dva tapa) ne pravi drugu blokadu istog dana.
  where not exists (
    select 1 from public.blocked_slots b
    where b.salon_id = p_salon_id and b.date = p_date and b.employee_id is null
      and b.start_time = '00:00' and b.end_time = '23:59:59'
  );

  for v_id in
    select a.id from public.appointments a
    where a.salon_id = p_salon_id and a.date = p_date
      and a.status in ('pending', 'confirmed')
    order by a.start_time
    for update
  loop
    perform public.cancel_appointment(p_salon_id, v_id, coalesce(v_razlog, 'Neradni dan'));
    v_broj := v_broj + 1;
  end loop;

  return v_broj;
end;
$fn$;

comment on function public.set_day_closed(uuid, date, text) is
  'Proglasava dan neradnim: blokira cijeli dan i otkazuje sve pending/confirmed termine kroz cancel_appointment (cancelled_by=salon). 42501 za ne-admina, PT400 za prosli dan i danas poslije otvaranja. Vraca broj otkazanih.';
comment on function public.day_closure_preview(uuid, date) is
  'Termini koje bi set_day_closed otkazao. Isti guard kao upis.';

revoke all on function public.set_day_closed(uuid, date, text) from public, anon;
grant execute on function public.set_day_closed(uuid, date, text) to authenticated;
revoke all on function public.day_closure_preview(uuid, date) from public, anon;
grant execute on function public.day_closure_preview(uuid, date) to authenticated;
