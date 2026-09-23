-- Task 41: svaki klijent se prijavljuje emailom, Googleom ili Appleom.
--
-- Supabase anonymous auth nije isto sto i Postgres rola `anon`: anonimna Auth sesija
-- dobija JWT i rolu `authenticated`. Zato `grant execute ... to authenticated` nije
-- dovoljna granica. Centralni `private.is_client()` sada trazi i stvarni, neanonimni
-- `auth_identities` red pozivaoca. Time isti guard zatvara `ensure_customer`,
-- `book_appointment`, otkazivanje i klijentske RLS politike, umjesto da svako mjesto
-- zasebno pamti novu vrstu identiteta.
create or replace function private.is_client() returns boolean
language sql stable security definer set search_path = ''
as $$
  select
    coalesce(auth.jwt()->'app_metadata'->>'role', 'client')
      not in ('super_admin', 'salon_admin', 'employee')
    and exists (
      select 1
      from public.auth_identities ai
      where ai.supabase_user_id = auth.uid()
        and ai.deleted_at is null
        and ai.is_anonymous is false
    )
$$;

comment on function private.is_client() is
  'Pravi klijentski nalog: neprivilegovana JWT uloga i aktivan, neanoniman auth identitet. Supabase anonymous Auth sesija nije klijent.';

revoke all on function private.is_client() from public;
grant execute on function private.is_client() to anon, authenticated, service_role;

-- Uklanjanje parametra mijenja potpis. Stara verzija mora nestati prije nove, inace bi
-- PostgREST zadrzao oba overload-a i stari klijent bi i dalje mogao slati guest flag.
drop function if exists public.update_salon_settings(
  uuid, text, text, int, int, int, int, int, boolean, boolean, boolean
);

-- Iskljucen flag i dalje naplacuje odrzavanje kroz modele, RPC i UI. Odluka je zato
-- uklanjanje kolone, isti obrazac kao ADR-0011 za Facebook, a ne `check (... = false)`.
alter table public.salon_settings drop column allow_guest_booking;

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
  p_show_prices_in_app boolean
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

  update public.salon_settings st set
    booking_mode = p_booking_mode,
    booking_granularity = p_booking_granularity,
    buffer_minutes = p_buffer_minutes,
    slot_step_minutes = p_slot_step_minutes,
    min_advance_booking_hours = p_min_advance_booking_hours,
    max_advance_booking_days = p_max_advance_booking_days,
    min_cancel_hours = p_min_cancel_hours,
    require_staff_choice = coalesce(p_require_staff_choice, false),
    show_prices_in_app = coalesce(p_show_prices_in_app, true)
  where st.salon_id = p_salon_id
  returning * into v_row;

  if not found then
    raise exception 'Salon nema red u salon_settings' using errcode = 'PT404';
  end if;
  return v_row;
end;
$fn$;

comment on function public.update_salon_settings(
  uuid, text, text, int, int, int, int, int, boolean, boolean
) is
  'Booking pravila salona iz admina. Guest booking ne postoji; zona, jezik i auth provideri ostaju platformski.';

revoke all on function public.update_salon_settings(
  uuid, text, text, int, int, int, int, int, boolean, boolean
) from public, anon, authenticated;
grant execute on function public.update_salon_settings(
  uuid, text, text, int, int, int, int, int, boolean, boolean
) to authenticated;
