import '../../l10n/generated/app_localizations.dart';

/// Relativan datum recenzije — „prije 3 dana", „prije 2 sedmice", „prije mjesec".
///
/// Handoff (`13-recenzije.png`) ne pokazuje nijedan apsolutan datum, i to je namjera:
/// „prije 3 dana" kaže da je salon **i dalje** ovakav, a „12.06.2026." traži od čitaoca da
/// sam računa koliko je to davno.
///
/// ## Zašto praguje ovako
///
/// Jedinica se bira po **najvećoj koja daje broj veći od nule**, pa 13 dana ostaje „prije
/// 13 dana" a 14 postaje „prije 2 sedmice". Granice su cjelobrojne i namjerno grube —
/// ovo je mjera starosti mišljenja, ne kalendar.
///
/// `now` se prosljeđuje, a ne uzima iz `DateTime.now()` unutra: test koji zavisi od
/// stvarnog sata je test koji je zelen samo dio dana. Task 17 je našao tri takva u ovom
/// repou.
String timeAgo(AppLocalizations l10n, DateTime when, {required DateTime now}) {
  final razlika = now.difference(when);

  // Budući datum (pogrešan unos ili sat uređaja koji kasni) ne smije dati „prije -2 dana".
  final dani = razlika.inDays < 0 ? 0 : razlika.inDays;

  if (dani >= 365) return l10n.timeAgoYears(dani ~/ 365);
  if (dani >= 30) return l10n.timeAgoMonths(dani ~/ 30);
  if (dani >= 7) return l10n.timeAgoWeeks(dani ~/ 7);
  if (dani >= 1) return l10n.timeAgoDays(dani);
  return l10n.timeAgoToday;
}
