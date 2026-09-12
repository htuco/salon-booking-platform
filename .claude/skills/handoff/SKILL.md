---
name: handoff
description: Predaja posla kolegi — napiši predaju (write) ili preuzmi tuđu (pickup).
argument-hint: write|pickup [task]
---

# Handoff

Dvoje ljudi rade na ovom repou, oboje kroz Claude Code, na različitim mašinama (Windows bez iOS-a,
macOS bez Dockera). Kontekst se ne prenosi između sesija — prenosi se **kroz repo**. Ovaj skill
piše i čita tu predaju.

Kanonsko mjesto predaje je **status blok**: `## Status (YYYY-MM-DD)` na dnu task fajla, plus
skraćena verzija u `tasks/README.md` ispod tabele. Ne pravi nove "handoff" fajlove — dva mjesta
koja se čitaju su bolja od pet koja zastarijevaju.

Režim: **$ARGUMENTS** (bez argumenta → `write`).

---

## `write` — predajem posao

Napiši predaju za osobu koja sutra sjeda i **ne zna ništa** o tvojoj sesiji. Skupi materijal prije
pisanja: `git log main..HEAD`, `git status`, `git diff main --stat`, zadnji CI runovi
(`gh run list --limit 5`), i trenutni task fajl.

Status blok sadrži, tim redom:

1. **Stanje jednom rečenicom** — ✅ zatvoreno, 🟡 dijelom, ⛔ blokirano.
2. **Šta je dokazano i čime.** Komanda + stvaran (skraćen) izlaz, ili link na CI run. Bez ovoga
   sljedeća osoba ponavlja tvoj posao da bi se uvjerila.
3. **Šta je napisano ali nije dokazano**, i zašto (nema macOS-a, nema uređaja, nema naloga).
   Ovo je najvrjedniji dio predaje i najčešće se izostavi.
4. **Ostalo za sljedećeg** — konkretni koraci, sa komandom kojom se počinje.
5. **Zamke** koje si našao. Onu koja se ponavlja ne piši samo ovdje nego i u kod/dokument gdje se
   dešava (`.claude/docs/tenant-factory.md` ima svoj odjeljak zamki).
6. **Otvorena pitanja** koja traže odluku, ne rad. Ako je odluka donesena — ADR, ne status blok.

Zatim:

- Ažuriraj oznaku taska u tabeli `tasks/README.md` (✅ / 🟡) i njegov kratki blok ispod.
- Prođi tabelu sinhronizacije iz `CLAUDE.md`; dokument koji je promjena dotakla ide u istu predaju.
- Na kraju ispiši **kratku poruku za PR/chat** (5–8 redova): stanje, dokaz, sljedeći korak. To je
  ono što kolega stvarno pročita prije nego otvori repo.

Ne piši predaju u prvom licu prošlom vremenu bez subjekta ("urađeno je") — piši šta stoji u repou
danas i šta sljedeći treba uraditi.

---

## `pickup` — preuzimam tuđi posao

Prije nego dotakneš ijedan fajl:

1. **`git status` i `git log --oneline -10`.** Rad na grani je često necommitan; provjeri prije
   bilo čega destruktivnog (`checkout`, `reset`, `stash`, `clean`).
2. Pročitaj `tasks/README.md` (tabela + status blokovi), pa cijeli task fajl na kojem se stalo.
3. Pročitaj `CLAUDE.md` i dokumente koje task dodiruje — ne kreni od koda.
4. **Provjeri tvrdnje predaje, ne vjeruj im.** Pokreni `dart run tool/gen_flavors.dart --check`,
   `melos run analyze`, i pogledaj zadnji CI run za granu. Predaja stara sedam dana opisuje repo
   od prije sedam dana.
5. Provjeri šta **tvoja** mašina može, a prethodna nije mogla (Docker? macOS? uređaj?). To je
   često najvrjednije što možeš doprinijeti — otključati dokaz koji je stajao.
6. Ispiši: gdje se stalo, šta si potvrdio, šta se ne slaže sa predajom, i šta radiš prvo.

Ako se predaja i repo ne slažu — repo je u pravu. Ispravi predaju u istoj promjeni.
