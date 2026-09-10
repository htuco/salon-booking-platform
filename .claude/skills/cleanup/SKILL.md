---
name: cleanup
description: Higijena repoa — drift generisanog, mrtvi TODO, dokumenti van sinhronizacije (dodaj "run" da popraviš).
argument-hint: check|run
---

# Cleanup

Režim: **$ARGUMENTS** (prazno ili `check` → samo prijavi; `run`/`fix` → prijavi pa popravi
odabrano).

Provjeri, tim redom — prve tri su specifične za ovaj repo i najčešće nešto nađu:

1. **Drift generisanog.** `dart run tool/gen_flavors.dart --check`. Ako padne, neko je ručno
   editovao izlaz ili zaboravio pokrenuti generator nakon izmjene `tenant.yaml`.
2. **`tenant.yaml` naspram `seed.sql`.** Za svaki `tenants/*/tenant.yaml`: postoji li taj `salonId`
   u `supabase/seed.sql`, i poklapaju li se `branding` boje sa `primary_color`/`secondary_color`.
3. **CI matrica naspram `tenants/`.** Svaki tenant sa `targets.android: true` mora biti u
   `build-flavors` matrici; svaki sa `ios: true` u `build-ios`. Tenant koji nije u matrici se ne
   buildа na CI-ju, a ništa ne pada.
4. **`workspace:` lista.** Svaki folder u `apps/` i `packages/` sa `pubspec.yaml` mora biti u root
   `pubspec.yaml`. Paket van liste ispada iz `melos exec` i CI-ja tiho.
5. **Statusi taskova.** Poklapa li se oznaka u tabeli `tasks/README.md` sa `## Status` blokom u
   samom task fajlu, i odgovaraju li oba stvarnom stanju repoa.
6. **Dokumenti van sinhronizacije.** Prođi tabelu iz `CLAUDE.md`: opisuje li neki `.claude/docs/`
   fajl ponašanje kojeg više nema (nepostojeća komanda, uklonjena funkcija, promijenjena putanja).
7. **`@` importi u dokumentima.** `.claude/docs/` i `CLAUDE.md` referenciraju putanje u
   backtickovima; `@path` uvlači fajl u svaki context window i poništava čitanje-po-potrebi.
8. **Mrtvi TODO i `// ignore:`** bez obrazloženja u `apps/`, `packages/`, `tool/`.
9. **`print` u produkcijskom kodu** (`avoid_print` je uključen) — alat u `tool/` je izuzetak i mora
   nositi obrazloženje.
10. **Zaostali `.gitkeep`** u folderima koji su u međuvremenu dobili prave fajlove.
11. **Tajne i artefakti u gitu**: `.env`, izlaz `supabase status`, pravi `google-services.json`,
    `build/` folderi, `.DS_Store`.
12. **Mrtve zavisnosti** u `package.json` — poznati slučaj su `@mui/*` i `@emotion/*` bez ijednog
    importa u `src/` (`docs/07 §2`).

## `check`

Samo prijavi, numerisano, sa putanjom i jednom rečenicom zašto je to problem. Ništa ne mijenjaj.

## `run`

1. Prijavi sve nalaze, numerisano.
2. Pitaj: "Šta da popravim? (brojevi, `sve` ili `ništa`)"
3. Sačekaj odgovor. Popravi **samo** traženo.
4. Reci šta si promijenio. Za nalaze koji traže odluku (mrtva zavisnost, zastarjeli dokument)
   predloži, ne odlučuj sam.
