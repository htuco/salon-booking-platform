-- Upsert klijenta u salonu iz `x-salon-id`. Task 14.
--
-- Zatvara poznatu rupu iz `.claude/docs/security.md` ("Sta jos nije zatvoreno"): upis u
-- `customers` do sada nije imao validiranu funkciju, a `book_appointment` trazi da klijent
-- vec postoji. Bez ovoga prijavljen korisnik ne moze rezervisati, jer nema `customer_id`.
--
-- Klijentski `insert` na `customers` ne postoji i nece: tabela nema `insert` grant za
-- `authenticated` (v. grantove u init migraciji), pa je ovo jedini put.

-- ---------------------------------------------------------------------------
-- 1. Politika prije funkcije
-- ---------------------------------------------------------------------------
-- Citanje vlastitog reda vec pokriva `own_customer` iz init migracije. Nova politika
-- se ne dodaje: funkcija je `security definer` i pise mimo RLS-a, a svaki drugi put do
-- `customers` ostaje zatvoren. Dodavanje `insert` politike bi otvorilo direktan upis sa
-- klijenta — tacno ono sto ova funkcija postoji da sprijeci.

-- ---------------------------------------------------------------------------
-- 2. Funkcija
-- ---------------------------------------------------------------------------
create function public.ensure_customer(
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
begin
  -- Pozivalac mora biti klijent **i** raditi u salonu koji je sam izabrao headerom.
  -- `private.client_salon_id()` vraca NULL za nepostojeci, neaktivan i pokvaren header.
  --
  -- **Provjera je namjerno rastavljena i NULL se hvata prvi.** Prirodniji zapis
  -- `if not (private.is_client() and p_salon_id = private.client_salon_id())` je
  -- **rupa**: `true and NULL` je `NULL`, `not NULL` je `NULL`, a `if NULL then` se ne
  -- izvrsava — pa bi zahtjev **bez headera** prosao kroz guard i napravio klijenta u
  -- salonu koji je pozivalac sam poslao kao argument. Nadjeno pgTAP testom
  -- ("Bez x-salon-id headera nema konteksta"), ne citanjem.
  --
  -- Osoblje namjerno nije ovdje: admin unosi telefonske klijente bez naloga
  -- (`auth_identity_id` je nullable, `docs/06 §4`), i to je drugi tok sa drugom
  -- validacijom — Sprint 3. Jedna funkcija za oba bi znacila da admin grana moze
  -- napraviti red vezan za tudji identitet.
  v_salon := private.client_salon_id();

  if v_salon is null
     or p_salon_id is null
     or p_salon_id <> v_salon
     or not private.is_client()
  then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Identitet se **izvodi iz tokena**, nikad ne stize kao argument. Kad bi pozivalac
  -- slao `auth_identity_id`, ova funkcija bi bila nacin da se napravi klijent vezan za
  -- tudju osobu — i to u salonu u kojem pozivalac ima pravo pristupa.
  select * into v_identity
  from public.auth_identities ai
  where ai.supabase_user_id = auth.uid() and ai.deleted_at is null;

  -- Ista poruka kao iznad: "nemas identitet" i "nisi klijent" se ne razlikuju.
  -- Red pravi trigger `private.sync_auth_identity()` nad `auth.users` (task 02), pa
  -- njegovo odsustvo znaci obrisan nalog ili poziv bez tokena.
  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Ime: prvo ono sto je korisnik upisao, pa ono sto je provider dao, pa neutralan
  -- fallback. `customers.name` je `not null`, a Apple private relay i email OTP cesto
  -- ne daju nikakvo ime — bez fallbacka bi prva prijava takvog korisnika pala.
  v_ime := nullif(btrim(coalesce(p_name, '')), '');
  v_ime := coalesce(v_ime, nullif(btrim(coalesce(v_identity.display_name, '')), ''), 'Klijent');

  -- `on conflict do nothing` pa ponovno citanje, a ne `do update`: drugi poziv ne smije
  -- prepisati ime koje je salon u medjuvremenu ispravio u svom adresaru. Upsert koji
  -- "osvjezava" ime na svakoj prijavi bi tiho vracao "Klijent" preko unesenog imena.
  insert into public.customers(salon_id, auth_identity_id, name)
  values (p_salon_id, v_identity.id, v_ime)
  on conflict (salon_id, auth_identity_id) do nothing
  returning * into v_row;

  if v_row.id is null then
    select * into v_row
    from public.customers c
    where c.salon_id = p_salon_id and c.auth_identity_id = v_identity.id;
  end if;

  return v_row;
end;
$$;

comment on function public.ensure_customer(uuid, text) is
  'Vraca klijenta prijavljenog korisnika u salonu iz x-salon-id, praveci ga pri prvom pozivu. Idempotentna; 42501 kad pozivalac nije klijent tog salona ili nema identitet.';

-- ---------------------------------------------------------------------------
-- 3. Grantovi
-- ---------------------------------------------------------------------------
-- Rezervacija trazi prijavu (`docs/06 §1.1`), pa je trazi i klijent koji je nosi.
--
-- **`revoke ... from public` ovdje nije dovoljno.** Supabase kroz `pg_default_acl` daje
-- `execute` na nove funkcije u `public` shemi **direktno** rolama `anon` i `authenticated`
-- (`select defaclacl from pg_default_acl` → `anon=X/postgres`), a ne kroz `PUBLIC`. Revoke
-- od `PUBLIC` zato ne skida nista, i funkcija ostaje pozivna neprijavljenom korisniku.
-- Nadjeno pgTAP testom ("anon nema execute grant"), koji je bez ovog reda padao.
revoke all on function public.ensure_customer(uuid, text) from public, anon;
grant execute on function public.ensure_customer(uuid, text) to authenticated;

-- Isti propust postoji i na `book_appointment` iz taska 05: `security.md` tvrdi da
-- "rezervacija trazi prijavu (grant execute ... to authenticated)", ali `anon` je i tamo
-- zadrzao `execute` iz istog razloga. Tok je i dalje branjen logikom — `auth.uid()` je
-- NULL za `anon`, pa `private.owns_identity(...)` pada i poziv zavrsi sa 42501 — ali
-- granica koju dokument opisuje nije postojala. Zatvara se ovdje, jer je jedan red, a
-- odbrana koja se oslanja samo na logiku unutar funkcije je odbrana koja pukne prvi put
-- kad se ta logika promijeni.
revoke all on function public.book_appointment(uuid, uuid, uuid, date, time, uuid, text, uuid)
  from public, anon;

-- Pregled slobodnih termina **ostaje javan** (`docs/06 §1.1`: login nikad ne smije
-- blokirati prikaz slobodnih termina). Ove dvije se namjerno ne diraju.
