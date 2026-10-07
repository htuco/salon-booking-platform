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
- [ ] Widget u `core/widgets/` (npr. `AdminUcitavanje`), `CustomPainter` ili `AnimatedBuilder`
      nad tokenima boja — bez hex vrijednosti u ekranu (`no_hardcoded_colors_test`)
- [ ] **Splash na webu:** ista animacija u `web/index.html` prije prvog Flutter kadra, čistim
      CSS-om, na pozadini koju FE-205 već postavlja (`web_splash_test.dart` ostaje zelen)
- [ ] **Dugme koje čeka:** zamjenjuje tri tačke `AdminButtonBusy` u dugmadi gdje se čeka
      server („Prijavi se", „Sačuvaj"); na koralnom dugmetu u boji teksta dugmeta
- [ ] Bez pokreta kad sistem to traži; widget test za oba stanja
- [ ] `no_material_indicators_test` zelen — nije `CircularProgressIndicator` ni
      `LinearProgressIndicator`
- [ ] Viđeno uživo: splash na sporoj vezi (DevTools throttling), dugme za prijavu, 1440 i 402

## Zamke
- **Skeletoni ostaju.** Na ekranima sa podacima (Danas, liste, kalendar) animacija ne
  zamjenjuje skeleton: skeleton pokazuje oblik sadržaja koji dolazi, pa se raspored ne
  pomjeri kad podaci stignu (FE-205). Ova animacija je za čekanje bez oblika — start
  aplikacije i radnja u toku.
- **Na 16–24 px** linija i tačka se stope; u dugmetu je dovoljna linija bez tačke (tako je i
  na stranici sa znakom, u dugmetu „PRIJAVLJUJEM").
- Na webu je splash HTML, ne Flutter: pokret u CSS-u i u Dartu mora biti isti, inače se na
  prelazu sa splasha na prvi kadar vidi skok.

## Status
Nije počet.
