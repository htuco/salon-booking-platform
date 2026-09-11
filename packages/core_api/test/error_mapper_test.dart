import 'dart:async';
import 'dart:io';

import 'package:core_api/core_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Svaka klasa grešaka koju ekran mora razlikovati ima svoj test.
///
/// Poenta nije pokrivenost nego ugovor: booking flow (task 11) grana po tipu greške, pa
/// pogrešno mapiran `409` znači da korisnik dobije "nema mreže" umjesto osvježene liste
/// termina.
void main() {
  group('PostgrestException', () {
    test('exclusion constraint je konflikt, ne serverska greška', () {
      // 23P01 — `appointments_no_overlap` iz taska 05.
      final error = mapError(
        const PostgrestException(message: 'conflicting key value', code: '23P01'),
      );

      expect(error, isA<ConflictError>());
    });

    test('unique violation je takođe konflikt', () {
      final error = mapError(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );

      expect(error, isA<ConflictError>());
    });

    test('409 iz book_appointment je konflikt', () {
      final error = mapError(
        const PostgrestException(message: 'slot taken', code: '409'),
      );

      expect(error, isA<ConflictError>());
    });

    test('PGRST116 (nula redova) je NotFound', () {
      final error = mapError(
        const PostgrestException(
          message: 'Results contain 0 rows',
          code: 'PGRST116',
        ),
      );

      expect(error, isA<NotFoundError>());
    });

    test('RLS odbijanje izgleda isto kao nepostojeći red', () {
      // Namjerno: razlika između "ne postoji" i "postoji ali ne smiješ" je
      // curenje podatka o tuđem tenantu.
      for (final code in ['42501', '401', '403']) {
        expect(
          mapError(PostgrestException(message: 'denied', code: code)),
          isA<NotFoundError>(),
          reason: 'kod $code mora biti NotFound, ne poseban "zabranjeno"',
        );
      }
    });

    test('ostali kodovi su serverska greška i nose originalnu poruku', () {
      final error = mapError(
        const PostgrestException(message: 'syntax error', code: '42601'),
      );

      expect(error, isA<ServerError>());
      expect(error.message, 'syntax error');
      expect(error.cause, isA<PostgrestException>());
    });
  });

  group('mreža', () {
    test('SocketException je mrežna greška', () {
      expect(mapError(const SocketException('nema rute')), isA<NetworkError>());
    });

    test('TimeoutException je mrežna greška', () {
      expect(mapError(TimeoutException('isteklo')), isA<NetworkError>());
    });

    test('HttpException je mrežna greška', () {
      expect(mapError(const HttpException('prekinuto')), isA<NetworkError>());
    });
  });

  group('oblik odgovora', () {
    test('FormatException znači da su šema i model razišli', () {
      final error = mapError(const FormatException('neispravan datum'));

      expect(error, isA<MappingError>());
    });

    test('TypeError je takođe MappingError, ne ServerError', () {
      // Tipično: kolona preimenovana u migraciji, `@JsonKey` ostao stari.
      try {
        // ignore: unnecessary_cast
        (<String, dynamic>{'x': 1}['x'] as String);
        fail('očekivan TypeError');
      } catch (error) {
        expect(mapError(error), isA<MappingError>());
      }
    });
  });

  group('guard', () {
    test('propušta uspješan rezultat', () async {
      expect(await guard(() async => 42), 42);
    });

    test('pretvara tuđi izuzetak u ApiError', () async {
      await expectLater(
        guard(() async => throw const SocketException('pao')),
        throwsA(isA<NetworkError>()),
      );
    });

    test('ne omotava ApiError po drugi put', () async {
      // Repozitorij koji baca NotFoundError unutar guard-a mora ga vidjeti kakav jeste.
      await expectLater(
        guard(() async => throw const NotFoundError('nema ga')),
        throwsA(isA<NotFoundError>()),
      );
    });
  });

  test('ApiError je sealed — switch je iscrpan bez default grane', () {
    // Ovaj test ne bi kompajlirao da neki tip nedostaje u switch-u. To je i poenta:
    // novi tip greške obori build ovdje, a ne tiho padne u `default` u produkciji.
    String describe(ApiError error) => switch (error) {
      NetworkError() => 'mreža',
      NotFoundError() => 'nema',
      ConflictError() => 'konflikt',
      ServerError() => 'server',
      MappingError() => 'oblik',
    };

    expect(describe(const NetworkError('x')), 'mreža');
    expect(describe(const ConflictError('x')), 'konflikt');
  });
}
