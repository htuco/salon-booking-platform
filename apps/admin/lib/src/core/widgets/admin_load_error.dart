import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// Greška učitavanja unutar panela ili sekcije: jedna rečenica i „Pokušaj ponovo"
/// (FE-501).
///
/// Za sekcije koje stoje **uz** drugi sadržaj (raspored na dashboardu, sekcije pravila,
/// izbor usluge). Ekrani čija je cijela površina greška imaju svoj centrirani `_Greska`.
/// Ovdje se ne centrira, jer bi poruka usred panela odvojila dugme od onoga na šta se
/// odnosi.
///
/// [onRetry] mora biti `ref.invalidate(...)` izvora. Bez dugmeta je jedini način da se
/// sekcija ponovo učita napustiti ekran.
class AdminLoadError extends StatelessWidget {
  const AdminLoadError({
    required this.poruka,
    required this.onRetry,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String poruka;
  final VoidCallback onRetry;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(poruka, style: TextStyle(color: context.adminColors.textMuted)),
          TextButton(onPressed: onRetry, child: const Text('Pokušaj ponovo')),
        ],
      ),
    );
  }
}
