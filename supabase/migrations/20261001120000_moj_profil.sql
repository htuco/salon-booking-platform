-- Moj profil (task 61): podaci i slika **osobe**, ne salona.
--
-- Nalog osoblja pripada jednom salonu (`public.users.salon_id`), pa je „članstvo" iz handoffa
-- (`design_handoff_admin_profil`) ovdje sam `users` red. Više salona po nalogu nije dio ovog
-- taska — v. `tasks/sprint-5/61-moj-profil.md`.
--
-- Klijent i dalje čita **samo** `employees.image_url`. Profilna slika do njega stiže tako što
-- je `set_use_profile_photo` upiše u povezanog radnika, a staru salonsku sačuva u
-- `salon_photo_url` da se može vratiti. Prikazna slika je time materijalizovana na jednom
-- mjestu, a ne izračunata u dvije aplikacije.
--
-- Sve se piše kroz RPC: `authenticated` nad `users` ima grant, ali nema `update` politiku, i
-- ovdje je ne dobija — direktan update bi pustio i `role`, `salon_id` i `employee_id`.

alter table public.users
  add column phone text not null default ''
    constraint users_phone_length check (char_length(phone) <= 30),
  add column photo_url text,
  add column use_profile_photo boolean not null default false,
  add column salon_photo_url text,
  add column password_changed_at timestamptz;

-- ---------------------------------------------------------------------------
-- Helperi
-- ---------------------------------------------------------------------------

-- Osoblje salona: vlasnik ili aktivan radnik, uz oba uslova (claim i red) iz postojećih helpera.
create function private.is_staff(p_salon uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(private.is_admin(p_salon), false) or coalesce(private.is_employee(p_salon), false)
$$;

-- Javni prefiks bucketa **ovog** projekta, iz `iss` claima: `https://<ref>.supabase.co/auth/v1`
-- na hostovanom, `http://127.0.0.1:54321/auth/v1` lokalno. Claim potpisuje projekat, pa ga
-- pozivalac ne bira. Bez ovoga bi host bio slobodan (`[^/?#]+`, kao u `is_salon_media_url`),
-- i radnik bi kao profilnu upisao URL sa svog servera — klijentska app bi ga učitavala
-- (nalaz `rls-auditor`). Cijena: custom domena ili emulator (`10.0.2.2`) ne prolaze.
create function private.storage_public_prefix() returns text
language sql stable set search_path = '' as $$
  select nullif(regexp_replace(coalesce(auth.jwt()->>'iss', ''), '/auth/v1/?$', ''), '')
    || '/storage/v1/object/public/salon-media/'
$$;

-- Ime objekta profilne slike: `<moj salon>/profil/<moj uid>-<ime>`, salon malim slovima kako ga
-- sweep i čita. Bez uid prefiksa bi radnik kao svoju upisao sliku kolege iz istog foldera.
create function private.profile_media_name_pattern(p_salon uuid, p_user uuid)
returns text language sql immutable set search_path = '' as $$
  select '^' || p_salon::text || '/profil/' || p_user::text || '-[A-Za-z0-9_-][A-Za-z0-9._-]*$'
$$;

create function private.is_profile_media_url(p_salon uuid, p_user uuid, p_url text)
returns boolean language sql stable set search_path = '' as $$
  select p_salon is not null and p_user is not null
    and private.storage_public_prefix() is not null
    and left(coalesce(p_url, ''), char_length(private.storage_public_prefix()))
        = private.storage_public_prefix()
    and substr(p_url, char_length(private.storage_public_prefix()) + 1)
        ~ private.profile_media_name_pattern(p_salon, p_user)
$$;

-- Ista provjera nad imenom u bucketu, za politiku upisa. Jedan regex nad cijelim imenom: velika
-- slova u UUID-u ili završna kosa crta bi prošle `storage_salon_id`, a sweep ih nikad ne vrati.
create function private.is_own_profile_media(p_name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null
    and private.is_staff(private.storage_salon_id(p_name))
    and p_name ~ private.profile_media_name_pattern(private.storage_salon_id(p_name), auth.uid())
$$;

revoke all on function private.storage_public_prefix() from public, anon;
revoke all on function private.profile_media_name_pattern(uuid, uuid) from public, anon;
revoke all on function private.is_staff(uuid) from public, anon;
revoke all on function private.is_profile_media_url(uuid, uuid, text) from public, anon;
revoke all on function private.is_own_profile_media(text) from public, anon;
grant execute on function private.is_staff(uuid), private.is_profile_media_url(uuid, uuid, text),
  private.is_own_profile_media(text), private.storage_public_prefix(),
  private.profile_media_name_pattern(uuid, uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Storage: radnik smije poslati **svoju** profilnu sliku
-- ---------------------------------------------------------------------------
-- Vlasnik to već može kroz `salon_media_admin_insert`. Radnik do sada nije pisao ništa u bucket;
-- ovo mu otvara samo `<salon>/profil/<moj uid>-<ime>`. Bez select/update/delete: svaki upload
-- dobija novo ime (`MediaRepository`), a staru sliku čisti sweep iz taska 51.
create policy salon_media_profile_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'salon-media' and private.is_own_profile_media(name));

-- ---------------------------------------------------------------------------
-- RPC
-- ---------------------------------------------------------------------------

create function public.update_my_profile(p_name text, p_phone text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_user public.users%rowtype;
  v_name text := btrim(coalesce(p_name, ''));
  v_phone text := btrim(coalesce(p_phone, ''));
begin
  select * into v_user from public.users where id = auth.uid() for update;
  if not found or not private.is_staff(v_user.salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if char_length(v_name) not between 1 and 120 then
    raise exception 'Ime mora imati između 1 i 120 znakova' using errcode = 'PT400';
  end if;
  if char_length(v_phone) > 30 or v_phone !~ '^[0-9+ ()/.-]*$' then
    raise exception 'Telefon smije imati najviše 30 znakova: cifre, razmak i + ( ) / . -'
      using errcode = 'PT400';
  end if;
  update public.users set name = v_name, phone = v_phone, updated_at = now()
  where id = v_user.id;
end $$;

-- Vraća salonsku sliku radniku i gasi prekidač. Zovu je i isključivanje, i uklanjanje slike, i
-- promjena veze — u sva tri slučaja salon mora dobiti nazad ono što je imao.
create function private.restore_salon_photo(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_user public.users%rowtype;
begin
  select * into v_user from public.users where id = p_user for update;
  if not found or not v_user.use_profile_photo then return; end if;
  -- Salonska slika obrisana u međuvremenu (vlasnik kroz Storage) se ne vraća: trigger iz
  -- taska 51 bi odbio upis i korisnik ne bi mogao skloniti svoju ličnu sliku.
  if v_user.employee_id is not null then
    update public.employees
    set image_url = case when private.salon_media_exists(v_user.salon_photo_url)
                         then v_user.salon_photo_url end
    where salon_id = v_user.salon_id and id = v_user.employee_id;
  end if;
  update public.users set use_profile_photo = false, salon_photo_url = null, updated_at = now()
  where id = p_user;
end $$;
revoke all on function private.restore_salon_photo(uuid) from public, anon, authenticated;

-- Uklonjen radnik (`remove_staff_user`) ili obrisan nalog (cascade iz `auth.users`) ne smije
-- ostaviti svoju ličnu sliku u javnom katalogu, a salonska ne smije postati siroče.
-- Radi nad `old`, ne kroz `restore_salon_photo`: update reda koji se upravo briše Postgres
-- odbija ("tuple to be deleted was already modified").
create function private.restore_salon_photo_on_delete() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.use_profile_photo and old.employee_id is not null then
    update public.employees
    set image_url = case when private.salon_media_exists(old.salon_photo_url)
                         then old.salon_photo_url end
    where salon_id = old.salon_id and id = old.employee_id;
  end if;
  return old;
end $$;
revoke all on function private.restore_salon_photo_on_delete() from public, anon, authenticated;

create trigger restore_salon_photo_on_delete
  before delete on public.users
  for each row execute function private.restore_salon_photo_on_delete();

create function public.set_my_photo(p_url text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_user public.users%rowtype;
  v_url text := nullif(btrim(coalesce(p_url, '')), '');
begin
  select * into v_user from public.users where id = auth.uid() for update;
  if not found or not private.is_staff(v_user.salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if v_url is not null and not private.is_profile_media_url(v_user.salon_id, v_user.id, v_url) then
    raise exception 'Slika mora biti vaša profilna slika iz ovog salona' using errcode = 'PT400';
  end if;

  if v_url is null then
    -- Bez profilne slike nema šta da salon koristi: vraća mu se njegova.
    perform private.restore_salon_photo(v_user.id);
  elsif v_user.use_profile_photo and v_user.employee_id is not null then
    update public.employees set image_url = v_url
    where salon_id = v_user.salon_id and id = v_user.employee_id;
  end if;
  update public.users set photo_url = v_url, updated_at = now() where id = v_user.id;
end $$;

create function public.set_use_profile_photo(p_use boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_user public.users%rowtype;
  v_salon_photo text;
begin
  select * into v_user from public.users where id = auth.uid() for update;
  if not found or not private.is_staff(v_user.salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if v_user.employee_id is null then
    raise exception 'Nalog nije povezan sa radnikom u Osoblju' using errcode = 'PT400';
  end if;
  if coalesce(p_use, false) = v_user.use_profile_photo then return; end if;

  if p_use then
    if v_user.photo_url is null then
      raise exception 'Prvo postavite profilnu sliku' using errcode = 'PT400';
    end if;
    select image_url into v_salon_photo from public.employees
    where salon_id = v_user.salon_id and id = v_user.employee_id for update;
    update public.employees set image_url = v_user.photo_url
    where salon_id = v_user.salon_id and id = v_user.employee_id;
    update public.users set use_profile_photo = true, salon_photo_url = v_salon_photo,
      updated_at = now()
    where id = v_user.id;
  else
    perform private.restore_salon_photo(v_user.id);
  end if;
end $$;

-- Vlasnik koji i sam radi (Amko) bira kojem radniku iz Osoblja odgovara njegov nalog. Radnik
-- vezu dobija iz poziva i ovdje je ne mijenja: `is_employee` se na nju oslanja.
create function public.link_my_employee(p_employee_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_user public.users%rowtype;
begin
  select * into v_user from public.users where id = auth.uid() for update;
  if not found or v_user.role <> 'salon_admin'
     or not coalesce(private.is_admin(v_user.salon_id), false) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if v_user.employee_id is not distinct from p_employee_id then return; end if;
  if p_employee_id is not null and not exists (
    select 1 from public.employees where salon_id = v_user.salon_id and id = p_employee_id
  ) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  perform private.restore_salon_photo(v_user.id);
  begin
    update public.users set employee_id = p_employee_id, updated_at = now() where id = v_user.id;
  exception when unique_violation then
    raise exception 'Taj radnik je već povezan sa drugim nalogom' using errcode = 'PT409';
  end;
end $$;

-- Samo prikaz („Promijenjena prije 3 mjeseca"). Lozinku mijenja GoTrue; ovo pozivalac javlja
-- sam, pa vrijednost nije dokaz ničega i ne koristi se ni u jednoj odluci.
create function public.mark_password_changed() returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.users set password_changed_at = now(), updated_at = now()
  where id = auth.uid() and private.is_staff(salon_id);
  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
end $$;

revoke all on function public.update_my_profile(text, text) from public, anon;
revoke all on function public.set_my_photo(text) from public, anon;
revoke all on function public.set_use_profile_photo(boolean) from public, anon;
revoke all on function public.link_my_employee(uuid) from public, anon;
revoke all on function public.mark_password_changed() from public, anon;
grant execute on function public.update_my_profile(text, text), public.set_my_photo(text),
  public.set_use_profile_photo(boolean), public.link_my_employee(uuid),
  public.mark_password_changed() to authenticated;

-- ---------------------------------------------------------------------------
-- Task 51: nova slikovna kolona mora u sweep i u trigger
-- ---------------------------------------------------------------------------
-- Inače sweep briše profilnu sliku dan nakon uploada, a `salon_photo_url` — sliku koju salon
-- treba dobiti nazad — čim prekidač stoji uključen duže od 24 sata.
create or replace function public.media_orphans(
  p_min_age interval default interval '24 hours',
  p_limit integer default 500
) returns table (salon_id uuid, name text)
language sql
stable
security definer
set search_path = ''
as $$
  with reference as (
    select private.salon_media_path(s.logo_url) as putanja from public.salons s
    union
    select private.salon_media_path(s.cover_image_url) from public.salons s
    union
    select private.salon_media_path(g.url)
    from public.salons s
    cross join lateral jsonb_array_elements_text(
      case when jsonb_typeof(s.gallery_urls) = 'array' then s.gallery_urls else '[]'::jsonb end
    ) as g(url)
    union
    select private.salon_media_path(sv.image_url) from public.services sv
    union
    select private.salon_media_path(e.image_url) from public.employees e
    union
    select private.salon_media_path(u.photo_url) from public.users u
    union
    select private.salon_media_path(u.salon_photo_url) from public.users u
  )
  select private.storage_salon_id(o.name), o.name
  from storage.objects o
  where o.bucket_id = 'salon-media'
    and private.storage_salon_id(o.name) is not null
    and split_part(o.name, '/', 1) = private.storage_salon_id(o.name)::text
    and o.name !~ '(^|/)\.{0,2}(/|$)'
    and o.created_at < now() - coalesce(p_min_age, interval '24 hours')
    and not exists (select 1 from reference r where r.putanja = o.name)
  order by o.created_at, o.name
  limit least(greatest(coalesce(p_limit, 0), 0), 1000)
$$;

create or replace function private.guard_salon_media_reference()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_url text;
begin
  if tg_table_name in ('services', 'employees') then
    if (tg_op = 'INSERT' or new.image_url is distinct from old.image_url)
       and not private.salon_media_exists(new.image_url) then
      raise exception 'Slika više ne postoji — izaberite je ponovo' using errcode = 'PT400';
    end if;
  elsif tg_table_name = 'users' then
    if (tg_op = 'INSERT' or new.photo_url is distinct from old.photo_url)
       and not private.salon_media_exists(new.photo_url) then
      raise exception 'Slika više ne postoji — izaberite je ponovo' using errcode = 'PT400';
    end if;
  elsif tg_table_name = 'salons' then
    if (tg_op = 'INSERT' or new.logo_url is distinct from old.logo_url)
       and not private.salon_media_exists(new.logo_url) then
      raise exception 'Slika više ne postoji — izaberite je ponovo' using errcode = 'PT400';
    end if;
    if (tg_op = 'INSERT' or new.cover_image_url is distinct from old.cover_image_url)
       and not private.salon_media_exists(new.cover_image_url) then
      raise exception 'Slika više ne postoji — izaberite je ponovo' using errcode = 'PT400';
    end if;
    if jsonb_typeof(new.gallery_urls) = 'array' then
      for v_url in select jsonb_array_elements_text(new.gallery_urls) loop
        if (tg_op = 'INSERT' or not coalesce(old.gallery_urls @> jsonb_build_array(v_url), false))
           and not private.salon_media_exists(v_url) then
          raise exception 'Slika više ne postoji — izaberite je ponovo' using errcode = 'PT400';
        end if;
      end loop;
    end if;
  end if;
  return new;
end $$;

create trigger guard_salon_media_reference
  before insert or update of photo_url on public.users
  for each row execute function private.guard_salon_media_reference();
