import { AdminSidebar } from '../components/AdminSidebar';
import { Card } from '../components/Card';
import { Button } from '../components/Button';
import { Badge } from '../components/Badge';
import { Calendar, TrendingUp, Clock, Plus } from 'lucide-react';

const stats = [
  { label: 'Termini danas', value: '12', icon: Calendar, color: 'text-blue-600', bg: 'bg-blue-50' },
  { label: 'Novi zahtjevi', value: '3', icon: TrendingUp, color: 'text-green-600', bg: 'bg-green-50' },
  { label: 'Termini ove sedmice', value: '47', icon: Clock, color: 'text-purple-600', bg: 'bg-purple-50' },
];

const newRequests = [
  { id: 1, customer: 'Haris Mehić', service: 'Fade šišanje', time: '14:00', date: '20.05.2026' },
  { id: 2, customer: 'Adnan Kovač', service: 'Šišanje + brada', time: '16:30', date: '20.05.2026' },
  { id: 3, customer: 'Edin Softić', service: 'Muško šišanje', time: '11:00', date: '21.05.2026' },
];

const todaySchedule = [
  { id: 1, time: '09:00', customer: 'Nedim Hadžić', service: 'Fade šišanje', employee: 'Emir', status: 'confirmed' },
  { id: 2, time: '10:00', customer: 'Armin Halilović', service: 'Uređivanje brade', employee: 'Amar', status: 'confirmed' },
  { id: 3, time: '11:30', customer: 'Jasmin Kulenović', service: 'Šišanje + brada', employee: 'Emir', status: 'confirmed' },
  { id: 4, time: '14:00', customer: 'Blocked Time', service: 'Pauza', employee: 'Svi', status: 'blocked' },
  { id: 5, time: '15:00', customer: 'Mirza Husić', service: 'Muško šišanje', employee: 'Amar', status: 'confirmed' },
];

export function AdminDashboard() {
  return (
    <div className="flex min-h-screen bg-neutral-50">
      <AdminSidebar />

      <div className="flex-1 overflow-auto">
        <div className="max-w-7xl mx-auto p-8">
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-neutral-900">Dashboard</h1>
            <p className="text-neutral-600 mt-1">Pregled današnjih aktivnosti</p>
          </div>

          <div className="grid grid-cols-3 gap-6 mb-8">
            {stats.map((stat) => {
              const Icon = stat.icon;
              return (
                <Card key={stat.label} variant="bordered" className="p-6">
                  <div className="flex items-start justify-between">
                    <div>
                      <p className="text-sm text-neutral-600 mb-1">{stat.label}</p>
                      <p className="text-3xl font-bold text-neutral-900">{stat.value}</p>
                    </div>
                    <div className={`w-12 h-12 rounded-lg ${stat.bg} flex items-center justify-center`}>
                      <Icon className={`w-6 h-6 ${stat.color}`} />
                    </div>
                  </div>
                </Card>
              );
            })}
          </div>

          <div className="grid grid-cols-2 gap-6 mb-8">
            <Card variant="bordered">
              <div className="p-6 border-b border-neutral-200">
                <h2 className="font-bold text-xl text-neutral-900">Novi zahtjevi</h2>
              </div>
              <div className="p-6">
                <div className="space-y-4">
                  {newRequests.map((request) => (
                    <div key={request.id} className="flex items-center justify-between p-4 bg-neutral-50 rounded-lg">
                      <div className="flex-1">
                        <p className="font-medium text-neutral-900">{request.customer}</p>
                        <p className="text-sm text-neutral-600">{request.service}</p>
                        <p className="text-sm text-neutral-500 mt-1">{request.date} u {request.time}</p>
                      </div>
                      <div className="flex gap-2">
                        <Button size="sm" variant="primary">Potvrdi</Button>
                        <Button size="sm" variant="outline">Odbij</Button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </Card>

            <Card variant="bordered">
              <div className="p-6 border-b border-neutral-200">
                <h2 className="font-bold text-xl text-neutral-900">Današnji raspored</h2>
              </div>
              <div className="p-6">
                <div className="space-y-3">
                  {todaySchedule.map((appointment) => (
                    <div key={appointment.id} className="flex items-center gap-4 p-3 bg-neutral-50 rounded-lg">
                      <div className="w-16 text-center">
                        <p className="text-sm font-medium text-neutral-900">{appointment.time}</p>
                      </div>
                      <div className="flex-1">
                        <p className="font-medium text-neutral-900">{appointment.customer}</p>
                        <p className="text-sm text-neutral-600">{appointment.service} · {appointment.employee}</p>
                      </div>
                      {appointment.status === 'confirmed' && (
                        <Badge variant="success">Potvrđeno</Badge>
                      )}
                      {appointment.status === 'blocked' && (
                        <Badge variant="default">Blokirano</Badge>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </Card>
          </div>

          <Card variant="bordered" className="p-6">
            <h2 className="font-bold text-xl text-neutral-900 mb-4">Brze akcije</h2>
            <div className="flex gap-3">
              <Button variant="primary">
                <Plus className="w-4 h-4 mr-2" />
                Dodaj termin
              </Button>
              <Button variant="outline">
                <Clock className="w-4 h-4 mr-2" />
                Blokiraj vrijeme
              </Button>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}
