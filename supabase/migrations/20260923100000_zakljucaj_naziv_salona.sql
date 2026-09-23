-- Task 40: naziv salona je dio identiteta brandirane aplikacije u prodavnici.
-- Mijenja se kroz tenant.yaml, generator i novi store build, ne kao runtime kontakt podatak.
--
-- Potpis ostaje isti zbog postojećih klijenata. `p_name` je sada optimistic assertion nad
-- nazivom koji je forma učitala: druga vrijednost je pokušaj promjene i odbija se prije upisa.
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

comment on function public.update_salon_contact(uuid, text, text, text, text, text, text, text, text) is
  'Kontakt podaci salona iz admina. p_name potvrđuje zatečeni build-time naziv i ne mijenja ga; branding, plan, status i slug ostaju platformski.';
