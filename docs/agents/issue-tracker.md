# Tracker: markdown u `tasks/`

Ovaj repo nema Jiru ni Linear. Taskovi i njihovo stanje žive kao markdown u `tasks/`, i to je
jedino mjesto koje se čita kad neko preuzima posao.

## Konvencije

- **`tasks/CURRENT.md` je aktivni task** — tačno jedan u svakom trenutku, sa `## Status`,
  `## Ciljevi` (šta stvarno preostaje), `## Napomene` i `## Istorija` (zatvoreni taskovi). Vodi ga
  skill `/task`. Derivat je: puni task fajl i repo su iznad njega.
- Jedan task = jedan fajl: `tasks/<NN>-<slug>.md`, numerisano po **redoslijedu izvršavanja**
  (šta blokira šta), ne po prioritetu feature-a.
- Svaki task ima: cilj, **definiciju gotovog kao checkbox listu**, korake, i `## Status (YYYY-MM-DD)`
  blok na dnu kad se na njemu radilo.
- `tasks/sprint-<N>/README.md` je index sprinta: tabela (`#`, task, blokira, procjena, ✅/🟡) plus kratki status blok
  po tasku ispod nje.
- Sprint se ne dopisuje u tuđu listu — novi sprint je novi folder (`tasks/sprint-1/`), sa nastavkom
  numeracije (07, 08, …) da `/task load <NN>` ostane jednoznačan.

## Kad skill kaže "otvori task"

Napravi novi `tasks/sprint-<N>/<NN>-<slug>.md` po uzoru na postojeće (`tasks/sprint-0/03-flavor-system.md` je najpuniji
primjer) i dodaj red u tabelu `tasks/sprint-<N>/README.md`. Broj je sljedeći slobodan, a kolona "blokira"
mora biti popunjena — red bez zavisnosti je red koji će neko pokrenuti prerano.

## Kad skill kaže "nađi task"

Korisnik obično da broj (`03`) ili slug. Čitaj **cijeli** fajl plus njegov status blok u
`tasks/sprint-<N>/README.md`; ta dva mogu se razilaziti i tad je task fajl detaljniji, a repo iznad oba.

## Stanje

- **✅** — svaka DoD stavka ima dokaz (izlaz komande ili zeleni CI job) zapisan u status bloku.
- **🟡** — dio je dokazan, ostalo je izričito nabrojano sa komandom kojom se nastavlja.
- **⛔** — blokirano; napiši čime i ko/šta to odblokira.

Čekirana DoD stavka bez dokaza je tvrdnja, ne stanje. Kad preuzimaš tuđi task, provjeri tvrdnje
prije nego što kreneš dalje (`/handoff pickup`).

## Zašto ne `.scratch/` ili eksterni tracker

Taskovi ovdje nose komande, izlaze i zamke — to je materijal koji pripada uz kod i mora se mijenjati
u istom PR-u kao i kod. Tracker u drugom alatu razilazi se od repoa unutar sedmice, a dvoje ljudi
na dvije mašine (jedna bez Dockera, druga bez macOS-a) nemaju drugi način da prenesu šta je stvarno
dokazano.
