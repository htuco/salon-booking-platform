# Task 29 — Responsive shell: desktop sidebar i mobilna navigacija

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [28](28-admin-tema-i-tipografija.md) |
| **Blokira** | 30–36 |
| **Reference** | [`prototype/admin/SPEC.md`](../../prototype/admin/SPEC.md) — prikazi `3b`–`3i`, `3k`–`3t` |

## Cilj
Jedna ljuska koja na 1440 crta tamni sidebar, a na 402 donju navigaciju — **iz istog route
modela**, ne kao dva stabla ekrana.

## Definicija gotovog
- [x] Desktop: sidebar ≈236 px, top bar 60–66 px, sadržaj na svijetloj radnoj površini
- [x] Telefon: donja navigacija **Danas · Kalendar · Zahtjevi · Još**, 20 px horizontalni gutter
- [x] Prelaz ide na breakpointu; horizontalno skaliran desktop **nije** mobilni layout
- [x] „Još" (`3t`) vodi u module izvan četiri ćelije — klijenti, usluge, osoblje, radno vrijeme,
      postavke
- [x] `AdminScaffold` ostaje jedini nosilac navigacije; ekran i dalje prosljeđuje `aktivna` rutu
      umjesto da je čita iz `GoRouterState`
- [x] Widget test za obje širine, nad istim ekranom

## Koraci
1. Breakpoint i ljuska u `core/widgets/`
2. Sidebar i donja navigacija nad istom listom ruta
3. Placeholder rute ostaju rute — dobijaju svoje mjesto u navigaciji
4. Commit: `feat(admin): responsive shell sa sidebarom i donjom navigacijom`

## Zamke
- **Razlog zbog kojeg ovaj task ide prije 30**, obrnuto od redoslijeda u `SPEC.md`: `3b` i `3k`
  nisu dva ekrana nego jedan ekran u dvije ljuske. Ko prvo prevede ekran, prevede ga u ljusku koja
  se sutra mijenja.
- **`aktivna` se ne smije početi čitati iz routera.** Komentar u `admin_scaffold.dart` objašnjava
  zašto: ekran koji čita rutu ne može se podići u widget testu bez pravog `GoRouter`-a, pa test
  liste termina postaje test navigacije.
- Admin je i web build. `initialLocation` nadjačava URL iz adresne trake — router to već zna, i
  ljuska to ne smije pokvariti.

## Status (2026-09-19) — ✅ zatvoren

Gotovo. `AdminScaffold` na 1440 crta tamni sidebar od 236 px i top bar od 66, na 402 četiri
ćelije donje navigacije; prelaz ide na **840** (Material `expanded`). Canvas taj broj ne daje —
`SPEC.md` crta 1440 i 402 i kaže da tablet „nije posebno nacrtan", pa je izabran najbliži
postojeći prag, uz obrazloženje u `AdminBreakpoint`.

Obje ljuske čitaju `kAdminDestinations`. Prve tri stavke su ćelije telefona, ostalih pet su rep
iste liste iza „Još" (`3t`) — nije druga lista, pa modul dodan u navigaciju ne može ostati
dostupan samo na jednoj širini.

### Šta je mjerenje canvasa oborilo ili donijelo

Sastav navigacije je izmjeren iz `canvas/Salon OS Admin.dc.html`, ne prepisan iz SPEC tabele:
sidebar `3b` nosi **osam** modula, donja navigacija `3k`/`3t` **četiri**.

- **`AdminSpacing.gutterDesktop` je bio 24, canvas crta 28.** `padding:28px` stoji u svih sedam
  desktop prikaza u opsegu i `padding:0 28px` devet puta u top barovima; `padding:24px` i
  `padding:0 24px` se ne javljaju **nijednom**. 24 u handoffu postoji, ali kao razmak *između
  sekcija*, ne kao gutter.
- **Handoff nema ćeliju „Termini".** Puna lista termina se ne pojavljuje ni u sidebaru ni u donjoj
  navigaciji. Zato „Zahtjevi" vode na `/appointments?status=pending`, a **ne** na vlastitu rutu:
  zasebna ruta bi `/appointments` ostavila bez ijednog ulaza iz navigacije, a ovako filter traka na
  ekranu vraća na „sve".
- **Usput popravljena web greška.** Kartica zahtjeva na dashboardu je mijenjala stanje providera pa
  navigirala, pa su refresh i „nazad" vraćali nefiltriranu listu, a URL nije opisivao šta se vidi.
  Sada oba ulaza — kartica i ćelija — nose istu adresu.
- **`AdminRoute` nije imao `clients`.** Dodane `/clients` i `/more`, i upisane u `docs/01 §12`;
  red ide u tabelu pa u enum, ne obrnuto.
- **Brojač uz „Zahtjeve" je dio ljuske**, ne ekrana: canvas ga crta u obje navigacije prije nego
  se ijedan ekran otvori.

### Odluka koja je svjesno obrnuta

Do ovog taska je vrijedilo „ćelija koja vodi na placeholder je gora od ćelije koje nema", pa
navigacija nije nudila nijednu nenapisanu rutu. Handoff traži suprotno — `3b` crta svih osam
modula — i odluka je obrnuta, uz obrazloženje zapisano u komentaru uz rutu, da se ne čita kao da je
staro pravilo tiho nestalo.

### Greška koju je našao browser, a testovi nisu mogli

`AdminPlaceholderScreen` je imao **vlastiti `Scaffold`**. To nije smetalo dok navigacija nije
nudila nenapisane rute; otkad ih nudi, `/clients` otvoren iz „Još" se crtao **bez ikakve
navigacije** i iz njega se izlazilo samo dugmetom „nazad" u browseru. Isto za svih pet modula iza
„Još". Nijedan widget test to nije mogao uhvatiti jer svaki diže **jedan** ekran, a ovo je svojstvo
prelaza između dva.

### Bezvrijedan test koji je ispravljen

Prva verzija provjere guttera je poredila `AdminSpacing.gutterDesktop` **sam sa sobom**. Prošla je
i kad je gutter vraćen na pogrešnih 24 — provjereno pokretanjem, i zato je zapisana. Sada test drži
izmjerene brojeve (28 i 20), a `theme_tokens_test` je dobio tvrdnju o 28.

### Dokaz

- **85 admin testova** (bilo 70), **582 ukupno** u pet paketa, čista analiza svuda.
- **12 novih u `admin_shell_test.dart`**, nad **istim** ekranom na 1440×900 i 402×874, plus četiri
  za filter iz adrese.
- **Provjereno da svaki novi test može pasti**: breakpoint koji nikad ne pogodi desktop obori četiri
  tvrdnje, donja navigacija sa svih osam modula tri, gutter vraćen na 24 dvije, `postaviStatusTacno`
  pretvoren u prebacivač jednu, „Zahtjevi" na vlastitoj ruti jednu, uklonjen fallback na „Još"
  jednu, sidebar bez brojača jednu, placeholder vraćen na vlastiti `Scaffold` jednu. Sve vraćeno.
- **CI zelen** — job „Analiza, format i testovi"
  ([run 35408537356](https://github.com/htuco/salon-booking-platform/actions/runs/35408537356)).
- **Uživo u Chromiumu** iz pravog `flutter build web` bundlea, na obje širine:
  `docs/screenshots/task-29-admin-*.png` — ljuska, „Još", zahtjevi, **refresh na
  `/appointments?status=pending`** (filter preživi hladan start) i placeholder na obje širine.

### Ostalo za sljedećeg

- **[PR #51](https://github.com/htuco/salon-booking-platform/pull/51) je otvoren i čeka spajanje.**
  CI je zelen i PR nije draft; merge je odluka vlasnika repoa, ne dio ovog taska.
- **Ljuska nije viđena sa pravim podacima ni pravom prijavom.** Snimci su iz
  `apps/admin/lib/demo_main.dart`, novog demo ulaza sa override-anim providerima — na ovoj mašini
  nema Dockera ni `supabase` CLI-ja. Hostovani projekat iz `.env.live` **ima šemu**
  (`/rest/v1/salons` vraća 200, promjena u odnosu na status taska 27), ali nije bilo naloga za
  prijavu. Kad ga bude: `tool/run_live_demo.sh admin`.
- **Top bar nema breadcrumb prefiks.** Canvas crta `Vitez / Danas`; ime lokacije ne postoji na
  `StaffMember`, pa top bar nosi samo naslov ekrana. Traži salon iz baze — task
  [30](30-postojeci-ekrani-na-handoff.md) ili [36](36-postavke-lokacije.md).
- **Naslov dashboarda je i dalje „Pregled", navigacija ga zove „Danas".** Nesklad se vidi na
  snimku; copy ekrana pripada tasku 30.
- **Desktop top bar ne nosi akcije iz `3b`** („Pretraži klijenta", „Blokiraj termin", „+ Novi
  termin") — ekran ih i dalje daje kao FAB. To su akcije ekrana, task 30.
- **Ikone su Material, ne Lucide.** Canvas crta Lucide poteze; admin nema taj paket, a dodavanje
  zavisnosti nije posao ljuske.
