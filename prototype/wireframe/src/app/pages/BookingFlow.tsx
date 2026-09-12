import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { Button } from '../components/Button';
import { Card } from '../components/Card';
import { Input } from '../components/Input';
import { Textarea } from '../components/Textarea';
import { ArrowLeft, Check } from 'lucide-react';

const services = [
  { id: '1', name: 'Muško šišanje', duration: '30 min', price: '15 KM', category: 'Šišanje' },
  { id: '2', name: 'Fade šišanje', duration: '40 min', price: '20 KM', category: 'Šišanje' },
  { id: '3', name: 'Šišanje + brada', duration: '45 min', price: '25 KM', category: 'Šišanje' },
  { id: '4', name: 'Uređivanje brade', duration: '20 min', price: '10 KM', category: 'Brada' },
];

const employees = [
  { id: 'any', name: 'Bilo koji dostupan', role: '' },
  { id: '1', name: 'Emir', role: 'Barber' },
  { id: '2', name: 'Amar', role: 'Barber' },
];

const dates = [
  { date: '2026-05-19', day: 'PON', dayNum: '19' },
  { date: '2026-05-20', day: 'UTO', dayNum: '20' },
  { date: '2026-05-21', day: 'SRI', dayNum: '21' },
  { date: '2026-05-22', day: 'ČET', dayNum: '22' },
  { date: '2026-05-23', day: 'PET', dayNum: '23' },
  { date: '2026-05-24', day: 'SUB', dayNum: '24' },
];

const timeSlots = {
  morning: ['09:00', '09:30', '10:00', '10:30', '11:00', '11:30'],
  afternoon: ['14:00', '14:30', '15:00', '15:30', '16:00', '16:30', '17:00', '17:30'],
};

export function BookingFlow() {
  const { step, slug = 'barber-studio-vitez' } = useParams();
  const navigate = useNavigate();
  const [selectedService, setSelectedService] = useState<string>('');
  const [selectedEmployee, setSelectedEmployee] = useState<string>('');
  const [selectedDate, setSelectedDate] = useState<string>('');
  const [selectedTime, setSelectedTime] = useState<string>('');
  const [formData, setFormData] = useState({ note: '' });

  const handleBack = () => {
    if (step === 'service') navigate(`/s/${slug}`);
    else if (step === 'employee') navigate(`/s/${slug}/book/service`);
    else if (step === 'datetime') navigate(`/s/${slug}/book/employee`);
    else if (step === 'details') navigate(`/s/${slug}/auth/login`);
  };

  const handleContinue = () => {
    if (step === 'service') navigate(`/s/${slug}/book/employee`);
    else if (step === 'employee') navigate(`/s/${slug}/book/datetime`);
    else if (step === 'datetime') navigate(`/s/${slug}/auth/login`);
    else if (step === 'details') navigate(`/s/${slug}/book/success`);
  };

  const isValid = () => {
    if (step === 'service') return selectedService !== '';
    if (step === 'employee') return selectedEmployee !== '';
    if (step === 'datetime') return selectedDate !== '' && selectedTime !== '';
    if (step === 'details') return true;
    return false;
  };

  const getStepNumber = () => {
    if (step === 'service') return 1;
    if (step === 'employee') return 2;
    if (step === 'datetime') return 3;
    if (step === 'details') return 4;
    return 1;
  };

  const selectedServiceData = services.find(s => s.id === selectedService);
  const selectedEmployeeData = employees.find(e => e.id === selectedEmployee);
  const selectedDateData = dates.find(d => d.date === selectedDate);

  return (
    <div className="min-h-screen bg-neutral-50">
      <div className="max-w-[390px] mx-auto bg-white min-h-screen pb-24">
        <div className="sticky top-0 bg-white border-b border-neutral-200 px-6 py-4">
          <div className="flex items-center gap-4 mb-4">
            <button onClick={handleBack} className="p-2 -ml-2 hover:bg-neutral-100 rounded-lg">
              <ArrowLeft className="w-5 h-5" />
            </button>
            <div className="flex-1">
              <div className="flex gap-2">
                {[1, 2, 3, 4].map((num) => (
                  <div
                    key={num}
                    className={`h-1 flex-1 rounded-full ${
                      num <= getStepNumber() ? 'bg-neutral-900' : 'bg-neutral-200'
                    }`}
                  />
                ))}
              </div>
            </div>
          </div>
        </div>

        <div className="px-6 py-6">
          {step === 'service' && (
            <>
              <h1 className="text-2xl font-bold text-neutral-900 mb-6">Izaberite uslugu</h1>

              <div className="mb-4">
                <h3 className="text-sm font-medium text-neutral-600 mb-3">Šišanje</h3>
                <div className="space-y-3">
                  {services.filter(s => s.category === 'Šišanje').map((service) => (
                    <Card
                      key={service.id}
                      variant="bordered"
                      className={`p-4 cursor-pointer transition-all ${
                        selectedService === service.id
                          ? 'border-neutral-900 bg-neutral-50'
                          : 'hover:border-neutral-400'
                      }`}
                      onClick={() => setSelectedService(service.id)}
                    >
                      <div className="flex justify-between items-start">
                        <div className="flex-1">
                          <h3 className="font-medium text-neutral-900">{service.name}</h3>
                          <p className="text-sm text-neutral-500 mt-1">{service.duration}</p>
                        </div>
                        <div className="flex items-center gap-3">
                          <span className="font-bold text-neutral-900">{service.price}</span>
                          {selectedService === service.id && (
                            <div className="w-5 h-5 rounded-full bg-neutral-900 flex items-center justify-center">
                              <Check className="w-3 h-3 text-white" />
                            </div>
                          )}
                        </div>
                      </div>
                    </Card>
                  ))}
                </div>
              </div>

              <div>
                <h3 className="text-sm font-medium text-neutral-600 mb-3">Brada</h3>
                <div className="space-y-3">
                  {services.filter(s => s.category === 'Brada').map((service) => (
                    <Card
                      key={service.id}
                      variant="bordered"
                      className={`p-4 cursor-pointer transition-all ${
                        selectedService === service.id
                          ? 'border-neutral-900 bg-neutral-50'
                          : 'hover:border-neutral-400'
                      }`}
                      onClick={() => setSelectedService(service.id)}
                    >
                      <div className="flex justify-between items-start">
                        <div className="flex-1">
                          <h3 className="font-medium text-neutral-900">{service.name}</h3>
                          <p className="text-sm text-neutral-500 mt-1">{service.duration}</p>
                        </div>
                        <div className="flex items-center gap-3">
                          <span className="font-bold text-neutral-900">{service.price}</span>
                          {selectedService === service.id && (
                            <div className="w-5 h-5 rounded-full bg-neutral-900 flex items-center justify-center">
                              <Check className="w-3 h-3 text-white" />
                            </div>
                          )}
                        </div>
                      </div>
                    </Card>
                  ))}
                </div>
              </div>
            </>
          )}

          {step === 'employee' && (
            <>
              <h1 className="text-2xl font-bold text-neutral-900 mb-6">Izaberite radnika</h1>
              <div className="space-y-3">
                {employees.map((employee) => (
                  <Card
                    key={employee.id}
                    variant="bordered"
                    className={`p-4 cursor-pointer transition-all ${
                      selectedEmployee === employee.id
                        ? 'border-neutral-900 bg-neutral-50'
                        : 'hover:border-neutral-400'
                    }`}
                    onClick={() => setSelectedEmployee(employee.id)}
                  >
                    <div className="flex items-center gap-4">
                      <div className="w-12 h-12 rounded-full bg-neutral-200 flex-shrink-0"></div>
                      <div className="flex-1">
                        <h3 className="font-medium text-neutral-900">{employee.name}</h3>
                        {employee.role && (
                          <p className="text-sm text-neutral-500">{employee.role}</p>
                        )}
                      </div>
                      {selectedEmployee === employee.id && (
                        <div className="w-5 h-5 rounded-full bg-neutral-900 flex items-center justify-center">
                          <Check className="w-3 h-3 text-white" />
                        </div>
                      )}
                    </div>
                  </Card>
                ))}
              </div>
            </>
          )}

          {step === 'datetime' && (
            <>
              <h1 className="text-2xl font-bold text-neutral-900 mb-6">Izaberite datum i vrijeme</h1>

              <div className="mb-6">
                <div className="flex gap-2 overflow-x-auto pb-2 -mx-1 px-1">
                  {dates.map((dateObj) => (
                    <button
                      key={dateObj.date}
                      onClick={() => setSelectedDate(dateObj.date)}
                      className={`flex-shrink-0 w-16 py-3 rounded-lg text-center transition-all ${
                        selectedDate === dateObj.date
                          ? 'bg-neutral-900 text-white'
                          : 'bg-neutral-100 text-neutral-700 hover:bg-neutral-200'
                      }`}
                    >
                      <div className="text-xs mb-1">{dateObj.day}</div>
                      <div className="text-lg font-bold">{dateObj.dayNum}</div>
                    </button>
                  ))}
                </div>
              </div>

              {selectedDate ? (
                <>
                  <div className="mb-6">
                    <h3 className="text-sm font-medium text-neutral-600 mb-3">Prijepodne</h3>
                    <div className="grid grid-cols-3 gap-2">
                      {timeSlots.morning.map((time) => (
                        <button
                          key={time}
                          onClick={() => setSelectedTime(time)}
                          className={`py-3 rounded-lg text-sm font-medium transition-all ${
                            selectedTime === time
                              ? 'bg-neutral-900 text-white'
                              : 'bg-neutral-100 text-neutral-700 hover:bg-neutral-200'
                          }`}
                        >
                          {time}
                        </button>
                      ))}
                    </div>
                  </div>

                  <div>
                    <h3 className="text-sm font-medium text-neutral-600 mb-3">Poslije podne</h3>
                    <div className="grid grid-cols-3 gap-2">
                      {timeSlots.afternoon.map((time) => (
                        <button
                          key={time}
                          onClick={() => setSelectedTime(time)}
                          className={`py-3 rounded-lg text-sm font-medium transition-all ${
                            selectedTime === time
                              ? 'bg-neutral-900 text-white'
                              : 'bg-neutral-100 text-neutral-700 hover:bg-neutral-200'
                          }`}
                        >
                          {time}
                        </button>
                      ))}
                    </div>
                  </div>
                </>
              ) : (
                <div className="py-12 text-center text-neutral-500">
                  Izaberite datum da vidite dostupne termine
                </div>
              )}
            </>
          )}

          {step === 'details' && (
            <>
              <h1 className="text-2xl font-bold text-neutral-900 mb-6">Vaši podaci</h1>

              <Card variant="bordered" className="p-4 mb-6">
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span className="text-neutral-600">Usluga:</span>
                    <span className="font-medium">{selectedServiceData?.name}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-neutral-600">Radnik:</span>
                    <span className="font-medium">{selectedEmployeeData?.name}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-neutral-600">Datum:</span>
                    <span className="font-medium">{selectedDateData?.day} {selectedDateData?.dayNum}.05.2026</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-neutral-600">Vrijeme:</span>
                    <span className="font-medium">{selectedTime}</span>
                  </div>
                  <div className="pt-2 border-t border-neutral-200 flex justify-between">
                    <span className="font-medium">Cijena:</span>
                    <span className="font-bold">{selectedServiceData?.price}</span>
                  </div>
                </div>
              </Card>

              <div className="space-y-4">
                <Card variant="bordered" className="p-4 bg-neutral-50">
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-10 h-10 rounded-full bg-neutral-200 flex items-center justify-center shrink-0">
                        <span className="text-sm font-medium text-neutral-600">AK</span>
                      </div>
                      <div className="min-w-0">
                        <p className="font-medium text-sm text-neutral-900">Adnan Kovač</p>
                        <p className="text-xs text-neutral-600 truncate">adnan@email.ba</p>
                      </div>
                    </div>
                    <button
                      onClick={() => navigate(`/s/${slug}/account`)}
                      className="text-xs font-medium text-neutral-700 underline shrink-0"
                    >
                      Uredi
                    </button>
                  </div>
                </Card>

                <Textarea
                  label="Napomena (opcionalno)"
                  placeholder="Dodatne napomene ili želje..."
                  rows={3}
                  value={formData.note}
                  onChange={(e) => setFormData({ note: e.target.value })}
                />

                <p className="text-xs text-neutral-500 leading-relaxed">
                  Ne tražimo broj telefona — potvrdu i podsjetnike dobijate kao
                  obavijest u aplikaciji.
                </p>
              </div>
            </>
          )}
        </div>

        <div className="fixed bottom-0 left-0 right-0 p-6 bg-white border-t border-neutral-200 max-w-[390px] mx-auto">
          <Button
            fullWidth
            size="lg"
            disabled={!isValid()}
            onClick={handleContinue}
          >
            {step === 'details' ? 'Pošalji zahtjev' : 'Nastavi'}
          </Button>
        </div>
      </div>
    </div>
  );
}
