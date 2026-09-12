# Task 12 — Supabase Auth provideri + `AuthConfig` po flavoru

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [07 — app plumbing](../sprint-1/07-app-plumbing.md) |
| **Blokira** | 13, 14, i sve što traži prijavljenog korisnika |
| **Reference** | [06 §1](../../docs/06-auth-login-flow.md) · [06 §2](../../docs/06-auth-login-flow.md) · [06 §7](../../docs/06-auth-login-flow.md) |

## Cilj
Apple, Google i Email OTP rade u Supabase projektu, a aplikacija zna **koji su provideri
dozvoljeni na kojoj platformi** — bez toga Android build nudi Sign in with Apple koji tamo nema šta
da radi.

## Definicija gotovog
- [ ] Provideri uključeni u Supabase konzoli: Apple, Google, Email (OTP, **bez lozinke**)
- [ ] `AuthConfig` u `core_api` filtrira listu po `TargetPlatform` ([06 §2](../../docs/06-auth-login-flow.md))
- [ ] Google client ID-evi **po flavoru** — iOS i Android imaju različite, i idu kao
      comma-separated lista u Supabase config ([06 §7.1](../../docs/06-auth-login-flow.md))
- [ ] Redirect URL-ovi po flavoru registrovani (`ba.nasadomena.<flavor>://login-callback`)
- [ ] Tajne **ne ulaze u repo** — idu u GitHub `secrets` i u `--dart-define` kroz `build_tenant.sh`
- [ ] Unit test: `AuthConfig` na iOS-u vraća Apple, na Androidu ne

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
- Email OTP, **nikad magic link** na mobilnom: link izlazi iz app-a u browser i ne vraća se
  pouzdano ([06 §2.1](../../docs/06-auth-login-flow.md)).
