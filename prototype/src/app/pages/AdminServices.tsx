import { AdminSidebar } from '../components/AdminSidebar';
import { Card } from '../components/Card';
import { Button } from '../components/Button';
import { Badge } from '../components/Badge';
import { Plus, Pencil, Clock, Tag } from 'lucide-react';

interface Service {
  id: number;
  name: string;
  duration: number;
  price: number;
  employees: string[];
  active: boolean;
}

const grouped: { category: string; services: Service[] }[] = [
  {
    category: 'Šišanje',
    services: [
      { id: 1, name: 'Muško šišanje', duration: 30, price: 15, employees: ['Emir', 'Amar'], active: true },
      { id: 2, name: 'Fade šišanje', duration: 40, price: 20, employees: ['Emir'], active: true },
      { id: 3, name: 'Šišanje + brada', duration: 45, price: 25, employees: ['Emir', 'Amar'], active: true },
      { id: 4, name: 'Dječije šišanje', duration: 20, price: 10, employees: ['Amar'], active: false },
    ],
  },
  {
    category: 'Brada',
    services: [
      { id: 5, name: 'Uređivanje brade', duration: 20, price: 10, employees: ['Emir', 'Amar'], active: true },
      { id: 6, name: 'Brijanje britvom', duration: 30, price: 15, employees: ['Emir'], active: true },
    ],
  },
];

export function AdminServices() {
  return (
    <div className="flex min-h-screen bg-neutral-50">
      <AdminSidebar />

      <div className="flex-1 p-8">
        <div className="max-w-3xl">
          <div className="flex items-start justify-between mb-6">
            <div>
              <h1 className="text-2xl font-bold text-neutral-900">Usluge</h1>
              <p className="text-neutral-600 mt-1">
                Trajanje usluge određuje dužinu termina u kalendaru.
              </p>
            </div>
            <Button>
              <Plus className="w-4 h-4 mr-1.5" />
              Dodaj uslugu
            </Button>
          </div>

          <div className="space-y-6">
            {grouped.map((group) => (
              <div key={group.category}>
                <div className="flex items-center gap-2 mb-3">
                  <Tag className="w-4 h-4 text-neutral-400" />
                  <h2 className="text-xs font-semibold text-neutral-500 uppercase tracking-wide">
                    {group.category}
                  </h2>
                </div>

                <Card variant="bordered" className="overflow-hidden">
                  {group.services.map((s, i) => (
                    <div
                      key={s.id}
                      className={`flex items-center justify-between gap-4 p-5 ${
                        i > 0 ? 'border-t border-neutral-100' : ''
                      } ${!s.active ? 'opacity-50' : ''}`}
                    >
                      <div className="min-w-0">
                        <div className="flex items-center gap-2.5">
                          <h3 className="font-medium text-neutral-900">{s.name}</h3>
                          {s.active ? (
                            <Badge variant="success">Aktivna</Badge>
                          ) : (
                            <Badge>Neaktivna</Badge>
                          )}
                        </div>
                        <div className="flex items-center gap-3 mt-1.5 text-sm text-neutral-600">
                          <span className="flex items-center gap-1">
                            <Clock className="w-3.5 h-3.5" />
                            {s.duration} min
                          </span>
                          <span className="font-medium text-neutral-900">{s.price} KM</span>
                        </div>
                        <p className="text-xs text-neutral-500 mt-1.5 truncate">
                          Radi: {s.employees.join(', ')}
                        </p>
                      </div>

                      <Button variant="ghost" size="sm">
                        <Pencil className="w-4 h-4" />
                      </Button>
                    </div>
                  ))}
                </Card>
              </div>
            ))}
          </div>

          <Card variant="bordered" className="mt-8 p-5 bg-blue-50 border-blue-200">
            <h3 className="font-medium text-blue-900 mb-1.5">Za stomatološku vertikalu</h3>
            <p className="text-sm text-blue-800">
              Usluga dobija dodatno polje <strong>Recall interval</strong> (mjeseci). Nakon
              završenog pregleda sistem automatski zakazuje podsjetnik za kontrolni pregled —
              jedina funkcija koja ordinaciji direktno donosi prihod.
            </p>
          </Card>
        </div>
      </div>
    </div>
  );
}
