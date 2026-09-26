-- Storage bucket po salonu. Task 48, ADR-0015.
--
-- Slike salona (usluge, radnici, galerija, logo, cover) idu u jedan bucket sa javnim citanjem.
-- Putanja je `<salon_id>/<vrsta>/<fajl>`: prvi segment odlucuje ko smije pisati, bez pretrage.
-- Pise samo admin tog salona (`private.is_admin`); radnik, klijent i anon ne pisu nista.
-- Tip i velicina su ograniceni na samom bucketu, ne samo u aplikaciji.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('salon-media', 'salon-media', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Salon iz putanje objekta. Prvi segment koji nije UUID daje NULL, a `is_admin(NULL)` nije
-- istina — pogresna putanja se odbija, ne baca gresku pri castu.
create or replace function private.storage_salon_id(p_name text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case
    when split_part(p_name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      and split_part(p_name, '/', 2) <> ''
      and split_part(p_name, '/', 3) <> ''
    then split_part(p_name, '/', 1)::uuid
  end
$$;

revoke all on function private.storage_salon_id(text) from public;
grant execute on function private.storage_salon_id(text) to anon, authenticated, service_role;

-- Javni URL (`/object/public/...`) ne prolazi kroz RLS, pa anon citanje ne treba politiku.
-- Listanje i `upsert` traze SELECT — to dobija samo admin, i samo za svoj salon.
create policy salon_media_admin_select on storage.objects
  for select to authenticated
  using (bucket_id = 'salon-media'
         and private.is_admin(private.storage_salon_id(name)) is true);

create policy salon_media_admin_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'salon-media'
              and private.is_admin(private.storage_salon_id(name)) is true);

create policy salon_media_admin_update on storage.objects
  for update to authenticated
  using (bucket_id = 'salon-media'
         and private.is_admin(private.storage_salon_id(name)) is true)
  with check (bucket_id = 'salon-media'
              and private.is_admin(private.storage_salon_id(name)) is true);

create policy salon_media_admin_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'salon-media'
         and private.is_admin(private.storage_salon_id(name)) is true);
