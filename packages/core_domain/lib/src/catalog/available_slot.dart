import 'package:meta/meta.dart';

import 'local_time.dart';

/// Jedan slobodan termin, tačno onako kako ga je vratio `get_available_slots` (task 05).
///
/// **Ovo je izlaz, ne ulaz u račun.** Baza je jedino mjesto koje zna radno vrijeme, pauze,
/// buffer, blokade i već zauzete termine; ovaj tip nosi gotov rezultat do ekrana i ništa
/// više. Zato ovdje nema nijedne metode koja slot pomjera, produžava, spaja sa sljedećim
/// ili poredi sa radnim vremenom — takva metoda bi bila druga implementacija availability
/// pravila, koja zastarijeva čim se pravilo promijeni u migraciji.
///
/// Ako ekranu zatreba nešto što ovaj tip nema, odgovor je nova kolona u RPC funkciji, ne
/// izračun u Dartu.
///
/// [employeeId] je **uvijek postavljen**, i kad korisnik nije birao radnika: funkcija tada
/// vrati po jedan red za svakog radnika koji je slobodan u to vrijeme, pa isti
/// [startTime] može doći više puta sa različitim radnikom. Ekran koji nudi "bilo koji"
/// zato slotove grupiše po vremenu — v. [AvailableSlotList.distinctTimes].
@immutable
class AvailableSlot {
  const AvailableSlot({required this.startTime, required this.employeeId});

  /// Mapira jedan red iz `get_available_slots`.
  ///
  /// Baca [FormatException] kad red nije očekivanog oblika — `core_api` ga hvata i
  /// pretvara u `MappingError`, kao i kod ostalih modela.
  factory AvailableSlot.fromJson(Map<String, dynamic> json) {
    final time = json['start_time'];
    final employee = json['employee_id'];
    if (time is! String) {
      throw FormatException('`start_time` nije string', json.toString());
    }
    if (employee is! String) {
      throw FormatException('`employee_id` nije string', json.toString());
    }
    return AvailableSlot(
      startTime: LocalTime.parse(time),
      employeeId: employee,
    );
  }

  /// Početak termina, zidno vrijeme salona — v. [LocalTime].
  final LocalTime startTime;

  /// Radnik koji je u to vrijeme slobodan. Nikad `null`: i u "bilo koji" modu funkcija
  /// vraća konkretnog radnika po redu.
  final String employeeId;

  @override
  bool operator ==(Object other) =>
      other is AvailableSlot &&
      other.startTime == startTime &&
      other.employeeId == employeeId;

  @override
  int get hashCode => Object.hash(startTime, employeeId);

  @override
  String toString() => 'AvailableSlot(${startTime.format()}, $employeeId)';
}

/// Grupisanje slotova za prikaz. Namjerno `extension`, ne metode na listi u repozitoriju:
/// ovo je prezentacija, ne availability logika.
extension AvailableSlotList on List<AvailableSlot> {
  /// Jedinstvena vremena, sortirana — lista koju vidi korisnik.
  ///
  /// Kad radnik nije izabran, isto vrijeme stiže jednom po slobodnom radniku; korisniku se
  /// prikazuje jedan chip po vremenu, a koga dobija odlučuje `book_appointment`.
  List<LocalTime> get distinctTimes {
    final times = map((slot) => slot.startTime).toSet().toList()..sort();
    return List.unmodifiable(times);
  }

  /// Radnici slobodni u zadanom vremenu, redoslijedom kojim ih je baza vratila.
  List<String> employeesAt(LocalTime time) => List.unmodifiable([
    for (final slot in this)
      if (slot.startTime == time) slot.employeeId,
  ]);
}
