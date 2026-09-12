# Task 12 — konzole, korak po korak

Sve iz [taska 12](12-auth-provideri.md) što se **ne može uraditi iz repoa**, jer traži naloge koji
nisu na ovoj mašini: Supabase, Google Cloud i Apple Developer. Kod je gotov i dokazan; ovo je
jedini dio koji čeka tebe.

Redoslijed je namjeran: Google i Apple **prave** client ID-eve, Supabase ih samo **prima**. Ako
kreneš od Supabasea, na trećem koraku nemaš šta upisati.

Kolona "gdje završi" govori gdje vrijednost ide kad je dobiješ — nijedna ne ide u git.

| # | Konzola | Šta radiš | Gdje završi |
|---|---|---|---|
| 1 | Google Cloud | Web + Android + iOS OAuth client | GitHub `vars`, Supabase |
| 2 | Apple Developer | Sign In with Apple na App ID-u | Supabase |
| 3 | Supabase | Uključi providere, upiši redirect URL-ove | — |
| 4 | GitHub | `vars` i `secrets` | — |
| 5 | Lokalno | Dokaz da OTP radi | — |

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
- **Confirm email** → isključi (OTP je sam po sebi potvrda)
- Lozinke ne koristimo nigdje u app-i — login ekran nudi samo OTP

Zatim *Emails → Templates → Magic Link*. Tijelo mora nositi **`{{ .Token }}`**, ne
`{{ .ConfirmationURL }}`. Ovo je jedino mjesto gdje se bira OTP naspram magic linka, i ono što
`docs/06 §2.1` traži: link na mobilnom izlazi iz app-a u browser i ne vraća se pouzdano.

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

Dodaj po jedan red za svaki flavor, **tačno ovako**:

```
ba.nasadomena.barberstudiovitez://login-callback
ba.nasadomena.beautystudiotravnik://login-callback
```

Lista je *exact match*. Novi tenant koji nije dobio svoj red ovdje završi na "requested path is
invalid" umjesto u app-i. Iste dvije vrijednosti su već upisane u `supabase/config.toml` za lokalni
stack — konzola i taj fajl se drže u paru.

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

## 5. Lokalni dokaz — email OTP bez ijedne tuđe konzole

Ovo možeš odmah, ne čeka ništa od gore:

```bash
supabase start
eval "$(supabase status -o env)"   # izlaz sadrzi service role kljuc — nikad u commit

curl -s -X POST "$API_URL/auth/v1/otp" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","create_user":true}'
```

Mail ne izlazi napolje — hvata ga Inbucket na <http://127.0.0.1:54324>. Otvori poruku i provjeri da
u njoj stoji **šestocifreni kod**, a ne link. Ako vidiš link, `{{ .Token }}` nije u templateu.

Rate limit je za lokalni stack podignut na 100 mailova na sat (`supabase/config.toml`); sa
podrazumijevana dva se flow potroši prije nego se vidi.

---

## Ostalo za task 13, ne za ovaj

Ove stavke traže prave client ID-eve, pa ih nema smisla raditi prije nego prođeš korak 1:

- **`REVERSED_CLIENT_ID` URL shema u iOS `Info.plist`**, po flavoru. Ide kroz generator
  (`tool/gen_ios_flavors.rb` → `apps/client/ios/flavors/<flavor>.xcconfig`), **ne rukom** — xcconfig
  su generisani fajlovi. Dok nema stvarnog ID-a, u repo ne ide placeholder.
- **`SupabaseAuthRepository`** — implementacija ugovora iz
  `packages/core_api/lib/src/auth/auth_repository.dart`.
- **Provjera na pravom uređaju.** Nativni Apple i Google tok se ne mogu odigrati ni u
  `supabase start` stacku ni u simulatoru bez naloga; to je jedini dokaz koji vrijedi.
