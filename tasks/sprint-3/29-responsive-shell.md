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
- [ ] Desktop: sidebar ≈236 px, top bar 60–66 px, sadržaj na svijetloj radnoj površini
- [ ] Telefon: donja navigacija **Danas · Kalendar · Zahtjevi · Još**, 20 px horizontalni gutter
- [ ] Prelaz ide na breakpointu; horizontalno skaliran desktop **nije** mobilni layout
- [ ] „Još" (`3t`) vodi u module izvan četiri ćelije — klijenti, usluge, osoblje, radno vrijeme,
      postavke
- [ ] `AdminScaffold` ostaje jedini nosilac navigacije; ekran i dalje prosljeđuje `aktivna` rutu
      umjesto da je čita iz `GoRouterState`
- [ ] Widget test za obje širine, nad istim ekranom

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

## Status

Nije počet.
