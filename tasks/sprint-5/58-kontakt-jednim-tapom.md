# Task 58 — Kontakt klijenta jednim tapom

| | |
|---|---|
| **Procjena** | 0,5–1 dan |
| **Zavisi od** | — |
| **Blokira** | — |
| **Reference** | `docs/01` §6.3 („Kontakt klijenta jednim tapom") · `prototype/admin/SPEC.md` (`3n`, `3e`) |

## Cilj
Iz detalja termina i profila klijenta vlasnik jednim tapom pozove klijenta ili mu piše na Viber/WhatsApp.

## Definicija gotovog
- [ ] `url_launcher` kao zavisnost admina
- [ ] `tel:`, `viber://chat?number=` i `https://wa.me/` iz detalja termina i profila klijenta
- [ ] Prikazuje se samo klijentu koji ima upisan telefon; klijenti iz aplikacije se dobijaju pushom
- [ ] Na webu gdje šema nije podržana — nema dugmeta, ne mrtvo dugme
- [ ] Widget test: bez telefona nema akcije; uživo na Android uređaju sve tri akcije

## Zamke
- Broj se normalizuje u međunarodni oblik (`+387…`) prije `wa.me`; lokalni `06x` ne radi.
- Task 54 ne smije ukloniti „Pozovi" ako ovaj task ide u sprint.

## Status
Nije počet.
