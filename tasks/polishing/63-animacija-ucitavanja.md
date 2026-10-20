# Task 63 — Animacija učitavanja „Termin i sada"

| | |
|---|---|
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | `apps/admin/assets/brand/melura-ucitavanje.svg` (referentni pokret) · [stranica sa znakom](https://claude.ai/artifact/U2xn39LXAjsUsF5dd11ppw), red „Učitavanje" · FE-205 |

## Cilj
Admin ima vlastitu animaciju čekanja iz jezika kalendara: termin koji stoji i linija „sada"
koja klizi kroz njega. Ideja je nastala uz izbor znaka proizvoda (2026-10-01) i vlasnik
proizvoda ju je odobrio: „sviđa mi se baš kako si uradio".

## Kako izgleda
Tačno kao `melura-ucitavanje.svg`; ono je izvor istine za pokret, ovo je prepis:

- **Termin:** koralni blok `#EE6C4D`, 52 × 76 u kvadratu 100 × 100, radius 10, ne pomjera se.
- **Linija „sada":** 84 × 7, radius 3,5, sa tačkom r 7,5 na lijevom kraju. `#3D5A80` na
  svijetloj podlozi, `#8FB0D6` na tamnoj — ista boja kao linija „sada" u kalendaru.
- **Pokret:** linija klizi od −34 do +34 (od vrha do dna termina) i nazad, 1,6 s,
  `cubic-bezier(.45, 0, .25, 1)`, u petlji.
- **Manje pokreta:** kad sistem traži (`MediaQuery.disableAnimations`, na webu
  `prefers-reduced-motion`), linija stoji na sredini termina.

## Definicija gotovog
- [x] Widget u `core/widgets/` (npr. `AdminUcitavanje`), `CustomPainter` ili `AnimatedBuilder`
      nad tokenima boja — bez hex vrijednosti u ekranu (`no_hardcoded_colors_test`)
- [x] **Splash na webu:** ista animacija u `web/index.html` prije prvog Flutter kadra, čistim
      CSS-om, na pozadini koju FE-205 već postavlja (`web_splash_test.dart` ostaje zelen)
- [x] **Dugme koje čeka:** zamjenjuje tri tačke `AdminButtonBusy` u dugmadi gdje se čeka
      server („Prijavi se", „Sačuvaj"); na koralnom dugmetu u boji teksta dugmeta
- [x] Bez pokreta kad sistem to traži; widget test za oba stanja
- [x] `no_material_indicators_test` zelen — nije `CircularProgressIndicator` ni
      `LinearProgressIndicator`
- [x] Viđeno uživo: splash na sporoj vezi (DevTools throttling), dugme za prijavu, 1440 i 402

## Zamke
- **Skeletoni ostaju.** Na ekranima sa podacima (Danas, liste, kalendar) animacija ne
  zamjenjuje skeleton: skeleton pokazuje oblik sadržaja koji dolazi, pa se raspored ne
  pomjeri kad podaci stignu (FE-205). Ova animacija je za čekanje bez oblika — start
  aplikacije i radnja u toku.
- **Na 16–24 px** linija i tačka se stope; u dugmetu je dovoljna linija bez tačke (tako je i
  na stranici sa znakom, u dugmetu „PRIJAVLJUJEM").
- Na webu je splash HTML, ne Flutter: pokret u CSS-u i u Dartu mora biti isti, inače se na
  prelazu sa splasha na prvi kadar vidi skok.

## Status (2026-10-20)

Gotov, grana `feat/animacija-ucitavanja`, [PR #141](https://github.com/htuco/salon-booking-platform/pull/141).

**Šta je urađeno.**
- `apps/admin/lib/src/core/widgets/admin_ucitavanje.dart`: `AdminUcitavanje` (puni znak, 72 px)
  i `AdminButtonBusy` (premješten iz `admin_skeleton.dart`, isti API). Jedan `CustomPainter` u
  kvadratu 100 × 100, prepis SVG-a; pokret je `Cubic(.45, 0, .25, 1)` po polovinama, kao CSS
  keyframes. Uz manje pokreta kontroler staje, linija na sredini.
- Token `AdminPalette.nowLine` (`#3D5A80` / `#8FB0D6`). **Linija „sada" u kalendaru je zapravo
  `destructive` (crvena)**, ne plava kako task kaže; znak prati SVG, kalendar nije diran.
- Dugme: znak bez tačke, jednobojan, `ink` (≈11:1 na sivom onemogućenom dugmetu), linija ≥ 2 px.
  Prijava gubi svoj indikator sa tri tačke i koristi `AdminButtonBusy`.
- Splash u `web/index.html`: isti znak u CSS-u, skida se na `flutter-first-frame`,
  `pointer-events: none`. **Samo svijetao**, i pozadina: admin je uvijek svijetao
  (`ThemeMode.light`), pa je stara tamna pozadina iz FE-205 na OS-u u dark modu davala tamno pa
  svijetlo. Vraća se kad se vrati `ThemeMode.system`.

**Dokaz.**

```
dart run melos run analyze   → svih 5 paketa: No issues found!
dart run melos run test      → core_domain 102, core_api 146, core_ui 146, client 667, admin 686 — SUCCESS
apps/admin flutter test      → 686 (poslije popravki iz pregleda)
web_splash_test: pokvareno trajanje (1.5s) i tamna linija → -2; pogrešna boja .sada → pada
web_splash_test: themeMode vraćen na ThemeMode.system u main.dart → -1 (splash nema tamnu varijantu)
```

Uživo (statički build nad lokalnim stackom, Playwright):
- 1440, mreža ~400 kbit/s: splash vidljiv, `.sada` transform `translateY(28.35)` pa `3.03` za
  0,5 s — klizi. Na normalnoj mreži nestaje 1,15 s od otvaranja; `flutter-view` postoji, splash
  je uklonjen iz DOM-a.
- OS u dark modu: pozadina `rgb(252,252,249)`, linija `rgb(61,90,128)`, termin `rgb(238,108,77)`.
- `prefers-reduced-motion: reduce`: `transform: none` u oba očitanja.
- Dugme „Prijavi se" sa usporenim token zahtjevom (3–4 s): 1440 i 402, znak u čekanju, pa `/today`.
- Pregled (`flutter-ui-reviewer`): splash po dark shemi i nevidljiv termin na onemogućenom dugmetu
  — oba popravljena u grani.

**Nije provjereno / svjesno ostavljeno.**
- `AdminUcitavanje` se danas ne koristi u ekranu: splash nestaje u prvi ekran koji router crta
  (prijava ili Danas sa kosturom). Ako se znak ikad stavi na startni ekran, faza mora krenuti od
  vremena učitavanja stranice, inače CSS i Dart nisu u istoj tački ciklusa.
- Koralno dugme u čekanju nije viđeno: sva dugmad u toku su onemogućena, dakle siva; „Prihvati"
  je prošao prije nego što je kašnjenje uhvatilo zahtjev.
- „Sačuvaj izmjene" u radnom vremenu se u čekanju suzi (bilo je isto i sa tri tačke).
- Kad Flutter ne podigne, znak se vrti bez poruke (prije je bio prazan ekran — nije regresija).
- Jednom, sa umjetnim kašnjenjem od 4 s na tokenu, prijava radnika na 402 je ostala u čekanju uz
  `401` na `/rest/v1/users`; bez kašnjenja i u ponovljenom pokušaju prolazi. Nije razjašnjeno —
  ide u regresiju (60).
