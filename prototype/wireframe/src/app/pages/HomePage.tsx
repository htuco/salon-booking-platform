import { useNavigate } from 'react-router';
import { Button } from '../components/Button';
import { Card } from '../components/Card';
import { Clock, MapPin, Phone, Mail, Instagram, Facebook } from 'lucide-react';

interface HomePageProps {
  theme: 'barber' | 'beauty';
}

const barberData = {
  name: 'Barber Studio Vitez',
  tagline: 'Profesionalna njega za modernog muškarca',
  description: 'Dobrodošli u naš barber studio. Nudimo vrhunsku uslugu šišanja i njege brade u opuštenoj atmosferi.',
  services: [
    { name: 'Muško šišanje', duration: '30 min', price: '15 KM' },
    { name: 'Fade šišanje', duration: '40 min', price: '20 KM' },
    { name: 'Šišanje + brada', duration: '45 min', price: '25 KM' },
    { name: 'Uređivanje brade', duration: '20 min', price: '10 KM' },
  ],
  hours: [
    { day: 'Ponedjeljak - Petak', time: '09:00 - 20:00' },
    { day: 'Subota', time: '09:00 - 18:00' },
    { day: 'Nedjelja', time: 'Zatvoreno' },
  ],
  location: 'Trg Slobode 15, Vitez',
  phone: '+387 62 123 456',
  email: 'info@barberstudiovitez.ba',
};

const beautyData = {
  name: 'Beauty Studio Travnik',
  tagline: 'Vaša ljepota, naša strast',
  description: 'Profesionalni frizerski salon sa iskusnim stilistima. Pretvorite svoj izgled u pravu umjetnost.',
  services: [
    { name: 'Žensko šišanje', duration: '45 min', price: '25 KM' },
    { name: 'Feniranje', duration: '40 min', price: '20 KM' },
    { name: 'Farbanje', duration: '120 min', price: '70 KM' },
    { name: 'Pramenovi', duration: '150 min', price: '100 KM' },
  ],
  team: [
    { name: 'Amira Hadžić', role: 'Stilista' },
    { name: 'Lejla Softić', role: 'Kolorista' },
    { name: 'Maja Kovač', role: 'Stilista' },
  ],
  hours: [
    { day: 'Ponedjeljak - Petak', time: '08:00 - 19:00' },
    { day: 'Subota', time: '08:00 - 16:00' },
    { day: 'Nedjelja', time: 'Zatvoreno' },
  ],
  location: 'Bosanska 42, Travnik',
  phone: '+387 62 789 123',
  email: 'kontakt@beautystudiotravnik.ba',
};

export function HomePage({ theme }: HomePageProps) {
  const navigate = useNavigate();
  const data = theme === 'barber' ? barberData : beautyData;
  const slug = theme === 'barber' ? 'barber-studio-vitez' : 'beauty-studio-travnik';
  const isDark = theme === 'barber';

  return (
    <div className={`min-h-screen ${isDark ? 'bg-neutral-900' : 'bg-neutral-50'}`}>
      <div className="max-w-[390px] mx-auto bg-white">
        <div className={`relative h-64 ${isDark ? 'bg-neutral-800' : 'bg-neutral-200'} flex items-center justify-center`}>
          <div className="text-center px-6">
            <div className={`w-20 h-20 rounded-full ${isDark ? 'bg-neutral-700' : 'bg-white'} mx-auto mb-4 flex items-center justify-center`}>
              <span className={`text-2xl ${isDark ? 'text-white' : 'text-neutral-600'}`}>Logo</span>
            </div>
            <h1 className={`text-2xl font-bold ${isDark ? 'text-white' : 'text-neutral-900'}`}>
              {data.name}
            </h1>
            <p className={`mt-2 text-sm ${isDark ? 'text-neutral-300' : 'text-neutral-600'}`}>
              {data.tagline}
            </p>
          </div>
        </div>

        <div className="p-6 space-y-8">
          <div>
            <p className="text-neutral-700 leading-relaxed">
              {data.description}
            </p>
            <Button
              fullWidth
              size="lg"
              className={`mt-6 ${isDark ? 'bg-amber-600 hover:bg-amber-700' : ''}`}
              onClick={() => navigate(`/s/${slug}/book/service`)}
            >
              Zakaži termin
            </Button>
          </div>

          <div>
            <h2 className="text-xl font-bold text-neutral-900 mb-4">Popularne usluge</h2>
            <div className="space-y-3">
              {data.services.map((service) => (
                <Card key={service.name} variant="bordered" className="p-4">
                  <div className="flex justify-between items-start">
                    <div>
                      <h3 className="font-medium text-neutral-900">{service.name}</h3>
                      <p className="text-sm text-neutral-500 mt-1">{service.duration}</p>
                    </div>
                    <span className="font-bold text-neutral-900">{service.price}</span>
                  </div>
                </Card>
              ))}
            </div>
          </div>

          {'team' in data && (
            <div>
              <h2 className="text-xl font-bold text-neutral-900 mb-4">Naš tim</h2>
              <div className="grid grid-cols-3 gap-3">
                {data.team.map((member) => (
                  <div key={member.name} className="text-center">
                    <div className="w-full aspect-square rounded-full bg-neutral-200 mb-2"></div>
                    <p className="text-sm font-medium text-neutral-900">{member.name}</p>
                    <p className="text-xs text-neutral-500">{member.role}</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div>
            <h2 className="text-xl font-bold text-neutral-900 mb-4">Radno vrijeme</h2>
            <Card variant="bordered" className="p-4 space-y-3">
              {data.hours.map((schedule) => (
                <div key={schedule.day} className="flex items-center justify-between">
                  <span className="text-sm text-neutral-700">{schedule.day}</span>
                  <span className="text-sm font-medium text-neutral-900">{schedule.time}</span>
                </div>
              ))}
            </Card>
          </div>

          <div>
            <h2 className="text-xl font-bold text-neutral-900 mb-4">Kontakt</h2>
            <Card variant="bordered" className="p-4 space-y-4">
              <div className="flex items-start gap-3">
                <MapPin className="w-5 h-5 text-neutral-400 mt-0.5 flex-shrink-0" />
                <span className="text-sm text-neutral-700">{data.location}</span>
              </div>
              <div className="flex items-center gap-3">
                <Phone className="w-5 h-5 text-neutral-400 flex-shrink-0" />
                <span className="text-sm text-neutral-700">{data.phone}</span>
              </div>
              <div className="flex items-center gap-3">
                <Mail className="w-5 h-5 text-neutral-400 flex-shrink-0" />
                <span className="text-sm text-neutral-700">{data.email}</span>
              </div>
            </Card>

            <div className="flex items-center justify-center gap-4 mt-6">
              <button className={`w-10 h-10 rounded-full ${isDark ? 'bg-neutral-800' : 'bg-neutral-100'} flex items-center justify-center`}>
                <Instagram className={`w-5 h-5 ${isDark ? 'text-white' : 'text-neutral-600'}`} />
              </button>
              <button className={`w-10 h-10 rounded-full ${isDark ? 'bg-neutral-800' : 'bg-neutral-100'} flex items-center justify-center`}>
                <Facebook className={`w-5 h-5 ${isDark ? 'text-white' : 'text-neutral-600'}`} />
              </button>
            </div>
          </div>
        </div>

        <div className="fixed bottom-0 left-0 right-0 p-4 bg-white border-t border-neutral-200 max-w-[390px] mx-auto">
          <Button
            fullWidth
            size="lg"
            className={isDark ? 'bg-amber-600 hover:bg-amber-700' : ''}
            onClick={() => navigate(`/s/${slug}/book/service`)}
          >
            Zakaži termin
          </Button>
        </div>
      </div>
    </div>
  );
}
