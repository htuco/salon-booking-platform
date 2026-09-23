import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../salon_schedule.dart';

/// Živi status iz `docs/02 §3`, računat iz `WorkingHour`-a, ne napisan.
///
/// Stoji uz hero jer ga crtaju dva ekrana (Početna i `/about`) — dvije kopije istog
/// `switch`-a bi se razišle pri prvom novom stanju salona.
String salonStatusLabel(AppLocalizations l10n, SalonStatus status) =>
    switch (status) {
      SalonOpen(:final until) => l10n.openUntil(until.format()),
      SalonOpensLater(:final at) => l10n.closedOpensAt(at.format()),
      SalonClosedToday() => l10n.closedToday,
    };

/// Vrh Početne — fotografija preko cijele širine, ime salona u serifu, živi status.
///
/// `prototype/ui/` `01-pocetna.png`: slika se **stapa sa pozadinom** umjesto da se
/// završi ivicom, pa naslov stoji na njoj bez okvira i bez kartice. Zato scrim, a ne
/// obična slika: bez njega bijeli serif na svijetloj fotografiji nestaje, i to se vidi
/// tek kad salon otpremi svoju prvu pravu sliku.
///
/// ## Zašto ime salona, a ne "Zakažite termin" sa slike
///
/// Handoff na tom mjestu ima poziv na akciju, a dugme ispod njega isti taj tekst u
/// drugom licu. Ovdje stoji ime salona, iz dva razloga: `docs/02 §3` traži da klijent u
/// prve dvije sekunde vidi **čiji** je salon, a ime je tenant podatak — jedina stvar na
/// ovom ekranu koja se mijenja bez builda. Poziv na akciju ostaje na dugmetu odmah
/// ispod, gdje ga handoff i ima.
class HomeHero extends StatelessWidget {
  const HomeHero({
    required this.salon,
    required this.status,
    required this.otvoren,
    super.key,
  });

  final Salon salon;

  /// Već formatiran status ("Otvoreno danas do 20:00") — prevod zna ekran.
  final String status;

  /// Je li salon trenutno otvoren. Nosi ga kvadratić uz status, ne tekst.
  final bool otvoren;

  /// **Svjesno odstupanje od handoffa, u njegovom smjeru.** `SPEC.md` („Assets") trazi hero kao
  /// **portret 3:4**, sto bi na 402 pt sirine bilo 536 pt — a ekran je do sada nosio 320, jer je
  /// prvi hero crtao brand gradijent, ne fotografiju. Cim je ispod stala stvarna fotografija,
  /// 320 je izgledalo kao traka, ne kao izlog.
  ///
  /// 420 je sredina: fotografija dobija zraka, a CTA i prva usluga i dalje ulaze u prvi ekran
  /// na telefonu od 812 pt. Naslov i status vise ne zavise od ove vrijednosti — lijepe se za
  /// dno (v. `Positioned` u `build`) — pa se ovaj broj mijenja sam, bez pomjeranja teksta.
  static const double visinaSlike = 420;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        SizedBox(
          height: visinaSlike,
          width: double.infinity,
          child: _Cover(salon: salon),
        ),
        Positioned.fill(child: _Scrim(visina: visinaSlike)),
        // **Naslov i status se lijepe za dno fotografije, ne za procenat njene visine.**
        // Ranije je ovo bio `Padding` sa `top: visinaSlike * 0.55`. Kako je sadrzaj ispod
        // fiksne visine (~132), svaki piksel dodan heroju isao je pola u razmak iznad teksta
        // a pola u **praznu traku ispod njega**: na 320 je ta traka bila ~12 px, na 420 je
        // narasla na ~57 i vidjela se kao rupa izmedju statusa i CTA dugmeta.
        //
        // Ovako razmak do dna je konstanta, pa je `visinaSlike` stvarno jedan broj koji se
        // mijenja bez posljedica po raspored — sto je ranija verzija obecavala a nije radila.
        Positioned(
          left: AppSpacing.gutter,
          right: AppSpacing.gutter,
          bottom: AppSpacing.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(salon.name, style: theme.textTheme.displaySmall),
              const SizedBox(height: AppSpacing.lg),
              _ZiviStatus(label: status, otvoren: otvoren),
            ],
          ),
        ),
      ],
    );
  }
}

/// Prelaz iz fotografije u pozadinu ekrana.
///
/// Ide do **pune** `surface` boje na dnu, ne do poluprozirne: rub koji se vidi je rub
/// koji na drugom tenantu ispadne druge boje nego pozadina ispod njega.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.visina});

  final double visina;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surface.withValues(alpha: 0.15),
            surface.withValues(alpha: 0.75),
            surface,
          ],
          stops: const [0, 0.6, 1],
        ),
      ),
      child: SizedBox(height: visina),
    );
  }
}

/// Živi status salona ("Otvoreno danas do 20:00").
///
/// Namjerno **nije** `StatusBadge`. Statusne boje su brand-neutralne po dogovoru iz
/// taska 09 — otkazan termin mora izgledati isto u svakom salonu — pa `StatusTone.info`
/// donosi fiksnu plavu, što je preko hero fotografije plava mrlja.
///
/// Handoff ga crta kao uokviren red sa malim kvadratom ispred teksta. Kvadrat je jedino
/// mjesto gdje boja nosi značenje: otvoren salon je `success`, zatvoren prigušen. Osam
/// piksela ne takmiče se sa brendom, a razlika "otvoreno / zatvoreno" se vidi bez
/// čitanja.
class _ZiviStatus extends StatelessWidget {
  const _ZiviStatus({required this.label, required this.otvoren});

  final String label;
  final bool otvoren;

  static const double _kvadrat = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = theme.extension<AppStatusColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.rowPadding,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: _kvadrat,
            width: _kvadrat,
            color: otvoren ? status.success : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation('wght', 600)],
              ),
            ),
          ),
        ],
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
