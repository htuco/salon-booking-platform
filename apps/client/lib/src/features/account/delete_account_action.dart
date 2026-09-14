import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../l10n/generated/app_localizations.dart';

/// Brisanje naloga — potvrda, poziv i povratak u javno stanje. Task 17.
///
/// Jedna funkcija, a **dva ulaza**: handoff (`11-postavke.png`) crta „Izbriši račun" na
/// samim Postavkama, a DoD taska traži isto i na „Mom računu". Oba ekrana zato zovu ovo,
/// umjesto da svaki nosi svoju kopiju dijaloga i obrade greške. Dvije kopije destruktivne
/// radnje su dvije prilike da se raziđu, i to na mjestu gdje razlika znači da jedan put
/// zaboravi odjavu.
///
/// ## Zašto dijalog kaže šta **ostaje**
///
/// DoD traži potvrdu koja objašnjava posljedicu, ne „jeste li sigurni". Tekst zato imenuje
/// i šta odlazi (ime, kontakt, budući termini) i šta ostaje (zapis salona o obavljenim
/// terminima, bez ličnih podataka). Bez te druge polovine korisnik ne može donijeti odluku
/// koju od njega tražimo — a i netačna je: `appointments` redovi zaista ostaju.
///
/// ## Povratak u javno stanje
///
/// Nakon uspjeha app ide na `/` i tamo pokazuje potvrdu. Odjavu radi
/// `AuthRepository.deleteAccount()` — ovdje se **ne ponavlja**, jer bi drugi `signOut` nad
/// već odjavljenom sesijom bio tiha zavisnost od redoslijeda. Navigacija je ovdje jer je
/// stvar ekrana, ne repozitorija.
Future<void> obrisiNalog(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  final potvrda = await AppDialog.show(
    context,
    dialog: AppDialog(
      kicker: l10n.accountDeleteKicker,
      title: l10n.accountDeleteTitle,
      message: l10n.accountDeleteBody,
      confirmLabel: l10n.accountDeleteConfirm,
      cancelLabel: l10n.accountDeleteCancel,
    ),
  );

  // `false` i `null` oboje znače odustajanje — `null` stiže od dodira izvan dijaloga i od
  // sistemskog „nazad" (v. `AppDialog.show`).
  if (potvrda != true) return;

  try {
    await ref.read(authRepositoryProvider).deleteAccount();
  } on ApiError catch (greska) {
    // **Korisnik ostaje prijavljen kad brisanje padne**, i to je namjerno: odjava bi mu
    // oduzela jedini token kojim može pokušati ponovo, pa bi nalog ostao neobrisan
    // zauvijek. Poruka se zato vraća na isti ekran, sa nepromijenjenim stanjem.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          greska.message.isEmpty ? l10n.accountDeleteFailed : greska.message,
        ),
      ),
    );
    return;
  }

  // `go`, ne `push`: nazad sa Početne ne smije voditi na Postavke naloga koji više ne
  // postoji. `go` briše stek, `push` bi ga ostavio.
  router.go(ClientRoute.home.path);
  messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeletedNotice)));
}
