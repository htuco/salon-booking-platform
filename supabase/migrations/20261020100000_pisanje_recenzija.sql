-- Task 67: pisanje recenzija.
--
-- Od taska 20 je `public.reviews` bila tabela koju pise samo salon: `author_name` je slobodan
-- tekst, red nije vezan ni za termin ni za klijenta, a politika `staff_manage` je adminu
-- davala `for all` — i mijenjanje tudjeg teksta. Recenzija koju salon moze prepisati nije
-- recenzija nego reklama.
--
-- Ova migracija mijenja tri stvari:
--
--   1. **Recenzija je vezana za zavrsen termin i identitet.** `appointment_id` i
--      `auth_identity_id`, najvise jedna po terminu. Pise je samo `submit_review`, i samo za
--      termin pozivaoca sa statusom `completed`. Ime autora pravi baza iz identiteta, ne
--      klijent — inace bi klijent potpisao recenziju tudjim imenom.
--   2. **Salon sakriva, ali ne mijenja.** `authenticated` gubi `insert/update/delete` nad
--      tabelom; `staff_manage` postaje `staff_read`. Jedino pisanje salona je
--      `set_review_published`, koji dira samo `is_published`.
--   3. **Prijava recenzije ide platformi**, istim putem kao slika (ADR-0024):
--      `content_reports` dobija `review_id`, a `notify-content-reports` je salje na webhook.
--
-- **Zateceni redovi ostaju.** Seed i buduci import (Google, Facebook) nemaju termin ni
-- identitet, pa su obje kolone nullable. `check` trazi da dolaze zajedno, a upis bez njih
-- ostaje samo `service_role`-u (seed, import), jer `authenticated` vise nema `insert` grant.

-- Nova vrijednost se u istoj transakciji ne smije **upotrijebiti**, ali tijelo plpgsql
-- funkcije se razrjesava tek pri pozivu (isti obrazac kao `expired` u tasku 64).
alter type public.notification_type add value if not exists 'review_request';

-- ---------------------------------------------------------------------------
-- Tabela
-- ---------------------------------------------------------------------------
alter table public.reviews
  add column appointment_id uuid,
  add column auth_identity_id uuid references public.auth_identities(id);

-- Kompozitni FK (`security.md`, „Kompozitni strani kljucevi"): termin mora biti iz istog
-- salona kao recenzija. Obican FK na `appointments(id)` bi pustio recenziju salona A na
-- termin salona B, i ona bi usla u prosjek pogresnog salona.
alter table public.reviews
  add constraint reviews_termin_fk
    foreign key (salon_id, appointment_id) references public.appointments(salon_id, id),
  add constraint reviews_jedna_po_terminu unique (appointment_id),
  add constraint reviews_termin_i_identitet
    check ((appointment_id is null) = (auth_identity_id is null)),
  -- Granica upisa, ne prikaza: ekran ima isto ogranicenje, ali baza je jedina koja ga drzi.
  add constraint reviews_comment_duzina check (char_length(comment) <= 1000);

comment on column public.reviews.appointment_id is
  'Termin koji je ocijenjen (task 67). NULL samo za seed i import, koje pise service_role.';
comment on column public.reviews.auth_identity_id is
  'Ko je ocijenio. Uvijek zajedno sa appointment_id; nikad ne stize iz klijenta, nego iz termina.';

comment on table public.reviews is
  'Recenzije salona. Klijent pise kroz submit_review (svoj zavrsen termin), salon samo sakriva kroz set_review_published; seed i import pise service_role.';

-- ---------------------------------------------------------------------------
-- Grantovi i politike
-- ---------------------------------------------------------------------------
revoke insert, update, delete on public.reviews from authenticated;

-- **Grant postaje kolonski.** `auth_identity_id` je ista osoba u svakom salonu, a vlasnik ga
-- vidi i na svom `customers` redu. Sa tabelarnim grantom bi vlasnik salona A filtrirao
-- javne recenzije po identitetima svojih klijenata i saznao ko od njih ide u salon B i kako
-- ga ocjenjuje (nalaz `rls-auditor`, prije merge-a). `appointment_id` je tuđi termin. Obje
-- kolone zato ne čita niko osim `service_role`; klijent svoje ocjene dobija kroz
-- `my_review_ratings`.
revoke select on public.reviews from anon, authenticated;
grant select (id, salon_id, author_name, rating, comment, is_published, created_at, updated_at)
  on public.reviews to anon, authenticated;

drop policy staff_manage on public.reviews;

-- Admin vidi i sakrivene, ali samo svoje. Radnik ne: recenzija je o salonu, a sakrivanje je
-- posao vlasnika.
create policy staff_read on public.reviews
  for select to authenticated
  using (private.is_admin(salon_id));

-- **Agregat broji samo objavljene, za svakoga.** Do sada je to drzala politika, pa je admin
-- vidio drugi prosjek od javnosti. Broj na ekranu je javni broj, i isti je za sve uloge.
-- `security_invoker` ostaje: bez njega `anon` dobija prosjek neaktivnog salona.
create or replace view public.salon_rating_summary
  with (security_invoker = true) as
select
  salon_id,
  round(avg(rating)::numeric, 1) as average,
  count(*)::int                                    as total,
  count(*) filter (where rating = 5)::int          as count_5,
  count(*) filter (where rating = 4)::int          as count_4,
  count(*) filter (where rating = 3)::int          as count_3,
  count(*) filter (where rating = 2)::int          as count_2,
  count(*) filter (where rating = 1)::int          as count_1
from public.reviews
where is_published
group by salon_id;

comment on view public.salon_rating_summary is
  'Prosjek, ukupan broj i histogram 5->1 objavljenih recenzija po salonu. security_invoker — RLS tabele `reviews` vazi.';

-- ---------------------------------------------------------------------------
-- Ime autora
-- ---------------------------------------------------------------------------
-- „Nedim Hodzic" -> „Nedim H.", kao u handoffu (5m): ime i inicijal prezimena, ne puno ime.
-- Recenzija je javna, a puno ime i prezime uz ocjenu frizera je vise nego sto treba.
-- Jedna rijec ostaje kakva jeste; prazno daje „Klijent".
create or replace function private.review_author(p_name text)
returns text language sql immutable set search_path = '' as $$
  select case
    when array_length(dijelovi, 1) is null then 'Klijent'
    when array_length(dijelovi, 1) = 1 then dijelovi[1]
    else dijelovi[1] || ' ' || upper(left(dijelovi[array_length(dijelovi, 1)], 1)) || '.'
  end
  from (
    select array_remove(regexp_split_to_array(btrim(coalesce(p_name, '')), '\s+'), '')
      as dijelovi
  ) d
$$;
revoke all on function private.review_author(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Klijent pise
-- ---------------------------------------------------------------------------
create function public.submit_review(
  p_appointment_id uuid,
  p_rating integer,
  p_comment text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_salon uuid;
  v_termin public.appointments%rowtype;
  v_comment text := nullif(btrim(coalesce(p_comment, '')), '');
  v_ime text;
  v_id uuid;
begin
  -- `NULL` se hvata prvi (`security.md`, zamka 1): bez headera je `client_salon_id()` NULL.
  v_salon := private.client_salon_id();
  if private.is_client() is not true or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  -- Tudji termin, termin drugog salona i nepostojeci termin daju istu gresku: odgovor ne
  -- smije reci da termin postoji.
  select a.* into v_termin
  from public.appointments a
  where a.id = p_appointment_id
    and a.salon_id = v_salon
    and a.auth_identity_id is not null
    and private.owns_identity(a.auth_identity_id);
  if not found then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  if v_termin.status <> 'completed' then
    raise exception 'Ocjena je moguća tek kad salon označi termin završenim'
      using errcode = 'PT400';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'Ocjena je od 1 do 5' using errcode = 'PT400';
  end if;
  if char_length(v_comment) > 1000 then
    raise exception 'Tekst je predug' using errcode = 'PT400';
  end if;

  select private.review_author(ai.display_name) into v_ime
  from public.auth_identities ai
  where ai.id = v_termin.auth_identity_id;

  insert into public.reviews (salon_id, appointment_id, auth_identity_id, author_name, rating, comment)
  values (v_salon, v_termin.id, v_termin.auth_identity_id, coalesce(v_ime, 'Klijent'), p_rating, v_comment)
  on conflict (appointment_id) do nothing
  returning id into v_id;

  -- Druga recenzija za isti termin pada, ne prepisuje prvu: ocjena nije forma koja se
  -- snima vise puta, a tiho prepisivanje bi bilo nevidljivo salonu koji je prvu vec procitao.
  if v_id is null then
    raise exception 'Ovaj termin je već ocijenjen' using errcode = 'PT409';
  end if;
  return v_id;
end $$;

revoke all on function public.submit_review(uuid, integer, text) from public, anon;
grant execute on function public.submit_review(uuid, integer, text) to authenticated;

comment on function public.submit_review(uuid, integer, text) is
  'Klijent ocjenjuje svoj zavrsen termin u salonu iz x-salon-id: 1-5 i opcionalan tekst do 1000 znakova. Ime autora je iz identiteta. 42501 za tudji/nepostojeci termin, PT400 kad termin nije completed, PT409 za drugu recenziju istog termina.';

-- Ocjene pozivaoca za njegove termine u salonu iz `x-salon-id`, i za sakrivene: po njima
-- „Moji termini" zna da je termin vec ocijenjen. Funkcija, a ne politika, jer tabela
-- `appointment_id` nikome ne daje (v. grant gore). Vraca samo par termin → ocjena, i samo
-- za termine ciji je identitet pozivaocev.
create function public.my_review_ratings()
returns table (appointment_id uuid, rating integer)
language plpgsql stable security definer set search_path = '' as $$
declare v_salon uuid;
begin
  v_salon := private.client_salon_id();
  if private.is_client() is not true or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  return query
  select r.appointment_id, r.rating
  from public.reviews r
  where r.salon_id = v_salon
    and r.auth_identity_id is not null
    and private.owns_identity(r.auth_identity_id);
end $$;

revoke all on function public.my_review_ratings() from public, anon;
grant execute on function public.my_review_ratings() to authenticated;

comment on function public.my_review_ratings() is
  'Ocjene pozivaoca u salonu iz x-salon-id kao (appointment_id, rating), i sakrivene. Samo identitet iz tokena; 42501 za osoblje, anon i bez konteksta.';

-- ---------------------------------------------------------------------------
-- Salon sakriva
-- ---------------------------------------------------------------------------
create function public.set_review_published(p_review_id uuid, p_published boolean)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_salon uuid;
begin
  select r.salon_id into v_salon from public.reviews r where r.id = p_review_id;
  -- `is_admin(NULL)` je false, pa nepostojeca recenzija pada na istu gresku kao tudja.
  if p_published is null or private.is_admin(v_salon) is not true then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;

  update public.reviews r
  set is_published = p_published, updated_at = now()
  where r.id = p_review_id;
end $$;

revoke all on function public.set_review_published(uuid, boolean) from public, anon;
grant execute on function public.set_review_published(uuid, boolean) to authenticated;

comment on function public.set_review_published(uuid, boolean) is
  'Admin salona sakriva ili vraca recenziju svog salona. Mijenja samo is_published; tekst, ocjenu i autora salon ne moze dirati. 42501 za tudju ili nepostojecu recenziju.';

-- ---------------------------------------------------------------------------
-- Brisanje naloga
-- ---------------------------------------------------------------------------
-- `delete_my_account` (task 17) anonimizira termine i klijente, a identitet dobija
-- `deleted_at`. Recenzija tada ostaje kao **ocjena** — brisanje bi pomjerilo prosjek salona
-- unatrag — ali ime i tekst nestaju: tekst je licni sadrzaj osobe koja je trazila brisanje.
-- Trigger, a ne nova verzija `delete_my_account`, da i brisanje kroz bilo koji drugi put
-- (support, service_role) ima isti ishod.
create or replace function private.anonymize_reviews_of_identity()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.reviews r
  set author_name = 'Bivši klijent', comment = null, updated_at = now()
  where r.auth_identity_id = new.id;
  return new;
end $$;
revoke all on function private.anonymize_reviews_of_identity() from public, anon, authenticated;

create trigger anonymize_reviews_of_identity
  after update of deleted_at on public.auth_identities
  for each row
  when (old.deleted_at is null and new.deleted_at is not null)
  execute function private.anonymize_reviews_of_identity();

-- ---------------------------------------------------------------------------
-- Prijava recenzije
-- ---------------------------------------------------------------------------
-- Isti red, isti worker i ista pravila kao prijava slike (ADR-0024): salon ne cita prijave
-- svog sadrzaja, cita ih samo `super_admin`, a webhook platforme dobija poruku.
alter table public.content_reports
  alter column image_url drop not null,
  add column review_id uuid references public.reviews(id) on delete cascade,
  add constraint content_reports_sta_je_prijavljeno
    check (num_nonnulls(image_url, review_id) = 1);

-- Jedan klijent, jedna recenzija, jedna prijava — i nakon razrjesenja, kao kod slike.
create unique index content_reports_recenzija_jednom
  on public.content_reports (reporter_user_id, review_id)
  where review_id is not null;

create function public.report_review(p_review_id uuid, p_reason text default null)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_salon uuid;
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_id uuid;
begin
  v_salon := private.client_salon_id();
  if private.is_client() is not true or v_salon is null then
    raise exception 'Nije dozvoljeno' using errcode = '42501';
  end if;
  if char_length(v_reason) > 500 then
    raise exception 'Razlog je predug' using errcode = 'PT400';
  end if;
  -- Dnevni limit je zajednicki sa slikama: svaka prijava je poruka u kanalu platforme.
  if (select count(*) from public.content_reports r
      where r.reporter_user_id = auth.uid() and r.created_at > now() - interval '1 day') >= 10 then
    raise exception 'Previše prijava u jednom danu' using errcode = 'PT429';
  end if;
  -- Prijavljuje se recenzija koju klijent stvarno vidi: objavljena, u salonu iz headera.
  if not exists (
    select 1 from public.reviews r
    where r.id = p_review_id and r.salon_id = v_salon and r.is_published
  ) then
    raise exception 'Recenzija nije pronađena' using errcode = 'PT400';
  end if;

  insert into public.content_reports (salon_id, review_id, reason, reporter_user_id)
  values (v_salon, p_review_id, v_reason, auth.uid())
  on conflict (reporter_user_id, review_id) where review_id is not null do nothing
  returning id into v_id;

  if v_id is null then
    select r.id into v_id
    from public.content_reports r
    where r.reporter_user_id = auth.uid() and r.review_id = p_review_id;
  end if;
  return v_id;
end $$;

revoke all on function public.report_review(uuid, text) from public, anon;
grant execute on function public.report_review(uuid, text) to authenticated;

comment on function public.report_review(uuid, text) is
  'Klijent prijavljuje objavljenu recenziju salona iz x-salon-id. Prijava ide platformi (content_reports, samo super_admin), ne salonu. Ponovljena prijava vraca postojeci id; dnevni limit od 10 je zajednicki sa slikama (PT429).';

-- Worker treba i recenziju. Povratni tip se mijenja, pa `drop` + `create`; grant se vraca
-- isti, samo `service_role`.
drop function public.claim_content_reports(integer);

create function public.claim_content_reports(p_limit integer default 20)
returns table (
  id uuid,
  salon_id uuid,
  salon_name text,
  image_url text,
  review_id uuid,
  review_rating integer,
  review_comment text,
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
    returning r.id, r.salon_id, r.image_url, r.review_id, r.reason, r.created_at
  )
  select p.id, p.salon_id, s.name, p.image_url, p.review_id, rv.rating, rv.comment,
    p.reason, p.created_at
  from preuzete p
  join public.salons s on s.id = p.salon_id
  left join public.reviews rv on rv.id = p.review_id
  order by p.created_at
$$;

revoke all on function public.claim_content_reports(integer) from public, anon, authenticated;
grant execute on function public.claim_content_reports(integer) to service_role;

-- ---------------------------------------------------------------------------
-- Push poslije termina
-- ---------------------------------------------------------------------------
-- Termin koji salon oznaci zavrsenim javlja klijentu „Kako je bilo?". Isti trigger i isti
-- `dispatch_push` kao ostale promjene statusa; `on conflict` u logu drzi jednu poruku po
-- terminu i kad salon status vrati i ponovo zavrsi.
create or replace function private.queue_appointment_push() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_type public.notification_type; v_staff boolean := false;
begin
  if tg_op = 'INSERT' then
    -- Rucni unos iz salona ne obavjestava salon o samom sebi, pa `source` i dalje presudjuje
    -- prvi. Status vise ne odlucuje **hoce li** se slati nego **sta** se salje.
    if new.source <> 'app' then return new; end if;
    if new.status = 'pending' then
      v_type := 'new_request';
    elsif new.status = 'confirmed' then
      v_type := 'new_booking';
    else
      return new;
    end if;
    v_staff := true;
  elsif new.status is not distinct from old.status then
    return new;
  elsif new.status = 'confirmed' then
    v_type := 'confirmed';
  elsif new.status = 'cancelled' and new.cancelled_by = 'salon' then
    v_type := case when old.status = 'pending' then 'rejected'::public.notification_type
      else 'cancelled'::public.notification_type end;
  elsif new.status = 'cancelled' and new.cancelled_by = 'customer' then
    v_type := 'cancelled'; v_staff := true;
  elsif new.status = 'cancelled' and new.cancelled_by = 'system' and old.status = 'pending' then
    v_type := 'expired';
  elsif new.status = 'completed' then
    v_type := 'review_request';
  else return new;
  end if;

  insert into public.notification_logs(salon_id, appointment_id, device_id, type)
  select new.salon_id, new.id, d.id, v_type from public.devices d
  where d.salon_id = new.salon_id and d.fcm_token is not null and (
    (v_staff and exists (select 1 from public.users u where u.id = d.staff_user_id
      and u.salon_id = new.salon_id and u.role = 'salon_admin'))
    or (not v_staff and d.id = new.device_id and d.staff_user_id is null
      and d.auth_identity_id = new.auth_identity_id)
  ) on conflict (appointment_id, device_id, type) do nothing;
  return new;
end $$;

revoke all on function private.queue_appointment_push() from public, anon, authenticated;

comment on function private.queue_appointment_push() is
  'Puni notification_logs iz promjene termina. INSERT sa source=app javlja salonu: new_request u manual modu, new_booking u auto modu. Promjena statusa javlja klijentu (confirmed/rejected/cancelled, istek zahtjeva kao expired, zavrsen termin kao review_request), a otkazivanje od klijenta salonu.';
