# Task 58 — Kontakt klijenta jednim tapom

| | |
|---|---|
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | [66](66-registracija-ime-telefon-tos.md) |
| **Blokira** | — |
| **Reference** | `docs/01` §6.3 („Kontakt klijenta jednim tapom") · `prototype/admin/SPEC.md` (`3n`, `3e`) |

## Cilj
Iz detalja termina i profila klijenta vlasnik jednim tapom pozove klijenta ili mu piše na Viber/WhatsApp.

## Definicija gotovog
- [x] `url_launcher` kao zavisnost admina
- [x] `tel:`, `viber://chat?number=` i `https://wa.me/` iz detalja termina i profila klijenta
- [x] Prikazuje se samo klijentu koji ima upisan telefon — od taska 66 to su i klijenti iz aplikacije
- [ ] Na webu gdje šema nije podržana — nema dugmeta, ne mrtvo dugme (Viber je na webu sakriven i
      to je dokazano testom; `tel:` na webu ostaje uz „Pozovi" i nije provjeren, a launcher na webu
      uvijek javi uspjeh, pa ni toast tamo ne bi uhvatio mrtvo dugme)
- [ ] Widget test: bez telefona nema akcije; ručno na iOS simulatoru ili Android emulatoru **i** na
      pravom uređaju sve tri akcije (Hamzina odluka, 2026-10-20 — widget test glumi launcher i ne
      dokazuje da link otvara aplikaciju)

## Zamke
- Broj se normalizuje u međunarodni oblik (`+387…`) prije `wa.me`; lokalni `06x` ne radi.
- Task 54 ne smije ukloniti „Pozovi" ako ovaj task ide u sprint.

## Status (2026-10-20)

U toku, grana `feat/kontakt-jednim-tapom`, [PR #138](https://github.com/htuco/salon-booking-platform/pull/138). Kod i testovi su gotovi, ostaje ručni test na simulatoru i na uređaju.

- **Oblik:** `apps/admin/lib/src/core/kontakt.dart` drži pravila: normalizaciju, URI, kanale po
  platformi i launcher kao provider. „Poruka" iz `3n` otvara sheet Viber / WhatsApp, jer canvas crta
  jedno dugme, a kanala su dva. Na webu Vibera nema, pa „Poruka" ide pravo na WhatsApp. Profil
  (`3e`) dobija „Pozovi" i „Poruka" uz „Zakaži termin". Bez broja, ili uz broj od kojeg nema
  linka, oba dugmeta nestaju. Kad uređaj link ne može otvoriti, info toast to kaže.
- **Normalizacija:** vodeća `0` → `+387`, `00` → `+`, dozvoljeno 8–15 cifara, a za `+387`
  11–12 (BiH nacionalni broj bez nule ima 8 ili 9 cifara). Broj bez nule i bez pozivnog je BiH
  samo do 9 cifara; duži je strani broj bez `+` i nema link. `+061 …` se čita kao lokalni, a
  `+00387 …` kao `+387 …`. Pretpostavka BiH tržišta je zapisana u komentaru funkcije; baza se ne
  mijenja.
- **Dokaz:** admin `+701: All tests passed!` (prije taska 677); `melos run analyze` `SUCCESS`;
  `dart format` bez promjena. Novi `kontakt_test` (14: normalizacija, URI, kanali) i grupe
  „kontakt jednim tapom (task 58)" u `appointment_detail_test` (8) i `clients_screen_test` (2).
  Mutacije: dugmad i bez broja → pada „broj od kojeg nema linka se ne nudi"; Viber na webu → pada
  „na webu nema Vibera"; sheet bez skrolanja → pada landscape test (`RenderFlex overflowed by 27
  pixels`); stara normalizacija → padaju tri nova testa normalizacije (`+387385912345678`,
  `+3876155210499`, `+061552104`).
- **Pregled (2026-10-20):** `dart-reviewer` i `flutter-ui-reviewer` nisu našli ništa kritično.
  Popravljeno je sljedeće: `+387 061 …` i `00387 061 …` gube nulu; BiH broj sa pozivnim koji
  ima manje od 11 cifara nema link (`12345` ga je dobijao); izuzetak launchera ide u log i ima
  svoj test; u sheetu oba kanala više nemaju istu ikonu; bez broja „Profil" zauzima trećinu
  reda. Svjesno je ostavljeno:
  broj u sheetu je normalizovan (to je broj koji se bira), na dugmadi nema `Semantics` sa
  imenom klijenta, a `height: 50` u redu iz `3n` je literal (bio je i prije).
- **Drugi pregled (2026-10-20):** sheet „Poruka" je u landscapeu sa notchom (667×375) prelazio
  visinu za 27 px i WhatsApp se nije mogao tapnuti — sad skrola kao „Šta dodajemo?" iz shella, uz
  test. Strani broj bez `+` (`385 91 …`, `49 151 …`) više ne dobija lažni `+387`, a `+0…` više ne
  daje broj sa `+0`. Komentari o webu ispravljeni: launcher na webu uvijek javi uspjeh, pa toast
  tamo ne hvata neuspjeh, a `tel:` na webu nije provjeren (DoD stavka o webu je zato odčekirana).
- **Uživo (web demo, 402 px):** detalj termina pokazuje „Pozovi · Poruka · Profil". Za broj
  `061 552 104` „Poruka" otvara `api.whatsapp.com/send/?phone=38761552104` (preusmjereno sa `wa.me`).
- **Ostaje — ručni test, obavezan prije nego je task gotov (Hamzina odluka, 2026-10-20).**
  Widget testovi glume launcher i ne dokazuju da link stvarno otvara aplikaciju. Na iOS
  simulatoru ili Android emulatoru **i** na pravom uređaju:
  1. `flutter devices`, pa `tool/run_live_demo.sh admin -d <device-id>` (traži `.env.live`).
  2. Detalj termina klijenta sa brojem → „Pozovi", „Poruka" → Viber, „Poruka" → WhatsApp.
  3. Profil klijenta (`3e`) → isto.
  4. Broj sa nulom (`061 552 104`) i bez nje (`+387 61 552 104`): isti broj u pozivu i chatu.
  5. Uređaj bez Vibera → toast „Viber se ne može otvoriti."
  6. Telefon u landscapeu: sheet „Poruka" skrola i WhatsApp se tapne.

  **Simulator/emulator:** iOS simulator nema ni Phone ni Viber, pa „Pozovi" i Viber trebaju
  pokazati toast — to je ujedno provjera toasta; WhatsApp otvara `wa.me` u Safariju. Android
  emulator ima dialer, pa „Pozovi" otvara dialer sa `+38761552104`; Viber bez aplikacije → toast;
  WhatsApp → `wa.me` u pregledniku. **Uređaj:** „Pozovi" nudi poziv na `+387 …`, Viber i WhatsApp
  otvaraju chat sa tim brojem (gdje su instalirani). Na ovoj mašini nema ni uređaja ni emulatora.
