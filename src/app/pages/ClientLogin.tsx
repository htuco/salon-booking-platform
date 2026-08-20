import { useState } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router';
import { Button } from '../components/Button';
import { Card } from '../components/Card';
import { Input } from '../components/Input';
import { ArrowLeft, Apple, Mail, User } from 'lucide-react';

type Platform = 'ios' | 'android';
type Screen = 'providers' | 'email' | 'otp';

// allowGuestBooking iz SalonSettings — default off, vidi docs/06 §5
const ALLOW_GUEST = true;

export function ClientLogin() {
  const navigate = useNavigate();
  const { slug = 'barber-studio-vitez' } = useParams();
  const [params, setParams] = useSearchParams();

  const platform = (params.get('platform') as Platform) || 'ios';
  const screen = (params.get('screen') as Screen) || 'providers';
  const [email, setEmail] = useState('adnan@email.ba');

  const go = (next: Screen) => {
    params.set('screen', next);
    setParams(params);
  };

  const setPlatform = (p: Platform) => {
    params.set('platform', p);
    setParams(params);
  };

  const finish = () => navigate(`/s/${slug}/book/details`);

  return (
    <div className="min-h-screen bg-neutral-100">
      <div className="max-w-[390px] mx-auto bg-white min-h-screen relative">
        {/* Demo prekidač platforme — nije dio proizvoda */}
        <div className="absolute top-0 left-0 right-0 flex gap-1 p-2 bg-amber-50 border-b border-amber-200">
          <span className="text-[10px] text-amber-800 px-1.5 py-1">Demo:</span>
          {(['ios', 'android'] as Platform[]).map((p) => (
            <button
              key={p}
              onClick={() => setPlatform(p)}
              className={`text-[10px] px-2 py-1 rounded ${
                platform === p ? 'bg-amber-900 text-white' : 'text-amber-800'
              }`}
            >
              {p === 'ios' ? 'iOS' : 'Android'}
            </button>
          ))}
        </div>

        <div className="pt-14 px-6 pb-8">
          <button
            onClick={() =>
              screen === 'providers'
                ? navigate(`/s/${slug}/book/datetime`)
                : go('providers')
            }
            className="flex items-center gap-1.5 text-sm text-neutral-600 mb-8"
          >
            <ArrowLeft className="w-4 h-4" />
            Nazad
          </button>

          {screen === 'providers' && (
            <>
              <div className="text-center mb-8">
                <div className="w-16 h-16 rounded-full bg-neutral-900 mx-auto mb-5 flex items-center justify-center">
                  <span className="text-white text-xs font-medium">LOGO</span>
                </div>
                <h1 className="text-2xl font-bold text-neutral-900">Još jedan korak</h1>
                <p className="text-sm text-neutral-600 mt-2 leading-relaxed">
                  Prijavite se da sačuvamo vaš termin i pošaljemo potvrdu.
                </p>
              </div>

              <Card variant="bordered" className="p-4 mb-8 bg-neutral-50">
                <p className="text-sm font-medium text-neutral-900">Fade šišanje · Emir</p>
                <p className="text-sm text-neutral-600 mt-0.5">Srijeda, 20.05. u 14:30</p>
              </Card>

              <div className="space-y-2.5">
                {platform === 'ios' && (
                  <button
                    onClick={finish}
                    className="w-full flex items-center justify-center gap-2.5 py-3.5 rounded-lg bg-neutral-900 text-white font-medium hover:bg-neutral-800 transition-colors"
                  >
                    <Apple className="w-5 h-5" />
                    Nastavi sa Apple
                  </button>
                )}

                <button
                  onClick={finish}
                  className="w-full flex items-center justify-center gap-2.5 py-3.5 rounded-lg border-2 border-neutral-200 font-medium text-neutral-900 hover:bg-neutral-50 transition-colors"
                >
                  <span className="w-5 h-5 rounded-full bg-white border border-neutral-300 flex items-center justify-center text-xs font-bold text-blue-600">
                    G
                  </span>
                  Nastavi sa Google
                </button>

                <button
                  onClick={finish}
                  className="w-full flex items-center justify-center gap-2.5 py-3.5 rounded-lg border-2 border-neutral-200 font-medium text-neutral-900 hover:bg-neutral-50 transition-colors"
                >
                  <span className="w-5 h-5 rounded bg-[#1877F2] text-white flex items-center justify-center text-xs font-bold">
                    f
                  </span>
                  Nastavi sa Facebook
                </button>

                <button
                  onClick={() => go('email')}
                  className="w-full flex items-center justify-center gap-2.5 py-3.5 rounded-lg border-2 border-neutral-200 font-medium text-neutral-900 hover:bg-neutral-50 transition-colors"
                >
                  <Mail className="w-5 h-5 text-neutral-500" />
                  Nastavi sa emailom
                </button>
              </div>

              {ALLOW_GUEST && (
                <>
                  <div className="flex items-center gap-3 my-6">
                    <div className="flex-1 h-px bg-neutral-200" />
                    <span className="text-xs text-neutral-400">ili</span>
                    <div className="flex-1 h-px bg-neutral-200" />
                  </div>
                  <button
                    onClick={finish}
                    className="w-full flex items-center justify-center gap-2 py-3 text-sm font-medium text-neutral-600 hover:text-neutral-900"
                  >
                    <User className="w-4 h-4" />
                    Nastavi kao gost
                  </button>
                </>
              )}

              <p className="text-xs text-neutral-400 text-center mt-8 leading-relaxed">
                Prijavom prihvatate Uslove korištenja i Politiku privatnosti.
              </p>

              <Card variant="bordered" className="mt-6 p-4 bg-blue-50 border-blue-200">
                <p className="text-xs text-blue-900 leading-relaxed">
                  <strong>Ovo je posljednji ekran prije potvrde.</strong> Ne tražimo broj
                  telefona — push zamjenjuje poziv i SMS. Vidi docs/06 §3.1.
                </p>
                <p className="text-xs text-blue-900 leading-relaxed mt-2">
                  <strong>Facebook je iza flaga</strong> — default off. Metina bundle politika
                  je nejasna za white-label. Vidi docs/06 §7.4.
                </p>
              </Card>
            </>
          )}

          {screen === 'email' && (
            <>
              <h1 className="text-2xl font-bold text-neutral-900 mb-2">Vaš email</h1>
              <p className="text-sm text-neutral-600 mb-8">
                Poslat ćemo vam 6-cifreni kod. Bez lozinke.
              </p>

              <Input
                label="Email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />

              <Button fullWidth size="lg" className="mt-6" onClick={() => go('otp')}>
                Pošalji kod
              </Button>
            </>
          )}

          {screen === 'otp' && (
            <>
              <h1 className="text-2xl font-bold text-neutral-900 mb-2">Unesite kod</h1>
              <p className="text-sm text-neutral-600 mb-8">
                Poslali smo kod na <span className="font-medium">{email}</span>
              </p>

              <div className="flex gap-2 justify-between mb-8">
                {['4', '8', '1', '2', '', ''].map((d, i) => (
                  <div
                    key={i}
                    className={`w-12 h-14 rounded-lg border-2 flex items-center justify-center text-xl font-medium ${
                      d
                        ? 'border-neutral-900 text-neutral-900'
                        : i === 4
                          ? 'border-neutral-900'
                          : 'border-neutral-200'
                    }`}
                  >
                    {d}
                  </div>
                ))}
              </div>

              <Button fullWidth size="lg" onClick={finish}>
                Potvrdi
              </Button>

              <p className="text-sm text-neutral-500 text-center mt-6">
                Nisam dobio kod — pošalji ponovo
                <span className="block text-xs text-neutral-400 mt-0.5">
                  dostupno za 42s
                </span>
              </p>
            </>
          )}

        </div>
      </div>
    </div>
  );
}
