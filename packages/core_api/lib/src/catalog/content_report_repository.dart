import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Prijava neprikladne slike iz galerije salona (task 51, ADR-0024).
///
/// Prijava ide **platformi, ne salonu**: `content_reports` čita samo `super_admin`, a
/// webhook platforme je dobija u roku od minute. Baza traži pravog klijenta, sliku koja je
/// stvarno u galeriji salona iz `x-salon-id` headera, i istu sliku prima jednom po klijentu
/// dok je prijava otvorena — ponovljen tap vraća isti red, ne grešku.
class ContentReportRepository {
  const ContentReportRepository(this._client);

  final SupabaseClient _client;

  /// Najduži razlog koji baza prima.
  static const maxReasonLength = 500;

  Future<void> reportImage({
    required String salonId,
    required String imageUrl,
    String? reason,
  }) => guard(() async {
    await _client.rpc<dynamic>(
      'report_content',
      params: {
        'p_salon_id': salonId,
        'p_image_url': imageUrl,
        'p_reason': reason,
      },
    );
  });
}
