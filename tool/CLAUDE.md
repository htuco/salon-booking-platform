# tool/ — generatori

Alati koji iz `tenants/*/tenant.yaml` proizvode sve što build treba. Greška ovdje se množi kroz sve
tenante, pa su pravila stroža nego u ostatku repoa. Root pravila važe — v. `../CLAUDE.md`.

## Pravila

- **Piši samo između markera.** `gen_flavors.dart` mijenja gradle blok između
  `BEGIN/END GENERATED FLAVORS` i ništa izvan njega. Svaki izlaz nosi
  `GENERISANO — ne editovati ručno`.
- **Svaki generator ima `--check` režim** koji pada ako je izlaz zastario; to je ono što CI zove.
- **Nikad ne prepisuj tuđi rad bez `--force`.** `gen_placeholder_icons.dart` ne dira postojeću
  ikonu — dizajnerski asset ne smije nestati na sljedećem pokretanju.
- **Strukturirani fajl se mijenja alatom, ne tekstom.** `project.pbxproj` ide kroz `xcodeproj` gem
  ([ADR-0004](../docs/adr/0004-ios-flavori-kroz-xcodeproj-gem.md)) — neispravan pbxproj ruši sve
  flavore odjednom, a vidi se tek kad se otvori Xcode.
- **Validiraj ulaz prije nego išta dotakneš**: `flavor` mora biti `[a-z][a-z0-9]*` i isto kao ime
  foldera, `salonId` mora biti UUID koji postoji u `supabase/seed.sql`.
- **Ne pretpostavljaj oblik okruženja.** `gen_ios_flavors.sh` probava sve vjerodostojne `GEM_HOME`
  kandidate jer `pod` nije isti na Homebrew mašini i na GitHub runneru — pretpostavka je već jednom
  pala na CI-ju.
- `avoid_print` je uključen globalno; alat koji stvarno piše na stdout nosi `// ignore:` sa
  obrazloženjem, ne gasi pravilo.

Puni lanac i zamke: `../.claude/docs/tenant-factory.md`.
