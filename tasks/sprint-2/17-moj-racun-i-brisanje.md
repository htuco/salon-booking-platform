# Task 17 — Client: "Moj račun", postavke i **brisanje računa**

| | |
|---|---|
| **Procjena** | ~~1–2 dana~~ → **2–3 dana** (v. „Doseg", 5k je ušao) |
| **Zavisi od** | [13](13-client-login-ekran.md) |
| **Blokira** | **store submission** |
| **Reference** | `prototype/ui/SPEC.md` 5k · [06 §8](../../docs/06-auth-login-flow.md) · [01 §17](../../docs/01-mvp-spec.md#17-build-order) korak 16 |

## Cilj
Ekran računa sa odjavom i **brisanjem naloga**. Bez brisanja iOS submission pada — to nije feature
nego uslov izlaska u store.

## Definicija gotovog
- [ ] `/settings` po handoffu 5k: profil, obavijesti, jezik, o aplikaciji, odjava, i red
      „Moj račun ›" — **ovo je jedini ulaz do `/account`**
- [ ] `/account`: podaci identiteta i brisanje naloga
- [ ] **Brisanje računa** briše `auth_identity` i anonimizira `customers` red, ne briše termine
      koje salon treba za evidenciju
- [ ] Brisanje traži potvrdu i **objašnjava šta ostaje**, ne samo "jeste li sigurni"
- [ ] Nakon brisanja app se vraća u javno stanje, bez zaostalog tokena
- [ ] Deno test: obrisan identitet više ne može čitati svoje termine

## Doseg — odluka od 2026-09-13

**`/settings` (5k) je ušao u ovaj task.** Kako je task prvobitno napisan, 5k je bio siroče: ovdje
je stajao kao referenca za `/account`, ali 5k i `/account` su dva ekrana — router iz
[taska 18](18-pocetna-i-tab-bar.md) ih razdvaja. Komentar u `app_router.dart` ga je pripisao
[tasku 21](21-obavijesti-i-pravni-ekrani.md), čiji DoD nabraja samo `/notifications`, `/about-app`
i `/terms`.

Bez 5k `/account` se ne može otvoriti iz aplikacije. Ekran za brisanje naloga do kojeg se ne može
doći pada na Apple reviewu — a to je jedini razlog zašto ovaj task postoji. 5k uz to već nosi
„odjavu" koju DoD ionako traži.

## Koraci
1. RPC za brisanje (soft-delete klijenta + hard-delete identiteta)
2. Edge Function koja zove RPC pa `auth.admin.deleteUser` — tim redom, obrnuto ostavlja siroče
3. `/settings` (5k), pa `/account` ispod njega
4. Commit: `feat(client): postavke, moj racun i brisanje naloga`

## Zamke
- **Brisanje naloga ≠ brisanje podataka salona.** Termin je i salonov zapis; anonimizuje se ime i
  kontakt, ne briše se red.
- Apple traži da brisanje bude **u aplikaciji**, ne link na mail podrške.
