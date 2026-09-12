import { useState } from 'react';
import { AdminSidebar } from '../components/AdminSidebar';
import { Card } from '../components/Card';
import { Button } from '../components/Button';
import { Badge } from '../components/Badge';
import { Select } from '../components/Select';
import { X, Phone, MessageSquare, Smartphone } from 'lucide-react';

type AppointmentStatus = 'pending' | 'confirmed' | 'cancelled' | 'completed';

interface Appointment {
  id: number;
  date: string;
  time: string;
  customer: string;
  /** 'app' klijenti nemaju telefon — komunikacija ide push-om. Vidi docs/06 §3.1 */
  source: 'app' | 'manual';
  phone?: string;
  email?: string;
  service: string;
  employee: string;
  duration: string;
  price: string;
  status: AppointmentStatus;
  note?: string;
}

const appointments: Appointment[] = [
  {
    id: 1,
    source: 'app',
    date: '20.05.2026',
    time: '09:00',
    customer: 'Nedim Hadžić',
    service: 'Fade šišanje',
    employee: 'Emir',
    duration: '40 min',
    price: '20 KM',
    status: 'confirmed',
  },
  {
    id: 2,
    source: 'manual',
    date: '20.05.2026',
    time: '10:00',
    customer: 'Armin Halilović',
    phone: '+387 62 333 444',
    email: 'armin@email.ba',
    service: 'Uređivanje brade',
    employee: 'Amar',
    duration: '20 min',
    price: '10 KM',
    status: 'confirmed',
  },
  {
    id: 3,
    source: 'app',
    date: '20.05.2026',
    time: '14:00',
    customer: 'Haris Mehić',
    service: 'Fade šišanje',
    employee: 'Emir',
    duration: '40 min',
    price: '20 KM',
    status: 'pending',
    note: 'Molim vas fade sa brojem 2 na stranama',
  },
  {
    id: 4,
    source: 'manual',
    date: '20.05.2026',
    time: '16:30',
    customer: 'Adnan Kovač',
    phone: '+387 62 777 888',
    email: 'adnan.k@email.ba',
    service: 'Šišanje + brada',
    employee: 'Amar',
    duration: '45 min',
    price: '25 KM',
    status: 'pending',
  },
  {
    id: 5,
    source: 'app',
    date: '21.05.2026',
    time: '11:00',
    customer: 'Edin Softić',
    service: 'Muško šišanje',
    employee: 'Bilo koji',
    duration: '30 min',
    price: '15 KM',
    status: 'pending',
  },
  {
    id: 6,
    source: 'manual',
    date: '19.05.2026',
    time: '15:00',
    customer: 'Mirza Husić',
    phone: '+387 62 123 789',
    email: 'mirza@email.ba',
    service: 'Muško šišanje',
    employee: 'Emir',
    duration: '30 min',
    price: '15 KM',
    status: 'completed',
  },
  {
    id: 7,
    source: 'app',
    date: '19.05.2026',
    time: '10:00',
    customer: 'Samir Hodžić',
    service: 'Fade šišanje',
    employee: 'Amar',
    duration: '40 min',
    price: '20 KM',
    status: 'cancelled',
  },
];

const getStatusBadge = (status: AppointmentStatus) => {
  switch (status) {
    case 'pending':
      return <Badge variant="warning">Na čekanju</Badge>;
    case 'confirmed':
      return <Badge variant="success">Potvrđeno</Badge>;
    case 'cancelled':
      return <Badge variant="danger">Otkazano</Badge>;
    case 'completed':
      return <Badge variant="default">Završeno</Badge>;
  }
};

export function AdminAppointments() {
  const [selectedAppointment, setSelectedAppointment] = useState<Appointment | null>(null);
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [filterEmployee, setFilterEmployee] = useState<string>('all');

  const filteredAppointments = appointments.filter((apt) => {
    if (filterStatus !== 'all' && apt.status !== filterStatus) return false;
    if (filterEmployee !== 'all' && apt.employee !== filterEmployee) return false;
    return true;
  });

  return (
    <div className="flex min-h-screen bg-neutral-50">
      <AdminSidebar />

      <div className="flex-1 overflow-auto">
        <div className="max-w-7xl mx-auto p-8">
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-neutral-900">Termini</h1>
            <p className="text-neutral-600 mt-1">Pregled i upravljanje terminima</p>
          </div>

          <Card variant="bordered" className="mb-6 p-6">
            <div className="flex gap-4">
              <Select
                options={[
                  { value: 'all', label: 'Svi statusi' },
                  { value: 'pending', label: 'Na čekanju' },
                  { value: 'confirmed', label: 'Potvrđeno' },
                  { value: 'cancelled', label: 'Otkazano' },
                  { value: 'completed', label: 'Završeno' },
                ]}
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value)}
              />
              <Select
                options={[
                  { value: 'all', label: 'Svi radnici' },
                  { value: 'Emir', label: 'Emir' },
                  { value: 'Amar', label: 'Amar' },
                ]}
                value={filterEmployee}
                onChange={(e) => setFilterEmployee(e.target.value)}
              />
            </div>
          </Card>

          <Card variant="bordered">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-neutral-50 border-b border-neutral-200">
                  <tr>
                    <th className="px-6 py-4 text-left text-sm font-medium text-neutral-600">Datum i vrijeme</th>
                    <th className="px-6 py-4 text-left text-sm font-medium text-neutral-600">Kupac</th>
                    <th className="px-6 py-4 text-left text-sm font-medium text-neutral-600">Usluga</th>
                    <th className="px-6 py-4 text-left text-sm font-medium text-neutral-600">Radnik</th>
                    <th className="px-6 py-4 text-left text-sm font-medium text-neutral-600">Cijena</th>
                    <th className="px-6 py-4 text-left text-sm font-medium text-neutral-600">Status</th>
                    <th className="px-6 py-4 text-left text-sm font-medium text-neutral-600">Akcije</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-neutral-200">
                  {filteredAppointments.map((appointment) => (
                    <tr key={appointment.id} className="hover:bg-neutral-50">
                      <td className="px-6 py-4">
                        <div className="text-sm font-medium text-neutral-900">{appointment.date}</div>
                        <div className="text-sm text-neutral-500">{appointment.time}</div>
                      </td>
                      <td className="px-6 py-4">
                        <div className="text-sm font-medium text-neutral-900">{appointment.customer}</div>
                        <div className="text-sm text-neutral-500">
                          {appointment.source === 'app' ? '📱 Iz aplikacije' : appointment.phone}
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <div className="text-sm text-neutral-900">{appointment.service}</div>
                        <div className="text-sm text-neutral-500">{appointment.duration}</div>
                      </td>
                      <td className="px-6 py-4 text-sm text-neutral-900">{appointment.employee}</td>
                      <td className="px-6 py-4 text-sm font-medium text-neutral-900">{appointment.price}</td>
                      <td className="px-6 py-4">{getStatusBadge(appointment.status)}</td>
                      <td className="px-6 py-4">
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => setSelectedAppointment(appointment)}
                        >
                          Detalji
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      </div>

      {selectedAppointment && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-end z-50">
          <div className="w-full max-w-md bg-white h-full overflow-auto shadow-2xl">
            <div className="sticky top-0 bg-white border-b border-neutral-200 px-6 py-4 flex items-center justify-between">
              <h2 className="text-xl font-bold text-neutral-900">Detalji termina</h2>
              <button
                onClick={() => setSelectedAppointment(null)}
                className="p-2 hover:bg-neutral-100 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-6">
              <div>
                <h3 className="text-sm font-medium text-neutral-600 mb-3">Status</h3>
                {getStatusBadge(selectedAppointment.status)}
              </div>

              <div>
                <h3 className="text-sm font-medium text-neutral-600 mb-3">Informacije o kupcu</h3>
                <Card variant="bordered" className="p-4 space-y-3">
                  <div>
                    <p className="text-sm text-neutral-600">Ime</p>
                    <p className="font-medium text-neutral-900">{selectedAppointment.customer}</p>
                  </div>
                  {selectedAppointment.source === 'app' ? (
                    <div className="p-3 rounded-lg bg-green-50 border border-green-200">
                      <div className="flex items-center gap-2">
                        <Smartphone className="w-4 h-4 text-green-700" />
                        <p className="text-sm font-medium text-green-900">
                          Iz aplikacije · push aktivan
                        </p>
                      </div>
                      <p className="text-xs text-green-800 mt-1.5 leading-relaxed">
                        Potvrda, odbijanje i podsjetnici idu automatski kao obavijest.
                        Broj telefona se ne prikuplja.
                      </p>
                    </div>
                  ) : (
                    <>
                      <div className="flex items-center gap-2">
                        <Phone className="w-4 h-4 text-neutral-400" />
                        <p className="text-sm text-neutral-900">{selectedAppointment.phone}</p>
                      </div>
                      <div className="flex gap-2 pt-1">
                        <Button variant="outline" size="sm">
                          <Phone className="w-3.5 h-3.5 mr-1.5" />
                          Zovi
                        </Button>
                        <Button variant="outline" size="sm">
                          <MessageSquare className="w-3.5 h-3.5 mr-1.5" />
                          Viber
                        </Button>
                      </div>
                      <p className="text-xs text-neutral-500 leading-relaxed">
                        Ručno unesen klijent — nema aplikaciju, pa je telefon jedini kanal.
                      </p>
                    </>
                  )}
                </Card>
              </div>

              <div>
                <h3 className="text-sm font-medium text-neutral-600 mb-3">Detalji termina</h3>
                <Card variant="bordered" className="p-4 space-y-3">
                  <div className="flex justify-between">
                    <span className="text-sm text-neutral-600">Usluga:</span>
                    <span className="text-sm font-medium text-neutral-900">{selectedAppointment.service}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-neutral-600">Radnik:</span>
                    <span className="text-sm font-medium text-neutral-900">{selectedAppointment.employee}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-neutral-600">Datum:</span>
                    <span className="text-sm font-medium text-neutral-900">{selectedAppointment.date}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-neutral-600">Vrijeme:</span>
                    <span className="text-sm font-medium text-neutral-900">{selectedAppointment.time}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-neutral-600">Trajanje:</span>
                    <span className="text-sm font-medium text-neutral-900">{selectedAppointment.duration}</span>
                  </div>
                  <div className="flex justify-between pt-3 border-t border-neutral-200">
                    <span className="font-medium text-neutral-900">Cijena:</span>
                    <span className="font-bold text-neutral-900">{selectedAppointment.price}</span>
                  </div>
                </Card>
              </div>

              {selectedAppointment.note && (
                <div>
                  <h3 className="text-sm font-medium text-neutral-600 mb-3">Napomena</h3>
                  <Card variant="bordered" className="p-4">
                    <div className="flex items-start gap-2">
                      <MessageSquare className="w-4 h-4 text-neutral-400 mt-0.5" />
                      <p className="text-sm text-neutral-700">{selectedAppointment.note}</p>
                    </div>
                  </Card>
                </div>
              )}

              <div className="space-y-3 pt-4 border-t border-neutral-200">
                {selectedAppointment.status === 'pending' && (
                  <>
                    <Button fullWidth variant="primary">Potvrdi termin</Button>
                    <Button fullWidth variant="danger">Odbij termin</Button>
                  </>
                )}
                {selectedAppointment.status === 'confirmed' && (
                  <>
                    <Button fullWidth variant="primary">Završi termin</Button>
                    <Button fullWidth variant="outline">Otkaži termin</Button>
                  </>
                )}
                {(selectedAppointment.status === 'completed' || selectedAppointment.status === 'cancelled') && (
                  <Button fullWidth variant="outline">Obriši termin</Button>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
