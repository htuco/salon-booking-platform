# Task 12 — konzole, korak po korak

Sve iz [taska 12](12-auth-provideri.md) što se **ne može uraditi iz repoa**, jer traži naloge koji
nisu na ovoj mašini: Supabase, Google Cloud i Apple Developer. Social konfiguracija čeka konzole;
email + lozinka dodatno čeka implementaciju [taska 27](27-email-password-auth.md). Postojeći OTP
kod nije dokaz ciljnog password toka.

Redoslijed je namjeran: Google i Apple **prave** client ID-eve, Supabase ih samo **prima**. Ako
kreneš od Supabasea, na trećem koraku nemaš šta upisati.

Kolona "gdje završi" govori gdje vrijednost ide kad je dobiješ — nijedna ne ide u git.

| # | Konzola | Šta radiš | Gdje završi |
|---|---|---|---|
| 1 | Google Cloud | Web + Android + iOS OAuth client | GitHub `vars`, Supabase |
| 2 | Apple Developer | Sign In with Apple na App ID-u | Supabase |
| 3 | Supabase | Uključi providere, upiši redirect URL-ove | — |
| 4 | GitHub | `vars` i `secrets` | — |
| 5 | Lokalno | Dokaz signup/login/recovery toka | — |

---

## 1. Google Cloud — tri OAuth klijenta po tenantu

<https://console.cloud.google.com/apis/credentials>

**Prvo jednom za cijeli projekat:** OAuth consent screen (*APIs & Services → OAuth consent screen*).
Tip **External**, ime app-a i support email su vidljivi korisniku u dijalogu prijave. Scope-ovi su
samo `email`, `profile`, `openid` — to su non-sensitive scope-ovi i **ne traže Google verifikaciju**,
pa ovdje nema čekanja.

Zatim, **po svakom flavoru** (`barberstudiovitez`, `beautystudiotravnik`), *Credentials → Create
credentials → OAuth client ID*, tri puta:

**a) Web application** — ime npr. `salon-web-shared`.
Ovo je `serverClientId`: ono što Supabase provjerava kao `aud` u ID tokenu. **Jedan web klijent za
sve flavore je u redu** — korisnik ga nikad ne vidi. Zapiši **Client ID** i **Client secret**.

**b) Android** — po flavoru, jer traži `applicationId`:

| flavor | package name |
|---|---|
| `barberstudiovitez` | `ba.nasadomena.barberstudiovitez` |
| `beautystudiotravnik` | `ba.nasadomena.beautystudiotravnik` |

Traži i SHA-1 otisak. **Debug i release su različiti** — to je najčešća greška iz `docs/06 §7.1`:
Google login radi u debugu i pada u produkciji. Napravi **oba klijenta**, za oba otiska.

```bash
# debug — isti keystore za sve flavore, pravi ga Android SDK sam
keytool -list -v -alias androiddebugkey -storepass android \
  -keystore ~/.android/debug.keystore | grep SHA1

# release — keystore još ne postoji (otvoreno iz taska 04)
keytool -list -v -alias <alias> -keystore <putanja-do-release.jks> | grep SHA1
```

> Release keystore je **otvorena stavka iz taska 04**. Dok ga nema, napravi samo debug klijente i
> vrati se ovdje kad keystore postoji — inače ćeš morati praviti release klijente dvaput.

**c) iOS** — po flavoru, traži bundle ID (isti string kao package name gore).
Zapiši **Client ID**. Google ti daje i `REVERSED_CLIENT_ID` (client ID sa obrnutim segmentima) —
treba za `Info.plist` URL shemu, v. "Ostalo za task 13" na dnu.

**Šta mi pošalji / upiši:** za oba flavora — web client ID + secret, Android client ID (debug i
release), iOS client ID.

---

## 2. Apple Developer — Sign In with Apple

<https://developer.apple.com/account/resources/identifiers/list>

Apple je **obavezan na iOS-u** čim postoji ijedan drugi social provider; bez njega App Review odbija
build po pravilu 4.8 (`docs/06 §7.2`). Nije opcija koju biramo.

Po flavoru:

1. *Identifiers* → App ID za taj bundle ID (`ba.nasadomena.<flavor>`). Ako ne postoji, napravi ga.
2. U *Capabilities* uključi **Sign In with Apple**, pa *Save*.
3. To je sve. **Ne treba Services ID ni privatni ključ** — oni su za web OAuth flow, a mi idemo
   nativno (`signInWithIdToken`, `docs/06 §6.1`). Supabaseu se za nativni iOS tok upisuje samo
   bundle ID.

**Jednom za sve tenante**, ne po flavoru:
*Services → Sign in with Apple for Email Communication* → verifikuj domen sa kojeg šalješ mailove
(`nasadomena.ba`) i registruj sender adresu. Bez toga Apple **ne prosljeđuje** mailove korisnicima
koji su sakrili adresu iza private relaya — a to je veliki dio njih. Ovo traži DNS zapis, pa ga
uradi rano.

> `docs/06 §7.2` nosi upozorenje koje vrijedi zapamtiti: Supabase podrška za **više Apple client
> ID-eva** u jednoj listi je slabije dokumentovana od Google varijante. Testiraj drugi flavor prije
> nego uzmeš trećeg iOS klijenta.

**Šta mi pošalji:** potvrdu da je capability uključen za oba bundle ID-a.

---

## 3. Supabase konzola

<https://supabase.com/dashboard> → projekat → *Authentication*

**a) Sign In / Providers → Email**

- **Enable** ostaje uključen
- **Confirm email** → uključi
- Minimum password length → **8**; zahtjev → najmanje slova i cifre
- Uključi leaked-password protection ako ga plan podržava
- Postavi stvarni HTTPS `Site URL` i confirmation/recovery callbacke iz taska 27
- *Emails → Templates*: prevedi **Confirm signup**, **Reset password** i obavijest o promjeni
  lozinke; OTP-specifični Magic Link template više nije aktivni klijentski tok
- Prije produkcije poveži vlastiti SMTP i verifikuj sending domen

**b) Sign In / Providers → Google**

- **Enable**
- **Client IDs**: comma-separated, **web client ID prvi** (`docs/06 §7.1`), pa Android i iOS ID-evi
  svih flavora:
  `<web>,<android-barber-debug>,<android-barber-release>,<ios-barber>,<android-beauty-...>,<ios-beauty>`
- **Client Secret**: secret web klijenta iz koraka 1a

**c) Sign In / Providers → Apple**

- **Enable**
- **Client IDs**: comma-separated lista bundle ID-eva:
  `ba.nasadomena.barberstudiovitez,ba.nasadomena.beautystudiotravnik`
- Secret ostavi prazno — nativni tok ga ne traži

**d) URL Configuration → Redirect URLs**

Postojeći login callbacki ostaju za social providere:

```
ba.nasadomena.barberstudiovitez://login-callback
ba.nasadomena.beautystudiotravnik://login-callback
```

Lista je *exact match*. Novi tenant koji nije dobio svoj red ovdje završi na "requested path is
invalid" umjesto u app-i. Iste dvije vrijednosti su već upisane u `supabase/config.toml` za lokalni
stack — konzola i taj fajl se drže u paru.

Za email confirmation i recovery dodaj i stvarni HTTPS callback sa finalne platform domene. On
mora korisniku ponuditi eksplicitan povratak u odgovarajući flavor; detalji i rute su u
[tasku 27](27-email-password-auth.md). Ne kreiraj produkcijske URL-ove sa placeholder domenom.

---

## 4. GitHub — gdje vrijednosti žive

Client ID **nije tajna** (putuje u buildu i vidi ga svako ko raspakuje APK), ali se mijenja po
tenantu i okruženju — zato `vars`. Secret ide u `secrets`.

```bash
# po flavoru — imena moraju biti tačno ovakva, build_tenant.sh ih tako traži
gh variable set GOOGLE_WEB_CLIENT_ID_BARBERSTUDIOVITEZ --body "<web-client-id>"
gh variable set GOOGLE_IOS_CLIENT_ID_BARBERSTUDIOVITEZ --body "<ios-client-id>"
gh variable set GOOGLE_WEB_CLIENT_ID_BEAUTYSTUDIOTRAVNIK --body "<web-client-id>"
gh variable set GOOGLE_IOS_CLIENT_ID_BEAUTYSTUDIOTRAVNIK --body "<ios-client-id>"

# secret Google klijenta — treba samo Supabaseu, ne buildu; ovdje stoji za Edge Functions
gh secret set SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET
```

`tool/build_tenant.sh` traži prvo `<IME>_<FLAVOR>`, pa tek onda zajednički `<IME>`. Lokalno:

```bash
GOOGLE_WEB_CLIENT_ID_BARBERSTUDIOVITEZ="..." \
GOOGLE_IOS_CLIENT_ID_BARBERSTUDIOVITEZ="..." \
tool/build_tenant.sh barberstudiovitez apk debug
```

Skripta ispisuje **da li** je ID stigao i iz koje varijable, ali nikad samu vrijednost — build log
je artefakt koji se čuva.

> Isti korak je trenutak da se konačno postave i `SUPABASE_URL` i `SUPABASE_ANON_KEY`, otvoreni još
> od taska 04. Bez njih app radi na fallback podacima i nijedna prijava ne može proći.

> CI ih neće potrošiti odmah — workflowovi su blokirani naplatom na `htuco` nalogu. Vrijednosti
> ipak postavi sad, da ne budu sljedeće što blokira kad se CI odblokira.

---

## 5. Lokalni dokaz — email + lozinka

Ovo se izvodi nakon implementacije taska 27 i promjene lokalnog Auth configa:

```bash
supabase start
eval "$(supabase status -o env)"   # izlaz sadrzi service role kljuc — nikad u commit

curl -s -X POST "$API_URL/auth/v1/signup" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Testna123"}'
```

Mail ne izlazi napolje — hvata ga Mailpit na URL-u koji vrati `supabase status`. Dokaz nije samo
uspješan `signup`: otvori confirmation poruku, vrati se u app, prijavi se lozinkom, zatraži reset,
postavi novu lozinku i dokaži da stara više ne radi. Ponovi na fizičkom iPhone i Android uređaju
sa produkcijskim SMTP-om prije releasea.

---

## Ostalo za taskove 13 i 27, ne za ovaj

Ove stavke traže prave client ID-eve, pa ih nema smisla raditi prije nego prođeš korak 1:

- **`REVERSED_CLIENT_ID` URL shema u iOS `Info.plist`**, po flavoru. Ide kroz generator
  (`tool/gen_ios_flavors.rb` → `apps/client/ios/flavors/<flavor>.xcconfig`), **ne rukom** — xcconfig
  su generisani fajlovi. Dok nema stvarnog ID-a, u repo ne ide placeholder.
- **`SupabaseAuthRepository`** — implementacija ugovora iz
  `packages/core_api/lib/src/auth/auth_repository.dart`.
- **Provjera na pravom uređaju.** Nativni Apple i Google tok se ne mogu odigrati ni u
  `supabase start` stacku ni u simulatoru bez naloga; to je jedini dokaz koji vrijedi.
