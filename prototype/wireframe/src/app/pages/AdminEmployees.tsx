import { AdminSidebar } from '../components/AdminSidebar';
import { Card } from '../components/Card';
import { Button } from '../components/Button';
import { Badge } from '../components/Badge';
import { Plus, Pencil, AlertTriangle } from 'lucide-react';

interface Employee {
  id: number;
  name: string;
  role: string;
  services: string[];
  active: boolean;
  upcoming: number;
}

const employees: Employee[] = [
  {
    id: 1,
    name: 'Emir Hadžić',
    role: 'Barber',
    services: ['Muško šišanje', 'Fade šišanje', 'Šišanje + brada', 'Uređivanje brade', 'Brijanje britvom'],
    active: true,
    upcoming: 12,
  },
  {
    id: 2,
    name: 'Amar Kovač',
    role: 'Barber',
    services: ['Muško šišanje', 'Šišanje + brada', 'Uređivanje brade', 'Dječije šišanje'],
    active: true,
    upcoming: 8,
  },
  {
    id: 3,
    name: 'Nedim Softić',
    role: 'Barber — pripravnik',
    services: ['Muško šišanje'],
    active: false,
    upcoming: 0,
  },
];

export function AdminEmployees() {
  return (
    <div className="flex min-h-screen bg-neutral-50">
      <AdminSidebar />

      <div className="flex-1 p-8">
        <div className="max-w-3xl">
          <div className="flex items-start justify-between mb-6">
            <div>
              <h1 className="text-2xl font-bold text-neutral-900">Radnici</h1>
              <p className="text-neutral-600 mt-1">
                Klijent u aplikaciji vidi samo radnike koji rade izabranu uslugu.
              </p>
            </div>
            <Button>
              <Plus className="w-4 h-4 mr-1.5" />
              Dodaj radnika
            </Button>
          </div>

          <div className="space-y-4">
            {employees.map((e) => (
              <Card
                key={e.id}
                variant="bordered"
                className={`p-5 ${!e.active ? 'opacity-60' : ''}`}
              >
                <div className="flex items-start gap-4">
                  <div className="w-14 h-14 rounded-full bg-neutral-200 shrink-0 flex items-center justify-center">
                    <span className="font-medium text-neutral-600">
                      {e.name.split(' ').map((n) => n[0]).join('')}
                    </span>
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2.5">
                      <h3 className="font-medium text-neutral-900">{e.name}</h3>
                      {e.active ? (
                        <Badge variant="success">Aktivan</Badge>
                      ) : (
                        <Badge>Neaktivan</Badge>
                      )}
                    </div>
                    <p className="text-sm text-neutral-600 mt-0.5">{e.role}</p>

                    <div className="flex flex-wrap gap-1.5 mt-3">
                      {e.services.map((s) => (
                        <span
                          key={s}
                          className="text-xs px-2 py-1 rounded-md bg-neutral-100 text-neutral-700"
                        >
                          {s}
                        </span>
                      ))}
                    </div>

                    {e.active && e.upcoming > 0 && (
                      <p className="text-xs text-neutral-500 mt-3">
                        {e.upcoming} budućih termina
                      </p>
                    )}
                  </div>

                  <Button variant="ghost" size="sm">
                    <Pencil className="w-4 h-4" />
                  </Button>
                </div>
              </Card>
            ))}
          </div>

          <Card variant="bordered" className="mt-8 p-5 bg-yellow-50 border-yellow-200">
            <div className="flex items-start gap-3">
              <AlertTriangle className="w-5 h-5 text-yellow-700 shrink-0 mt-0.5" />
              <div>
                <h3 className="font-medium text-yellow-900 mb-1.5">
                  Deaktivacija radnika sa terminima
                </h3>
                <p className="text-sm text-yellow-800">
                  Ako radnik ima buduće termine, sistem mora ponuditi prebacivanje na drugog
                  radnika ili otkazivanje — nikad tiho ne ostavljaj termine bez radnika.
                </p>
              </div>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}
