-- Task 66: registracija sa imenom, telefonom i prihvatanjem uslova.
--
-- Do sada je svaki email klijent u Meluri bio „Klijent / Bez broja": forma je trazila samo
-- email i lozinku, a `ensure_customer` pada na `'Klijent'` kad identitet nema ime. ADR-0029
-- je odlucio da se ime i telefon traze pri registraciji (telefon bez SMS-a), a uslovi
-- prihvataju checkboxom koji se biljezi sa verzijom. ADR-0030 nosi dvije odluke ovog taska:
-- eksplicitnu verziju uslova i pravilo po kojem identitet popunjava adresar salona.
--
-- **Ime i telefon su po identitetu, a `customers` je po salonu.** Identitet je jedan covjek;
-- adresar je salonova kopija koju salon smije ispraviti. Zato identitet adresar samo
-- **popunjava**, a nikad ne prepisuje: ime samo preko „Klijent" ili praznog, telefon samo
-- preko praznog (ADR-0030). Salonova ispravka uvijek pobjedjuje.
--
-- **Popunjavanje namjerno prelazi granicu salona**, kao `delete_my_account` (task 17): dira
-- iskljucivo redove vezane za identitet koji se mijenja, u svakom salonu u kojem je taj covjek
-- klijent. Nijedan salon pri tome ne cita tudji red — podatak tece od identiteta ka salonu,
-- nikad od salona ka salonu (`docs/06` §4.3).

-- ---------------------------------------------------------------------------
-- 1. Kolone na identitetu
-- ---------------------------------------------------------------------------
alter table public.auth_identities
  add column phone text,
  add column terms_version int,
  add column privacy_version int,
  add column terms_accepted_at timestamptz;

comment on column public.auth_identities.phone is
  'Telefon iz registracije ili sa „Dopuni profil" (task 66), bez SMS verifikacije. Prikazni podatak: nikad ne odlucuje o pristupu.';
comment on column public.auth_identities.terms_version is
  'Verzija Uslova koristenja koju je korisnik prihvatio (public.legal_versions()). NULL = nije prihvatio nijednu.';
comment on column public.auth_identities.privacy_version is
  'Verzija Politike privatnosti koju je korisnik prihvatio (public.legal_versions()).';
comment on column public.auth_identities.terms_accepted_at is
  'Kad su oba dokumenta zadnji put prihvacena.';

-- ---------------------------------------------------------------------------
-- 2. Verzija uslova — eksplicitna, podize je platforma (ADR-0030)
-- ---------------------------------------------------------------------------
-- **Konstanta u funkciji, ne tabela ni `max(updated_at)`.** `updated_at` sekcija se mijenja na
-- svaku ispravku zareza i na svaku salonsku izmjenu `salon_policies`; verzija izvedena iz njega
-- bi trazila ponovno prihvatanje od svih korisnika zbog tipfelera. Tabela bez `salon_id` bi bila
-- jos jedan izuzetak od zlatnog pravila (v. `app_policies`) za dva broja. Podizanje verzije je
-- zato nova migracija sa `create or replace` — vidljiv, pregledan korak, a ne tihi update.
create function public.legal_versions()
returns table (terms int, privacy int)
language sql immutable set search_path = '' as $$
  select 1, 1
$$;

revoke all on function public.legal_versions() from public;
grant execute on function public.legal_versions() to anon, authenticated;

comment on function public.legal_versions() is
  'Vazece verzije Uslova koristenja i Politike privatnosti (task 66, ADR-0030). Podize se novom migracijom kad se dokument sustinski promijeni; nova verzija trazi ponovno prihvatanje.';

-- ---------------------------------------------------------------------------
-- 3. Telefon iz slobodnog teksta
-- ---------------------------------------------------------------------------
-- Vraca `NULL` za sve sto nije telefon, umjesto da baca. Poziva je i trigger nad `auth.users`,
-- a izuzetak u tom triggeru bi oborio **prijavu** — korisnik sa pokvarenim metapodatkom ne bi
-- mogao uci u aplikaciju. Format se ne normalizuje: salon broj cita i zove onako kako ga je
-- covjek napisao.
create function private.clean_phone(p_phone text) returns text
language sql immutable set search_path = '' as $$
  select case
    when v is null then null
    when v !~ '^\+?[0-9 ()/-]+$' then null
    when length(regexp_replace(v, '[^0-9]', '', 'g')) not between 6 and 15 then null
    else v
  end
  from (select nullif(btrim(coalesce(p_phone, '')), '') as v) t
$$;

revoke all on function private.clean_phone(text) from public;

-- Ime iz slobodnog teksta: prazno i predugo su „nema imena", ne greska.
create function private.clean_name(p_name text) returns text
language sql immutable set search_path = '' as $$
  select case when char_length(v) between 1 and 120 then v end
  from (select nullif(btrim(coalesce(p_name, '')), '') as v) t
$$;

revoke all on function private.clean_name(text) from public;

-- ---------------------------------------------------------------------------
-- 4. Sinhronizacija identiteta iz `auth.users`
-- ---------------------------------------------------------------------------
-- Isto kao do sada, plus telefon i prihvatanje uslova pri registraciji.
--
-- **Prihvatanje se cita samo pri `INSERT`-u.** Registracija salje
-- `signUp(data: {full_name, phone, terms_accepted: true})`, a sesije tada nema kad je potvrda
-- emaila ukljucena — RPC se ne moze pozvati, pa metapodatak nosi pristanak do baze. Pri
-- `UPDATE`-u (svaka prijava mijenja `last_sign_in_at`) isti metapodatak i dalje stoji, pa bi ga
-- trigger citao kao novo prihvatanje svake **nove** verzije uslova bez ijednog klika. **Brava je
-- `do update set` lista ispod: kolone uslova u njoj ne postoje.** Ko ih doda, prijava prihvata
-- uslove umjesto korisnika (pgTAP `030`, sekcija 2, to obara). Ponovno prihvatanje zato ide
-- samo kroz `complete_my_profile`, sa sesijom.
create or replace function private.sync_auth_identity() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_terms boolean := tg_op = 'INSERT'
  and coalesce(new.raw_user_meta_data->>'terms_accepted', '') = 'true';
begin
 insert into public.auth_identities(supabase_user_id,providers,email,email_verified,display_name,
   phone,is_anonymous,last_login_at,terms_version,privacy_version,terms_accepted_at)
 select new.id,
 coalesce(array(select jsonb_array_elements_text(new.raw_app_meta_data->'providers')),array[]::text[]),
 new.email,new.email_confirmed_at is not null,
 coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name'),
 private.clean_phone(new.raw_user_meta_data->>'phone'),
 coalesce(new.is_anonymous,false),coalesce(new.last_sign_in_at,now()),
 case when v_terms then v.terms end, case when v_terms then v.privacy end,
 case when v_terms then now() end
 from public.legal_versions() v
 on conflict(supabase_user_id) do update set
 providers=excluded.providers,email=excluded.email,email_verified=excluded.email_verified,
 display_name=coalesce(excluded.display_name,public.auth_identities.display_name),
 phone=coalesce(excluded.phone,public.auth_identities.phone),
 is_anonymous=excluded.is_anonymous,last_login_at=excluded.last_login_at
 where public.auth_identities.deleted_at is null;
 return new;
end $$;

revoke all on function private.sync_auth_identity() from public;

-- ---------------------------------------------------------------------------
-- 5. Identitet popunjava adresar svakog salona (ADR-0030)
-- ---------------------------------------------------------------------------
-- **Samo prazno se popunjava.** Ime samo preko `'Klijent'` (fallback iz `ensure_customer`) ili
-- praznog, telefon samo preko `NULL`. „Obrisan klijent" nije ni jedno ni drugo, pa
-- anonimiziran red ostaje anoniman.
--
-- **Telefon koji salon vec ima za drugog klijenta se preskace.** `unique(salon_id, phone)`
-- bi inace oborio upis, a time i prijavu koja ga je pokrenula. Isti broj na telefonskom
-- klijentu znaci da je to vjerovatno isti covjek, ali spajanje dva reda je odluka salona iz
-- admin ekrana, ne baze pogadjanjem po broju (v. `upsert_walkin_customer`). Poredi se po
-- ciframa, jer salon i klijent isti broj pisu razlicito.
--
-- `appointments` nosi denormalizovano ime i telefon (v. `security.md`, „Brisanje naloga"), pa
-- se termini popunjavaju po istom pravilu — inace bi detalj termina u Meluri i dalje pisao
-- „Klijent" za svaki termin zakazan prije ovog taska.
create function private.fill_customers_from_identity(p_identity uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_identity public.auth_identities%rowtype;
begin
  select * into v_identity from public.auth_identities i
  where i.id = p_identity and i.deleted_at is null;
  if not found then return; end if;

  update public.customers c
  set name = case when btrim(c.name) in ('', 'Klijent') and private.clean_name(v_identity.display_name) is not null
        then private.clean_name(v_identity.display_name) else c.name end,
      phone = case when c.phone is null and v_identity.phone is not null and not exists (
          select 1 from public.customers d
          where d.salon_id = c.salon_id and d.id <> c.id and d.phone is not null
            and regexp_replace(d.phone, '[^0-9]', '', 'g')
              = regexp_replace(v_identity.phone, '[^0-9]', '', 'g'))
        then v_identity.phone else c.phone end
  where c.auth_identity_id = v_identity.id
    and ((btrim(c.name) in ('', 'Klijent') and private.clean_name(v_identity.display_name) is not null)
      or (c.phone is null and v_identity.phone is not null));

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

create function private.on_identity_profile_change() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform private.fill_customers_from_identity(new.id);
  return new;
end $$;

revoke all on function private.on_identity_profile_change() from public, anon, authenticated;

-- Dva triggera, jer `update of display_name, phone` okida na svaku prijavu: `sync_auth_identity`
-- ima obje kolone u `SET`-u i kad se vrijednost ne mijenja. `when` gleda vrijednost.
create trigger fill_customers_from_identity_insert
after insert on public.auth_identities
for each row execute function private.on_identity_profile_change();

create trigger fill_customers_from_identity_update
after update of display_name, phone on public.auth_identities
for each row
when (old.display_name is distinct from new.display_name or old.phone is distinct from new.phone)
execute function private.on_identity_profile_change();

-- ---------------------------------------------------------------------------
-- 6. `ensure_customer` uzima i telefon identiteta
-- ---------------------------------------------------------------------------
-- Novi red u salonu dobija telefon odmah, osim kad ga u tom salonu vec nosi drugi klijent
-- (isti razlog kao gore). `on conflict (salon_id, auth_identity_id) do nothing` ostaje: drugi
-- poziv i dalje ne prepisuje ime koje je salon ispravio.
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

  insert into public.customers(salon_id, auth_identity_id, name, phone)
  values (p_salon_id, v_identity.id, v_ime, v_phone)
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

revoke all on function public.ensure_customer(uuid, text) from public, anon;
grant execute on function public.ensure_customer(uuid, text) to authenticated;

comment on function public.ensure_customer(uuid, text) is
  'Vraca klijenta prijavljenog korisnika u salonu iz x-salon-id, praveci ga pri prvom pozivu sa imenom i telefonom identiteta (telefon samo ako ga salon vec ne nosi na drugom klijentu). Idempotentna; 42501 kad pozivalac nije klijent tog salona ili nema identitet.';

-- ---------------------------------------------------------------------------
-- 7. Klijentski profil: sta fali i „Dopuni profil"
-- ---------------------------------------------------------------------------
-- Oba RPC-a su po **identitetu**, ne po salonu: profil je osoba, kao kod `delete_my_account`.
-- `x-salon-id` se zato ne trazi — ne bi nista dokazao.
create function public.client_profile_status()
returns table (has_name boolean, has_phone boolean, terms_current boolean)
language plpgsql stable security definer set search_path = '' as $$
declare v_identity public.auth_identities%rowtype;
begin
  if not private.is_client() then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  select * into v_identity from public.auth_identities i
  where i.supabase_user_id = auth.uid() and i.deleted_at is null;
  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  return query
  select private.clean_name(v_identity.display_name) is not null,
    v_identity.phone is not null,
    coalesce(v_identity.terms_version >= v.terms and v_identity.privacy_version >= v.privacy, false)
  from public.legal_versions() v;
end $$;

revoke all on function public.client_profile_status() from public, anon;
grant execute on function public.client_profile_status() to authenticated;

comment on function public.client_profile_status() is
  'Sta klijentskom profilu fali: ime, telefon i prihvatanje vazece verzije uslova (task 66). Po identitetu, bez x-salon-id. 42501 za osoblje i anon.';

-- **Popunjava, ne mijenja.** Ime se upisuje samo kad ga identitet nema (Apple ga daje samo pri
-- prvoj autorizaciji, pa se moze izgubiti); izmjena profila je task 82. Telefon se upisuje
-- uvijek kad je ispravan — ovo je ekran na kojem ga korisnik i daje.
create function public.complete_my_profile(
  p_phone text,
  p_accept_terms boolean,
  p_name text default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_identity public.auth_identities%rowtype;
  v_phone text := private.clean_phone(p_phone);
  v_name text := private.clean_name(p_name);
begin
  if not private.is_client() then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  select * into v_identity from public.auth_identities i
  where i.supabase_user_id = auth.uid() and i.deleted_at is null
  for update;
  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  if v_phone is null then
    raise exception 'Unesite ispravan broj telefona' using errcode = 'PT400';
  end if;
  if p_accept_terms is not true then
    raise exception 'Prihvatite Uslove korištenja i Politiku privatnosti' using errcode = 'PT400';
  end if;
  if private.clean_name(v_identity.display_name) is null and v_name is null then
    raise exception 'Unesite ime i prezime' using errcode = 'PT400';
  end if;

  update public.auth_identities i
  set phone = v_phone,
      display_name = coalesce(private.clean_name(i.display_name), v_name),
      terms_version = v.terms, privacy_version = v.privacy, terms_accepted_at = now()
  from public.legal_versions() v
  where i.id = v_identity.id;
end $$;

revoke all on function public.complete_my_profile(text, boolean, text) from public, anon;
grant execute on function public.complete_my_profile(text, boolean, text) to authenticated;

comment on function public.complete_my_profile(text, boolean, text) is
  'Dopuni profil (task 66): telefon, prihvatanje vazece verzije uslova i ime ako ga identitet nema. Po identitetu; ime i telefon se kroz trigger popunjavaju u adresar svakog salona po ADR-0030. PT400 za neispravan unos, 42501 za osoblje i anon.';

-- ---------------------------------------------------------------------------
-- 8. Brisanje naloga brise i telefon
-- ---------------------------------------------------------------------------
-- `security.md` („Brisanje naloga"): svaka kolona koja nosi licni podatak mora uci u
-- anonimizaciju. Funkcija je ista kao u tasku 17 osim reda `phone = null`.
create or replace function public.delete_my_account()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_identity public.auth_identities%rowtype;
  v_otkazano int := 0;
  v_klijenata int := 0;
  v_termina int := 0;
begin
  -- Identitet se **izvodi iz tokena**, nikad ne stize kao argument — isti razlog kao u
  -- `ensure_customer`: argument bi ovo pretvorio u funkciju kojom se brise tudji nalog.
  select * into v_identity
  from public.auth_identities ai
  where ai.supabase_user_id = auth.uid() and ai.deleted_at is null;

  -- Nepostojeci identitet, vec obrisan nalog i poziv bez tokena vracaju **istu** gresku,
  -- isto kao svuda u repou: razlika bi bila endpoint kojim se nabraja ko postoji.
  --
  -- Osoblje je namjerno iskljuceno. Admin nalog se ne brise kroz klijentsku app — njegov
  -- `public.users` red je salonov podatak i gasi ga salon, ne ekran u app-i. Posljedica
  -- koju treba znati: korisnik koji je istovremeno `salon_admin` ne moze obrisati svoj
  -- klijentski nalog iz app-e. Za MVP je to ispravno, jer taj covjek ima drugi put.
  if not found or not private.is_client() then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- -------------------------------------------------------------------------
  -- 2a. Buduci termini se otkazuju
  -- -------------------------------------------------------------------------
  -- **Rok iz `salon_settings.min_cancel_hours` se ovdje namjerno ne primjenjuje.**
  -- `cancel_appointment` ga primjenjuje i tu je ispravan: klijent koji kasno otkazuje
  -- treba nazvati salon. Ali brisanje naloga se ne smije moci blokirati — Apple trazi da
  -- ono radi, a nalog koji se ne moze obrisati zato sto je termin sutra nije nalog koji
  -- se moze obrisati. Cijena je da salon moze dobiti otkazivanje u zadnji cas; zato
  -- `cancel_reason` kaze **zasto**, a push vlasniku dolazi sa taskom 25.
  --
  -- `cancelled_by = 'customer'`, ne `'system'`: covjek je to pokrenuo. `'system'` je
  -- rezervisan za istekli `pending` koji pise scheduler (`security.md`).
  --
  -- Zidno vrijeme salona, ne UTC — ista zamka kao u `cancel_appointment`: `date` i
  -- `start_time` su bez zone, pa se zona dodaje iz postavki **tog** salona. Klijent u dva
  -- salona moze biti u dvije zone.
  with moji as (
    select c.salon_id, c.id
    from public.customers c
    where c.auth_identity_id = v_identity.id
  )
  update public.appointments a
  set status = 'cancelled',
      cancelled_by = 'customer'::public.cancelled_by,
      cancel_reason = 'Klijent je obrisao nalog',
      updated_at = now()
  from moji m
  left join public.salon_settings s on s.salon_id = m.salon_id
  where a.salon_id = m.salon_id
    and a.customer_id = m.id
    and a.status in ('pending', 'confirmed')
    and (a.date + a.start_time) at time zone coalesce(s.timezone, 'Europe/Sarajevo') > now();

  get diagnostics v_otkazano = row_count;

  -- -------------------------------------------------------------------------
  -- 2b. Licni podaci na samim terminima
  -- -------------------------------------------------------------------------
  -- **Nalaz koji task fajl ne vidi, i bez kojeg je ovaj task pozoriste.**
  -- `appointments` nosi `customer_name`, `customer_phone` i `customer_note` kao
  -- **denormalizovane** kolone, ne samo `customer_id`. Anonimizacija koja dira samo
  -- `customers` ostavlja puno ime i telefon u svakom terminu tog covjeka — obrisan nalog
  -- kojem ime i dalje stoji u salonovoj listi nije obrisan nalog.
  --
  -- Sadrzaj koji salon stvarno treba za evidenciju ostaje netaknut: datum, vrijeme,
  -- usluga, radnik, status, cijena. Odlazi samo ono sto identifikuje osobu.
  update public.appointments a
  set customer_name = 'Obrisan klijent',
      customer_phone = null,
      customer_note = null,
      updated_at = now()
  from public.customers c
  where c.auth_identity_id = v_identity.id
    and a.salon_id = c.salon_id
    and a.customer_id = c.id;

  get diagnostics v_termina = row_count;

  -- -------------------------------------------------------------------------
  -- 2c. Klijentski redovi
  -- -------------------------------------------------------------------------
  -- Red **ostaje**, zajedno sa `visit_count`, `no_show_count` i `first_seen_at`: to je
  -- salonova evidencija, a ne korisnikov podatak. Odlazi ono sto imenuje osobu.
  --
  -- Dvije zamke koje šema namece:
  --   - `name` je `not null`, pa mora dobiti tekst, ne `NULL`;
  --   - `unique(salon_id, phone)` znaci da `phone` mora ici na **`NULL`**, a ne na neku
  --     konstantu — druga anonimizacija u istom salonu bi inace pala na unique. Postgres
  --     dozvoljava vise `NULL`-ova u unique indeksu, konstanta bi bila druga prica.
  --
  -- `auth_identity_id` se **ne** postavlja na NULL: veza je ono sto `own_customer`
  -- politika koristi, a kad identitet dobije `deleted_at`, ta politika vise ne prolazi.
  -- Kidanje veze bi umjesto toga napravilo red bez vlasnika, koji bi admin mogao spojiti
  -- sa novim nalogom istog covjeka.
  update public.customers c
  set name = 'Obrisan klijent',
      phone = null,
      note = null
  where c.auth_identity_id = v_identity.id;

  get diagnostics v_klijenata = row_count;

  -- -------------------------------------------------------------------------
  -- 2d. Identitet
  -- -------------------------------------------------------------------------
  -- `deleted_at` je ono sto stvarno gasi pristup (v. tacku 2). Uz njega se brisu i
  -- `email`, `display_name` i `providers` — bez toga bi soft-delete ostavio mail adresu
  -- zauvijek, a "obrisan nalog" koji i dalje zna tvoj mail nije obrisan nalog.
  --
  -- `supabase_user_id` se namjerno **zadrzava**: dok `auth.users` red postoji, on je
  -- jedino sto sprjecava da trigger napravi **novi** identitet za istog korisnika i time
  -- ga vrati u zivot. Kad Edge Function obrise `auth.users`, FK `on delete set null` ga
  -- sam pretvori u NULL i oslobodi unique — pa sljedeca prijava istim mailom dobije
  -- cist, nov nalog.
  update public.auth_identities ai
  set deleted_at = now(),
      email = null,
      display_name = null,
      -- Task 66: telefon je nov licni podatak na identitetu. Prihvatanje uslova (verzija i
      -- vrijeme) ostaje — to je zapis o pristanku, ne podatak o osobi.
      phone = null,
      providers = array[]::text[]
  where ai.id = v_identity.id;

  return jsonb_build_object(
    'identity_id', v_identity.id,
    'cancelled_appointments', v_otkazano,
    'anonymized_appointments', v_termina,
    'anonymized_customers', v_klijenata
  );
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ---------------------------------------------------------------------------
-- 9. Postojeci „Klijent" redovi
-- ---------------------------------------------------------------------------
-- Google i Apple korisnici vec imaju ime na identitetu, a u adresaru stoje kao „Klijent" jer
-- `ensure_customer` nije dobijao ime. Jedan prolaz ih popuni po istom pravilu.
select private.fill_customers_from_identity(i.id)
from public.auth_identities i
where i.deleted_at is null and (i.display_name is not null or i.phone is not null);
