-- Task 36: salon mijenja svoje podatke i booking pravila bez novog builda i bez nas.
--
-- Do sada je vlasnik salona mogao promijeniti **postavke** direktnim `update`-om (init
-- migracija daje `staff_manage` nad `salon_settings` i pun grant), ali **kontakt podatke
-- nije mogao uopste**: nad `salons` stoje samo `public_salons`, `staff_salons` (oba
-- `select`) i `super_salons`. Ime, adresa i telefon salona su zato bili podatak koji
-- mijenjamo mi, a cilj taska je suprotan.
--
-- Oba puta se ovdje zatvaraju u `rpc`, kao sto je task 24 zatvorio `appointments`, 33
-- `employees`, a 34 `working_hours`.

-- ---------------------------------------------------------------------------
-- Grant se oduzima, kao i na ostalim tabelama koje admin mijenja kroz `rpc`
-- ---------------------------------------------------------------------------
-- `salons` nikad nije ni imao politiku pisanja za vlasnika, pa je grant bio mrtav; oduzima
-- se da red iz init migracije ne izgleda kao dozvola koja ceka politiku.
--
-- Nad `salon_settings` grant **jeste** bio ziv i `staff_manage` ga je pustao. Ostavljen bi
-- znacio da postoje dva puta do istog reda, od kojih jedan (direktan `update`) ne prolazi
-- kroz nijednu validaciju ispod — vlasnik bi mogao upisati `min_cancel_hours = 0` zajedno
-- sa `booking_mode` koji RPC ne bi primio.
revoke insert, update, delete on public.salons, public.salon_settings
  from authenticated;

-- `staff_manage` nad `salon_settings` je bio `for all`; poslije oduzetog granta `insert`,
-- `update` i `delete` grane nemaju sta da pokrivaju, ali politika koja tvrdi vise nego sto
-- grant dopusta je politika koju sljedeci citalac pogresno procita. Suzava se na `select`,
-- koji je jedini razlog zasto i postoji: vlasnik mora vidjeti svoje postavke i kad salon
-- nije aktivan (`public_active` tada ne vrati red).
drop policy staff_manage on public.salon_settings;
create policy staff_read on public.salon_settings
  for select to authenticated
  using (private.is_admin(salon_id));

-- ---------------------------------------------------------------------------
-- Kontakt podaci salona
-- ---------------------------------------------------------------------------
-- **Kolone su nabrojane, ne prosljedjene kroz.** `salons` je najsira tabela u semi i nosi
-- `status`, `plan`, `vertical_pack_key`, `slug`, `terminology_override` i boje — sve
-- platformski podaci. Funkcija koja bi primila red i spojila ga preko postojeceg dala bi
-- vlasniku put do svih njih.
--
-- **Boje i logo ovdje namjerno nisu.** Branding dolazi iz `tenant.yaml` kroz generator
-- (`.claude/docs/tenant-factory.md`); polje u adminu bi napravilo drugi izvor istine za
-- isti podatak, i build bi ga vratio na staro pri sljedecem generisanju.
--
-- `facebook_url` je **stranica salona kao kontakt**, ne prijava Facebookom — ta ne postoji
-- (`docs/adr/0011-facebook-login-se-ne-implementira.md`).
create function public.update_salon_contact(
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
declare v_row public.salons%rowtype;
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Naziv i grad su jedina dva obavezna polja: naziv stoji u zaglavlju klijentske app-e, a
  -- grad je jedini podatak po kojem se lokacija razlikuje od druge istog brenda. Adresa
  -- smije biti prazna (salon koji radi na vise adresa je stvarna pojava), ali `not null`
  -- kolona ne smije dobiti `null`, pa se prazno pise kao prazan string.
  if length(btrim(coalesce(p_name, ''))) = 0 then
    raise exception 'Naziv je obavezan' using errcode = 'PT400';
  end if;
  if length(btrim(coalesce(p_city, ''))) = 0 then
    raise exception 'Grad je obavezan' using errcode = 'PT400';
  end if;

  -- Prazan unos iz forme stize kao prazan string, a nullable kolone (`phone`, `email`,
  -- linkovi) treba da nose `null` — inace "nema telefona" i "telefon je prazan string"
  -- postanu dva stanja koja ekran mora razlikovati, a znace isto.
  update public.salons s set
    name = btrim(p_name),
    address = btrim(coalesce(p_address, '')),
    city = btrim(p_city),
    description = btrim(coalesce(p_description, '')),
    phone = nullif(btrim(coalesce(p_phone, '')), ''),
    email = nullif(btrim(coalesce(p_email, '')), ''),
    instagram_url = nullif(btrim(coalesce(p_instagram_url, '')), ''),
    facebook_url = nullif(btrim(coalesce(p_facebook_url, '')), '')
  where s.id = p_salon_id
  returning * into v_row;

  -- `is_admin` je vec prosao, pa ovdje salona nema samo ako je red u medjuvremenu nestao.
  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  return v_row;
end;
$fn$;

comment on function public.update_salon_contact(uuid, text, text, text, text, text, text, text, text) is
  'Kontakt podaci salona iz admina. Branding, plan, status i slug ostaju platformski.';

-- ---------------------------------------------------------------------------
-- Booking pravila
-- ---------------------------------------------------------------------------
-- Ista logika nabrajanja: `auth_providers`, `timezone` i `language` se ovdje ne diraju.
-- Prva je platformska (koji login postoji u buildu), druge dvije mijenjaju znacenje **svih**
-- vec upisanih `time` vrijednosti u `working_hours` i `appointments` — promjena zone nije
-- postavka nego migracija podataka.
--
-- **Validacija ponavlja `check` constraint iz init migracije, i to je namjerno.** Constraint
-- ostaje jedini koji obavezuje; ova provjera postoji samo da greska stigne kao recenica uz
-- polje koje je krivo, umjesto kao `23514` sa imenom constrainta.
create function public.update_salon_settings(
  p_salon_id uuid,
  p_booking_mode text,
  p_booking_granularity text,
  p_buffer_minutes int,
  p_slot_step_minutes int,
  p_min_advance_booking_hours int,
  p_max_advance_booking_days int,
  p_min_cancel_hours int,
  p_require_staff_choice boolean,
  p_show_prices_in_app boolean,
  p_allow_guest_booking boolean
) returns public.salon_settings language plpgsql security definer set search_path = '' as $fn$
declare v_row public.salon_settings%rowtype;
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  if p_booking_mode not in ('manual', 'auto') then
    raise exception 'Nepoznat nacin potvrde' using errcode = 'PT400';
  end if;
  if p_booking_granularity not in ('exact_slot', 'date_only') then
    raise exception 'Nepoznata granularnost' using errcode = 'PT400';
  end if;
  if p_buffer_minutes is null or p_buffer_minutes not between 0 and 120 then
    raise exception 'Pauza izmedju termina mora biti 0-120 minuta' using errcode = 'PT400';
  end if;
  if p_slot_step_minutes is null or p_slot_step_minutes not between 1 and 120 then
    raise exception 'Korak termina mora biti 1-120 minuta' using errcode = 'PT400';
  end if;
  if p_min_advance_booking_hours is null or p_min_advance_booking_hours < 0 then
    raise exception 'Najraniji termin ne moze biti negativan' using errcode = 'PT400';
  end if;
  if p_max_advance_booking_days is null or p_max_advance_booking_days <= 0 then
    raise exception 'Kalendar mora biti otvoren bar jedan dan unaprijed' using errcode = 'PT400';
  end if;
  if p_min_cancel_hours is null or p_min_cancel_hours < 0 then
    raise exception 'Rok otkazivanja ne moze biti negativan' using errcode = 'PT400';
  end if;

  update public.salon_settings st set
    booking_mode = p_booking_mode,
    booking_granularity = p_booking_granularity,
    buffer_minutes = p_buffer_minutes,
    slot_step_minutes = p_slot_step_minutes,
    min_advance_booking_hours = p_min_advance_booking_hours,
    max_advance_booking_days = p_max_advance_booking_days,
    min_cancel_hours = p_min_cancel_hours,
    require_staff_choice = coalesce(p_require_staff_choice, false),
    show_prices_in_app = coalesce(p_show_prices_in_app, true),
    allow_guest_booking = coalesce(p_allow_guest_booking, false)
  where st.salon_id = p_salon_id
  returning * into v_row;

  if not found then
    raise exception 'Salon nema red u salon_settings' using errcode = 'PT404';
  end if;
  return v_row;
end;
$fn$;

comment on function public.update_salon_settings(uuid, text, text, int, int, int, int, int, boolean, boolean, boolean) is
  'Booking pravila salona iz admina. Zona, jezik i auth provideri ostaju platformski.';

-- ---------------------------------------------------------------------------
-- Salonske sekcije pravila
-- ---------------------------------------------------------------------------
-- **`app_policies` se ovdje ne dira, i to je cijela odluka ADR-0009.** Zakazivanje, Cijene
-- i "Vasi podaci" obavezuju firmu pod cijim imenom app stoji u storeu; `super_manage` ih
-- drzi, a `007_policies.test.sql` pada ako se to oslabi na `private.is_admin(...)`.
--
-- Nad `salon_policies` `staff_manage` vec daje CRUD i grant stoji uz njega, pa se tabela
-- **ne zatvara u rpc**. Razlog nije nedosljednost nego to sto ovdje nema sta da se validira
-- mimo `check` constrainta koji vec stoje (`sort_order > 0`, neprazan naslov i tijelo):
-- funkcija bi bila prosljedjivanje bez ijednog pravila, a to je sloj koji sakriva politiku
-- umjesto da je pojaca. Zapisano u `security.md` da sljedeci citalac ne trazi rpc kojeg nema.

-- ---------------------------------------------------------------------------
-- Grantovi
-- ---------------------------------------------------------------------------
revoke all on function public.update_salon_contact(uuid, text, text, text, text, text, text, text, text)
  from public, anon, authenticated;
revoke all on function public.update_salon_settings(uuid, text, text, int, int, int, int, int, boolean, boolean, boolean)
  from public, anon, authenticated;

grant execute on function public.update_salon_contact(uuid, text, text, text, text, text, text, text, text)
  to authenticated;
grant execute on function public.update_salon_settings(uuid, text, text, int, int, int, int, int, boolean, boolean, boolean)
  to authenticated;
