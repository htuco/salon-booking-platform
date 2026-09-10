# review

Pregled prije nego što se task zatvori. Cilj je naći ono što ne valja, ne potvrditi da valja.

1. Pročitaj DoD iz task fajla. Za **svaku** stavku odgovori jednim od: dokazano (i čime),
   napisano ali nedokazano, nije urađeno.
2. `git diff main --stat`, pa pročitaj cijeli diff. Traži:
   - ✅ ispunjeno iz DoD-a
   - ❌ neispunjeno ili polovično
   - ⚠️ kvalitet: prekršena konvencija (`.claude/docs/conventions.md`), ručno editovan generisani
     fajl, tvrdnja u komentaru koja nije tačna
   - 🚫 scope creep — promjene koje task nije tražio
3. Ako diff dira `supabase/` → pokreni subagent `rls-auditor`.
   Ako dira Dart → `dart-reviewer`. Ako dira ekrane → `flutter-ui-reviewer`.
4. Provjeri sinhronizaciju dokumenata po tabeli u `CLAUDE.md`. Promjena koja mijenja opisano
   ponašanje a ne dira dokument je nekompletna promjena.
5. Verdikt: spremno za `/task verify`, ili tačna lista onoga što fali.
