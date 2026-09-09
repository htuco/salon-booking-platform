-- MVP data model. Migrations are the source of truth; never edit deployed migrations.
create schema if not exists private;
revoke all on schema private from public;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists btree_gist with schema extensions;
create extension if not exists pgtap with schema extensions;

create type public.salon_status as enum ('active','inactive');
create type public.salon_plan as enum ('starter','pro','premium');
create type public.staff_role as enum ('super_admin','salon_admin','employee');
create type public.store_status as enum ('draft','in_review','live');
create type public.appointment_status as enum ('pending','confirmed','cancelled','completed','no_show');
create type public.appointment_source as enum ('app','web','manual','guest');
create type public.cancelled_by as enum ('customer','salon','system');
create type public.device_platform as enum ('android','ios','web');
create type public.notification_type as enum ('confirmed','rejected','reminder_d1','reminder_h3','new_request','cancelled');
create type public.notification_status as enum ('queued','sending','sent','failed','logged');

create table public.vertical_packs (
 id uuid primary key default gen_random_uuid(),
 key text not null unique check (key in ('barber','beauty','dental','health','generic')),
 display_name text not null, terminology jsonb not null default '{}',
 default_settings jsonb not null default '{}', default_theme text not null,
 default_services jsonb not null default '[]', feature_flags jsonb not null default '{}',
 required_consents jsonb not null default '[]'
);
create table public.salons (
 id uuid primary key default gen_random_uuid(), name text not null, slug text not null unique
 check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'), description text not null default '',
 logo_url text, cover_image_url text, gallery_urls jsonb not null default '[]',
 primary_color text not null default '#C6A667' check(primary_color ~ '^#[0-9A-Fa-f]{6}$'),
 secondary_color text not null default '#171717' check(secondary_color ~ '^#[0-9A-Fa-f]{6}$'),
 theme text not null default 'modern_barber', address text not null default '', city text not null,
 phone text, email text, instagram_url text, facebook_url text,
 status public.salon_status not null default 'active', plan public.salon_plan not null default 'starter',
 vertical_pack_key text not null references public.vertical_packs(key),
 terminology_override jsonb, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.salon_builds (
 id uuid primary key default gen_random_uuid(), salon_id uuid not null unique references public.salons(id),
 flavor text not null unique check(flavor ~ '^[a-z][a-z0-9]*$'),
 application_id text not null unique, bundle_id text not null unique, app_display_name text not null,
 app_icon_url text, android_version_code int not null default 1 check(android_version_code > 0),
 ios_build_number int not null default 1 check(ios_build_number > 0),
 play_store_status public.store_status not null default 'draft',
 app_store_status public.store_status not null default 'draft',
 play_store_url text, app_store_url text, last_built_at timestamptz,
 build_status text not null default 'idle' check(build_status in ('idle','queued','building','succeeded','failed')),
 build_url text, unique(salon_id,id)
);
-- Credentials live exclusively in auth.users. Do not duplicate password hashes.
create table public.users (
 id uuid primary key references auth.users(id) on delete cascade,
 salon_id uuid references public.salons(id), name text not null, email text not null,
 role public.staff_role not null, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check ((role = 'super_admin' and salon_id is null) or (role <> 'super_admin' and salon_id is not null)),
 unique(salon_id,id)
);
create table public.services (
 id uuid primary key default gen_random_uuid(), salon_id uuid not null references public.salons(id),
 name text not null, description text not null default '', category text not null default '',
 price numeric(10,2) not null check(price >= 0), duration_minutes int not null check(duration_minutes > 0 and duration_minutes <= 1440),
 is_active bool not null default true, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), unique(salon_id,id)
);
create table public.employees (
 id uuid primary key default gen_random_uuid(), salon_id uuid not null references public.salons(id),
 name text not null, role text not null default '', bio text not null default '', image_url text,
 is_active bool not null default true, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), unique(salon_id,id)
);
create table public.employee_services (
 id uuid primary key default gen_random_uuid(), salon_id uuid not null references public.salons(id),
 employee_id uuid not null, service_id uuid not null,
 foreign key(salon_id,employee_id) references public.employees(salon_id,id) on delete cascade,
 foreign key(salon_id,service_id) references public.services(salon_id,id) on delete cascade,
 unique(salon_id,employee_id,service_id)
);
create table public.working_hours (
 id uuid primary key default gen_random_uuid(), salon_id uuid not null references public.salons(id),
 employee_id uuid, day_of_week int not null check(day_of_week between 1 and 7),
 start_time time not null default '09:00', end_time time not null default '17:00',
 break_start_time time, break_end_time time, is_closed bool not null default false,
 foreign key(salon_id,employee_id) references public.employees(salon_id,id),
 check(is_closed or end_time > start_time),
 check((break_start_time is null and break_end_time is null) or
 (break_start_time is not null and break_end_time is not null and
 break_start_time >= start_time and break_end_time <= end_time and break_end_time > break_start_time)),
 unique nulls not distinct(salon_id,employee_id,day_of_week)
);
create table public.auth_identities (
 id uuid primary key default gen_random_uuid(),
 supabase_user_id uuid unique references auth.users(id) on delete set null,
 providers text[] not null default '{}', email text, email_verified bool not null default false,
 display_name text, is_anonymous bool not null default false, deleted_at timestamptz,
 created_at timestamptz not null default now(), last_login_at timestamptz not null default now()
);
create table public.customers (
 id uuid primary key default gen_random_uuid(), salon_id uuid not null references public.salons(id),
 auth_identity_id uuid references public.auth_identities(id), name text not null, phone text, note text,
 visit_count int not null default 0 check(visit_count >= 0), no_show_count int not null default 0 check(no_show_count >= 0),
 is_vip bool not null default false, first_seen_at timestamptz not null default now(), last_visit_at timestamptz,
 unique(salon_id,id), unique(salon_id,auth_identity_id), unique(salon_id,phone),
 unique(salon_id,id,auth_identity_id)
);
create table public.devices (
 id uuid primary key default gen_random_uuid(), salon_id uuid not null references public.salons(id),
 device_id text not null, fcm_token text, platform public.device_platform not null,
 auth_identity_id uuid references public.auth_identities(id), staff_user_id uuid,
 app_version text not null default '0.1.0', last_seen_at timestamptz not null default now(),
 foreign key(salon_id,staff_user_id) references public.users(salon_id,id) on delete cascade,
 unique(salon_id,device_id), unique(salon_id,id)
);
create table public.appointments (
 id uuid primary key default gen_random_uuid(), salon_id uuid not null references public.salons(id),
 service_id uuid not null, employee_id uuid, customer_id uuid not null, auth_identity_id uuid,
 device_id uuid, customer_name text not null, customer_phone text, customer_note text,
 date date not null, start_time time not null, end_time time not null,
 buffer_minutes int not null default 0 check(buffer_minutes >= 0 and buffer_minutes <= 120),
 status public.appointment_status not null default 'pending',
 source public.appointment_source not null default 'app', cancel_reason text, cancelled_by public.cancelled_by,
 pending_expires_at timestamptz, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 foreign key(salon_id,service_id) references public.services(salon_id,id),
 foreign key(salon_id,employee_id) references public.employees(salon_id,id),
 foreign key(salon_id,customer_id) references public.customers(salon_id,id),
 foreign key(salon_id,customer_id,auth_identity_id) references public.customers(salon_id,id,auth_identity_id),
 foreign key(salon_id,device_id) references public.devices(salon_id,id),
 check(end_time > start_time), unique(salon_id,id)
);
create table public.blocked_slots (
 id uuid primary key default gen_random_uuid(), salon_id uuid not null references public.salons(id),
 employee_id uuid, date date not null, start_time time not null, end_time time not null, reason text,
 created_at timestamptz not null default now(),
 foreign key(salon_id,employee_id) references public.employees(salon_id,id),
 check(end_time > start_time), unique(salon_id,id)
);
create table public.notification_logs (
 id uuid primary key default gen_random_uuid(), salon_id uuid not null references public.salons(id),
 appointment_id uuid not null, device_id uuid not null, type public.notification_type not null,
 sent_at timestamptz, status public.notification_status not null default 'queued',
 attempts int not null default 0, error text, claimed_at timestamptz,
 created_at timestamptz not null default now(),
 foreign key(salon_id,appointment_id) references public.appointments(salon_id,id),
 foreign key(salon_id,device_id) references public.devices(salon_id,id),
 unique(appointment_id,device_id,type)
);
create table public.salon_settings (
 id uuid primary key default gen_random_uuid(), salon_id uuid not null unique references public.salons(id),
 booking_mode text not null default 'manual' check(booking_mode in ('manual','auto')),
 booking_granularity text not null default 'exact_slot' check(booking_granularity in ('exact_slot','date_only')),
 buffer_minutes int not null default 5 check(buffer_minutes between 0 and 120),
 slot_step_minutes int not null default 15 check(slot_step_minutes between 1 and 120),
 min_advance_booking_hours int not null default 2 check(min_advance_booking_hours >= 0),
 max_advance_booking_days int not null default 30 check(max_advance_booking_days > 0),
 pending_expiry_hours int not null default 12 check(pending_expiry_hours > 0),
 min_cancel_hours int not null default 3 check(min_cancel_hours >= 0),
 require_staff_choice bool not null default false, show_prices_in_app bool not null default true,
 allow_guest_booking bool not null default false,
 auth_providers jsonb not null default '{"apple":true,"google":true,"email":true,"facebook":false}',
 reminders_enabled bool not null default true, notify_on_cancellation bool not null default true,
 timezone text not null default 'Europe/Sarajevo', language text not null default 'bs',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create index appointments_employee_date_idx on public.appointments(salon_id,employee_id,date,status);
create index appointments_customer_idx on public.appointments(salon_id,customer_id,date);
create index appointments_pending_expiry_idx on public.appointments(pending_expires_at) where status = 'pending';
create index customers_identity_idx on public.customers(auth_identity_id,salon_id);
create index devices_identity_idx on public.devices(auth_identity_id,salon_id);
create index blocked_slots_date_idx on public.blocked_slots(salon_id,date);
create index notification_logs_status_idx on public.notification_logs(status,created_at);

create function private.touch_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end $$;
do $$ declare t text; begin
 foreach t in array array['salons','users','services','employees','appointments','salon_settings'] loop
 execute format('create trigger touch_updated_at before update on public.%I for each row execute function private.touch_updated_at()',t);
 end loop;
end $$;
create function private.salon_active(p_salon uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.salons where id=p_salon and status='active') $$;
create function private.is_super_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select coalesce(auth.jwt()->'app_metadata'->>'role' = 'super_admin',false)
and exists(select 1 from public.users where id=auth.uid() and role='super_admin') $$;
create function private.is_admin(p_salon uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select private.is_super_admin() or (
coalesce(auth.jwt()->'app_metadata'->>'role' = 'salon_admin',false)
and auth.jwt()->'app_metadata'->>'salon_id' = p_salon::text
and exists(select 1 from public.users where id=auth.uid() and role='salon_admin' and salon_id=p_salon)) $$;
-- Header scopes the owner's reads, never grants membership or staff permissions.
-- Malformed/missing headers deliberately return NULL: no accidental global scope.
create function private.client_salon_id() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare requested uuid;
begin
 requested := nullif(current_setting('request.headers',true),'')::jsonb->>'x-salon-id';
 if private.salon_active(requested) then return requested; end if;
 return null;
exception when invalid_text_representation then return null;
end $$;
create function private.owns_identity(p_identity uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.auth_identities
where id=p_identity and supabase_user_id=auth.uid() and deleted_at is null) $$;
create function private.is_client() returns boolean
language sql stable set search_path = ''
as $$ select coalesce(auth.jwt()->'app_metadata'->>'role','client') not in ('super_admin','salon_admin','employee') $$;

do $$ declare t text; begin
 foreach t in array array['vertical_packs','salons','salon_builds','users','services','employees','employee_services','working_hours','auth_identities','customers','devices','appointments','blocked_slots','notification_logs','salon_settings'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 execute format('grant all on public.%I to service_role',t);
 end loop;
end $$;
grant usage on schema private to anon, authenticated, service_role;
revoke all on all functions in schema private from public;
grant execute on function private.salon_active(uuid), private.is_super_admin(), private.is_admin(uuid),
 private.client_salon_id(), private.owns_identity(uuid), private.is_client() to anon, authenticated, service_role;

grant select on public.vertical_packs,public.salons,public.services,public.employees,
 public.employee_services,public.working_hours,public.salon_settings to anon,authenticated;
grant insert,update,delete on public.vertical_packs,public.salons,public.services,public.employees,
 public.employee_services,public.working_hours,public.salon_settings to authenticated;
grant select,insert,update,delete on public.salon_builds,public.users,public.customers,
 public.appointments,public.blocked_slots to authenticated;
grant select on public.auth_identities,public.devices,public.notification_logs to authenticated;

create policy public_verticals on public.vertical_packs for select to anon,authenticated using(true);
create policy super_verticals on public.vertical_packs for all to authenticated using(private.is_super_admin()) with check(private.is_super_admin());
create policy public_salons on public.salons for select to anon,authenticated using(status='active');
create policy staff_salons on public.salons for select to authenticated using(private.is_admin(id));
-- Salon activation, plan, branding and identifiers are platform-managed.
create policy super_salons on public.salons for all to authenticated using(private.is_super_admin()) with check(private.is_super_admin());
create policy staff_builds on public.salon_builds for select to authenticated using(private.is_admin(salon_id));
create policy super_builds on public.salon_builds for all to authenticated using(private.is_super_admin()) with check(private.is_super_admin());
create policy own_staff_profile on public.users for select to authenticated using(id=auth.uid());
create policy super_users on public.users for all to authenticated using(private.is_super_admin()) with check(private.is_super_admin());

do $$ declare t text; begin
 foreach t in array array['services','employees'] loop
 execute format('create policy public_active on public.%I for select to anon,authenticated using(is_active and private.salon_active(salon_id))',t);
 execute format('create policy staff_manage on public.%I for all to authenticated using(private.is_admin(salon_id)) with check(private.is_admin(salon_id))',t);
 end loop;
 foreach t in array array['employee_services','working_hours','salon_settings'] loop
 execute format('create policy public_active on public.%I for select to anon,authenticated using(private.salon_active(salon_id))',t);
 execute format('create policy staff_manage on public.%I for all to authenticated using(private.is_admin(salon_id)) with check(private.is_admin(salon_id))',t);
 end loop;
 foreach t in array array['customers','appointments','blocked_slots'] loop
 execute format('create policy staff_manage on public.%I for all to authenticated using(private.is_admin(salon_id)) with check(private.is_admin(salon_id))',t);
 end loop;
end $$;

create policy own_identity on public.auth_identities for select to authenticated
 using(private.is_client() and supabase_user_id=auth.uid() and deleted_at is null);
create policy own_customer on public.customers for select to authenticated
 using(private.is_client() and salon_id=private.client_salon_id() and private.owns_identity(auth_identity_id));
create policy own_appointments on public.appointments for select to authenticated
 using(private.is_client() and salon_id=private.client_salon_id() and private.owns_identity(auth_identity_id));
create policy own_devices on public.devices for select to authenticated
 using(salon_id=private.client_salon_id() and private.owns_identity(auth_identity_id));
create policy own_staff_devices on public.devices for select to authenticated
 using(staff_user_id=auth.uid() and private.is_admin(salon_id));
create policy staff_notification_logs on public.notification_logs for select to authenticated
 using(private.is_admin(salon_id));
-- Device writes and customer app writes go only through validated RPC/Edge functions.
-- Realtime follows SELECT RLS; replica default avoids broadcasting identity data.
alter publication supabase_realtime add table public.appointments;
