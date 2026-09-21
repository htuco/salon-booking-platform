# Task 40 — Naziv lokala se ne mijenja iz admina

| | |
|---|---|
| **Procjena** | 0,5 dan |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | [ADR-0003](../../docs/adr/0003-x-salon-id-bira-kontekst-ne-daje-prava.md) · `tenants/<flavor>/tenant.yaml` |

## Cilj
Vlasnik može promijeniti naziv salona iz postavki, a taj naziv se kosi sa imenom brandirane
aplikacije u prodavnici. Dvije istine o istoj stvari, i ona u storeu se ne mijenja bez submissiona.

## Definicija gotovog
- [ ] Naziv salona je u postavkama **samo za čitanje**, uz rečenicu zašto
- [ ] RPC odbija promjenu naziva — ugovor se brani u bazi, ne samo na ekranu
- [ ] pgTAP: pokušaj izmjene naziva vraća grešku
- [ ] Zapisano gdje naziv **jeste** promjenjiv: `tenant.yaml` → generator → store build

## Otvoreno pitanje
Treba li salonu zaseban **prikazni naziv** koji se smije mijenjati (npr. „Barber Studio Vitez —
Stari Grad") dok ime aplikacije ostaje fiksno? Ako da, to je nova kolona i nova odluka, ne dio ovog
taska.

## Zamke
- Naziv se pojavljuje na više mjesta (breadcrumb, klijentska Početna, pravila korištenja). Kad se
  zaključa, nijedan ekran ne smije nuditi polje koje ne radi.

## Status

Nije počet.
