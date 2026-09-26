import 'dart:typed_data';

import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../poruka_greske.dart';
import '../theme/theme.dart';

/// Slika koju je vlasnik izabrao, prije slanja.
class IzabranaSlika {
  const IzabranaSlika({required this.bytes, required this.contentType});
  final Uint8List bytes;
  final String contentType;
}

/// Otvara izbor slike. Provider, da widget test podmetne sliku bez platformskog plugina.
///
/// **Smanjenje je ovdje, ne na serveru.** Telefon šalje 4–12 MB; `maxWidth` i
/// `imageQuality` svedu fotografiju na par stotina KB prije slanja, a bucket (5 MiB) je
/// samo granica za ono što bi ipak prošlo.
final izborSlikeProvider = Provider<Future<IzabranaSlika?> Function()>(
  (ref) => () async {
    final fajl = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (fajl == null) return null;
    return IzabranaSlika(
      bytes: await fajl.readAsBytes(),
      contentType: fajl.mimeType ?? _tipIzImena(fajl.name),
    );
  },
);

String _tipIzImena(String ime) {
  final malo = ime.toLowerCase();
  if (malo.endsWith('.png')) return 'image/png';
  if (malo.endsWith('.webp')) return 'image/webp';
  if (malo.endsWith('.jpg') || malo.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/octet-stream';
}

/// Polje za sliku u obrascu (task 49): pregled, „Izaberi" i „Ukloni".
///
/// Slika se šalje **odmah po izboru**, a [onChanged] dobija javni URL tek kad upload
/// uspije. Neuspio upload zato ne dira ni polje ni kolonu — ostaje stara slika i poruka.
/// Kolona se mijenja tek kad obrazac snimi, kao i svako drugo polje.
class SlikaPolje extends ConsumerStatefulWidget {
  const SlikaPolje({
    required this.url,
    required this.kind,
    required this.onChanged,
    this.onSaljeChanged,
    this.krug = false,
    this.velicina = 72,
    super.key,
  });

  final String? url;
  final MediaKind kind;
  final ValueChanged<String?> onChanged;

  /// Obrazac blokira „Sačuvaj" dok upload traje — inače bi snimio staru sliku, a nova bi
  /// završila kao siroče.
  final ValueChanged<bool>? onSaljeChanged;

  /// Radnik je krug (kao u listi osoblja), usluga kvadrat.
  final bool krug;
  final double velicina;

  @override
  ConsumerState<SlikaPolje> createState() => _SlikaPoljeState();
}

class _SlikaPoljeState extends ConsumerState<SlikaPolje> {
  bool _salje = false;
  String? _greska;

  void _postaviSalje(bool v) {
    setState(() => _salje = v);
    widget.onSaljeChanged?.call(v);
  }

  Future<void> _izaberi() async {
    final salon = ref.read(adminSalonIdProvider);
    final IzabranaSlika? slika;
    try {
      slika = await ref.read(izborSlikeProvider)();
    } catch (_) {
      if (mounted) setState(() => _greska = 'Galerija se ne može otvoriti.');
      return;
    }
    if (slika == null || !mounted) return;
    if (salon == null) {
      setState(() => _greska = opstaPorukaGreske);
      return;
    }
    _greska = null;
    _postaviSalje(true);
    try {
      final url = await ref
          .read(mediaRepositoryProvider)
          .upload(
            salonId: salon,
            kind: widget.kind,
            bytes: slika.bytes,
            contentType: slika.contentType,
          );
      if (!mounted) return;
      _postaviSalje(false);
      widget.onChanged(url);
    } catch (e) {
      if (!mounted) return;
      _greska = porukaGreske(e, opsta: 'Slika se ne može poslati.');
      _postaviSalje(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    final url = widget.url;
    final ima = url != null && url.isNotEmpty;
    final prazno = ColoredBox(
      color: boje.neutralTint,
      child: Icon(
        widget.krug ? Icons.person_outline : Icons.image_outlined,
        color: boje.textMuted,
      ),
    );
    Widget pregled = SizedBox.square(
      dimension: widget.velicina,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ima)
            Image.network(
              url,
              key: ValueKey(url),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => prazno,
            )
          else
            prazno,
          // Napredak je zatamnjen pregled i „Šaljem…" na dugmetu — bez Material
          // spinnera (FE-205, `no_material_indicators_test`).
          if (_salje) ColoredBox(color: boje.ink.withValues(alpha: 0.45)),
        ],
      ),
    );
    pregled = widget.krug ? ClipOval(child: pregled) : ClipRect(child: pregled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Semantics(
              image: true,
              label: _salje
                  ? 'Slika se šalje'
                  : ima
                  ? 'Trenutna slika'
                  : 'Bez slike',
              child: pregled,
            ),
            const SizedBox(width: AdminSpacing.md),
            Expanded(
              child: Wrap(
                spacing: AdminSpacing.sm,
                runSpacing: AdminSpacing.xs,
                children: [
                  OutlinedButton.icon(
                    key: const Key('slika-izaberi'),
                    onPressed: _salje ? null : _izaberi,
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: Text(
                      _salje
                          ? 'Šaljem…'
                          : ima
                          ? 'Zamijeni sliku'
                          : 'Izaberi sliku',
                    ),
                  ),
                  if (ima)
                    TextButton(
                      key: const Key('slika-ukloni'),
                      onPressed: _salje
                          ? null
                          : () {
                              setState(() => _greska = null);
                              widget.onChanged(null);
                            },
                      child: const Text('Ukloni'),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_greska != null) ...[
          const SizedBox(height: AdminSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              _greska!,
              style: tema.bodySmall?.copyWith(color: boje.destructive),
            ),
          ),
        ],
      ],
    );
  }
}
