-- Ciscenje bucketa i prijava neprikladnog sadrzaja. Task 51, ADR-0024.
--
-- Dva odvojena dijela, oba iza Edge Functiona koje okida `pg_cron` kroz `pg_net`, potpisano
-- HMAC-om kao `send-push`:
--
--   * `media_orphans` daje listu objekata u `salon-media` koje nijedna slikovna kolona ne
--     referencira. Brise ih `cleanup-media` kroz Storage API — direktan `delete` nad
--     `storage.objects` blokira `storage.protect_delete`, a red bez fajla bi bio gori od
--     fajla bez reda.
--   * `content_reports` prima prijavu slike iz galerije. Salon je ne cita; cita je samo
--     `super_admin`, a `notify-content-reports` je salje na webhook platforme.

-- ---------------------------------------------------------------------------
-- Siroce u bucketu
-- ---------------------------------------------------------------------------

-- Putanja objekta iz javnog URL-a (`.../object/public/salon-media/<putanja>`), bez upita i
-- fragmenta. Vanjski URL (seed, Unsplash) daje NULL i nikad ne stiti ni ne brise nista.
create or replace function private.salon_media_path(p_url text)
returns text
language sql
immutable
set search_path = ''
as $$
  select substring(p_url from '/storage/v1/object/public/salon-media/([^?#]+)')
$$;

revoke all on function private.salon_media_path(text) from public;
grant execute on function private.salon_media_path(text) to service_role;

-- Objekti bez reference, najstariji prvi. Referenca se trazi u **svim** salonima, ne samo u
-- salonu iz putanje: pogresno zadrzan fajl kosta prostor, pogresno obrisan kvari ekran.
-- Neaktivna usluga i radnik i dalje stite svoju sliku (ADR-0024) — vracena usluga je ima.
--
-- Objekat mladji od `p_min_age` se ne vraca: upload je gore, a RPC koji upisuje referencu
-- mozda jos nije stigao. Putanja koja nije `<salon_id>/<vrsta>/<fajl>` se nikad ne vraca.
create or replace function public.media_orphans(
  p_min_age interval default interval '1 hour',
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
  )
  select private.storage_salon_id(o.name), o.name
  from storage.objects o
  where o.bucket_id = 'salon-media'
    and private.storage_salon_id(o.name) is not null
    and o.created_at < now() - coalesce(p_min_age, interval '1 hour')
    and not exists (select 1 from reference r where r.putanja = o.name)
  order by o.created_at, o.name
  limit least(greatest(coalesce(p_limit, 0), 0), 1000)
$$;

revoke all on function public.media_orphans(interval, integer) from public, anon, authenticated;
grant execute on function public.media_orphans(interval, integer) to service_role;

comment on function public.media_orphans(interval, integer) is
  'Objekti u salon-media koje ne referencira nijedna slikovna kolona nijednog salona, stariji od p_min_age. Samo service_role; brise ih cleanup-media kroz Storage API (ADR-0024).';

-- ---------------------------------------------------------------------------
-- Prijava sadrzaja
-- ---------------------------------------------------------------------------
create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id) on delete cascade,
  image_url text not null,
  reason text check (char_length(reason) <= 500),
  -- Brisanje naloga ne brise prijavu — platforma i dalje treba odluciti o slici.
  reporter_user_id uuid references auth.users(id) on delete set null,
  status text not null default 'open' check (status in ('open', 'removed', 'dismissed')),
  created_at timestamptz not null default now(),
  -- NULL = webhook platforme jos nije primio ovu prijavu.
  notified_at timestamptz,
  resolved_at timestamptz
);

-- Jedan klijent, jedna slika, jedna otvorena prijava. Ponovljen tap ne pravi novi red.
create unique index content_reports_otvorena_jednom
  on public.content_reports (reporter_user_id, image_url)
  where status = 'open';
create index content_reports_neobavijestene
  on public.content_reports (created_at)
  where notified_at is null;

alter table public.content_reports enable row level security;
revoke all on public.content_reports from anon, authenticated;
-- Salon ne cita prijave svog sadrzaja. Cita i razrjesava ih samo platforma.
grant select, update (status, resolved_at) on public.content_reports to authenticated;

create policy content_reports_super_admin_select on public.content_reports
  for select to authenticated
  using (private.is_super_admin());
create policy content_reports_super_admin_update on public.content_reports
  for update to authenticated
  using (private.is_super_admin())
  with check (private.is_super_admin());

create or replace function public.report_content(
  p_salon_id uuid,
  p_image_url text,
  p_reason text default null
) returns uuid language plpgsql security definer set search_path = '' as $fn$
declare
  v_url text := btrim(coalesce(p_image_url, ''));
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_id uuid;
begin
  -- Pravi klijent (ne anonimna Auth sesija, ne osoblje) u salonu koji je izabrao headerom.
  if private.is_client() is not true
     or p_salon_id is null
     or p_salon_id is distinct from private.client_salon_id() then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if char_length(v_reason) > 500 then
    raise exception 'Razlog je predug' using errcode = 'PT400';
  end if;
  -- Prijavljuje se slika koju klijent stvarno vidi, ne proizvoljan URL.
  if not exists (
    select 1 from public.salons s
    where s.id = p_salon_id and s.gallery_urls @> jsonb_build_array(v_url)
  ) then
    raise exception 'Slika nije u galeriji salona' using errcode = 'PT400';
  end if;

  insert into public.content_reports (salon_id, image_url, reason, reporter_user_id)
  values (p_salon_id, v_url, v_reason, auth.uid())
  on conflict (reporter_user_id, image_url) where status = 'open' do nothing
  returning id into v_id;

  if v_id is null then
    select r.id into v_id
    from public.content_reports r
    where r.reporter_user_id = auth.uid() and r.image_url = v_url and r.status = 'open';
  end if;
  return v_id;
end;
$fn$;

revoke all on function public.report_content(uuid, text, text) from public, anon;
grant execute on function public.report_content(uuid, text, text) to authenticated;

comment on function public.report_content(uuid, text, text) is
  'Klijent prijavljuje sliku iz galerije salona. Prijava ide platformi (content_reports, samo super_admin), ne salonu. Ponovljena prijava iste slike vraca postojeci id.';

-- Worker preuzima neobavijestene prijave. `notified_at` se postavlja pri preuzimanju, pa dva
-- preklopljena poziva ne salju istu prijavu dvaput; neuspjesan webhook ga vraca na NULL.
create or replace function public.claim_content_reports(p_limit integer default 20)
returns table (
  id uuid,
  salon_id uuid,
  salon_name text,
  image_url text,
  reason text,
  created_at timestamptz
) language sql security definer set search_path = '' as $$
  with preuzete as (
    update public.content_reports r
    set notified_at = now()
    where r.id in (
      select c.id from public.content_reports c
      where c.notified_at is null
      order by c.created_at
      limit least(greatest(coalesce(p_limit, 0), 0), 50)
      for update skip locked
    )
    returning r.id, r.salon_id, r.image_url, r.reason, r.created_at
  )
  select p.id, p.salon_id, s.name, p.image_url, p.reason, p.created_at
  from preuzete p
  join public.salons s on s.id = p.salon_id
  order by p.created_at
$$;

revoke all on function public.claim_content_reports(integer) from public, anon, authenticated;
grant execute on function public.claim_content_reports(integer) to service_role;

-- ---------------------------------------------------------------------------
-- Okidaci workera
-- ---------------------------------------------------------------------------

-- Poziva Edge Function potpisanu sa `<scope>:<timestamp>`. Scope je u potpisu da potpis za
-- jedan worker ne vrijedi na drugom. Bez URL-a ili tajne u Vaultu (lokalni stack) ne salje
-- nista: fajlovi ostaju, prijave cekaju u tabeli.
create or replace function private.call_worker(p_url_name text, p_secret_name text, p_scope text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_url text; v_secret text; v_timestamp text; v_signature text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = p_url_name;
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = p_secret_name;
  if v_url is null or v_secret is null then return; end if;
  -- pg_net posjeduje supabase_admin. Trajna tajna ne smije u njegove transportne tabele.
  v_timestamp := floor(extract(epoch from clock_timestamp()))::bigint::text;
  v_signature := encode(extensions.hmac(p_scope || ':' || v_timestamp, v_secret, 'sha256'), 'hex');
  perform net.http_post(url := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_timestamp || '.' || v_signature),
    body := '{}'::jsonb, timeout_milliseconds := 5000);
end $$;
revoke all on function private.call_worker(text, text, text) from public, anon, authenticated;
grant execute on function private.call_worker(text, text, text) to service_role;

create or replace function private.dispatch_content_reports()
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.content_reports where notified_at is null) then return; end if;
  perform private.call_worker('content_report_worker_url', 'content_report_worker_secret',
    'notify-content-reports');
end $$;
revoke all on function private.dispatch_content_reports() from public, anon, authenticated;
grant execute on function private.dispatch_content_reports() to service_role;

select cron.schedule('notify-content-reports', '* * * * *',
  'select private.dispatch_content_reports()');
select cron.schedule('cleanup-media', '17 * * * *',
  $$select private.call_worker('media_cleanup_url', 'media_cleanup_secret', 'cleanup-media')$$);
