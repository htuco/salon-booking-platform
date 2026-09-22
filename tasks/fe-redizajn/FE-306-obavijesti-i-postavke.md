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
- [ ] Označavanje kao pročitano mijenja badge bez ponovnog učitavanja ekrana
- [ ] Postavke grupisane u sekcije sa naslovima po handoffu
- [ ] Odjava traži potvrdu (modal iz [FE-203](FE-203-modali-i-bottom-sheet.md))
- [ ] Brisanje naloga ostaje odvojeno od odjave i zadržava svoje upozorenje
- [ ] Pravila i dalje spajaju dvije tabele; numeracija se i dalje računa, ne upisuje
- [ ] Verzija u „O aplikaciji" i dalje dolazi iz build parametara

## Zamke
- **Badge broja nepročitanih ne smije biti fiksne boje u klijentu** — v. [README](README.md), odluka 2.
- Statični ekrani izgledaju kao najlakši dio epika i jedini su koji nose pravni tekst; promjena
  rasporeda koja izgubi sekciju je pravni, ne vizuelni problem.

## Status

Nije počet.
