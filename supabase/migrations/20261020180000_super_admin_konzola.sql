-- Task 72: platformski RPC-ovi za lokalnu super admin konzolu (ADR-0032).
--
-- Konzola (`apps/superadmin`) je Dart server na mašini developera sa service role ključem.
-- Sve što piše ide kroz ove funkcije, a ne direktno u tabele. Razlog je da validacija bude
-- u bazi, pa ručni poziv pravila ne može zaobići.
--
-- **Nijedna od ovih funkcija nije za aplikaciju.** `execute` ima samo `service_role`. Uloga
-- `super_admin` u JWT-u ih ne otvara: platformska prava ne idu u aplikaciju koju koriste
-- saloni (ADR-0029, ADR-0032). Poznata rupa, van ovog taska: `super_admin` JWT i dalje pravi
-- poziv vlasnika kroz `create_staff_invite` (`private.is_admin` počinje sa `is_super_admin()`)
-- i piše `salon_builds` kroz politiku `super_builds`. V. `security.md` §„Šta još nije zatvoreno".
--
-- Usluge, radnici i radno vrijeme ovdje namjerno ne postoje. Njih vlasnik postavlja u Meluri.

-- ---------------------------------------------------------------------------
-- Poziv platforme: `created_by = null`
-- ---------------------------------------------------------------------------
-- Prvi vlasnik novog salona nema ko da ga pozove iz salona. Poziv pravi konzola, a on nema
-- `auth.users` red. Zato `null` znači „poziv platforme". Poziv salona i dalje nosi
-- `auth.uid()` iz `create_staff_invite`.
alter table public.staff_invites alter column created_by drop not null;

comment on column public.staff_invites.created_by is
  'Ko je napravio poziv. null = platforma (super admin konzola, task 72) — prvi vlasnik salona.';

-- ---------------------------------------------------------------------------
-- Lista salona
-- ---------------------------------------------------------------------------
create function public.platform_list_salons()
returns table (
  id uuid,
  name text,
  slug text,
  city text,
  status public.salon_status,
  plan public.salon_plan,
  vertical_pack_key text,
  theme text,
  primary_color text,
  secondary_color text,
  flavor text,
  application_id text,
  bundle_id text,
  app_display_name text,
  play_store_status public.store_status,
  app_store_status public.store_status,
  admin_count int,
  open_owner_invites int,
  -- Otvoren poziv **platforme** (`created_by is null`), da konzola može ponuditi „Povuci".
  -- Najviše jedan: novi poziv platforme povlači prethodni.
  platform_invite_id uuid,
  platform_invite_expires_at timestamptz,
  created_at timestamptz
)
language sql stable security definer set search_path = '' as $fn$
  select s.id, s.name, s.slug, s.city, s.status, s.plan, s.vertical_pack_key, s.theme,
    s.primary_color, s.secondary_color,
    b.flavor, b.application_id, b.bundle_id, b.app_display_name,
    b.play_store_status, b.app_store_status,
    (select count(*)::int from public.users u
      where u.salon_id = s.id and u.role = 'salon_admin'),
    (select count(*)::int from public.staff_invites i
      where i.salon_id = s.id and i.role = 'salon_admin'
        and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()),
    p.id, p.expires_at,
    s.created_at
  from public.salons s
  left join public.salon_builds b on b.salon_id = s.id
  left join lateral (
    select i.id, i.expires_at from public.staff_invites i
    where i.salon_id = s.id and i.created_by is null
      and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()
    order by i.created_at desc
    limit 1
  ) p on true
  order by s.created_at, s.name;
$fn$;

-- ---------------------------------------------------------------------------
-- Teme i rezervisana imena flavora
-- ---------------------------------------------------------------------------
-- Teme koje `buildAppTheme()` poznaje (`AppTheme` u `core_ui`, ADR-0025, ADR-0026). Ovo je
-- jedina lista u bazi; konzola je čita kroz `platform_list_themes`, a da se slaže sa `core_ui`
-- drži test `apps/superadmin/test/sinhronizacija_test.dart`. Klijent nepoznatu temu ne ruši,
-- nego pada na `modern_barber`. Zato je ovo provjera unosa, a ne `check` na koloni.
create function private.known_themes()
returns text[] language sql immutable set search_path = '' as $fn$
  select array['modern_barber', 'elegant_beauty', 'warm_wellness', 'clinical_calm'];
$fn$;

create function private.is_known_theme(p_theme text)
returns boolean language sql immutable set search_path = '' as $fn$
  select coalesce(p_theme = any(private.known_themes()), false);
$fn$;

create function public.platform_list_themes()
returns setof text language sql stable security definer set search_path = '' as $fn$
  select unnest(private.known_themes());
$fn$;

-- Ime koje `[a-z][a-z0-9]*` pušta, a Android Gradle Plugin odbija: flavor ne smije počinjati sa
-- `test` (prefiks unit test source seta) ni biti `lint`, a `main` je zajednički source set.
-- Ni ime build tipa (`debug`, `profile`, `release`) ne smije biti flavor. Takav flavor ne ruši
-- samo svoj build nego Gradle sync **svih** tenanata. Isto pravilo drži `tool/gen_flavors.dart`.
create function private.is_reserved_flavor(p_flavor text)
returns boolean language sql immutable set search_path = '' as $fn$
  select coalesce(p_flavor like 'test%'
    or p_flavor in ('lint', 'main', 'debug', 'profile', 'release'), false);
$fn$;

-- ---------------------------------------------------------------------------
-- Novi salon: salons + salon_builds + salon_settings u jednoj transakciji
-- ---------------------------------------------------------------------------
-- `p_id` je UUID salona. Prvo okruženje ga ne daje i baza ga izmisli; svako sljedeće
-- (produkcija → lokalni stack, ili lokalni stack poslije `db reset`) ga daje iz
-- `tenant.yaml`-a, pa fajl i sve baze nose isti `salonId`.
create function public.platform_create_salon(
  p_name text,
  p_slug text,
  p_city text,
  p_vertical text,
  p_theme text,
  p_primary_color text,
  p_secondary_color text,
  p_flavor text,
  p_application_id text,
  p_bundle_id text,
  p_display_name text,
  p_plan public.salon_plan default 'starter',
  p_id uuid default null
) returns uuid
language plpgsql security definer set search_path = '' as $fn$
declare
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
  v_city text := nullif(btrim(coalesce(p_city, '')), '');
  v_display text := nullif(btrim(coalesce(p_display_name, '')), '');
  v_pack public.vertical_packs%rowtype;
  v_theme text;
  v_id uuid;
begin
  if v_name is null then
    raise exception 'Naziv salona je obavezan' using errcode = 'PT400';
  end if;
  if v_city is null then
    raise exception 'Grad je obavezan' using errcode = 'PT400';
  end if;
  if v_display is null then
    raise exception 'Ime aplikacije je obavezno' using errcode = 'PT400';
  end if;
  -- Naziv i grad idu u komentar prve linije `tenant.yaml`-a, a ime aplikacije u `displayName`.
  -- Prelom reda bi tu ubacio novi YAML ključ.
  if v_name ~ '[[:cntrl:]]' or v_city ~ '[[:cntrl:]]' or v_display ~ '[[:cntrl:]]' then
    raise exception 'Naziv, grad i ime aplikacije ne smiju imati prelom reda ni kontrolne znakove'
      using errcode = 'PT400';
  end if;
  if p_slug is null or p_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    raise exception 'Slug smije imati mala slova, cifre i crticu između njih' using errcode = 'PT400';
  end if;
  -- Isto pravilo kao `gen_flavors.dart` i `salon_builds.flavor`: Gradle identifikator.
  if p_flavor is null or p_flavor !~ '^[a-z][a-z0-9]*$' then
    raise exception 'Flavor smije imati samo mala slova i cifre, i počinje slovom' using errcode = 'PT400';
  end if;
  if private.is_reserved_flavor(p_flavor) then
    raise exception 'Flavor ne smije počinjati sa „test" niti biti lint, main, debug, profile ili release (Gradle ga odbija za sve tenante)'
      using errcode = 'PT400';
  end if;
  -- UUID šablona (`tenants/_template`) znači da fajl nije popunjen.
  if p_id = '00000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'UUID iz šablona nije UUID salona' using errcode = 'PT400';
  end if;
  if p_application_id is null or p_application_id !~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$' then
    raise exception 'Android ID nije ispravan (npr. ba.nasadomena.salon)' using errcode = 'PT400';
  end if;
  if p_bundle_id is null or p_bundle_id !~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$' then
    raise exception 'iOS bundle ID nije ispravan (npr. ba.nasadomena.salon)' using errcode = 'PT400';
  end if;
  if p_primary_color is null or p_primary_color !~ '^#[0-9A-Fa-f]{6}$'
     or p_secondary_color is null or p_secondary_color !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception 'Boja mora biti #RRGGBB' using errcode = 'PT400';
  end if;

  select * into v_pack from public.vertical_packs v where v.key = p_vertical;
  if not found then
    raise exception 'Nepoznata vertikala' using errcode = 'PT400';
  end if;
  v_theme := coalesce(nullif(btrim(coalesce(p_theme, '')), ''), v_pack.default_theme);
  if not private.is_known_theme(v_theme) then
    raise exception 'Nepoznata tema' using errcode = 'PT400';
  end if;

  -- Zauzeto se javlja po polju, da konzola kaže šta tačno treba promijeniti. Trka dva
  -- prozora konzole i dalje pada na `unique`, ispod.
  if p_id is not null and exists (select 1 from public.salons s where s.id = p_id) then
    raise exception 'Salon sa ovim UUID-om već postoji u ovoj bazi' using errcode = 'PT409';
  end if;
  if exists (select 1 from public.salons s where s.slug = p_slug) then
    raise exception 'Slug je zauzet' using errcode = 'PT409';
  end if;
  if exists (select 1 from public.salon_builds b where b.flavor = p_flavor) then
    raise exception 'Flavor je zauzet' using errcode = 'PT409';
  end if;
  if exists (select 1 from public.salon_builds b
             where b.application_id = p_application_id or b.bundle_id = p_bundle_id) then
    raise exception 'ID aplikacije je zauzet' using errcode = 'PT409';
  end if;

  begin
    insert into public.salons(id, name, slug, city, primary_color, secondary_color, theme,
      vertical_pack_key, plan)
    values (coalesce(p_id, gen_random_uuid()), v_name, p_slug, v_city, upper(p_primary_color),
      upper(p_secondary_color), v_theme, v_pack.key, coalesce(p_plan, 'starter'))
    returning salons.id into v_id;

    insert into public.salon_builds(salon_id, flavor, application_id, bundle_id, app_display_name)
    values (v_id, p_flavor, p_application_id, p_bundle_id, v_display);
  exception when unique_violation then
    raise exception 'UUID, slug, flavor ili ID aplikacije je zauzet' using errcode = 'PT409';
  end;

  -- Početne postavke iz vertikale. Ključ koji pack nema ostaje na defaultu kolone.
  insert into public.salon_settings(salon_id, booking_mode, booking_granularity, buffer_minutes,
    slot_step_minutes, min_advance_booking_hours, max_advance_booking_days, pending_expiry_hours,
    min_cancel_hours, require_staff_choice, show_prices_in_app)
  select v_id,
    coalesce(d->>'bookingMode', 'manual'),
    coalesce(d->>'bookingGranularity', 'exact_slot'),
    coalesce((d->>'bufferMinutes')::int, 5),
    coalesce((d->>'slotStepMinutes')::int, 15),
    coalesce((d->>'minAdvanceBookingHours')::int, 2),
    coalesce((d->>'maxAdvanceBookingDays')::int, 30),
    coalesce((d->>'pendingExpiryHours')::int, 12),
    coalesce((d->>'minCancelHours')::int, 3),
    coalesce((d->>'requireStaffChoice')::boolean, false),
    coalesce((d->>'showPricesInApp')::boolean, true)
  from (select v_pack.default_settings as d) p;

  return v_id;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Status, boje i tema, store
-- ---------------------------------------------------------------------------
create function public.platform_set_salon_status(p_salon_id uuid, p_status public.salon_status)
returns void language plpgsql security definer set search_path = '' as $fn$
begin
  if p_status is null then
    raise exception 'Status je obavezan' using errcode = 'PT400';
  end if;
  update public.salons s set status = p_status where s.id = p_salon_id;
  if not found then
    raise exception 'Salon ne postoji' using errcode = 'PT404';
  end if;
end;
$fn$;

create function public.platform_set_branding(
  p_salon_id uuid,
  p_theme text,
  p_primary_color text,
  p_secondary_color text
) returns void language plpgsql security definer set search_path = '' as $fn$
begin
  if not private.is_known_theme(p_theme) then
    raise exception 'Nepoznata tema' using errcode = 'PT400';
  end if;
  if p_primary_color is null or p_primary_color !~ '^#[0-9A-Fa-f]{6}$'
     or p_secondary_color is null or p_secondary_color !~ '^#[0-9A-Fa-f]{6}$' then
    raise exception 'Boja mora biti #RRGGBB' using errcode = 'PT400';
  end if;
  update public.salons s
  set theme = p_theme, primary_color = upper(p_primary_color),
      secondary_color = upper(p_secondary_color)
  where s.id = p_salon_id;
  if not found then
    raise exception 'Salon ne postoji' using errcode = 'PT404';
  end if;
end;
$fn$;

create function public.platform_set_store_status(
  p_salon_id uuid,
  p_store text,
  p_status public.store_status
) returns void language plpgsql security definer set search_path = '' as $fn$
begin
  if p_store is null or p_store not in ('play', 'app') then
    raise exception 'Store je play ili app' using errcode = 'PT400';
  end if;
  if p_status is null then
    raise exception 'Status je obavezan' using errcode = 'PT400';
  end if;
  update public.salon_builds b set
    play_store_status = case when p_store = 'play' then p_status else b.play_store_status end,
    app_store_status = case when p_store = 'app' then p_status else b.app_store_status end
  where b.salon_id = p_salon_id;
  if not found then
    raise exception 'Salon nema build red' using errcode = 'PT404';
  end if;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Kod poziva: jedno mjesto za oba puta (salon i platforma)
-- ---------------------------------------------------------------------------
-- 10 znakova iz abecede bez 0/O/1/I/L: kod se prepisuje sa telefona. 31^10 ≈ 8e14. Baza čuva
-- samo sha256 koda, a sam kod vraća samo funkcija koja je poziv napravila, jednom.
-- Nije `security definer` i nema `execute` za klijentske uloge: zovu je samo `security definer`
-- funkcije ispod, koje se izvršavaju kao vlasnik.
create function private.new_invite_code()
returns text language plpgsql volatile set search_path = '' as $fn$
declare
  v_abeceda constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bajtovi bytea := extensions.gen_random_bytes(10);
  v_kod text := '';
begin
  for i in 0..9 loop
    v_kod := v_kod || substr(v_abeceda, (get_byte(v_bajtovi, i) % length(v_abeceda)) + 1, 1);
  end loop;
  return v_kod;
end;
$fn$;

-- Isti potpis, ista provjera i isti grantovi kao u `20260924160000_uloga_employee.sql`
-- (`create or replace` čuva grantove). Mijenja se samo to da kod dolazi iz
-- `private.new_invite_code()`, umjesto petlje kopirane u dvije funkcije.
create or replace function public.create_staff_invite(
  p_salon_id uuid,
  p_role public.staff_role,
  p_name text,
  p_employee_id uuid default null
) returns table (invite_id uuid, code text, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $fn$
declare
  v_kod text;
  v_id uuid;
  v_istice timestamptz := now() + interval '7 days';
begin
  if not private.is_admin(p_salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_role is null or p_role not in ('salon_admin', 'employee') then
    raise exception 'Uloga mora biti vlasnik ili radnik' using errcode = 'PT400';
  end if;
  if nullif(btrim(p_name), '') is null then
    raise exception 'Ime je obavezno' using errcode = 'PT400';
  end if;
  if p_employee_id is not null and not exists (
    select 1 from public.employees e where e.salon_id = p_salon_id and e.id = p_employee_id
  ) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_role = 'employee' and p_employee_id is null then
    raise exception 'Izaberite radnika za koga je poziv' using errcode = 'PT400';
  end if;
  if p_employee_id is not null and exists (
    select 1 from public.users u where u.salon_id = p_salon_id and u.employee_id = p_employee_id
  ) then
    raise exception 'Ovaj radnik vec ima nalog' using errcode = 'PT400';
  end if;

  v_kod := private.new_invite_code();

  insert into public.staff_invites(salon_id, role, name, employee_id, code_hash, expires_at, created_by)
  values (p_salon_id, p_role, btrim(p_name), p_employee_id,
    encode(extensions.digest(v_kod, 'sha256'), 'hex'), v_istice, auth.uid())
  returning id into v_id;

  return query select v_id, v_kod, v_istice;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Poziv za vlasnika
-- ---------------------------------------------------------------------------
-- Isti oblik koda kao `create_staff_invite` (`private.new_invite_code`), sha256 u bazi, istek
-- 7 dana. Kod se vraća samo ovdje, jednom. Uloga je uvijek `salon_admin`, jer konzola poziva
-- samo vlasnika, a radnike poziva vlasnik iz Melure.
--
-- Novi poziv platforme **povlači prethodne otvorene pozive platforme** za isti salon. Svaki klik
-- bi inače ostavio još jedan važeći vlasnički kod, a kod koji je developer izgubio ili poslao
-- pogrešnoj osobi ne bi imao kako nestati. Pozive koje je napravio salon (`created_by` nije
-- `null`) ne dira.
create function public.platform_create_owner_invite(p_salon_id uuid, p_name text)
returns table (invite_id uuid, code text, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $fn$
declare
  v_kod text;
  v_id uuid;
  v_istice timestamptz := now() + interval '7 days';
begin
  if nullif(btrim(coalesce(p_name, '')), '') is null then
    raise exception 'Ime vlasnika je obavezno' using errcode = 'PT400';
  end if;
  if p_name ~ '[[:cntrl:]]' then
    raise exception 'Ime vlasnika ne smije imati prelom reda ni kontrolne znakove' using errcode = 'PT400';
  end if;
  if not exists (select 1 from public.salons s where s.id = p_salon_id) then
    raise exception 'Salon ne postoji' using errcode = 'PT404';
  end if;
  -- `peek_staff_invite` ne prima poziv neaktivnog salona. Kod koji se ne može iskoristiti
  -- ne pravimo.
  if not private.salon_active(p_salon_id) then
    raise exception 'Salon nije aktivan' using errcode = 'PT409';
  end if;

  update public.staff_invites i set revoked_at = now()
  where i.salon_id = p_salon_id and i.created_by is null
    and i.accepted_at is null and i.revoked_at is null and i.expires_at > now();

  v_kod := private.new_invite_code();

  insert into public.staff_invites(salon_id, role, name, code_hash, expires_at, created_by)
  values (p_salon_id, 'salon_admin', btrim(p_name),
    encode(extensions.digest(v_kod, 'sha256'), 'hex'), v_istice, null)
  returning id into v_id;

  return query select v_id, v_kod, v_istice;
end;
$fn$;

-- Povlačenje poziva platforme. Isti oblik kao `revoke_staff_invite`, ali samo za poziv sa
-- `created_by = null`: poziv koji je napravio salon povlači salon.
create function public.platform_revoke_owner_invite(p_salon_id uuid, p_invite_id uuid)
returns void language plpgsql security definer set search_path = '' as $fn$
begin
  update public.staff_invites i set revoked_at = now()
  where i.salon_id = p_salon_id and i.id = p_invite_id and i.created_by is null
    and i.accepted_at is null and i.revoked_at is null;
  if not found then
    -- Tuđi, nepostojeći, salonski, već prihvaćen i već povučen poziv daju istu grešku.
    raise exception 'Poziv ne postoji ili je već iskorišten' using errcode = 'PT404';
  end if;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Grad iz Melure: ista zabrana kontrolnih znakova
-- ---------------------------------------------------------------------------
-- Grad mijenja i vlasnik (`update_salon_contact`), a konzola ga piše u `tenant.yaml` kad fajl
-- piše ponovo iz reda u bazi. Ostatak funkcije je isti kao u
-- `20260923100000_zakljucaj_naziv_salona.sql`; `create or replace` čuva grantove.
create or replace function public.update_salon_contact(
  p_salon_id uuid,
  p_name text,
  p_address text,
  p_city text,
  p_description text default '',
  p_phone text default null,
  p_email text default null,
  p_instagram_url text default null,
  p_facebook_url text default null
) returns public.salons language plpgsql security definer set search_path = '' as $fn$
declare
  v_name text;
  v_row public.salons%rowtype;
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  select s.name into v_name
  from public.salons s
  where s.id = p_salon_id
  for update;

  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  if p_name is distinct from v_name then
    raise exception 'Naziv aplikacije mijenja se kroz novi store build'
      using errcode = 'PT400';
  end if;
  if length(btrim(coalesce(p_city, ''))) = 0 then
    raise exception 'Grad je obavezan' using errcode = 'PT400';
  end if;
  if btrim(p_city) ~ '[[:cntrl:]]' then
    raise exception 'Grad ne smije imati prelom reda ni kontrolne znakove' using errcode = 'PT400';
  end if;

  update public.salons s set
    address = btrim(coalesce(p_address, '')),
    city = btrim(p_city),
    description = btrim(coalesce(p_description, '')),
    phone = nullif(btrim(coalesce(p_phone, '')), ''),
    email = nullif(btrim(coalesce(p_email, '')), ''),
    instagram_url = nullif(btrim(coalesce(p_instagram_url, '')), ''),
    facebook_url = nullif(btrim(coalesce(p_facebook_url, '')), '')
  where s.id = p_salon_id
  returning * into v_row;

  return v_row;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Grantovi: samo service_role
-- ---------------------------------------------------------------------------
-- Supabase daje `execute` na svaku novu funkciju u `public` i `anon` i `authenticated`
-- (default privileges). Zato se oduzima eksplicitno svima, pa vraća samo service_role.
-- pgTAP `034` broji sve `public.platform_%` funkcije u katalogu, pa nova funkcija bez ovog
-- para obara test.
revoke all on function public.platform_list_salons() from public, anon, authenticated;
revoke all on function public.platform_list_themes() from public, anon, authenticated;
revoke all on function public.platform_create_salon(text, text, text, text, text, text, text, text, text, text, text, public.salon_plan, uuid) from public, anon, authenticated;
revoke all on function public.platform_set_salon_status(uuid, public.salon_status) from public, anon, authenticated;
revoke all on function public.platform_set_branding(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.platform_set_store_status(uuid, text, public.store_status) from public, anon, authenticated;
revoke all on function public.platform_create_owner_invite(uuid, text) from public, anon, authenticated;
revoke all on function public.platform_revoke_owner_invite(uuid, uuid) from public, anon, authenticated;
revoke all on function private.known_themes() from public, anon, authenticated;
revoke all on function private.is_known_theme(text) from public, anon, authenticated;
revoke all on function private.is_reserved_flavor(text) from public, anon, authenticated;
revoke all on function private.new_invite_code() from public, anon, authenticated;

grant execute on function public.platform_list_salons() to service_role;
grant execute on function public.platform_list_themes() to service_role;
grant execute on function public.platform_create_salon(text, text, text, text, text, text, text, text, text, text, text, public.salon_plan, uuid) to service_role;
grant execute on function public.platform_set_salon_status(uuid, public.salon_status) to service_role;
grant execute on function public.platform_set_branding(uuid, text, text, text) to service_role;
grant execute on function public.platform_set_store_status(uuid, text, public.store_status) to service_role;
grant execute on function public.platform_create_owner_invite(uuid, text) to service_role;
grant execute on function public.platform_revoke_owner_invite(uuid, uuid) to service_role;
