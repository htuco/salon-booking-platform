-- Task 33: osoblje nije nalog. Upis radnika i njegovih usluga je jedna transakcija.
revoke insert, update, delete on public.employees, public.employee_services
  from authenticated;

-- Klijent ne smije dobiti neaktivni katalog samo da bi procitao ime na svom terminu.
alter table public.appointments add column employee_name text;
update public.appointments a set employee_name = e.name
from public.employees e where e.salon_id = a.salon_id and e.id = a.employee_id;

create function private.snapshot_appointment_employee() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.employee_name := (select e.name from public.employees e
    where e.salon_id = new.salon_id and e.id = new.employee_id);
  return new;
end;
$$;
revoke all on function private.snapshot_appointment_employee() from public, anon, authenticated;
create trigger snapshot_appointment_employee
before insert or update of salon_id, employee_id on public.appointments
for each row execute function private.snapshot_appointment_employee();

create function private.validate_employee_input(
  p_salon_id uuid, p_name text, p_experience_years integer, p_service_ids uuid[]
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if nullif(btrim(p_name), '') is null or length(btrim(p_name)) > 120 then
    raise exception 'Ime mora imati od 1 do 120 znakova' using errcode = 'PT400';
  end if;
  if p_experience_years is not null and p_experience_years not between 0 and 80 then
    raise exception 'Staz mora biti izmedju 0 i 80 godina' using errcode = 'PT400';
  end if;
  if p_service_ids is null then
    raise exception 'Lista usluga je obavezna' using errcode = 'PT400';
  end if;
  if exists(select 1 from unnest(p_service_ids) x(id)
    where not exists(select 1 from public.services s
      where s.salon_id = p_salon_id and s.id = x.id)) then
    -- Jednako za tudji i nepostojeci ID, bez otkrivanja kataloga drugog salona.
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
end;
$$;
revoke all on function private.validate_employee_input(uuid,text,integer,uuid[])
  from public, anon, authenticated;

create function public.create_employee(
  p_salon_id uuid, p_name text, p_role text, p_bio text,
  p_experience_years integer, p_service_ids uuid[], p_image_url text default null
) returns public.employees language plpgsql security definer set search_path = '' as $$
declare v_row public.employees%rowtype;
begin
  perform private.validate_employee_input(p_salon_id,p_name,p_experience_years,p_service_ids);
  insert into public.employees(salon_id,name,role,bio,experience_years,image_url)
  values(p_salon_id,btrim(p_name),coalesce(btrim(p_role),''),coalesce(btrim(p_bio),''),
    p_experience_years,nullif(btrim(p_image_url),'')) returning * into v_row;
  insert into public.employee_services(salon_id,employee_id,service_id)
  select p_salon_id,v_row.id,x.id from (select distinct unnest(p_service_ids) id) x;
  return v_row;
end;
$$;

create function public.update_employee(
  p_salon_id uuid, p_employee_id uuid, p_name text, p_role text, p_bio text,
  p_experience_years integer, p_service_ids uuid[], p_image_url text default null
) returns public.employees language plpgsql security definer set search_path = '' as $$
declare v_row public.employees%rowtype;
begin
  perform private.validate_employee_input(p_salon_id,p_name,p_experience_years,p_service_ids);
  -- UPDATE zakljucava radnika prije zamjene veza: dva editora ne mogu pomijesati liste.
  update public.employees set name=btrim(p_name),role=coalesce(btrim(p_role),''),
    bio=coalesce(btrim(p_bio),''),experience_years=p_experience_years,
    image_url=nullif(btrim(p_image_url),'')
  where salon_id=p_salon_id and id=p_employee_id returning * into v_row;
  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  delete from public.employee_services
  where salon_id=p_salon_id and employee_id=p_employee_id
    and not(service_id = any(p_service_ids));
  insert into public.employee_services(salon_id,employee_id,service_id)
  select p_salon_id,p_employee_id,x.id from (select distinct unnest(p_service_ids) id) x
  on conflict (salon_id,employee_id,service_id) do nothing;
  return v_row;
end;
$$;

create function public.set_employee_active(p_salon_id uuid,p_employee_id uuid,p_is_active boolean)
returns public.employees language plpgsql security definer set search_path = '' as $$
declare v_row public.employees%rowtype;
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_is_active is null then
    raise exception 'Status je obavezan' using errcode = 'PT400';
  end if;
  update public.employees set is_active=p_is_active
  where salon_id=p_salon_id and id=p_employee_id returning * into v_row;
  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  -- Postojeci termini, smjene i veze ostaju, ukljucujuci buduce termine.
  return v_row;
end;
$$;

revoke all on function public.create_employee(uuid,text,text,text,integer,uuid[],text)
  from public,anon,authenticated;
revoke all on function public.update_employee(uuid,uuid,text,text,text,integer,uuid[],text)
  from public,anon,authenticated;
revoke all on function public.set_employee_active(uuid,uuid,boolean)
  from public,anon,authenticated;
grant execute on function public.create_employee(uuid,text,text,text,integer,uuid[],text)
  to authenticated;
grant execute on function public.update_employee(uuid,uuid,text,text,text,integer,uuid[],text)
  to authenticated;
grant execute on function public.set_employee_active(uuid,uuid,boolean) to authenticated;
