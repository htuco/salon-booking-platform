import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// `StarRating` — oblik ocjene.
///
/// **Ovaj fajl postoji zbog greške koju obični widget testovi nisu mogli vidjeti.** Prva
/// verzija je punu zvjezdicu od prazne razlikovala samo **bojom** linijske Lucide ikone,
/// jer taj set nema popunjenu zvjezdicu. Svaki test je prolazio — pet ikona je bilo pet
/// ikona — a na živom ekranu su kartica sa peticom i kartica sa četvorkom izgledale isto.
///
/// ## Zašto se mjeri mastilo, a ne jednakost slika
///
/// Prvi pokušaj ovog testa je poredio sirove piksele i tvrdio „4 i 5 ne smiju biti
/// identični". **Taj test je prolazio i nad pokvarenom verzijom**, jer se pikseli jesu
/// razlikovali — samo neprimjetno. Izmjereno: zatečena verzija je po zvjezdici dodavala
/// **2,4%** svjetline i crtala 3,5 **identično** kao 4,0; ispunjena dodaje oko **11%**.
///
/// Mjeri se zato **koliko** se razlikuju, ne da li se razlikuju. Prag od 5% po zvjezdici
/// pada na zatečenoj verziji i prolazi na ispunjenoj, sa dvostrukom rezervom na obje
/// strane.
///
/// Uz to, razlika nošena **samo bojom** je i WCAG 1.4.1 problem: ocjena je informacija, a
/// informacija se ne smije prenositi isključivo bojom.
void main() {
  /// Prosječna svjetlina iscrtanog widgeta, 0–255.
  ///
  /// Ispunjena zvjezdica oboji svoju unutrašnjost, obris ne — pa je ovo mjera koliko je
  /// „popunjenosti" stvarno završilo na ekranu.
  Future<double> mastilo(WidgetTester tester, double ocjena) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(child: StarRating(value: ocjena, size: 40)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).last,
    );

    // **`runAsync` nije stil nego uslov.** `toImage()` se dovršava na raster niti, koju
    // test binding ne pogoni sam — bez ovoga Future nikad ne stigne i test **visi**
    // umjesto da padne, što je gore od pada.
    late ByteData podaci;
    await tester.runAsync(() async {
      final slika = await boundary.toImage();
      podaci = (await slika.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      slika.dispose();
    });

    final bajtovi = podaci.buffer.asUint8List();
    var zbir = 0.0;
    for (var i = 0; i < bajtovi.length; i += 4) {
      final siva = (bajtovi[i] + bajtovi[i + 1] + bajtovi[i + 2]) / 3;
      zbir += siva * (bajtovi[i + 3] / 255);
    }
    return zbir / (bajtovi.length / 4);
  }

  /// Koliko svaka zvjezdica mora dodati da bi se razlika **vidjela**, a ne samo izmjerila.
  ///
  /// Zatečena verzija je davala 2,4%; ispunjena daje oko 11%. Prag je između, bliže dnu,
  /// da sitna izmjena debljine obrisa ne obori test bez razloga.
  const pragPoZvjezdici = 0.05;

  testWidgets('svaka zvjezdica mora vidljivo dodati, ne samo promijeniti nijansu', (
    tester,
  ) async {
    final mjere = <int, double>{};
    for (var ocjena = 0; ocjena <= 5; ocjena++) {
      mjere[ocjena] = await mastilo(tester, ocjena.toDouble());
    }

    for (var ocjena = 1; ocjena <= 5; ocjena++) {
      final prirast =
          (mjere[ocjena]! - mjere[ocjena - 1]!) / mjere[ocjena - 1]!;
      expect(
        prirast,
        greaterThan(pragPoZvjezdici),
        reason:
            'Ocjena $ocjena dodaje samo ${(prirast * 100).toStringAsFixed(1)}% '
            'u odnosu na ${ocjena - 1}. Ispod ${pragPoZvjezdici * 100}% razlika se '
            'ne vidi — tačno ta greška je pustila peticu i četvorku da izgledaju isto.',
      );
    }
  });

  testWidgets('petica je vidljivo punija od četvorke', (tester) async {
    // Isti slučaj koji je pao na živom ekranu, izdvojen da poruka o grešci bude jasna.
    final cetiri = await mastilo(tester, 4);
    final pet = await mastilo(tester, 5);

    expect((pet - cetiri) / cetiri, greaterThan(pragPoZvjezdici));
  });

  testWidgets('polovina je vlastito stanje, ne zaokružena puna', (
    tester,
  ) async {
    // Zatečena verzija je 3,5 crtala **identično** kao 4,0 — pola zvjezdice je postojalo
    // u kodu, a ne na ekranu.
    final tri = await mastilo(tester, 3);
    final polovina = await mastilo(tester, 3.5);
    final cetiri = await mastilo(tester, 4);

    expect(polovina, greaterThan(tri));
    expect(polovina, lessThan(cetiri));
  });

  testWidgets('4,8 se zaokružuje na pet punih, ne na četiri', (tester) async {
    // „4,8" i četiri zvjezdice na istom ekranu je greška koju svako primijeti.
    expect(await mastilo(tester, 4.8), closeTo(await mastilo(tester, 5), 0.01));
  });

  group('pristupačnost', () {
    testWidgets('labela se pročita kad je data', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRating(value: 4, semanticsLabel: '4 od 5 zvjezdica'),
          ),
        ),
      );

      expect(find.bySemanticsLabel('4 od 5 zvjezdica'), findsOneWidget);

      // Ručno, ne kroz `addTearDown`: provjera da su handle-ovi otpušteni ide **prije**
      // tearDown-a, pa bi test pao i sa prolaznim asercijama.
      handle.dispose();
    });

    testWidgets('bez labele zvjezdice su nijeme', (tester) async {
      // Tamo gdje isti broj stoji kao tekst odmah pored (kartica na Početnoj), čitač
      // ekrana ga ne smije pročitati dvaput.
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StarRating(value: 4))),
      );

      expect(find.bySemanticsLabel(RegExp('zvjezdic')), findsNothing);

      handle.dispose();
    });
  });
}
