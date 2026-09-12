import 'package:flutter/material.dart';

import '../tokens/spacing.dart';

/// Kvadratni (ili portretni) okvir za fotografiju — `SPEC.md` §Recurring components.
///
/// "**Photo frame** — square/portrait, `1px solid`, background ground, **never rounded,
/// never cropped round**." Okrugli avatar je zato greška u ovom sistemu, ne stilski izbor:
/// sve je uglato, pa jedan krug odmah izgleda kao da je došao iz druge aplikacije.
///
/// Kad slike nema — a danas je nema nijedne, svih 45 slotova u handoffu su placeholderi —
/// okvir **ostaje vidljiv** i nosi zamjenski sadržaj (inicijal, upitnik, ikona). Prazan
/// prostor bi pomjerio raspored čim prve prave fotografije stignu.
class PhotoFrame extends StatelessWidget {
  const PhotoFrame({
    this.imageUrl,
    this.placeholder,
    this.size = AppSize.rowPhoto,
    this.aspectRatio = 1,
    super.key,
  });

  /// Fotografija. Podrzana su dva oblika:
  ///
  /// - `http(s)://…` — slika sa mreze (`salons`/`employees.image_url`)
  /// - `assets/…` — slika spakovana uz app; koristi je demo ulaz sa placeholder plocama
  ///
  /// `null` ili prazno → crta se [placeholder].
  final String? imageUrl;

  /// Šta stoji u okviru dok slike nema (inicijal, `?`, ikona).
  final Widget? placeholder;

  /// Strana okvira; kod portreta je to širina.
  final double size;

  /// 1 za kvadrat, 0.75 za portret 3:4.
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrl;
    final imaSliku = url != null && url.isNotEmpty;

    return Container(
      width: size,
      height: size / aspectRatio,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outline),
      ),
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.center,
      child: imaSliku
          ? Image(
              image: url.startsWith('assets/')
                  ? AssetImage(url) as ImageProvider<Object>
                  : NetworkImage(url),
              fit: BoxFit.cover,
              width: size,
              height: size / aspectRatio,
              // Slika koja ne stigne ne smije srušiti red — okvir se vrati na zamjenu.
              errorBuilder: (context, error, stack) =>
                  placeholder ?? const SizedBox.shrink(),
            )
          : placeholder,
    );
  }
}
