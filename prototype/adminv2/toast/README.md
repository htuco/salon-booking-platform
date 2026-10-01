# Handoff — Melura admin: Toast obavijesti

Reference design: `Salon OS Admin.dc.html` in the project, **section 5** (5a desktop, 5c phone, 5b variants + rules). Use the ▶ Pusti buttons to replay the motion.

## Files
- `toast.css` — tokens, layout, animations (import once globally)
- `toast.ts` — framework-agnostic API (`toast.ok/info/warn/err`). Wrap it in your framework's store/context if you prefer; keep the DOM/CSS as-is.
- `screenshots/5b-varijante.png` — all variants (motion: see section 5 live)

## Rules
| | |
|---|---|
| Position | Desktop: top-right, 16px below the 66px top bar, 24px from edge, width 360. Phone (≤640px): top, below safe-area, 12px side margins |
| Motion | In 320ms `cubic-bezier(.2,.9,.3,1.15)` (slight overshoot): desktop from right, phone from top. Out 220ms ease-in, same path. Respect `prefers-reduced-motion` |
| Duration | ok/info 5s with a 2px coral countdown line; hover/focus pauses. warn/err stay until closed |
| Stacking | Desktop max 3, newest on top, oldest evicted. Phone: one at a time, new replaces old |
| Dismiss | × button, action button, or (phone) swipe up |
| Action | Max one, short, uppercase coral (Poništi, Otvori, Pokušaj ponovo) |
| Copy | Title = what happened. Description optional, one line of context |
| A11y | `role=status` for ok/info, `role=alert` for warn/err; close has `aria-label="Zatvori"`; focus ring 2px coral |

## Colors
Background `#141517` (sidebar), title `#fff`, description `#c1c2c5`, close `#909296`, action + countdown `#ee6c4d`.
Icon circle: ok `#5cc08a`, info `#8fb0d6`, warn `#e3b45a`, err `#e8746f` (glyph `#141517`). Radius 4, shadow `0 12px 32px rgba(20,21,23,.28), 0 2px 6px rgba(20,21,23,.16)`. Font Barlow.

## Examples
```ts
toast.ok('Termin potvrđen', { desc: 'Haris Delić · danas 14:20', action: { label: 'Poništi', onClick: undoConfirm } });
toast.info('Novi zahtjev', { desc: 'Kenan Zukić · sutra 10:00', action: { label: 'Otvori', onClick: () => goto('/appointments?status=pending') } });
toast.warn('Termin se preklapa', { desc: '14:20 – 14:50 već je zauzeto kod Emira.', action: { label: 'Prikaži', onClick: showConflict } });
toast.err('Slanje nije uspjelo', { desc: 'Provjerite internet vezu.', action: { label: 'Pokušaj ponovo', onClick: retry } });
toast.ok('Promjene sačuvane');
```
Use toasts for results of the user's own actions and live events (new request). Don't use them for form validation — keep that inline.
