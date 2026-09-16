# Klijentski email provider koristi lozinku umjesto OTP koda

## Status

prihvaćen

## Kontekst

Klijentska aplikacija trenutno ima implementiran email OTP: korisnik unese adresu, prepiše
šestocifreni kod iz poruke i dobije Supabase sesiju. Taj tok je izabran da smanji frikciju i
izbjegne reset lozinke, ali više nije ciljni proizvodni tok.

Nova proizvodna odluka je klasična email autentifikacija: postojeći korisnik se prijavljuje
emailom i lozinkom, a novi korisnik kreira račun emailom i lozinkom. Apple i Google ostaju
zasebni provideri; ovom odlukom mijenja se samo ponašanje providera `email`.

Promjena uvodi tri toka koja OTP nije imao: registraciju, potvrdu email adrese i oporavak
zaboravljene lozinke. Zato nije dovoljno zamijeniti `signInWithOtp` jednim API pozivom.

## Odluka

- Email provider koristi Supabase `signUp` za registraciju i `signInWithPassword` za prijavu.
- Produkcija zahtijeva potvrdu email adrese prije prve prijave. Nepotvrđen račun ne može
  rezervisati termin.
- Login ekran jasno razdvaja **Prijavu** i **Kreiranje računa**. Ne pokušava se automatski
  pogoditi namjera korisnika na osnovu odgovora servera.
- Registracija traži email, lozinku i ponovljenu lozinku. Prijava traži email i lozinku.
- Minimalna lozinka je 8 znakova i mora sadržati slova i cifre. Server je izvor istine; klijentska
  validacija samo ranije prikazuje isto pravilo.
- Produkcija koristi vlastiti SMTP. Supabase testni mail servis nije proizvodna zavisnost.
- Potvrda emaila i reset lozinke vraćaju korisnika u odgovarajući flavor preko dozvoljenog
  callback URL-a. Povratak mora biti dokazan iz stvarnog email klijenta na fizičkom uređaju.
- `Zaboravili ste lozinku?` koristi `resetPasswordForEmail`; nakon `passwordRecovery` auth događaja
  korisnik unosi novu lozinku, a aplikacija poziva `updateUser`.
- Zahtjev za reset uvijek prikazuje istu poruku bez obzira postoji li račun, da se ne omogući
  enumeracija korisnika.
- Booking draft se lokalno sačuva prije izlaska u potvrdu emaila ili reset. Povratak u aplikaciju
  ne smije obrisati uslugu, radnika i termin; postojeći `409` i dalje rješava slot koji je u
  međuvremenu zauzet.
- Lozinka se nikad ne zapisuje u log, analitiku, bazu aplikacije, crash report ili
  `user_metadata`. Hashiranje i provjeru lozinke radi isključivo Supabase Auth.
- Postojeća OTP implementacija ostaje historijski dokaz, ali se uklanja iz aktivnog korisničkog
  toka tek u zasebnom implementacijskom tasku.

## Razmatrane opcije

### Email OTP

Najmanje trenja i nema reset flow, ali je odbačen novom proizvodnom odlukom. Već implementirani
testovi i statusi ostaju zapis onoga što je ranije dokazano, ne opis ciljnog stanja.

### Magic link bez lozinke

I dalje bi izvodio korisnika iz aplikacije i ne bi ispunio odluku da email autentifikacija koristi
lozinku.

### Email i lozinka bez potvrde adrese

Kraći je tok, ali aplikacija tada ne zna da korisnik kontroliše adresu. Pogrešno unesena ili tuđa
adresa može dobiti račun i termine, a oporavak lozinke nije pouzdan. Zato potvrda ostaje obavezna
u produkciji.

### Jedan ekran koji automatski bira login ili registraciju

Smanjuje broj dugmadi, ali odgovor servera može otkriti da li email već postoji i otežava jasne
poruke. Eksplicitne radnje su predvidljivije i lakše za testirati.

## Posljedice

- `AuthRepository`, kontroler, ekran i testovi moraju zamijeniti OTP metode registracijom,
  password loginom, ponovnim slanjem potvrde i recovery metodama.
- `supabase/config.toml` i hostovani projekat moraju uključiti potvrdu emaila, pojačati password
  policy i zamijeniti OTP poruku templateima za potvrdu i reset.
- Svaki flavor dobija callback putanje za potvrdu emaila i reset lozinke; Supabase allow-lista,
  Android intent filteri i iOS URL sheme moraju ostati usklađeni.
- Login flow dobija više ekrana i veću frikciju nego OTP. Mjerenje odustajanja na registraciji
  postaje dio produkcijskog praćenja.
- SMTP postaje blokirajuća produkcijska zavisnost, jer bez emaila korisnik ne može potvrditi račun
  ni vratiti lozinku.
- Plan implementacije i kriteriji prihvata su u
  `tasks/sprint-2/27-email-password-auth.md`.

## Reference

- [Supabase password auth](https://supabase.com/docs/guides/auth/passwords)
- [Supabase Flutter `signUp`](https://supabase.com/docs/reference/dart/auth-signup)
- [Supabase Flutter `signInWithPassword`](https://supabase.com/docs/reference/dart/auth-signinwithpassword)
- [Supabase native mobile deep linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking)
