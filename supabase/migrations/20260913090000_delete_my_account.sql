-- Brisanje naloga: soft-delete identiteta + anonimizacija klijenta. Task 17.
--
-- Zatvara zadnju stavku iz `.claude/docs/security.md`, "Sta jos nije zatvoreno"
-- ("Brisanje/anonimizacija naloga dolazi u kasnijoj migraciji").
--
-- Cetvrti upis kojim klijentska app dira bazu, uz `book_appointment`, `ensure_customer`
-- i `cancel_appointment`. Apple trazi da brisanje naloga bude **u aplikaciji**, ne link
-- na mail podrske (`docs/06 §8.2`) — bez ovoga iOS submission pada.
--
-- **Ovo je prvi i jedini upis koji namjerno prelazi granicu salona.** Sve ostalo u repou
-- je tenant-scoped; identitet nije. Isti covjek moze biti klijent u vise salona — task 15
-- to dokazuje — a brisanje naloga je odluka o **osobi**, ne o jednom salonu. Kad bi
-- funkcija radila samo nad salonom iz `x-salon-id`, korisnik bi obrisao nalog i njegovo
-- ime bi ostalo u drugom salonu, bez ijednog ekrana s kojeg bi to mogao ponoviti.
--
-- Granica je zato pomjerena sa salona na **identitet**: funkcija dira iskljucivo redove
-- vezane za `auth_identities` red pozivaoca. `x-salon-id` se namjerno **ne trazi** — ne bi
-- nista dokazao, a sugerisao bi salon-scoped operaciju koja ovo nije.

-- ---------------------------------------------------------------------------
-- 1. Zasto RPC, a ne `auth.admin.deleteUser` iz app-e
-- ---------------------------------------------------------------------------
-- `auth.admin.deleteUser` je admin API i radi samo sa service role kljucem, koji nikad ne
-- smije u klijentsku app (`security.md`, "Tajne"). Brisanje je zato dvokoracno:
--
--   1. ova funkcija — soft-delete identiteta i anonimizacija, pod tokenom korisnika;
--   2. Edge Function — `auth.admin.deleteUser` nad `auth.users`, pod service role kljucem.
--
-- **Tim redom, ne obrnuto.** Kad bi prvo isao `auth.users`, pad drugog koraka bi ostavio
-- `customers` red sa punim imenom i telefonom, bez ijednog nacina da korisnik ponovi
-- brisanje — njegov token vise ne postoji. Ovako pad drugog koraka ostavlja nalog koji je
-- **vec neupotrebljiv** (v. tacku 2), pa je najgori ishod siroce u `auth.users`, ne
-- zaostali licni podatak.

-- ---------------------------------------------------------------------------
-- 2. Zasto je sam `deleted_at` dovoljan da ugasi pristup
-- ---------------------------------------------------------------------------
-- Gate je usiven od init migracije (task 02) i ne treba mu nijedna nova politika:
--
--   `private.owns_identity`            -> `... and deleted_at is null`
--   politika `own_identity`            -> `... and deleted_at is null`
--   politika `own_customer`            -> kroz `owns_identity`
--   politika `own_appointments`        -> kroz `owns_identity`
--   `public.ensure_customer` (task 14) -> `ai.deleted_at is null`
--   trigger `sync_auth_identity`       -> upsert samo `where deleted_at is null`
--
-- Trigger je ovdje najvazniji: bez `where deleted_at is null` bi sljedeca prijava istim
-- mailom **uskrsnula** obrisani nalog kroz `on conflict do update`.
--
-- To je i dalje **hipoteza dok pgTAP i Deno test ne prodju**, ne razlog da se test
-- preskoci (`security.md`: politika bez negativnog testa je pretpostavka).

create function public.delete_my_account()
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

comment on function public.delete_my_account() is
  'Brise nalog pozivaoca: otkazuje buduce termine, anonimizira customers i appointments redove u svim salonima, i soft-delete-a identitet (deleted_at). Identitet se izvodi iz tokena; 42501 kad pozivalac nije klijent ili nema identitet. Drugi korak (auth.admin.deleteUser) radi Edge Function.';

-- ---------------------------------------------------------------------------
-- 3. Grantovi
-- ---------------------------------------------------------------------------
-- `from public, anon`, ne samo `from public`: Supabase kroz `pg_default_acl` daje
-- `execute` na nove funkcije u `public` shemi **direktno** roli `anon`, ne kroz `PUBLIC`,
-- pa revoke od `PUBLIC` ne skida nista (`security.md`, nadjeno u tasku 14).
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
