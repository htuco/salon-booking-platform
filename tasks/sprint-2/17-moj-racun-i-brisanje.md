# Task 17 — Client: "Moj račun", postavke i **brisanje računa**

| | |
|---|---|
| **Procjena** | 1–2 dana |
| **Zavisi od** | [13](13-client-login-ekran.md) |
| **Blokira** | **store submission** |
| **Reference** | `prototype/ui/SPEC.md` 5k · [06 §8](../../docs/06-auth-login-flow.md) · [01 §17](../../docs/01-mvp-spec.md#17-build-order) korak 16 |

## Cilj
Ekran računa sa odjavom i **brisanjem naloga**. Bez brisanja iOS submission pada — to nije feature
nego uslov izlaska u store.

## Definicija gotovog
- [ ] `/account` po handoffu 5k: profil, obavijesti, jezik, o aplikaciji, odjava
- [ ] **Brisanje računa** briše `auth_identity` i anonimizira `customers` red, ne briše termine
      koje salon treba za evidenciju
- [ ] Brisanje traži potvrdu i **objašnjava šta ostaje**, ne samo "jeste li sigurni"
- [ ] Nakon brisanja app se vraća u javno stanje, bez zaostalog tokena
- [ ] Deno test: obrisan identitet više ne može čitati svoje termine

## Koraci
1. RPC za brisanje (soft-delete klijenta + hard-delete identiteta), pa ekran
2. Commit: `feat(client): moj racun i brisanje naloga`

## Zamke
- **Brisanje naloga ≠ brisanje podataka salona.** Termin je i salonov zapis; anonimizuje se ime i
  kontakt, ne briše se red.
- Apple traži da brisanje bude **u aplikaciji**, ne link na mail podrške.
