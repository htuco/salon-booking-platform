/// Kontakt klijenta jednim tapom (task 58): poziv, Viber i WhatsApp.
///
/// Dva ekrana nude isti kontakt, detalj termina (`3n`) i profil klijenta (`3e`), pa su
/// pravila ovdje: kako se broj pretvara u link, koji kanal postoji na kojoj platformi i
/// šta se desi kad uređaj link ne može otvoriti. Ekran crta samo svoja dugmad.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme/theme.dart';
import 'widgets/admin_toast.dart';

/// Kanal kojim vlasnik dobija klijenta.
enum KanalKontakta {
  poziv('Poziv'),
  viber('Viber'),
  whatsapp('WhatsApp');

  const KanalKontakta(this.naziv);

  /// Ime na dugmetu i u poruci kad se ne može otvoriti.
  final String naziv;
}

/// Broj u međunarodnom obliku (`+38761552104`), ili `null` kad od njega nema linka.
///
/// **Zašto normalizacija, a ne broj kakav jeste:** `wa.me` i Viber traže pozivni broj, a
/// lokalni `061 …` tamo otvori pogrešnu osobu ili ništa. App od taska 66 šalje `+387 61 …`,
/// ali salon walk-in klijenta upisuje kako ga čuje, sa nulom.
///
/// **Vodeća `0` je `+387`, i to je pretpostavka tržišta, ne podatak.** Salon nema polje
/// zemlje (v. `security.md`, „po ciframa"), pa lokalni broj iz salona van BiH ovdje dobije
/// pogrešan prefiks. Baza se ne mijenja: ovo je samo oblik linka.
///
/// `null` za prazan unos i za ono što ne liči na broj (manje od 8 ili više od 15 cifara,
/// granica iz E.164). Ekran tada ne nudi kontakt, umjesto da ponudi dugme koje ne radi.
String? medjunarodniBroj(String? telefon) {
  final unos = telefon?.trim() ?? '';
  if (unos.isEmpty) return null;
  final cifre = unos.replaceAll(RegExp(r'\D'), '');

  final String medjunarodne;
  if (unos.startsWith('+')) {
    medjunarodne = cifre;
  } else if (cifre.startsWith('00')) {
    medjunarodne = cifre.substring(2);
  } else if (cifre.startsWith('0')) {
    medjunarodne = '387${cifre.substring(1)}';
  } else if (cifre.startsWith('387')) {
    medjunarodne = cifre;
  } else {
    // „61 552 104": lokalni broj kojem je salon izostavio nulu.
    medjunarodne = '387$cifre';
  }

  if (medjunarodne.length < 8 || medjunarodne.length > 15) return null;
  return '+$medjunarodne';
}

/// Link kanala za broj iz [medjunarodniBroj].
Uri uriKontakta(KanalKontakta kanal, String broj) {
  final cifre = broj.replaceFirst('+', '');
  return switch (kanal) {
    KanalKontakta.poziv => Uri(scheme: 'tel', path: broj),
    // `Uri` kodira `+` u `%2B`; nekodiran `+` Viber čita kao razmak i ne nađe broj.
    KanalKontakta.viber => Uri(
      scheme: 'viber',
      host: 'chat',
      queryParameters: {'number': broj},
    ),
    // `wa.me` traži samo cifre, bez `+` i bez razmaka.
    KanalKontakta.whatsapp => Uri.https('wa.me', '/$cifre'),
  };
}

/// Kanali poruke koje platforma može otvoriti.
///
/// **Viber na webu ne postoji kao dugme.** `viber://` u pregledniku bez instalirane
/// desktop aplikacije ne radi ništa i ne javi grešku, a `canLaunchUrl` na webu za
/// nepoznatu šemu ne zna odgovor — dugme bi bilo mrtvo. `tel:` i `https://wa.me/` na webu
/// rade (sistemski izbor aplikacije, WhatsApp Web).
List<KanalKontakta> kanaliPoruke({required bool web}) => web
    ? const [KanalKontakta.whatsapp]
    : const [KanalKontakta.viber, KanalKontakta.whatsapp];

/// Kanali poruke na ovoj platformi. Test ga override-uje da glumi web.
final kanaliPorukeProvider = Provider<List<KanalKontakta>>(
  (ref) => kanaliPoruke(web: kIsWeb),
);

/// Otvara link izvan aplikacije; `false` kad uređaj nema čime.
///
/// Provider, a ne direktan `launchUrl`, da widget test vidi **koji** link je otvoren bez
/// mockovanja platformskog kanala.
final otvoriLinkProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Otvara [kanal] za [broj] i javi kad ne može.
///
/// Za razliku od klijentske app-e, ovdje se neuspjeh **ne guta**: vlasnik je usred posla i
/// treba znati da Viber nije instaliran, inače tapne ponovo i misli da app ne radi.
Future<void> kontaktiraj(
  BuildContext context,
  WidgetRef ref,
  KanalKontakta kanal,
  String broj,
) async {
  final otvori = ref.read(otvoriLinkProvider);
  var otvoreno = false;
  try {
    otvoreno = await otvori(uriKontakta(kanal, broj));
  } catch (_) {
    // Platforma baca kad šema nije registrovana; ishod je isti kao `false`.
  }
  if (otvoreno || !context.mounted) return;
  AdminToast.info(
    context,
    kanal == KanalKontakta.poziv
        ? 'Poziv se ne može otvoriti.'
        : '${kanal.naziv} se ne može otvoriti.',
    opis: 'Na ovom uređaju nema aplikacije za to.',
  );
}

/// „Poruka": izbor kanala, pa otvaranje.
///
/// Canvas (`3n`, `adminv2/profil`) crta jedno dugme „Poruka", a kanala su dva. Dva dugmeta
/// bi razbila red od tri iz `3n`, pa izbor ide u sheet. Kad platforma ima samo jedan kanal
/// (web), sheet se preskače — izbor od jedne stavke je dodir viška.
Future<void> ponudiPoruku(
  BuildContext context,
  WidgetRef ref,
  String broj,
) async {
  final kanali = ref.read(kanaliPorukeProvider);
  if (kanali.isEmpty) return;
  if (kanali.length == 1) {
    await kontaktiraj(context, ref, kanali.single, broj);
    return;
  }

  final boje = context.adminColors;
  final izbor = await showModalBottomSheet<KanalKontakta>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    barrierColor: boje.sidebarBackground.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AdminRadius.mobileSheet),
      ),
    ),
    builder: (sheetContext) {
      final tekst = Theme.of(sheetContext).textTheme;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Poruka',
                style: tekst.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                broj,
                style: AdminText.time.copyWith(color: boje.textSecondary),
              ),
              const SizedBox(height: AdminSpacing.lg),
              for (final kanal in kanali)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: AdminSize.touchTarget,
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(kanal.naziv),
                  onTap: () => Navigator.pop(sheetContext, kanal),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (izbor == null || !context.mounted) return;
  await kontaktiraj(context, ref, izbor, broj);
}
