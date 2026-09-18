# Demo zahtjevi — Vitez klijent i admin

## Status i cilj

Ovaj dokument definiše prvi integrisani demo. Cilj nije produkcijski release nego dokaz da
**Barber Studio Vitez klijentska aplikacija** i **admin aplikacija** zajedno rade nad istim
Supabase projektom, sa stvarnim tenant pravilima i bez zavisnosti od SMTP-a.

Za demo se konfigurišu samo:

1. klijentski flavor `barberstudiovitez`;
2. admin aplikacija;
3. Supabase projekat `olggovhqwirxamggkwuf`;
4. Firebase projekat `hades-75751`, isključivo za push notifikacije.

`beautystudiotravnik`, novi tenant-i i produkcijski store release nisu dio ove faze.

## 1. Važna definicija simulacije emaila

U demou se **simulira email komunikacija**, ne sigurnosna sesija:

- aplikacija koristi stvarni Supabase `signUp` i `signInWithPassword`;
- Supabase vraća stvarnu korisničku sesiju i JWT;
- potvrda email adrese je privremeno isključena;
- ne šalju se confirmation, welcome ni reset poruke;
- vlastiti SMTP, sending domen i email callback nisu potrebni;
- `Zaboravili ste lozinku?` je skriven ili jasno označen kao nedostupan u demo verziji.

Ovo je najkraći demo tok koji još uvijek može dokazati rezervaciju i RLS. Potpuno lokalni lažni
login ne može autorizovati pozive prema hostovanom Supabaseu, pa bi tada i rezervacije i admin
podaci morali biti lažni. Offline `demo_main.dart` ostaje odvojeni vizuelni demo i nije dokaz
integracije.

## 2. Klijentska aplikacija — Barber Studio Vitez

### 2.1 Login opcije

Ekran prijave prikazuje tačno tri opcije:

| Opcija | Demo ponašanje |
|---|---|
| **Nastavi s Appleom** | Stvarni nativni Apple login, samo na podržanom i pravilno potpisanom iOS uređaju |
| **Nastavi s Googleom** | Stvarni Google login sa Vitez OAuth klijentima |
| **Nastavi s emailom** | Stvarna Supabase email+password sesija, bez slanja email poruka |

Social login ne smije prikazati lažni uspjeh. Ako Apple ili Google konzola još nije spremna,
odgovarajuće dugme je onemogućeno uz poruku **Nije konfigurirano za ovaj demo**.

### 2.2 Email registracija i prijava

- Postojeći korisnik unosi email i lozinku i bira **Prijavi se**.
- Novi korisnik bira **Kreiraj račun** i unosi email, lozinku i ponovljenu lozinku.
- Lozinka ima najmanje 8 znakova te sadrži najmanje jedno slovo i jednu cifru.
- Nakon registracije nema ekrana **Provjerite inbox**; korisnik odmah dobija sesiju.
- Pogrešni podaci uvijek prikazuju generičku poruku **Pogrešan email ili lozinka.**
- Lozinka se ne upisuje u log, analitiku, lokalnu bazu, `user_metadata` niti crash report.
- Uspješan login vraća korisnika na sačuvanu rezervaciju.
- Za svakog uspješno prijavljenog korisnika nastaju ili se pronalaze odgovarajući
  `AuthIdentity` i Vitez `Customer` redovi.

### 2.3 Rezervacija

- Korisnik može izabrati uslugu, radnika i slobodan termin prije prijave.
- Izbor ostaje sačuvan tokom prijave.
- Nakon prijave rezervacija se upisuje u stvarnu bazu za Vitez salon.
- Zauzet termin vraća postojeći `409` tok i novi izbor termina; ne pravi dupli booking.
- Korisnik vidi samo vlastite termine i može ih otkazati prema postojećim pravilima.
- Promjena termina, blokade, radnog vremena ili booking postavki mijenja javni bezlični Realtime
  signal salona; klijent zatim ponovo poziva availability RPC. Signal ne izlaže termin, klijenta,
  vrijeme promjene ni kumulativni broj rezervacija.

## 3. Admin aplikacija

Vizuelni handoff i mapa ekrana nalaze se u [`prototype/admin`](../prototype/admin/README.md).
Handoff definiše izgled, ali ne mijenja ni jedan sigurnosni zahtjev ispod.

- Admin koristi stvarni Supabase email+password login; social login se ne prikazuje.
- Demo admin nalog se kreira ručno, označava kao potvrđen i povezuje samo sa Vitez salonom.
- Uloga i pristup dolaze iz server-side membershipa/RLS-a, ne iz lokalnog demo flaga.
- Admin vidi samo Vitez podatke i može pregledati, potvrditi ili odbiti novu rezervaciju.
- Admin aplikacija ne smije prihvatiti običan klijentski nalog.
- Admin lozinka i administratorski tokeni ne ulaze u repo ni dokumentaciju.

Admin login ne može biti samo lokalna simulacija: bez stvarnog Supabase JWT-a RLS ne može
dokazati da je korisnik Vitez administrator.

## 4. Apple, Google i identifikatori

Trenutni bundle/package identifikatori i domen sa `nasadomena` su **demo placeholderi**. Mogu se
koristiti samo za privremenu konzolnu konfiguraciju i testne buildove.

- Za Vitez se registruje jedan iOS App ID i potrebni Google OAuth klijenti.
- Sign in with Apple traži Apple Developer tim koji podržava tu capability; Personal Team nije
  dovoljan za taj dokaz.
- Za Google se registruju samo Vitez Android/iOS klijenti i zajednički web client ID koji
  Supabase koristi za provjeru tokena.
- Admin dobija zasebne Firebase Android/iOS app registracije ako push test uključuje obje
  platforme; Google login se u adminu ne uključuje.
- Prije produkcije finalni domen, bundle ID-evi i package nameovi moraju biti potvrđeni, a zatim
  se prave nove ili ažuriraju postojeće Apple, Google, Firebase i Supabase konfiguracije.

Placeholder identifikatori ne smiju se predstaviti kao finalni store identitet aplikacije.

## 5. Supabase demo konfiguracija

- Email provider je uključen.
- Email confirmation je isključen samo u demo okruženju.
- Apple i Google provider prihvataju samo trenutno konfigurirane Vitez identifikatore.
- Vitez `salon_id` dolazi iz build konfiguracije; korisnik ga ne bira i ne može ga promijeniti.
- Anon/publishable ključ smije biti u runtime konfiguraciji aplikacije jer RLS ostaje sigurnosna
  granica.
- Database password, `service_role`, Supabase access token i administratorske lozinke ostaju
  izvan repoa, build logova i aplikacije.
- Ranije podijeljena database lozinka mora se rotirati prije korištenja projekta.

## 6. Firebase i push

- Firebase se koristi samo za FCM; nije auth provider.
- Konfigurišu se samo Vitez klijent i admin aplikacija.
- `google-services.json`, `GoogleService-Info.plist`, APNs materijal i service-account
  vjerodajnice ne commituju se u repo; dolaze kroz lokalni/CI secret proces.
- Uspješan FCM API odgovor nije dovoljan dokaz. Demo je dokazan tek kada fizički uređaj primi
  notifikaciju i tap otvori očekivani ekran.
- Ako APNs ili fizički uređaj nisu spremni, push se označava kao nedokazan; ostatak demo toka
  može biti prihvaćen odvojeno.

## 7. Van scopea ovog demoa

- stvarni SMTP i verifikovan sending domen;
- potvrda email adrese, resend confirmation i reset lozinke;
- email callback/deep-link tokovi;
- Beauty Studio Travnik i dodatni tenant-i;
- Facebook login i guest login;
- produkcijski domen i finalni store identifikatori;
- store submission i produkcijski release;
- migracija postojećih OTP korisnika na lozinku.

Te stavke pripadaju produkcijskoj fazi iz [taska 27](../tasks/sprint-2/27-email-password-auth.md).

## 8. Kriteriji prihvata

Demo je gotov kada su dokazani svi obavezni koraci:

- [ ] Vitez aplikacija prikazuje Apple, Google i Email opcije bez Facebook/guest opcije.
- [ ] Email registracija bez inboxa stvara stvarnu Supabase sesiju.
- [ ] Email odjava i ponovna prijava istom lozinkom rade.
- [ ] Rezervacija započeta prije login ekrana ostaje sačuvana i nastaje u Vitez salonu.
- [ ] Admin se prijavljuje stvarnim demo admin nalogom i vidi novu Vitez rezervaciju.
- [ ] Admin potvrđuje ili odbija rezervaciju, a klijentsko stanje se pravilno osvježava.
- [ ] Slot zauzet u drugoj sesiji nestaje iz otvorenog klijentskog flowa bez ručnog refresha.
- [ ] Klijentski nalog ne može otvoriti admin podatke.
- [ ] Vitez klijent i admin ne mogu pročitati podatke drugog salona.
- [ ] Apple i Google ili prolaze na fizičkom uređaju ili su eksplicitno označeni kao
      **nije konfigurirano**; nema lažnog uspjeha.
- [ ] Nijedna tajna nije u git diffu, buildu ili logovima.
- [ ] Evidentirano je da su identifikatori demo placeholderi i da SMTP/recovery nisu testirani.
- [ ] Ako je push dio prezentacije, notifikacija je primljena i otvorena na fizičkom uređaju.

## 9. Šta je još potrebno za live dokaz

Kod je implementiran lokalno. Za deploy i dokaz na uređaju još treba:

1. pristup Supabase projektu nakon rotacije database lozinke;
2. Vitez `salon_id` i podatke demo admin naloga kroz siguran kanal;
3. Apple Developer tim koji podržava Sign in with Apple;
4. Google OAuth konfiguraciju za Vitez Android i iOS build;
5. Vitez i admin Firebase app registracije te APNs ključ za iOS push, ako push ulazi u demo;
6. fizički iPhone, a za puni Android dokaz i fizički Android uređaj.

SMTP, finalni domen i produkcijski bundle/package identifikatori nisu blokatori ove demo faze.
