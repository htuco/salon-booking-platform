# Slike idu u Supabase Storage, javni bucket po salonu

## Status

prihvaćen

## Kontekst

Aplikacija nema **nijedan** način da primi sliku. `storage.buckets` je prazan — Storage nije ni
postavljen. `services.image_url`, `employees.image_url` i `salons.gallery_urls` su obična `text`
polja, a vrijednosti u njima su vanjski Unsplash URL-ovi iz seeda. Salon svoje slike ne može ni
dodati ni zamijeniti; galerija radova ne postoji kao feature.

[ADR-0008](0008-galerija-ostaje-u-salons-gallery-urls.md) je odlučio da galerija ostaje niz URL-ova
u `salons.gallery_urls`. Novi podatak koji otvara temu nije oblik zapisa nego to da **izvor tih
URL-ova ne postoji** — odluka je pretpostavljala da ih neko upiše.

## Odluka

Slike idu u Supabase Storage, u bucket sa **javnim čitanjem** i upisom ograničenim na salon kojem
pripadaju.

- Čitanje je javno jer katalog i jeste javan: neprijavljen korisnik u klijentskoj aplikaciji vidi
  usluge, radnike i galeriju. Potpisani URL-ovi bi tome dodali rok trajanja i osvježavanje po listi,
  a ne bi sakrili ništa što već nije dostupno.
- Upis, izmjena i brisanje idu kroz politiku po `salon_id`, istom logikom kao i ostale tabele.
- Putanja nosi `salon_id` kao prvi segment, da politika može odlučiti bez pretrage.
- Kolone ostaju gdje jesu (`image_url`, `gallery_urls`) — mijenja se **odakle** vrijednost dolazi,
  ne gdje se čuva. ADR-0008 time nije oboren nego dopunjen.

## Posljedice

- Fajl koji se zamijeni ili obriše mora nestati i iz bucketa. Bez toga bucket raste zauvijek, a
  salon plaća prostor za slike koje niko ne vidi.
- Javno čitanje znači da URL slike **nije tajna**. Ništa što bi identifikovalo klijenta ne ide u
  ovaj bucket; slike „prije i poslije" sa licem klijenta traže zasebnu odluku i zaseban bucket.
- Store review traži da aplikacija koja prima korisnički sadržaj ima način prijave neprikladnog
  sadržaja. To je zaseban task, ne dio prvog upload toka.
