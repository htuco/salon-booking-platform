-- Fotografija usluge i staz radnika. Task 22.
--
-- Dvije kolone koje `prototype/ui/SPEC.md` trazi, a sema nema: red usluge ima 76x76 thumb, a
-- red radnika pise "Barber · 9 godina". Bez njih korak 1 i Pocetna nikad ne mogu biti 1:1 sa
-- handoffom (nadjeno u tasku 11).
--
-- **Obje su nullable, i to je namjera, ne popustljivost.** Salon koji nema fotografije mora
-- raditi; prazan okvir je predvidjeno stanje koje `PhotoFrame` vec crta. Obavezna kolona bi
-- znacila da onboarding novog klijenta staje dok neko ne nadje slike.

alter table public.services
  add column image_url text;

comment on column public.services.image_url is
  'Fotografija usluge, 1:1 thumb. Nullable — salon bez fotografija radi, okvir ostaje prazan.';

alter table public.employees
  add column experience_years int
    -- Gornja granica nije kozmetika: bez nje jedna pogresno prekucana cifra u admin panelu
    -- ispise "Barber · 990 godina" i to se vidi tek na ekranu klijenta.
    check (experience_years is null or (experience_years >= 0 and experience_years <= 70));

comment on column public.employees.experience_years is
  'Godine staza radnika. Nullable — prikazuje se samo kad postoji (handoff: "Barber · 9 godina").';

-- ---------------------------------------------------------------------------
-- Grantovi i politike
-- ---------------------------------------------------------------------------
-- **Nista se ne dodaje, i to treba provjeriti, ne pretpostaviti.** Grantovi iz init migracije
-- su tabelarni (`grant select on public.services ... to anon, authenticated`), ne kolonski, pa
-- nova kolona ulazi u postojeci grant sama. Isto vazi za politike — `public_services` je
-- `using(...)` nad redom, ne nad listom kolona.
--
-- Da je grant bio kolonski, nova kolona bi bila nevidljiva `anon`-u i javni katalog bi tiho
-- izgubio fotografije. Zato to dokazuje REST test bez tokena, ne ovaj komentar.
