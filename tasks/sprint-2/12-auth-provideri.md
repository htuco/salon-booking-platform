# Task 12 — Supabase Auth provideri + `AuthConfig` po flavoru

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [07 — app plumbing](../sprint-1/07-app-plumbing.md) |
| **Blokira** | 13, 14, i sve što traži prijavljenog korisnika |
| **Reference** | [06 §1](../../docs/06-auth-login-flow.md) · [06 §2](../../docs/06-auth-login-flow.md) · [06 §7](../../docs/06-auth-login-flow.md) |

> **Promjena plana 16.09.2026.** OTP dijelovi ovog taska su historijski dokaz. Ciljni email tok je
> email + lozinka iz [ADR-0010](../../docs/adr/0010-email-lozinka-umjesto-otp-a.md), a implementacija
> je izdvojena u [task 27](27-email-password-auth.md).

## Cilj
Apple, Google i Email rade u Supabase projektu, a aplikacija zna **koji su provideri
dozvoljeni na kojoj platformi** — bez toga Android build nudi Sign in with Apple koji tamo nema šta
da radi.

## Definicija gotovog
- [ ] Provideri uključeni u Supabase konzoli: Apple, Google, Email; **Confirm email uključen**
      za ciljni password tok
      — **traži tvoj nalog**, v. [konzole checklist](12-konzole-checklist.md) §3
- [x] `AuthConfig` filtrira listu po platformi ([06 §2](../../docs/06-auth-login-flow.md))
      — u `core_domain`, sa vlastitim `AuthPlatform` enumom umjesto `TargetPlatform`;
      odstupanje od originalnog teksta ("u `core_api`") obrazloženo u
      [ADR-0007](../../docs/adr/0007-authconfig-u-core-domain.md)
- [x] Google client ID-evi **po flavoru** — `build_tenant.sh` traži `GOOGLE_WEB_CLIENT_ID_<FLAVOR>`
      pa zajednički; comma-separated lista u Supabase configu je korak u konzoli
      ([06 §7.1](../../docs/06-auth-login-flow.md))
- [x] Redirect URL-ovi po flavoru registrovani (`ba.nasadomena.<flavor>://login-callback`)
      — u `supabase/config.toml`, dokazano u pokrenutom stacku; u konzoli hostovanog projekta
      **ostaje tebi**
- [x] Tajne **ne ulaze u repo** — idu u GitHub `vars`/`secrets` i u `--dart-define` kroz
      `build_tenant.sh`; skripta ispisuje odakle je ID stigao, nikad vrijednost
- [x] Unit test: `AuthConfig` na iOS-u vraća Apple, na Androidu ne

## Koraci
1. Supabase konzola: uključi provideri, upiši redirect URL-ove za oba demo flavora
2. `AuthConfig` + test prije ijednog ekrana — lista providera je podatak, ne `if` u widgetu
3. `build_tenant.sh`: proslijedi client ID kroz `--dart-define`, isto kao `SALON_ID`
4. Commit: `feat(auth): provideri i AuthConfig po platformi`

## Zamke
- **Apple je obavezan na iOS-u** čim postoji ijedan drugi social provider — inače App Review 4.8
  odbija build ([06 §7.2](../../docs/06-auth-login-flow.md)).
- **Client ID je po flavoru, ne po projektu.** Jedan ID za sve tenante znači da korisnik u
  Google dijalogu vidi tuđe ime salona.
- Confirmation i recovery link moraju se vratiti u tačan flavor; nije dovoljno dobiti HTTP 200
  od Auth API-ja ([06 §2.1](../../docs/06-auth-login-flow.md)).


## Status (2026-09-12) — 🟡 kod gotov, konzole čekaju

Ovaj status opisuje tada isporučeni OTP tok. Ne dokazuje niti implementira odluku iz ADR-0010.

Grana `feat/auth-provideri`, PR [#20](https://github.com/htuco/salon-booking-platform/pull/20).

**Šta je napisano.** `AuthConfig`, `AuthProvider`, `AuthPlatform` i `AuthSession` u `core_domain`;
`AuthRepository` ugovor i `authPlatformOf`/`currentAuthPlatform` u `core_api`; `authConfigProvider`
i `visibleAuthProvidersProvider` u klijentu. `auth:` blok u sva tri `tenant.yaml` i u generatoru,
uz validaciju. `build_tenant.sh` prosljeđuje dva Google client ID-a po flavoru. `supabase/config.toml`
sa redirect URL-ovima, OTP templateom i podignutim rate limitom.

**Dvije odluke koje su bile blokada.**

1. `AuthConfig` ide u `core_domain` sa vlastitim `AuthPlatform` enumom, a ne u `core_api` kako je
   stajalo u DoD-u — `docs/06 §6.2` skica sa `TargetPlatform` se **nije mogla kompajlirati**, jer je
   `core_domain` čist Dart. [ADR-0007](../../docs/adr/0007-authconfig-u-core-domain.md), `docs/06`
   ispravljen u istoj promjeni.
2. Lista providera ide u `tenant.yaml` (`docs/06 §7.6`), ne kao hardkodiran default — pa je i
   generator morao naučiti novo polje. Zbog toga je promjena šira od originalnih koraka taska.

**Dokazano pokretanjem:**

- `melos run analyze` čist, `melos run test` **238 testova PASS** (bilo 215): `core_domain` 54,
  `core_api` 48, `core_ui` 40, `client` 92, `admin` 4. Od toga 23 nova u ovom tasku.
- `dart run tool/gen_flavors.dart --check` čist; pokvaren `auth.providers` ključ i vrijednost koja
  nije boolean oboje obore generator sa **izlaznim kodom 1** i imenom flavora u poruci.
- `build_tenant.sh` kroz `bash -x`, sve tri grane: ID po flavoru pretekne zajednički, zajednički se
  koristi uz upozorenje, a kad nema nijednog build prolazi i to kaže.
- **Email OTP odigran do kraja na lokalnom stacku**: `POST /auth/v1/otp` → 200, mail u Mailpitu
  nosi šestocifreni kod i **nijedan link**, `POST /auth/v1/verify` vraća sesiju
  (`providers: ['email']`, `is_anonymous: false`).
- **Trigger iz taska 02 prvi put dokazan stvarnom prijavom**: `public.auth_identities` je dobila red
  sa `providers = {email}` i `last_login_at`. To potvrđuje napomenu da je pola
  [taska 14](14-identitet-i-klijent-upsert.md) već u repou — tamo stvarno preostaje samo `customers`
  upsert.
- Config je stigao do servisa: `GOTRUE_URI_ALLOW_LIST` sadrži oba deep linka, `GOTRUE_MAILER_OTP_LENGTH=6`,
  Google sekcija prepoznata.

**Šta NIJE dokazano, i zašto:**

- **Apple i Google prijava nisu odigrane nijednom.** Traže Apple Developer i Google Cloud naloge
  (tvoje) i **pravi uređaj** — nativni `signInWithIdToken` se ne može odigrati ni u lokalnom stacku
  ni u simulatoru.
- **Nijedan provider nije uključen u konzoli hostovanog projekta.** Cijeli korak 1 taska je tamo.
- **Redirect URL-ovi su dokazani samo lokalno.** Pokušaj da se allowlist dokaže preko REST-a nije
  uspio: Supabase na `/auth/v1/otp` ne odbija nedozvoljen `redirect_to` nego tiho padne na
  `site_url`, pa test vraća 200 u oba slučaja. Dokaz je zato posredan — lista u `GOTRUE_URI_ALLOW_LIST`
  pokrenutog servisa.
- **`SupabaseAuthRepository` ne postoji** — ovdje je samo ugovor. Piše ga
  [task 13](13-client-login-ekran.md).
- **`REVERSED_CLIENT_ID` URL shema u iOS `Info.plist`** nije dodana: traži stvarni client ID, a
  xcconfig su generisani fajlovi u koje placeholder ne ide.
- CI ništa ne potvrđuje — workflowovi su blokirani naplatom.

**Ostalo za sljedećeg:**

```sh
# 1. konzole — jedini blokirajući korak
open tasks/sprint-2/12-konzole-checklist.md

# 2. kad su ID-evi tu, provjera da stvarno stizu do builda
GOOGLE_WEB_CLIENT_ID_BARBERSTUDIOVITEZ=... tool/build_tenant.sh barberstudiovitez apk debug

# 3. lokalni OTP u bilo kojem trenutku, bez ijedne konzole
supabase start && open http://127.0.0.1:54324
```
