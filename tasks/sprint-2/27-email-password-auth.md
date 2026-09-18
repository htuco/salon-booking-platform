# Task 27 — Client email + lozinka umjesto OTP-a

| | |
|---|---|
| **Status** | Demo kod implementiran; hostovani Supabase još nije konfigurisan |
| **Procjena** | Demo 2–3 dana; produkcijski email dodatno 2–3 dana + dokaz SMTP/deep linka |
| **Zavisi od** | Demo: [13](13-client-login-ekran.md) i Supabase pristup; produkcija: SMTP i finalni callback domen |
| **Blokira** | Produkcijsku email prijavu i store release |
| **Reference** | [Demo zahtjevi](../../docs/08-vitez-admin-demo-requirements.md) · [06 §2.1](../../docs/06-auth-login-flow.md) · [ADR-0010](../../docs/adr/0010-email-lozinka-umjesto-otp-a.md) |

## Cilj

Zamijeniti klijentski email OTP klasičnom registracijom i prijavom emailom i lozinkom, uz
potvrdu adrese, oporavak lozinke i povratak na sačuvani booking flow. Apple i Google nisu dio ove
zamjene i nastavljaju raditi kroz postojeći `AuthConfig`.

Implementacija demo faze je počela 16.09.2026. Dart kod i lokalni Supabase config koriste password
tok; hostovani projekat još nije promijenjen jer lokalni CLI nema pristup projektu ni potvrđenu
connection string putanju.

## Dogovorene faze

### Faza A — Vitez + admin demo

- Konfigurišu se samo `barberstudiovitez` i admin aplikacija.
- Apple i Google ostaju stvarni provideri; nekonfiguriran provider ne smije glumiti uspjeh.
- Email koristi stvarni `signUp`/`signInWithPassword` i stvarnu Supabase sesiju, ali je potvrda
  emaila isključena i SMTP se ne koristi.
- Confirmation, recovery i migracija OTP korisnika nisu dio demo faze.
- Admin koristi unaprijed kreiran i potvrđen Supabase nalog vezan samo za Vitez salon.
- Potpuni scope i kriteriji prihvata su u
  [demo zahtjevima](../../docs/08-vitez-admin-demo-requirements.md).

Stanje demo faze 16.09.2026:

- [x] Klijentski OTP UI i repository metode zamijenjeni su prijavom i registracijom lozinkom.
- [x] Validacija traži najmanje osam znakova, slovo i cifru; email se trimuje, lozinka ne.
- [x] Signup bez sesije javlja konfiguracijsku grešku umjesto da obeća email koji demo ne šalje.
- [x] Widget i repository testovi pokrivaju prijavu, registraciju, greške i povratak u booking flow.
- [x] Bezlični `availability_signals` Realtime signal osvježava slotove i za tuđe rezervacije;
      RLS test potvrđuje da ne izlaže appointment podatke.
- [ ] Na hostovanom projektu isključiti **Confirm email** za trajanje demo faze.
- [ ] Deployati migracije i seed na hostovani projekat; trenutno nema ni `public.salons`.
- [ ] Odigrati registraciju, prijavu i booking protiv hostovanog projekta na uređaju.

### Faza B — produkcijski email

Ostatak ovog taska opisuje ciljnu produkcijsku varijantu: potvrdu adrese, resend, recovery,
SMTP, callbacke i migraciju starih OTP korisnika. Demo odstupanje ne mijenja proizvodnu odluku.

## Korisnički tokovi

### Postojeći korisnik

1. Na login ekranu izabere **Nastavi sa emailom**.
2. Ekran **Prijava** traži email i lozinku, nudi prikaz/sakrivanje lozinke i link
   **Zaboravili ste lozinku?**.
3. `signInWithPassword` vraća sesiju.
4. Korisnik se vraća na originalni `from` route; booking draft ostaje netaknut.

Poruka za pogrešne podatke je uvijek: **Pogrešan email ili lozinka.** Ne razdvaja nepostojeći
email od pogrešne lozinke.

### Novi korisnik

1. Sa ekrana prijave otvara **Kreiraj račun**.
2. Unosi email, lozinku i ponovljenu lozinku.
3. App lokalno validira format emaila, podudaranje lozinki i javno password pravilo, zatim poziva
   `signUp(email, password, emailRedirectTo)`.
4. App prikazuje stanje **Potvrdite email** i dugme **Pošalji ponovo** sa cooldownom.
5. Link iz poruke potvrđuje adresu i vraća korisnika u isti flavor.
6. Nakon valjane sesije app osigurava `AuthIdentity`/`Customer` kao i za social login i vraća
   korisnika na rezervaciju.

Ako je aplikacija bila ugašena, lokalno sačuvani booking draft vraća uslugu, radnika, vrijeme i
sigurni `from` route. Lozinka se nikad ne sprema. Ako je slot zauzet tokom potvrde, postojeći
`409` vraća korisnika na izbor termina.

### Zaboravljena lozinka

1. Korisnik unosi email i poziva se `resetPasswordForEmail` sa tenant callbackom.
2. App uvijek prikazuje: **Ako račun postoji, poslali smo upute za promjenu lozinke.**
3. Link otvara `/auth/new-password`; auth listener prepoznaje `passwordRecovery`.
4. Korisnik unosi novu lozinku dvaput; `updateUser` je mijenja.
5. Nakon uspjeha ide na prijavu ili originalni sigurni `from` route prema stanju sesije.

## Ekrani i rute

- `/auth/login?from=<dozvoljena-ruta>` — provider izbor.
- `/auth/email/sign-in?from=...` — email + lozinka.
- `/auth/email/sign-up?from=...` — email + lozinka + ponovljena lozinka.
- `/auth/email/check-inbox?mode=signup` — potvrda i resend.
- `/auth/forgot-password` — zahtjev za recovery poruku.
- `/auth/new-password` — nova lozinka nakon valjanog recovery događaja.

Sve `from` vrijednosti prolaze kroz postojeću allow-listu ruta. Callback ne smije prihvatiti
proizvoljan vanjski URL.

## Repository ugovor

Demo ugovor koji je sada u kodu zamjenjuje OTP metode:

```dart
abstract interface class AuthRepository {
  Stream<AuthSession?> get sessionChanges;
  AuthSession? get currentSession;

  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  });
  Future<AuthSession> signUpWithPassword({
    required String email,
    required String password,
  });

  Future<AuthSession> signInWithApple();
  Future<AuthSession> signInWithGoogle();
  Future<AuthSession> signInWithFacebook();
  Future<AuthSession> continueAsGuest({required String name});
  Future<void> signOut();
  Future<void> deleteAccount();
}
```

Produkcijska faza proširuje ugovor sa `EmailSignUpResult`, resend, recovery i update-password
metodama. `EmailSignUpResult` tada mora razlikovati najmanje:

- potvrda poslana, još nema sesije;
- sesija postoji (dozvoljeno samo u lokalnom testnom okruženju bez confirmationa);
- zahtjev je odbijen mapiranim `ApiError` tipom.

Supabase tipovi ne izlaze iz `core_api`.

## Supabase konfiguracija — cilj implementacije

- Email signup ostaje uključen.
- `enable_confirmations = true` lokalno i **Confirm email = on** na hostovanom projektu.
- `minimum_password_length = 8`.
- `password_requirements = "letters_digits"`.
- Uključiti leaked-password protection ako ga aktivni Supabase plan podržava.
- `secure_password_change = true` za kasniji in-app change-password tok.
- Ukloniti OTP-specifični `magic_link` template iz aktivnog toka.
- Dodati bosanske template za **Confirm signup**, **Reset password** i obavijest o promjeni lozinke.
- Produkcija mora imati vlastiti SMTP sa verifikovanim sending domenom.
- `SITE_URL` mora biti stvarni HTTPS domen, ne localhost i ne custom scheme.
- Tenant callback URL-ovi za potvrdu i reset moraju biti na allow-listi.

Preporučeni proizvodni povratak je:

```text
email → https://<platform-domain>/auth/callback → korisnikov tap "Otvori aplikaciju"
      → ba.<domena>.<flavor>://auth-callback/<signup|recovery>
```

HTTPS međukorak ne smije automatski izvršiti osjetljivu radnju. Eksplicitan tap smanjuje problem
email skenera i in-app browsera; web korisnik na istoj stranici nastavlja bez mobile deep linka.

## Password i sigurnosna pravila

- Email se trimuje prije slanja; lozinka se **ne trimuje** niti mijenja.
- Polja koriste password-manager/autofill hintove i dozvoljavaju paste.
- Lozinka se nikad ne ispisuje u log, analytics ili crash report.
- Server validira password policy; klijent prikazuje isti tekst, ali nije sigurnosna granica.
- Login i reset imaju rate-limit mapiranje. CAPTCHA se uvodi ako produkcijski promet pokaže abuse,
  bez promjene repository ugovora.
- Recovery odgovor je generički. Login odgovor je generički za nepostojeći email i pogrešnu
  lozinku.
- Social-only korisniku se ne obećava password login dok taj scenario nije zasebno dokazan;
  social provider i email provider ne smiju tiho napraviti dva `AuthIdentity` reda.

## Migracija postojećih OTP korisnika

OTP korisnici već imaju Supabase email identitet, ali nemaju postavljenu lozinku. Nakon releasea:

- na email ekranu vide objašnjenje **Ranije ste koristili kod? Postavite lozinku**;
- radnja koristi isti recovery tok;
- postojeći `auth.users.id`, `AuthIdentity`, `Customer` i termini ostaju isti;
- ne radi se SQL migracija password hashova i ne kreira se novi auth user.

Prije produkcije testirati stvarnog korisnika kreiranog starim `signInWithOtp` tokom migracije na
lozinku. To je obavezan regresijski slučaj, ne pretpostavka.

## Greške koje UI mora razlikovati

| Slučaj | Poruka / ponašanje |
|---|---|
| Pogrešan email ili lozinka | Jedna generička poruka |
| Email nije potvrđen | Otvori `check-inbox`, ponudi resend |
| Slaba lozinka | Prikaži serverovo javno pravilo bez tehničkog koda |
| Signup sa adresom koja možda već postoji | Ne potvrđuj postojanje; na `check-inbox` ekranu ponudi prijavu ili reset |
| Rate limit | Jasna poruka da korisnik sačeka; resend dugme ostaje zaključano |
| Mreža nedostupna | Booking draft ostaje; ponovni pokušaj ne duplira signup |
| Nevažeći/istekli link | Ponudi novi confirmation/reset zahtjev |
| Callback za drugi flavor | Odbij povratak; ne mijenjaj tenant kontekst |

## Definicija gotovog

- [x] OTP metode i OTP UI više nisu aktivni u klijentskoj aplikaciji.
- [ ] Registracija, potvrda emaila, prijava, odjava i reset lozinke rade na iOS-u i Androidu.
- [ ] Web varijanta istih tokova radi bez mobile schemea.
- [ ] Booking draft preživi izlazak u email aplikaciju i hladni povratak.
- [ ] Stari OTP korisnik postavi lozinku bez novog `auth.users`/`AuthIdentity` reda.
- [ ] Pogrešni login i recovery ne otkrivaju postoji li email.
- [ ] Lozinka od 7 znakova i lozinka bez cifre padaju na serveru; prihvatljiva lozinka prolazi.
- [ ] Confirmation i recovery link za tenant A ne može otvoriti tenant B kontekst.
- [ ] SMTP templatei su bosanski, branding-neutralni i dokazani stvarnom porukom.
- [ ] Testovi pokrivaju uspjeh, sve mapirane greške, resend cooldown, cold-start callback i
      očuvanje booking drafta.
- [ ] Fizički iPhone i Android uređaj prolaze signup → potvrda → booking i
      forgot-password → nova lozinka → login.
- [ ] `docs/06`, konzolni checklist i status taska se ažuriraju dokazima u istoj promjeni.

## Ne ulazi u ovaj task

- uklanjanje Apple ili Google providera;
- guest flow (Facebook je skinut — [ADR-0011](../../docs/adr/0011-facebook-login-se-ne-implementira.md));
- MFA/passkeys;
- promjena admin prijave, koja već koristi poseban `StaffRepository` i email + lozinku;
- ručno upravljanje lozinkama iz super-admin baze.
