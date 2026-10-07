// Melura toasts — framework-agnostic reference. Import toast.css once globally.
// Usage: toast.ok('Termin potvrđen', { desc: 'Haris Delić · danas 14:20', action: { label: 'Poništi', onClick: undo } })

export type ToastKind = 'ok' | 'info' | 'warn' | 'err';
export interface ToastOptions {
  desc?: string;
  action?: { label: string; onClick: () => void };
  /** ms; 0 = sticky. Default: 5000 for ok/info, sticky for warn/err */
  duration?: number;
}

const GLYPH: Record<ToastKind, string> = { ok: '✓', info: 'i', warn: '!', err: '×' };
const MAX_DESKTOP = 3;
const isPhone = () => matchMedia('(max-width:640px)').matches;

let region: HTMLElement | null = null;
function getRegion() {
  if (region) return region;
  region = document.createElement('div');
  region.className = 'toast-region';
  region.setAttribute('role', 'region');
  region.setAttribute('aria-label', 'Obavijesti');
  document.body.appendChild(region);
  return region;
}

function dismiss(el: HTMLElement) {
  if (el.dataset.leaving != null) return;
  el.dataset.leaving = '';
  el.addEventListener('animationend', () => el.remove(), { once: true });
}

export function show(kind: ToastKind, title: string, opts: ToastOptions = {}) {
  const r = getRegion();
  const duration = opts.duration ?? (kind === 'ok' || kind === 'info' ? 5000 : 0);

  // phone: one at a time; desktop: max 3, newest on top
  const live = [...r.querySelectorAll<HTMLElement>('.toast:not([data-leaving])')];
  if (isPhone()) live.forEach(dismiss);
  else if (live.length >= MAX_DESKTOP) dismiss(live[live.length - 1]);

  const el = document.createElement('div');
  el.className = `toast toast--${kind}`;
  el.setAttribute('role', kind === 'err' || kind === 'warn' ? 'alert' : 'status');
  el.innerHTML = `
    <div class="toast__icon" aria-hidden="true">${GLYPH[kind]}</div>
    <div class="toast__body">
      <div class="toast__title"></div>
      ${opts.desc ? '<div class="toast__desc"></div>' : ''}
      ${opts.action ? '<button class="toast__action" type="button"></button>' : ''}
    </div>
    <button class="toast__close" type="button" aria-label="Zatvori">×</button>
    ${duration ? '<div class="toast__bar"></div>' : ''}`;
  el.querySelector('.toast__title')!.textContent = title;
  if (opts.desc) el.querySelector('.toast__desc')!.textContent = opts.desc;
  if (opts.action) {
    const b = el.querySelector<HTMLButtonElement>('.toast__action')!;
    b.textContent = opts.action.label;
    b.onclick = () => { opts.action!.onClick(); dismiss(el); };
  }
  el.querySelector<HTMLButtonElement>('.toast__close')!.onclick = () => dismiss(el);

  // auto-dismiss driven by the progress bar, so hover/focus pause it for free
  if (duration) {
    el.style.setProperty('--toast-dur', `${duration}ms`);
    el.querySelector('.toast__bar')!.addEventListener('animationend', () => dismiss(el));
  }

  // phone: swipe up to dismiss
  let y0: number | null = null;
  el.addEventListener('pointerdown', e => { if (isPhone()) y0 = e.clientY; });
  el.addEventListener('pointermove', e => {
    if (y0 == null) return;
    const dy = Math.min(0, e.clientY - y0);
    el.style.transform = `translateY(${dy}px)`;
    if (dy < -40) { y0 = null; el.style.transform = ''; dismiss(el); }
  });
  const reset = () => { y0 = null; if (el.dataset.leaving == null) el.style.transform = ''; };
  el.addEventListener('pointerup', reset);
  el.addEventListener('pointercancel', reset);

  r.prepend(el);
  return { dismiss: () => dismiss(el) };
}

export const toast = {
  ok: (t: string, o?: ToastOptions) => show('ok', t, o),
  info: (t: string, o?: ToastOptions) => show('info', t, o),
  warn: (t: string, o?: ToastOptions) => show('warn', t, o),
  err: (t: string, o?: ToastOptions) => show('err', t, o),
};
