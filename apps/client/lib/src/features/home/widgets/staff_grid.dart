import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Majstori — dvije kolone portretnih fotografija, ime i titula ispod (`01-pocetna.png`).
///
/// Mreža, a ne horizontalna traka kakvu je ekran imao od taska 10: handoff pokazuje dvije
/// pune kolone, jer su radnici razlog zašto se salon bira. U traci su bili avatari od 72
/// px koje se skrola postrance i koje niko ne pogleda.
///
/// Okvir je `PhotoFrame`, dakle **uglat i vidljiv i kad slike nema** — salon bez
/// fotografija radnika je predviđeno stanje, ne rupa u rasporedu (task 22).
class StaffGrid extends StatelessWidget {
  const StaffGrid({
    required this.employees,
    required this.subtitleOf,
    super.key,
  });

  final List<Employee> employees;

  /// Titula i staž u jednom redu ("Barber · 9 godina"). Sastavlja ekran, jer spajanje
  /// zavisi od jezika i od toga ima li radnik upisan staž.
  final String Function(Employee) subtitleOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Širina kolone se računa iz stvarne širine, ne iz pretpostavke o ekranu:
        // `GridView` unutar `Column`-a u sliveru traži poznatu visinu, a ovdje je
        // visina ćelije posljedica širine (portret 3:4 plus dva reda teksta).
        final sirina = (constraints.maxWidth - AppSpacing.sm) / 2;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.lg,
          children: [
            for (final employee in employees)
              SizedBox(
                width: sirina,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PhotoFrame(
                      imageUrl: employee.imageUrl,
                      size: sirina,
                      aspectRatio: 0.75,
                      placeholder: Center(
                        child: Text(
                          _inicijal(employee.name),
                          style: theme.textTheme.headlineMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      employee.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      subtitleOf(employee),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Prvo slovo imena, kao zamjena za fotografiju koje nema.
///
/// `characters.first`, ne `substring(0, 1)`: ime sa dijakritikom van BMP-a bi se
/// prepolovilo i iscrtalo kao kockica.
String _inicijal(String ime) {
  final trimmed = ime.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}
