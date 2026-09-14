import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Destruktivna radnja Postavki i Mog računa — `prototype/ui/SPEC.md` **5k**
/// (`11-postavke.png`).
///
/// Redovi liste su se odselili u `core_ui` kao `LinkRow`/`LinkRowGroup` kad su dobili
/// drugog pozivaoca („O aplikaciji", task 21) — tako je ovdje i pisalo da će biti. Ostalo
/// je ono što se nije preselilo, i to namjerno: brisanje naloga nije red liste nego jedina
/// nepovratna radnja u aplikaciji, i ne smije izgledati kao susjedi.

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
