-- Task 64: istek neodgovorenih zahtjeva.
--
-- `appointments.pending_expires_at` postoji od init seme i `book_appointment` ga puni iz
-- `salon_settings.pending_expiry_hours`, ali ga do sada niko nije citao. Zahtjev na koji salon
-- zaboravi odgovoriti je zato **zauvijek drzao termin**: `pending` ulazi u exclusion constraint
-- i u zauzetost u `get_available_slots`. Na salonu sa jednim radnikom to je jedan zaboravljen
-- zahtjev = jedan izgubljen termin, a klijent ne zna ni da treba traziti drugi.
--
-- **Isteklo nije novi status.** Isteklo je `cancelled` sa `cancelled_by = 'system'` i
-- `cancel_reason = 'isteklo'` — vrijednost `system` je u enumu `cancelled_by` od init seme
-- upravo za ovo (v. `security.md`, „Otkazivanje"). Novi status bi znacio da svaki filter
-- (`status <> 'cancelled'`), exclusion constraint i brojac treba znati za njega; propusten
-- na jednom mjestu, istekli termin bi i dalje drzao slot.
--
-- **Rok se ne preracunava.** `pending_expires_at` je zapisan pri zahtjevu iz postavke koja je
-- tada vrijedila. Promjena `pending_expiry_hours` vrijedi unaprijed, kao i `booking_mode`
-- (task 37) — vlasnik koji produzi rok nije time produzio zahtjeve koji vec cekaju.
--
-- **Termin koji pocne prije roka se zatvara najkasnije na svoj pocetak.** Zahtjev za termin
-- za dva sata uz rok od 12 sati bi inace cekao odgovor jos deset sati nakon sto je termin
-- prosao. Pocetak se racuna u vremenskoj zoni salona, jer su `date` i `start_time` lokalni.

-- Nova vrijednost se u istoj transakciji ne smije **upotrijebiti**, ali tijelo plpgsql
-- funkcije se razrjesava tek pri pozivu (isti obrazac kao `new_booking` u tasku 39).
alter type public.notification_type add value if not exists 'expired';

create function private.expire_pending() returns integer
language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  -- `skip locked`: termin koji vlasnik upravo potvrdjuje ceka sljedeci prolaz umjesto da
  -- cron ceka na njegovu transakciju. Ponovljen uslov `status = 'pending'` u `update`-u je
  -- druga brava — red koji je u medjuvremenu potvrdjen se ne dira.
  with istekli as (
    select a.id
    from public.appointments a
    left join public.salon_settings s on s.salon_id = a.salon_id
    where a.status = 'pending'
      and (a.pending_expires_at <= now()
        or (a.date + a.start_time) at time zone coalesce(s.timezone, 'Europe/Sarajevo') <= now())
    for update of a skip locked
  )
  update public.appointments a
  set status = 'cancelled', cancelled_by = 'system', cancel_reason = 'isteklo'
  from istekli
  where a.id = istekli.id and a.status = 'pending';

  get diagnostics v_count = row_count;
  return v_count;
end $$;

revoke all on function private.expire_pending() from public, anon, authenticated;
grant execute on function private.expire_pending() to service_role;

comment on function private.expire_pending() is
  'Zatvara pending termine ciji je rok (pending_expires_at) ili pocetak prosao: cancelled, cancelled_by=system, cancel_reason=isteklo. Vraca broj zatvorenih. Zove je pg_cron svakih 5 min.';

-- Push klijentu: istekli zahtjev je promjena statusa kao i odbijanje, pa ide kroz isti
-- trigger i isti `dispatch_push`. Zaseban tip, a ne `rejected`: „Zahtjev je odbijen" bi
-- klijentu rekao da je salon rekao ne, a salon nije rekao nista.
create or replace function private.queue_appointment_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_type public.notification_type; v_staff boolean := false;
begin
  if tg_op = 'INSERT' then
    -- Rucni unos iz salona ne obavjestava salon o samom sebi, pa `source` i dalje presudjuje
    -- prvi. Status vise ne odlucuje **hoce li** se slati nego **sta** se salje.
    if new.source <> 'app' then return new; end if;
    if new.status = 'pending' then
      v_type := 'new_request';
    elsif new.status = 'confirmed' then
      v_type := 'new_booking';
    else
      return new;
    end if;
    v_staff := true;
  elsif new.status is not distinct from old.status then
    return new;
  elsif new.status = 'confirmed' then
    v_type := 'confirmed';
  elsif new.status = 'cancelled' and new.cancelled_by = 'salon' then
    v_type := case when old.status = 'pending' then 'rejected'::public.notification_type
      else 'cancelled'::public.notification_type end;
  elsif new.status = 'cancelled' and new.cancelled_by = 'customer' then
    v_type := 'cancelled'; v_staff := true;
  elsif new.status = 'cancelled' and new.cancelled_by = 'system' and old.status = 'pending' then
    v_type := 'expired';
  else return new;
  end if;

  insert into public.notification_logs(salon_id, appointment_id, device_id, type)
  select new.salon_id, new.id, d.id, v_type from public.devices d
  where d.salon_id = new.salon_id and d.fcm_token is not null and (
    (v_staff and exists (select 1 from public.users u where u.id = d.staff_user_id
      and u.salon_id = new.salon_id and u.role = 'salon_admin'))
    or (not v_staff and d.id = new.device_id and d.staff_user_id is null
      and d.auth_identity_id = new.auth_identity_id)
  ) on conflict (appointment_id, device_id, type) do nothing;
  return new;
end $$;

revoke all on function private.queue_appointment_push() from public, anon, authenticated;

comment on function private.queue_appointment_push() is
  'Puni notification_logs iz promjene termina. INSERT sa source=app javlja salonu: new_request u manual modu, new_booking u auto modu. Promjena statusa javlja klijentu (confirmed/rejected/cancelled, a istek zahtjeva kao expired), a otkazivanje od klijenta salonu.';

-- Svakih 5 minuta: rok je u satima, pa je pet minuta kasnjenja nevidljivo, a prolaz cita
-- samo `pending` redove, kojih je u svakom trenutku malo.
select cron.schedule('expire-pending', '*/5 * * * *', 'select private.expire_pending()');
