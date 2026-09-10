# Domenska dokumentacija — kako je agenti koriste

Kako skillovi i subagenti treba da čitaju domenske dokumente ovog repoa prije nego što krenu u kod.

## Pročitaj prije istraživanja

- **`CONTEXT.md`** u rootu — rječnik. Kanonski termin za svaki pojam, i riječi koje se izbjegavaju.
- **`docs/adr/`** — ADR-ovi koji dodiruju područje u koje ulaziš. Odluka i šta je odbačeno.
- **`docs/README.md`** — tabela "Odluke koje su već donesene". Ne otvaraju se bez novog podatka.
- **`docs/01`–`docs/07`** — proizvodna specifikacija. `01` (šta se gradi), `05` (vertikale),
  `06` (auth), `07` (izbor paketa) najčešće trebaju.

Ako neki od tih fajlova ne postoji, radi dalje bez komentara — ne prijavljuj odsustvo i ne predlaži
da se kreiraju unaprijed. Nastaju kad se pojam ili odluka stvarno razriješe.

## Koristi rječnik

Kad tvoj izlaz imenuje domenski pojam — u naslovu taska, prijedlogu, hipotezi, imenu testa —
koristi termin kako ga definiše `CONTEXT.md`. Ne skreći na sinonime koje rječnik izričito
izbjegava: "slot" nije "termin", "flavor" nije "varijanta", `x-salon-id` nije ovlaštenje.

Ako pojam koji ti treba nije u rječniku, to je signal: ili izmišljaš jezik koji projekat ne koristi
(preispitaj), ili postoji stvarna rupa (zabilježi je, ne popunjavaj usput).

## Prijavi sukob sa ADR-om

Ako tvoj prijedlog protivrječi prihvaćenom ADR-u, reci to eksplicitno umjesto da ga tiho pregaziš:

> _Protivrječi ADR-0002 (generisani fajlovi se commituju) — ali vrijedi otvoriti jer…_

Isto važi za tabelu odluka u `docs/README.md`. Novi podatak je razlog da se odluka otvori; ukus
nije.

## Granica između dokumenata

| Pitanje | Gdje |
|---|---|
| Kako se ovo zove? | `CONTEXT.md` |
| Zašto je odlučeno ovako? | `docs/adr/`, pa `docs/README.md` |
| Šta se gradi? | `docs/01`–`docs/07` |
| Kako je repo složen danas? | `.claude/docs/architecture.md` |
| Kako se ovdje piše kod? | `.claude/docs/conventions.md` |
| Kojom komandom? | `.claude/docs/workflows.md` |
| Šta se radi sada? | `tasks/CURRENT.md`, pa `tasks/` |
