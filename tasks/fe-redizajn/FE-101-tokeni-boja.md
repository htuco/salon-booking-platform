# FE-101 — Paleta kao dizajn tokeni

| | |
|---|---|
| **Epik** | FE-1 · Temelji i dizajn tokeni |
| **Aplikacija** | `apps/client` + `apps/admin` |
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | ADR o koralnoj na klijentu (v. [README](README.md)) |
| **Blokira** | FE-3xx, FE-4xx |
| **Reference** | `apps/admin/lib/src/core/theme/admin_colors.dart` · `packages/core_ui/lib/src/theme/theme_factory.dart` · `prototype/admin/SPEC.md` |

## Cilj
Handoff traži da boje odu u tokene i da koralna bude akcent. **Veći dio toga već postoji** — ovaj
task zatvara ostatak i, što je važnije, sprječava da se koralna upiše na mjesto gdje je ne smije biti.

## Zatečeno stanje
Ne ono što task iz handoffa pretpostavlja:

- Boje **jesu** centralizovane. Od 135 `Color(0x…)` u repou, 129 stoji u tri token fajla:
  `apps/admin/lib/src/core/theme/admin_colors.dart` (76), `packages/core_ui/lib/src/theme/app_theme.dart`
  (33) i `packages/core_ui/lib/src/tokens/status_colors.dart` (20).
- Kriterij „nema hex vrijednosti izvan token fajla" **već je test koji pada**:
  `apps/admin/test/no_hardcoded_colors_test.dart` čita izvor svakog admin ekrana i prijavljuje
  `Color(0x`, `Color.fromARGB` i `Colors.*`. Klijent takav test nema.
- Koralna `#EE6C4D` je specificirana i implementirana kao akcent **admina**
  (`prototype/admin/SPEC.md:82`, tekst na koralu `#2C2C2C`).
- Van tokena su ostala dva mjesta: `packages/core_ui/lib/src/components/app_dialog.dart` i
  `packages/core_ui/lib/core_ui.dart`.

## Definicija gotovog
- [x] Dva preostala hex-a u `core_ui` idu u tokene — ispalo ih je **tri, ne dva** (v. ispod)
- [x] Klijent dobija svoj ekvivalent `no_hardcoded_colors_test`
- [x] Koralna ostaje **admin** akcent; klijentska brand boja i dalje dolazi iz `tenant.yaml`
      kroz `buildAppTheme()` — sada i **provedeno testom**, ne samo pregledom
- [x] Kontrast teksta na koralnoj ≥ 4,5:1 dokazan testom — `apps/admin/test/theme_contrast_test.dart`
      to **već mjeri** na `filledButtonTheme` i na FAB-u, dakle na onome što se stvarno iscrtava
- [x] Dark/light varijante klijenta ostaju van obima — zapisano kao dug u `README` epika

## Zamke
- **Ovo je task u kojem je najlakše slomiti multi-tenant.** `primary` u klijentu nije boja nego
  vrijednost po salonu; koralna kao globalni `primary` prolazi analizu, prolazi testove i vidi se
  tek kad se pokrene drugi flavor.
- `Colors.transparent` je jedini izuzetak koji admin test već priznaje — nije boja nego odsustvo
  boje, i tema njime gasi Material `surfaceTint`.
- Token fajl nije mjesto za „skoro istu" boju. Dvije nijanse iste uloge su znak da uloga fali.

## Status

**Gotovo, dokazano.** Grana `feat/fe-101-tokeni-boja`.

### Hex-ova je bilo tri, ne dva

Task je nabrajao `app_dialog.dart` i `core_ui.dart`. Stvarno stanje:

- `core_ui.dart` je bio **lažan pogodak** — heks je tamo u doc komentaru, ne u kodu.
- `app_dialog.dart:76` — scrim `Color(0xB80B0C0D)`, **jeste** bio hardkodiran.
- `theme_factory.dart:73-74` — `error` i `onError`, koje task **nije spomenuo**. Bili su
  heks uz `jeTamna` granu, pa su **dvije svijetle teme dijelile jednu vrijednost**, a
  tamna dobijala svoju. To je bila greška koja se vidi tek na `elegantBeauty` temi.
- `contrast.dart:34-35` — crna i bijela ostaju heks **namjerno**: to su konstante
  algoritma koji bira čitljiviju od te dvije, ne paleta. Izuzetak je napisan, ne prećutan.

Sva tri stvarna hex-a su sada tokeni u `AppNeutrals` (`scrim`, `error`, `onError`), po
temi različiti, i idu u `ColorScheme` kroz `buildAppTheme()`.

### Guard test je glavni dio, ne hex

Hex-ovi su bili tri reda. Ono što task stvarno zatvara je `apps/client/test/no_hardcoded_colors_test.dart`
— blizanac admin testa, ali sa jačim razlogom: u adminu pogrešna boja izgleda pogrešno
svima **odmah**, a u klijentu prolazi svaki test i svaki pregled, jer testovi i demo crtaju
**jedan** tenant. Vidi se tek kad drugi salon otvori aplikaciju, a tada je već u storeu.

**Provjereno da stvarno pada:** privremeno upisana `Color(0xFFEE6C4D)` u
`gallery_lightbox.dart` — tačno greška pred kojom
[ADR-0018](../../docs/adr/0018-klijent-nema-fiksnu-koralnu-boja-ostaje-tenant-podatak.md)
upozorava — prijavljena je uz fajl i broj reda.

Dva napisana izuzetka: `lib/src/generated/` (registar tenanata nosi brand boje **kao
podatak iz `tenant.yaml`**, što je i ispravan izvor) i `demo_main.dart` (glumi backend).

### Dokaz

**613 testova PASS** — admin 309, klijent 237, `core_ui` 67. Analiza i format čisti.

**Zamka pri pokretanju:** testovi koji čitaju izvor (`no_hardcoded_colors_test` u obje
aplikacije, `theme_tokens_test`) koriste **relativne** putanje, pa moraju ići iz korijena
svog paketa. `flutter test apps/admin` iz korijena repoa im obori pet testova sa
`PathNotFoundException: lib\*` — to nije regresija nego pogrešan radni folder.

