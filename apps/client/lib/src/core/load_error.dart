import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/generated/app_localizations.dart';

/// Stanje „nije se učitalo" — jedan obrazac za sve ekrane klijenta (FE-501).
///
/// **Greška nije prazno stanje.** Ekran koji pad upita nacrta kao „nema slika" ili
/// „nema pravila" tvrdi nešto netačno, i korisniku ne daje ništa da uradi. Ovdje je uvijek
/// kratka rečenica i „Pokušaj ponovo", koje zove [onRetry]. To mora biti
/// `ref.invalidate(...)` izvora, a ne ponovni prikaz iste keširane greške.
///
/// Rečenica se bira po tipu greške, ne iz `ApiError.message`: taj tekst je za log
/// (`api_error.dart`). Mreža ima svoju poruku, jer korisnik tu nešto može uraditi.
/// Sve ostalo dobija opštu.
///
/// Namjerno nije crvena: isti mirni `EmptyState` kao prazno stanje, sa ikonom oblaka.
/// Galerija je ranije grešku crtala kao prazno stanje upravo da ne bi uznemirila; ovaj
/// oblik je jednako miran, ali ne laže.
class LoadError extends StatelessWidget {
  const LoadError({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return EmptyState(
      message: error is NetworkError ? l10n.noConnection : l10n.genericError,
      icon: LucideIcons.cloudOff,
      actionLabel: l10n.retry,
      onAction: onRetry,
    );
  }
}
