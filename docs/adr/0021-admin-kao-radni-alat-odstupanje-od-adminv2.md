# Admin kao radni alat — gdje se smije odstupiti od `adminv2`

## Status

predložen — čeka vlasnika proizvoda. Dok nije prihvaćen, važi
[ADR-0020](0020-admin-je-1na1-sa-adminv2-barlow-i-svijetla-tema.md) i taskovi FE-6xx su blokirani.

## Kontekst

Stigao je UI prijedlog za admin (2026-09-23) koji admin vidi kao **radnu površinu**, ne pregled
brojki: zahtjevi sa odobri/odbij u redu na vrhu dashboarda, kalendar kao glavni ekran sa
povlačenjem termina, gušće tabele, ⌘K paleta, prečice, brzo kreiranje u bočnom panelu, undo
umjesto potvrde, kontekstni panel na širokim ekranima.

To se kosi sa ADR-0020, koji kaže da je admin **1:1 sa `prototype/adminv2/export/`** i da je crtež
jači od izostavljanja. Dio prijedloga ne mijenja crtež (stanja, prečice, paleta), dio ga mijenja
(raspored dashboarda, gustoća reda), a dio mijenja ponašanje (povlačenje termina, undo).

Činjenice iz koda na `main`-u (`4e92803`):

- Koralna `#EE6C4D` je u adminu **platformska boja**, ne tenant boja (ADR-0018 važi samo za
  klijenta). Prijedlog „koralna samo za jednu primarnu akciju" zato nije pitanje brendiranja nego
  hijerarhije — i FE-402 je to već djelimično zatvorio („Novi termin" je jedina koralna akcija),
  ali je obrub kartice „Čeka potvrdu" namjerno koralan jer ga `3b` tako crta.
- Barlow i `barlowTabular` su već uvedeni (ADR-0020) — „tabular nums" je zatečeno, ne novo.
- Status termina već nosi razliku oblikom: isprekidan rub za `pending` (FE-403).
- Nijedan admin ekran nema `Shortcuts`/`Actions`; potvrde idu kroz `AlertDialog`
  (`appointment_actions_bar.dart`, `appointments_screen.dart`).
- Novi termin je zaseban ekran (`new_appointment_screen.dart`), ne panel.
- Fluidni layout do 2560 px je gotov (FE-406); desnog kontekstnog panela nema.

## Odluka

Predlaže se podjela u tri grupe, svaka sa drugačijim pravom:

1. **Bez odstupanja od crteža — ulazi odmah po prihvatanju.** Stanja (FE-501 proširen na sve
   admin ekrane), tastaturne prečice, ⌘K paleta, linija trenutnog vremena i sticky zaglavlje
   kalendara. `adminv2` ih ne crta, ali ih ni ne isključuje; to je ponašanje, ne izgled.
2. **Odstupanje od crteža — ulazi kao izmjena handoffa.** Raspored dashboarda (zahtjevi na vrh,
   statistika sekundarna), gustoća reda 40 px, bočni panel za novi termin, desni kontekstni panel,
   tri nivoa naslova. Za svaki se prvo dopuni `prototype/adminv2/` (ili zapiše odstupanje u
   `prototype/admin/SPEC.md`), pa tek onda kod — inače ADR-0020 i ekran govore različito.
3. **Promjena ponašanja — svaka svoj ADR.** Povlačenje termina (dira `appointments`, exclusion
   constraint, obavijest klijentu) i undo umjesto potvrde (obavijest klijentu o otkazivanju je već
   otišla ako se šalje odmah).

## Razmatrane opcije

- **Primijeniti prijedlog u cjelini** — odbačeno: poništava ADR-0020 prećutno, a vlasnik je 1:1
  tražio izričito prije dva dana.
- **Odbiti prijedlog jer ADR-0020 važi** — odbačeno: grupa 1 ne dira crtež, a stanja i prečice su
  stvarna rupa (svi mockovi su „happy path").
- **Undo za sve destruktivne akcije** — odgođeno: vraća se kad obavijest klijentu ide sa
  zakašnjenjem jednakim trajanju toasta.

## Posljedice

- Taskovi FE-601…FE-608 u `tasks/fe-redizajn/` su blokirani ovim ADR-om; grupa 2 dodatno čeka
  dopunu handoffa, grupa 3 čeka svoj ADR.
- Ako se prihvati, `docs/README.md` tabela odluka dobija red, a `prototype/CLAUDE.md` rečenicu da
  `adminv2` nije konačan za ekrane iz grupe 2.
- Admin će neko vrijeme odstupati od izvoza tamo gdje je handoff dopunjen, a izvoz nije ponovo
  urađen — to je očekivano, ne bug.
