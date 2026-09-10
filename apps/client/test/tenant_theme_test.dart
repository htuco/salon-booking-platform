import 'package:client/main.dart';
import 'package:client/src/generated/tenants.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresija za neusklađenost teme: `Theme.of` pozvan u `build` metodi koja
/// tek gradi `MaterialApp` vraća Flutterov default (svijetlu) temu, pa se
/// tekst iscrta tamno na tamnoj tenant pozadini i postane nevidljiv.
///
/// Prazan `SALON_ID` daje svijetlu temu, gdje neusklađenost nije vidljiva —
/// zato ovaj fajl traži `--dart-define=SALON_ID=<uuid tamnog tenanta>`:
///
///   flutter test test/tenant_theme_test.dart \
///     --dart-define=SALON_ID=550e8400-e29b-41d4-a716-446655440000
void main() {
  const salonId = TenantPreviewApp.salonId;
  final tenant = kTenants[salonId];

  testWidgets('svaki tekst ima WCAG AA kontrast na tenant temi', (
    tester,
  ) async {
    await tester.pumpWidget(const TenantPreviewApp());

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    final background = theme.colorScheme.surface;
    final fallback = theme.textTheme.bodyMedium!.color!;

    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final color = text.style?.color ?? fallback;
      final a = color.computeLuminance();
      final b = background.computeLuminance();
      final ratio = a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
      expect(
        ratio,
        greaterThan(4.5),
        reason:
            'Tekst "${text.data}" ima kontrast ${ratio.toStringAsFixed(2)}:1 '
            'prema pozadini — ispod WCAG AA. Vjerovatno `Theme.of` iz '
            'konteksta iznad MaterialApp-a.',
      );
    }
    // Bez --dart-define nema tenanta, pa ni neusklađenosti koju bi se provjerilo.
  }, skip: tenant == null);
}
