# Auth tok krajnjeg korisnika — registracija, podaci, potvrda emaila, spam

Istraživanje, 2026-10-12. Povod: prvi prolaz vlasnika proizvoda kroz Authentic na iPhoneu.
Nalazi: „nemamo polje za ime i prezime ni telefon", „email i telefon se ne mogu mijenjati",
„tok prijave je klimav", „povuci ime i sliku od Applea/Googlea", „ToS na registraciji", „potvrda
emaila kodom i povratak na unos koda kad se korisnik vrati".

Izvori: kod i dokumentacija repoa (stanje grane `fix/client-navigacija-prijava-termini`),
Apple App Review Guidelines (*Last Updated: June 8, 2026*), Google Play Help, Supabase i Resend
dokumentacija, pročitano 2026-10-12. Store politike zastarijevaju brzo — provjeriti prije submissiona.

## 1. Stanje danas

| Tema | Stanje | Dokaz |
|---|---|---|
| Polja na registraciji | email, lozinka, ponovljena lozinka. **Nema imena ni telefona** | `login_screen.dart` (forma) |
| Ime klijenta za salon | `ensure_customer` uzima `p_name` → `display_name` iz auth metapodataka → **`'Klijent'`**. Klijent ne šalje `p_name`, a `on conflict do nothing` ime nikad ne osvježi | `20260912120000_ensure_customer.sql:77,84` |
| Šta vidi Melura | „Klijent", „Bez broja", broj posjeta. Email nikad. **Svi email klijenti izgledaju isto** | `clients_screen.dart:22-41` |
| Izmjena podataka | „Moj račun" je samo za čitanje + brisanje. Nema RPC-a za klijentski profil ni promjenu emaila | `account_screen.dart:97-111` |
| Apple / Google | Paketi i `signInWithIdToken` postoje. Apple ime se čuva u `full_name` samo prvi put. **Google slika se nigdje ne čita** | `supabase_auth_repository.dart:115-241` |
| ToS | Pasivna rečenica bez linkova, samo na koraku 4 i izboru providera — **ne i na email formi**. Prihvatanje se ne bilježi | `app_bs.arb:458` |
| Potvrda emaila | Nema ekrana za kod, nema `verifyOTP`/`resend`. `email_not_confirmed` je slijepa ulica (poruka, bez akcije). Android nema intent-filter za deep link | `login_controller.dart:8`, `AndroidManifest.xml:29-32` |
| Spam | Supabase rate limiti (30 prijava/5 min po IP). CAPTCHA zakomentarisan. **`book_appointment` nema limit otvorenih zahtjeva po klijentu** | `config.toml:207-231` |
| Klimava mjesta | Novi email korisnik: ~5 tapova (forma se otvara na *prijavi*, pa „Nemate račun?"). `user_already_exists`/`weak_password` → „ovaj način prijave nije dostupan". Forma prijave provjerava pravila registracije. Nema „Zaboravili ste lozinku?". Demo tekst „ne šaljemo email potvrdu" je u UI-ju | `error_mapper.dart:89-97`, `app_bs.arb:642` |

## 2. Odluke koje ovo dira

| Odluka | Gdje | Šta istraživanje kaže |
|---|---|---|
| **Telefon se ne traži od klijenta** — push zamjenjuje poziv i SMS, ekran manje, manje ličnih podataka | `docs/06 §3.1`, `docs/01 §7` | **Novi podatak:** na uređaju se pokazalo da salon u Meluri ne razlikuje klijente („Klijent", „Bez broja"), a task 58 (kontakt jednim tapom) bez broja nema šta zvati. Telefon kao **polje bez SMS verifikacije** ne dodaje ekran ni trošak. → **ADR** |
| Ime „dolazi iz računa i nikad se ne kuca" | `docs/06:52` | Važi za Apple/Google. Za email račun ime ne dolazi ni odakle — zato je danas „Klijent" |
| Login na kraju booking flowa, ne na ulazu | `docs/06 §3` | Ostaje. Polja idu u istu formu, ne u novi korak |
| Email + lozinka, potvrda obavezna u produkciji | ADR-0010 | Ostaje; ovdje se razrađuje **kako** (kod, ne link) |
| Bez Facebooka | ADR-0011 | Ostaje |

## 3. Pravila storeova koja oblikuju tok

| Pravilo | Posljedica za nas |
|---|---|
| **Apple 4.8:** čim postoji Google prijava, mora postojati i Sign in with Apple (ili ekvivalent). Samo email+lozinka je izuzet | Apple ostaje uz Google na iOS-u — već tako odlučeno (`docs/06 §8.1`) |
| **Apple HIG / 4.0:** poslije Sign in with Apple ne tražiti ponovo ime ni email; dodatni podaci samo ako su stvarno potrebni i jasno označeni | Apple korisnik ne kuca ime. Telefon smije tražiti — jedan ekran „Dopuni profil", polje označeno kao obavezno, sa razlogom |
| **Apple:** ime stiže **samo pri prvoj** autorizaciji | Sačuvati odmah (već se radi). Ako se izgubi, korisnik ga upiše na „Dopuni profil" |
| **Apple Hide My Email:** relay adresa je ista za sve app-e jednog developer naloga; slanje na nju traži registrovanu domenu pošiljaoca (SPF) kod Applea, max 100 mailova/dan po relay adresi | Domena pošiljaoca se registruje kod Applea zajedno sa Resendom. Email na relay adresi se ne mijenja iz app-e |
| **Apple 5.1.1(v)/(iii):** ne tražiti lične podatke koji nisu direktno vezani za funkciju | Ime i telefon su opravdani za rezervaciju („salon vas može kontaktirati ako se termin mijenja"). **Datum rođenja ne** — Apple ga dozvoljava samo zbog zakona o djeci (5.1.4), a age rating ga ne traži |
| **Apple 5.1.1(v):** brisanje računa u app-i; Sign in with Apple mora opozvati token | Brisanje postoji; **opoziv Apple tokena fali** (`delete-account/index.ts:116`) |
| **Google Play:** brisanje računa u app-i **i javna web stranica** za zahtjev za brisanje, link u Play Consoleu | Treba stranica na domeni projekta (npr. `/brisanje-racuna`) |
| **Google Play Data safety:** ime, email, telefon su posebne kategorije, svaka obavezna ili opcionalna | Formular se popunjava po ovoj odluci |
| ToS: nijedan store ne traži checkbox; obavijest je norma (Treatwell: „By submitting this form you agree…") | Obavijest ispod dugmeta, sa linkovima, **i zapis prihvatanja u bazi** (verzija + vrijeme) |

Konkurencija: **Booksy** — email, ime, telefon, SMS kod; email i telefon se mijenjaju u profilu.
**Treatwell** (web) — ime, prezime, email, lozinka; ToS kao obavijest; bez telefona i datuma
rođenja. **Fresha** — politika privatnosti navodi ime, datum rođenja, telefon…; tačna polja
klijentske registracije nisu provjerena. Planity nije provjeren.

## 4. Potvrda emaila kodom

Supabase preporučuje **6-cifreni kod umjesto linka**: email skeneri otvaraju linkove unaprijed i
troše token, a kod ne traži deep link (Android danas nema intent-filter).

- Šablon *Confirm sign up* sa `{{ .Token }}`; `otp_length` 6, `otp_expiry` 3600 s (default).
- `signUp(email, password, data: {full_name, phone}, captchaToken?)` → sesija je `null` → ekran
  „Unesite kod" (booking draft ostaje).
- `verifyOTP(type: OtpType.email, token, email)` → sesija → povratak na korak 4.
  (`OtpType.signup` je u dokumentaciji označen kao zastario.)
- „Pošalji ponovo": `resend(type: OtpType.signup, email)`, dugme sa odbrojavanjem 60 s
  (Supabase dozvoljava jedan email u 60 s po korisniku).
- **Povratak poslije izlaska iz app-e:** email koji čeka potvrdu i booking draft čuvaju se lokalno
  (`shared_preferences`). Na startu, ako postoji nepotvrđen email → ekran za kod. Na prijavi koja
  vrati `email_not_confirmed` → automatski `resend` i isti ekran. Ovo nije dokumentovan Supabase
  obrazac nego naša preporuka.
- `signUp` za već potvrđen email vraća **lažnog korisnika** (anti-enumeracija), pa ekran za kod
  mora imati izlaz „Već imate račun? Prijavite se".

## 5. Slanje emaila — Resend + Supabase SMTP

Ne treba hosting provajder za mail. Treba **domena** (registrar, npr. GlobalHost) i **Resend**
kao servis koji šalje. GlobalHost samo drži DNS zapise.

| Korak | Gdje | Šta |
|---|---|---|
| 1 | Resend | Dodaj domenu, preporuka **poddomena** (npr. `mail.<domena>`) |
| 2 | GlobalHost DNS panel | Zapisi koje Resend pokaže: MX `send` → `feedback-smtp.<regija>.amazonses.com` (prioritet 10), TXT `send` → `v=spf1 include:amazonses.com ~all`, TXT `resend._domainkey` → DKIM ključ, TXT `_dmarc` → `v=DMARC1; p=none; …` |
| 3 | Supabase → Auth → SMTP | Host `smtp.resend.com`, port 465, user `resend`, lozinka = Resend API ključ, pošiljalac `noreply@mail.<domena>` |
| 4 | Supabase → Auth → Rate limits | Podići limit emailova (custom SMTP počinje na 30/h) |
| 5 | Apple Developer | Registrovati domenu pošiljaoca za Private Email Relay |

Cijena: **Resend Free — 3.000 mailova mjesečno, 100 dnevno, 3 domene**; Pro 20 $/mj za 50.000.
Alternative: Brevo besplatno 300/dan, AWS SES 0,10 $ na 1.000. Supabase ugrađeni SMTP (2/h, samo
adrese tima) **nije za produkciju**.

## 6. Spam bez 2FA

| Mjera | Šta zaustavlja | Trošak |
|---|---|---|
| **Potvrda emaila kodom** | Lažne i tuđe adrese; bot mora imati pravo sanduče | Resend free |
| **Limit otvorenih zahtjeva po klijentu** (npr. max 2 `pending` po salonu), u `book_appointment` | Jedan račun koji zatrpa salon zahtjevima | Migracija + pgTAP |
| **Istek neodgovorenih zahtjeva** (`expire-pending`) | Zahtjevi koji zauvijek drže termin | Cron + Edge Function |
| **Odobravanje salona** (`manual` mod) | Već postoji | — |
| Supabase rate limiti po IP | Masovne registracije | Već postoji |
| CAPTCHA (Turnstile/hCaptcha) | Botovi na registraciji | Nema službenog Flutter widgeta (`cloudflare_turnstile` je neslužben); **tek ako se zloupotreba pojavi** |

## 7. Preporuka

1. **Registracija emailom = jedna forma:** ime i prezime, telefon, email, lozinka (jednom, sa
   „prikaži lozinku" umjesto ponavljanja). Ispod dugmeta obavijest „Kreiranjem računa
   prihvatate **Uslove** i **Politiku privatnosti**" sa linkovima. Forma se otvara na
   **registraciji**, „Već imate račun? Prijavite se" je sekundarno dugme.
2. **Apple / Google:** ime (i Google slika) iz providera, bez ponovnog pitanja. Ako fali telefon
   (ili Apple ime), jedan ekran **„Dopuni profil"** sa samo onim što fali.
3. **Potvrda kodom** (§4) preko **Resenda** (§5), sa nastavkom poslije izlaska iz app-e.
4. **Telefon bez SMS verifikacije**, obavezan, sa razlogom ispod polja. **Datum rođenja se ne
   traži.** **2FA ne postoji.** Ovo mijenja `docs/06 §3.1` → **ADR**.
5. **Profil se može mijenjati:** ime i telefon slobodno; email kroz `updateUser` sa kodom
   (*Secure email change* šalje na obje adrese); Apple relay email se ne mijenja. Promjena se
   upisuje i u `customers` red svakog salona tog korisnika (salon ne mijenja klijentovo ime —
   admin nema izmjenu klijenta).
6. **Zapis prihvatanja ToS-a** (verzija + vrijeme) na identitetu. *Odluka vlasnika proizvoda
   (2026-10-12): checkbox, ne samo obavijest — v. ADR-0029.*
7. **Spam:** potvrda + limit otvorenih zahtjeva + istek zahtjeva. CAPTCHA tek kad zatreba.
8. **Store obaveze:** web stranica za brisanje računa (Google), opoziv Apple tokena pri
   brisanju, registracija domene pošiljaoca kod Applea.
9. **Sitnice odmah:** mapirati `user_already_exists` i `weak_password`; forma prijave ne provjerava
   pravila registracije; ukloniti demo tekst; „Zaboravili ste lozinku?" (task 57).

Zamke:
- `ensure_customer` sa `on conflict do nothing` znači da **postojeći** klijenti ostaju „Klijent"
  dok se profil ne sačuva — migracija mora osvježiti ime i telefon iz identiteta.
- Apple ime stiže jednom: ako se `full_name` ne upiše u prvoj sesiji, nema ga više.
- Jedna relay adresa za sve tenante: korisnik koji sakrije email ima istu relay adresu u Authenticu
  i Amku. Salon je ionako ne vidi (Melura ne prikazuje email).
