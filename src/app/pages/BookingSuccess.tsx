import { useNavigate } from 'react-router';
import { Button } from '../components/Button';
import { Card } from '../components/Card';
import { CheckCircle2 } from 'lucide-react';

export function BookingSuccess() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-neutral-50">
      <div className="max-w-[390px] mx-auto bg-white min-h-screen">
        <div className="px-6 py-12">
          <div className="text-center mb-8">
            <div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-green-100 mb-6">
              <CheckCircle2 className="w-10 h-10 text-green-600" />
            </div>
            <h1 className="text-2xl font-bold text-neutral-900 mb-2">
              Zahtjev za termin je poslan
            </h1>
            <p className="text-neutral-600">
              Salon će uskoro potvrditi vaš termin.
            </p>
          </div>

          <Card variant="bordered" className="p-6 mb-8">
            <h2 className="font-medium text-neutral-900 mb-4">Detalji termina</h2>
            <div className="space-y-3">
              <div className="flex justify-between text-sm">
                <span className="text-neutral-600">Salon:</span>
                <span className="font-medium">Barber Studio Vitez</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-neutral-600">Usluga:</span>
                <span className="font-medium">Fade šišanje</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-neutral-600">Radnik:</span>
                <span className="font-medium">Emir</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-neutral-600">Datum:</span>
                <span className="font-medium">UTO 20.05.2026</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-neutral-600">Vrijeme:</span>
                <span className="font-medium">14:00</span>
              </div>
              <div className="pt-3 border-t border-neutral-200 flex justify-between">
                <span className="font-medium">Cijena:</span>
                <span className="font-bold">20 KM</span>
              </div>
            </div>
          </Card>

          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <p className="text-sm text-blue-900">
              Primit ćete SMS potvrdu kada salon potvrdi vaš termin. Možete otkazati termin najkasnije 24 sata prije zakazanog vremena.
            </p>
          </div>
        </div>

        <div className="fixed bottom-0 left-0 right-0 p-6 bg-white border-t border-neutral-200 max-w-[390px] mx-auto">
          <Button
            fullWidth
            size="lg"
            onClick={() => navigate('/s/barber-studio-vitez')}
          >
            Nazad na salon
          </Button>
        </div>
      </div>
    </div>
  );
}
