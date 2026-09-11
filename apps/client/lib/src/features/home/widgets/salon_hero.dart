import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Hero sekcija — cover, logo, ime salona, opis i živi status.
///
/// `docs/02 §3`: klijent u prve dvije sekunde vidi **čiji je salon**. Sve u ovom widgetu
/// je tenant podatak; nijedna vrijednost nije literal osim razmaka iz `AppSpacing`.
class SalonHero extends StatelessWidget {
  const SalonHero({
    required this.salon,
    required this.status,
    this.tagline,
    super.key,
  });

  final Salon salon;

  /// Već formatiran status ("Otvoreno do 20:00") — prevod zna ekran, ne ovaj widget.
  final String status;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: _Cover(salon: salon),
        ),
        // Logo preklapa cover za -32 px po wireframeu iz `docs/02 §3`. `Transform` umjesto
        // `Stack` sa negativnim `top`: negativan offset u `Stack`-u se odsiječe clipom, pa
        // bi gornja trećina logotipa nestala.
        Transform.translate(
          offset: const Offset(0, -32),
          child: Column(
            children: [
              _Logo(salon: salon),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  children: [
                    Text(
                      salon.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    if (tagline != null && tagline!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        tagline!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _ZiviStatus(label: status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Živi status salona u heroju ("Otvoreno do 20:00").
///
/// Namjerno **nije** `StatusBadge`. Statusne boje su brand-neutralne po dogovoru iz
/// taska 09 — otkazan termin mora izgledati isto u svakom salonu — pa `StatusTone.info`
/// donosi fiksnu plavu. U heroju je to plava mrlja preko zlatnog odnosno roze brenda,
/// što se vidi tek na screenshotu. Ovaj status nije poruka o ishodu akcije nego dio
/// brendiranog zaglavlja, pa ide u tenant boje.
class _ZiviStatus extends StatelessWidget {
  const _ZiviStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Cover slika, a bez nje gradijent `primary → secondary`.
///
/// `docs/02 §3` traži gradijent, ne sivu površinu: salon bez cover slike i dalje mora
/// izgledati kao svoj brend, a ne kao app koji nije učitao sliku.
class _Cover extends StatelessWidget {
  const _Cover({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final gradijent = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.secondary],
        ),
      ),
      child: const SizedBox.expand(),
    );

    final url = salon.coverImageUrl;
    if (url == null || url.isEmpty) return gradijent;

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      // Placeholder je isti gradijent, ne spinner: prelaz slike preko vlastitog brenda
      // se ne primijeti, a spinner preko hero površine izgleda kao da app ne radi.
      placeholder: (context, url) => gradijent,
      errorWidget: (context, url, error) => gradijent,
    );
  }
}

/// Logo u krugu, a bez njega inicijali salona (`docs/02 §3`).
class _Logo extends StatelessWidget {
  const _Logo({required this.salon});

  final Salon salon;

  static const double _promjer = 88;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final url = salon.logoUrl;
    final sadrzaj = url == null || url.isEmpty
        ? Center(
            child: Text(
              _inicijali(salon.name),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          )
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context, url) => const SizedBox.expand(),
            errorWidget: (context, url, error) => Center(
              child: Text(
                _inicijali(salon.name),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          );

    return Container(
      height: _promjer,
      width: _promjer,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.surface, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: sadrzaj,
    );
  }
}

/// Prva slova prve dvije riječi imena. "Barber Studio Vitez" → "BS".
///
/// `characters.first`, ne `substring(0, 1)`: ime sa emojijem ili dijakritikom van BMP-a
/// bi se prepolovilo i iscrtalo kao kockica.
String _inicijali(String ime) {
  final rijeci = ime.trim().split(RegExp(r'\s+')).where((r) => r.isNotEmpty);
  if (rijeci.isEmpty) return '?';
  return rijeci.take(2).map((r) => r.characters.first).join().toUpperCase();
}
