# GitHub Actions umjesto Codemagica za Flutter buildove

## Status

prihvaćen

## Kontekst

[Task 04](../../tasks/sprint-0/04-ci-pipeline.md) i [04 §8](../04-flutter-tenant-factory.md#8-cicd) ostavljaju izbor otvoren: Codemagic za Flutter build/store matricu, GitHub Actions za `supabase/` i web. Codemagic je specijalizovan za Flutter, ima gotovu store publikaciju i macOS runnere bez podešavanja.

U praksi je repo već dobio dva GitHub Actions workflowa (`Flutter` i `Supabase tests`) prije nego što je odluka formalno donesena, a oni već rade ono što je najteže: matricu po tenantu, iOS build na `macos-latest`, i provjeru na gotovom artefaktu.

## Odluka

**Jedan CI sistem — GitHub Actions.** Codemagic se ne uvodi.

Store publikacija (upload u Play Console / App Store Connect), koja je bila najjači Codemagicov argument, radi se preko `fastlane` iz istog GitHub Actions workflowa kad dođe Sprint 3, ili ručno za prvih nekoliko izdanja.

## Razmatrane opcije

- **Codemagic za Flutter + GH Actions za ostalo** — odbačeno: dva CI sistema znače dvije konfiguracije, dva mjesta za secrets i dva mjesta gdje treba tražiti zašto je build pao. Za tim od dvoje ljudi to je trošak bez pokrića.
- **Samo Codemagic** — odbačeno: `supabase/` testovi (Docker, pgTAP, Deno) su prirodno GH Actions posao, a Codemagicova vrijednost je u Flutter dijelu koji nam već radi.
- **Codemagic kasnije, samo za store publikaciju** — odgođeno, ne odbačeno: ako se ispostavi da `fastlane` matrica na 20 tenanata postane teret, ovo se ponovo otvara. Novi podatak koji bi to tražio: vrijeme koje mjesečno gubimo na store upload.

## Posljedice

- Sve što CI radi živi u `.github/workflows/`, a ulaz u build je `tool/build_tenant.sh` — CI ne drži svoju kopiju `flutter build` komande, jer bi lokalni i CI build tiho odlutali.
- macOS runneri se plaćaju po minuti i troše 10× kvotu privatnog repoa. Zato iOS job radi samo `--debug --no-codesign`, a release AAB job je na ručnom triggeru, ne na svaki PR.
- Store publikacija nije riješena ovom odlukom, samo odgođena. Sprint 3 mora izabrati `fastlane` ili ručni upload.
