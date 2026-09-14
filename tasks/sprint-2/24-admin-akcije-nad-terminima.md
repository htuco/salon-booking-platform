# Task 24 — Admin: potvrda, odbijanje, otkazivanje i ručni termin

| | |
|---|---|
| **Procjena** | 2 dana |
| **Zavisi od** | [23](23-admin-login-i-lista.md) |
| **Blokira** | 25 (push se okida na ove akcije) |
| **Reference** | [01 §8](../../docs/01-mvp-spec.md) · [`.claude/docs/security.md`](../../.claude/docs/security.md) |

## Cilj
Salon odgovara na zahtjev. Bez ovoga termin ostaje `pending` dok ne istekne, i cijeli klijentski
flow visi u zraku.

## Definicija gotovog
- [ ] Akcije: **potvrdi / odbij / otkaži / no-show**, svaka kroz RPC sa provjerom vlasništva
- [ ] Ručno dodavanje termina, sa pretragom po `Customer` i unosom telefonskog klijenta
      (`auth_identity_id` ostaje `null`)
- [ ] **Ručni upis prolazi istu validaciju slota** kao klijentski — danas je to poznata rupa
      (`security.md`, "Šta još nije zatvoreno"): exclusion constraint hvata preklapanje, ali radno
      vrijeme, blokade i `min_advance_booking_hours` ne
- [ ] `cancel_reason` i `cancelled_by` se popunjavaju na svakoj akciji
- [ ] pgTAP: sve četiri akcije, plus odbijanje ručnog termina van radnog vremena

## Koraci
1. RPC funkcije + pgTAP prije ekrana
2. Ekran akcija, pa ručni unos
3. Commit: `feat(admin): akcije nad terminima i rucni unos`

## Zamke
- **Ovo zatvara rupu iz `security.md`.** Ako ručni unos ostane direktan `insert`, admin može
  napraviti termin koji availability engine nikad ne bi dozvolio.
- No-show je statistika za kasnije (`vertical.features.noShowTracking`) — polje se puni sada, ekran
  dolazi u Sprintu 3.

## Status (2026-09-14)

🟡 **U toku** — grana `feat/admin-akcije-nad-terminima`, otvorena sa `main`-a na `fcd44e4`.

Krenulo od koraka 1: RPC funkcije i pgTAP prije ekrana, kako task nalaže.
