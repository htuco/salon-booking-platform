# ADR — zapisi arhitektonskih odluka

Jedna odluka po fajlu, `NNNN-<slug>.md`, numerisano rastuće. ADR se piše kad je odluka
**donesena i kad se ne može pročitati iz koda** — kod pokazuje šta radimo, ADR zašto, i šta smo
odbacili.

## Kad se piše ADR

- Odluka mijenja nešto iz tabele "Odluke koje su već donesene" u `docs/README.md`.
- Odluka će za tri mjeseca izgledati proizvoljno ("zašto je ovo Ruby?").
- Postojale su vjerodostojne alternative i odbačene su iz razloga koji nije očigledan.

Kad odluka nije donesena nego se samo radi — to je task (`tasks/`), ne ADR. Kad je pojam nejasan,
a ne odluka — to je `CONTEXT.md`.

## Struktura

`_TEMPLATE.md`. Sekcije: Status · Kontekst · Odluka · Razmatrane opcije · Posljedice.
Piši u prezentu i konkretno; "razmotrili smo alternative" nije razmatranje.

## Status

`predložen` → `prihvaćen` → `zamijenjen sa ADR-NNNN`. Prihvaćen ADR se **ne prepravlja** kad se
predomislimo — piše se novi koji ga zamjenjuje, i stari dobija liniju o tome. Istorija odluke je
dio odluke.

## Ako tvoj rad protivrječi ADR-u

Reci to eksplicitno umjesto da ga tiho pregaziš:

> _Protivrječi ADR-0003 (`x-salon-id` ne daje prava) — ali vrijedi otvoriti jer…_
