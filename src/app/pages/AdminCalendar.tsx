import { useState } from 'react';
import { AdminSidebar } from '../components/AdminSidebar';
import { Card } from '../components/Card';
import { Button } from '../components/Button';
import { Select } from '../components/Select';
import { ChevronLeft, ChevronRight, Plus, Ban } from 'lucide-react';

type SlotKind = 'confirmed' | 'pending' | 'blocked' | 'free';

interface Slot {
  time: string;
  kind: SlotKind;
  label?: string;
  employee?: string;
  span?: number;
}

const slots: Slot[] = [
  { time: '08:00', kind: 'free' },
  { time: '08:30', kind: 'free' },
  { time: '09:00', kind: 'confirmed', label: 'Muško šišanje', employee: 'Emir', span: 2 },
  { time: '09:30', kind: 'confirmed', label: '', employee: 'Emir' },
  { time: '10:00', kind: 'confirmed', label: 'Uređivanje brade', employee: 'Amar' },
  { time: '10:30', kind: 'free' },
  { time: '11:00', kind: 'free' },
  { time: '11:30', kind: 'confirmed', label: 'Šišanje + brada', employee: 'Emir', span: 3 },
  { time: '12:00', kind: 'confirmed', label: '', employee: 'Emir' },
  { time: '12:30', kind: 'confirmed', label: '', employee: 'Emir' },
  { time: '13:00', kind: 'free' },
  { time: '13:30', kind: 'pending', label: 'Feniranje', employee: 'Lejla' },
  { time: '14:00', kind: 'blocked', label: 'Pauza', span: 2 },
  { time: '14:30', kind: 'blocked', label: '' },
  { time: '15:00', kind: 'confirmed', label: 'Muško šišanje', employee: 'Amar' },
  { time: '15:30', kind: 'free' },
  { time: '16:00', kind: 'free' },
  { time: '16:30', kind: 'free' },
];

const barStyle: Record<SlotKind, string> = {
  confirmed: 'bg-green-500',
  pending: 'bg-yellow-400',
  blocked: 'bg-neutral-400',
  free: 'bg-transparent',
};

const rowStyle: Record<SlotKind, string> = {
  confirmed: 'bg-green-50',
  pending: 'bg-yellow-50',
  blocked: 'bg-neutral-100',
  free: 'hover:bg-neutral-50 cursor-pointer',
};

export function AdminCalendar() {
  const [employee, setEmployee] = useState('all');

  return (
    <div className="flex min-h-screen bg-neutral-50">
      <AdminSidebar />

      <div className="flex-1 p-8">
        <div className="max-w-4xl">
          <div className="flex items-start justify-between mb-6">
            <div>
              <h1 className="text-2xl font-bold text-neutral-900">Kalendar</h1>
              <p className="text-neutral-600 mt-1">
                Dnevni prikaz. Sedmični prikaz i drag-and-drop dolaze u Fazi 2.
              </p>
            </div>
            <div className="flex gap-2">
              <Button variant="outline" size="sm">
                <Plus className="w-4 h-4 mr-1.5" />
                Dodaj termin
              </Button>
              <Button variant="outline" size="sm">
                <Ban className="w-4 h-4 mr-1.5" />
                Blokiraj vrijeme
              </Button>
            </div>
          </div>

          <Card variant="bordered" className="mb-4 p-4">
            <div className="flex items-center justify-between gap-4">
              <div className="flex items-center gap-2">
                <Button variant="ghost" size="sm">
                  <ChevronLeft className="w-4 h-4" />
                </Button>
                <span className="font-medium text-neutral-900 min-w-[190px] text-center">
                  Srijeda, 20.05.2026.
                </span>
                <Button variant="ghost" size="sm">
                  <ChevronRight className="w-4 h-4" />
                </Button>
                <Button variant="secondary" size="sm" className="ml-2">
                  Danas
                </Button>
              </div>

              <div className="w-48">
                <Select
                  value={employee}
                  onChange={(e) => setEmployee(e.target.value)}
                  options={[
                    { value: 'all', label: 'Svi radnici' },
                    { value: 'emir', label: 'Emir' },
                    { value: 'amar', label: 'Amar' },
                    { value: 'lejla', label: 'Lejla' },
                  ]}
                />
              </div>
            </div>
          </Card>

          <Card variant="bordered" className="overflow-hidden">
            {slots.map((slot) => (
              <div
                key={slot.time}
                className={`flex items-stretch border-b border-neutral-100 last:border-0 ${rowStyle[slot.kind]}`}
              >
                <div className="w-20 py-3 px-4 text-sm text-neutral-500 tabular-nums shrink-0">
                  {slot.time}
                </div>
                <div className={`w-1 shrink-0 ${barStyle[slot.kind]}`} />
                <div className="flex-1 py-3 px-4">
                  {slot.label ? (
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium text-neutral-900">
                        {slot.kind === 'blocked' ? `⛔ Blokirano — ${slot.label}` : slot.label}
                      </span>
                      {slot.employee && (
                        <span className="text-sm text-neutral-500">· {slot.employee}</span>
                      )}
                      {slot.kind === 'pending' && (
                        <span className="text-xs text-yellow-700 font-medium">Na čekanju</span>
                      )}
                    </div>
                  ) : slot.kind === 'free' ? (
                    <span className="text-sm text-neutral-300">+ Dodaj termin</span>
                  ) : null}
                </div>
              </div>
            ))}
          </Card>

          <div className="flex items-center gap-6 mt-4 text-sm text-neutral-600">
            <span className="flex items-center gap-2">
              <span className="w-3 h-3 rounded bg-green-500" /> Potvrđeno
            </span>
            <span className="flex items-center gap-2">
              <span className="w-3 h-3 rounded bg-yellow-400" /> Na čekanju
            </span>
            <span className="flex items-center gap-2">
              <span className="w-3 h-3 rounded bg-neutral-400" /> Blokirano
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
