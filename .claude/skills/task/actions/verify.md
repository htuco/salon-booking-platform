# verify

Zaobiđi tvrdnju, uzmi dokaz. Pokreni recept iz `/verify` skilla koji odgovara tipu promjene
(`.claude/skills/verify/SKILL.md`).

1. Odredi tip: Dart/widget · flavor/build · Supabase/RLS · CI · prototip.
2. Pokreni komande iz tog recepta i **sačuvaj stvarni izlaz** — ne prepričavaj ga.
3. Za sve što se ne može dokazati u ovom okruženju (Docker, macOS, uređaj), reci to eksplicitno i
   navedi ko/gdje to može dokazati.
4. Upiši dokaz u `## Status (YYYY-MM-DD)` blok task fajla: komanda, skraćen ali stvaran izlaz, i
   šta iz toga slijedi.
5. Tek sad čekiraj DoD stavke koje su pokrivene dokazom.

Ako nešto padne — to nije neuspjeh verifikacije nego nalaz. Popravi, pa ponovo.
