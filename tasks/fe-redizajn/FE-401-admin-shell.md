# FE-401 — Admin ljuska i Melura branding

| | |
|---|---|
| **Epik** | FE-4 · Admin panel |
| **Aplikacija** | `apps/admin` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | ✅ [ADR-0016](../../docs/adr/0016-adminv2-je-vizuelni-izvor-istine-za-admin.md) — riješen, task odblokiran |
| **Blokira** | FE-402…FE-405 |
| **Reference** | `apps/admin/lib/src/core/widgets/admin_scaffold.dart` · `apps/admin/lib/src/core/navigation/admin_destinations.dart` · `prototype/adminv2/export/` |

## Cilj
Sidebar sa Melura wordmarkom, oznakom uloge i navigacijom po novom handoffu.

## Zatečeno stanje
Ljuska **postoji i nije trivijalna** — `AdminScaffold` već rješava ono što handoff traži kao novo:

- Jedan route model, dvije ljuske: sidebar iznad `AdminBreakpoint.desktop = 840`, donja navigacija
  ispod. Obje čitaju `kAdminDestinations`; nema ekrana koji postoji samo na jednoj širini.
- Prag 840 je **odabran sa obrazloženjem** (Material `expanded`), jer canvas crta samo 1440 i 402.
- `AdminShell.jeDesktop` / `gutterOf` su statičke metode nad `MediaQuery` **namjerno**: ekran gradi
  tijelo prije nego ga ljuska primi, pa bi `InheritedWidget` uvijek vratio telefonske vrijednosti.

Za preimenovanje: „Salon OS" stoji na **dva mjesta u UI-u** — `admin_scaffold.dart:157` i
`login_screen.dart:505` (uz znak `SO` u kvadratu) — i u **tri asercije** u
`admin_shell_test.dart` i `login_screen_test.dart`. Stringa `salonos.ba` u kodu nema.

## Definicija gotovog
- [x] Wordmark **Melura** i logo placeholder u sidebaru i na prijavi — `AdminWordmark`, jedan
      widget za obje ljuske, uz `kImeProizvoda` kao jedinu tačku istine za string
- [x] Znak `SO` zamijenjen; nijedan „Salon OS" string ne ostaje u UI-u — `grep` nad `apps/`
      vraća samo komentare i istorijske reference, nijedan string koji se crta
- [x] **Četiri** testa koja traže „Salon OS" prepisana na novo ime, ne obrisana — task je
      govorio o tri, stvarno ih je bilo četiri (tri u `admin_shell_test.dart`, jedan u
      `login_screen_test.dart`). Svi sada traže `kImeProizvoda`, pa sljedeće preimenovanje
      ne dira testove.
- [x] Navigacija u velikim slovima — `toUpperCase()` u sidebaru, **ne** u
      `kAdminDestinations`: mijenjanje labela bi tiho poverzalilo i donju navigaciju na
      telefonu, gdje `3k` crta mala slova. Test tvrdi oboje.
- [ ] ~~aktivna stavka sa lijevom oznakom u koralnoj~~ — **nema je u izvozu.** Skeniran je
      cijeli sidebar u `3b`: nijedan koralni piksel osim pilule brojača. Aktivna stavka je
      `#373A40` bez oznake. V. „Odstupanja od teksta taska".
- [x] Oznaka uloge ispod imena korisnika — `labelaUloge()` nad tri vrijednosti
      `public.staff_role`; nepoznata uloga ne ispisuje ništa umjesto sirove vrijednosti
- [x] Sidebar se i dalje sklapa ispod praga — postojeći test nije mijenjan i i dalje prolazi
- [x] `prototype/CLAUDE.md` dopunjen: šta je `adminv2/` i koji handoff je jači — urađeno uz
      [ADR-0016](../../docs/adr/0016-adminv2-je-vizuelni-izvor-istine-za-admin.md), prije ovog
      taska, jer je blokiralo svih pet preostalih FE-4xx
- [x] `admin/SPEC.md` ispravljen na mjestima koja ADR-0016 imenuje kao zastarjela: naslov,
      tamni sidebar i raspodjela akcenta. Uz to `apps/admin/README.md` više ne upućuje samo
      na zastarjeli folder.

## Zamke
- **Koralna ovdje je ispravna** (admin je jedan platformski build za sve salone); ista boja u
  klijentu nije. Ne prenositi je kroz `core_ui`.
- Prag 840 nije iz canvasa i ima zapisan razlog. Ako novi handoff traži drugi, mijenja se i taj
  komentar, inače sljedeći čitalac nađe dva obrazloženja.
- Preimenovanje proizvoda dira i `docs/`; ime se ne mijenja samo u UI-u.

## Odstupanja od teksta taska

Dva mjesta gdje je izvoz rekao drugo nego task; oba su provjerena mjerenjem, ne procjenom.

**1. Nema koralne oznake uz aktivnu stavku.** DoD je tražio „aktivnu stavku sa lijevom oznakom
u koralnoj". Skeniran je **cijeli sidebar** u `3b` na koralne piksele: nula. Sva koralna na
ekranu je desno — dugme „+ NOVI TERMIN" i „POTVRDI" u panelu zahtjeva. Aktivna stavka je
jednostavno `#373A40` podloga sa bijelim tekstom. Oznaka nije izostavljena nego je **nema u
izvoru**; dodati je značilo bi crtati nešto što dizajn ne traži.

**2. Pilula brojača je bila plava, a izvoz traži koralnu.** Ovo task nije spomenuo. Poslije
prelaska na tamni sidebar plava `#3D5A80` pilula se na `#141517` čitala kao greška;
mjerenje daje `#EE6C4D` na tom mjestu. Prebačeno na postojeći par `action`/`onAction`, koji
je već AA-provjeren — bijela na koralu pada (3,05:1), pa je tekst `#2C2C2C`.

**Sidebar je taman i u svijetloj temi**, što je razriješilo protivrječnost *unutar*
`admin/SPEC.md`: red pod „Status i opseg" oduvijek traži „stalni tamni sidebar", a tabela
tokena je davala `#F8F9FA`. Kod je slijedio tabelu. Sve izmjerene vrijednosti (`#141517`,
`#373A40`, `#FFFFFF`, `#C1C2C5`) su **već postojeći dark tokeni** — nije uvedena nijedna nova
boja.

## Status

Kod gotov i dokazan — grana `feat/fe-401-admin-ljuska-melura`.

**Dokaz:** `flutter test` u `apps/admin` — **294 prolazna** (bilo 289), čista analiza i format.

Vidjeno uživo na tri mjesta (`flutter build web` + Chromium):

- **desktop 1600×1000** — tamni sidebar, Melura wordmark sa LOGO placeholderom, verzal
  navigacija, „vlasnik lokacije" ispod imena, koralna pilula, svijetla radna površina
- **telefon 402×874** — donja navigacija i dalje malim slovima („Danas", „Kalendar"), što
  potvrđuje da `toUpperCase()` u sidebaru nije procurio u `kAdminDestinations`
- **prijava 1600×1000** — wordmark umjesto znaka `SO`, „administracija salona", koralno
  „Prijavi se" sa tamnim tekstom

Svaki nov test provjeren sabotažom: pilula vraćena na `accent` obori test, `sidebarText`
spušten na `#444444` obori kontrastni test na tamnoj podlozi.

**ADR-0016 je spojen u `main`** (`29fd030`) — pravilo po kojem je ovaj task odblokiran. Grana
je rebaseovana na `main` i nosi samo ovaj task, jedan commit.

Ostalo:

- [ ] Zelen CI — dokaz iz čistog checkouta.
