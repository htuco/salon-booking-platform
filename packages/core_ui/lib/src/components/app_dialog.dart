import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import 'app_button.dart';
import 'app_modal.dart';

/// Dijalog potvrde — `prototype/ui/SPEC.md`, modal **5p**.
///
/// Oblik iz handoffa: pozadinski ekran dobije **blur i scrim**, dijalog je uglat, sa
/// hairline obrubom, kicker-om u verzalu, serif naslovom i dva dugmeta **jedno ispod
/// drugog** — destruktivno gore, „zadrži" ispod.
///
/// ## Zašto blur, a ne samo zatamnjenje
///
/// `SPEC.md` traži oboje. Scrim sam po sebi zadrži čitljiv tekst iza dijaloga, pa oko
/// luta; blur ga ukloni kao sadržaj, a ostavi kao kontekst — korisnik i dalje vidi **gdje**
/// je, ali ne čita ispod pitanja koje mu je postavljeno. Za destruktivnu radnju to je
/// razlika između „kliknuo je" i „odlučio je".
///
/// ## Redoslijed dugmadi
///
/// Destruktivna akcija je **primarna i gore**, a „zadrži" ispod nje — tako stoji u
/// handoffu. To je namjerno suprotno od Material defaulta (potvrda desno): dijalog se
/// otvara samo kad je korisnik već pritisnuo „otkaži termin", pa je destruktivna radnja
/// ono što je tražio, a ne zamka. Odustajanje je i dalje jedan dodir, i dodatno: dodir
/// izvan dijaloga i sistemski „nazad" oba znače „zadrži".
///
/// Ne prima `Color` ni tekst iz vertikale — boje dolaze iz teme, tekst iz `.arb`-a ekrana
/// koji ga otvara (v. `core_ui.dart`, pravilo 3).
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.kicker,
    this.destructive = true,
    this.busy = false,
    super.key,
  });

  /// Serif naslov — jedini veliki element u dijalogu.
  final String title;

  /// Objašnjenje posljedice. Ne ponavlja naslov; kaže šta se dešava nakon potvrde.
  final String message;

  /// Labela potvrde. Kaže **šta radi**, ne „U redu" — dijalog se čita u hodu.
  final String confirmLabel;

  /// Labela odustajanja.
  final String cancelLabel;

  /// Kratka oznaka iznad naslova, verzalom (`SPEC.md`: 14px/600, letterspacing .18em).
  final String? kicker;

  /// Da li je potvrda destruktivna. `false` daje običan primarni CTA.
  final bool destructive;

  /// Potvrda je u letu — blokira oba dugmeta i dodir izvan dijaloga.
  final bool busy;

  /// Otvara dijalog i vraća `true` kad je korisnik potvrdio.
  ///
  /// `false` **i** `null` znače odustajanje: `null` stiže od dodira izvan dijaloga i od
  /// sistemskog „nazad". Pozivalac ih zato ne razlikuje — `await showAppDialog(...) == true`
  /// je jedina provjera koja ne propušta.
  static Future<bool?> show(
    BuildContext context, {
    required AppDialog dialog,
  }) => AppModal.dialog<bool>(
    context,
    barrierDismissible: !dialog.busy,
    // Scrim je gotovo neproziran (`SPEC.md`: rgba(6,7,8,.72)) i ide **uz** blur ispod.
    // Vrijednost je token teme (`AppNeutrals.scrim`), jer se po temi razlikuje; postavlja
    // ga `AppModal`, zajedno sa animacijom ulaza (FE-203).
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
      child: dialog,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      backgroundColor: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.none),
        side: BorderSide(color: scheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xxl,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kicker != null) ...[
              Text(
                kicker!.toUpperCase(),
                // Verzal je stil (FE-502): čitač ekrana dobija riječ, ne slova.
                semanticsLabel: kicker,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(title, style: theme.textTheme.displaySmall),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: confirmLabel,
              loading: busy,
              variant: destructive
                  ? AppButtonVariant.danger
                  : AppButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: cancelLabel,
              variant: AppButtonVariant.outline,
              onPressed: busy ? null : () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
