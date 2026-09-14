-- Recenzije salona. Task 20.
--
-- `prototype/ui/SPEC.md` 5m trazi ekran koji sema ne moze napuniti: prosjek "4,8", histogram
-- 5->1 i lista recenzija. Do sada je `salonRatingProvider` u `apps/client` vracao `null` i
-- sekcija na Pocetnoj se krila — uredno privremeno stanje, ali stanje bez podatka.
--
-- **Galerija u ovoj migraciji ne postoji.** DoD taska 20 trazi i tabelu `gallery_photos`, ali
-- `salons.gallery_urls` stoji u init migraciji i vec je spojena do ekrana. Odluka i ono sto se
-- njome gubi: `docs/adr/0008-galerija-ostaje-u-salons-gallery-urls.md`.

-- ---------------------------------------------------------------------------
-- Tabela
-- ---------------------------------------------------------------------------
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id),

  -- Ime kako ga handoff pise: "Nedim H.", ne puno prezime. Tekst, ne FK na `customers` —
  -- recenzije dolaze iz admina ili importa (Google, Facebook), pa autor cesto nije nijedan
  -- red u ovoj bazi. FK bi znacio da se uvezena recenzija ne moze upisati bez izmisljanja
  -- klijenta.
  author_name text not null check (length(btrim(author_name)) > 0),

  rating int not null check (rating between 1 and 5),

  -- **Nullable, i to nosi histogram.** Handoff pokazuje "142 ocjene" iznad tri recenzije:
  -- vecina ljudi da zvjezdice bez teksta. Da je `comment` obavezan, prosjek bi se racunao
  -- samo nad napisanim recenzijama i bio bi drugi broj od onog koji salon vidi na Googleu.
  comment text,

  -- Recenzija se moze sakriti bez brisanja. Uvezeni sadrzaj trazi moderaciju, a brisanje
  -- reda mijenja prosjek i to se ne moze vratiti. Isti obrazac kao `is_active` na uslugama.
  is_published bool not null default true,

  -- Datum koji ekran pokazuje relativno ("prije 3 dana"). Kod importa je to datum originalne
  -- recenzije, ne datum uvoza — zato se smije upisati, a ne samo `default now()`.
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Kompozitni kljuc kao i na ostalim tabelama vezanim za salon (`security.md`, "Kompozitni
  -- strani kljucevi"): daje buducoj tabeli nacin da se veze na recenziju bez rizika da
  -- pokupi red drugog salona.
  unique (salon_id, id)
);

comment on table public.reviews is
  'Recenzije salona, read-only u klijentskoj app-i. Pisu se iz admina ili importa.';

-- Ekran trazi zadnjih N objavljenih recenzija jednog salona; agregat ide preko cijelog salona.
create index reviews_salon_published_created_idx
  on public.reviews (salon_id, is_published, created_at desc);

-- ---------------------------------------------------------------------------
-- Agregat: prosjek, ukupno i histogram
-- ---------------------------------------------------------------------------
-- **Zasto pogled, a ne racunanje u Dartu.** PostgREST u `config.toml` ima `max_rows = 1000`.
-- Salon sa 1200 ocjena bi klijentu vratio 1000 redova i prosjek bi bio **tih i pogresan** —
-- greska koja se ne vidi ni u jednom testu sa demo podacima. Agregat zato racuna baza, kao i
-- availability (`docs/01 §8.1`).
--
-- `security_invoker = true` nije kozmetika: bez njega pogled radi sa pravima vlasnika i
-- **zaobilazi RLS**, pa bi `anon` dobio prosjek neaktivnog salona i sakrivenih recenzija.
-- Negativan test u `006_reviews.test.sql` pada ako se ova opcija ukloni.
create view public.salon_rating_summary
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
group by salon_id;

comment on view public.salon_rating_summary is
  'Prosjek, ukupan broj i histogram 5->1 po salonu. security_invoker — RLS tabele `reviews` vazi.';

-- ---------------------------------------------------------------------------
-- Grantovi: prvo sve oduzeto, pa vraceno taksativno
-- ---------------------------------------------------------------------------
-- Nova tabela nije automatski dostupna (`config.toml` ne postavlja `auto_expose_new_tables`),
-- pa mora dobiti i grant i politiku. Tabela sa politikom bez granta je nevidljiva.
revoke all on public.reviews from anon, authenticated;
revoke all on public.salon_rating_summary from anon, authenticated;

grant all on public.reviews to service_role;
grant all on public.salon_rating_summary to service_role;

-- Citanje da, pisanje ne. Klijentska app nema nijedan write put ka recenzijama — ekran je
-- read-only (`tasks/sprint-2/20-galerija-recenzije.md`, Zamke). Upis ide iz admina, koji je
-- `salon_admin` i pokriven je politikom `staff_manage` ispod.
grant select on public.reviews to anon, authenticated;
grant select on public.salon_rating_summary to anon, authenticated;

grant insert, update, delete on public.reviews to authenticated;

-- ---------------------------------------------------------------------------
-- Politike
-- ---------------------------------------------------------------------------
alter table public.reviews enable row level security;

-- Javno citanje: samo objavljene recenzije samo aktivnog salona. Oba uslova su potrebna i
-- oba imaju svoj negativan test — sakrivena recenzija aktivnog salona i objavljena recenzija
-- neaktivnog salona moraju biti nevidljive `anon`-u.
create policy public_published on public.reviews
  for select to anon, authenticated
  using (is_published and private.salon_active(salon_id));

-- Osoblje vidi i sakrivene, ali samo svoje. `private.is_admin(salon_id)` trazi i claim iz
-- JWT-a i red u `public.users` — uloga iz tokena sama po sebi ne znaci nista.
create policy staff_manage on public.reviews
  for all to authenticated
  using (private.is_admin(salon_id))
  with check (private.is_admin(salon_id));
