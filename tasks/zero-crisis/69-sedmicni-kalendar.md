# Task 69 — Sedmični kalendar u Meluri

| | |
|---|---|
| **Procjena** | 2–3 dana |
| **Zavisi od** | — |
| **Blokira** | [87](87-sigurnosni-pregled.md) |
| **Reference** | ADR-0029 · FE-403 (imenovan dug: prekidač dan/sedmica) · `prototype/adminv2/` |

## Cilj
Salon vidi cijelu sedmicu odjednom za planiranje. Primarno tablet i računar; na telefonu dnevni
prikaz ostaje default.

## Definicija gotovog
- [x] Dizajn prije koda (handoff ili skica u `prototype/adminv2/`)
- [x] Prekidač dan/sedmica; sedmica = 7 kolona sa terminima, blokadama i neradnim danima
- [x] Tap na termin otvara isti detalj kao u dnevnom prikazu; tap na prazno nudi ručno zakazivanje
- [x] Radnik vidi samo svoje termine i u sedmici
- [x] Widget testovi za obje uloge; viđeno na 1440 i 402

## Status
Spremno za merge (PR #137, 2026-10-19). Drugi pregled zatvoren u istoj grani: prošli dan ne nudi
termin, vrijeme u bloku se mjeri i nikad ne reže, natpisi pojaseva se lome, dugmad sedmice i dana
čitač ekrana može pritisnuti, prekidač ima metu 44 px, prijedlog vremena čuva brojač upita, demo
radi preko granice mjeseca. Testovi mjere u Barlowu i sa sidebarom; dvanaest mutacija obara po
barem jedan test; admin 677. Viđeno uživo na demo buildu na 1440, 1024 i 402.

Prvi pregled (2026-10-16): Ekran je `calendar_week_view.dart` (`part` ekrana kalendara).
Dokaz: `calendar_week_screen_test` (23, uz pristupačnost na obje širine), pet mutacija obara po jedan
test; admin 651, `analyze` i `format` čisti. Viđeno uživo na demo buildu (`demo_main.dart`) na 1440,
1024 i 402. Tap na prazno šalje `?date=&time=` u formu ručnog termina, a forma vrijeme izabere samo
ako ga baza vrati među slobodnima.
