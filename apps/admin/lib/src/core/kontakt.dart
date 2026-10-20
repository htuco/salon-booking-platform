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
/// `null` za prazan unos i za ono što ne liči na broj. Granice: 8–15 cifara (E.164), a za
/// `+387` 11–12, jer BiH nacionalni broj bez nule ima 8 cifara (fiksni i većina mobilnih) ili
/// 9 (noviji mobilni). Broj bez nule i bez pozivnog je BiH samo dok staje u tih 9; duži je
/// strani broj kojem je salon izostavio `+`, i pogrešan `+387` bi zvao nepostojeći broj.
/// Ekran tada ne nudi kontakt, umjesto da ponudi dugme koje ne radi.
String? medjunarodniBroj(String? telefon) {
  final unos = telefon?.trim() ?? '';
  if (unos.isEmpty) return null;
  final cifre = unos.replaceAll(RegExp(r'\D'), '');

  String medjunarodne;
  if (cifre.startsWith('00')) {
    // I „+00387 …": plus i `00` znače isto, pa je jedno od njih višak.
    medjunarodne = cifre.substring(2);
  } else if (cifre.startsWith('0')) {
    // I „+061 …": pozivni broj države ne počinje nulom, pa je `0` nacionalna nula, a plus
    // višak — isto pravilo kao bez plusa.
    medjunarodne = '387${cifre.substring(1)}';
  } else if (unos.startsWith('+') || cifre.startsWith('387')) {
    medjunarodne = cifre;
  } else {
    // „61 552 104": lokalni broj kojem je salon izostavio nulu. Duži od 9 cifara odbije
    // granica za `+387` ispod.
    medjunarodne = '387$cifre';
  }
  // „+387 061 …": adresar često drži i pozivni i nulu, a `wa.me` i Viber sa nulom ne
  // nađu osobu.
  if (medjunarodne.startsWith('3870')) {
    medjunarodne = '387${medjunarodne.substring(4)}';
  }
  // „00 061 …": i poslije `00` ostaje nula, a nijedan pozivni broj države njom ne počinje.
  if (medjunarodne.startsWith('0')) return null;

  final (najmanje, najvise) = medjunarodne.startsWith('387')
      ? (11, 12)
      : (8, 15);
  if (medjunarodne.length < najmanje || medjunarodne.length > najvise)
    return null;
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
/// nepoznatu šemu ne zna odgovor — dugme bi bilo mrtvo. `https://wa.me/` na webu otvara
/// WhatsApp Web (provjereno uživo). „Pozovi" ostaje jer macOS i Windows imaju handler za
/// `tel:`, ali `tel:` u pregledniku **nije provjeren**, a neuspjeh se tamo ne vidi (v.
/// [kontaktiraj]).
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
///
/// **Na webu toast ne hvata neuspjeh.** Launcher tamo otvara novi prozor sa `noopener` i
/// uvijek javi uspjeh, pa link bez handlera ostane tih — toast radi samo na iOS-u i Androidu.
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
  } catch (e) {
    // Platforma baca kad šema nije registrovana; za vlasnika je ishod isti kao `false`,
    // a uzrok ostaje u logu.
    debugPrint('kontakt: $kanal nije otvoren: $e');
  }
  if (otvoreno || !context.mounted) return;
  AdminToast.info(
    context,
    '${kanal.naziv} se ne može otvoriti.',
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
    // Kao „Šta dodajemo?" iz mobilnog shella: bez ovoga sheet u landscapeu sa notchom
    // prelazi visinu i WhatsApp ostaje ispod ivice.
    isScrollControlled: true,
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
        child: SingleChildScrollView(
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
                // Bez ikone, kao lista u profilu: ista ikona za oba kanala ne nosi
                // ništa, a logo tuđeg brenda u adminu ne crtamo.
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: AdminSize.touchTarget,
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
