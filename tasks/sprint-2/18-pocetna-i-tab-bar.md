# Task 18 — Client: Početna po handoffu + bottom tab bar

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | [11](../sprint-1/11-booking-flow.md), [22](22-sema-slike-i-staz.md) |
| **Blokira** | 19, 20, 21 (svi tab-level ekrani) |
| **Reference** | `prototype/ui/screenshots/01-pocetna.png` · `SPEC.md` §Bottom tab bar |

## Cilj
Početna izgleda kao `5a`, i aplikacija dobija navigaciju kakvu handoff pretpostavlja. Danas je
Početna iz taska 10 — naslijedila je nove tokene, ali joj je raspored stariji od dizajna.

## Definicija gotovog
- [ ] **Bottom tab bar** u `core_ui`: pet ćelija, redoslijed **Usluge · Termini · Početna ·
      Obavijesti · Postavke**, Početna namjerno u sredini
- [ ] Aktivna ćelija: bijela, `weight 600`, traka 3 px na vrhu, inset 16% lijevo/desno
- [ ] Pod-ekrani (Galerija, Recenzije, O aplikaciji, Pravila, Lightbox) **nemaju** tab bar
- [ ] Početna po `01-pocetna.png`: hero foto + serif naslov, živi status, CTA, **Cjenovnik** sa tri
      usluge + "Prikaži svih N", Majstori (2 kolone), Galerija (3 kolone), Recenzije sa ocjenom
- [ ] Tab se vraća na svoj korijen pri ponovnom tapu; prelaz je instant, bez cross-fade
- [ ] Screenshot uz `01-pocetna.png`

## Koraci
1. Tab bar kao `core_ui` komponenta + `StatefulShellRoute` u `go_router`-u
2. Početna sekciju po sekciju, odozgo
3. Commit: `feat(client): pocetna po handoffu i tab bar`

## Zamke
- **`StatefulShellRoute` mijenja oblik rutiranja** — deep linkovi iz taska 07 moraju i dalje raditi.
  Test iz `router_test.dart` je tu da to uhvati.
- Tab bar je **jedina zajednička komponenta koja se gradi prva** (`SPEC.md` to kaže doslovno);
  ekrani ispod nje su lakši kad ona postoji.
