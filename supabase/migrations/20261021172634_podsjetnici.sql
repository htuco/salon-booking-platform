-- Task 56: push podsjetnici (ADR-0033).
--
-- Dnevni podsjetnik (`reminder_d1`) ide tacno 24 h prije pocetka termina, satni (`reminder_h3`)
-- N sati prije, a N bira salon. Ime enuma `reminder_h3` ostaje i kad je N razlicit od 3.
--
-- Obrazac je task 64: pravilo je SQL u bazi, `pg_cron` ga zove svakih 5 minuta, a slanje ide
-- postojecim putem (`notification_logs` → `dispatch_push` → `send-push`). Edge Function
-- `send-reminders` ne postoji; worker bi samo prepisao ovaj upit i dodao jos jedan HTTP skok.
--
-- Cetiri stvari:
--
--   1. **Postavke.** `reminders_enabled` (postoji od init seme) sada znaci samo dnevni.
--      Satni dobija `hourly_reminder_enabled` i `hourly_reminder_hours` (1–12, prijedlog iz
--      ADR-0033). `update_salon_settings` ih prima kroz **novu verziju istog imena**: stari
--      potpis se dropa prije `create` (zamka iz taskova 24 i 37 — `create` sa novim
--      parametrom pravi drugi overload, ne zamjenu). Novi parametri imaju `default null`
--      (= ne mijenjaj), pa Melura iz storea koja salje stari skup argumenata i dalje pogadja
--      jedinu funkciju i ne gasi podsjetnike.
--   2. **`appointments.confirmed_at`.** Pravilo „zakazan ili potvrdjen kasnije od trenutka
--      podsjetnika → ne salje se" (prijedlog iz ADR-0033) treba trenutak potvrde, a
--      `created_at` je trenutak zahtjeva. Pise ga samo trigger. Stari termini ostaju `null` i
--      citaju se kao `created_at` — bez backfill `update`-a, koji bi pomjerio `updated_at` i
--      okinuo `availability_signal` za svaki termin.
--   3. **`private.queue_reminders()`** + cron `queue-reminders`.
--   4. **`claim_push_notifications`** ne salje podsjetnik koji vise ne vrijedi, i daje
--      `send-push`-u rijec za termin po vertikali i minute do pocetka.

-- ---------------------------------------------------------------------------
-- 1. Postavke
-- ---------------------------------------------------------------------------
alter table public.salon_settings
  add column hourly_reminder_enabled boolean not null default true,
  add column hourly_reminder_hours int not null default 3
    constraint salon_settings_hourly_reminder_hours_check
      check (hourly_reminder_hours between 1 and 12);

comment on column public.salon_settings.reminders_enabled is
  'Dnevni podsjetnik (reminder_d1): push klijentu tacno 24 h prije pocetka termina. Od taska 56 ne gasi satni.';
comment on column public.salon_settings.hourly_reminder_enabled is
  'Satni podsjetnik (reminder_h3): push klijentu hourly_reminder_hours sati prije pocetka termina.';
comment on column public.salon_settings.hourly_reminder_hours is
  'N za satni podsjetnik, 1–12 (ADR-0033). Enum ostaje reminder_h3 i kad je N razlicit od 3.';

drop function if exists public.update_salon_settings(
  uuid, text, text, int, int, int, int, int, boolean, boolean
);

create function public.update_salon_settings(
  p_salon_id uuid,
  p_booking_mode text,
  p_booking_granularity text,
  p_buffer_minutes int,
  p_slot_step_minutes int,
  p_min_advance_booking_hours int,
  p_max_advance_booking_days int,
  p_min_cancel_hours int,
  p_require_staff_choice boolean,
  p_show_prices_in_app boolean,
  p_reminders_enabled boolean default null,
  p_hourly_reminder_enabled boolean default null,
  p_hourly_reminder_hours int default null
) returns public.salon_settings
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_row public.salon_settings%rowtype;
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  if p_booking_mode not in ('manual', 'auto') then
    raise exception 'Nepoznat nacin potvrde' using errcode = 'PT400';
  end if;
  if p_booking_granularity not in ('exact_slot', 'date_only') then
    raise exception 'Nepoznata granularnost' using errcode = 'PT400';
  end if;
  if p_buffer_minutes is null or p_buffer_minutes not between 0 and 120 then
    raise exception 'Pauza izmedju termina mora biti 0-120 minuta' using errcode = 'PT400';
  end if;
  if p_slot_step_minutes is null or p_slot_step_minutes not between 1 and 120 then
    raise exception 'Korak termina mora biti 1-120 minuta' using errcode = 'PT400';
  end if;
  if p_min_advance_booking_hours is null or p_min_advance_booking_hours < 0 then
    raise exception 'Najraniji termin ne moze biti negativan' using errcode = 'PT400';
  end if;
  if p_max_advance_booking_days is null or p_max_advance_booking_days <= 0 then
    raise exception 'Kalendar mora biti otvoren bar jedan dan unaprijed' using errcode = 'PT400';
  end if;
  if p_min_cancel_hours is null or p_min_cancel_hours < 0 then
    raise exception 'Rok otkazivanja ne moze biti negativan' using errcode = 'PT400';
  end if;
  -- Ista granica kao `check`, da greska stigne kao recenica (PT400), a ne kao 23514.
  if p_hourly_reminder_hours is not null and p_hourly_reminder_hours not between 1 and 12 then
    raise exception 'Satni podsjetnik mora biti 1-12 sati prije termina' using errcode = 'PT400';
  end if;

  update public.salon_settings st set
    booking_mode = p_booking_mode,
    booking_granularity = p_booking_granularity,
    buffer_minutes = p_buffer_minutes,
    slot_step_minutes = p_slot_step_minutes,
    min_advance_booking_hours = p_min_advance_booking_hours,
    max_advance_booking_days = p_max_advance_booking_days,
    min_cancel_hours = p_min_cancel_hours,
    require_staff_choice = coalesce(p_require_staff_choice, false),
    show_prices_in_app = coalesce(p_show_prices_in_app, true),
    -- `null` = ne mijenjaj: stari klijent ne salje ove argumente i ne smije ih ugasiti.
    reminders_enabled = coalesce(p_reminders_enabled, st.reminders_enabled),
    hourly_reminder_enabled = coalesce(p_hourly_reminder_enabled, st.hourly_reminder_enabled),
    hourly_reminder_hours = coalesce(p_hourly_reminder_hours, st.hourly_reminder_hours)
  where st.salon_id = p_salon_id
  returning * into v_row;

  if not found then
    raise exception 'Salon nema red u salon_settings' using errcode = 'PT404';
  end if;
  return v_row;
end;
$fn$;

comment on function public.update_salon_settings(
  uuid, text, text, int, int, int, int, int, boolean, boolean, boolean, boolean, int
) is
  'Booking pravila i podsjetnici salona iz admina. Podsjetnici: null = ne mijenjaj. Zona, jezik i auth provideri ostaju platformski.';

revoke all on function public.update_salon_settings(
  uuid, text, text, int, int, int, int, int, boolean, boolean, boolean, boolean, int
) from public, anon, authenticated;
grant execute on function public.update_salon_settings(
  uuid, text, text, int, int, int, int, int, boolean, boolean, boolean, boolean, int
) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Trenutak potvrde
-- ---------------------------------------------------------------------------
alter table public.appointments add column confirmed_at timestamptz;

comment on column public.appointments.confirmed_at is
  'Kad je termin postao confirmed (upis ili prelaz). Pise ga samo trigger stamp_confirmed_at. NULL kod termina potvrdjenih prije taska 56: citaj kao created_at.';

-- Vrijednost iz upisa se ne prihvata: put koji bi je poslao (danas nijedan) ne smije
-- pomjeriti trenutak potvrde unazad i tako vratiti podsjetnik koji pravilo iskljucuje.
create function private.stamp_confirmed_at() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.confirmed_at := case when new.status = 'confirmed' then now() end;
  elsif new.status = 'confirmed' and old.status is distinct from 'confirmed' then
    new.confirmed_at := now();
  end if;
  return new;
end $$;
revoke all on function private.stamp_confirmed_at() from public, anon, authenticated;

create trigger stamp_confirmed_at
  before insert or update of status on public.appointments
  for each row execute function private.stamp_confirmed_at();

-- ---------------------------------------------------------------------------
-- 3. Pravljenje podsjetnika
-- ---------------------------------------------------------------------------
-- Prozori, svi u zoni salona (`date` i `start_time` su lokalni, cron radi u UTC-u):
--
--   dnevni: od (pocetak - 24 h) do ponoci pred dan termina. Poslije ponoci bi „sutra" u
--           tekstu bila laz, pa red koji tada nije nastao vise ne nastaje.
--   satni:  od (pocetak - N h) do pocetka.
--
-- Pocetak prozora je trenutak podsjetnika; kasno pokretanje crona (ili salon koji podsjetnik
-- ukljuci kasnije) ga jos uvijek posalje dok prozor traje. Kraj prozora drzi „nikad poslije
-- pocetka".
--
-- Termin zakazan ili potvrdjen **poslije** trenutka podsjetnika ga ne dobija (prijedlog iz
-- ADR-0033): klijent je upravo zakazao ili dobio „Zahtjev je potvrdjen", i podsjetnik minut
-- kasnije bi bio drugi push o istom.
--
-- Primalac: svaki klijentski uredjaj vlasnika termina **u salonu termina**, sa tokenom. Kao
-- ponuda liste cekanja (task 68), a ne samo `appointments.device_id`: klijent koji je
-- reinstalirao app ili ima i tablet je i dalje vlasnik termina. Osoblje nikad.
--
-- `p_now` postoji samo da pgTAP moze postaviti sat; cron je zove bez argumenta. Funkciju
-- zove samo `service_role`, koji ionako smije pisati `notification_logs`.
create function private.queue_reminders(p_now timestamptz default now()) returns integer
language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  insert into public.notification_logs (salon_id, appointment_id, device_id, type)
  select r.salon_id, r.id, d.id, r.type
  from (
    select a.salon_id, a.id, a.auth_identity_id, k.type
    from public.appointments a
    left join public.salon_settings s on s.salon_id = a.salon_id
    cross join lateral (
      select coalesce(s.timezone, 'Europe/Sarajevo') as zona
    ) z
    cross join lateral (
      select (a.date + a.start_time) at time zone z.zona as pocetak,
             a.date::timestamp at time zone z.zona as ponoc
    ) t
    cross join lateral (values
      ('reminder_d1'::public.notification_type,
        coalesce(s.reminders_enabled, true),
        t.pocetak - interval '24 hours',
        t.ponoc),
      ('reminder_h3'::public.notification_type,
        coalesce(s.hourly_reminder_enabled, true),
        t.pocetak - make_interval(hours => coalesce(s.hourly_reminder_hours, 3)),
        t.pocetak)
    ) k(type, ukljucen, trenutak, kraj)
    where a.status = 'confirmed'
      and a.auth_identity_id is not null
      -- Samo da upit ne cita cijelu istoriju: lokalni dan termina koji pocinje u sljedecih
      -- 24 h je unutar [UTC danas - 1, UTC danas + 2] za svaku zonu.
      and a.date between (p_now at time zone 'UTC')::date - 1
                     and (p_now at time zone 'UTC')::date + 2
      and private.salon_active(a.salon_id)
      and k.ukljucen
      and k.trenutak <= p_now
      and p_now < k.kraj
      -- `confirmed_at` je uvijek >= `created_at`, pa ovaj jedan uslov pokriva i „zakazan
      -- kasnije" i „potvrdjen kasnije". NULL je termin potvrdjen prije taska 56.
      and coalesce(a.confirmed_at, a.created_at) <= k.trenutak
  ) r
  join public.devices d
    on d.salon_id = r.salon_id
   and d.staff_user_id is null
   and d.auth_identity_id = r.auth_identity_id
   and d.fcm_token is not null
  where exists (select 1 from public.auth_identities i
                where i.id = r.auth_identity_id and i.deleted_at is null)
  on conflict (appointment_id, device_id, type) do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end $$;

revoke all on function private.queue_reminders(timestamptz) from public, anon, authenticated;
grant execute on function private.queue_reminders(timestamptz) to service_role;

comment on function private.queue_reminders(timestamptz) is
  'Pravi redove reminder_d1 (24 h prije, do ponoci pred dan termina) i reminder_h3 (N h prije, do pocetka) u notification_logs za confirmed termine, klijentskim uredjajima vlasnika u salonu termina. Ne za termin zakazan ili potvrdjen poslije trenutka podsjetnika. Jednom po (termin, uredjaj, tip). Vraca broj novih redova. Zove je pg_cron svakih 5 min.';

-- Svakih 5 minuta, kao `expire-pending`: podsjetnik minut-dva kasnije je nevidljiv, a upit
-- cita samo potvrdjene termine u tri dana oko danas.
select cron.schedule('queue-reminders', '*/5 * * * *', 'select private.queue_reminders()');

-- ---------------------------------------------------------------------------
-- 4. Slanje: podsjetnik koji vise ne vrijedi se ne salje
-- ---------------------------------------------------------------------------
-- Redefinisano iz `20261020140000_lista_cekanja.sql`. Argumenti i grantovi isti; izlaz dobija
-- dvije kolone, pa `create or replace` ne moze (Postgres ne mijenja tip izlaza) — drop, pa
-- create. Stari `send-push` nove kolone ignorise, a novi bez njih pada na genericki tekst.
--
-- Red podsjetnika ide u `logged` sa razlogom, umjesto da ode, kad:
--   - termin vise nije `confirmed` (otkazan, zavrsen, no-show) — red je mogao cekati u redu;
--   - je termin poceo;
--   - je salon u medjuvremenu ugasio taj podsjetnik;
--   - je dnevni zakasnio preko ponoci pred dan termina („sutra" vise nije istina).
drop function public.claim_push_notifications(int);

create function public.claim_push_notifications(p_limit int default 20)
returns table (id uuid, salon_id uuid, appointment_id uuid, type public.notification_type,
  fcm_token text, staff boolean, appointment_term text, starts_in_minutes int)
language plpgsql security definer set search_path = '' as $$
begin
  update public.notification_logs n set status = 'logged', error = v.razlog
  from (
    select n2.id,
      case
        when a.status is distinct from 'confirmed' then 'appointment_not_confirmed'
        when now() >= t.pocetak then 'appointment_started'
        when n2.type = 'reminder_d1' and not coalesce(s.reminders_enabled, true)
          then 'reminder_disabled'
        when n2.type = 'reminder_h3' and not coalesce(s.hourly_reminder_enabled, true)
          then 'reminder_disabled'
        when n2.type = 'reminder_d1' and now() >= t.ponoc then 'reminder_late'
      end as razlog
    from public.notification_logs n2
    left join public.appointments a
      on a.id = n2.appointment_id and a.salon_id = n2.salon_id
    left join public.salon_settings s on s.salon_id = n2.salon_id
    cross join lateral (
      select (a.date + a.start_time) at time zone coalesce(s.timezone, 'Europe/Sarajevo') as pocetak,
             a.date::timestamp at time zone coalesce(s.timezone, 'Europe/Sarajevo') as ponoc
    ) t
    where n2.status = 'queued' and n2.type in ('reminder_d1', 'reminder_h3')
  ) v
  where n.id = v.id and v.razlog is not null and n.status = 'queued';

  -- Provjera primaoca iz taska 68, nepromijenjena.
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
    d.staff_user_id is not null,
    -- Rijec za termin po vertikali, sa override-om salona kljuc po kljuc — isto pravilo kao
    -- `VerticalTerms.mergeOverride` u aplikaciji.
    coalesce(nullif(sa.terminology_override->>'appointmentSingular', ''),
             nullif(vp.terminology->>'appointmentSingular', ''),
             'Termin'),
    -- Minute do pocetka pri slanju, ne N iz postavke: red koji ceka ili salon koji promijeni
    -- N ne smiju dati tekst koji laze.
    case when n.type = 'reminder_h3' then
      greatest(1, ceil(extract(epoch from (
        (a.date + a.start_time) at time zone coalesce(s.timezone, 'Europe/Sarajevo') - now()
      )) / 60))::int
    end
  from claimed n
  join public.devices d on d.id = n.device_id and d.salon_id = n.salon_id
  join public.salons sa on sa.id = n.salon_id
  left join public.vertical_packs vp on vp.key = sa.vertical_pack_key
  left join public.appointments a on a.id = n.appointment_id and a.salon_id = n.salon_id
  left join public.salon_settings s on s.salon_id = n.salon_id;
end $$;
revoke all on function public.claim_push_notifications(int) from public, anon, authenticated;
grant execute on function public.claim_push_notifications(int) to service_role;

comment on function public.claim_push_notifications(int) is
  'Samo service_role (send-push). Gasi redove bez valjanog primaoca i podsjetnike koji vise ne vrijede (termin nije confirmed, poceo je, podsjetnik ugasen, dnevni poslije ponoci), pa preuzima do p_limit redova. appointment_term je rijec za termin po vertikali, starts_in_minutes minute do pocetka za reminder_h3.';
