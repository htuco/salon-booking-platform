-- Tajna instalacije nije javni ID niti FCM token. Ne smije izaci kroz SELECT/REST.
create table private.device_credentials (
  salon_id uuid not null,
  device_id uuid primary key,
  secret_hash bytea not null,
  foreign key (salon_id, device_id) references public.devices(salon_id, id) on delete cascade
);
alter table private.device_credentials enable row level security;
revoke all on private.device_credentials from public, anon, authenticated;
grant all on private.device_credentials to service_role;

revoke insert, update, delete on public.devices from anon, authenticated;

create function public.register_device(
  p_salon_id uuid, p_installation_id uuid, p_secret text,
  p_platform public.device_platform, p_fcm_token text default null,
  p_staff boolean default false
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_device public.devices;
  v_identity uuid;
  v_staff uuid;
begin
  if p_secret is null or p_secret !~ '^[a-f0-9]{64}$'
     or p_installation_id is null or p_platform is null or p_staff is null
     or length(p_fcm_token) > 4096 or p_fcm_token = '' then
    raise exception 'Neispravna registracija' using errcode = 'PT400';
  end if;
  if p_staff then
    if private.is_admin(p_salon_id) is not true or not exists (
      select 1 from public.users where id = auth.uid() and salon_id = p_salon_id
        and role = 'salon_admin'
    ) then
      raise exception 'Nije dozvoljeno' using errcode = '42501';
    end if;
    v_staff := auth.uid();
  else
    if (private.is_client() and p_salon_id = private.client_salon_id()) is not true then
      raise exception 'Nije dozvoljeno' using errcode = '42501';
    end if;
    if auth.uid() is not null then
      select id into v_identity from public.auth_identities
      where supabase_user_id = auth.uid() and deleted_at is null;
      if v_identity is null then
        raise exception 'Nije dozvoljeno' using errcode = '42501';
      end if;
    end if;
  end if;

  -- Serijalizuje i prvi upis: SELECT FOR UPDATE ne zakljucava nepostojeci red.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    p_salon_id::text || p_installation_id::text, 0));
  select * into v_device from public.devices
  where salon_id = p_salon_id and device_id = p_installation_id::text for update;
  if found then
    if not exists (select 1 from private.device_credentials
      where device_id = v_device.id and salon_id = p_salon_id
        and secret_hash = extensions.digest(p_secret, 'sha256')) then
      raise exception 'Nije dozvoljeno' using errcode = '42501';
    end if;
    if v_device.auth_identity_id is distinct from v_identity
       or v_device.staff_user_id is distinct from v_staff then
      update public.notification_logs set status = 'logged', error = 'recipient_changed'
      where device_id = v_device.id and status = 'queued';
    end if;
    update public.devices set fcm_token = p_fcm_token, platform = p_platform,
      auth_identity_id = v_identity, staff_user_id = v_staff, last_seen_at = now()
    where id = v_device.id;
  else
    insert into public.devices(salon_id, device_id, platform, fcm_token,
      auth_identity_id, staff_user_id)
    values(p_salon_id, p_installation_id::text, p_platform, p_fcm_token, v_identity, v_staff)
    returning * into v_device;
    insert into private.device_credentials values
      (p_salon_id, v_device.id, extensions.digest(p_secret, 'sha256'));
  end if;
  return v_device.id;
end $$;
revoke all on function public.register_device(uuid,uuid,text,public.device_platform,text,boolean)
  from public, anon, authenticated;
grant execute on function public.register_device(uuid,uuid,text,public.device_platform,text,boolean)
  to anon, authenticated;

-- Odjava radi i nakon isteka JWT-a, ali samo uz tajnu bas te instalacije.
create function public.unregister_device(p_salon_id uuid, p_installation_id uuid, p_secret text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  select d.id into v_id from public.devices d join private.device_credentials c
    on c.device_id = d.id and c.salon_id = d.salon_id
  where d.salon_id = p_salon_id and d.device_id = p_installation_id::text
    and c.secret_hash = extensions.digest(p_secret, 'sha256') for update of d;
  if v_id is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  update public.devices set fcm_token = null, auth_identity_id = null, staff_user_id = null
  where id = v_id;
  update public.notification_logs set status = 'logged', error = 'signed_out'
  where device_id = v_id and status = 'queued';
end $$;
revoke all on function public.unregister_device(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.unregister_device(uuid,uuid,text) to anon, authenticated;

-- Kompozitni FK provjerava salon, ali ne i vlasnika uredjaja unutar istog salona.
create function private.validate_appointment_device() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.device_id is not null and not exists (
    select 1 from public.devices d where d.id = new.device_id and d.salon_id = new.salon_id
      and d.staff_user_id is null and d.auth_identity_id = new.auth_identity_id
      and new.auth_identity_id is not null
  ) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  return new;
end $$;
revoke all on function private.validate_appointment_device() from public, anon, authenticated;
create trigger validate_appointment_device before insert or update of device_id on public.appointments
for each row execute function private.validate_appointment_device();

create function private.queue_appointment_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_type public.notification_type; v_staff boolean := false;
begin
  if tg_op = 'INSERT' then
    if new.source <> 'app' or new.status <> 'pending' then return new; end if;
    v_type := 'new_request'; v_staff := true;
  elsif new.status is not distinct from old.status then
    return new;
  elsif new.status = 'confirmed' then
    v_type := 'confirmed';
  elsif new.status = 'cancelled' and new.cancelled_by = 'salon' then
    v_type := case when old.status = 'pending' then 'rejected'::public.notification_type
      else 'cancelled'::public.notification_type end;
  elsif new.status = 'cancelled' and new.cancelled_by = 'customer' then
    v_type := 'cancelled'; v_staff := true;
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
create trigger queue_appointment_push after insert or update of status on public.appointments
for each row execute function private.queue_appointment_push();

-- Jedan worker preuzme red samo jednom. Ne ponavljamo nepoznat ishod FCM zahtjeva:
-- HTTP timeout moze znaciti da je FCM prihvatio poruku, a odgovor nije stigao.
create function public.claim_push_notifications(p_limit int default 20)
returns table (id uuid, salon_id uuid, appointment_id uuid, type public.notification_type,
  fcm_token text, staff boolean)
language plpgsql security definer set search_path = '' as $$
begin
  update public.notification_logs n set status = 'logged', error = 'recipient_unavailable'
  where n.status = 'queued' and not exists (
    select 1 from public.devices d join public.appointments a
      on a.id = n.appointment_id and a.salon_id = n.salon_id
    where d.id = n.device_id and d.salon_id = n.salon_id and d.fcm_token is not null
      and private.salon_active(d.salon_id) and (
        (d.staff_user_id is not null and exists (select 1 from public.users u
          where u.id = d.staff_user_id and u.salon_id = d.salon_id and u.role = 'salon_admin'))
        or (d.staff_user_id is null and d.auth_identity_id = a.auth_identity_id
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
    d.staff_user_id is not null from claimed n join public.devices d
      on d.id = n.device_id and d.salon_id = n.salon_id;
end $$;
revoke all on function public.claim_push_notifications(int) from public, anon, authenticated;
grant execute on function public.claim_push_notifications(int) to service_role;
