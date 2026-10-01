import 'dart:ui' as ui;

import 'package:core_api/core_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/poruka_greske.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/slika_polje.dart';
import '../appointments/appointments_providers.dart';

/// Najmanja strana profilne slike (`4b`: „JPG ili PNG, najmanje 400×400").
///
/// Manja slika na klijentskoj kartici radnika (dvije kolone, portret) izgleda mutno na
/// svakom telefonu sa gustim ekranom — a to je jedino mjesto gdje je klijent vidi.
const kProfilnaMinStrana = 400;

/// Izbor profilne slike iz galerije ili kamerom. Provider, da widget test podmetne sliku
/// bez platformskog plugina — isto kao [izborSlikeProvider].
final izborProfilneSlikeProvider =
    Provider<Future<IzabranaSlika?> Function(ImageSource)>(
      (ref) => (izvor) async {
        final fajl = await ImagePicker().pickImage(
          source: izvor,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85,
          preferredCameraDevice: CameraDevice.front,
        );
        if (fajl == null) return null;
        return IzabranaSlika(
          bytes: await fajl.readAsBytes(),
          contentType: fajl.mimeType ?? tipSlikeIzImena(fajl.name),
        );
      },
    );

/// Kamera postoji samo na telefonu; web i desktop otvaraju fajl dijalog.
bool get imaKameru =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Izabere, provjeri, pošalje i postavi profilnu sliku. Vraća `true` kad je nova slika
/// postavljena; grešku javlja sam, porukom ispod ekrana.
///
/// Upload ide prije poziva baze, kao i u [SlikaPolje]: neuspio upload ne dira ni red ni
/// prikaz. Objekat koji je poslan, a baza ga odbije, postaje siroče koje čisti task 51.
///
/// **Sve iz providera se uzima prije prvog `await`.** Zove je i meni u sidebaru, čiji widget
/// nestane čim korisnik promijeni ekran dok bira sliku; `ref` tada baca, a upload bi tiho
/// propao. `ProviderContainer` živi koliko i aplikacija.
Future<bool> promijeniProfilnuSliku(
  BuildContext context,
  WidgetRef ref, {
  ImageSource izvor = ImageSource.gallery,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final clan = container.read(currentStaffProvider).valueOrNull;
  final salonId = clan?.salonId;
  if (clan == null || salonId == null) return false;
  final izbor = container.read(izborProfilneSlikeProvider);
  final media = container.read(mediaRepositoryProvider);
  final staff = container.read(staffRepositoryProvider);

  final IzabranaSlika? slika;
  try {
    slika = await izbor(izvor);
  } catch (_) {
    if (context.mounted) {
      _poruka(
        context,
        izvor == ImageSource.camera
            ? 'Kamera se ne može otvoriti.'
            : 'Galerija se ne može otvoriti.',
      );
    }
    return false;
  }
  if (slika == null) return false;

  final strana = await _manjaStrana(slika.bytes);
  if (strana != null && strana < kProfilnaMinStrana) {
    if (context.mounted) {
      _poruka(
        context,
        'Slika je premala ($strana px). Treba najmanje '
        '$kProfilnaMinStrana×$kProfilnaMinStrana.',
      );
    }
    return false;
  }

  try {
    final url = await media.upload(
      salonId: salonId,
      kind: MediaKind.profil,
      ownerId: clan.id,
      bytes: slika.bytes,
      contentType: slika.contentType,
    );
    await staff.setPhoto(url);
  } catch (e) {
    if (context.mounted) {
      _poruka(context, porukaGreske(e, opsta: 'Slika se ne može poslati.'));
    }
    return false;
  }
  osvjeziProfil(container);
  if (context.mounted) _poruka(context, 'Profilna slika je promijenjena.');
  return true;
}

/// Ukloni profilnu sliku. Baza tada salonu vraća njegovu sliku radnika i gasi prekidač.
Future<void> ukloniProfilnuSliku(BuildContext context, WidgetRef ref) async {
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    await container.read(staffRepositoryProvider).setPhoto(null);
  } catch (e) {
    if (context.mounted) _poruka(context, porukaGreske(e));
    return;
  }
  osvjeziProfil(container);
  if (context.mounted) _poruka(context, 'Profilna slika je uklonjena.');
}

/// Član (avatar, prekidač) i radnici (slika koju klijent vidi) se mijenjaju zajedno.
void osvjeziProfil(ProviderContainer container) {
  container
    ..invalidate(currentStaffProvider)
    ..invalidate(adminEmployeesProvider);
}

/// Kraća strana slike, ili `null` kad se ne da dekodirati — tada odlučuje bucket.
Future<int?> _manjaStrana(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final okvir = await codec.getNextFrame();
    final s = okvir.image.width < okvir.image.height
        ? okvir.image.width
        : okvir.image.height;
    okvir.image.dispose();
    codec.dispose();
    return s;
  } catch (_) {
    return null;
  }
}

/// Kratka poruka ispod ekrana — jedna za cijeli profil.
void porukaProfila(BuildContext context, String tekst) =>
    _poruka(context, tekst);

void _poruka(BuildContext context, String tekst) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(tekst)));
}

/// Okrugli avatar osobe; bez slike inicijali (`4b`), ne siva kugla.
///
/// Kugla bez slova bi izgledala isto za svakog člana osoblja, a u meniju i na profilu je
/// upravo pitanje „čiji je ovo nalog".
class ProfilAvatar extends StatelessWidget {
  const ProfilAvatar({
    required this.url,
    required this.ime,
    required this.velicina,
    this.naTamnom = false,
    super.key,
  });

  final String? url;
  final String ime;
  final double velicina;

  /// Sidebar je taman, pa inicijali idu svijetlim na tamnijoj podlozi.
  final bool naTamnom;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final inicijali = Text(
      inicijaliOd(ime),
      style: TextStyle(
        fontSize: velicina * 0.36,
        fontWeight: FontWeight.w600,
        color: naTamnom ? boje.sidebarAccentForeground : boje.textSecondary,
        height: 1,
      ),
    );
    final prazno = ColoredBox(
      color: naTamnom ? boje.sidebarSelected : boje.neutralTint,
      child: Center(child: inicijali),
    );
    final adresa = url;

    return Semantics(
      image: true,
      label: adresa == null ? 'Bez profilne slike' : 'Profilna slika',
      child: ClipOval(
        child: SizedBox.square(
          dimension: velicina,
          child: adresa == null || adresa.isEmpty
              ? prazno
              : Image.network(
                  adresa,
                  key: ValueKey(adresa),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => prazno,
                ),
        ),
      ),
    );
  }
}

/// `Emir Bešić` → `EB`, `Amko` → `A`. Prazno ime daje prazan string.
String inicijaliOd(String ime) {
  final dijelovi = ime
      .trim()
      .split(RegExp(r'\s+'))
      .where((d) => d.isNotEmpty)
      .toList();
  if (dijelovi.isEmpty) return '';
  final prvi = dijelovi.first.characters.first.toUpperCase();
  if (dijelovi.length == 1) return prvi;
  return prvi + dijelovi.last.characters.first.toUpperCase();
}
