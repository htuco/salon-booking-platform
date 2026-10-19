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
- [x] Na webu gdje šema nije podržana — nema dugmeta, ne mrtvo dugme
- [ ] Widget test: bez telefona nema akcije; uživo na Android uređaju sve tri akcije

## Zamke
- Broj se normalizuje u međunarodni oblik (`+387…`) prije `wa.me`; lokalni `06x` ne radi.
- Task 54 ne smije ukloniti „Pozovi" ako ovaj task ide u sprint.

## Status (2026-10-19)

U toku, grana `feat/kontakt-jednim-tapom`. Kod i testovi su gotovi, ostaje Android uređaj.

- **Oblik:** `apps/admin/lib/src/core/kontakt.dart` drži pravila: normalizaciju, URI, kanale po
  platformi i launcher kao provider. „Poruka" iz `3n` otvara sheet Viber / WhatsApp, jer canvas crta
  jedno dugme, a kanala su dva. Na webu Vibera nema, pa „Poruka" ide pravo na WhatsApp. Profil
  (`3e`) dobija „Pozovi" i „Poruka" uz „Zakaži termin". Bez broja, ili uz broj od kojeg nema
  linka, oba dugmeta nestaju. Kad uređaj link ne može otvoriti, info toast to kaže.
- **Normalizacija:** vodeća `0` → `+387`, `00` → `+`, dozvoljeno 8–15 cifara. Pretpostavka BiH
  tržišta je zapisana u komentaru funkcije; baza se ne mijenja.
- **Dokaz:** `melos run test` → admin `+694: All tests passed!` (bilo je 677), client i `core_*`
  `SUCCESS`; `melos run analyze` `SUCCESS`; `dart format` bez promjena. Novi `kontakt_test`
  (normalizacija, URI, kanali) i grupe „kontakt jednim tapom (task 58)" u `appointment_detail_test`
  (6) i `clients_screen_test` (2). Mutacije: dugmad i bez broja → pada „broj od kojeg nema linka se
  ne nudi"; Viber na webu → pada „na webu nema Vibera".
- **Uživo (web demo, 402 px):** detalj termina pokazuje „Pozovi · Poruka · Profil". Za broj
  `061 552 104` „Poruka" otvara `api.whatsapp.com/send/?phone=38761552104` (preusmjereno sa `wa.me`).
- **Ostalo za sljedećeg:** sve tri akcije na Android uređaju (`tool/run_live_demo.sh admin -d
  <device-id>`, pa detalj termina → Pozovi, Poruka → Viber, Poruka → WhatsApp). Na ovoj mašini nema
  ni uređaja ni emulatora.
