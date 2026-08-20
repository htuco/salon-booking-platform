import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { Button } from '../components/Button';
import { Card } from '../components/Card';
import { Badge } from '../components/Badge';
import { ArrowLeft, Apple, LogOut, Trash2, AlertTriangle } from 'lucide-react';

export function ClientAccount() {
  const navigate = useNavigate();
  const { slug = 'barber-studio-vitez' } = useParams();
  const [confirmDelete, setConfirmDelete] = useState(false);

  return (
    <div className="min-h-screen bg-neutral-100">
      <div className="max-w-[390px] mx-auto bg-white min-h-screen">
        <div className="px-6 pt-6 pb-4 border-b border-neutral-200">
          <button
            onClick={() => navigate(`/s/${slug}`)}
            className="flex items-center gap-1.5 text-sm text-neutral-600 mb-4"
          >
            <ArrowLeft className="w-4 h-4" />
            Nazad
          </button>
          <h1 className="text-2xl font-bold text-neutral-900">Moj račun</h1>
        </div>

        <div className="p-6 space-y-6">
          <Card variant="bordered" className="p-5">
            <div className="flex items-center gap-4">
              <div className="w-14 h-14 rounded-full bg-neutral-200 flex items-center justify-center shrink-0">
                <span className="font-medium text-neutral-600">AK</span>
              </div>
              <div className="min-w-0">
                <p className="font-medium text-neutral-900">Adnan Kovač</p>
                <p className="text-sm text-neutral-600">adnan@email.ba</p>
              </div>
            </div>

            <div className="mt-5 pt-5 border-t border-neutral-100 space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-sm text-neutral-600">Email</span>
                <span className="text-sm text-neutral-900">adnan@email.ba</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-neutral-600">Prijava</span>
                <span className="flex items-center gap-1.5 text-sm text-neutral-900">
                  <Apple className="w-4 h-4" />
                  Apple
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-neutral-600">Obavijesti</span>
                <Badge variant="success">Uključene</Badge>
              </div>
            </div>

            <Button variant="outline" size="sm" fullWidth className="mt-5">
              Uredi podatke
            </Button>
          </Card>

          <Card variant="bordered" className="p-5">
            <h2 className="font-medium text-neutral-900 mb-1">Privatnost</h2>
            <p className="text-sm text-neutral-600 mb-4 leading-relaxed">
              Vaši podaci su vidljivi samo ovom salonu.
            </p>
            <div className="space-y-2">
              <button className="block text-sm text-neutral-700 underline">
                Politika privatnosti
              </button>
              <button className="block text-sm text-neutral-700 underline">
                Uslovi korištenja
              </button>
            </div>
          </Card>

          <Button variant="outline" fullWidth>
            <LogOut className="w-4 h-4 mr-2" />
            Odjavi se
          </Button>

          <Card variant="bordered" className="p-5 border-red-200">
            {!confirmDelete ? (
              <>
                <h2 className="font-medium text-neutral-900 mb-1">Izbriši račun</h2>
                <p className="text-sm text-neutral-600 mb-4 leading-relaxed">
                  Trajno briše vaše podatke i historiju termina.
                </p>
                <Button variant="danger" fullWidth onClick={() => setConfirmDelete(true)}>
                  <Trash2 className="w-4 h-4 mr-2" />
                  Izbriši račun
                </Button>
              </>
            ) : (
              <>
                <div className="flex items-start gap-2.5 mb-4">
                  <AlertTriangle className="w-5 h-5 text-red-600 shrink-0 mt-0.5" />
                  <div>
                    <h2 className="font-medium text-neutral-900 mb-1.5">
                      Sigurno želite izbrisati račun?
                    </h2>
                    <p className="text-sm text-neutral-600 leading-relaxed">
                      Brišu se: ime, email i historija termina. Budući potvrđeni
                      termini se otkazuju i salon se obavještava. Ovo se ne može vratiti.
                    </p>
                  </div>
                </div>
                <div className="flex gap-2">
                  <Button variant="outline" fullWidth onClick={() => setConfirmDelete(false)}>
                    Odustani
                  </Button>
                  <Button variant="danger" fullWidth>
                    Da, izbriši
                  </Button>
                </div>
              </>
            )}
          </Card>

          <Card variant="bordered" className="p-4 bg-amber-50 border-amber-200">
            <p className="text-xs text-amber-900 leading-relaxed">
              <strong>Ovaj ekran je obavezan.</strong> Apple i Google zahtijevaju brisanje
              računa iz same aplikacije. Bez njega iOS submission pada. Vidi docs/06 §8.2.
            </p>
          </Card>
        </div>
      </div>
    </div>
  );
}
