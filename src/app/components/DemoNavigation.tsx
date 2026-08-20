import { useNavigate, useLocation } from 'react-router';
import { Card } from './Card';
import { ChevronDown, ChevronUp, Smartphone, Monitor, Settings2 } from 'lucide-react';
import { useState } from 'react';
import { clsx } from 'clsx';

const groups = [
  {
    category: 'Client app — brandiran po salonu',
    icon: Smartphone,
    items: [
      { path: '/s/barber-studio-vitez', label: 'Home — Modern Barber' },
      { path: '/s/beauty-studio-travnik', label: 'Home — Elegant Beauty' },
      { path: '/s/barber-studio-vitez/book/service', label: 'Booking 1 — Usluga' },
      { path: '/s/barber-studio-vitez/book/employee', label: 'Booking 2 — Radnik' },
      { path: '/s/barber-studio-vitez/book/datetime', label: 'Booking 3 — Termin' },
      { path: '/s/barber-studio-vitez/auth/login', label: 'Login gate' },
      { path: '/s/barber-studio-vitez/auth/login?screen=email', label: 'Login — Email' },
      { path: '/s/barber-studio-vitez/auth/login?screen=otp', label: 'Login — OTP kod' },
      { path: '/s/barber-studio-vitez/book/details', label: 'Booking 4 — Podaci' },
      { path: '/s/barber-studio-vitez/book/success', label: 'Booking — Potvrda' },
      { path: '/s/barber-studio-vitez/appointments', label: 'Moji termini' },
      { path: '/s/barber-studio-vitez/account', label: 'Moj račun' },
    ],
  },
  {
    category: 'Admin app — jedna za sve salone',
    icon: Monitor,
    items: [
      { path: '/admin/login', label: 'Login' },
      { path: '/admin/dashboard', label: 'Dashboard' },
      { path: '/admin/appointments', label: 'Termini' },
      { path: '/admin/calendar', label: 'Kalendar' },
      { path: '/admin/services', label: 'Usluge' },
      { path: '/admin/employees', label: 'Radnici' },
    ],
  },
  {
    category: 'Super admin — Flutter Web',
    icon: Settings2,
    items: [{ path: '/super-admin/salons/new', label: 'Novi salon' }],
  },
];

export function DemoNavigation() {
  const navigate = useNavigate();
  const location = useLocation();
  const [open, setOpen] = useState(false);

  if (location.pathname === '/') return null;

  return (
    <div className="fixed bottom-4 right-4 z-50 w-[280px]">
      {open && (
        <Card variant="elevated" className="mb-2 max-h-[70vh] overflow-y-auto">
          <div className="p-3 border-b border-neutral-200">
            <button
              onClick={() => navigate('/')}
              className="text-sm font-medium text-neutral-900 hover:underline"
            >
              ← Pregled svih ekrana
            </button>
          </div>

          <div className="p-3 space-y-4">
            {groups.map((group) => {
              const Icon = group.icon;
              return (
                <div key={group.category}>
                  <div className="flex items-center gap-1.5 mb-1.5">
                    <Icon className="w-3.5 h-3.5 text-neutral-400" />
                    <p className="text-[10px] font-semibold text-neutral-500 uppercase tracking-wide">
                      {group.category}
                    </p>
                  </div>
                  <div className="space-y-0.5">
                    {group.items.map((item) => (
                      <button
                        key={item.path}
                        onClick={() => navigate(item.path)}
                        className={clsx(
                          'w-full text-left px-2.5 py-1.5 rounded text-xs transition-colors',
                          item.path.startsWith(location.pathname + '?') || location.pathname === item.path.split('?')[0]
                            ? 'bg-neutral-900 text-white font-medium'
                            : 'text-neutral-700 hover:bg-neutral-100'
                        )}
                      >
                        {item.label}
                      </button>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        </Card>
      )}

      <button
        onClick={() => setOpen(!open)}
        className="w-full flex items-center justify-between gap-2 px-4 py-3 rounded-lg bg-neutral-900 text-white shadow-lg hover:bg-neutral-800 transition-colors"
      >
        <span className="text-sm font-medium">Wireframe ekrani</span>
        {open ? <ChevronDown className="w-4 h-4" /> : <ChevronUp className="w-4 h-4" />}
      </button>
    </div>
  );
}
