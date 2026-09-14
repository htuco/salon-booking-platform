/// Domenski sloj — entiteti i pravila, bez Fluttera i bez mreže.
///
/// ## Pravilo bez izuzetka: vertical-zavisan string ne ide u ekran
///
/// Nijedan string koji se razlikuje između frizera, beauty salona i ordinacije ne smije
/// stajati kao literal u `.dart` fajlu ekrana. Ide kroz `Vertical.terms`:
///
/// ```dart
/// // ne
/// Text('Zakaži termin')
/// Text('Klijent')
///
/// // da
/// Text(vertical.terms.bookCta)        // "Zakaži termin" · "Rezerviši termin" · "Zakaži pregled"
/// Text(vertical.terms.customerSingular) // "Klijent" · "Klijentica" · "Pacijent"
/// ```
///
/// Razlog je distribucija, ne stil: string u ekranu se mijenja samo novim store submissionom,
/// a `vertical_packs.terminology` se mijenja `update`-om jednog reda. Isti razlog vrijedi za
/// grananje — nema `if (vertical.key == 'dental')` u ekranu, nego flag u `Vertical.features`.
///
/// **Ovo nije isto što i jezik aplikacije.** Dugmad, greške i sistemski tekst idu kroz `.arb`
/// (`intl`), terminologija kroz `Vertical.terms`. Dvije različite stvari koje se ne miješaju:
/// `.arb` prevodi "Otkaži" na engleski, `terms` bira između "Klijent" i "Pacijent" na istom
/// jeziku.
///
/// Tabela terminologije, booking pravila i feature flagova po vertikali:
/// `docs/05-vertical-packs.md`.
library;

export 'src/auth/auth_config.dart';
export 'src/auth/auth_platform.dart';
export 'src/auth/auth_provider.dart';
export 'src/auth/auth_session.dart';
export 'src/catalog/appointment.dart';
export 'src/catalog/appointment_status.dart';
export 'src/catalog/available_slot.dart';
export 'src/catalog/employee.dart';
export 'src/catalog/employee_service.dart';
export 'src/catalog/local_date.dart';
export 'src/catalog/local_time.dart';
export 'src/catalog/policy_section.dart';
export 'src/catalog/review.dart';
export 'src/catalog/salon.dart';
export 'src/catalog/salon_rating_summary.dart';
export 'src/catalog/salon_settings.dart';
export 'src/catalog/service.dart';
export 'src/catalog/working_hour.dart';
export 'src/vertical/booking_rules.dart';
export 'src/vertical/vertical.dart';
export 'src/vertical/vertical_features.dart';
export 'src/vertical/vertical_terms.dart';
