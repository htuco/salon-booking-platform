import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Redovi Postavki i Mog računa — `prototype/ui/SPEC.md` **5k** (`11-postavke.png`).
///
/// ## Zašto ovdje, a ne u `core_ui`
///
/// Oblik je blizak `SelectableRow`-u i `SpecCard`-u iz `core_ui`, ali nijedan ne odgovara:
/// `SelectableRow` nosi fotografiju i stanje izbora, `SpecCard` je par labela–vrijednost
/// bez dodira. Ovo je treća stvar — labela i chevron, grupisano u jedan okvir.
///
/// Ostaje u `features/account/` **dok ga ne zatreba drugi ekran**. Komponenta u `core_ui`
/// sa jednim pozivaocem je pretpostavka o budućnosti; kad task 21 („O aplikaciji",
/// „Pravila") posegne za istim oblikom, tada se seli — sa dva stvarna pozivaoca koji kažu
/// šta je zajedničko, a šta nije.
///
/// Ne prima `Color` ni tekst iz vertikale, isto kao komponente u `core_ui`.

/// Jedan red: labela lijevo, chevron desno.
///
/// **Bez `onTap` nema chevrona i nema fokusa.** Jezik je zasad jedan, pa taj red ne vodi
/// nigdje; red koji izgleda dodirno a ne reaguje je gori od reda koji to ne glumi, a
/// čitaču ekrana bi se javljao kao dugme koje ne radi.
class AccountRow extends StatelessWidget {
  const AccountRow({required this.label, this.onTap, super.key});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dodirni = onTap != null;

    final sadrzaj = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
          if (dodirni)
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );

    if (!dodirni) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
        child: sadrzaj,
      );
    }

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
            child: sadrzaj,
          ),
        ),
      ),
    );
  }
}

/// Grupa redova u **jednom** okviru, sa hairline razdjelnicima između.
///
/// Handoff ih crta kao jednu kutiju, ne kao pet zasebnih kartica — pet okvira bi se čitalo
/// kao pet nepovezanih dugmadi. Razdjelnik ide **između**, nikad iznad prvog ni ispod
/// zadnjeg: tamo ga već crta obrub grupe, pa bi dupli potez bio deblji nego ostali.
class AccountRowGroup extends StatelessWidget {
  const AccountRowGroup({required this.rows, super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: scheme.outline)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: scheme.outline),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// „Izbriši račun" — jedino dugme u app-i koje je *namjerno* u statusnoj boji greške.
///
/// `AppButton(variant: danger)` je otkazivanje termina: neugodno, ali svakodnevno i
/// povratno. Brisanje naloga nije povratno, pa handoff (`11-postavke.png`) crta **prazan
/// okvir sa crvenim tekstom i crvenim obrubom**, ne punu crvenu ploču. Razlika je
/// namjerna i u oba smjera: dovoljno da se izdvoji, premalo da se dodirne u prolazu.
///
/// Boja dolazi iz `AppStatusColors` ekstenzije teme, ne kao literal — statusne boje su
/// platformske i iste u svakom salonu, ali se i dalje čitaju iz teme, jer se svijetla i
/// tamna razlikuju.
class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// Tekst dugmeta. Dolazi iz `.arb`-a ekrana, kao i kod komponenti u `core_ui`
  /// (`core_ui.dart`, pravilo 3) — komponenta ne poznaje jezik.
  final String label;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boja = theme.extension<AppStatusColors>()!.danger;

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: AppSize.buttonHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: boja)),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(color: boja),
            ),
          ),
        ),
      ),
    );
  }
}
