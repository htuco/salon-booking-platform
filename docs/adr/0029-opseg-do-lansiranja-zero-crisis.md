# Opseg do lansiranja („zero-crisis")

## Status

prihvaćen (2026-10-12) — mijenja `docs/01` §6.1, §7 i §17 (koraci 28–29) i `docs/06` §3.1.

## Kontekst

Sprint 5 je zatvoren, a prvi pravi tenanti (Amko, Authentic) prolaze kroz aplikaciju na uređaju.
Vlasnik proizvoda je 2026-10-12, poslije prvog prolaza kroz Authentic i pregleda onoga što od MVP-a
fali, odlučio šta ulazi do lansiranja, a šta ne. Novi podaci iza tih odluka:

- Melura sve email klijente prikazuje kao „Klijent" i „Bez broja" — salon ne zna ko je ko, a
  „kontakt jednim tapom" (task 58) nema šta zvati (`docs/research/auth-krajnji-korisnik.md`).
- Super admin konzola iz `docs/01` §6.1 je zamišljena kao hostovana Next.js aplikacija; nijedan red
  nije napisan, a salone dodaje developer.
- Javni web link i QR (§17) nisu traženi ni od jednog salona.
- Lista čekanja, pisanje recenzija i sedmični kalendar su bili van MVP-a; vlasnik proizvoda ih
  vidi kao ono što salonu najviše fali u odnosu na konkurenciju.

## Odluka

| Tema | Odluka | Bilo |
|---|---|---|
| Super admin konzola | **Minimalna, lokalna**: radi samo na mašini developera, nikad se ne deploya. Mali, ali intuitivan UI | hostovana Next.js aplikacija (§6.1) |
| Javni web link `/s/:slug` i QR | **Ne postoji** | §17 korak 28 |
| Telefon klijenta | **Traži se pri registraciji, bez SMS verifikacije**; ime i prezime takođe | „telefona nema i neće ga biti" (`06 §3.1`) |
| Uslovi i privatnost | **Checkbox** pri registraciji (i poslije prve Apple/Google prijave), prihvatanje se bilježi sa verzijom | pasivna rečenica bez linkova |
| Datum rođenja, 2FA, SMS | **Ne postoje** | — |
| Potvrda emaila | **Kodom** (6 cifara), preko vlastitog SMTP-a (Resend) | ADR-0010 kaže obavezna, bez mehanike |
| Praćenje rušenja | **Firebase Crashlytics**, ne Sentry | `07 §7` Sentry |
| Pisanje recenzija | **Ulazi** | van MVP-a (§7) |
| Sedmični kalendar u Meluri | **Ulazi** | Faza 2 (§7, FE-403 dug) |
| Lista čekanja | **Ulazi** | nije bila planirana |
| Plaćanje | ostaje **van aplikacije** | isto |

Sve što ulazi raspisano je u [`tasks/zero-crisis/`](../../tasks/zero-crisis/). Kad su ti taskovi
gotovi, **nema novih featurea do lansiranja** — samo `tasks/polishing/` i regresija.

## Razmatrane opcije

- **Telefon kao opcionalno polje** — odbačeno: salon ne može računati na podatak koji polovina
  klijenata preskoči, a Apple 5.1.1(v) dozvoljava obavezan podatak koji je direktno vezan za
  funkciju (rezervacija).
- **SMS verifikacija telefona** — odbačeno: trošak po poruci, a broj služi salonu za poziv, ne kao
  identitet.
- **Super admin kao dio Melure** (uloga `platform_admin`) — odbačeno: platformska prava u
  aplikaciji koju koriste saloni su nova površina za curenje između tenanata; lokalni alat sa
  service ključem je nikad ne dobija.
- **Crashlytics izostaviti uz dobro testiranje** — odbačeno: testovi ne hvataju rušenja na tuđem
  uređaju (stari Android, malo memorije, drugi jezik sistema); Firebase je već u projektu.

## Posljedice

- `docs/06 §3.1` više ne važi: forma registracije ima ime i telefon, a Melura ih prikazuje.
  Data safety i App Privacy formulari navode ime, email i telefon kao obavezne.
- Super admin koristi **service role ključ lokalno** — ključ nikad ne smije u repo ni u build.
- Lista čekanja i recenzije dodaju nove tabele sa RLS-om — svaka traži `security.md` dopunu i
  negativan test.
- Sedmični kalendar je primarno za tablet i računar; na telefonu ostaje dnevni prikaz kao default.
