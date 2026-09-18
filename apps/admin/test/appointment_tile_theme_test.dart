/// Šta stvarno stigne do `Text` widgeta u listi termina.
///
/// `theme_tokens_test.dart` provjerava **tokene** — da je `AdminText.time` mono. Ovaj
/// provjerava da je taj token stvarno upotrijebljen: token može biti savršen, a ekran ga
/// ne koristi, i to se ne vidi ni iz jednog drugog testa.
///
/// Ovo je jedini dokaz za monu i za statusne boje koji ne traži pokrenut backend: liste
/// termina nema bez prijave, a lokalni Supabase stack ovdje trenutno nije dostupan.
library;

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/features/appointments/appointment_tile.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';

Appointment _termin({
  AppointmentStatus status = AppointmentStatus.confirmed,
}) => Appointment(
  id: 'a1',
  salonId: _salonId,
  serviceId: 's1',
  customerId: 'c1',
  customerName: 'Adnan Kovac',
  date: LocalDate(2026, 9, 14),
  startTime: LocalTime(13, 0),
  endTime: LocalTime(13, 40),
  status: status,
);

Widget _uTemi(Widget dijete) =>
    MaterialApp(theme: buildAdminTheme(), home: Scaffold(body: dijete));

/// Stil koji je stvarno iscrtan za dati tekst.
TextStyle _stilZa(WidgetTester tester, String tekst) =>
    tester.widget<Text>(find.text(tekst)).style!;

void main() {
  testWidgets('vrijeme termina je JetBrains Mono, sa tabularnim ciframa', (
    tester,
  ) async {
    await tester.pumpWidget(_uTemi(AppointmentTile(termin: _termin())));

    final stil = _stilZa(tester, '13:00');
    expect(stil.fontFamily, kAdminMonoFamily);
    expect(stil.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(stil.fontVariations, isNotEmpty);
  });

  testWidgets('statusna oznaka je Space Grotesk i nosi tekst, ne samo boju', (
    tester,
  ) async {
    await tester.pumpWidget(_uTemi(AppointmentTile(termin: _termin())));

    // WCAG 1.4.1: vlasnik koji ne razlikuje zelenu od narandžaste mora **pročitati**
    // status. Oznaka bez teksta prolazi svaki drugi test u ovom fajlu.
    final oznaka = _stilZa(tester, 'Potvrđeni');
    expect(oznaka.fontFamily, kAdminSansFamily);
    expect(oznaka.color, AdminStatusColors.standard().positive.foreground);
  });

  testWidgets('potvrđen termin je zelen, ne plav', (tester) async {
    // Ranija verzija je uzimala `primaryContainer`, pa je „potvrđeno" bilo plavo — a
    // plava je u ovom sistemu akcent, ne status. Handoff ga crta zeleno.
    await tester.pumpWidget(_uTemi(AppointmentTile(termin: _termin())));

    final pilula = tester.widget<Container>(
      find
          .ancestor(of: find.text('Potvrđeni'), matching: find.byType(Container))
          .first,
    );
    final ukras = pilula.decoration! as BoxDecoration;
    expect(ukras.color, AdminColors.positiveTint);
    expect(ukras.color, isNot(AdminColors.accentTint));
  });

  testWidgets('otkazan i „nije došao" se ne crtaju isto', (tester) async {
    Color podloga(WidgetTester t) {
      final pilula = t.widget<Container>(
        find
            .ancestor(
              of: find.byWidgetPredicate(
                (w) => w is Text && (w.data?.isNotEmpty ?? false),
              ),
              matching: find.byType(Container),
            )
            .last,
      );
      return (pilula.decoration! as BoxDecoration).color!;
    }

    await tester.pumpWidget(
      _uTemi(
        AppointmentTile(termin: _termin(status: AppointmentStatus.cancelled)),
      ),
    );
    final otkazan = podloga(tester);

    await tester.pumpWidget(
      _uTemi(
        AppointmentTile(termin: _termin(status: AppointmentStatus.noShow)),
      ),
    );
    final nijeDosao = podloga(tester);

    expect(otkazan, isNot(nijeDosao));
  });
}
