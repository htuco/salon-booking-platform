import { useNavigate } from 'react-router';
import { Card } from '../components/Card';
import { Button } from '../components/Button';
import { Badge } from '../components/Badge';
import {
  Smartphone,
  Monitor,
  Settings2,
  Scissors,
  Sparkles,
  Stethoscope,
  ArrowRight,
  CheckCircle2,
  CircleDashed,
} from 'lucide-react';

interface ScreenItem {
  name: string;
  description: string;
  path?: string;
}

const sections: {
  title: string;
  subtitle: string;
  icon: typeof Smartphone;
  branded: boolean;
  items: ScreenItem[];
}[] = [
  {
    title: 'Client app',
    subtitle: 'Flutter native — brandirana, N flavora iz jednog koda',
    icon: Smartphone,
    branded: true,
    items: [
      {
        name: 'Home — Modern Barber',
        description: 'Barber Studio Vitez · tamna tema',
        path: '/s/barber-studio-vitez',
      },
      {
        name: 'Home — Elegant Beauty',
        description: 'Beauty Studio Travnik · svijetla tema',
        path: '/s/beauty-studio-travnik',
      },
      {
        name: 'Booking 1 — Usluga',
        description: 'Izbor usluge sa trajanjem i cijenom',
        path: '/s/barber-studio-vitez/book/service',
      },
      {
        name: 'Booking 2 — Radnik',
        description: '"Bilo koji dostupan" je default',
        path: '/s/barber-studio-vitez/book/employee',
      },
      {
        name: 'Booking 3 — Termin',
        description: 'Najteži ekran — samo slobodni slotovi',
        path: '/s/barber-studio-vitez/book/datetime',
      },
      {
        name: 'Login gate',
        description: 'Apple · Google · Facebook · Email — posljednji ekran prije potvrde',
        path: '/s/barber-studio-vitez/auth/login',
      },
      {
        name: 'Login — Email OTP',
        description: '6-cifreni kod, bez lozinke',
        path: '/s/barber-studio-vitez/auth/login?screen=otp',
      },
      {
        name: 'Booking 4 — Podaci',
        description: 'Ime iz računa — bez telefona, push zamjenjuje SMS',
        path: '/s/barber-studio-vitez/book/details',
      },
      {
        name: 'Potvrda zahtjeva',
        description: 'Status je "na čekanju", ne "potvrđeno"',
        path: '/s/barber-studio-vitez/book/success',
      },
      {
        name: 'Moji termini',
        description: 'Prate korisnika kroz uređaje i reinstalacije',
        path: '/s/barber-studio-vitez/appointments',
      },
      {
        name: 'Moj račun + brisanje',
        description: 'Obavezno za store — bez njega iOS submission pada',
        path: '/s/barber-studio-vitez/account',
      },
    ],
  },
  {
    title: 'Admin app',
    subtitle: 'Flutter native, jedna generička app za sve salone — vlasnik mora dobiti push',
    icon: Monitor,
    branded: false,
    items: [
      { name: 'Login', description: 'Email + lozinka, biometrija nakon prve prijave', path: '/admin/login' },
      { name: 'Dashboard', description: 'Novi zahtjevi su prvi i najveći blok', path: '/admin/dashboard' },
      { name: 'Termini', description: 'Filteri + detalji u bottom sheetu', path: '/admin/appointments' },
      { name: 'Kalendar', description: 'Dnevni prikaz, boje po statusu', path: '/admin/calendar' },
      { name: 'Usluge', description: 'Trajanje određuje dužinu termina', path: '/admin/services' },
      { name: 'Radnici', description: 'Dodjela usluga po radniku', path: '/admin/employees' },
      { name: 'Radno vrijeme', description: 'Nije u mockupu — vidi docs/02 §12' },
      { name: 'Postavke + branding', description: 'Nije u mockupu — vidi docs/02 §12' },
    ],
  },
  {
    title: 'Super admin',
    subtitle: 'Next.js + shadcn — fabrika salona, koristiš ga samo ti',
    icon: Settings2,
    branded: false,
    items: [
      {
        name: 'Novi salon',
        description: 'Vertikala → podaci → branding → usluge → admin → build config',
        path: '/super-admin/salons/new',
      },
      { name: 'Lista salona + build status', description: 'Nije u mockupu — vidi docs/02 §13' },
    ],
  },
];

const verticals = [
  { icon: Scissors, label: 'Barber / frizeri', phase: 'Faza 1', active: true },
  { icon: Sparkles, label: 'Beauty / nokti / obrve', phase: 'Faza 1', active: true },
  { icon: Stethoscope, label: 'Stomatologija', phase: 'Faza 2', active: false },
];

const docs = [
  { file: 'docs/01-mvp-spec.md', label: 'MVP Specifikacija', desc: 'Proizvod, DB shema, pricing, build order' },
  { file: 'docs/02-user-flows-wireframes.md', label: 'Flows & Wireframes', desc: 'Svi ekrani, push flow, UX copy, design system' },
  { file: 'docs/03-market-research-cutlio.md', label: 'Market Research', desc: 'Cutlio, Rezervo, Rezervacija — cijene i modeli' },
  { file: 'docs/04-flutter-tenant-factory.md', label: 'Tenant Factory', desc: 'Flavors, CI/CD, store submission, skaliranje' },
  { file: 'docs/05-vertical-packs.md', label: 'Vertikalni paketi', desc: 'Frizeri, beauty, zubari — terminologija i pravila' },
  { file: 'docs/06-auth-login-flow.md', label: 'Auth & Login Flow', desc: 'Apple, Google, Email OTP, Facebook — identity model' },
];

export function LandingPage() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-neutral-100">
      <div className="max-w-5xl mx-auto px-6 py-12">
        <div className="mb-12">
          <Badge variant="info">Faza 2 — wireframe prototip</Badge>
          <h1 className="text-4xl font-bold text-neutral-900 mt-4 mb-3">
            Salon Booking Platform
          </h1>
          <p className="text-xl text-neutral-600 max-w-2xl">
            Personalizovane native aplikacije za frizere, beauty salone, stomatološke
            ordinacije i ostale uslužne djelatnosti.
          </p>

          <div className="mt-6 p-5 rounded-xl bg-neutral-900 text-white">
            <p className="text-sm leading-relaxed">
              <strong className="font-semibold">Model:</strong> jedan Flutter codebase + jedan
              multi-tenant backend → N brandiranih aplikacija u storeovima. Novi klijent = novi
              flavor i config, ne novi projekat.
            </p>
            <p className="text-sm leading-relaxed mt-3 text-neutral-300">
              <strong className="font-semibold text-white">Stack:</strong> Flutter (client + admin)
              · Supabase (Postgres, RLS, Auth, cron) · Firebase FCM (samo push) · Next.js
              (super admin + politika privatnosti)
            </p>
          </div>

          <div className="mt-4 p-4 rounded-xl bg-amber-50 border border-amber-200">
            <p className="text-sm text-amber-900 leading-relaxed">
              <strong className="font-semibold">Ovo je React/web prototip za validaciju flowa,
              ne production kod.</strong>{' '}
              Produkt je Flutter. Mapiranje ekrana na Flutter screenove je u{' '}
              <code className="px-1.5 py-0.5 rounded bg-amber-100 text-xs">docs/02 §2</code>.
            </p>
          </div>
        </div>

        <div className="mb-12">
          <h2 className="text-xs font-semibold text-neutral-500 uppercase tracking-wide mb-3">
            Vertikale
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {verticals.map((v) => {
              const Icon = v.icon;
              return (
                <Card key={v.label} variant="bordered" className="p-4">
                  <div className="flex items-start gap-3">
                    <div
                      className={`w-9 h-9 rounded-lg flex items-center justify-center shrink-0 ${
                        v.active ? 'bg-neutral-900' : 'bg-neutral-200'
                      }`}
                    >
                      <Icon
                        className={`w-4 h-4 ${v.active ? 'text-white' : 'text-neutral-500'}`}
                      />
                    </div>
                    <div className="min-w-0">
                      <p className="font-medium text-sm text-neutral-900">{v.label}</p>
                      <p className="text-xs text-neutral-500 mt-0.5">{v.phase}</p>
                    </div>
                  </div>
                </Card>
              );
            })}
          </div>
        </div>

        <div className="space-y-6">
          {sections.map((section) => {
            const Icon = section.icon;
            return (
              <Card key={section.title} variant="bordered">
                <div className="p-6 border-b border-neutral-200">
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 rounded-lg bg-neutral-900 flex items-center justify-center shrink-0">
                      <Icon className="w-5 h-5 text-white" />
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center gap-2.5">
                        <h2 className="font-bold text-xl text-neutral-900">{section.title}</h2>
                        {section.branded ? (
                          <Badge variant="success">Brandirano</Badge>
                        ) : (
                          <Badge>Generičko</Badge>
                        )}
                      </div>
                      <p className="text-sm text-neutral-600 mt-1">{section.subtitle}</p>
                    </div>
                  </div>
                </div>

                <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-3">
                  {section.items.map((item) => {
                    const available = Boolean(item.path);
                    return (
                      <Card
                        key={item.name}
                        variant="bordered"
                        className={`p-4 transition-colors ${
                          available
                            ? 'hover:border-neutral-900 cursor-pointer'
                            : 'bg-neutral-50 opacity-70'
                        }`}
                        onClick={() => item.path && navigate(item.path)}
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className="min-w-0">
                            <div className="flex items-center gap-1.5">
                              {available ? (
                                <CheckCircle2 className="w-3.5 h-3.5 text-green-600 shrink-0" />
                              ) : (
                                <CircleDashed className="w-3.5 h-3.5 text-neutral-400 shrink-0" />
                              )}
                              <h3 className="font-medium text-sm text-neutral-900 truncate">
                                {item.name}
                              </h3>
                            </div>
                            <p className="text-xs text-neutral-600 mt-1.5 leading-relaxed">
                              {item.description}
                            </p>
                          </div>
                          {available && (
                            <ArrowRight className="w-4 h-4 text-neutral-400 shrink-0 mt-0.5" />
                          )}
                        </div>
                      </Card>
                    );
                  })}
                </div>
              </Card>
            );
          })}
        </div>

        <Card variant="bordered" className="mt-6">
          <div className="p-6 border-b border-neutral-200">
            <h2 className="font-bold text-xl text-neutral-900">Dokumentacija</h2>
            <p className="text-sm text-neutral-600 mt-1">
              Čitaj u ovom redoslijedu. Sve odluke su obrazložene.
            </p>
          </div>
          <div className="p-6 space-y-2">
            {docs.map((d) => (
              <div
                key={d.file}
                className="flex items-center justify-between gap-4 p-3 rounded-lg hover:bg-neutral-50"
              >
                <div className="min-w-0">
                  <p className="font-medium text-sm text-neutral-900">{d.label}</p>
                  <p className="text-xs text-neutral-600 mt-0.5">{d.desc}</p>
                </div>
                <code className="text-xs text-neutral-500 shrink-0 hidden sm:block">
                  {d.file}
                </code>
              </div>
            ))}
          </div>
        </Card>

        <Card variant="bordered" className="mt-6 p-6 bg-neutral-900 border-neutral-900">
          <h3 className="font-bold text-lg text-white mb-4">
            Tri odluke koje moraš znati prije prvog sastanka
          </h3>
          <div className="space-y-4 text-sm">
            <div>
              <p className="font-medium text-white">
                1. Rezervo prodaje isto za 25 EUR/mjesečno
              </p>
              <p className="text-neutral-300 mt-1 leading-relaxed">
                White-label app za frizere i zubare, bez ugovora, setup u 24h. Naš pricing je
                2–3× viši — treba mu obrazloženje: BiH lokalizacija, Viber, lokalna podrška.
                <span className="text-neutral-500"> → docs/03 §2.4</span>
              </p>
            </div>
            <div>
              <p className="font-medium text-white">
                2. Sve iOS app-e idu pod tvojim accountom — i to nosi tail risk
              </p>
              <p className="text-neutral-300 mt-1 leading-relaxed">
                Klijent ne otvara nikakav Apple nalog, kao kod Cutlia. Ali 4.2.6 i 4.3 (Spam)
                cilja N sličnih app-a — ponovljena odbijanja mogu ugasiti cijeli account.
                Disciplina diferencijacije nije kozmetika.
                <span className="text-neutral-500"> → docs/04 §6.2</span>
              </p>
            </div>
            <div>
              <p className="font-medium text-white">
                3. Zubari su najvrjedniji, ali ne prvi
              </p>
              <p className="text-neutral-300 mt-1 leading-relaxed">
                Izgubljeni sat vrijedi 80–300 KM protiv 15–25 KM kod frizera. Ali napomena
                pacijenta je zdravstveni podatak — traži pristanak, enkripciju i DPA.
                <span className="text-neutral-500"> → docs/05 §6–7</span>
              </p>
            </div>
          </div>
        </Card>

        <div className="mt-8 flex flex-wrap gap-3">
          <Button onClick={() => navigate('/s/barber-studio-vitez')}>
            Otvori client app
          </Button>
          <Button variant="outline" onClick={() => navigate('/admin/dashboard')}>
            Otvori admin
          </Button>
        </div>

        <p className="text-xs text-neutral-400 mt-8">
          Hamza Tuco · v4 native (Flutter) + auth · 20.08.2026.
        </p>
      </div>
    </div>
  );
}
