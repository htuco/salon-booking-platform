-- Task 66, pregled PR-a #136 (Eniz, 2026-10-14). `20261013160000_registracija_profil` je vec
-- na hostovanom projektu, pa se ne mijenja: ispravke idu ovdje.
--
--   1. Trka na `unique(salon_id, phone)`: izmedju provjere „nijedan drugi klijent u salonu ne
--      nosi ovaj broj" i upisa, drugi upis moze zauzeti isti broj. Tada `unique_violation`
--      obori trigger nad `auth_identities` — dakle **prijavu** — ili `ensure_customer`, dakle
--      slanje termina. Upravo to `clean_phone`/`clean_name` i provjera sudara pokusavaju
--      sprijeciti, pa sudar koji stigne kasno ide istim putem kao sudar koji se vidi: broj se
--      preskace.
--   2. `legal_versions()` je `stable`, ne `immutable`: vrijednost se namjerno mijenja
--      migracijom, a `immutable` planeru dozvoljava da je uvijek zamijeni konstantom.
--   3. Komentar o poredjenju po ciframa je obecavao vise nego sto kod radi (v. dolje).

-- ---------------------------------------------------------------------------
-- 1. `legal_versions()` — stable
-- ---------------------------------------------------------------------------
alter function public.legal_versions() stable;

-- ---------------------------------------------------------------------------
-- 2. Popunjavanje adresara: telefon u svom pod-bloku
-- ---------------------------------------------------------------------------
-- Pravila su ista kao u `20261013160000` („samo prazno se popunjava", sudar se preskace).
-- Mijenja se samo oblik: ime i telefon vise nisu jedan `update`, jer bi kasni sudar na telefonu
-- ponistio i ime. Telefon ide red po red, svaki u svom bloku sa `exception` — pod-transakcija
-- vraca samo taj red, a prijava prolazi.
--
-- **Sta „po ciframa" znaci, tacno.** Porede se samo cifre, pa razmak, crtica, zagrade i `+` ne
-- smetaju: `+387 61 111 111` i `+38761111111` su isti broj. **Prefiks se ne normalizuje:**
-- aplikacija salje `+387 61 …`, a salon telefonskog klijenta obicno upise kao `061 …`, i te
-- cifre se ne poklapaju — isti covjek tada ostaje dva reda, koja salon spaja iz admina.
-- Normalizacija vodece `0` naspram pozivnog broja trazi zemlju salona i nije dio ovog taska.
create or replace function private.fill_customers_from_identity(p_identity uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_identity public.auth_identities%rowtype;
  v_red record;
  v_constraint text;
begin
  select * into v_identity from public.auth_identities i
  where i.id = p_identity and i.deleted_at is null;
  if not found then return; end if;

  update public.customers c
  set name = private.clean_name(v_identity.display_name)
  where c.auth_identity_id = v_identity.id
    and btrim(c.name) in ('', 'Klijent')
    and private.clean_name(v_identity.display_name) is not null;

  if v_identity.phone is not null then
    for v_red in
      select c.salon_id, c.id from public.customers c
      where c.auth_identity_id = v_identity.id and c.phone is null
    loop
      begin
        -- **Vlasnik i prazan telefon se provjeravaju ponovo**, ne samo u kursoru. Kursor je
        -- snimak od početka petlje; ako je salon u međuvremenu upisao svoju ispravku broja ili
        -- red prebacio na drugi identitet, upis bez ovog uslova bi pregazio salonovu ispravku
        -- ili tuđem redu dao ovaj broj. Original je bio jedan `update` sa tim uslovom, koji
        -- Postgres ponovo provjerava na najnovijoj verziji reda (revizija pregleda #136).
        update public.customers c
        set phone = v_identity.phone
        where c.salon_id = v_red.salon_id and c.id = v_red.id
          and c.auth_identity_id = v_identity.id and c.phone is null
          and not exists (
            select 1 from public.customers d
            where d.salon_id = c.salon_id and d.id <> c.id and d.phone is not null
              and regexp_replace(d.phone, '[^0-9]', '', 'g')
                = regexp_replace(v_identity.phone, '[^0-9]', '', 'g'));
      exception when unique_violation then
        -- Drugi upis je broj zauzeo poslije provjere. Isti ishod kao sudar koji se vidi.
        -- Hvata se **samo** sudar na telefonu: unique koji kasnije doda neki trigger nad
        -- `customers` ne smije biti tiho progutan.
        get stacked diagnostics v_constraint = constraint_name;
        if v_constraint is distinct from 'customers_salon_id_phone_key' then
          raise;
        end if;
      end;
    end loop;
  end if;

  -- Termini preuzimaju ono sto je red klijenta **sada**, a ne direktno identitet: ako je
  -- telefon preskocen zbog sudara, ni termin ga ne smije dobiti.
  update public.appointments a
  set customer_name = case when btrim(coalesce(a.customer_name, '')) in ('', 'Klijent')
        then c.name else a.customer_name end,
      customer_phone = coalesce(a.customer_phone, c.phone)
  from public.customers c
  where c.salon_id = a.salon_id and c.id = a.customer_id
    and c.auth_identity_id = v_identity.id
    and ((btrim(coalesce(a.customer_name, '')) in ('', 'Klijent') and btrim(c.name) not in ('', 'Klijent'))
      or (a.customer_phone is null and c.phone is not null));
end $$;

revoke all on function private.fill_customers_from_identity(uuid) from public, anon, authenticated;

comment on function private.fill_customers_from_identity(uuid) is
  'Popunjava adresar svakog salona identiteta (ADR-0030): ime samo preko Klijent/praznog, telefon samo preko NULL. Telefon se preskace kad ga u salonu drugi klijent nosi sa istim ciframa (razmaci i + ne smetaju, ali 061 i +387 61 nisu isti) ili kad ga drugi upis zauzme izmedju provjere i upisa.';

-- ---------------------------------------------------------------------------
-- 3. `ensure_customer`: kasni sudar na telefonu pravi red bez telefona
-- ---------------------------------------------------------------------------
-- Tijelo je ono iz `20261013160000`; nov je samo `exception` oko `insert`-a. Bez njega bi
-- sudar koji stigne poslije provjere oborio slanje termina umjesto da klijent nastane bez broja.
create or replace function public.ensure_customer(
  p_salon_id uuid,
  p_name text default null
) returns public.customers
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_salon uuid;
  v_identity public.auth_identities%rowtype;
  v_row public.customers%rowtype;
  v_ime text;
  v_phone text;
  v_constraint text;
begin
  -- Guard je nepromijenjen od taska 14: NULL iz `client_salon_id()` se hvata prvi, jer
  -- `not (true and NULL)` ne okida `if` (v. `security.md`, „Upsert klijenta").
  v_salon := private.client_salon_id();

  if v_salon is null
     or p_salon_id is null
     or p_salon_id <> v_salon
     or not private.is_client()
  then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Identitet se izvodi iz tokena, nikad ne stize kao argument.
  select * into v_identity
  from public.auth_identities ai
  where ai.supabase_user_id = auth.uid() and ai.deleted_at is null;

  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  v_ime := nullif(btrim(coalesce(p_name, '')), '');
  v_ime := coalesce(v_ime, private.clean_name(v_identity.display_name), 'Klijent');

  v_phone := v_identity.phone;
  if v_phone is not null and exists (
    select 1 from public.customers d
    where d.salon_id = p_salon_id and d.phone is not null
      and regexp_replace(d.phone, '[^0-9]', '', 'g') = regexp_replace(v_phone, '[^0-9]', '', 'g')
  ) then
    v_phone := null;
  end if;

  begin
    insert into public.customers(salon_id, auth_identity_id, name, phone)
    values (p_salon_id, v_identity.id, v_ime, v_phone)
    on conflict (salon_id, auth_identity_id) do nothing
    returning * into v_row;
  exception when unique_violation then
    -- Broj je zauzet poslije provjere: klijent nastaje bez njega, kao kod vidljivog sudara.
    -- Samo sudar na telefonu; svaki drugi unique ide dalje (v. trigger popunjavanja).
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint is distinct from 'customers_salon_id_phone_key' then
      raise;
    end if;
    insert into public.customers(salon_id, auth_identity_id, name, phone)
    values (p_salon_id, v_identity.id, v_ime, null)
    on conflict (salon_id, auth_identity_id) do nothing
    returning * into v_row;
  end;

  if v_row.id is null then
    select * into v_row
    from public.customers c
    where c.salon_id = p_salon_id and c.auth_identity_id = v_identity.id;
  end if;

  return v_row;
end;
$$;

revoke all on function public.ensure_customer(uuid, text) from public, anon;
grant execute on function public.ensure_customer(uuid, text) to authenticated;

comment on function public.ensure_customer(uuid, text) is
  'Vraca klijenta prijavljenog korisnika u salonu iz x-salon-id, praveci ga pri prvom pozivu sa imenom i telefonom identiteta (telefon samo ako ga salon vec ne nosi na drugom klijentu, i ako ga niko ne zauzme izmedju provjere i upisa). Idempotentna; 42501 kad pozivalac nije klijent tog salona ili nema identitet.';
