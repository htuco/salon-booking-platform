# load

1. Nađi task: `$ARGUMENTS` može biti broj (`06`), slug (`vertical-pack`) ili puna putanja. Traži u
   `tasks/` i `tasks/sprint-*/`. Ako ništa nije dato — greška, traži broj taska.
2. Pročitaj **cijeli** task fajl, njegov status blok u odgovarajućem `README.md`, i dokumente na
   koje task pokazuje (`docs/NN-...`, `.claude/docs/...`).
3. Provjeri zavisnosti iz tabele. Ako blokirajući task nije ✅, reci to i stani.
4. **Uporedi DoD sa stvarnim stanjem repoa** — čekirana stavka nije dokaz, a nečekirana nije nužno
   neurađena. Pogledaj postoje li fajlovi, tabele, kolone i seed redovi; prolazi li CI; radi li
   komanda iz koraka. Ovaj korak redovno nađe da je dio taska već isporučen kroz raniji.
5. Ako je `tasks/CURRENT.md` popunjen drugim taskom koji nije `Gotov`, stani i pitaj — jedan aktivni
   task odjednom. Ako jeste `Gotov`, njegov sažetak ide u `## Istorija` prije prepisivanja.
6. Prepiši `tasks/CURRENT.md`:
   - `# Trenutni task: <NN> — <naziv>` + link na puni task i datum učitavanja
   - `## Status` → `Nije počet`
   - `## Ciljevi` → checkbox lista **onoga što stvarno preostaje**, ne prepisan DoD
   - `## Napomene` → šta je već isporučeno i gdje je to provjereno, zavisnosti kojih nema u task
     fajlu, zamke iz `.claude/docs/`, i korigovana procjena ako nalazi iz koraka 4 to traže
   - `## Istorija` → netaknuta
7. Ispiši sažetak: cilj, šta je već urađeno, šta preostaje, šta blokira.

Ne mijenjaj nijedan drugi fajl u ovoj akciji.
