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
- [x] Svaka ruta klijenta u demou crta sadržaj na oba tenanta, i prijavljeno i neprijavljeno stanje
- [x] Svaka admin ruta u demou crta sadržaj
- [x] Demo podaci prate `supabase/seed.sql` (pravilo iz komentara `demo_main.dart`)
- [x] Nema druge kopije override liste koja se može razići sa harnessom — ili je izvedena iz
      zajedničkog izvora, ili postoji test koji ruši build kad demo ne pokrije rutu

## Zamke
- Demo **nije** production ulaz. Ništa odavde ne smije ući u `main.dart`.
- Siva površina u release buildu je izuzetak, ne prazan ekran. U debug buildu je to crveni ekran sa porukom.

## Status

**Gotovo, dokazano.** Grana `fix/fe-505-demo-ulazi`.

- Podaci i override-i iz oba `demo_main.dart` su premješteni u **`lib/src/demo/demo_overrides.dart`**
  (`demoOverrides(env)`); ulaz je sada tanak.
- **Klijent** dobija demo prijavu (`_DemoAuth`, sesija u memoriji — odjava i brisanje rade),
  tri svoja termina (jedan naredni, dva prošla), galeriju iz `assets/demo/`, ocjenu, tri
  recenzije, pravila, privatnost i postavke salona. `demoOverrides(env, prijavljen: false)`
  pokazuje i neprijavljeno stanje.
- **Admin** dobija klijente (izvedene iz demo termina; `customerId` je sada po imenu, ranije je
  bio isti za sve), istoriju klijenta, radno vrijeme, buduće blokade i tri izvora Postavki.

### Čuvar

`test/demo_overrides_test.dart` u obje aplikacije podiže app **istom listom** kojom je podiže
demo, na svakoj ruti. Klijent: 20 ruta × 2 tenanta × prijavljen/odjavljen (82 testa). Admin:
12 ruta × 2 širine (24). Pada na `LoadError`/`AdminLoadError` i na rečenice tipa „ne može
učitati". **Sabotaža:** bez override-a galerije i auth-a pada 32 klijentska testa — među njima
`/account`, detalj termina i `/book/details`, koje FE-504 nije ni stigao otvoriti. Bez klijenata
i postavki padaju tačno `/clients` i `/settings` admina, na obje širine.

### Viđeno

Demo web buildovi, svjež browser kontekst: svih **devet** prikaza iz FE-504 crta sadržaj —
Termini i Postavke na oba tenanta, Galerija, Recenzije, Pravila, Privatnost, admin Klijenti,
Radno vrijeme i Postavke.

**Zamka koju je provjera našla:** prvi snimak je i dalje pokazao sive ekrane — browser je sa
istog porta servirao stari build preko service workera. Zapisano u `workflows.md`.

### Dokaz

Admin 416, klijent 391, `core_ui` 104 testova PASS; analiza i format čisti.
