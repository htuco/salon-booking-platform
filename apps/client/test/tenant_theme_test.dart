import 'package:client/main.dart';
import 'package:client/src/core/env/app_env.dart';
import 'package:client/src/generated/tenants.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresija za neusklađenost teme: `Theme.of` pozvan u `build` metodi koja
/// tek gradi `MaterialApp` vraća Flutterov default (svijetlu) temu, pa se
/// tekst iscrta tamno na tamnoj tenant pozadini i postane nevidljiv.
///
/// Ranije je ovaj fajl tražio `--dart-define=SALON_ID=<uuid>` i bez njega se **skipovao**,
/// jer je `SALON_ID` bio compile-time konstanta. Otkad env ulazi kroz `appEnvProvider`,
/// test bira tenanta sam i uvijek se izvršava — uključujući tamnu temu, gdje se
/// neusklađenost jedino i vidi.
void main() {
  for (final tenant in kTenants.values) {
    testWidgets('svaki tekst ima WCAG AA kontrast — ${tenant.flavor}', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appEnvProvider.overrideWithValue(
              AppEnv(
                salonId: tenant.salonId,
                supabaseUrl: '',
                supabaseAnonKey: '',
                apiUrl: '',
              ),
            ),
          ],
          child: const SalonClientApp(),
        ),
      );
      await tester.pumpAndSettle();

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
    });
  }
}
