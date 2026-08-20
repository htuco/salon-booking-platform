import { useState } from 'react';
import { Card } from '../components/Card';
import { Button } from '../components/Button';
import { Input } from '../components/Input';
import { Select } from '../components/Select';
import { ArrowLeft, Upload, Check } from 'lucide-react';
import { useNavigate } from 'react-router';

const themes = [
  {
    id: 'modern-barber',
    name: 'Modern Barber',
    description: 'Dark, premium barber shop style',
    preview: 'bg-neutral-900 text-white',
  },
  {
    id: 'elegant-beauty',
    name: 'Elegant Beauty',
    description: 'Light, elegant beauty salon style',
    preview: 'bg-white border-2 border-neutral-200 text-neutral-900',
  },
];

export function SuperAdminCreateSalon() {
  const navigate = useNavigate();
  const [selectedTheme, setSelectedTheme] = useState<string>('');
  const [formData, setFormData] = useState({
    salonName: '',
    slug: '',
    city: '',
    address: '',
    phone: '',
    primaryColor: '#171717',
    secondaryColor: '#f59e0b',
    adminName: '',
    adminEmail: '',
    tempPassword: '',
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    console.log('Creating salon:', { ...formData, theme: selectedTheme });
  };

  return (
    <div className="min-h-screen bg-neutral-50">
      <div className="max-w-4xl mx-auto p-8">
        <div className="mb-8">
          <button
            onClick={() => navigate('/super-admin/salons')}
            className="flex items-center gap-2 text-neutral-600 hover:text-neutral-900 mb-4"
          >
            <ArrowLeft className="w-4 h-4" />
            Nazad
          </button>
          <h1 className="text-3xl font-bold text-neutral-900">Kreiraj novi salon</h1>
          <p className="text-neutral-600 mt-1">Popunite informacije o novom salonu</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <Card variant="bordered">
            <div className="p-6 border-b border-neutral-200">
              <h2 className="font-bold text-xl text-neutral-900">Osnovne informacije</h2>
            </div>
            <div className="p-6 space-y-4">
              <Input
                label="Naziv salona"
                placeholder="npr. Barber Studio Vitez"
                value={formData.salonName}
                onChange={(e) => setFormData({ ...formData, salonName: e.target.value })}
                required
              />
              <Input
                label="Slug (URL)"
                placeholder="barber-studio-vitez"
                value={formData.slug}
                onChange={(e) => setFormData({ ...formData, slug: e.target.value })}
                required
              />
              <div className="grid grid-cols-2 gap-4">
                <Input
                  label="Grad"
                  placeholder="Vitez"
                  value={formData.city}
                  onChange={(e) => setFormData({ ...formData, city: e.target.value })}
                  required
                />
                <Input
                  label="Adresa"
                  placeholder="Trg Slobode 15"
                  value={formData.address}
                  onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                  required
                />
              </div>
              <Input
                label="Telefon"
                type="tel"
                placeholder="+387 62 123 456"
                value={formData.phone}
                onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                required
              />
            </div>
          </Card>

          <Card variant="bordered">
            <div className="p-6 border-b border-neutral-200">
              <h2 className="font-bold text-xl text-neutral-900">Branding</h2>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-2">
                  Logo
                </label>
                <div className="border-2 border-dashed border-neutral-300 rounded-lg p-8 text-center hover:border-neutral-400 cursor-pointer">
                  <Upload className="w-8 h-8 text-neutral-400 mx-auto mb-2" />
                  <p className="text-sm text-neutral-600">Kliknite ili povucite sliku</p>
                  <p className="text-xs text-neutral-500 mt-1">PNG, JPG do 2MB</p>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-neutral-700 mb-2">
                  Cover slika
                </label>
                <div className="border-2 border-dashed border-neutral-300 rounded-lg p-8 text-center hover:border-neutral-400 cursor-pointer">
                  <Upload className="w-8 h-8 text-neutral-400 mx-auto mb-2" />
                  <p className="text-sm text-neutral-600">Kliknite ili povucite sliku</p>
                  <p className="text-xs text-neutral-500 mt-1">PNG, JPG do 5MB, preporučeno 1920x600px</p>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-neutral-700 mb-2">
                    Primarna boja
                  </label>
                  <div className="flex gap-2">
                    <input
                      type="color"
                      value={formData.primaryColor}
                      onChange={(e) => setFormData({ ...formData, primaryColor: e.target.value })}
                      className="w-16 h-10 rounded border border-neutral-300"
                    />
                    <Input
                      value={formData.primaryColor}
                      onChange={(e) => setFormData({ ...formData, primaryColor: e.target.value })}
                      className="flex-1"
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-medium text-neutral-700 mb-2">
                    Sekundarna boja
                  </label>
                  <div className="flex gap-2">
                    <input
                      type="color"
                      value={formData.secondaryColor}
                      onChange={(e) => setFormData({ ...formData, secondaryColor: e.target.value })}
                      className="w-16 h-10 rounded border border-neutral-300"
                    />
                    <Input
                      value={formData.secondaryColor}
                      onChange={(e) => setFormData({ ...formData, secondaryColor: e.target.value })}
                      className="flex-1"
                    />
                  </div>
                </div>
              </div>
            </div>
          </Card>

          <Card variant="bordered">
            <div className="p-6 border-b border-neutral-200">
              <h2 className="font-bold text-xl text-neutral-900">Tema</h2>
            </div>
            <div className="p-6">
              <div className="grid grid-cols-2 gap-4">
                {themes.map((theme) => (
                  <div
                    key={theme.id}
                    onClick={() => setSelectedTheme(theme.id)}
                    className={`relative border-2 rounded-lg p-6 cursor-pointer transition-all ${
                      selectedTheme === theme.id
                        ? 'border-neutral-900 bg-neutral-50'
                        : 'border-neutral-200 hover:border-neutral-400'
                    }`}
                  >
                    {selectedTheme === theme.id && (
                      <div className="absolute top-3 right-3 w-6 h-6 rounded-full bg-neutral-900 flex items-center justify-center">
                        <Check className="w-4 h-4 text-white" />
                      </div>
                    )}
                    <div className={`w-full h-32 rounded-lg mb-4 flex items-center justify-center ${theme.preview}`}>
                      <span className="font-bold">Preview</span>
                    </div>
                    <h3 className="font-bold text-neutral-900">{theme.name}</h3>
                    <p className="text-sm text-neutral-600 mt-1">{theme.description}</p>
                  </div>
                ))}
              </div>
            </div>
          </Card>

          <Card variant="bordered">
            <div className="p-6 border-b border-neutral-200">
              <h2 className="font-bold text-xl text-neutral-900">Admin korisnik</h2>
            </div>
            <div className="p-6 space-y-4">
              <Input
                label="Ime i prezime"
                placeholder="Emir Hodžić"
                value={formData.adminName}
                onChange={(e) => setFormData({ ...formData, adminName: e.target.value })}
                required
              />
              <Input
                label="Email"
                type="email"
                placeholder="admin@barberstudio.ba"
                value={formData.adminEmail}
                onChange={(e) => setFormData({ ...formData, adminEmail: e.target.value })}
                required
              />
              <Input
                label="Privremena lozinka"
                type="password"
                placeholder="********"
                value={formData.tempPassword}
                onChange={(e) => setFormData({ ...formData, tempPassword: e.target.value })}
                required
              />
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <p className="text-sm text-blue-900">
                  Admin će dobiti email sa uputstvima za prijavu i promjenu lozinke.
                </p>
              </div>
            </div>
          </Card>

          <div className="flex gap-3 justify-end">
            <Button variant="outline" onClick={() => navigate('/super-admin/salons')}>
              Otkaži
            </Button>
            <Button type="submit" variant="primary">
              Kreiraj salon
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
