import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast_test.dart'
    show barberPrimary, barberSecondary, beautyPrimary, beautySecondary;

/// Ekran koji koristi sve komponente odjednom.
///
/// Zamka iz `docs/02 §14` i iz taska: **ekran testiran samo na beauty paleti je ekran
/// testiran napola.** Tamna barber paleta ima potpuno drugu pozadinu, pa boja koja je na
/// svijetloj pozadini bila uredna zna nestati. Zato isti widget ide kroz obje teme.
class _DemoEkran extends StatelessWidget {
  const _DemoEkran();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Katalog')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const ServiceCard(
          name: 'Fade sisanje',
          duration: '45 min',
          price: '25 KM',
          description: 'Masinica i skare, pranje kose.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const ServiceCard(
          name: 'Brijanje',
          duration: '30 min',
          price: '15 KM',
          selected: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            TimeSlotChip(label: '09:00', onTap: () {}),
            const TimeSlotChip(label: '09:30'),
            TimeSlotChip(label: '10:00', onTap: () {}, selected: true),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const Row(
          children: [
            StatusBadge(label: 'Potvrden', tone: StatusTone.success),
            SizedBox(width: AppSpacing.sm),
            StatusBadge(label: 'Na cekanju', tone: StatusTone.warning),
            SizedBox(width: AppSpacing.sm),
            StatusBadge(label: 'Otkazan', tone: StatusTone.danger),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SkeletonLoader.card(),
        const SizedBox(height: AppSpacing.lg),
        const EmptyState(
          message: 'Nema slobodnih termina za ovaj dan.',
          icon: Icons.event_busy,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(label: 'Zakazi termin', onPressed: () {}),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Otkazi',
          onPressed: () {},
          variant: AppButtonVariant.danger,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Nazad',
          onPressed: () {},
          variant: AppButtonVariant.outline,
        ),
      ],
    ),
  );
}

const _palete = <String, (Color, Color, String)>{
  'modern_barber (tamna)': (barberPrimary, barberSecondary, 'modern_barber'),
  'elegant_beauty (svijetla)': (
    beautyPrimary,
    beautySecondary,
    'elegant_beauty',
  ),
};

void main() {
  _palete.forEach((ime, paleta) {
    final (primary, secondary, themeName) = paleta;
    final tema = buildAppTheme(
      primary: primary,
      secondary: secondary,
      themeName: themeName,
    );

    group(ime, () {
      testWidgets('svaki tekst na ekranu prolazi WCAG AA', (tester) async {
        // Visok viewport da ListView iscrta sve odjednom — tekst koji nikad nije
        // izgradjen ne bi bio provjeren, pa bi test prosao ne dokazavsi nista.
        tester.view
          ..physicalSize = const Size(1080, 3200)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(theme: tema, home: const _DemoEkran()),
        );
        await tester.pump(AppDuration.slow);

        final tekstovi = find.byType(Text);
        expect(tekstovi, findsWidgets);

        for (final element in tekstovi.evaluate()) {
          final widget = element.widget as Text;
          final stil = DefaultTextStyle.of(element).style.merge(widget.style);
          final boja = stil.color;
          if (boja == null) continue;

          // Stvarna pozadina ispod ovog teksta, ne pozadina ekrana: badge i izabrani
          // chip imaju svoju. Bez ovoga bi test mjerio tekst badgea prema `surface`-u
          // i pao na necemu sto je u stvarnosti citljivo.
          final pozadina = _pozadinaIspod(element, tema);
          final odnos = contrastRatio(boja, pozadina);

          expect(
            odnos,
            greaterThanOrEqualTo(kWcagAa),
            reason:
                '$ime: tekst "${widget.data}" ima kontrast '
                '${odnos.toStringAsFixed(2)}:1 prema svojoj pozadini '
                '(${boja.toARGB32().toRadixString(16)} na '
                '${pozadina.toARGB32().toRadixString(16)}).',
          );
        }
      });

      testWidgets('dodirne mete nisu ispod 44 px', (tester) async {
        tester.view
          ..physicalSize = const Size(1080, 3200)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(theme: tema, home: const _DemoEkran()),
        );
        await tester.pump(AppDuration.slow);

        for (final chip in find.byType(TimeSlotChip).evaluate()) {
          final velicina = chip.size!;
          expect(velicina.height, greaterThanOrEqualTo(AppSize.touchTarget));
          expect(velicina.width, greaterThanOrEqualTo(AppSize.touchTarget));
        }

        for (final dugme in find.byType(AppButton).evaluate()) {
          expect(dugme.size!.height, greaterThanOrEqualTo(AppSize.touchTarget));
        }
      });

      testWidgets('nijedna komponenta ne iscrtava Flutterov default', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(theme: tema, home: const _DemoEkran()),
        );
        await tester.pump(AppDuration.slow);

        final scaffold = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(Scaffold),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(
          scaffold.color ?? tema.scaffoldBackgroundColor,
          tema.colorScheme.surface,
        );
      });
    });
  });

  testWidgets('AppButton u loading stanju ne prima tap', (tester) async {
    // Dvostruki tap na "Zakazi" je dva zahtjeva za isti termin. Exclusion constraint u
    // bazi (task 05) drugi odbije, ali korisnik vidi gresku umjesto potvrde.
    var brojPoziva = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          primary: beautyPrimary,
          secondary: beautySecondary,
          themeName: 'elegant_beauty',
        ),
        home: Scaffold(
          body: AppButton(
            label: 'Zakazi',
            loading: true,
            onPressed: () => brojPoziva++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(brojPoziva, 0);
  });

  testWidgets('SkeletonLoader postuje reduce motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          primary: barberPrimary,
          secondary: barberSecondary,
          themeName: 'modern_barber',
        ),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: SkeletonLoader.card()),
        ),
      ),
    );
    await tester.pump();

    // Bez ovoga puls se vrti u nedogled; `pumpAndSettle` bi istekao, a korisnik koji je
    // ugasio animacije dobio bi tacno ono sto je iskljucio.
    //
    // Trazi se `FadeTransition` **unutar skeletona**: `MaterialApp` svoje pravi za
    // prelaz rute, pa bi provjera nad cijelim stablom nasla tudje i pala uvijek.
    expect(
      find.descendant(
        of: find.byType(SkeletonLoader),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('SkeletonLoader ipak pulsira kad su animacije dozvoljene', (
    tester,
  ) async {
    // Bez ove polovine bi gornji test prolazio i da je animacija potpuno obrisana.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          primary: barberPrimary,
          secondary: barberSecondary,
          themeName: 'modern_barber',
        ),
        home: Scaffold(body: SkeletonLoader.card()),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(SkeletonLoader),
        matching: find.byType(FadeTransition),
      ),
      findsOneWidget,
    );
  });
}

/// Boja koju tekst stvarno ima iza sebe.
///
/// Ide uz stablo do prvog pretka koji crta neprozirnu pozadinu (`Material`, `Container`
/// sa bojom, `DecoratedBox`). Bez toga bi se tekst badgea mjerio prema pozadini ekrana i
/// test bi prijavljivao greške tamo gdje ih nema.
Color _pozadinaIspod(Element element, ThemeData tema) {
  Color? nadjena;

  element.visitAncestorElements((predak) {
    final widget = predak.widget;
    if (widget is Material && widget.color != null && widget.color!.a == 1.0) {
      nadjena = widget.color;
      return false;
    }
    if (widget is ColoredBox && widget.color.a == 1.0) {
      nadjena = widget.color;
      return false;
    }
    if (widget is DecoratedBox) {
      final dekoracija = widget.decoration;
      if (dekoracija is BoxDecoration &&
          dekoracija.color != null &&
          dekoracija.color!.a == 1.0) {
        nadjena = dekoracija.color;
        return false;
      }
    }
    if (widget is Container && widget.color != null && widget.color!.a == 1.0) {
      nadjena = widget.color;
      return false;
    }
    return true;
  });

  return nadjena ?? tema.colorScheme.surface;
}
