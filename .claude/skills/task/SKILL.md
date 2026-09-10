---
name: task
description: Životni ciklus taska iz tasks/ — učitaj, počni, pregledaj, dokaži, zatvori.
argument-hint: load|start|review|verify|complete|explain
---

# Task workflow

Taskovi ovog repoa su fajlovi u `tasks/` (`NN-<slug>.md`), sa ciljem, definicijom gotovog (DoD kao
checkbox lista) i koracima. `tasks/README.md` je tabela svih taskova plus **status blokovi** koje
čita sljedeća osoba koja sjedne za posao. Ta dva mjesta su tracker — nema Jire, nema Linear-a.

Ovaj skill vodi task kroz njegov životni ciklus i, što je važnije, održava ta dva mjesta tačnim.

## Radni fajlovi

- `tasks/<NN>-<slug>.md` — jedan task: cilj, DoD checkboxovi, koraci, `## Status (datum)` na dnu
- `tasks/README.md` — tabela (`#`, task, blokira, procjena, ✅/🟡) + status blok po tasku
- `docs/adr/` — kad task donese odluku koja se ne može pročitati iz koda

## Akcija: $ARGUMENTS

| Akcija | Šta radi |
|---|---|
| `load` | Učitaj task, pročitaj zavisnosti i DoD, reci šta je stvarno ostalo |
| `start` | Otvori granu i kreni redom kroz korake |
| `review` | Provjeri DoD stavku po stavku, bez samouvjeravanja |
| `verify` | Dokaži da radi — pokreni `/verify` recept za taj tip promjene |
| `complete` | Zatvori: dokaz, status blok, dokumenti, commit, PR |
| `explain` | Objasni šta je promijenjeno i kako se dijelovi vežu |

Detalji: `actions/`. Bez argumenta — nabroji opcije i reci koji je task trenutno u toku
(nađi ga po 🟡 u `tasks/README.md` i po grani na kojoj si).

## Pravila koja važe u svakoj akciji

- **Ne otvaraj task čije zavisnosti nisu gotove.** Redoslijed u `tasks/README.md` nije formalnost:
  availability testovi trebaju stvarnu šemu, CI treba flavor sistem da ima šta buildati.
- **DoD stavka se čekira tek kad postoji dokaz**, ne kad je kod napisan. Dokaz je izlaz komande
  ili zeleni CI job, i ide u `## Status` blok taska.
- **Ne sužavaj zadatak da bi ga zatvorio.** Ako je nešto ostalo, to se piše u status blok kao
  "ostalo za sljedećeg", sa komandom kojom se nastavlja.
- **Novi taskovi za sljedeći sprint idu u novi fajl/folder** (`tasks/sprint-1/`), ne dopisuju se u
  Sprint 0 listu.
