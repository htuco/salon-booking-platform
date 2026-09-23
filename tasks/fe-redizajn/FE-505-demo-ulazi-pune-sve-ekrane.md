# FE-505 — Demo ulazi pune sve ekrane

| | |
|---|---|
| **Epik** | FE-5 · Kvalitet i konzistentnost |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | — |
| **Blokira** | ponovljeni [FE-504](FE-504-qa-prolaz.md) |
| **Reference** | `apps/client/lib/demo_main.dart` · `apps/admin/lib/demo_main.dart` · `apps/client/test/support/screen_harness.dart` |

## Cilj
QA prolaz na webu mora moći otvoriti **svaki** ekran. Danas devet prikaza u demou pada ili
pokazuje grešku učitavanja, pa ih vizuelni prolaz ne može vidjeti.

## Zatečeno stanje
Nađeno u FE-504 (2026-09-23), `flutter build web -t lib/demo_main.dart`:

- **Klijent — ekran se sruši u sivu površinu** (Flutterov widget greške u release buildu):
  `/appointments` i `/settings`, na oba tenanta. `demo_main.dart` ne podmeće
  `authRepositoryProvider` ni `isSignedInProvider`, pa ekran traži `Supabase.instance`,
  kojeg u demou nema.
- **Klijent — stanje greške umjesto sadržaja:** `/gallery`, `/reviews`, `/terms`, `/privacy`.
  Nisu podmetnuti `salonGalleryProvider`, `salonRatingProvider`, `salonReviewsProvider`,
  `termsProvider` i `privacyPolicyProvider`. Stanje greške je pri tome ispravno nacrtano (FE-501).
- **Admin — greška učitavanja:** `/clients`, `/working-hours`, `/settings`.

`test/support/screen_harness.dart` već ima potpunu listu override-a za klijenta. Demo je
zaostao za njom.

## Definicija gotovog
- [ ] Svaka ruta klijenta u demou crta sadržaj na oba tenanta, i prijavljeno i neprijavljeno stanje
- [ ] Svaka admin ruta u demou crta sadržaj
- [ ] Demo podaci prate `supabase/seed.sql` (pravilo iz komentara `demo_main.dart`)
- [ ] Nema druge kopije override liste koja se može razići sa harnessom — ili je izvedena iz
      zajedničkog izvora, ili postoji test koji ruši build kad demo ne pokrije rutu

## Zamke
- Demo **nije** production ulaz. Ništa odavde ne smije ući u `main.dart`.
- Siva površina u release buildu je izuzetak, ne prazan ekran. U debug buildu je to crveni ekran sa porukom.
