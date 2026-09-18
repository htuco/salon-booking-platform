# Facebook login se ne implementira

## Status

prihvaćen

## Kontekst

Facebook je od prve verzije specifikacije stajao u ponudi providera, ali nikad nije bio odigran:
`AuthProvider.facebook` je postojao u `core_domain`, `signInWithFacebook()` u ugovoru
`AuthRepository`, a jedina implementacija je bacala grešku „nedostaje paket
`flutter_facebook_auth`". Nijedan tenant ga nije uključio — `auth.providers` u sva tri
`tenant.yaml` fajla ima `apple`, `google` i `email`, i nijedan `facebook`.

`docs/06 §7.4` je već opisao trošak: Meta dopušta **jedan odobren iOS i Android bundle po app
ID-u**, deep linking veže **jedan** package name, a Login izvan dev moda traži Meta app review sa
politikom privatnosti i data deletion callbackom. Za fabriku koja pravi N brandiranih app-i to
znači ili jedan app ID koji Meta može pauzirati, ili jedan Facebook App **po klijentu**, sa 30–60
minuta rada i 1–5 dana tuđeg reviewa u svakom onboardingu. Isti dokument je zaključio: „ako
onboarding počne kasniti zbog Meta review-a, to je prvo što treba pasti."

Novi podatak koji zatvara odluku je proizvodni: Facebook login se ne nudi klijentima. Apple,
Google i email + lozinka ([ADR-0010](0010-email-lozinka-umjesto-otp-a.md)) pokrivaju korisnike u
BiH, a težište rada prelazi na admin aplikaciju po handoffu u `prototype/admin/`.

## Odluka

- Facebook **nije** provider prijave. Uklanja se iz koda, ne ostaje iza flaga.
- `AuthProvider` ima tačno tri člana: `apple`, `google`, `email`.
- `AuthRepository` nema `signInWithFacebook()`.
- `tool/gen_flavors.dart` više ne poznaje `facebook` u `auth.providers`. Tenant koji ga upiše
  **obara generator**, pa i CI — odluka se provodi alatom, ne dogovorom.
- `salons.facebook_url` **ostaje**. To je link na Facebook stranicu salona u „O nama" i nema veze
  sa prijavom; brisanje kolone bi uklonilo podatak koji salon stvarno koristi.
- Task `26 — Guest flow i Facebook login iza flaga` skida se sa plana. Tok gosta iz tog taska nije
  odbačen — nastavlja zasebno, jer je nezavisan od Facebooka.

## Razmatrane opcije

- **Ostaviti kod iza flaga isključenog po defaultu** — odbačeno: to je stanje koje je već trajalo
  od Sprinta 2 i koštalo je na svakom dodiru auth koda. Četiri `switch` izraza, jedan ugovor,
  jedan `.arb` string i jedan stub koji baca grešku održavali su se zbog puta koji niko nije
  prešao. Isključen flag ne smanjuje cijenu održavanja, samo je sakriva.
- **Jedan Facebook App za sve flavore** — odbačeno: Metina bundle politika ga može pauzirati, a
  pad bi pogodio **sve** klijente odjednom, ne onog koji je Facebook tražio.
- **Jedan Facebook App po flavoru** — odbačeno: trošak skalira linearno sa brojem klijenata i
  ubacuje tuđi review u onboarding koji je inače naš od početka do kraja (`docs/04 §6.2`).
- **Ukloniti i `salons.facebook_url`** — odbačeno: nije isti podatak. Salon ima Facebook stranicu
  i onda kad prijava preko Facebooka ne postoji.
- **Odgođeno, ne odbačeno:** ako klijent uslovi potpis Facebook prijavom, odluka se vraća na sto
  novim ADR-om. Vraćanje je tada svjestan posao (paket, Meta review, callback), ne odmrzavanje
  mrtvog koda.

## Posljedice

- `AuthProvider` ima tri člana, pa svaki `switch` nad njim postaje kraći. Dart `switch` je
  iscrpan, tako da uklanjanje člana **obara analizu** na svakom mjestu koje ga je nabrajalo —
  nema tiho preživjelog poziva.
- `tenant.yaml` sa `facebook: false` sad **pada**, a ne ignoriše se. To izgleda kao regresija a
  nije: generator namjerno odbija ključ koji više ne postoji, umjesto da tiho propusti
  konfiguraciju koja ne radi ništa.
- `docs/01` i `docs/02` i dalje nabrajaju Facebook u starijim tabelama i wireframeovima. Oni su
  zapis specifikacije u trenutku pisanja; ovaj ADR i tabela odluka u `docs/README.md` su jači.
  `docs/06 §7.4` nosi bilješku da je odluka pala.
- Tok gosta (`AuthConfig.allowGuest`, `AuthRepository.continueAsGuest`) ostaje neimplementiran i
  bez taska dok se ne raspiše ponovo. To je jedina stavka koja je izgubila svoj task fajl, pa je
  imenovana ovdje da ne nestane tiho.

## Reference

- [06 §7.4](../06-auth-login-flow.md) — analiza troška koja je prethodila ovoj odluci
- [ADR-0010](0010-email-lozinka-umjesto-otp-a.md) — email + lozinka, provider koji ostaje
