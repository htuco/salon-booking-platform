-- Task 45: nalozi za osoblje kroz poziv sa kodom.
--
-- Do sada nije postojao **nijedan** nacin da nastane nalog osoblja — oba seed admina su
-- upisana rucno u SQL-u.
--
-- **Zasto kod, a ne Supabase email invite.** Hostovani projekat nema vlastiti SMTP i odbija
-- slanje poslije dva emaila na sat. Poziv koji zavisi od emaila bi pukao na prvom salonu sa
-- tri radnika. Uz to je kod najlaksi za vlasnika: upise ime, izabere ulogu i posalje link
-- kako god salje sve ostalo (Viber, WhatsApp). Ne kuca radnikov email i ne zna mu lozinku.
-- Odluka zapisana u ADR-0023.
--
-- Tok:
--   1. vlasnik: `create_staff_invite` -> kod (vidi ga **samo jednom**, baza cuva hash);
--   2. radnik: Edge Function `accept-staff-invite` sa kodom, emailom i lozinkom;
--   3. funkcija pod service role kljucem pravi `auth.users` sa `app_metadata` **iz poziva**,
--      pa `accept_staff_invite` upisuje `public.users` i zatvara poziv.
--
-- Uloga i salon **nikad ne dolaze od radnika**: oba su u redu poziva, koji je napisao admin
-- tog salona. Radnik donosi samo kod, email i lozinku.

create extension if not exists pgcrypto with schema extensions;

create table public.staff_invites (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id),

  -- Zatvorena lista: `super_admin` se pozivom ne moze dodijeliti, i to drzi `check`, ne
  -- samo RPC. Red upisan mimo RPC-a (service role) i dalje ne moze nositi platformsku ulogu.
  role public.staff_role not null check (role in ('salon_admin', 'employee')),
  name text not null check (length(btrim(name)) > 0),

  -- Opciono: poziv napravljen iz reda u Osoblju. Vezivanje naloga na `employees` je task 46;
  -- ovdje se samo pamti odakle je poziv dosao, da 46 ne mora pitati vlasnika ponovo.
  employee_id uuid,

  -- sha256 koda. Kod se vraca samo pri kreiranju; procurjela tabela ne daje upotrebljiv poziv.
  code_hash text not null unique,
  expires_at timestamptz not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  accepted_user_id uuid references auth.users(id) on delete set null,
  revoked_at timestamptz,

  foreign key (salon_id, employee_id) references public.employees(salon_id, id),
  unique (salon_id, id),
  check (accepted_at is null or revoked_at is null)
);

comment on table public.staff_invites is
  'Pozivi za nalog osoblja. Kod se cuva kao sha256; uloga i salon dolaze iz poziva, nikad od radnika.';

revoke all on public.staff_invites from anon, authenticated;
grant all on public.staff_invites to service_role;
-- Admin cita pozive svog salona (lista „na cekanju" u Pristupu). Pisanje samo kroz RPC.
grant select on public.staff_invites to authenticated;
alter table public.staff_invites enable row level security;
create policy staff_read on public.staff_invites
  for select to authenticated
  using (private.is_admin(salon_id));

-- ---------------------------------------------------------------------------
-- Kreiranje i povlacenje — admin salona
-- ---------------------------------------------------------------------------
create function public.create_staff_invite(
  p_salon_id uuid,
  p_role public.staff_role,
  p_name text,
  p_employee_id uuid default null
) returns table (invite_id uuid, code text, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $fn$
declare
  -- 10 znakova iz abecede bez 0/O/1/I/L: kod se prepisuje sa telefona. 31^10 ≈ 8e14.
  v_abeceda constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_kod text := '';
  v_bajtovi bytea := extensions.gen_random_bytes(10);
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

  for i in 0..9 loop
    v_kod := v_kod || substr(v_abeceda, (get_byte(v_bajtovi, i) % length(v_abeceda)) + 1, 1);
  end loop;

  insert into public.staff_invites(salon_id, role, name, employee_id, code_hash, expires_at, created_by)
  values (p_salon_id, p_role, btrim(p_name), p_employee_id,
    encode(extensions.digest(v_kod, 'sha256'), 'hex'), v_istice, auth.uid())
  returning id into v_id;

  return query select v_id, v_kod, v_istice;
end;
$fn$;

create function public.revoke_staff_invite(p_salon_id uuid, p_invite_id uuid)
returns void language plpgsql security definer set search_path = '' as $fn$
begin
  if not private.is_admin(p_salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  update public.staff_invites i set revoked_at = now()
  where i.salon_id = p_salon_id and i.id = p_invite_id
    and i.accepted_at is null and i.revoked_at is null;
  if not found then
    -- Tudji, nepostojeci, vec prihvacen i vec povucen poziv daju istu gresku.
    raise exception 'Poziv ne postoji ili je vec iskoristen' using errcode = 'PT404';
  end if;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Prihvatanje — samo service role (Edge Function `accept-staff-invite`)
-- ---------------------------------------------------------------------------
-- Dva koraka jer izmedju njih Edge Function pravi `auth.users` red, a to moze samo admin API:
--   `peek_staff_invite` — je li kod ziv, i koju ulogu/salon nosi (za `app_metadata`);
--   `accept_staff_invite` — upis `public.users` i zatvaranje poziva, **u istoj transakciji**,
--   uz ponovnu provjeru i `for update`, pa dva radnika sa istim kodom ne mogu oba uspjeti.
create function public.peek_staff_invite(p_code text)
returns table (invite_id uuid, salon_id uuid, role public.staff_role, name text)
language sql stable security definer set search_path = '' as $fn$
  select i.id, i.salon_id, i.role, i.name
  from public.staff_invites i
  where i.code_hash = encode(extensions.digest(upper(btrim(p_code)), 'sha256'), 'hex')
    and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()
    and private.salon_active(i.salon_id);
$fn$;

create function public.accept_staff_invite(p_code text, p_user_id uuid, p_email text)
returns public.users
language plpgsql security definer set search_path = '' as $fn$
declare
  v_poziv public.staff_invites%rowtype;
  v_red public.users%rowtype;
begin
  select * into v_poziv from public.staff_invites i
  where i.code_hash = encode(extensions.digest(upper(btrim(p_code)), 'sha256'), 'hex')
    and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()
  for update;
  if not found then
    raise exception 'Poziv ne postoji, istekao je ili je vec iskoristen' using errcode = 'PT404';
  end if;

  insert into public.users(id, salon_id, name, email, role)
  values (p_user_id, v_poziv.salon_id, v_poziv.name, lower(btrim(p_email)), v_poziv.role)
  returning * into v_red;

  update public.staff_invites set accepted_at = now(), accepted_user_id = p_user_id
  where id = v_poziv.id;

  return v_red;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Uklanjanje clana osoblja
-- ---------------------------------------------------------------------------
-- **Pristup prestaje, istorija ostaje.** Brise se samo `public.users` red: `is_admin` trazi
-- i taj red, pa JWT koji jos nosi `role = salon_admin` od sljedeceg zahtjeva ne otvara nista.
-- Termini, klijenti i `staff_invites.created_by` ostaju — nijedan ne referencira `public.users`.
-- `auth.users` red ostaje bez prava (isti ishod kao nalog koji nikad nije bio osoblje).
--
-- Vlasnik ne moze ukloniti sebe: salon bez ijednog admina nema ko da pozove novog.
create function public.remove_staff_user(p_salon_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $fn$
begin
  if not private.is_admin(p_salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'Ne mozete ukloniti vlastiti nalog' using errcode = 'PT400';
  end if;
  delete from public.users u
  where u.salon_id = p_salon_id and u.id = p_user_id and u.role <> 'super_admin';
  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Lista osoblja salona
-- ---------------------------------------------------------------------------
-- **RPC, a ne politika nad `public.users`.** `StaffRepository.membership()` cita
-- `public.users` bez filtera i oslanja se na `own_staff_profile` da vrati tacno jedan red.
-- Politika „admin vidi osoblje salona" bi adminu vratila vise redova i srusila prijavu
-- (`maybeSingle`). Vidljivost tabele zato ostaje ista, a lista ide kroz ovu funkciju.
create function public.list_staff_users(p_salon_id uuid)
returns table (id uuid, name text, email text, role public.staff_role, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $fn$
begin
  if not private.is_admin(p_salon_id) then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  return query
  select u.id, u.name, u.email, u.role, u.created_at
  from public.users u
  where u.salon_id = p_salon_id and u.role <> 'super_admin'
  order by u.created_at;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Grantovi
-- ---------------------------------------------------------------------------
revoke all on function public.create_staff_invite(uuid, public.staff_role, text, uuid) from public, anon;
revoke all on function public.revoke_staff_invite(uuid, uuid) from public, anon;
revoke all on function public.remove_staff_user(uuid, uuid) from public, anon;
revoke all on function public.list_staff_users(uuid) from public, anon;
grant execute on function public.create_staff_invite(uuid, public.staff_role, text, uuid) to authenticated;
grant execute on function public.revoke_staff_invite(uuid, uuid) to authenticated;
grant execute on function public.remove_staff_user(uuid, uuid) to authenticated;
grant execute on function public.list_staff_users(uuid) to authenticated;

-- Prihvatanje nije za `authenticated` ni `anon`: bez service role kljuca se ne moze
-- napraviti `auth.users`, a `accept_staff_invite` bez tog reda pada na FK.
revoke all on function public.peek_staff_invite(text) from public, anon, authenticated;
revoke all on function public.accept_staff_invite(text, uuid, text) from public, anon, authenticated;
grant execute on function public.peek_staff_invite(text) to service_role;
grant execute on function public.accept_staff_invite(text, uuid, text) to service_role;
