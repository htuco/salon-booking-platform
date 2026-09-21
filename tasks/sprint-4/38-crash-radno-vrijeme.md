# Task 38 — Crash pri izmjeni radnog vremena

| | |
|---|---|
| **Procjena** | 1 dan |
| **Zavisi od** | — |
| **Blokira** | 42 |
| **Reference** | `apps/admin/lib/src/features/working_hours/` · task [34](../sprint-3/34-radno-vrijeme-i-blokade.md) |

## Cilj
Izmjena radnog vremena iz admina ruši aplikaciju, uz poruku u konzoli. Prijavljeno sa uređaja.

## Prvo reprodukcija, pa popravka
**Uzrok nije poznat.** Čitanje `working_hours_providers.dart` i `working_hours_dialogs.dart` ne
pokazuje ni `!`, ni `firstWhere` bez `orElse`, ni `.single` — dakle nije očigledan null ni prazan
izbor. Bez doslovne poruke iz konzole svaka popravka je pogađanje.

Reprodukcija ide **protiv hostovanog projekta**, ne protiv demo ulaza: demo ne dira mrežu, pa
greška koja dolazi iz RPC-a ili iz mapiranja odgovora tamo ne postoji.

## Definicija gotovog
- [ ] U ovom fajlu zapisan tačan korak reprodukcije i **doslovna** poruka iz konzole
- [ ] Uzrok imenovan; ako je `ApiError`, ekran ga pokazuje umjesto da se ruši
- [ ] Widget test koji **pada** na zatečenom kodu i prolazi poslije popravke
- [ ] Ako je uzrok u RPC ugovoru — pgTAP ili REST test, ne samo Dart

## Koraci
1. `tool/run_live_demo.sh admin -d chrome`, prijava seed nalogom, izmjena radnog vremena
2. Uhvatiti izlaz konzole i stack
3. Tek onda popravka

## Zamke
- **Ekran hvata `ApiError`, nikad `PostgrestException`.** `ApiError` je `sealed`, pa `switch` mora
  pokriti sve grane — pravilo iz `apps/client/CLAUDE.md` vrijedi i za admin.
- Ako se crash desi tek **poslije** uspješnog upisa, greška je u osvježavanju providera, ne u upisu.

## Status

Nije počet.
