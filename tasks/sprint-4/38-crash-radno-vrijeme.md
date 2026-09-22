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
- [x] U ovom fajlu zapisan tačan korak reprodukcije i **doslovna** poruka iz konzole
- [x] Uzrok imenovan; ako je `ApiError`, ekran ga pokazuje umjesto da se ruši
      (**nije** `ApiError` — v. status blok)
- [x] Widget test koji **pada** na zatečenom kodu i prolazi poslije popravke
- [x] Ako je uzrok u RPC ugovoru — pgTAP ili REST test, ne samo Dart
      (**nije u RPC ugovoru**; baza i mreža su nedužne, pa novi SQL test ne bi ništa dokazao)

## Koraci
1. `tool/run_live_demo.sh admin -d chrome`, prijava seed nalogom, izmjena radnog vremena
2. Uhvatiti izlaz konzole i stack
3. Tek onda popravka

## Zamke
- **Ekran hvata `ApiError`, nikad `PostgrestException`.** `ApiError` je `sealed`, pa `switch` mora
  pokriti sve grane — pravilo iz `apps/client/CLAUDE.md` vrijedi i za admin.
- Ako se crash desi tek **poslije** uspješnog upisa, greška je u osvježavanju providera, ne u upisu.

## Status (2026-09-22)

Uzrok nađen i popravljen na grani `fix/crash-radno-vrijeme`; spremno za draft PR.

### Reprodukcija

1. `tool/run_live_demo.sh admin -d chrome` protiv hostovanog projekta
2. Prijava sa `admin@barberstudiovitez.test`
3. `/working-hours` → izmijeniti bilo koji dan → **`Sačuvaj izmjene`**

**Uslov bez kojeg se ne vidi:** salon mora imati bar jedan zakazan termin koji ispada van
novog radnog vremena. Dijalog konflikata se otvara **samo** kad lista nije prazna, pa salon
bez termina prolazi snimanje uredno. Zato demo ulaz ovo nikad nije pogodio — a `tasks/38`
je tražio hostovani projekat iz pogrešnog razloga: nije stvar u mreži, nego u tome što na
hostovanom projektu **postoje termini**.

### Doslovna poruka iz konzole

```
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════
The following assertion was thrown during performLayout():
RenderShrinkWrappingViewport does not support returning intrinsic dimensions.
Calculating the intrinsic dimensions would require instantiating every child of
the viewport, which defeats the point of viewports being lazy.
If you are merely trying to shrink-wrap the viewport in the main axis direction,
you should be able to achieve that effect by just giving the viewport loose
constraints, without needing to measure its intrinsic dimensions.

The relevant error-causing widget was:
  AlertDialog
  AlertDialog:.../working_hours/working_hours_dialogs.dart:30:12
```

Stack ide `viewport.dart:735 computeMaxIntrinsicWidth` → `box.dart getMaxIntrinsicWidth`
→ `rendering/binding.dart drawFrame`. Ispod toga slijedi kaskada
`Cannot hit test a render box with no size`: dijalog nije dobio veličinu, pa ekran prestaje
primati dodire — to je ono što se sa uređaja vidi kao „sve se sruši".

### Uzrok

**Nije `ApiError`, nije null, nije RPC.** `AlertDialog` mjeri sadržaj kroz `IntrinsicWidth`,
a `ListView.separated` unutar `content` je `RenderShrinkWrappingViewport`, koji intrinsične
dimenzije **ne podržava** i baca assertion. `shrinkWrap: true` tu ne pomaže — on je baš ono
što pravi shrink-wrapping viewport.

**Zato ga čitanje koda nije našlo, i zato ga nijedan `try/catch` nije uhvatio.** Task je
tražio `!`, `firstWhere` bez `orElse` i `.single` — ničega od toga nema, jer greška nije u
podacima. `_sacuvaj` je uredno pokriven (`on ApiError` **i** gola `catch (_)`), a
repozitorij ide kroz `guard()` koji garantuje da izađe samo `ApiError`. Assertion se baca
**poslije** `await`-a, u `performLayout()` — u fazi crtanja, gdje `catch` oko poziva ne stoji
i ne može stajati. Zamka iz task fajla („ako se crash desi poslije uspješnog upisa, greška je
u osvježavanju providera") pokazivala je u pravom smjeru ali na pogrešno mjesto: crash je
**prije** upisa, u dijalogu koji pita smije li se upisati.

### Popravka

`ListView.separated` → `SingleChildScrollView` + `Column` u
`working_hours_dialogs.dart`. `_RenderSingleChildViewport` intrinsične dimenzije podržava
(delegira ih djetetu), pa `AlertDialog` može mjeriti, a sadržaj i dalje skrola.
**Lijenost se ne gubi** — `shrinkWrap: true` ju je ionako već bio isključio, a lista je
ograničena brojem termina koji ispadaju iz jedne sedmice.

**Jedna popravka zatvara dva ulaza.** `prikaziKonflikte` zove i snimanje radnog vremena
(`working_hours_screen.dart`) i snimanje blokade (`_UredjivacBlokade._sacuvaj`) — drugi put
je isti crash čekao na „Dodaj neradni dan" preko postojećeg termina.

### Dokazi

- `flutter test test/working_hours_screen_test.dart` — **15 testova, svi prolaze** (dva nova).
  Prvi novi test prolazi kroz stvarni ekran: izmjena dana → `Sačuvaj izmjene` → konfliktni
  dijalog, pa ne dokazuje samo izdvojeni widget.
- **Sabotaža provjerena obrnutim redoslijedom**: test je pisan i pokrenut **prije** popravke i
  pao je sa `Multiple exceptions (15) were detected` — tačno kaskada iz konzole.
- `flutter test` nad cijelim admin paketom — **280 testova, PASS**.
- `dart analyze` nad izmijenjenim fajlom — bez primjedbi.

Drugi test (`duga lista konflikata se skrola`) postoji zato što bi popravka koja samo makne
viewport prošla prvi test, a vratila preliv na telefonu koji je task 34 već jednom platio:
40 konflikata na `402×874` mora skrolati, i test to dovlači skrolom.

### Ostalo

- **Post-fix klik protiv hostovanog projekta nije ponovljen.** Kvar jeste reprodukovan tim
  putem prije popravke, a trajni regresijski test sada prolazi kroz isti UI slijed na stvarnom
  ekranu. Backend nije dio uzroka ni popravke.
- `blocked_slot_conflicts` ne vraća `reason`, pa kod blokade red nosi samo ime i vrijeme —
  to je namjerno (v. `ScheduleConflict.reason`), ali test to ne pokriva.
