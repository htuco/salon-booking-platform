# Handoff — Salon admin: Moj profil

Feature: the user menu (bottom of the sidebar) and a personal profile page with a profile photo that can be shared with every salon where the user is the owner or employed.

Reference design: `Salon OS Admin.dc.html`, **section 4** (ids `4a`–`4e`). Open it in a browser. Screenshots are in `screenshots/`. Sections 3/2/… are the existing admin screens and are context only.

## Why a separate page (not in settings)
The photo, name, phone and password belong to the **person**, not the salon. Postavke lokacije (3i) stays salon-scoped. The profile is account-scoped and applies to every salon.

## Screens
| id | Screen | File |
|---|---|---|
| 4a | Desktop: clicking the user block opens a menu | screenshots/4a-meni-korisnika.png |
| 4b | Desktop: Moj profil page | screenshots/4b-moj-profil.png |
| 4c | Phone: Još tab, profile row at the top | screenshots/4c-telefon-jos.png |
| 4d | Phone: Moj profil (pushed from Još) | screenshots/4d-telefon-moj-profil.png |
| 4e | Phone: photo action sheet | screenshots/4e-telefon-promjena-slike.png |

## Behaviour
**User menu (4a)**
- Trigger: the whole user block at the sidebar bottom. It shows ▴ while open and gets the `#2c2e33` background.
- Popover: anchored above the trigger, width 272, white, radius 4, shadow `0 12px 32px rgba(20,21,23,.28)`.
- Header: avatar 44, name, email (ellipsis).
- Items:
  - **Moj profil** → `/profile`
  - **Promijeni sliku** → opens the file picker directly. On success the photo is saved and applied according to the salon toggles.
  - **Odjavi se** (red `#c94c4c`), in its own group.
- Closes on outside click, on Esc, and on route change.
- While the user is on `/profile`, the user block gets the active-nav style (`#373a40` plus a 2px inset coral bar).

**Moj profil (4b / 4d)**
- Photo:
  - Desktop: "Promijeni sliku" plus a red "Ukloni".
  - Phone: a tap opens the sheet (4e) with Uslikaj / Izaberi iz galerije / Ukloni sliku / Odustani.
  - Accepts JPG/PNG, min 400×400, square crop, shown as a circle.
  - With no photo, show initials.
- Lični podaci:
  - First name, last name and phone are editable (on phone, first and last name are one field).
  - Email is read-only. "Promijeni" starts an email-change flow with verification (out of scope here).
- **Slika u salonima**: one row per membership (salon thumb, name, role: Vlasnik / Zaposlen · frizer).
  - Toggle ON: that salon uses the profile photo, so clients see it when choosing a barber.
  - Toggle OFF: the salon keeps its own photo of this staff member. Show it as a 30px avatar with "Slika koju je dodao salon" and a "Zamijeni mojom" link, which turns the toggle ON.
  - **Koristi svuda** is the master toggle. It is ON only when all rows are ON. Switching it on or off sets every row.
  - Changing the profile photo updates every salon whose row is ON.
- Sigurnost:
  - Lozinka shows when it was last changed, with a "Promijeni lozinku" button.
  - "Odjavi sve uređaje" (red) revokes the other sessions and shows a confirmation first.
- Save:
  - Desktop: Odustani / Sačuvaj in the top bar.
  - Phone: Sačuvaj in the nav bar.
  - Disable Sačuvaj until something changes.
  - Toggles and the photo save immediately; text fields save on Sačuvaj.

**Phone entry (4c)**: the first card in Još is the person (avatar 56, name, "Moj profil · email"). The salon card moves under a "Salon" label.

## Data
```
User { id, firstName, lastName, phone, email, photoUrl | null, passwordChangedAt }
Membership { userId, salonId, role: 'owner'|'staff', useProfilePhoto: boolean, salonPhotoUrl | null }
displayPhoto(membership) = membership.useProfilePhoto ? user.photoUrl : membership.salonPhotoUrl
```
The client booking app (barber picker) must read `displayPhoto`, never `user.photoUrl` directly.

## Tokens (same as the existing admin)
- Font: Barlow 400/500/600.
- Ground `#fcfcf9`, card `#fff`, radius 4, card shadow `0 1px 2px rgba(44,44,44,.06)`.
- Text `#2c2c2c` / muted `#666666`. Borders `#e2e2e2` / inputs `#dee2e6`.
- Sidebar `#141517`, active `#373a40`, salon chip `#2c2e33`.
- Accent / primary `#ee6c4d` (text on it `#2c2c2c`). Links `#3d5a80`. Danger `#c94c4c`.
- Toggle on `#ee6c4d`, off `#c1c2c5`. Size 40×22 on desktop, 44×26 on phone.
- Phone hit targets ≥ 44px; list rows ≥ 58px.

Sample data (Emir Bešić, salons, email) is placeholder.
