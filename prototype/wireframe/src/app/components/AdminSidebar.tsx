import { useNavigate, useLocation } from 'react-router';
import {
  LayoutDashboard,
  Calendar,
  CalendarClock,
  Scissors,
  Users,
  Clock,
  Settings,
  LogOut,
} from 'lucide-react';
import { clsx } from 'clsx';

const menuItems = [
  { icon: LayoutDashboard, label: 'Dashboard', path: '/admin/dashboard', ready: true },
  { icon: CalendarClock, label: 'Termini', path: '/admin/appointments', ready: true },
  { icon: Calendar, label: 'Kalendar', path: '/admin/calendar', ready: true },
  { icon: Scissors, label: 'Usluge', path: '/admin/services', ready: true },
  { icon: Users, label: 'Radnici', path: '/admin/employees', ready: true },
  { icon: Clock, label: 'Radno vrijeme', path: '/admin/working-hours', ready: false },
  { icon: Settings, label: 'Postavke', path: '/admin/settings', ready: false },
];

export function AdminSidebar() {
  const navigate = useNavigate();
  const location = useLocation();

  return (
    <div className="w-64 bg-white border-r border-neutral-200 h-screen sticky top-0 flex flex-col">
      <div className="p-6 border-b border-neutral-200">
        <h1 className="font-bold text-lg text-neutral-900">Barber Studio Vitez</h1>
        <p className="text-sm text-neutral-500 mt-0.5">Salon Admin</p>
      </div>

      <nav className="flex-1 p-4 overflow-y-auto">
        <ul className="space-y-1">
          {menuItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path;

            return (
              <li key={item.path}>
                <button
                  onClick={() => item.ready && navigate(item.path)}
                  disabled={!item.ready}
                  title={item.ready ? undefined : 'Nije u mockupu — vidi docs/02 §12'}
                  className={clsx(
                    'w-full flex items-center gap-3 px-4 py-3 rounded-lg transition-colors text-left',
                    isActive
                      ? 'bg-neutral-900 text-white'
                      : item.ready
                        ? 'text-neutral-700 hover:bg-neutral-100'
                        : 'text-neutral-300 cursor-not-allowed'
                  )}
                >
                  <Icon className="w-5 h-5 shrink-0" />
                  <span className="font-medium text-sm">{item.label}</span>
                </button>
              </li>
            );
          })}
        </ul>
      </nav>

      <div className="p-4 border-t border-neutral-200">
        <button
          onClick={() => navigate('/admin/login')}
          className="w-full flex items-center gap-3 px-4 py-3 rounded-lg text-neutral-600 hover:bg-neutral-100 transition-colors"
        >
          <LogOut className="w-5 h-5" />
          <span className="font-medium text-sm">Odjava</span>
        </button>
      </div>
    </div>
  );
}
