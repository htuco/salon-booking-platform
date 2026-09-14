# Galerija ostaje u `salons.gallery_urls`, tabela `gallery_photos` ne nastaje

## Status

prihvaćen

## Kontekst

DoD [taska 20](../../tasks/sprint-2/20-galerija-recenzije.md) traži dvije nove tabele:
`gallery_photos` i `reviews`. Za recenzije u šemi zaista nema ničega. Za galeriju ima, i to od
prvog dana:

- `public.salons.gallery_urls jsonb not null default '[]'` stoji u init migraciji
  (`20260910090000_init_schema.sql`), dakle prije nego što je task 20 napisan;
- `SalonRepository.galleryUrls` je čita, `salonGalleryProvider` je izlaže, a `GalleryGrid` je crta
  na Početnoj i na `/about` — sve isporučeno kroz taskove 18 i 19;
- `seed.sql` puni šest fotografija za barbera i namjerno ostavlja `[]` za beauty, pa je prazno
  stanje pokriveno demo podatkom, a ne samo testom.

Tabela bi, dakle, nastala pored puta koji već radi i koji je dokazan na ekranu. Dva mjesta za
istu listu su dva izvora istine, a `CLAUDE.md` to izričito zabranjuje.

Pritisak koji je tražio odluku je što DoD i šema tvrde različite stvari, a migracija je prvi korak
taska — greška ovdje se plaća prepisivanjem tri ekrana i njihovih testova.

## Odluka

**Galerija čita `salons.gallery_urls`. `gallery_photos` ne nastaje.** Ekran `/gallery` i lightbox
5q dobijaju podatke kroz postojeći `salonGalleryProvider`; migracija ovog taska donosi **samo**
`public.reviews`.

Redoslijed slika je redoslijed elemenata u jsonb nizu. `SalonRepository.galleryUrls` ga ne sortira
ponovo — isti razlog zbog kojeg `groupByCategory` iz taska 19 ne sortira usluge: drugo sortiranje
nad već uređenim izvorom je drugi izvor istine za isti poredak.

Ova odluka ispravlja red 17 DoD-a taska 20. DoD nije mjesto na kojem se odluka o šemi smije
ostaviti prećutnom, pa stoji ovdje.

## Razmatrane opcije

- **Nova tabela `gallery_photos(salon_id, url, alt, sort_order)`** — odbačeno: dobitak je ručni
  redoslijed i alt tekst po slici, a cijena je migracija, seed, gašenje kolone koja radi, i
  prepisivanje `SalonRepository`, `home_screen.dart`, `about_screen.dart` i tri postojeća testa.
  Nijedan ekran iz `prototype/ui/` ne traži ni alt tekst ni redoslijed drugačiji od zadatog:
  `SPEC.md` §Interactions doslovno kaže „No titles or captions on photos".
- **Obje, uz `gallery_urls` kao izvor** — odbačeno: tabela koja postoji a ne koristi se je gore od
  tabele koje nema. Sljedeći čitalac ne može znati koje je mjesto tačno, i prva izmjena ide u
  pogrešno.
- **Selidba na `gallery_photos` kad dođe admin CRUD nad galerijom** — odgođeno, ne odbačeno.
  Vratiće je na sto prvi zahtjev koji jsonb niz ne pokriva uredno: ručno prevlačenje redoslijeda u
  adminu, alt tekst zbog pristupačnosti, ili metapodatak po slici (radnik, usluga, datum).
  Sprint 3 planira admin CRUD nad uslugama, radnicima i radnim vremenom — galerija u toj listi
  nije.

## Posljedice

- Migracija taska 20 dira samo `reviews`. Galerija ne dobija nijedan red SQL-a.
- Galerija nema `sort_order` ni alt tekst. **Ovo je očekivano ponašanje, a ne propust:** slika bez
  opisa je ono što handoff traži, a poredak se mijenja preuređivanjem niza u `gallery_urls`.
- Čitalac koji dođe sa DoD-a taska 20 u ruci naći će tabelu koje nema. Zato red 17 tog DoD-a nosi
  vezu na ovaj ADR.
- Ako galerija ikad pređe na svoju tabelu, selidba je jednosmjerna i traži novi ADR koji ovaj
  zamjenjuje — ne usputnu promjenu u tasku koji radi nešto drugo.
- `reviews` je i dalje nova tabela i ide punim putem iz `supabase/CLAUDE.md`: `salon_id`,
  `enable row level security`, eksplicitan grant, politika i **negativan** test.
