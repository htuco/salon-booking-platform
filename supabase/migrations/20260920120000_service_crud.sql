-- Admin CRUD nad cjenovnikom. Task 32.
--
-- `services` je do sada imala staff RLS, ali i direktne write grantove. To je znacilo da
-- je svaka validacija iz aplikacije samo konvencija. Od ove migracije admin pise kroz tri
-- uska RPC-a, a "brisanje" je promjena `is_active`: termini i veze sa radnicima ostaju.

-- Termin mora nositi ono sto je dogovoreno u trenutku rezervacije. `end_time` vec cuva
-- trajanje, ali cijena i naziv su se do sada citali iz zivog cjenovnika, pa bi promjena
-- cijene retroaktivno promijenila stari termin i promet na dashboardu.
alter table public.appointments
  add column service_name text,
  add column service_price numeric(10,2),
  add column service_duration_minutes integer;

update public.appointments a
set service_name = s.name,
    service_price = s.price,
    service_duration_minutes = extract(epoch from (a.end_time - a.start_time))::integer / 60
from public.services s
where s.salon_id = a.salon_id and s.id = a.service_id;

alter table public.appointments
  alter column service_name set not null,
  alter column service_price set not null,
  alter column service_duration_minutes set not null,
  add constraint appointments_service_price_nonnegative check (service_price >= 0),
  add constraint appointments_service_duration_positive
    check (service_duration_minutes > 0 and service_duration_minutes <= 1440);

create function private.snapshot_appointment_service()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_service public.services%rowtype;
begin
  select * into v_service
  from public.services s
  where s.salon_id = new.salon_id and s.id = new.service_id;

  if not found then
    raise exception 'Usluga ne postoji' using errcode = '23503';
  end if;

  -- Vrijednosti iz payload-a se namjerno prepisuju: pozivalac ne bira historijsku cijenu.
  new.service_name := v_service.name;
  new.service_price := v_service.price;
  new.service_duration_minutes := v_service.duration_minutes;
  return new;
end;
$$;

revoke all on function private.snapshot_appointment_service() from public, anon, authenticated;

create trigger snapshot_appointment_service
before insert or update of salon_id, service_id on public.appointments
for each row execute function private.snapshot_appointment_service();

create function public.create_service(
  p_salon_id uuid,
  p_name text,
  p_description text,
  p_category text,
  p_price numeric,
  p_duration_minutes integer,
  p_image_url text default null
) returns public.services
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.services%rowtype;
begin
  if not private.is_admin(p_salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if nullif(btrim(p_name), '') is null then
    raise exception 'Naziv je obavezan' using errcode = 'PT400';
  end if;
  if p_price is null or p_price < 0 then
    raise exception 'Cijena mora biti nula ili veca' using errcode = 'PT400';
  end if;
  if p_duration_minutes is null or p_duration_minutes not between 1 and 1440 then
    raise exception 'Trajanje mora biti izmedju 1 i 1440 minuta' using errcode = 'PT400';
  end if;

  insert into public.services (
    salon_id, name, description, category, price, duration_minutes, image_url
  ) values (
    p_salon_id,
    btrim(p_name),
    coalesce(btrim(p_description), ''),
    coalesce(btrim(p_category), ''),
    p_price,
    p_duration_minutes,
    nullif(btrim(p_image_url), '')
  ) returning * into v_row;
  return v_row;
end;
$$;

create function public.update_service(
  p_salon_id uuid,
  p_service_id uuid,
  p_name text,
  p_description text,
  p_category text,
  p_price numeric,
  p_duration_minutes integer,
  p_image_url text default null
) returns public.services
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.services%rowtype;
begin
  if not private.is_admin(p_salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if nullif(btrim(p_name), '') is null then
    raise exception 'Naziv je obavezan' using errcode = 'PT400';
  end if;
  if p_price is null or p_price < 0 then
    raise exception 'Cijena mora biti nula ili veca' using errcode = 'PT400';
  end if;
  if p_duration_minutes is null or p_duration_minutes not between 1 and 1440 then
    raise exception 'Trajanje mora biti izmedju 1 i 1440 minuta' using errcode = 'PT400';
  end if;

  update public.services s
  set name = btrim(p_name),
      description = coalesce(btrim(p_description), ''),
      category = coalesce(btrim(p_category), ''),
      price = p_price,
      duration_minutes = p_duration_minutes,
      image_url = nullif(btrim(p_image_url), '')
  where s.salon_id = p_salon_id and s.id = p_service_id
  returning * into v_row;

  if not found then
    -- Ista greska za nepostojecu i tudju uslugu: RPC nije endpoint za nabrajanje ID-eva.
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  return v_row;
end;
$$;

create function public.set_service_active(
  p_salon_id uuid,
  p_service_id uuid,
  p_is_active boolean
) returns public.services
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.services%rowtype;
begin
  if not private.is_admin(p_salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_is_active is null then
    raise exception 'Status usluge je obavezan' using errcode = 'PT400';
  end if;

  update public.services s
  set is_active = p_is_active
  where s.salon_id = p_salon_id and s.id = p_service_id
  returning * into v_row;

  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  return v_row;
end;
$$;

revoke all on function public.create_service(uuid, text, text, text, numeric, integer, text)
  from public, anon;
revoke all on function public.update_service(uuid, uuid, text, text, text, numeric, integer, text)
  from public, anon;
revoke all on function public.set_service_active(uuid, uuid, boolean)
  from public, anon;
grant execute on function public.create_service(uuid, text, text, text, numeric, integer, text)
  to authenticated;
grant execute on function public.update_service(uuid, uuid, text, text, text, numeric, integer, text)
  to authenticated;
grant execute on function public.set_service_active(uuid, uuid, boolean)
  to authenticated;

-- Oduzimanje granta je sigurnosna granica; RPC bez ovoga bio bi samo preporuceni put.
revoke insert, update, delete on public.services from authenticated;

comment on table public.services is
  'Cjenovnik salona. authenticated cita kroz RLS, a kreira/mijenja/deaktivira iskljucivo kroz create_service, update_service i set_service_active; fizicko brisanje nije aplikacijska operacija.';
comment on column public.appointments.service_price is
  'Cijena usluge u trenutku rezervacije; promjena cjenovnika ne mijenja historijski termin.';
