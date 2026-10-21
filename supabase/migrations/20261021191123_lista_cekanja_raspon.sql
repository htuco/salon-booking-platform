-- Task 91: lista cekanja sa rasponom do prvog slobodnog termina (ADR-0031, dopuna 2026-10-21).
--
-- Upis vise nije jedan pun dan nego **raspon**: od izabranog dana (ili danas) do dana prije
-- prvog slobodnog termina za uslugu i radnika. Raspon racuna baza, istim pravilom slotova
-- (`private.candidate_slots`), a klijent ga ne salje. Kad otkazivanje bilo kojeg dana u rasponu
-- otvori vrijeme za uslugu i radnika upisa, ponuda ide kao i do sada (task 68).
--
-- Sta se mijenja u odnosu na `20261020140000_lista_cekanja.sql` (ta migracija se ne dira):
--
--   1. `waitlist_entries.date` postaje `date_from` + `date_to`. Postojeci upis je raspon od
--      jednog dana. Jedan upis po (salon, identitet, usluga, radnik), a ne po danu.
--   2. Ponuda pamti **dan koji se oslobodio** (`notification_logs.waitlist_offer_date`). Upis
--      vise nema jedan dan, a istorija obavijesti mora reci koji. Kolonu pise okidac, a
--      `claim_push_notifications` je ne cita, pa se ta funkcija ovdje ne redefinise (task 56 je
--      redefinise u svojoj migraciji).
--   3. `join_waitlist(service, employee, from)` vraca upis sa rasponom; `my_waitlist` vraca
--      raspon. Oba mijenjaju potpis, pa idu kroz `drop` + `create` (bez paralelnog
--      preopterecenja, `security.md`).
--   4. Upis istice kad prode zadnji dan: svaki citac ga filtrira odmah, a `expire-waitlist`
--      (pg_cron, svaki sat) ga brise zajedno sa ponudama. Prosli dani otpadaju sa pocetka pri
--      citanju; red se zbog toga ne prepisuje.
--
-- Sta ostaje isto: tabela bez app grantova, push svima kojima je bas to otkazivanje otvorilo
-- vrijeme (isti radnik, preklapanje `span`-a), jedna ponuda po klijentu, bez drzanja termina,
-- salon vidi samo broj. `waitlist_full_dates` je nepromijenjen: i dalje kaze koji je dan pun.

-- ---------------------------------------------------------------------------
-- 1. Raspon umjesto dana
-- ---------------------------------------------------------------------------
alter table public.waitlist_entries
  add column date_from date,
  add column date_to date;

update public.waitlist_entries set date_from = date, date_to = date;

-- Dan ponude za postojece ponude je dan njihovog upisa: do sada je upis imao samo jedan dan.
alter table public.notification_logs add column waitlist_offer_date date;

update public.notification_logs n
set waitlist_offer_date = w.date
from public.waitlist_entries w
where w.salon_id = n.salon_id and w.id = n.waitlist_entry_id;

-- Jedinstvenost vise ne ukljucuje dan. Isti klijent je mogao cekati istu uslugu kod istog
-- radnika na vise dana (tri reda); takvi redovi postaju **jedan** upis od najranijeg do
-- najkasnijeg dana. Nijedna ponuda se ne gubi: ponude ostalih redova prelaze na upis koji ostaje
-- (`on delete cascade` bi ih inace obrisao). Od vise ponuda koje bi istom uredjaju cekale slanje
-- ostaje jedna (parcijalni `unique`), a ostale se zatvaraju kao `logged` sa razlogom, kao da ih
-- je worker spojio — isto pravilo „jedna ponuda po klijentu".
create temporary table waitlist_spoj as
select
  w.id,
  first_value(w.id) over g as ostaje,
  min(w.date) over k as od,
  max(w.date) over k as do_dana
from public.waitlist_entries w
window
  g as (partition by w.salon_id, w.auth_identity_id, w.service_id, w.employee_id
        order by w.date, w.created_at, w.id),
  k as (partition by w.salon_id, w.auth_identity_id, w.service_id, w.employee_id);

update public.waitlist_entries w
set date_from = s.od, date_to = s.do_dana
from waitlist_spoj s
where s.id = w.id and s.ostaje = w.id;

update public.notification_logs n
set status = 'logged', error = 'waitlist_merged'
from (
  select n2.id,
    row_number() over (
      partition by s.ostaje, n2.device_id
      order by (n2.waitlist_entry_id = s.ostaje) desc, n2.created_at, n2.id
    ) as rb
  from public.notification_logs n2
  join waitlist_spoj s on s.id = n2.waitlist_entry_id
  where n2.status = 'queued'
) v
where v.id = n.id and v.rb > 1;

update public.notification_logs n
set waitlist_entry_id = s.ostaje
from waitlist_spoj s
where s.id = n.waitlist_entry_id and s.ostaje <> s.id;

delete from public.waitlist_entries w
using waitlist_spoj s
where s.id = w.id and s.ostaje <> w.id;

drop table waitlist_spoj;

alter table public.waitlist_entries drop constraint waitlist_entries_jedan_upis;
-- `waitlist_entries_dan_idx` pada sa kolonom.
alter table public.waitlist_entries drop column date;

alter table public.waitlist_entries
  alter column date_from set not null,
  alter column date_to set not null,
  add constraint waitlist_entries_raspon check (date_from <= date_to);

-- Ista usluga kod istog radnika je jedan upis, i „Bilo ko" (NULL) takodje. Novi raspon za isti
-- kljuc ne nastaje dok stari vazi: granica se ne pomjera (task 91, zamke).
alter table public.waitlist_entries
  add constraint waitlist_entries_jedan_upis
    unique nulls not distinct (salon_id, auth_identity_id, service_id, employee_id);

create index waitlist_entries_kraj_idx on public.waitlist_entries (salon_id, date_to);

comment on table public.waitlist_entries is
  'Lista cekanja (task 68 i 91, ADR-0031): klijent ceka da se u rasponu [date_from, date_to] oslobodi mjesto za uslugu, opcionalno kod radnika. date_to je dan prije prvog slobodnog termina u trenutku upisa (ili kraj prozora rezervacije). Nema app grantova; pise i cita se samo kroz RPC.';

-- Red ponude nosi dan, red termina ne. Stari redovi su popunjeni iznad.
alter table public.notification_logs
  add constraint notification_logs_dan_ponude
    check ((waitlist_entry_id is null) = (waitlist_offer_date is null));

comment on column public.notification_logs.waitlist_offer_date is
  'Dan koji je otkazivanje oslobodilo, samo za ponudu liste cekanja (task 91). Pise ga okidac queue_waitlist_offers; my_notifications ga vraca kao date ponude.';

-- ---------------------------------------------------------------------------
-- 2. Upis racuna raspon
-- ---------------------------------------------------------------------------
drop function public.join_waitlist(uuid, date, uuid);

-- Raspon pocinje izabranim danom (ili danas) i ide do dana prije prvog dana koji ima slobodnog
-- vremena za uslugu i radnika. Nema slobodnog do kraja prozora → raspon do kraja prozora.
-- „Ima slobodnog" je `candidate_slots` sa terminima, isto pitanje koje postavlja
-- `get_available_dates`, pa „Prvi slobodan termin" u aplikaciji i granica ovdje ne mogu
-- reci dvije razlicite stvari.
--
-- Odbija se (PT400):
--   * prvi dan ima slobodnog vremena — tada se zakazuje, ne ceka;
--   * u rasponu nema nijednog punog dana (dan koji radi, a popunjen je): neaktivna usluga ili
--     radnik, sve zatvoreni dani, dan van prozora. Upis bez punog dana bi cekao obavijest koja
--     nikad ne stigne;
--   * salon zakazuje samo dan (`date_only`): tamo nema vremena koje bi se oslobodilo (task 68).
--
-- Postojeci upis za istu uslugu i radnika se vraca neizmijenjen: granica se ne pomjera ni kad
-- se kasnije oslobodi nesto ranije (to je ponuda), ni kad se granicni termin zauzme.
create function public.join_waitlist(
  p_service_id uuid,
  p_employee_id uuid default null,
  p_from date default null
) returns table (id uuid, date_from date, date_to date)
language plpgsql security definer set search_path = '' as $$
declare
  v_salon uuid;
  v_identity uuid;
  v_today date;
  v_kraj date;
  v_granularity text;
  v_od date;
  v_dan date;
  v_pun boolean := false;
  v_upis public.waitlist_entries;
begin
  -- `NULL` se hvata prvi (`security.md`, zamka 1): bez headera je `client_salon_id()` NULL.
  v_salon := private.client_salon_id();
  if private.is_client() is not true or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Identitet iz tokena, nikad iz argumenta. `for update` zakljucava brojanje ispod: dva
  -- istovremena upisa istog klijenta ne prodju oba preko limita.
  select ai.id into v_identity
  from public.auth_identities ai
  where ai.supabase_user_id = auth.uid() and ai.deleted_at is null
  for update;
  if v_identity is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  select (now() at time zone st.timezone)::date,
         (now() at time zone st.timezone)::date + st.max_advance_booking_days,
         st.booking_granularity
    into v_today, v_kraj, v_granularity
  from public.salon_settings st where st.salon_id = v_salon;

  -- Istekao upis klijenta ne smije blokirati novi za isti kljuc dok ga cron ne pokupi.
  delete from public.waitlist_entries w
  where w.salon_id = v_salon and w.auth_identity_id = v_identity and w.date_to < v_today;

  -- Ponovljen upis vraca isti red i ne broji se u limit: dva tapa nisu dva upisa.
  select w.* into v_upis
  from public.waitlist_entries w
  where w.salon_id = v_salon and w.auth_identity_id = v_identity
    and w.service_id = p_service_id
    and w.employee_id is not distinct from p_employee_id;
  if found then
    return query select v_upis.id, greatest(v_upis.date_from, v_today), v_upis.date_to;
    return;
  end if;

  if v_granularity is distinct from 'exact_slot' then
    raise exception 'Ovaj salon nema listu čekanja' using errcode = 'PT400';
  end if;

  v_od := coalesce(p_from, v_today);
  if p_service_id is null or v_od < v_today or v_od > v_kraj then
    raise exception 'Na ovaj dan se ne možete upisati na listu čekanja' using errcode = 'PT400';
  end if;

  v_dan := v_od;
  while v_dan <= v_kraj loop
    exit when exists (
      select 1 from private.candidate_slots(v_salon, p_service_id, v_dan, p_employee_id, false, true));
    if not v_pun then
      v_pun := exists (
        select 1 from private.candidate_slots(v_salon, p_service_id, v_dan, p_employee_id, false, false));
    end if;
    v_dan := v_dan + 1;
  end loop;

  if v_dan = v_od then
    raise exception 'Na ovaj dan ima slobodnog vremena. Zakažite ga umjesto liste čekanja.'
      using errcode = 'PT400';
  end if;
  if not v_pun then
    raise exception 'Na ove dane se ne možete upisati na listu čekanja' using errcode = 'PT400';
  end if;

  if (select count(*) from public.waitlist_entries w
      where w.salon_id = v_salon and w.auth_identity_id = v_identity
        and w.date_to >= v_today) >= 3 then
    raise exception 'Već imate tri upisa na listi čekanja. Odjavite jedan da biste se upisali na novi.'
      using errcode = 'PT429';
  end if;

  -- Petlja koja izadje bez slobodnog dana stane na `v_kraj + 1`, pa je `v_dan - 1` u oba
  -- slucaja zadnji dan raspona.
  insert into public.waitlist_entries
    (salon_id, auth_identity_id, service_id, employee_id, date_from, date_to)
  values (v_salon, v_identity, p_service_id, p_employee_id, v_od, v_dan - 1)
  returning * into v_upis;

  return query select v_upis.id, v_upis.date_from, v_upis.date_to;
end $$;

revoke all on function public.join_waitlist(uuid, uuid, date) from public, anon;
grant execute on function public.join_waitlist(uuid, uuid, date) to authenticated;

comment on function public.join_waitlist(uuid, uuid, date) is
  'Klijent se u salonu iz x-salon-id upisuje na listu cekanja za uslugu i opcionalno radnika, od p_from (ili danas) do dana prije prvog slobodnog termina (ili kraja prozora). Vraca upis sa rasponom. Idempotentno po (usluga, radnik): postojeci upis se vraca neizmijenjen. PT400 kad je prvi dan slobodan, u rasponu nema punog dana, dan je van prozora ili salon zakazuje samo dan; PT429 za cetvrti aktivan upis; 42501 za osoblje, anon i bez konteksta.';

-- ---------------------------------------------------------------------------
-- 3. Citanje
-- ---------------------------------------------------------------------------
drop function public.my_waitlist();

create function public.my_waitlist()
returns table (
  id uuid,
  service_id uuid,
  service_name text,
  employee_id uuid,
  employee_name text,
  date_from date,
  date_to date,
  created_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
declare v_salon uuid;
begin
  v_salon := private.client_salon_id();
  if private.is_client() is not true or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Istekao upis se ne vraca, a prosli dani otpadaju sa pocetka raspona.
  return query
  select w.id, w.service_id, sv.name, w.employee_id, e.name,
    greatest(w.date_from, (now() at time zone st.timezone)::date), w.date_to, w.created_at
  from public.waitlist_entries w
  join public.salon_settings st on st.salon_id = w.salon_id
  join public.services sv on sv.salon_id = w.salon_id and sv.id = w.service_id
  left join public.employees e on e.salon_id = w.salon_id and e.id = w.employee_id
  where w.salon_id = v_salon
    and private.owns_identity(w.auth_identity_id)
    and w.date_to >= (now() at time zone st.timezone)::date
  order by w.date_to, w.created_at;
end $$;

revoke all on function public.my_waitlist() from public, anon;
grant execute on function public.my_waitlist() to authenticated;

comment on function public.my_waitlist() is
  'Aktivni upisi pozivaoca na listu cekanja u salonu iz x-salon-id, sa rasponom od danas (prosli dani otpadaju) do date_to. 42501 za osoblje, anon i bez konteksta.';

-- Isti potpis kao u tasku 68. Upis se broji na svaki dan koji pokriva, i dalje kao broj
-- razlicitih identiteta: klijent sa „Bilo ko" i „kod Emira" na isti dan je jedan.
create or replace function public.waitlist_demand(p_salon_id uuid, p_from date, p_to date)
returns table (date date, waiting integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if private.is_admin(p_salon_id) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 62 then
    raise exception 'Neispravan raspon' using errcode = 'PT400';
  end if;

  return query
  select d.dan, count(distinct w.auth_identity_id)::int
  from public.salon_settings st
  cross join lateral (
    select gs::date as dan
    from generate_series(
      greatest(p_from, (now() at time zone st.timezone)::date), p_to, interval '1 day') gs
  ) d
  join public.waitlist_entries w
    on w.salon_id = st.salon_id
   and d.dan between w.date_from and w.date_to
  where st.salon_id = p_salon_id
  group by d.dan
  order by d.dan;
end $$;

comment on function public.waitlist_demand(uuid, date, date) is
  'Broj klijenata koji cekaju po danu (od danas), za admina salona. Upis se broji na svaki dan svog raspona. Najvise 63 dana. 42501 za ne-admina, PT400 za neispravan raspon.';

-- Isti potpis kao u tasku 70 i 68. Ponuda nosi dan koji se oslobodio, ne raspon upisa.
create or replace function public.my_notifications(p_limit integer default 50)
returns table (
  appointment_id uuid,
  type text,
  created_at timestamptz,
  read boolean,
  service_name text,
  employee_name text,
  date date,
  start_time time
)
language plpgsql stable security definer set search_path = '' as $$
declare v_salon uuid;
begin
  v_salon := private.client_salon_id();
  if not private.is_client() or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  return query
  select d.appointment_id, d.type, d.created_at, d.read,
    d.service_name, d.employee_name, d.date, d.start_time
  from (
    select n.appointment_id, n.type::text as type,
      min(n.created_at) as created_at,
      bool_and(n.read_at is not null) as read,
      a.service_name, a.employee_name, a.date, a.start_time
    from public.notification_logs n
    join public.appointments a on a.salon_id = n.salon_id and a.id = n.appointment_id
    join public.devices dv on dv.salon_id = n.salon_id and dv.id = n.device_id
    where n.salon_id = v_salon
      and a.auth_identity_id is not null
      and private.owns_identity(a.auth_identity_id)
      and dv.staff_user_id is null
    group by n.appointment_id, n.type, a.service_name, a.employee_name, a.date, a.start_time
    union all
    -- Jedna stavka po ponudi, ne po upisu: dva oslobadjanja u rasponu su dvije vijesti, svaka
    -- sa svojim danom. Redovi jedne ponude na vise uredjaja nastaju u istoj transakciji, pa
    -- dijele `created_at`.
    select null::uuid, n.type::text,
      n.created_at,
      bool_and(n.read_at is not null),
      sv.name, e.name, n.waitlist_offer_date, null::time
    from public.notification_logs n
    join public.waitlist_entries w on w.salon_id = n.salon_id and w.id = n.waitlist_entry_id
    join public.services sv on sv.salon_id = w.salon_id and sv.id = w.service_id
    left join public.employees e on e.salon_id = w.salon_id and e.id = w.employee_id
    join public.devices dv on dv.salon_id = n.salon_id and dv.id = n.device_id
    where n.salon_id = v_salon
      and private.owns_identity(w.auth_identity_id)
      and dv.staff_user_id is null
    group by w.id, n.type, n.created_at, sv.name, e.name, n.waitlist_offer_date
  ) d
  order by d.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
end $$;

comment on function public.my_notifications(integer) is
  'Obavijesti klijenta u salonu iz x-salon-id: jedna stavka po (termin, tip) i po ponudi liste cekanja, najnovije prve, sa oznakom procitanog. Samo termini i upisi ciji je identitet pozivaoca i samo redovi poslani klijentskim uredjajima. Ponuda nema appointment_id ni start_time, a date je dan koji se oslobodio. 42501 za osoblje, anon i bez konteksta.';

-- ---------------------------------------------------------------------------
-- 4. Okidaci
-- ---------------------------------------------------------------------------
-- Kao u tasku 68, uz jednu razliku: upis se budi kad dan otkazanog termina pada u njegov
-- raspon, a slobodan slot se trazi **tog dana**. Prosli dani se ne nude: `candidate_slots` za
-- prosli dan ne vraca nista, a za danas ne vraca vrijeme koje je proslo. Ponuda pamti dan.
create or replace function private.queue_waitlist_offers() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notification_logs
    (salon_id, waitlist_entry_id, device_id, type, waitlist_offer_date)
  select u.salon_id, u.id, d.id, 'waitlist_offer'::public.notification_type, new.date
  from (
    select distinct on (w.auth_identity_id) w.salon_id, w.id, w.auth_identity_id
    from public.waitlist_entries w
    where w.salon_id = new.salon_id
      and new.date between w.date_from and w.date_to
      and exists (
        select 1
        from private.candidate_slots(
          w.salon_id, w.service_id, new.date, w.employee_id, false, true) s
        where (old.employee_id is null or s.employee_id = old.employee_id)
          and s.span && tsrange(
                old.date + old.start_time,
                old.date + old.end_time + make_interval(mins => old.buffer_minutes))
      )
    order by w.auth_identity_id, w.created_at, w.id
  ) u
  join public.devices d
    on d.salon_id = u.salon_id
   and d.staff_user_id is null
   and d.auth_identity_id = u.auth_identity_id
   and d.fcm_token is not null
  on conflict (waitlist_entry_id, device_id)
    where waitlist_entry_id is not null and status = 'queued'
    do nothing;
  return new;
end $$;

-- Potvrden termin iste usluge **bilo koji dan u rasponu** gasi upis (bilo koji radnik, kao u
-- 68). Termin na prvi slobodan dan (`date_to + 1`) ga ne gasi: to je granica, a klijent koji je
-- zakazao prvi slobodan termin i dalje ceka da se oslobodi ranije. `pending` i dalje ne gasi.
create or replace function private.close_waitlist_entry() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.waitlist_entries w
  where w.salon_id = new.salon_id
    and w.auth_identity_id = new.auth_identity_id
    and w.service_id = new.service_id
    and new.date between w.date_from and w.date_to;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Istek
-- ---------------------------------------------------------------------------
-- Filter je istina (svaki citac trazi `date_to >= danas`), a ovaj prolaz brise ono sto je
-- isteklo, zajedno sa ponudama (`on delete cascade`). Bez brisanja bi istekao upis zauzimao
-- kljuc (jedan upis po usluzi i radniku) i ostao u istoriji obavijesti kao ponuda na koju se
-- vise ne ceka. „Danas" je po vremenskoj zoni salona, kao u `expire_pending` (task 64).
create function private.expire_waitlist() returns integer
language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  delete from public.waitlist_entries w
  using public.salon_settings st
  where st.salon_id = w.salon_id
    and w.date_to < (now() at time zone st.timezone)::date;
  get diagnostics v_count = row_count;
  return v_count;
end $$;

revoke all on function private.expire_waitlist() from public, anon, authenticated;
grant execute on function private.expire_waitlist() to service_role;

comment on function private.expire_waitlist() is
  'Brise upise na listu cekanja ciji je zadnji dan (date_to) prosao po zoni salona, sa ponudama. Vraca broj obrisanih. Zove je pg_cron svaki sat (expire-waitlist).';

-- Svaki sat, ne jednom dnevno: saloni mogu biti u razlicitim zonama, a ponoc salona je ono
-- sto upis gasi. Do prolaza ga citaci vec ne vide.
select cron.schedule('expire-waitlist', '7 * * * *', 'select private.expire_waitlist()');
