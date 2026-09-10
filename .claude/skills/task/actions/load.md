# load

1. Nađi task: `$ARGUMENTS` može biti broj (`03`), slug (`flavor-system`) ili puna putanja.
   Ako ništa nije dato — greška, traži broj taska.
2. Pročitaj **cijeli** task fajl, plus njegov status blok u `tasks/README.md`, plus dokumente na
   koje task pokazuje (`docs/NN-...`).
3. Provjeri zavisnosti iz tabele u `tasks/README.md`. Ako blokirajući task nije ✅, reci to i stani.
4. Uporedi DoD sa stvarnim stanjem repoa — čekirana stavka nije dokaz. Pogledaj postoje li fajlovi,
   prolazi li CI, radi li komanda iz koraka.
5. Ispiši sažetak: cilj, šta je već urađeno, **šta je stvarno ostalo**, i koje su poznate zamke
   (iz status bloka i iz `.claude/docs/`).

Ne mijenjaj nijedan fajl u ovoj akciji.
