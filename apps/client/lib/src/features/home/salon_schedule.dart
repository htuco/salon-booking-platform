import 'package:core_domain/core_domain.dart';

/// Radno vrijeme salona pripremljeno za prikaz: trenutni status i sažeta sedmica.
///
/// Postoji kao zasebna klasa, a ne kao logika u `build` metodi, jer je ovo jedini
/// dio home ekrana koji ima stvarna pravila — sve ostalo je raspoređivanje podataka.
/// `docs/02 §3` traži da "Otvoreno do 20:00" bude **izračunato iz `WorkingHour`**, ne
/// napisano rukom; izračun koji stoji u widgetu se ne može testirati bez `pumpWidget`,
/// pa se u praksi ne testira.
///
/// Gleda samo redove salona (`isSalonWide`). Redovi po radniku opisuju kad radi jedan
/// zaposlenik, što nije isto što i kad je salon otvoren — radnik može imati slobodan dan
/// dok salon radi.
class SalonSchedule {
  const SalonSchedule._(this._poDanu);

  factory SalonSchedule.fromHours(List<WorkingHour> hours) {
    final poDanu = <int, WorkingHour>{};
    for (final hour in hours) {
      if (!hour.isSalonWide) continue;
      poDanu[hour.dayOfWeek] = hour;
    }
    return SalonSchedule._(poDanu);
  }

  /// `day_of_week` u bazi je 1–7 sa ponedjeljkom kao 1 — isto kao `DateTime.weekday`,
  /// pa se dan traži direktno, bez preračunavanja.
  final Map<int, WorkingHour> _poDanu;

  bool get isEmpty => _poDanu.isEmpty;

  /// Dani sedmice redom, počev od ponedjeljka. Dan bez reda u bazi je zatvoren dan —
  /// nedostatak podatka o danu ne smije značiti da se dan ne prikaže, jer bi lista
  /// preskočila utorak i izgledala kao greška.
  List<ScheduleDay> get week => [
    for (var dan = 1; dan <= 7; dan++)
      ScheduleDay(
        weekday: dan,
        hour: _poDanu[dan]?.isClosed == true ? null : _poDanu[dan],
      ),
  ];

  /// Status u trenutku `now`: otvoreno do X, zatvoreno pa otvara u X, ili danas zatvoreno.
  ///
  /// `now` je parametar, a ne `DateTime.now()` unutra, da test može stajati u srijedu
  /// u 10:00 bez čekanja srijede.
  SalonStatus statusAt(DateTime now) {
    final danas = _poDanu[now.weekday];
    if (danas == null || danas.isClosed) {
      return const SalonStatus.closedToday();
    }

    final minute = now.hour * 60 + now.minute;
    if (minute < danas.startTime.minutesFromMidnight) {
      return SalonStatus.opensAt(danas.startTime);
    }
    if (minute < danas.endTime.minutesFromMidnight) {
      return SalonStatus.openUntil(danas.endTime);
    }
    return const SalonStatus.closedToday();
  }
}

/// Jedan dan u listi radnog vremena. `hour == null` znači zatvoreno.
class ScheduleDay {
  const ScheduleDay({required this.weekday, required this.hour});

  /// 1–7, ponedjeljak je 1.
  final int weekday;
  final WorkingHour? hour;

  bool get isClosed => hour == null;
}

/// Trenutni status salona. Tri stanja, jer `docs/02 §3` traži tačno ta tri.
///
/// Nosi `LocalTime`, ne gotov string: formatiranje i prevod su posao ekrana, koji jedini
/// zna jezik — isti razlog zbog kojeg `core_ui` komponente primaju stringove.
sealed class SalonStatus {
  const SalonStatus();

  const factory SalonStatus.openUntil(LocalTime until) = SalonOpen;
  const factory SalonStatus.opensAt(LocalTime at) = SalonOpensLater;
  const factory SalonStatus.closedToday() = SalonClosedToday;
}

class SalonOpen extends SalonStatus {
  const SalonOpen(this.until);
  final LocalTime until;
}

class SalonOpensLater extends SalonStatus {
  const SalonOpensLater(this.at);
  final LocalTime at;
}

class SalonClosedToday extends SalonStatus {
  const SalonClosedToday();
}
