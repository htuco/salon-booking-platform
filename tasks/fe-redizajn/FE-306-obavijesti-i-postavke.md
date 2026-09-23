# FE-306 — Obavijesti i postavke

| | |
|---|---|
| **Epik** | FE-3 · Klijentski ekrani |
| **Aplikacija** | `apps/client` |
| **Procjena** | 1–2 dana |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | `apps/client/lib/src/features/notifications/`, `account/`, `legal/` · `prototype/ui/screenshots/10-obavijesti.png`, `11-postavke.png`, `14-o-aplikaciji.png`, `15-pravila-koristenja.png` |

## Cilj
Lista obavijesti (pročitano/nepročitano) i postavke sa jezikom, notifikacijama i odjavom.

## Zatečeno stanje
- Svi ekrani postoje: `features/notifications/`, `features/account/` (postavke, brisanje naloga),
  `features/legal/` (pravila), `features/about/` („O aplikaciji").
- **„O aplikaciji" je jedini ekran koji prikazuje verziju**, i ona dolazi iz `tenant.yaml` kroz
  `--build-name`, ne iz `pubspec.yaml`. Redizajn ne smije taj izvor zamijeniti konstantom.
- **Pravila se sastavljaju iz dvije tabele** ([ADR-0009](../../docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md)):
  platformske sekcije iz `app_policies` i salonske iz `salon_policies`. Prikazani broj sekcije
  (`01..NN`) **nije pohranjen** nego je pozicija u spojenoj listi. Tijela nose `{minCancelHours}`,
  `{phone}`, `{email}`, `{appointmentSingular}`, koje klijent puni iz živih podataka, a
  **nerazriješen placeholder ostaje vidljiv namjerno**.
- Odjava i brisanje naloga su dva različita toka; brisanje ide kroz Edge Function.

## Definicija gotovog
- [ ] Označavanje kao pročitano mijenja badge bez ponovnog učitavanja ekrana — **nema izvora podataka, v. Status**
- [x] Postavke grupisane po handoffu — `11-postavke.png` crta jednu grupu bez naslova
- [x] Odjava traži potvrdu (modal iz [FE-203](FE-203-modali-i-bottom-sheet.md))
- [x] Brisanje naloga ostaje odvojeno od odjave i zadržava svoje upozorenje
- [x] Pravila i dalje spajaju dvije tabele; numeracija se i dalje računa, ne upisuje
- [x] Verzija u „O aplikaciji" i dalje dolazi iz build parametara

## Zamke
- **Badge broja nepročitanih ne smije biti fiksne boje u klijentu** — v. [README](README.md), odluka 2.
- Statični ekrani izgledaju kao najlakši dio epika i jedini su koji nose pravni tekst; promjena
  rasporeda koja izgubi sekciju je pravni, ne vizuelni problem.

## Status

🟡 **Odjava sada traži potvrdu. Badge pročitanog nema odakle doći.** Grana
`feat/fe-306-obavijesti-i-postavke`.

**Urađeno u ovom tasku:** „Odjavi se" otvara `AppDialog` („Odjaviti se?"). Tijelo kaže da termini
ostaju sačuvani, a to je razlika prema brisanju ispod. `destructive: false`, jer je crvena
rezervisana za brisanje. Odustajanje (`null` ili `false`) ne zove `signOut`.

Zatečeno isporučeno (provjereno čitanjem koda i postojećim testovima):
- **Sekcije:** `prototype/ui/screenshots/11-postavke.png` crta karticu profila, **jednu** grupu
  redova bez naslova, pa „Odjavi se" i „Izbriši račun". Ekran je već takav (`LinkRowGroup`).
  Naslove sekcija handoff ne crta, pa se ne dodaju.
- **Brisanje** ostaje zaseban tok (`delete_account_action.dart`), sa svojim `AppDialog`-om i
  kickerom „Nepovratno".
- **Pravila:** redni broj je `padLeft(2, '0')` nad pozicijom u spojenoj listi
  (`policy_document_screen.dart:183`), pokriveno u `legal_screens_test.dart`.
- **Verzija:** `PackageInfo.fromPlatform()` (`about_app_screen.dart:27`) čita
  `--build-name`/`--build-number`, koje `build_tenant.sh` puni iz `tenant.yaml`. Konstante nema.

**Otvoreno: lista obavijesti i badge.** `NotificationsScreen` je namjerno samo prazno stanje. Nad
`notification_logs` postoji samo politika `staff_notification_logs`, pa klijent ne vidi nijedan
red, a kolone „pročitano" nema. Za badge treba šema (`read_at` ili posebna tabela), klijentska
RLS politika i pgTAP. To nije redizajn, a ovaj epik ne dira RLS (README, „Šta ovaj epik ne
dira"). Ide kao task u sprintu, poslije 25/39.

**Dokaz (2026-09-23):**
- `apps/client`: `flutter test` → **254 pass, 1 skip**; `flutter analyze` → No issues found.
- Novi test `odjava traži potvrdu — „Ostani prijavljen" ne odjavljuje` provjerava
  `brojOdjava == 0` nakon odustajanja i `== 1` nakon potvrde. Kad se modal preskoči, pada tačno
  taj test (`+11 -1`).

Na uređaju nije viđeno.
