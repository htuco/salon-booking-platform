-- Pravila koristenja i politika privatnosti. Task 21.
--
-- `prototype/ui/screenshots/15-pravila-koristenja.png` crta sest numerisanih sekcija, ali one
-- **nisu iste vrste**: tri obavezuju firmu koja app objavljuje (Zakazivanje, Cijene, Vasi
-- podaci), tri obavezuju salon (Otkazivanje, Kasnjenje, Kontakt). Otud dvije tabele, a ne jedna
-- sa nullable `salon_id`.
--
-- Obrazlozenje i odbacene opcije:
-- `docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md`.

-- ---------------------------------------------------------------------------
-- Dokument kojem sekcija pripada
-- ---------------------------------------------------------------------------
-- Enum, a ne `text check(...)`: ovo je zatvoren skup domenskih vrijednosti koji klijentski kod
-- cita kao tip (kao `appointment_status`), a ne postavka koja se podesava (kao `booking_mode`).
create type public.policy_document as enum ('terms', 'privacy');

comment on type public.policy_document is
  'Pravni dokument kojem sekcija pripada. `privacy` postoji samo u `app_policies`.';

-- ---------------------------------------------------------------------------
-- Platformske sekcije — bez `salon_id`
-- ---------------------------------------------------------------------------
-- **Namjeran izuzetak od pravila „svaka nova tabela nosi `salon_id`"** (`supabase/CLAUDE.md`).
-- Drugi takav slucaj u semi; prvi je `vertical_packs`, i oblik politike je isti: javno citanje,
-- pisanje samo super adminu.
--
-- Razlog nije udobnost nego odgovornost: tekst o obradi licnih podataka je izjava firme pod
-- kojom aplikacija stoji u storeu. Salon koji ga moze mijenjati je salon koji u ime firme tvrdi
-- nesto sto firma ne vidi.
create table public.app_policies (
  id uuid primary key default gen_random_uuid(),

  document public.policy_document not null,

  -- Redoslijed unutar dokumenta. **Broj sekcije koji korisnik vidi (`01`..`NN`) se ne cuva
  -- ovdje** — ekran ga racuna iz pozicije u spojenoj listi. Upisan broj bi se razisao sa
  -- prikazanim cim salon doda svoju sekciju iznad.
  sort_order int not null check (sort_order > 0),

  title text not null check (length(btrim(title)) > 0),

  -- Tijelo smije nositi placeholdere koje ekran puni iz zivih podataka:
  -- `{minCancelHours}`, `{phone}`, `{email}`, `{appointmentSingular}`.
  --
  -- Bez njih bi rok otkazivanja bio slobodan tekst, a `cancel_appointment` (task 16) ga stvarno
  -- provodi iz `salon_settings.min_cancel_hours` — barber 3, beauty 6, handoff pise 2. Pravno
  -- obavezujuci ekran koji pise drugi broj od onog koji baza provodi laze korisniku.
  body text not null check (length(btrim(body)) > 0),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Dvije sekcije istog dokumenta na istoj poziciji znace nedeterministican redoslijed, a to
  -- se na pravnom ekranu vidi kao da se tekst „promijenio" izmedju dva otvaranja.
  unique (document, sort_order)
);

comment on table public.app_policies is
  'Platformske sekcije pravila i cijela politika privatnosti. Bez `salon_id` — v. ADR-0009.';

-- ---------------------------------------------------------------------------
-- Salonske sekcije
-- ---------------------------------------------------------------------------
create table public.salon_policies (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id),

  -- **Samo `terms`.** Politika privatnosti je u cijelosti platformska (ADR-0009), i to provodi
  -- `check`, ne komentar. Kolona ipak postoji da upit i model imaju isti oblik nad obje tabele;
  -- kad bi je nestalo, repozitorij bi za jednu tabelu morao pretpostaviti dokument.
  document public.policy_document not null default 'terms'
    check (document = 'terms'),

  sort_order int not null check (sort_order > 0),
  title text not null check (length(btrim(title)) > 0),
  body text not null check (length(btrim(body)) > 0),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (salon_id, document, sort_order),

  -- Kompozitni kljuc kao i na ostalim tabelama vezanim za salon (`security.md`, „Kompozitni
  -- strani kljucevi").
  unique (salon_id, id)
);

comment on table public.salon_policies is
  'Sekcije pravila koje pise salon (otkazivanje, kasnjenje, kontakt). Samo dokument `terms`.';

-- „Zadnja izmjena" na ekranu je `max(updated_at)` nad spojenom listom, pa kolona mora biti ziva.
-- Bez triggera bi pisala datum unosa zauvijek i ekran bi tvrdio da se pravila nikad nisu mijenjala.
create trigger touch_updated_at before update on public.app_policies
  for each row execute function private.touch_updated_at();
create trigger touch_updated_at before update on public.salon_policies
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Grantovi: prvo sve oduzeto, pa vraceno taksativno
-- ---------------------------------------------------------------------------
-- Nova tabela nije automatski dostupna (`config.toml` ne postavlja `auto_expose_new_tables`).
revoke all on public.app_policies from anon, authenticated;
revoke all on public.salon_policies from anon, authenticated;

grant all on public.app_policies to service_role;
grant all on public.salon_policies to service_role;

-- Citanje **bez prijave**: pravila se moraju moci procitati prije nego se korisnik prijavi, jer
-- prijava je zadnji korak booking flowa (`docs/06 §1.1`).
grant select on public.app_policies to anon, authenticated;
grant select on public.salon_policies to anon, authenticated;

-- Pisanje ide iz admina, i grant ga ne odobrava — odobrava ga politika ispod. Grant bez politike
-- je nevidljiva tabela; politika bez granta isto.
grant insert, update, delete on public.app_policies to authenticated;
grant insert, update, delete on public.salon_policies to authenticated;

-- ---------------------------------------------------------------------------
-- Politike
-- ---------------------------------------------------------------------------
alter table public.app_policies enable row level security;
alter table public.salon_policies enable row level security;

-- Platformski tekst je isti u svakoj brandiranoj app-i i ne zavisi od salona — zato `true`, kao
-- `public_verticals` na `vertical_packs`. Ovdje nema `private.salon_active(...)` jer nema
-- `salon_id`: uslov koji ne postoji ne smije se izmisliti da bi politika „izgledala" strozije.
create policy public_read on public.app_policies
  for select to anon, authenticated
  using (true);

-- **Salon admin ovdje nema nista.** `private.is_admin(...)` bi ga pustio, pa se trazi
-- `private.is_super_admin()` — i negativan test u `007_policies.test.sql` pada ako se to oslabi.
create policy super_manage on public.app_policies
  for all to authenticated
  using (private.is_super_admin())
  with check (private.is_super_admin());

-- Salonske sekcije aktivnog salona su javne, kao i ostatak kataloga. Neaktivan salon izgleda
-- isto kao nepostojeci — RLS ne vraca „zabranjeno" nego odsustvo reda.
create policy public_active on public.salon_policies
  for select to anon, authenticated
  using (private.salon_active(salon_id));

create policy staff_manage on public.salon_policies
  for all to authenticated
  using (private.is_admin(salon_id))
  with check (private.is_admin(salon_id));
