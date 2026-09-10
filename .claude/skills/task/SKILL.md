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

- **`tasks/CURRENT.md`** — jedan aktivni task, uvijek tačno jedan. Sekcije: `# Trenutni task: <NN — naziv>`,
  `## Status` (Nije počet | U toku | Gotov), `## Ciljevi` (samo ono što stvarno preostaje),
  `## Napomene` (kontekst i zamke), `## Istorija` (zatvoreni taskovi, dopisuje se na kraj).
  Ovo je fajl koji se čita prvi kad neko sjedne za posao.
- `tasks/<NN>-<slug>.md` — puni task: cilj, DoD checkboxovi, koraci, `## Status (datum)` na dnu
- `tasks/README.md` i `tasks/sprint-1/README.md` — tabele (`#`, task, blokira, procjena, ✅/🟡) + status blokovi
- `docs/adr/` — kad task donese odluku koja se ne može pročitati iz koda

`CURRENT.md` je **derivat**, ne izvor: puni task fajl i repo su iznad njega. Kad se raziđu, ispravi
`CURRENT.md`.

## Akcija: $ARGUMENTS

| Akcija | Šta radi |
|---|---|
| `load` | Učitaj task u `CURRENT.md` — zavisnosti i DoD naspram stvarnog stanja repoa |
| `start` | Otvori granu, postavi status `U toku`, kreni redom kroz korake |
| `review` | Provjeri DoD stavku po stavku, bez samouvjeravanja |
| `verify` | Dokaži da radi — pokreni `/verify` recept za taj tip promjene |
| `complete` | Zatvori: dokaz, status blok, dokumenti, commit, PR |
| `explain` | Objasni šta je promijenjeno i kako se dijelovi vežu |

Detalji: `actions/`. Bez argumenta — pročitaj `tasks/CURRENT.md` i reci šta je učitano, u kojem je
statusu i koji je sljedeći korak.

## Pravila koja važe u svakoj akciji

- **Ne otvaraj task čije zavisnosti nisu gotove.** Redoslijed u `tasks/README.md` nije formalnost:
  availability testovi trebaju stvarnu šemu, CI treba flavor sistem da ima šta buildati.
- **DoD stavka se čekira tek kad postoji dokaz**, ne kad je kod napisan. Dokaz je izlaz komande
  ili zeleni CI job, i ide u `## Status` blok taska.
- **Ne sužavaj zadatak da bi ga zatvorio.** Ako je nešto ostalo, to se piše u status blok kao
  "ostalo za sljedećeg", sa komandom kojom se nastavlja.
- **Novi taskovi za sljedeći sprint idu u novi fajl/folder** (`tasks/sprint-1/`), ne dopisuju se u
  Sprint 0 listu.
