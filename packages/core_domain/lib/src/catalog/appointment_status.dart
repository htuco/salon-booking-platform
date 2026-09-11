import 'package:json_annotation/json_annotation.dart';

/// Stanje termina — `public.appointment_status` enum iz baze.
///
/// Tipizirano, ne goli string: ekran grana po statusu na više mjesta ("čeka potvrdu" vs
/// "potvrđeno" vs "otkazano"), a `switch` nad enumom Dart provjerava na iscrpnost. Novo
/// stanje u bazi tako obori build na svakom mjestu koje ga ne obrađuje, umjesto da se
/// provuče kao neprepoznat string i tiho padne u `else`.
///
/// [unknown] postoji jer je app u storeu uvijek starija od baze: `alter type ... add value`
/// je migracija koju niko ne prati po verzijama storea. Bez fallbacka bi svaki termin sa
/// novim statusom bio `CastError` usred liste; ovako se prikaže neutralno i ostane vidljiv
/// u logu. Isti razlog zbog kojeg je `Vertical.key` namjerno `String`.
@JsonEnum(valueField: 'wireName')
enum AppointmentStatus {
  /// Klijent je rezervisao, salon još nije potvrdio. Ističe nakon
  /// `salon_settings.pending_expiry_hours`.
  pending('pending'),

  /// Salon je potvrdio (ili je `booking_mode = 'auto'` pa je potvrda automatska).
  confirmed('confirmed'),

  /// Otkazano — ko je otkazao stoji u `cancelled_by`.
  cancelled('cancelled'),

  /// Termin je odrađen.
  completed('completed'),

  /// Klijent se nije pojavio.
  noShow('no_show'),

  /// Status koji ova verzija app-e ne poznaje — v. dokumentaciju gore.
  unknown('unknown');

  const AppointmentStatus(this.wireName);

  /// Vrijednost kako stoji u bazi (`no_show`, ne `noShow`).
  final String wireName;

  /// Mapira vrijednost iz baze, uz [unknown] za sve što ova verzija ne poznaje.
  static AppointmentStatus fromWire(String? value) => switch (value) {
    'pending' => pending,
    'confirmed' => confirmed,
    'cancelled' => cancelled,
    'completed' => completed,
    'no_show' => noShow,
    _ => unknown,
  };

  /// Termin još zauzima slot — availability engine računa `pending` i `confirmed` kao
  /// zauzeto (v. `get_available_slots`).
  bool get blocksSlot => this == pending || this == confirmed;

  /// Termin je iza nas, na ovaj ili onaj način.
  bool get isClosed => this == cancelled || this == completed || this == noShow;
}
