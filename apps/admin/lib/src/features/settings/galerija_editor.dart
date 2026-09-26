/// Galerija salona u postavkama (task 50): dodaj, obriši, promijeni redoslijed.
///
/// ## Svaka radnja je svoj upis
///
/// Za razliku od ostatka postavki, galerija ne čeka „Sačuvaj". Slika se šalje u bucket čim
/// je izabrana, a niz se upisuje odmah poslije — da izabrana, a nesnimljena fotografija ne
/// visi u formi dok vlasnik ne zaboravi na nju. Isto za brisanje i pomjeranje: jedna
/// radnja, jedan `set_salon_gallery`.
///
/// ## Dva taba ne pregaze jedan drugog
///
/// Svaki upis šalje niz koji je ekran **prikazao** kao `p_expected`. Ako ga je drugi tab ili
/// uređaj u međuvremenu promijenio, baza ne upiše ništa (`PT409`), a ekran učita stvarno
/// stanje i kaže vlasniku da ponovi izmjenu. Tiho spajanje bi pogađalo namjeru: pomjeranje
/// slike koju je drugi tab upravo obrisao nema tačan ishod.
///
/// ## Redoslijed su strelice, ne prevlačenje
///
/// Mreža sa prevlačenjem na telefonu se bori sa skrolom, a čitač ekrana je ne može
/// koristiti. „Naprijed" i „Nazad" rade isto na 402 i 1440 i imaju svoj opis.
library;

import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/poruka_greske.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/slika_polje.dart';
import 'settings_providers.dart';

/// Najviše slika u galeriji — ista granica kao u `set_salon_gallery`.
const maksGalerija = 30;

/// Stranica sličice; tri dugmeta ispod nje su po [AdminSize.touchTarget].
const double _strana = AdminSize.touchTarget * 3;

class GalerijaEditor extends ConsumerStatefulWidget {
  const GalerijaEditor({super.key});

  @override
  ConsumerState<GalerijaEditor> createState() => _GalerijaEditorState();
}

class _GalerijaEditorState extends ConsumerState<GalerijaEditor> {
  bool _radim = false;
  String? _poruka;

  /// Jedan upis niza. [zatecena] je ono što je ekran prikazao prije radnje.
  Future<void> _upisi(List<String> zatecena, List<String> nova) async {
    try {
      await ref
          .read(settingsActionsProvider)
          .sacuvajGaleriju(zatecena: zatecena, nova: nova);
      _poruka = null;
    } on ConflictError {
      _poruka =
          'Galerija je u međuvremenu promijenjena na drugom mjestu. '
          'Prikazana je trenutna — ponovite izmjenu.';
    } catch (e) {
      _poruka = porukaGreske(e, opsta: 'Galerija se ne može sačuvati.');
    }
  }

  Future<void> _radnja(Future<void> Function() posao) async {
    if (_radim) return;
    setState(() {
      _radim = true;
      _poruka = null;
    });
    await posao();
    if (mounted) setState(() => _radim = false);
  }

  Future<void> _dodaj(List<String> zatecena) => _radnja(() async {
    final salon = ref.read(adminSalonIdProvider);
    final IzabranaSlika? slika;
    try {
      slika = await ref.read(izborSlikeProvider)();
    } catch (_) {
      _poruka = 'Galerija uređaja se ne može otvoriti.';
      return;
    }
    if (slika == null) return;
    if (salon == null) {
      _poruka = opstaPorukaGreske;
      return;
    }
    final String url;
    try {
      url = await ref
          .read(mediaRepositoryProvider)
          .upload(
            salonId: salon,
            kind: MediaKind.galerija,
            bytes: slika.bytes,
            contentType: slika.contentType,
          );
    } catch (e) {
      _poruka = porukaGreske(e, opsta: 'Slika se ne može poslati.');
      return;
    }
    // Nova ide na početak: ono što je salon upravo uradio je ono što želi pokazati.
    await _upisi(zatecena, [url, ...zatecena]);
  });

  Future<void> _pomjeri(List<String> zatecena, int od, int ka) =>
      _radnja(() async {
        final nova = [...zatecena];
        final url = nova.removeAt(od);
        nova.insert(ka, url);
        await _upisi(zatecena, nova);
      });

  Future<void> _obrisi(List<String> zatecena, int i) async {
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obrisati fotografiju?'),
        content: const Text('Klijenti je više neće vidjeti u galeriji.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          TextButton(
            key: const Key('galerija-obrisi-potvrda'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (potvrda != true || !mounted) return;
    await _radnja(() => _upisi(zatecena, [...zatecena]..removeAt(i)));
  }

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final tema = Theme.of(context).textTheme;
    final galerija = ref.watch(postavkeGalerijaProvider);
    final opis = tema.bodySmall?.copyWith(color: boje.textSecondary);

    // Osvježavanje poslije upisa ne vraća prazno stanje — mreža ostaje dok ne stigne nova.
    final lista = galerija.valueOrNull;
    if (lista == null) {
      if (galerija.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Galerija se ne može učitati.'),
            const SizedBox(height: AdminSpacing.sm),
            OutlinedButton(
              onPressed: () => ref.invalidate(postavkeGalerijaProvider),
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        );
      }
      return Text('Učitavam galeriju…', style: opis);
    }

    final zauzeto = _radim || galerija.isLoading;
    final puna = lista.length >= maksGalerija;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Fotografije radova na Početnoj i u galeriji aplikacije, ovim '
          'redoslijedom. Nova fotografija ide na početak.',
          style: opis,
        ),
        const SizedBox(height: AdminSpacing.md),
        if (lista.isEmpty)
          Text(
            'Galerija je prazna. Klijenti tada ne vide sekciju galerije.',
            key: const Key('galerija-prazna'),
            style: tema.bodyMedium,
          )
        else
          Wrap(
            spacing: AdminSpacing.md,
            runSpacing: AdminSpacing.md,
            children: [
              for (var i = 0; i < lista.length; i++)
                _Plocica(
                  key: ValueKey(lista[i]),
                  url: lista[i],
                  redni: i + 1,
                  ukupno: lista.length,
                  naprijed: zauzeto || i == 0
                      ? null
                      : () => _pomjeri(lista, i, i - 1),
                  nazad: zauzeto || i == lista.length - 1
                      ? null
                      : () => _pomjeri(lista, i, i + 1),
                  obrisi: zauzeto ? null : () => _obrisi(lista, i),
                ),
            ],
          ),
        const SizedBox(height: AdminSpacing.md),
        Wrap(
          spacing: AdminSpacing.md,
          runSpacing: AdminSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const Key('galerija-dodaj'),
              onPressed: zauzeto || puna ? null : () => _dodaj(lista),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(_radim ? 'Čuvam…' : 'Dodaj fotografiju'),
            ),
            Text(
              puna
                  ? 'Galerija je puna ($maksGalerija / $maksGalerija).'
                  : '${lista.length} / $maksGalerija',
              style: opis,
            ),
          ],
        ),
        if (_poruka case final poruka?) ...[
          const SizedBox(height: AdminSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              poruka,
              key: const Key('galerija-poruka'),
              style: tema.bodySmall?.copyWith(color: boje.destructive),
            ),
          ),
        ],
      ],
    );
  }
}

/// Jedna fotografija sa svoje tri radnje.
class _Plocica extends StatelessWidget {
  const _Plocica({
    required this.url,
    required this.redni,
    required this.ukupno,
    required this.naprijed,
    required this.nazad,
    required this.obrisi,
    super.key,
  });

  final String url;
  final int redni;
  final int ukupno;
  final VoidCallback? naprijed;
  final VoidCallback? nazad;
  final VoidCallback? obrisi;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final prazno = ColoredBox(
      color: boje.neutralTint,
      child: Icon(Icons.broken_image_outlined, color: boje.textMuted),
    );

    return SizedBox(
      width: _strana,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            image: true,
            label: 'Fotografija $redni od $ukupno',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AdminRadius.small),
              child: SizedBox.square(
                dimension: _strana,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => prazno,
                ),
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                key: Key('galerija-naprijed-$redni'),
                tooltip: 'Pomjeri naprijed',
                style: _dugme,
                onPressed: naprijed,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                key: Key('galerija-nazad-$redni'),
                tooltip: 'Pomjeri nazad',
                style: _dugme,
                onPressed: nazad,
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                key: Key('galerija-obrisi-$redni'),
                tooltip: 'Obriši fotografiju',
                style: _dugme,
                onPressed: obrisi,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dugme ispod sličice je tačno [AdminSize.touchTarget]; Material bi ga inače proširio
/// na 48 i tri ne bi stala ispod sličice.
final _dugme = IconButton.styleFrom(
  fixedSize: const Size.square(AdminSize.touchTarget),
  minimumSize: const Size.square(AdminSize.touchTarget),
  padding: EdgeInsets.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);
