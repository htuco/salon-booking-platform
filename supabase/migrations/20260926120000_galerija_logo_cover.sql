-- Galerija salona, logo i cover iz admina. Task 50, ADR-0008, ADR-0015.
--
-- `authenticated` nad `salons` ima samo SELECT (task 36), pa vlasnik do sada nije mogao
-- postaviti nijednu sliku salona. Ova migracija otvara dva uska puta, oba `security definer`
-- i oba iza `private.is_admin(p_salon_id)`:
--
--   * `set_salon_image` mijenja **jednu** kolonu — logo ili cover. Zasebno, a ne oboje u
--     jednom pozivu: forma koja salje obje vrijednosti bi zamjenom loga vratila cover koji je
--     drugi tab u medjuvremenu promijenio.
--   * `set_salon_gallery` zamjenjuje cijeli niz `gallery_urls` (redoslijed = redoslijed niza,
--     ADR-0008), ali samo ako je zatečeni niz isti kao onaj koji je forma ucitala. Dva taba
--     koja istovremeno mijenjaju galeriju dobiju `PT409`, umjesto da drugi tiho pregazi prvi.
--
-- **Nova slika mora biti iz svog foldera u `salon-media`.** Inace bi vlasnik mogao u svoj
-- salon upisati tudji objekat ili bilo koji vanjski URL koji klijentska app onda ucitava.
-- Zatečeni URL-ovi (seed, ranije postavljene slike) smiju ostati u galeriji kad se samo
-- mijenja redoslijed ili brise — funkcija ih ne prepoznaje kao novu sliku.

-- Da li je `p_url` javni URL objekta `salon-media/<salon>/<vrsta>/<fajl>`. Host se ne
-- provjerava (lokalni stack i hostovani projekat imaju razlicit), ali putanja jeste — i to
-- do kraja stringa, bez upita, fragmenta ili dodatnog segmenta.
create or replace function private.is_salon_media_url(p_salon_id uuid, p_kind text, p_url text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_salon_id is not null
    and p_kind in ('galerija', 'logo', 'cover')
    and coalesce(p_url, '') ~ (
      '^https?://[^/?#]+/storage/v1/object/public/salon-media/'
      || p_salon_id::text || '/' || p_kind
      || '/[A-Za-z0-9_-][A-Za-z0-9._-]*$'
    )
$$;

revoke all on function private.is_salon_media_url(uuid, text, text) from public;
grant execute on function private.is_salon_media_url(uuid, text, text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Logo i cover
-- ---------------------------------------------------------------------------
create or replace function public.set_salon_image(
  p_salon_id uuid,
  p_kind text,
  p_url text
) returns public.salons language plpgsql security definer set search_path = '' as $fn$
declare
  v_url text := nullif(btrim(coalesce(p_url, '')), '');
  v_row public.salons%rowtype;
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_kind is null or p_kind not in ('logo', 'cover') then
    raise exception 'Nepoznata vrsta slike' using errcode = 'PT400';
  end if;
  -- `null` brise sliku; sve drugo mora biti objekat ovog salona u folderu te vrste.
  if v_url is not null and not private.is_salon_media_url(p_salon_id, p_kind, v_url) then
    raise exception 'Slika mora biti iz galerije salona' using errcode = 'PT400';
  end if;

  update public.salons s set
    logo_url = case when p_kind = 'logo' then v_url else s.logo_url end,
    cover_image_url = case when p_kind = 'cover' then v_url else s.cover_image_url end
  where s.id = p_salon_id
  returning * into v_row;

  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  return v_row;
end;
$fn$;

revoke all on function public.set_salon_image(uuid, text, text) from public, anon;
grant execute on function public.set_salon_image(uuid, text, text) to authenticated;

comment on function public.set_salon_image(uuid, text, text) is
  'Logo ili naslovna slika salona iz admina. Nova vrijednost mora biti objekat tog salona u salon-media; null brise. App ikona i splash su build artefakti iz tenant.yaml i ovo ih ne mijenja.';

-- ---------------------------------------------------------------------------
-- Galerija
-- ---------------------------------------------------------------------------
create or replace function public.set_salon_gallery(
  p_salon_id uuid,
  p_expected jsonb,
  p_urls jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  v_current jsonb;
  v_el jsonb;
  v_url text;
  v_seen text[] := '{}';
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  select s.gallery_urls into v_current
  from public.salons s
  where s.id = p_salon_id
  for update;

  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Optimisticka provjera: forma salje niz koji je ucitala. Ako ga je u medjuvremenu
  -- promijenio drugi tab ili drugi uredjaj, nista se ne upisuje.
  if p_expected is null or p_expected is distinct from v_current then
    raise exception 'Galerija je u međuvremenu promijenjena' using errcode = 'PT409';
  end if;

  if p_urls is null or jsonb_typeof(p_urls) <> 'array' then
    raise exception 'Galerija mora biti lista slika' using errcode = 'PT400';
  end if;
  if jsonb_array_length(p_urls) > 30 then
    raise exception 'Galerija prima najviše 30 slika' using errcode = 'PT400';
  end if;

  for v_el in select value from jsonb_array_elements(p_urls) loop
    if jsonb_typeof(v_el) <> 'string' then
      raise exception 'Galerija mora biti lista slika' using errcode = 'PT400';
    end if;
    v_url := v_el #>> '{}';
    if v_url = any(v_seen) then
      raise exception 'Ista slika je dvaput u galeriji' using errcode = 'PT400';
    end if;
    v_seen := v_seen || v_url;
    -- Zatečena slika smije ostati (redoslijed, brisanje drugih); nova mora biti iz
    -- foldera `galerija` ovog salona.
    if not (v_current @> jsonb_build_array(v_url))
       and not private.is_salon_media_url(p_salon_id, 'galerija', v_url) then
      raise exception 'Slika mora biti iz galerije salona' using errcode = 'PT400';
    end if;
  end loop;

  update public.salons s set gallery_urls = p_urls where s.id = p_salon_id;
  return p_urls;
end;
$fn$;

revoke all on function public.set_salon_gallery(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.set_salon_gallery(uuid, jsonb, jsonb) to authenticated;

comment on function public.set_salon_gallery(uuid, jsonb, jsonb) is
  'Zamjenjuje salons.gallery_urls (ADR-0008) ako je zatečeni niz jednak p_expected, inace PT409. Nove slike moraju biti iz salon-media/<salon>/galerija/; zatečene smiju ostati.';
