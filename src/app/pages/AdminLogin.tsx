import { useNavigate } from 'react-router';
import { Button } from '../components/Button';
import { Card } from '../components/Card';
import { Input } from '../components/Input';
import { Phone, Scissors } from 'lucide-react';

export function AdminLogin() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-neutral-100 flex items-center justify-center p-6">
      <div className="w-full max-w-[390px]">
        <div className="text-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-neutral-900 mx-auto mb-5 flex items-center justify-center">
            <Scissors className="w-7 h-7 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-neutral-900">Salon Admin</h1>
          <p className="text-sm text-neutral-600 mt-1.5">
            Prijavite se na svoj salon
          </p>
        </div>

        <Card variant="bordered" className="p-6 space-y-5">
          <Input
            label="Email"
            type="email"
            placeholder="emir@barberstudiovitez.ba"
            defaultValue="emir@barberstudiovitez.ba"
          />
          <Input
            label="Lozinka"
            type="password"
            placeholder="••••••••••"
            defaultValue="demolozinka"
          />

          <label className="flex items-center gap-2.5 cursor-pointer">
            <input
              type="checkbox"
              defaultChecked
              className="w-4 h-4 rounded border-neutral-300 accent-neutral-900"
            />
            <span className="text-sm text-neutral-700">Zapamti me</span>
          </label>

          <Button fullWidth size="lg" onClick={() => navigate('/admin/dashboard')}>
            Prijavi se
          </Button>

          <button className="w-full text-sm text-neutral-600 hover:text-neutral-900">
            Zaboravili ste lozinku?
          </button>
        </Card>

        <div className="mt-6 pt-6 border-t border-neutral-200 text-center">
          <p className="text-sm text-neutral-600 mb-2">Nemate salon?</p>
          <a
            href="tel:+38700000000"
            className="inline-flex items-center gap-1.5 text-sm font-medium text-neutral-900"
          >
            <Phone className="w-4 h-4" />
            Kontaktirajte nas
          </a>
        </div>

        <p className="text-xs text-neutral-400 text-center mt-8">
          Jedna admin aplikacija za sve salone — generička, ne brandirana.
        </p>
      </div>
    </div>
  );
}
