# Šablon za nove subagente

Kopiraj `_new-subagent.template.md` u `.claude/agents/<ime>.md` i popuni `{{...}}`. Ovaj folder
namjerno nije `.claude/agents/` — šablon ne smije biti živ agent.

## Frontmatter

| Polje | Napomena |
|---|---|
| `name` | kebab-case, isto kao ime fajla bez `.md` |
| `description` | **okidač, ne opis.** Po ovome se agent bira automatski — piši "kada", ne "šta" |
| `tools` | najuži skup koji posao traži. Revizor ne treba `Edit` ni `Write` |
| `model` | `opus` za prosuđivanje, `haiku` za mehaničko pretraživanje |

## Šta agent treba biti u ovom repou

- **Uzak.** Jedan agent = jedna vrsta nalaza. `rls-auditor` ne komentariše stil Darta.
- **Ukorijenjen u dokumente.** Prvi korak je uvijek "pročitaj `.claude/docs/<x>.md`" — inače agent
  revidira po opštem znanju, a ne po pravilima ovog projekta.
- **Konkretan u izlazu.** Putanja, linija, scenario, popravak. Bez "razmisliti o poboljšanju".
- **Iskren o tome šta nije mogao provjeriti.** Čitanje SQL-a nije dokaz da RLS radi; screenshot bez
  `--dart-define=SALON_ID` nije dokaz teme.

Postojeći agenti su primjeri: `rls-auditor` (najstroži), `dart-reviewer`, `duplication-scanner`,
`flutter-ui-reviewer`.
