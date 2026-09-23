# Admin pakuje Barlow bez reza 700

## Status

prihvaćen — mijenja jedan detalj [ADR-0020](0020-admin-je-1na1-sa-adminv2-barlow-i-svijetla-tema.md)
(rezovi 400/500/600/700 → 400/500/600); ostatak ADR-0020 važi.

## Kontekst

ADR-0020 je admin prebacio na Barlow u četiri statična reza, 400–700. FE-503 (čišćenje legacy
stilova, 2026-09-23) je izmjerio dvije stvari:

- **Nijedan stil admina ne traži 700.** U `apps/admin/lib` nema `FontWeight.w700` ni
  `FontWeight.bold`, a `barlow(weight:)` se zove samo sa 400, 500 i 600. Material 3 tekst
  tema koristi 400 i 500.
- **Rez 700 nosi 108 KB**, a bundle admina je kroz FE epik porastao za 242 KB, od čega
  +100 KB pisma. Bez tog reza su pisma admina 316 KB, **manje nego prije epika** (324 KB).

DoD FE-503 traži da bundle ne poraste i da nema neiskorištenih pisama. Vlasnik proizvoda je
odlučio da se rez izbaci.

## Odluka

`apps/admin` pakuje Barlow u **tri** reza: Regular (400), Medium (500), SemiBold (600).
`Barlow-Bold.ttf` je uklonjen iz `assets/fonts/` i iz `pubspec.yaml`; `theme_tokens_test`
provjerava tačno ta tri reza.

## Razmatrane opcije

- **Zadržati 700 „za svaki slučaj"** — odbačeno: 108 KB za stil koji ne postoji, a DoD
  FE-503 traži da mrtvih pisama nema.
- **Varijabilni Barlow** — odbačeno: Barlow nema zvanični varijabilni fajl. ADR-0020 je zato
  i izabrao statične rezove.

## Posljedice

- Stil koji zatraži `w700` ne dobija pravi bold nego najbliži rez (600), uz mogući sintetički
  podebljaj. Ko uvodi takav stil, prvo vraća fajl i red u `pubspec.yaml` — i mijenja ovaj ADR.
- `theme_tokens_test` pada ako se fajl vrati bez reda u `pubspec.yaml` ili obrnuto, isto
  kao i do sada.
