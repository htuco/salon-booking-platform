# start

1. Pročitaj `tasks/CURRENT.md`. Ako `## Ciljevi` nije popunjen — greška: "Pokreni `/task load <NN>` prvo".
   Potvrdi da su zavisnosti gotove.
2. Provjeri da je radno stablo čisto (`git status`) i da si na `main` sa svježim `git pull`.
3. Otvori granu sa svježeg `main`-a: `feat/<kratko-ime>` ili `fix/<kratko-ime>`, izvedeno iz taska.
   **Nikad ne radi na `main`-u** — grana se pravi prije prve izmjene, ne poslije.
4. Postavi `## Status` u `tasks/CURRENT.md` na `U toku`, i 🟡 u tabeli odgovarajućeg `README.md`.
5. Nakon prvog commita: `git push -u origin <grana>` pa `gh pr create --draft --base main` sa
   opisom po `.github/pull_request_template.md`. PR stoji otvoren dok rad traje.
6. Idi kroz korake iz taska **redom**, čekirajući stavke u `## Ciljevi` kako dobijaju dokaz. Redoslijed je pisan tako da svaki korak može biti dokazan
   prije sljedećeg; preskakanje znači da će pola dokaza morati nazad.
6. Prije nego što napišeš kod za neki korak, pročitaj dokument koji taj korak spominje —
   `.claude/docs/security.md` za sve što dira `supabase/`, `.claude/docs/tenant-factory.md` za sve
   što dira flavore.
