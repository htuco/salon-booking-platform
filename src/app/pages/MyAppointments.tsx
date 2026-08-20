import { useState } from 'react';
import { useNavigate } from 'react-router';
import { Button } from '../components/Button';
import { Card } from '../components/Card';
import { Badge } from '../components/Badge';
import { ArrowLeft, Calendar, CalendarPlus, Phone, Scissors } from 'lucide-react';

type Status = 'pending' | 'confirmed' | 'cancelled' | 'completed' | 'no_show';

interface ClientAppointment {
  id: number;
  status: Status;
  service: string;
  employee: string;
  dateLabel: string;
  relative: string;
  price: string;
  cancellable: boolean;
}

const upcoming: ClientAppointment[] = [
  {
    id: 1,
    status: 'confirmed',
    service: 'Fade šišanje',
    employee: 'Emir',
    dateLabel: 'Srijeda, 20.05. u 14:30',
    relative: 'za 2 dana',
    price: '20 KM',
    cancellable: true,
  },
  {
    id: 2,
    status: 'pending',
    service: 'Uređivanje brade',
    employee: 'Bilo koji dostupan',
    dateLabel: 'Subota, 23.05. u 11:00',
    relative: 'za 5 dana',
    price: '10 KM',
    cancellable: true,
  },
];

const past: ClientAppointment[] = [
  {
    id: 3,
    status: 'completed',
    service: 'Muško šišanje',
    employee: 'Emir',
    dateLabel: 'Ponedjeljak, 28.04. u 10:00',
    relative: 'prije 3 sedmice',
    price: '15 KM',
    cancellable: false,
  },
  {
    id: 4,
    status: 'cancelled',
    service: 'Šišanje + brada',
    employee: 'Amar',
    dateLabel: 'Četvrtak, 10.04. u 17:00',
    relative: 'prije 6 sedmica',
    price: '25 KM',
    cancellable: false,
  },
];

const statusMeta: Record<Status, { label: string; variant: 'success' | 'warning' | 'danger' | 'default' }> = {
  pending: { label: 'Na čekanju', variant: 'warning' },
  confirmed: { label: 'Potvrđeno', variant: 'success' },
  cancelled: { label: 'Otkazano', variant: 'danger' },
  completed: { label: 'Završeno', variant: 'default' },
  no_show: { label: 'Nije došao/la', variant: 'danger' },
};

export function MyAppointments() {
  const navigate = useNavigate();
  const [tab, setTab] = useState<'upcoming' | 'past'>('upcoming');

  const list = tab === 'upcoming' ? upcoming : past;

  return (
    <div className="min-h-screen bg-neutral-100">
      <div className="max-w-[390px] mx-auto bg-white min-h-screen">
        <div className="px-6 pt-6 pb-4 border-b border-neutral-200">
          <button
            onClick={() => navigate('/s/barber-studio-vitez')}
            className="flex items-center gap-1.5 text-sm text-neutral-600 mb-4"
          >
            <ArrowLeft className="w-4 h-4" />
            Nazad
          </button>
          <h1 className="text-2xl font-bold text-neutral-900">Moji termini</h1>
          <p className="text-sm text-neutral-500 mt-1">
Prate vaš račun kroz sve uređaje
          </p>
        </div>

        <div className="flex border-b border-neutral-200">
          {(
            [
              ['upcoming', 'Naredni'],
              ['past', 'Prošli'],
            ] as const
          ).map(([key, label]) => (
            <button
              key={key}
              onClick={() => setTab(key)}
              className={`flex-1 py-3.5 text-sm font-medium transition-colors ${
                tab === key
                  ? 'text-neutral-900 border-b-2 border-neutral-900'
                  : 'text-neutral-500'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        <div className="p-6 space-y-4">
          {list.length === 0 ? (
            <div className="text-center py-16">
              <div className="w-16 h-16 rounded-full bg-neutral-100 mx-auto mb-4 flex items-center justify-center">
                <Scissors className="w-7 h-7 text-neutral-400" />
              </div>
              <h2 className="font-medium text-neutral-900 mb-1">Još nemate termina</h2>
              <p className="text-sm text-neutral-600 mb-6">
                Zakažite prvi termin u par tapova.
              </p>
              <Button onClick={() => navigate('/s/barber-studio-vitez/book/service')}>
                Zakaži termin
              </Button>
            </div>
          ) : (
            list.map((a) => {
              const meta = statusMeta[a.status];
              const dimmed = tab === 'past';

              return (
                <Card
                  key={a.id}
                  variant="bordered"
                  className={`p-5 ${dimmed ? 'opacity-60' : ''}`}
                >
                  <Badge variant={meta.variant}>{meta.label}</Badge>

                  <h3 className="font-medium text-neutral-900 mt-3">{a.service}</h3>
                  <p className="text-sm text-neutral-600">{a.employee}</p>

                  <div className="mt-4 pt-4 border-t border-neutral-100">
                    <p className="text-sm font-medium text-neutral-900">{a.dateLabel}</p>
                    <p className="text-xs text-neutral-500 mt-0.5">{a.relative}</p>
                  </div>

                  {a.cancellable && (
                    <div className="flex gap-2 mt-4">
                      <Button variant="outline" size="sm" className="flex-1">
                        {a.status === 'pending' ? 'Otkaži zahtjev' : 'Otkaži'}
                      </Button>
                      <Button variant="ghost" size="sm" className="flex-1">
                        <CalendarPlus className="w-4 h-4 mr-1.5" />
                        Kalendar
                      </Button>
                    </div>
                  )}

                  {tab === 'upcoming' && !a.cancellable && (
                    <div className="mt-4 p-3 bg-neutral-50 rounded-lg">
                      <p className="text-xs text-neutral-600 mb-2">
                        Prošao je rok za otkazivanje. Pozovite salon.
                      </p>
                      <Button variant="outline" size="sm" fullWidth>
                        <Phone className="w-4 h-4 mr-1.5" />
                        Pozovi salon
                      </Button>
                    </div>
                  )}

                  {a.status === 'completed' && (
                    <div className="mt-4 p-3 bg-blue-50 rounded-lg flex items-start gap-2">
                      <Calendar className="w-4 h-4 text-blue-600 mt-0.5 shrink-0" />
                      <div>
                        <p className="text-xs text-blue-900">
                          Vrijeme je za novo šišanje?
                        </p>
                        <button className="text-xs font-medium text-blue-700 underline mt-1">
                          Zakaži ponovo
                        </button>
                      </div>
                    </div>
                  )}
                </Card>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}
