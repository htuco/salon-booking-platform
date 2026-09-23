# FE-204 — Lightbox galerije

| | |
|---|---|
| **Epik** | FE-2 · Navigacija i tranzicije |
| **Aplikacija** | `apps/client` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | — |
| **Blokira** | [FE-305](FE-305-usluge-galerija-recenzije.md) |
| **Reference** | `apps/client/lib/src/features/gallery/` · `prototype/ui/screenshots/17-lightbox-galerije.png` · [ADR-0008](../../docs/adr/0008-galerija-ostaje-u-salons-gallery-urls.md) |

## Cilj
Slika iz galerije otvara se u fullscreen lightbox sa shared-element prelazom.

## Zatečeno stanje
- `apps/client/lib/src/features/gallery/` postoji — ovo je redizajn postojećeg ekrana, ne novi ekran.
- Handoff canvas za lightbox postoji: `prototype/ui/screenshots/17-lightbox-galerije.png`.
- Slike dolaze iz `salons.gallery_urls` (jsonb niz, redoslijed niza je redoslijed prikaza,
  [ADR-0008](../../docs/adr/0008-galerija-ostaje-u-salons-gallery-urls.md)) — nema tabele, pa nema
  ni ID-a po slici; `Hero` tag se izvodi iz URL-a i pozicije.

## Definicija gotovog
- [ ] `Hero` prelaz sa thumbnaila na fullscreen, 260 ms
- [ ] Swipe lijevo/desno mijenja sliku, swipe dolje zatvara
- [ ] Brojač (`3/12`) u gornjem desnom uglu
- [ ] `Hero` ne „skače" pri zatvaranju — uključujući slučaj kad je korisnik odswipeao na drugu sliku
      od one s koje je ušao
- [ ] Pinch-zoom ne otima gestu od swipea

## Zamke
- **Zatvaranje sa druge slike je slučaj koji lomi `Hero`.** Ušlo se sa slike 3, izašlo sa slike 7 —
  ako thumbnail slike 7 nije na ekranu, `Hero` nema odredište i animacija poskoči. Rješava se
  sinhronizacijom skrola ispod lightboxa prije `pop`-a.
- `Hero` tag mora biti jedinstven; dva puta ista slika u nizu daju dva ista taga i Flutter baci grešku.
- Storage još ne postoji (Sprint 5), pa su svi URL-ovi vanjski — keširanje i mjerenje se rade nad
  tim stanjem, ne nad budućim bucketom.

## Status

Gotov u kodu, dokazan widget testovima; **nije viđen na uređaju**.

- [x] `Hero` 260 ms — ruta je `PageRouteBuilder`, ne `showDialog`: `Hero` leti samo između
      `PageRoute`-ova, u dijalogu let se tiho ne desi. Tag je `(indeks, url)`, pa dupla slika u
      nizu ne ruši ekran.
- [x] Swipe lijevo/desno lista, swipe dolje zatvara (prag 120 px ili brzina 700).
- [x] Brojač gore desno, ✕ lijevo.
- [x] Zatvaranje sa druge slike — lightbox javlja indeks (`onIndeks`), mreža skroluje da ćelija bude
      na ekranu prije `pop`-a. Test na 402×874 sa 30 slika; sabotaža (bez skrola) obara tačno njega.
- [x] Pinch ne otima swipe — na 1× nema `InteractiveViewer`-a; recognizer sluša samo dva prsta.
      `InteractiveViewer` preuzima tek uvećanu sliku, a tada `PageView` i swipe dolje stoje.

**Ostaje:** pogledati let i pinch na pravom uređaju (`/verify`) — widget test ne vidi „skok"
animacije ni osjećaj geste. Nestanak struje je 2026-09-23 prepisao dva fajla ove grane NUL
bajtovima; `gallery_lightbox.dart` i test su ponovo napisani od `main`-a.
