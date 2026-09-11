import 'package:flutter/material.dart';

import '../tokens/spacing.dart';

/// Skeleton — `docs/02 §14`: **skeleton, ne spinner preko cijelog ekrana**.
///
/// Spinner kaže "čekaj", skeleton kaže "evo šta stiže" i zadržava raspored, pa ekran ne
/// poskoči kad podaci dođu. Uz to rješava zahtjev da nema bijelog flasha: kostur se
/// iscrtava u tenant temi, koja je poznata prije prvog mrežnog odgovora.
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    required this.height,
    this.width = double.infinity,
    this.radius = AppRadius.sm,
    super.key,
  });

  /// Kartica usluge u listi — tri reda visine kartice.
  factory SkeletonLoader.card({Key? key}) =>
      SkeletonLoader(key: key, height: 96, radius: AppRadius.md);

  /// Jedan red teksta.
  factory SkeletonLoader.text({Key? key, double width = 160}) =>
      SkeletonLoader(key: key, height: 16, width: width);

  final double height;
  final double width;
  final double radius;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDuration.slow,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // `docs/02 §14` trazi postovanje `reduce motion`. Korisnik koji je ugasio animacije
    // najcesce to radi zbog mucnine ili migrene — puls koji se ponavlja u nedogled je
    // tacno ono sto ga izaziva, pa se ovdje iscrta mirna povrsina.
    final bezAnimacije = MediaQuery.disableAnimationsOf(context);

    final povrsina = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: SizedBox(height: widget.height, width: widget.width),
    );

    if (bezAnimacije) {
      return ExcludeSemantics(child: povrsina);
    }

    return ExcludeSemantics(
      child: FadeTransition(
        // Ne ide do pune prozirnosti: kostur koji nestane pa se vrati izgleda kao
        // treptaj sadrzaja, a ne kao ucitavanje.
        opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
        child: povrsina,
      ),
    );
  }
}
