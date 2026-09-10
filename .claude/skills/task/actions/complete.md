# complete

Zatvaranje taska. Ne pokreći dok `/task review` i `/task verify` nisu prošli.

1. **`tasks/CURRENT.md`**: `## Status` → `Gotov`, pa dopiši jednoredni sažetak na **kraj**
   `## Istorija` (`**<NN> — naziv** (datum) — šta je isporučeno i čime je dokazano`), isprazni
   `## Ciljevi` i `## Napomene`, i vrati naslov na `# Trenutni task` dok se ne učita sljedeći.
2. **Status blok** u task fajlu: `## Status (YYYY-MM-DD) — ✅ zatvoren` ili `🟡` sa tačnim
   "ostalo za sljedećeg" i komandom kojom se nastavlja.
3. **`tasks/README.md`** (ili `tasks/sprint-N/README.md`): ažuriraj oznaku u tabeli i status blok ispod nje. Taj blok piše se za
   osobu koja sjeda sutra i ne zna ništa — šta je dokazano, čime, i gdje je sljedeći korak.
4. **Dokumenti**: prođi tabelu sinhronizacije iz `CLAUDE.md` i ažuriraj sve što je promjena
   dotakla. Ako je task donio odluku koja se ne vidi iz koda → novi ADR u `docs/adr/`.
5. **Commit**: Conventional Commits, naslov na bosanskom u imperativu. Tijelo nosi *zašto*, koje su
   zamke nađene i **čime je dokazano**. Prati stil postojećeg `git log`-a.
6. **Push grane i PR protiv `main`.** U opisu PR-a: cilj taska, šta je dokazano (sa izlazima), šta
   nije provjereno i zašto.
7. Sačekaj CI. Crveni job je dio taska, ne tuđi problem.
8. Ponudi `/handoff` ako posao ostaje otvoren za nekog drugog.

Ne mergaj i ne briši granu bez izričite potvrde korisnika.
