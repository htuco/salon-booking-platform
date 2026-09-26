import 'dart:typed_data';

import 'package:core_api/core_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Uint8List _b(List<int> x) => Uint8List.fromList(x);

void main() {
  group('MediaRepository.tipIzSadrzaja (task 49)', () {
    test('prepoznaje JPEG, PNG i WebP po prvim bajtovima', () {
      expect(
        MediaRepository.tipIzSadrzaja(_b([0xFF, 0xD8, 0xFF, 0xE0])),
        'image/jpeg',
      );
      expect(
        MediaRepository.tipIzSadrzaja(
          _b([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
        'image/png',
      );
      expect(
        MediaRepository.tipIzSadrzaja(
          _b('RIFF\x00\x00\x00\x00WEBPVP8 '.codeUnits),
        ),
        'image/webp',
      );
    });

    test('SVG, tekst i prekratak sadržaj nisu slika', () {
      expect(MediaRepository.tipIzSadrzaja(_b('<svg/>'.codeUnits)), isNull);
      expect(MediaRepository.tipIzSadrzaja(_b('nije slika'.codeUnits)), isNull);
      expect(MediaRepository.tipIzSadrzaja(_b([0xFF])), isNull);
    });
  });

  group('StorageException → ApiError (task 49)', () {
    String? poruka(StorageException e) => mapError(e).displayMessage;

    test('bucket odbija veličinu i tip porukom na bosanskom', () {
      expect(
        poruka(const StorageException('x', statusCode: '413')),
        'Slika je veća od 5 MB.',
      );
      expect(
        poruka(
          const StorageException(
            'mime type image/svg+xml is not supported',
            statusCode: '400',
          ),
        ),
        'Podržane su JPG, PNG i WebP slike.',
      );
    });

    test('odbijen upis kaže šta se desilo, ne „zapis ne postoji"', () {
      expect(
        poruka(
          const StorageException(
            'new row violates row-level security policy',
            statusCode: '400',
          ),
        ),
        'Nemate pravo da mijenjate slike ovog salona.',
      );
      expect(
        poruka(const StorageException('jwt expired', statusCode: '401')),
        'Sesija je istekla. Prijavite se ponovo.',
      );
    });

    test('nepoznata greška ne pušta englesku poruku servera', () {
      expect(
        poruka(
          const StorageException('Internal Server Error', statusCode: '500'),
        ),
        'Slika se ne može poslati. Pokušajte ponovo.',
      );
    });
  });
}
